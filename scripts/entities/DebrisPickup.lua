-- ============================================================================
-- 星河战姬 Starkyries - 残骸掉落物系统
-- 护盾电池 & 补给箱（与普通晶体分开管理）
-- ============================================================================

local Settings = require("config.settings")
local Materials = require("render.Materials")
local Math = require("utils.Math")
local EventBus = require("utils.EventBus")

local DebrisPickup = {}

-- 护盾电池列表
local shieldBatteries = {}

-- 补给箱列表
local supplyCrates = {}

-- 已收集的补给箱（波次结束时处理）
local collectedCrates = {}

-- 配置
DebrisPickup.Config = {
    -- 护盾电池
    BatteryCollectRadius = 1.5,   -- 拾取半径
    BatteryMagnetRadius = 3.0,    -- 磁吸半径
    BatteryShieldRestore = 8,     -- 护盾恢复量
    
    -- 补给箱
    CrateCollectRadius = 2.0,  -- 拾取半径
}

-- 回调
DebrisPickup.onCollectBattery = nil  -- function(battery) 收集护盾电池
DebrisPickup.onCollectCrate = nil    -- function(crate) 收集补给箱
DebrisPickup.onShieldRestore = nil   -- function(amount) 护盾恢复

-- ============================================================================
-- 护盾电池3D模型 - 科幻风格能量电池
-- 设计理念：六角棱柱主体 + 发光能量环 + 护盾符号
-- ============================================================================

local function CreateShieldBatteryModel(node)
    -- 主体：六角棱柱电池壳（使用圆柱近似，稍扁）
    local body = node:CreateChild("Body")
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    body:SetScale(Vector3(0.35, 0.5, 0.35))
    -- 深蓝色金属外壳
    bodyModel:SetMaterial(Materials.CreatePBR(0.15, 0.25, 0.4, 0.8, 0.3))
    
    -- 顶部电极（金色）
    local topCap = node:CreateChild("TopCap")
    local topCapModel = topCap:CreateComponent("StaticModel")
    topCapModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    topCap:SetScale(Vector3(0.2, 0.08, 0.2))
    topCap.position = Vector3(0, 0.28, 0)
    topCapModel:SetMaterial(Materials.CreatePBR(0.85, 0.7, 0.25, 0.9, 0.2))
    
    -- 底部电极（金色）
    local bottomCap = node:CreateChild("BottomCap")
    local bottomCapModel = bottomCap:CreateComponent("StaticModel")
    bottomCapModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    bottomCap:SetScale(Vector3(0.2, 0.08, 0.2))
    bottomCap.position = Vector3(0, -0.28, 0)
    bottomCapModel:SetMaterial(Materials.CreatePBR(0.85, 0.7, 0.25, 0.9, 0.2))
    
    -- 中央能量环（青色发光）- 护盾能量指示
    local energyRing = node:CreateChild("EnergyRing")
    local energyRingModel = energyRing:CreateComponent("StaticModel")
    energyRingModel:SetModel(cache:GetResource("Model", "Models/Torus.mdl"))
    energyRing:SetScale(Vector3(0.4, 0.4, 0.12))
    energyRing.position = Vector3(0, 0, 0)
    -- 青色发光（护盾色）
    energyRingModel:SetMaterial(Materials.CreateGlow(0.2, 0.9, 1.0, 3.0))
    
    -- 上部能量条（发光）
    local upperGlow = node:CreateChild("UpperGlow")
    local upperGlowModel = upperGlow:CreateComponent("StaticModel")
    upperGlowModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    upperGlow:SetScale(Vector3(0.28, 0.12, 0.28))
    upperGlow.position = Vector3(0, 0.15, 0)
    upperGlowModel:SetMaterial(Materials.CreateGlow(0.3, 0.8, 1.0, 2.0))
    
    -- 下部能量条（发光）
    local lowerGlow = node:CreateChild("LowerGlow")
    local lowerGlowModel = lowerGlow:CreateComponent("StaticModel")
    lowerGlowModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    lowerGlow:SetScale(Vector3(0.28, 0.12, 0.28))
    lowerGlow.position = Vector3(0, -0.15, 0)
    lowerGlowModel:SetMaterial(Materials.CreateGlow(0.3, 0.8, 1.0, 2.0))
    
    -- 护盾符号球（中心发光点，表示护盾能量）
    local shieldCore = node:CreateChild("ShieldCore")
    local shieldCoreModel = shieldCore:CreateComponent("StaticModel")
    shieldCoreModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    shieldCore:SetScale(0.12)
    shieldCore.position = Vector3(0, 0, 0.2)
    shieldCoreModel:SetMaterial(Materials.CreateEmissive(0.5, 1.0, 1.0, 4.0))
    
    return {
        body = body,
        topCap = topCap,
        bottomCap = bottomCap,
        energyRing = energyRing,
        upperGlow = upperGlow,
        lowerGlow = lowerGlow,
        shieldCore = shieldCore
    }
end

-- ============================================================================
-- 补给箱3D模型
-- ============================================================================

local function CreateSupplyCrateModel(node, tier)
    tier = tier or 1
    
    -- 颜色根据内容等级
    local colors = {
        {r = 0.6, g = 0.6, b = 0.6},   -- T1 灰色
        {r = 0.3, g = 0.7, b = 0.3},   -- T2 绿色
        {r = 0.3, g = 0.5, b = 0.9},   -- T3 蓝色
        {r = 0.7, g = 0.3, b = 0.8},   -- T4 紫色
    }
    local color = colors[math.min(tier, 4)]
    
    -- 主箱体
    local box = node:CreateChild("Box")
    local boxModel = box:CreateComponent("StaticModel")
    boxModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    box:SetScale(Vector3(0.6, 0.5, 0.5))
    boxModel:SetMaterial(Materials.CreatePBR(color.r * 0.7, color.g * 0.7, color.b * 0.7, 0.6, 0.4))
    
    -- 发光边框
    local frame = node:CreateChild("Frame")
    local frameModel = frame:CreateComponent("StaticModel")
    frameModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    frame:SetScale(Vector3(0.65, 0.08, 0.55))
    frame.position = Vector3(0, 0.22, 0)
    frameModel:SetMaterial(Materials.CreateGlow(color.r, color.g, color.b, 2.0))
    
    -- 锁扣
    local lock = node:CreateChild("Lock")
    local lockModel = lock:CreateComponent("StaticModel")
    lockModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    lock:SetScale(Vector3(0.12, 0.15, 0.08))
    lock.position = Vector3(0.25, 0, 0.27)
    lockModel:SetMaterial(Materials.CreatePBR(0.8, 0.7, 0.2, 0.8, 0.3))
    
    -- 问号标记（表示随机内容）
    local mark = node:CreateChild("Mark")
    local markModel = mark:CreateComponent("StaticModel")
    markModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    mark:SetScale(0.1)
    mark.position = Vector3(0, 0.35, 0)
    markModel:SetMaterial(Materials.CreateGlow(1.0, 0.9, 0.3, 2.5))
    
    return {box = box, frame = frame, lock = lock, mark = mark}
end

-- ============================================================================
-- 创建护盾电池
-- ============================================================================

function DebrisPickup.CreateShieldBattery(scene, x, y)
    local node = scene:CreateChild("ShieldBattery")
    node.position = Vector3(x, y, 0)
    
    local parts = CreateShieldBatteryModel(node)
    
    local battery = {
        node = node,
        parts = parts,
        x = x,
        y = y,
        bobPhase = math.random() * math.pi * 2,
        rotationPhase = math.random() * math.pi * 2,
        pulsePhase = math.random() * math.pi * 2,  -- 能量脉冲动画
        lifetime = 999,  -- 永久存在直到波次结束
    }
    
    table.insert(shieldBatteries, battery)
    return battery
end

-- ============================================================================
-- 创建补给箱
-- ============================================================================

function DebrisPickup.CreateSupplyCrate(scene, x, y, crateData)
    local node = scene:CreateChild("SupplyCrate")
    node.position = Vector3(x, y, 0)
    
    -- 根据内容等级确定外观
    local tier = 1
    if crateData and crateData.type == "item" then
        tier = crateData.tier or 1
    end
    
    local parts = CreateSupplyCrateModel(node, tier)
    
    local crate = {
        node = node,
        parts = parts,
        x = x,
        y = y,
        data = crateData,  -- 内容数据（预决定）
        bobPhase = math.random() * math.pi * 2,
        lifetime = 999,
    }
    
    table.insert(supplyCrates, crate)
    return crate
end

-- ============================================================================
-- 更新
-- ============================================================================

function DebrisPickup.UpdateAll(dt, playerX, playerY, shieldRegenMult, moduleEffects)
    shieldRegenMult = shieldRegenMult or 1.0
    moduleEffects = moduleEffects or {}
    
    -- 更新护盾电池
    for i = #shieldBatteries, 1, -1 do
        local battery = shieldBatteries[i]
        
        -- 浮动动画
        battery.bobPhase = battery.bobPhase + dt * 2.5
        local bobY = math.sin(battery.bobPhase) * 0.2
        
        -- 旋转能量环
        battery.rotationPhase = battery.rotationPhase + dt * 2
        if battery.parts.energyRing then
            battery.parts.energyRing.rotation = Quaternion(0, battery.rotationPhase * 60, 0)
        end
        
        -- 能量脉冲动画（中心发光点明暗变化）
        battery.pulsePhase = battery.pulsePhase + dt * 4
        local pulseScale = 0.1 + 0.04 * math.sin(battery.pulsePhase)
        if battery.parts.shieldCore then
            battery.parts.shieldCore:SetScale(pulseScale)
        end
        
        -- 磁吸
        local dist = Math.Distance(battery.x, battery.y, playerX, playerY)
        
        -- 磁力牵引模块：护盾电池自动飞向玩家
        if moduleEffects.hasMagneticPull then
            local pullSpeed = 8
            local dx, dy = Math.Normalize(playerX - battery.x, playerY - battery.y)
            battery.x = battery.x + dx * pullSpeed * dt
            battery.y = battery.y + dy * pullSpeed * dt
        elseif dist < DebrisPickup.Config.BatteryMagnetRadius then
            local pullStrength = (DebrisPickup.Config.BatteryMagnetRadius - dist) / DebrisPickup.Config.BatteryMagnetRadius * 6
            local dx, dy = Math.Normalize(playerX - battery.x, playerY - battery.y)
            battery.x = battery.x + dx * pullStrength * dt
            battery.y = battery.y + dy * pullStrength * dt
        end
        
        battery.node.position = Vector3(battery.x, battery.y + bobY, 0)
        
        -- 收集判定
        if dist < DebrisPickup.Config.BatteryCollectRadius then
            -- 护盾恢复（受护盾回复属性加成）
            local shieldAmount = DebrisPickup.Config.BatteryShieldRestore * shieldRegenMult
            if DebrisPickup.onShieldRestore then
                DebrisPickup.onShieldRestore(shieldAmount)
            end
            
            -- 回调
            if DebrisPickup.onCollectBattery then
                DebrisPickup.onCollectBattery(battery)
            end
            
            -- 移除
            battery.node:Remove()
            table.remove(shieldBatteries, i)
        end
    end
    
    -- 更新补给箱
    for i = #supplyCrates, 1, -1 do
        local crate = supplyCrates[i]
        
        -- 浮动动画
        crate.bobPhase = crate.bobPhase + dt * 1.8
        local bobY = math.sin(crate.bobPhase) * 0.15
        
        -- 缓慢旋转
        local currentRot = crate.node.rotation
        crate.node.rotation = currentRot * Quaternion(0, dt * 30, 0)
        
        crate.node.position = Vector3(crate.x, crate.y + bobY, 0)
        
        -- 收集判定
        local dist = Math.Distance(crate.x, crate.y, playerX, playerY)
        if dist < DebrisPickup.Config.CrateCollectRadius then
            -- 存入已收集列表（波次结束时处理）
            print(string.format("[DebrisPickup] 收集补给箱! data=%s, type=%s", 
                tostring(crate.data), crate.data and crate.data.type or "nil"))
            table.insert(collectedCrates, crate.data)
            print(string.format("[DebrisPickup] collectedCrates count: %d", #collectedCrates))
            
            -- 回调
            if DebrisPickup.onCollectCrate then
                DebrisPickup.onCollectCrate(crate)
            end
            
            -- 移除
            crate.node:Remove()
            table.remove(supplyCrates, i)
        end
    end
end

-- ============================================================================
-- 已收集补给箱管理
-- ============================================================================

-- 获取已收集的补给箱列表
function DebrisPickup.GetCollectedCrates()
    print(string.format("[DebrisPickup] GetCollectedCrates called, count: %d", #collectedCrates))
    for i, crate in ipairs(collectedCrates) do
        print(string.format("[DebrisPickup]   [%d] type=%s", i, crate and crate.type or "nil"))
    end
    return collectedCrates
end

-- 清空已收集的补给箱（开箱完成后调用）
function DebrisPickup.ClearCollectedCrates()
    collectedCrates = {}
end

-- 有未开启的补给箱？
function DebrisPickup.HasPendingCrates()
    print(string.format("[DebrisPickup] HasPendingCrates called, count: %d", #collectedCrates))
    return #collectedCrates > 0
end

-- ============================================================================
-- 获取
-- ============================================================================

function DebrisPickup.GetShieldBatteryCount()
    return #shieldBatteries
end

function DebrisPickup.GetSupplyCrateCount()
    return #supplyCrates
end

-- ============================================================================
-- 清理
-- ============================================================================

function DebrisPickup.ClearAll()
    for _, battery in ipairs(shieldBatteries) do
        if battery.node then battery.node:Remove() end
    end
    shieldBatteries = {}
    
    for _, crate in ipairs(supplyCrates) do
        if crate.node then crate.node:Remove() end
    end
    supplyCrates = {}
end

-- 波次结束清理（未拾取的消失）
function DebrisPickup.ClearUncollected()
    print(string.format("[DebrisPickup] ClearUncollected called. collectedCrates count before: %d", #collectedCrates))
    for _, battery in ipairs(shieldBatteries) do
        if battery.node then battery.node:Remove() end
    end
    shieldBatteries = {}
    
    for _, crate in ipairs(supplyCrates) do
        if crate.node then crate.node:Remove() end
    end
    supplyCrates = {}
    print(string.format("[DebrisPickup] ClearUncollected done. collectedCrates count after: %d", #collectedCrates))
end

-- 隐藏所有（超空间跳跃时）
function DebrisPickup.HideAll()
    for _, battery in ipairs(shieldBatteries) do
        if battery.node then battery.node:SetEnabled(false) end
    end
    for _, crate in ipairs(supplyCrates) do
        if crate.node then crate.node:SetEnabled(false) end
    end
end

-- 显示所有
function DebrisPickup.ShowAll()
    for _, battery in ipairs(shieldBatteries) do
        if battery.node then battery.node:SetEnabled(true) end
    end
    for _, crate in ipairs(supplyCrates) do
        if crate.node then crate.node:SetEnabled(true) end
    end
end

return DebrisPickup
