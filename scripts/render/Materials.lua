-- ============================================================================
-- 星河战姬 Starkyries - 材质系统
-- PBR材质创建和管理（带完整缓存，优化内存）
-- ============================================================================

local Materials = {}

-- 材质缓存
local materialCache = {}

-- 缓存统计（调试用）
local cacheHits = 0
local cacheMisses = 0

-- ============================================================================
-- 缓存辅助函数
-- ============================================================================

-- 颜色量化（减少缓存条目数，但保持视觉质量）
local function QuantizeColor(v)
    return math.floor(v * 100 + 0.5) / 100  -- 量化到0.01精度，视觉无损
end

-- 生成缓存键
local function MakeCacheKey(prefix, r, g, b, ...)
    local qr = QuantizeColor(r or 0)
    local qg = QuantizeColor(g or 0)
    local qb = QuantizeColor(b or 0)
    local extra = {...}
    local key = string.format("%s_%.2f_%.2f_%.2f", prefix, qr, qg, qb)
    for i, v in ipairs(extra) do
        if type(v) == "number" then
            key = key .. string.format("_%.1f", QuantizeColor(v))
        else
            key = key .. "_" .. tostring(v)
        end
    end
    return key
end

-- ============================================================================
-- PBR 材质创建（带缓存）
-- ============================================================================

-- 创建基础PBR材质（内部函数，不缓存）
local function CreatePBRInternal(r, g, b, metallic, roughness, emissiveR, emissiveG, emissiveB)
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(r, g, b, 1.0)))
    mat:SetShaderParameter("MatSpecColor", Variant(Color(0.6, 0.6, 0.6, 1.0)))
    mat:SetShaderParameter("Metallic", Variant(metallic or 0.5))
    mat:SetShaderParameter("Roughness", Variant(roughness or 0.5))
    if emissiveR then
        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(
            emissiveR, 
            emissiveG or emissiveR, 
            emissiveB or emissiveR
        )))
    end
    return mat
end

-- 创建基础PBR材质（带缓存）
function Materials.CreatePBR(r, g, b, metallic, roughness, emissiveR, emissiveG, emissiveB)
    local key = MakeCacheKey("pbr", r, g, b, metallic or 0.5, roughness or 0.5, 
                              emissiveR or 0, emissiveG or emissiveR or 0, emissiveB or emissiveR or 0)
    if materialCache[key] then
        cacheHits = cacheHits + 1
        return materialCache[key]
    end
    cacheMisses = cacheMisses + 1
    local mat = CreatePBRInternal(r, g, b, metallic, roughness, emissiveR, emissiveG, emissiveB)
    materialCache[key] = mat
    return mat
end

-- 创建发光材质（带缓存）
function Materials.CreateGlow(r, g, b, intensity)
    intensity = intensity or 2.0
    local key = MakeCacheKey("glow", r, g, b, intensity)
    if materialCache[key] then
        cacheHits = cacheHits + 1
        return materialCache[key]
    end
    cacheMisses = cacheMisses + 1
    local mat = CreatePBRInternal(r, g, b, 0.0, 0.3, r * intensity, g * intensity, b * intensity)
    materialCache[key] = mat
    return mat
end

-- 创建纯发光材质（带缓存）
function Materials.CreateEmissive(r, g, b, intensity)
    intensity = intensity or 2.0
    local key = MakeCacheKey("emissive", r, g, b, intensity)
    if materialCache[key] then
        cacheHits = cacheHits + 1
        return materialCache[key]
    end
    cacheMisses = cacheMisses + 1
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(r * 0.5, g * 0.5, b * 0.5, 1.0)))
    mat:SetShaderParameter("MatSpecColor", Variant(Color(0.2, 0.2, 0.2, 1.0)))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(0.5))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(r * intensity, g * intensity, b * intensity)))
    materialCache[key] = mat
    return mat
end

-- 创建金属材质（带缓存）
function Materials.CreateMetal(r, g, b)
    return Materials.CreatePBR(r, g, b, 0.9, 0.2)
end

-- 创建磨砂材质（带缓存）
function Materials.CreateMatte(r, g, b)
    return Materials.CreatePBR(r, g, b, 0.1, 0.8)
end

-- ============================================================================
-- 预设材质（带缓存）
-- ============================================================================

-- 获取缓存的材质
function Materials.GetCached(key, createFunc)
    if not materialCache[key] then
        materialCache[key] = createFunc()
    end
    return materialCache[key]
end

-- 预设：星星材质
function Materials.Star(r, g, b, brightness)
    local key = string.format("star_%d_%d_%d_%d", 
        math.floor(r * 100), math.floor(g * 100), math.floor(b * 100), 
        math.floor((brightness or 1) * 100))
    return Materials.GetCached(key, function()
        return Materials.CreateGlow(r, g, b, 2.5 * (brightness or 1))
    end)
end

-- 预设：护盾材质
function Materials.Shield(alpha)
    alpha = alpha or 0.5
    local key = string.format("shield_%d", math.floor(alpha * 100))
    return Materials.GetCached(key, function()
        local mat = Materials.CreateGlow(0.3, 0.6, 1.0, 2.0)
        mat:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.6, 1.0, alpha)))
        return mat
    end)
end

-- 预设：引擎光芒
function Materials.EngineGlow(r, g, b)
    return Materials.CreateGlow(r or 0.3, g or 0.6, b or 1.0, 3.0)
end

-- 预设：导弹尾焰（半透明发光）
function Materials.MissileTrail(r, g, b, alpha, intensity)
    alpha = alpha or 0.6
    intensity = intensity or 3.0
    local key = string.format("missile_trail_%.2f_%.2f_%.2f_%d_%d", 
        r, g, b, math.floor(alpha * 100), math.floor(intensity * 10))
    return Materials.GetCached(key, function()
        local mat = Materials.CreateGlow(r, g, b, intensity)
        mat:SetShaderParameter("MatDiffColor", Variant(Color(r, g, b, alpha)))
        return mat
    end)
end

-- 预设：武器颜色（带缓存）
function Materials.Weapon(weaponColor, intensity)
    intensity = intensity or 2.5
    return Materials.CreateGlow(
        weaponColor.r, weaponColor.g, weaponColor.b, 
        intensity
    )
end

-- 预设：敌人身体（带缓存）
function Materials.EnemyBody(bodyColor)
    return Materials.CreatePBR(
        bodyColor.r, bodyColor.g, bodyColor.b,
        0.3, 0.6
    )
end

-- 预设：敌人发光部位（带缓存）
function Materials.EnemyGlow(glowColor)
    return Materials.CreateGlow(
        glowColor.r, glowColor.g, glowColor.b,
        2.0
    )
end

-- 预设：爆炸（带缓存，alpha量化）
-- 注意：alpha被量化到0.05精度，平衡缓存效率和视觉质量
function Materials.Explosion(color, alpha)
    alpha = alpha or 1.0
    -- 量化alpha到0.05精度（20级渐变，视觉平滑）
    local qAlpha = math.floor(alpha * 20 + 0.5) / 20
    qAlpha = math.max(0.05, qAlpha)  -- 最小0.05
    return Materials.CreateGlow(
        color.r * qAlpha, 
        color.g * qAlpha, 
        color.b * qAlpha, 
        3.0 * qAlpha
    )
end

-- 预设：爆炸透明材质（真正的透明度渐变）
function Materials.ExplosionAlpha(r, g, b, alpha, intensity)
    alpha = alpha or 1.0
    intensity = intensity or 3.0
    -- 量化 alpha 到 0.05 精度（20 级渐变，更平滑）
    local qAlpha = math.floor(alpha * 20 + 0.5) / 20
    qAlpha = math.max(0.0, qAlpha)  -- 允许完全透明（移除最小值限制）
    local key = string.format("explosion_alpha_%.2f_%.2f_%.2f_%d_%d", 
        r, g, b, math.floor(qAlpha * 20), math.floor(intensity * 10))
    return Materials.GetCached(key, function()
        local mat = Materials.CreateGlow(r, g, b, intensity)
        mat:SetShaderParameter("MatDiffColor", Variant(Color(r, g, b, qAlpha)))
        return mat
    end)
end

-- 预设：拾取物（带缓存）
-- 使用预缓存的材质
local pickupMaterials = {}
function Materials.Pickup(pickupType)
    if pickupMaterials[pickupType] then
        return pickupMaterials[pickupType]
    end
    
    local mat
    if pickupType == "crystal" then
        mat = Materials.CreateGlow(0.3, 0.5, 1.0, 2.0)
    elseif pickupType == "health" then
        mat = Materials.CreateGlow(1.0, 0.3, 0.3, 2.0)
    else
        mat = Materials.CreateGlow(1.0, 1.0, 1.0, 1.5)
    end
    pickupMaterials[pickupType] = mat
    return mat
end

-- 预设：晶体拾取物（带缓存）
-- 只有4种等级的材质
local crystalMaterials = {}
function Materials.CrystalByAmount(amount)
    amount = amount or 1
    
    -- 分级（只有4种材质）
    local tier
    if amount >= 10 then
        tier = 4
    elseif amount >= 5 then
        tier = 3
    elseif amount >= 2 then
        tier = 2
    else
        tier = 1
    end
    
    if crystalMaterials[tier] then
        return crystalMaterials[tier]
    end
    
    local mat
    if tier == 4 then
        mat = Materials.CreateGlow(1.0, 0.85, 0.2, 4.0)
    elseif tier == 3 then
        mat = Materials.CreateGlow(0.4, 0.7, 1.0, 3.0)
    elseif tier == 2 then
        mat = Materials.CreateGlow(0.3, 0.6, 1.0, 2.5)
    else
        mat = Materials.CreateGlow(0.3, 0.5, 1.0, 2.5)  -- T1: 2.0 → 2.5
    end
    crystalMaterials[tier] = mat
    return mat
end

-- 预设：跃迁漩涡（带缓存）
local warpVortexMat = nil
function Materials.WarpVortex()
    if not warpVortexMat then
        warpVortexMat = Materials.CreateGlow(0.5, 0.2, 0.8, 2.0)
    end
    return warpVortexMat
end

-- ============================================================================
-- 战舰材质
-- ============================================================================

-- 舰体材质
function Materials.ShipHull(hullColor)
    return Materials.CreatePBR(
        hullColor.r, hullColor.g, hullColor.b,
        0.7, 0.3
    )
end

-- 舰体高光部分
function Materials.ShipAccent(accentColor)
    return Materials.CreateGlow(
        accentColor.r, accentColor.g, accentColor.b,
        1.5
    )
end

-- 引擎材质
function Materials.ShipEngine(engineColor)
    return Materials.CreateGlow(
        engineColor.r, engineColor.g, engineColor.b,
        3.0
    )
end

-- 炮塔基座（固定颜色，兼容旧代码）
function Materials.TurretBase()
    return Materials.CreatePBR(0.4, 0.4, 0.45, 0.8, 0.3)
end

-- 炮塔基座（按品质等级着色）
-- tier: 1=灰色, 2=绿色, 3=蓝色, 4=紫色
-- 使用低调的 PBR 材质，颜色作为简单引导，不喧宾夺主
function Materials.TurretBaseByTier(tier)
    -- 品质颜色（更鲜明的颜色，便于区分）
    local tierColors = {
        {r = 0.50, g = 0.50, b = 0.55},  -- T1 灰色
        {r = 0.30, g = 0.65, b = 0.30},  -- T2 绿色
        {r = 0.30, g = 0.45, b = 0.75},  -- T3 蓝色
        {r = 0.65, g = 0.30, b = 0.70},  -- T4 紫色
    }
    
    tier = math.max(1, math.min(4, tier or 1))
    local color = tierColors[tier]
    
    -- 使用 PBR 材质，金属感强
    return Materials.CreatePBR(color.r, color.g, color.b, 0.7, 0.35)
end

-- 武器炮管（默认状态，不发光，与炮塔基座颜色一致）
function Materials.WeaponBarrel()
    -- 使用与炮塔基座相同的灰色金属材质
    return Materials.CreatePBR(0.4, 0.4, 0.45, 0.8, 0.3)
end

-- 武器炮管（射击闪光状态，发光）
function Materials.WeaponBarrelGlow(weaponColor)
    return Materials.CreateGlow(
        weaponColor.r, weaponColor.g, weaponColor.b,
        3.0  -- 高亮度
    )
end

-- ============================================================================
-- 清理
-- ============================================================================

function Materials.ClearCache()
    -- 🔧 清理所有材质缓存
    materialCache = {}
    pickupMaterials = {}
    crystalMaterials = {}
    warpVortexMat = nil
    
    -- 重置统计
    cacheHits = 0
    cacheMisses = 0
end

return Materials
