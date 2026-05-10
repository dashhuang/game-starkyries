-- ============================================================================
-- 星河战姬 Starkyries - 敌人模型工厂
-- 统一管理所有敌人的可视化创建
-- ============================================================================

local Materials = require("render.Materials")

local EnemyModels = {}

-- 延迟加载各敌人模型模块
local modelCreators = {}

local function GetModelCreator(enemyType)
    if not modelCreators[enemyType] then
        local success, creator = pcall(require, "entities.EnemyModels." .. enemyType)
        if success then
            modelCreators[enemyType] = creator
        else
            modelCreators[enemyType] = false  -- 标记为不存在
        end
    end
    return modelCreators[enemyType]
end

-- ============================================================================
-- 通用材质创建（供各模型模块使用）
-- ============================================================================

function EnemyModels.CreateMaterials(def)
    local bc = def.bodyColor
    local gc = def.glowColor
    
    return {
        body = Materials.EnemyBody(bc),
        dark = Materials.CreatePBR(bc.r * 0.5, bc.g * 0.5, bc.b * 0.5, 0.8, 0.3),
        glow = Materials.EnemyGlow(gc),
        engine = Materials.CreateEmissive(gc.r, gc.g, gc.b, 2.0),
    }
end

-- ============================================================================
-- 创建敌人模型
-- @param hull 船体节点（用于添加模型组件）
-- @param def 敌人配置定义
-- @param materials 预创建的材质表
-- @return flameNodes 火焰节点列表（用于引擎动画）
-- ============================================================================

function EnemyModels.Create(hull, enemyType, def, materials)
    local s = def.scale
    local flameNodes = {}
    
    -- 尝试获取专用模型创建器
    local creator = GetModelCreator(enemyType)
    
    if creator and creator.Create then
        -- 使用专用模型创建器
        flameNodes = creator.Create(hull, def, materials) or {}
    else
        -- 默认外观（未定义类型）
        flameNodes = EnemyModels.CreateDefault(hull, def, materials)
    end
    
    return flameNodes
end

-- ============================================================================
-- 默认敌人外观
-- ============================================================================

function EnemyModels.CreateDefault(hull, def, materials)
    local s = def.scale  -- s 现在直接是视觉大小
    local flameNodes = {}
    
    local body = hull:CreateChild("Body")
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    body:SetScale(Vector3(s * 1.0, s * 0.63, s * 0.5))  -- 基准长度 1.0
    bodyModel:SetMaterial(materials.body)
    
    local glow = hull:CreateChild("Glow")
    glow.position = Vector3(s * 0.38, 0, 0)
    local glowModel = glow:CreateComponent("StaticModel")
    glowModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    glow:SetScale(s * 0.25)
    glowModel:SetMaterial(materials.glow)
    
    return flameNodes
end

return EnemyModels
