-- ============================================================================
-- 星河战姬 Starkyries - 敌人视觉特效模块
-- ============================================================================
-- 
-- 职责：管理敌人的视觉特效
-- 
-- 功能：
--   - 引擎火焰：UpdateFlame (移动时显示推进器火焰)
--   - 受击闪白：TriggerHitFlash / RestoreOriginalMaterials
--   - 蓄力闪红：UpdateChargeFlash (自爆虫蓄力时闪烁)
-- 
-- 用法：
--   EnemyVisualEffects.UpdateFlame(enemy, dt)
--   EnemyVisualEffects.TriggerHitFlash(enemy)
--   EnemyVisualEffects.UpdateChargeFlash(enemy, dt)
-- 
-- ============================================================================

local Settings = nil
local Materials = nil

-- 延迟加载依赖
local function LoadDependencies()
    if not Settings then
        Settings = require("config.settings")
        Materials = require("render.Materials")
    end
end

local EnemyVisualEffects = {}

-- ============================================================================
-- 材质缓存
-- ============================================================================

local hitFlashMaterial = nil
local chargeFlashMaterial = nil

local function GetHitFlashMaterial()
    LoadDependencies()
    if not hitFlashMaterial then
        hitFlashMaterial = Materials.CreateGlow(1.0, 1.0, 1.0, 1.2)
    end
    return hitFlashMaterial
end

local function GetChargeFlashMaterial()
    LoadDependencies()
    if not chargeFlashMaterial then
        chargeFlashMaterial = Materials.CreateGlow(1.0, 0.1, 0.1, 5.0)  -- 红色高亮
    end
    return chargeFlashMaterial
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

-- 递归收集节点下所有 StaticModel
local function CollectModels(node, models)
    models = models or {}
    local model = node:GetComponent("StaticModel")
    if model then
        table.insert(models, {node = node, model = model})
    end
    local numChildren = node:GetNumChildren(false)
    for i = 0, numChildren - 1 do
        CollectModels(node:GetChild(i), models)
    end
    return models
end

-- ============================================================================
-- 引擎火焰
-- ============================================================================

--- 更新敌人引擎火焰
---@param enemy table 敌人对象
---@param dt number 时间增量
function EnemyVisualEffects.UpdateFlame(enemy, dt)
    LoadDependencies()
    
    local targetIntensity = enemy.isMoving and 1.0 or 0.0
    local fadeSpeed = Settings.Visual.FlameFadeSpeed
    
    if enemy.flameIntensity ~= targetIntensity then
        if targetIntensity > enemy.flameIntensity then
            enemy.flameIntensity = math.min(1.0, enemy.flameIntensity + fadeSpeed * 2 * dt)
        else
            enemy.flameIntensity = math.max(0.0, enemy.flameIntensity - fadeSpeed * dt)
        end
        
        -- 更新火焰视觉
        local intensity = enemy.flameIntensity
        local visible = intensity > 0.01
        
        for _, flameData in ipairs(enemy.flameNodes or {}) do
            if flameData.node then
                flameData.node:SetEnabled(visible)
                if visible then
                    local baseScale = flameData.baseScale
                    flameData.node:SetScale(Vector3(
                        baseScale.x * intensity,
                        baseScale.y * intensity,
                        baseScale.z * intensity
                    ))
                end
            end
        end
    end
end

-- ============================================================================
-- 受击闪白
-- ============================================================================

--- 触发受击闪白效果
---@param enemy table 敌人对象
function EnemyVisualEffects.TriggerHitFlash(enemy)
    LoadDependencies()
    
    -- 冷却检查：如果还在冷却中，跳过本次闪烁
    local cooldown = Settings.Visual.HitFlashCooldown or 0.15
    if enemy.hitFlashCooldown and enemy.hitFlashCooldown > 0 then
        return  -- 跳过闪烁，防止高频攻击时一直白色
    end
    
    enemy.hitFlashTimer = Settings.Visual.HitFlashDuration  -- 闪白持续时间
    enemy.hitFlashCooldown = cooldown  -- 设置冷却时间
    
    local targetNode = enemy.hull or enemy.node
    
    -- 如果还没保存原始材质，先保存（使用独立的 hitFlashMaterials）
    if not enemy.hitFlashMaterials then
        enemy.hitFlashMaterials = {}
        local models = CollectModels(targetNode)
        for _, item in ipairs(models) do
            enemy.hitFlashMaterials[item.node.name] = item.model:GetMaterial(0)
        end
    end
    
    -- 应用闪白材质
    local flashMat = GetHitFlashMaterial()
    local models = CollectModels(targetNode)
    for _, item in ipairs(models) do
        item.model:SetMaterial(flashMat)
    end
end

--- 恢复原始材质（受击闪白结束时调用）
---@param enemy table 敌人对象
function EnemyVisualEffects.RestoreOriginalMaterials(enemy)
    if not enemy.hitFlashMaterials then return end
    
    local targetNode = enemy.hull or enemy.node
    local models = CollectModels(targetNode)
    for _, item in ipairs(models) do
        if enemy.hitFlashMaterials[item.node.name] then
            item.model:SetMaterial(enemy.hitFlashMaterials[item.node.name])
        end
    end
end

-- ============================================================================
-- 蓄力闪红（自爆虫专用）
-- ============================================================================

--- 更新蓄力闪红效果
---@param enemy table 敌人对象
---@param dt number 时间增量
function EnemyVisualEffects.UpdateChargeFlash(enemy, dt)
    -- 只有自爆虫才需要处理蓄力闪红
    if not enemy.isSuicide then return end
    
    if not enemy.isCharging then
        -- 如果有缓存的原始材质，恢复它们
        if enemy.chargeFlashMaterials then
            local hull = enemy.node:GetChild("Hull")
            if hull then
                local numChildren = hull:GetNumChildren()
                for i = 0, numChildren - 1 do
                    local child = hull:GetChild(i)
                    local model = child:GetComponent("StaticModel")
                    if model and enemy.chargeFlashMaterials[i] then
                        model:SetMaterial(enemy.chargeFlashMaterials[i])
                    end
                end
            end
            enemy.chargeFlashMaterials = nil
        end
        return
    end
    
    -- 闪烁效果：根据蓄力进度快速闪烁
    local flashRate = 8 + enemy.chargeProgress * 12  -- 越接近完成闪得越快
    local flashOn = math.sin(enemy.chargeTimer * flashRate * math.pi * 2) > 0
    
    local hull = enemy.node:GetChild("Hull")
    if not hull then return end
    
    -- 缓存原始材质（蓄力闪红专用）
    if not enemy.chargeFlashMaterials then
        enemy.chargeFlashMaterials = {}
        local numChildren = hull:GetNumChildren()
        for i = 0, numChildren - 1 do
            local child = hull:GetChild(i)
            local model = child:GetComponent("StaticModel")
            if model then
                enemy.chargeFlashMaterials[i] = model:GetMaterial()
            end
        end
    end
    
    -- 应用闪红或恢复原始材质
    local numChildren = hull:GetNumChildren()
    for i = 0, numChildren - 1 do
        local child = hull:GetChild(i)
        local model = child:GetComponent("StaticModel")
        if model then
            if flashOn then
                model:SetMaterial(GetChargeFlashMaterial())
            elseif enemy.chargeFlashMaterials[i] then
                model:SetMaterial(enemy.chargeFlashMaterials[i])
            end
        end
    end
end

return EnemyVisualEffects
