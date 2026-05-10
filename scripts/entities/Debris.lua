-- ============================================================================
-- 星河战姬 Starkyries - 漂浮残骸系统
-- 对标 Brotato 的 "Trees" 机制
-- ============================================================================

local Settings = require("config.settings")
local Materials = require("render.Materials")
local Math = require("utils.Math")
local EventBus = require("utils.EventBus")

local Debris = {}

-- 残骸列表
local debrisList = {}

-- 配置
Debris.Config = {
    BaseHP = 10,              -- 基础耐久
    HPPerWave = 5,            -- 每波增加
    SpawnInterval = 10,       -- 每10秒生成一次
    -- Brotato 公式: quantity = 0.50 + 0.33 × tree-item-count
    BaseSpawnRate = 0.50,     -- 基础生成率（无道具时）
    SpawnRatePerItem = 0.33,  -- 每个残骸道具增加的生成率
    MinPlayerDistance = 5,    -- 距玩家最小距离
    MinDebrisDistance = 3,    -- 残骸间最小距离
    -- 掉落配置
    ShieldBatteryDrop = 0.80, -- 护盾电池掉落率 (80%)
    SupplyCrateDrop = 0.20,   -- 补给箱掉落率 (20%)
    -- 晶体直接掉落配置
    BaseCrystalDrop = 3,      -- 基础晶体掉落
    CrystalPerWave = 1,       -- 每波增加晶体
}

-- 生成累积器（用于处理小数生成率）
local spawnAccumulator = 0

-- 回调
Debris.onDestroy = nil           -- function(debris) 残骸被摧毁
Debris.onDropShieldBattery = nil -- function(x, y) 掉落护盾电池
Debris.onDropSupplyCrate = nil   -- function(x, y, crateData) 掉落补给箱
Debris.onDropCrystals = nil      -- function(x, y, amount) 掉落晶体
Debris.getPlayerPosition = nil   -- function() return x, y
Debris.getDebrisItemCount = nil  -- function() return count 获取残骸相关道具数量

-- ============================================================================
-- 残骸3D模型创建（太空站风格，宽2 x 高3）
-- ============================================================================

local function CreateDebrisModel(node, debrisType)
    local hull = node:CreateChild("Hull")
    
    -- 材质定义
    local whiteMat = Materials.CreatePBR(0.85, 0.85, 0.82, 0.6, 0.3)    -- 白色主体
    local grayMat = Materials.CreatePBR(0.5, 0.5, 0.48, 0.7, 0.4)      -- 灰色金属
    local darkMat = Materials.CreatePBR(0.2, 0.2, 0.22, 0.5, 0.6)      -- 深色部分
    local panelMat = Materials.CreatePBR(0.08, 0.12, 0.2, 0.2, 0.4)    -- 深蓝太阳能板
    local goldMat = Materials.CreatePBR(0.8, 0.6, 0.2, 0.8, 0.3)       -- 金色隔热层
    local redMat = Materials.CreatePBR(0.7, 0.15, 0.1, 0.5, 0.5)       -- 红色标记
    local orangeGlow = Materials.CreateGlow(1.0, 0.5, 0.1, 1.5)        -- 橙色警示灯
    local blueGlow = Materials.CreateGlow(0.3, 0.6, 1.0, 1.2)          -- 蓝色指示灯
    local greenGlow = Materials.CreateGlow(0.2, 1.0, 0.3, 1.0)         -- 绿色状态灯
    
    if debrisType == "wreck" then
        -- ========== 国际空间站风格残骸（宽2 x 高3）==========
        
        -- 主体圆柱模块（垂直放置）
        local mainModule = hull:CreateChild("MainModule")
        local mainModel = mainModule:CreateComponent("StaticModel")
        mainModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        mainModule:SetScale(Vector3(0.6, 2.2, 0.6))
        mainModule:SetRotation(Quaternion(0, 0, 8))
        mainModel:SetMaterial(whiteMat)
        
        -- 上部节点舱
        local nodeTop = hull:CreateChild("NodeTop")
        nodeTop.position = Vector3(0, 1.3, 0)
        local nodeTopModel = nodeTop:CreateComponent("StaticModel")
        nodeTopModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        nodeTop:SetScale(Vector3(0.7, 0.5, 0.7))
        nodeTopModel:SetMaterial(whiteMat)
        
        -- 下部对接口
        local dockBottom = hull:CreateChild("DockBottom")
        dockBottom.position = Vector3(0, -1.4, 0)
        local dockModel = dockBottom:CreateComponent("StaticModel")
        dockModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        dockBottom:SetScale(Vector3(0.4, 0.3, 0.4))
        dockModel:SetMaterial(grayMat)
        
        -- 左侧太阳能板支架
        local armL = hull:CreateChild("ArmL")
        armL.position = Vector3(-0.5, 0.3, 0)
        local armLModel = armL:CreateComponent("StaticModel")
        armLModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        armL:SetScale(Vector3(0.8, 0.08, 0.08))
        armL:SetRotation(Quaternion(0, 0, -5))
        armLModel:SetMaterial(grayMat)
        
        -- 左侧太阳能板
        local panelL = hull:CreateChild("PanelL")
        panelL.position = Vector3(-1.2, 0.4, 0)
        local panelLModel = panelL:CreateComponent("StaticModel")
        panelLModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        panelL:SetScale(Vector3(0.9, 1.8, 0.04))
        panelL:SetRotation(Quaternion(0, 0, -12))
        panelLModel:SetMaterial(panelMat)
        
        -- 右侧太阳能板（断裂）
        local panelR = hull:CreateChild("PanelR")
        panelR.position = Vector3(0.9, -0.2, 0)
        local panelRModel = panelR:CreateComponent("StaticModel")
        panelRModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        panelR:SetScale(Vector3(0.6, 1.2, 0.04))
        panelR:SetRotation(Quaternion(8, 15, 25))
        panelRModel:SetMaterial(panelMat)
        
        -- 散热器（金色）
        local radiator = hull:CreateChild("Radiator")
        radiator.position = Vector3(0.4, 0.8, 0.3)
        local radiatorModel = radiator:CreateComponent("StaticModel")
        radiatorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        radiator:SetScale(Vector3(0.5, 0.8, 0.03))
        radiator:SetRotation(Quaternion(-10, 20, 5))
        radiatorModel:SetMaterial(goldMat)
        
        -- 红色标记带
        local stripe = hull:CreateChild("Stripe")
        stripe.position = Vector3(0, 0.5, 0.32)
        local stripeModel = stripe:CreateComponent("StaticModel")
        stripeModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        stripe:SetScale(Vector3(0.3, 0.1, 0.02))
        stripeModel:SetMaterial(redMat)
        
        -- 警示灯
        local light1 = hull:CreateChild("Light1")
        light1.position = Vector3(0, 1.5, 0.3)
        local light1Model = light1:CreateComponent("StaticModel")
        light1Model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        light1:SetScale(0.12)
        light1Model:SetMaterial(orangeGlow)
        
        local light2 = hull:CreateChild("Light2")
        light2.position = Vector3(-0.35, -0.5, 0.3)
        local light2Model = light2:CreateComponent("StaticModel")
        light2Model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        light2:SetScale(0.08)
        light2Model:SetMaterial(blueGlow)
        
    elseif debrisType == "container" then
        -- ========== 货运飞船残骸（宽2 x 高3）==========
        
        -- 主货舱（大型方形）
        local cargo = hull:CreateChild("Cargo")
        cargo.position = Vector3(0, 0.3, 0)
        local cargoModel = cargo:CreateComponent("StaticModel")
        cargoModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        cargo:SetScale(Vector3(1.4, 1.6, 0.9))
        cargo:SetRotation(Quaternion(3, 0, 5))
        cargoModel:SetMaterial(whiteMat)
        
        -- 服务舱（底部圆柱）
        local service = hull:CreateChild("Service")
        service.position = Vector3(0, -1.0, 0)
        local serviceModel = service:CreateComponent("StaticModel")
        serviceModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        service:SetScale(Vector3(0.5, 0.6, 0.5))
        serviceModel:SetMaterial(grayMat)
        
        -- 对接环
        local dockRing = hull:CreateChild("DockRing")
        dockRing.position = Vector3(0, 1.2, 0)
        local dockRingModel = dockRing:CreateComponent("StaticModel")
        dockRingModel:SetModel(cache:GetResource("Model", "Models/Torus.mdl"))
        dockRing:SetScale(Vector3(0.35, 0.35, 0.1))
        dockRing:SetRotation(Quaternion(0, 0, 0))
        dockRingModel:SetMaterial(darkMat)
        
        -- 左太阳能板
        local panelL = hull:CreateChild("PanelL")
        panelL.position = Vector3(-1.1, 0.2, 0)
        local panelLModel = panelL:CreateComponent("StaticModel")
        panelLModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        panelL:SetScale(Vector3(0.7, 2.0, 0.04))
        panelL:SetRotation(Quaternion(5, 0, -8))
        panelLModel:SetMaterial(panelMat)
        
        -- 右太阳能板（部分损坏）
        local panelR = hull:CreateChild("PanelR")
        panelR.position = Vector3(1.0, 0.5, 0)
        local panelRModel = panelR:CreateComponent("StaticModel")
        panelRModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        panelR:SetScale(Vector3(0.7, 1.4, 0.04))
        panelR:SetRotation(Quaternion(-8, 10, 15))
        panelRModel:SetMaterial(panelMat)
        
        -- 推进器组
        local thruster1 = hull:CreateChild("Thruster1")
        thruster1.position = Vector3(-0.3, -1.4, 0)
        local thruster1Model = thruster1:CreateComponent("StaticModel")
        thruster1Model:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        thruster1:SetScale(Vector3(0.15, 0.2, 0.15))
        thruster1Model:SetMaterial(darkMat)
        
        local thruster2 = hull:CreateChild("Thruster2")
        thruster2.position = Vector3(0.3, -1.4, 0)
        local thruster2Model = thruster2:CreateComponent("StaticModel")
        thruster2Model:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        thruster2:SetScale(Vector3(0.15, 0.2, 0.15))
        thruster2Model:SetMaterial(darkMat)
        
        -- 货舱门（半开）
        local door = hull:CreateChild("Door")
        door.position = Vector3(0.6, 0.3, 0.5)
        local doorModel = door:CreateComponent("StaticModel")
        doorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        door:SetScale(Vector3(0.5, 0.7, 0.05))
        door:SetRotation(Quaternion(0, -40, 0))
        doorModel:SetMaterial(grayMat)
        
        -- 公司标志（金色方块）
        local logo = hull:CreateChild("Logo")
        logo.position = Vector3(-0.5, 0.6, 0.48)
        local logoModel = logo:CreateComponent("StaticModel")
        logoModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        logo:SetScale(Vector3(0.25, 0.25, 0.02))
        logoModel:SetMaterial(goldMat)
        
        -- 状态灯
        local light1 = hull:CreateChild("Light1")
        light1.position = Vector3(0, 1.3, 0.2)
        local light1Model = light1:CreateComponent("StaticModel")
        light1Model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        light1:SetScale(0.1)
        light1Model:SetMaterial(greenGlow)
        
        local light2 = hull:CreateChild("Light2")
        light2.position = Vector3(0.5, -0.5, 0.5)
        local light2Model = light2:CreateComponent("StaticModel")
        light2Model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        light2:SetScale(0.08)
        light2Model:SetMaterial(orangeGlow)
        
    else  -- "station" 
        -- ========== 科研空间站残骸（宽2 x 高3）==========
        
        -- 中央实验舱
        local labModule = hull:CreateChild("LabModule")
        local labModel = labModule:CreateComponent("StaticModel")
        labModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        labModule:SetScale(Vector3(0.55, 1.8, 0.55))
        labModule:SetRotation(Quaternion(5, 0, 3))
        labModel:SetMaterial(whiteMat)
        
        -- 观察窗圆顶
        local dome = hull:CreateChild("Dome")
        dome.position = Vector3(0, 1.1, 0.3)
        local domeModel = dome:CreateComponent("StaticModel")
        domeModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        dome:SetScale(Vector3(0.4, 0.25, 0.3))
        domeModel:SetMaterial(Materials.CreatePBR(0.2, 0.3, 0.4, 0.1, 0.2))
        
        -- 上部气闸舱
        local airlock = hull:CreateChild("Airlock")
        airlock.position = Vector3(0, 1.4, 0)
        local airlockModel = airlock:CreateComponent("StaticModel")
        airlockModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        airlock:SetScale(Vector3(0.3, 0.35, 0.3))
        airlockModel:SetMaterial(grayMat)
        
        -- 左侧大型太阳能板阵列
        local solarArmL = hull:CreateChild("SolarArmL")
        solarArmL.position = Vector3(-0.45, 0, 0)
        local solarArmLModel = solarArmL:CreateComponent("StaticModel")
        solarArmLModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        solarArmL:SetScale(Vector3(0.6, 0.06, 0.06))
        solarArmLModel:SetMaterial(grayMat)
        
        local panelL1 = hull:CreateChild("PanelL1")
        panelL1.position = Vector3(-1.0, 0.6, 0)
        local panelL1Model = panelL1:CreateComponent("StaticModel")
        panelL1Model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        panelL1:SetScale(Vector3(0.8, 1.3, 0.03))
        panelL1:SetRotation(Quaternion(0, 0, -5))
        panelL1Model:SetMaterial(panelMat)
        
        local panelL2 = hull:CreateChild("PanelL2")
        panelL2.position = Vector3(-1.0, -0.7, 0)
        local panelL2Model = panelL2:CreateComponent("StaticModel")
        panelL2Model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        panelL2:SetScale(Vector3(0.8, 1.0, 0.03))
        panelL2:SetRotation(Quaternion(5, 8, -10))
        panelL2Model:SetMaterial(panelMat)
        
        -- 右侧残破太阳能板
        local panelR = hull:CreateChild("PanelR")
        panelR.position = Vector3(0.85, 0.2, 0)
        local panelRModel = panelR:CreateComponent("StaticModel")
        panelRModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        panelR:SetScale(Vector3(0.6, 1.6, 0.03))
        panelR:SetRotation(Quaternion(-5, -10, 18))
        panelRModel:SetMaterial(panelMat)
        
        -- 通信天线阵
        local antenna1 = hull:CreateChild("Antenna1")
        antenna1.position = Vector3(0.25, 1.0, -0.2)
        local antenna1Model = antenna1:CreateComponent("StaticModel")
        antenna1Model:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        antenna1:SetScale(Vector3(0.04, 0.6, 0.04))
        antenna1:SetRotation(Quaternion(-20, 0, 15))
        antenna1Model:SetMaterial(grayMat)
        
        -- 天线碟
        local dish = hull:CreateChild("Dish")
        dish.position = Vector3(0.4, 1.35, -0.25)
        local dishModel = dish:CreateComponent("StaticModel")
        dishModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
        dish:SetScale(Vector3(0.3, 0.15, 0.3))
        dish:SetRotation(Quaternion(160, 30, 0))
        dishModel:SetMaterial(whiteMat)
        
        -- 下部推进模块
        local propulsion = hull:CreateChild("Propulsion")
        propulsion.position = Vector3(0, -1.2, 0)
        local propulsionModel = propulsion:CreateComponent("StaticModel")
        propulsionModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        propulsion:SetScale(Vector3(0.45, 0.5, 0.45))
        propulsionModel:SetMaterial(grayMat)
        
        -- 引擎喷口
        local nozzle = hull:CreateChild("Nozzle")
        nozzle.position = Vector3(0, -1.5, 0)
        local nozzleModel = nozzle:CreateComponent("StaticModel")
        nozzleModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
        nozzle:SetScale(Vector3(0.25, 0.2, 0.25))
        nozzle:SetRotation(Quaternion(180, 0, 0))
        nozzleModel:SetMaterial(darkMat)
        
        -- 舷窗灯光
        local light1 = hull:CreateChild("Light1")
        light1.position = Vector3(0.3, 0.4, 0.3)
        local light1Model = light1:CreateComponent("StaticModel")
        light1Model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        light1:SetScale(0.08)
        light1Model:SetMaterial(blueGlow)
        
        local light2 = hull:CreateChild("Light2")
        light2.position = Vector3(-0.3, 0.1, 0.3)
        local light2Model = light2:CreateComponent("StaticModel")
        light2Model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        light2:SetScale(0.08)
        light2Model:SetMaterial(blueGlow)
        
        -- 警示信标
        local beacon = hull:CreateChild("Beacon")
        beacon.position = Vector3(0, 1.6, 0)
        local beaconModel = beacon:CreateComponent("StaticModel")
        beaconModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        beacon:SetScale(0.15)
        beaconModel:SetMaterial(orangeGlow)
    end
    
    return hull
end

-- ============================================================================
-- 创建残骸
-- ============================================================================

function Debris.Create(scene, x, y, waveNum)
    local node = scene:CreateChild("Debris")
    node.position = Vector3(x, y, 0)
    
    -- 随机选择残骸类型
    local types = {"wreck", "container", "station"}
    local debrisType = types[math.random(#types)]
    
    -- 创建模型
    local hull = CreateDebrisModel(node, debrisType)
    
    -- 随机初始旋转（模拟太空漂浮的随机姿态）
    local randomPitch = (math.random() - 0.5) * 30  -- -15° ~ +15°
    local randomYaw = math.random(360)              -- 0° ~ 360°
    local randomRoll = (math.random() - 0.5) * 40   -- -20° ~ +20°
    node.rotation = Quaternion(randomPitch, randomYaw, randomRoll)
    
    -- 计算HP (10 + 5 per wave)
    local hp = Debris.Config.BaseHP + Debris.Config.HPPerWave * (waveNum - 1)
    
    local debris = {
        node = node,
        hull = hull,
        type = debrisType,
        x = x,
        y = y,
        hp = hp,
        maxHp = hp,
        scale = 1.0,
        hitRadius = 2.0,  -- 碰撞半径（匹配2x3模型大小）
        isDebris = true,  -- 标识为残骸（区分敌人）
        waveNum = waveNum, -- 记录波次（用于补给箱掉落等级计算）
        bobPhase = math.random() * math.pi * 2,
        rotationSpeed = (math.random() - 0.5) * 20,  -- 缓慢旋转
        -- 闪白效果
        hitFlashTimer = 0,
        originalMaterials = nil,
    }
    
    table.insert(debrisList, debris)
    return debris
end

-- ============================================================================
-- 伤害处理
-- ============================================================================

function Debris.Damage(debris, damage, hitDirX, hitDirY)
    if not debris or debris.hp <= 0 then return 0 end
    
    local actualDamage = damage  -- 残骸无装甲
    debris.hp = debris.hp - actualDamage
    
    -- 触发闪白
    Debris.TriggerHitFlash(debris)
    
    if debris.hp <= 0 then
        Debris.Destroy(debris)
    end
    
    return actualDamage
end

-- 受击闪白效果
function Debris.TriggerHitFlash(debris)
    if debris.hitFlashTimer > 0 then return end  -- 冷却中
    
    debris.hitFlashTimer = Settings.Visual.HitFlashDuration or 0.08
    
    -- 保存原材质并设置闪白
    if not debris.originalMaterials then
        debris.originalMaterials = {}
        local whiteMat = Materials.CreateEmissive(1.0, 1.0, 1.0, 2.0)
        
        local function flashNode(n)
            for i = 0, n:GetNumComponents() - 1 do
                local comp = n:GetComponent(i)
                if comp:GetTypeName() == "StaticModel" then
                    local model = tolua.cast(comp, "StaticModel")
                    table.insert(debris.originalMaterials, {model = model, mat = model:GetMaterial(0)})
                    model:SetMaterial(whiteMat)
                end
            end
            for i = 0, n:GetNumChildren() - 1 do
                flashNode(n:GetChild(i))
            end
        end
        
        flashNode(debris.hull)
    end
end

-- 恢复原材质
function Debris.RestoreOriginalMaterials(debris)
    if debris.originalMaterials then
        for _, entry in ipairs(debris.originalMaterials) do
            entry.model:SetMaterial(entry.mat)
        end
        debris.originalMaterials = nil
    end
end

-- ============================================================================
-- 摧毁残骸
-- ============================================================================

function Debris.Destroy(debris)
    if not debris or not debris.node then return end
    
    local x, y = debris.x, debris.y
    local waveNum = debris.waveNum or 1
    
    -- 回调
    if Debris.onDestroy then
        Debris.onDestroy(debris)
    end
    
    -- 必定掉落晶体（数量随波次增加）
    local crystalAmount = Debris.Config.BaseCrystalDrop + math.floor((waveNum - 1) * Debris.Config.CrystalPerWave * 0.5)
    crystalAmount = math.max(3, math.min(crystalAmount, 15))  -- 限制在 3-15 之间
    if Debris.onDropCrystals then
        Debris.onDropCrystals(x, y, crystalAmount)
    end
    
    -- 掉落判定：80% 护盾电池，20% 补给箱
    local roll = math.random()
    if roll < Debris.Config.ShieldBatteryDrop then
        -- 掉落护盾电池 (80%)
        if Debris.onDropShieldBattery then
            Debris.onDropShieldBattery(x, y)
        end
    else
        -- 掉落补给箱 (20%)，只含模块
        if Debris.onDropSupplyCrate then
            local crateData = Debris.GenerateCrateContents(waveNum)
            Debris.onDropSupplyCrate(x, y, crateData)
        end
    end
    
    -- 移除节点
    debris.node:Remove()
    
    -- 从列表移除
    for i, d in ipairs(debrisList) do
        if d == debris then
            table.remove(debrisList, i)
            break
        end
    end
end

-- ============================================================================
-- 生成补给箱内容（在掉落时预决定）
-- 补给箱只包含模块，不含武器和晶体
-- ============================================================================

function Debris.GenerateCrateContents(waveNum)
    waveNum = waveNum or 1
    
    -- 补给箱只掉落模块
    local tier = Debris.RollModuleTier(waveNum)
    return {
        type = "module",  -- 只有模块类型
        tier = tier,
        -- moduleId 会在开箱时从对应等级模块池中随机
    }
end

-- 按波次掷模块等级（对标 Brotato）
function Debris.RollModuleTier(waveNum)
    local roll = math.random()
    
    -- 波次1-3：只出T1
    if waveNum <= 3 then
        return 1
    -- 波次4-7：75% T1, 25% T2
    elseif waveNum <= 7 then
        if roll < 0.75 then return 1
        else return 2 end
    -- 波次8-12：55% T1, 35% T2, 9% T3, 1% T4
    elseif waveNum <= 12 then
        if roll < 0.55 then return 1
        elseif roll < 0.90 then return 2
        elseif roll < 0.99 then return 3
        else return 4 end
    -- 波次13+：40% T1, 40% T2, 17% T3, 3% T4
    else
        if roll < 0.40 then return 1
        elseif roll < 0.80 then return 2
        elseif roll < 0.97 then return 3
        else return 4 end
    end
end

-- ============================================================================
-- 更新
-- ============================================================================

function Debris.UpdateAll(dt)
    for i = #debrisList, 1, -1 do
        local debris = debrisList[i]
        
        -- 更新闪白计时
        if debris.hitFlashTimer > 0 then
            debris.hitFlashTimer = debris.hitFlashTimer - dt
            if debris.hitFlashTimer <= 0 then
                Debris.RestoreOriginalMaterials(debris)
            end
        end
        
        -- 浮动动画
        debris.bobPhase = debris.bobPhase + dt * 1.5
        local bobY = math.sin(debris.bobPhase) * 0.1
        
        -- 缓慢旋转
        local currentRot = debris.node.rotation
        debris.node.rotation = currentRot * Quaternion(0, debris.rotationSpeed * dt, 0)
        
        -- 更新位置（加浮动）
        debris.node.position = Vector3(debris.x, debris.y + bobY, 0)
    end
end

-- ============================================================================
-- 碰撞检测（供武器系统调用）
-- ============================================================================

function Debris.GetList()
    return debrisList
end

function Debris.GetCount()
    return #debrisList
end

-- 查找最近的残骸
function Debris.FindNearest(x, y, maxRange)
    maxRange = maxRange or 999
    local nearest = nil
    local nearestDist = maxRange
    
    for _, debris in ipairs(debrisList) do
        if debris.hp > 0 then
            local dist = Math.Distance(x, y, debris.x, debris.y)
            if dist < nearestDist then
                nearestDist = dist
                nearest = debris
            end
        end
    end
    
    return nearest, nearestDist
end

-- 查找范围内的残骸
function Debris.FindInRange(x, y, range)
    local results = {}
    for _, debris in ipairs(debrisList) do
        if debris.hp > 0 then
            local dist = Math.Distance(x, y, debris.x, debris.y)
            if dist <= range then
                table.insert(results, {debris = debris, dist = dist})
            end
        end
    end
    table.sort(results, function(a, b) return a.dist < b.dist end)
    return results
end

-- 检查子弹碰撞（与敌人相同的判定逻辑）
function Debris.CheckBulletCollision(x, y, radius)
    radius = radius or 0.5
    for _, debris in ipairs(debrisList) do
        if debris.hp > 0 then
            local hitDist = debris.scale * 0.8 + radius  -- 残骸碰撞半径
            if Math.Distance(x, y, debris.x, debris.y) < hitDist then
                return debris
            end
        end
    end
    return nil
end

-- ============================================================================
-- 生成管理（对标 Brotato Tree 机制）
-- ============================================================================

-- 计算生成数量（Brotato 公式: 0.50 + 0.33 × tree-item-count）
-- 使用累积器模式处理小数生成率
function Debris.CalculateSpawnCount()
    -- 获取残骸相关道具数量
    local itemCount = 0
    if Debris.getDebrisItemCount then
        itemCount = Debris.getDebrisItemCount()
    end
    
    -- Brotato 公式: quantity = 0.50 + 0.33 × tree-item-count
    local spawnRate = Debris.Config.BaseSpawnRate + Debris.Config.SpawnRatePerItem * itemCount
    
    -- 累积生成率
    spawnAccumulator = spawnAccumulator + spawnRate
    
    -- 取整数部分作为本次生成数量，保留小数部分累积到下次
    local count = math.floor(spawnAccumulator)
    spawnAccumulator = spawnAccumulator - count
    
    return count
end

-- 重置生成累积器（波次开始时调用）
function Debris.ResetSpawnAccumulator()
    spawnAccumulator = 0
end

-- 生成残骸（由 Battle 系统调用，每10秒触发一次）
function Debris.SpawnDebris(scene, waveNum, visibleArea)
    local count = Debris.CalculateSpawnCount()
    
    -- 如果计算出0个，则本次不生成（累积到下次）
    if count <= 0 then return end
    
    local playerX, playerY = 0, 0
    if Debris.getPlayerPosition then
        playerX, playerY = Debris.getPlayerPosition()
    end
    
    local arena = Settings.BattleArea
    local margin = 3  -- 距边界margin
    
    for i = 1, count do
        -- 尝试找到合适位置
        local x, y
        local validPos = false
        
        for attempt = 1, 20 do
            -- 在可视区域内随机位置
            if visibleArea then
                x = Math.RandomRange(visibleArea.minX + margin, visibleArea.maxX - margin)
                y = Math.RandomRange(visibleArea.minY + margin, visibleArea.maxY - margin)
            else
                x = Math.RandomRange(arena.MinX + margin, arena.MaxX - margin)
                y = Math.RandomRange(arena.MinY + margin, arena.MaxY - margin)
            end
            
            -- 检查是否太近玩家
            local playerDist = Math.Distance(x, y, playerX, playerY)
            if playerDist < Debris.Config.MinPlayerDistance then
                goto next_attempt
            end
            
            -- 检查是否太近其他残骸
            local tooClose = false
            for _, debris in ipairs(debrisList) do
                if Math.Distance(x, y, debris.x, debris.y) < Debris.Config.MinDebrisDistance then
                    tooClose = true
                    break
                end
            end
            
            if not tooClose then
                validPos = true
                break
            end
            
            ::next_attempt::
        end
        
        if validPos then
            Debris.Create(scene, x, y, waveNum)
        end
    end
end

-- ============================================================================
-- 清理
-- ============================================================================

function Debris.ClearAll()
    for _, debris in ipairs(debrisList) do
        if debris.node then
            debris.node:Remove()
        end
    end
    debrisList = {}
    -- 重置生成累积器
    spawnAccumulator = 0
end

-- 隐藏所有残骸（超空间跳跃时）
function Debris.HideAll()
    for _, debris in ipairs(debrisList) do
        if debris.node then
            debris.node:SetEnabled(false)
        end
    end
end

-- 显示所有残骸
function Debris.ShowAll()
    for _, debris in ipairs(debrisList) do
        if debris.node then
            debris.node:SetEnabled(true)
        end
    end
end

return Debris
