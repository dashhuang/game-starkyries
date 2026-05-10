-- ============================================================================
-- 星河战姬 Starkyries - 战舰模型系统
-- 支持不同战舰使用独立模型
-- ============================================================================

local Materials = require("render.Materials")

local ShipModels = {}

-- 模型注册表
ShipModels.Registry = {}

-- ============================================================================
-- 模型注册接口
-- ============================================================================

--- 注册战舰模型生成函数
---@param shipId string 战舰ID（如 "Pioneer", "Polyhedron"）
---@param createFunc function 模型生成函数 function(parentNode, shipConfig) -> hullNode, flameNodes
function ShipModels.Register(shipId, createFunc)
    ShipModels.Registry[shipId] = createFunc
end

--- 创建战舰模型
---@param shipId string 战舰ID
---@param parentNode Node 父节点
---@param shipConfig table 战舰配置（来自ships.lua）
---@return Node hullNode 船体节点
---@return table flameNodes 引擎火焰节点列表 {node, baseScale}
---@return Light engineLight 引擎点光源（可选）
function ShipModels.Create(shipId, parentNode, shipConfig)
    local createFunc = ShipModels.Registry[shipId]
    if not createFunc then
        -- 回退到默认模型
        createFunc = ShipModels.Registry["Default"]
    end
    
    if createFunc then
        return createFunc(parentNode, shipConfig)
    end
    
    -- 如果连默认模型都没有，创建一个简单占位
    local hull = parentNode:CreateChild("Hull")
    local model = hull:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(Materials.CreatePBR(0.5, 0.5, 0.5, 0.5, 0.5))
    return hull, {}, nil
end

--- 检查是否有指定战舰的模型
---@param shipId string
---@return boolean
function ShipModels.HasModel(shipId)
    return ShipModels.Registry[shipId] ~= nil
end

--- 获取所有已注册的战舰ID
---@return table
function ShipModels.GetRegisteredIds()
    local ids = {}
    for id, _ in pairs(ShipModels.Registry) do
        table.insert(ids, id)
    end
    return ids
end

-- ============================================================================
-- 通用材质工厂（供各模型函数使用）
-- ============================================================================

--- 创建战舰材质集
---@param shipConfig table 战舰配置
---@return table materials 材质集合
function ShipModels.CreateMaterials(shipConfig)
    local hc = shipConfig.hullColor or {r = 0.5, g = 0.5, b = 0.6}
    local ac = shipConfig.accentColor or {r = 0.4, g = 0.6, b = 0.8}
    local ec = shipConfig.engineColor or {r = 0.3, g = 0.6, b = 1.0}
    
    return {
        -- 船体材质（基于配置颜色）
        hullLight = Materials.CreatePBR(
            hc.r * 1.3, hc.g * 1.3, hc.b * 1.3, 
            0.6, 0.4
        ),
        hullMid = Materials.CreatePBR(
            hc.r, hc.g, hc.b, 
            0.7, 0.3
        ),
        hullDark = Materials.CreatePBR(
            hc.r * 0.4, hc.g * 0.4, hc.b * 0.4, 
            0.8, 0.2
        ),
        -- 强调色（装饰、发光舱室）
        accent = Materials.CreatePBR(
            ac.r, ac.g, ac.b, 
            0.5, 0.5
        ),
        accentGlow = Materials.CreateEmissive(
            ac.r, ac.g, ac.b, 
            3.0
        ),
        -- 金属部件
        metal = Materials.CreatePBR(0.4, 0.4, 0.45, 0.9, 0.1),
        -- 引擎
        engine = Materials.CreateEmissive(ec.r, ec.g, ec.b, 4.0),
        engineGlow = Materials.CreateEmissive(ec.r * 0.6, ec.g * 0.8, ec.b, 2.5),
        -- 导航灯
        navLight = Materials.CreateEmissive(0.2, 1.0, 0.3, 3.0),
    }
end

-- ============================================================================
-- 默认模型（作为回退）
-- ============================================================================

ShipModels.Register("Default", function(parentNode, shipConfig)
    local mats = ShipModels.CreateMaterials(shipConfig)
    local hull = parentNode:CreateChild("Hull")
    
    -- 简单的楔形船体
    local body = hull:CreateChild("Body")
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    body:SetScale(Vector3(2.0, 0.4, 0.6))
    bodyModel:SetMaterial(mats.hullMid)
    
    -- 船首
    local bow = hull:CreateChild("Bow")
    bow.position = Vector3(1.2, 0, 0)
    local bowModel = bow:CreateComponent("StaticModel")
    bowModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    bow:SetScale(Vector3(0.3, 0.6, 0.4))
    bow.rotation = Quaternion(0, 0, -90)
    bowModel:SetMaterial(mats.hullLight)
    
    -- 引擎
    local flameNodes = {}
    local flame = hull:CreateChild("Flame")
    flame.position = Vector3(-1.2, 0, 0)
    local flameModel = flame:CreateComponent("StaticModel")
    flameModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    local flameScale = Vector3(0.15, 0.4, 0.15)
    flame:SetScale(flameScale)
    flame.rotation = Quaternion(0, 0, 90)
    flameModel:SetMaterial(mats.engine)
    table.insert(flameNodes, {node = flame, baseScale = flameScale})
    
    return hull, flameNodes, nil
end)

-- ============================================================================
-- SSA-01 先锋号 - 均衡型突击舰
-- 特点：经典战舰造型，流线型，导航灯清晰
-- ============================================================================

ShipModels.Register("Pioneer", function(parentNode, shipConfig)
    local mats = ShipModels.CreateMaterials(shipConfig)
    local hull = parentNode:CreateChild("Hull")
    local flameNodes = {}
    
    -- ========== 主船体（楔形） ==========
    local mainBody = hull:CreateChild("MainBody")
    local mainBodyModel = mainBody:CreateComponent("StaticModel")
    mainBodyModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    mainBody:SetScale(Vector3(3.0, 0.5, 0.7))
    mainBodyModel:SetMaterial(mats.hullLight)
    
    -- 船体上部斜面
    local upperSlope = hull:CreateChild("UpperSlope")
    upperSlope.position = Vector3(0.3, 0.32, 0)
    local upperSlopeModel = upperSlope:CreateComponent("StaticModel")
    upperSlopeModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    upperSlope:SetScale(Vector3(2.2, 0.15, 0.6))
    upperSlopeModel:SetMaterial(mats.hullMid)
    
    -- 船体下部（深色装甲）
    local lowerHull = hull:CreateChild("LowerHull")
    lowerHull.position = Vector3(0, -0.35, 0)
    local lowerHullModel = lowerHull:CreateComponent("StaticModel")
    lowerHullModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    lowerHull:SetScale(Vector3(2.6, 0.22, 0.75))
    lowerHullModel:SetMaterial(mats.hullDark)
    
    -- ========== 舰首（尖锐楔形） ==========
    local bow = hull:CreateChild("Bow")
    bow.position = Vector3(1.8, 0.05, 0)
    local bowModel = bow:CreateComponent("StaticModel")
    bowModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    bow:SetScale(Vector3(0.4, 0.9, 0.55))
    bow.rotation = Quaternion(0, 0, -90)
    bowModel:SetMaterial(mats.hullLight)
    
    -- 舰首下部（深色）
    local bowLower = hull:CreateChild("BowLower")
    bowLower.position = Vector3(1.5, -0.2, 0)
    local bowLowerModel = bowLower:CreateComponent("StaticModel")
    bowLowerModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bowLower:SetScale(Vector3(0.6, 0.2, 0.5))
    bowLowerModel:SetMaterial(mats.hullDark)
    
    -- ========== 上层建筑（阶梯式指挥塔） ==========
    local super1 = hull:CreateChild("Super1")
    super1.position = Vector3(-0.1, 0.5, 0)
    local super1Model = super1:CreateComponent("StaticModel")
    super1Model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    super1:SetScale(Vector3(1.4, 0.25, 0.55))
    super1Model:SetMaterial(mats.hullMid)
    
    local super2 = hull:CreateChild("Super2")
    super2.position = Vector3(0, 0.75, 0)
    local super2Model = super2:CreateComponent("StaticModel")
    super2Model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    super2:SetScale(Vector3(0.9, 0.25, 0.45))
    super2Model:SetMaterial(mats.hullLight)
    
    local bridge = hull:CreateChild("Bridge")
    bridge.position = Vector3(0.15, 0.98, 0)
    local bridgeModel = bridge:CreateComponent("StaticModel")
    bridgeModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bridge:SetScale(Vector3(0.5, 0.22, 0.35))
    bridgeModel:SetMaterial(mats.hullMid)
    
    local bridgeTop = hull:CreateChild("BridgeTop")
    bridgeTop.position = Vector3(0.1, 1.15, 0)
    local bridgeTopModel = bridgeTop:CreateComponent("StaticModel")
    bridgeTopModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bridgeTop:SetScale(Vector3(0.35, 0.12, 0.28))
    bridgeTopModel:SetMaterial(mats.hullDark)
    
    -- ========== 主炮塔 ==========
    local turretBase = hull:CreateChild("TurretBase")
    turretBase.position = Vector3(0.8, 0.45, 0)
    local turretBaseModel = turretBase:CreateComponent("StaticModel")
    turretBaseModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    turretBase:SetScale(Vector3(0.25, 0.1, 0.25))
    turretBaseModel:SetMaterial(mats.hullDark)
    
    local turret = hull:CreateChild("Turret")
    turret.position = Vector3(0.8, 0.55, 0)
    local turretModel = turret:CreateComponent("StaticModel")
    turretModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    turret:SetScale(Vector3(0.3, 0.15, 0.2))
    turretModel:SetMaterial(mats.hullMid)
    
    local barrel = hull:CreateChild("Barrel")
    barrel.position = Vector3(1.05, 0.55, 0)
    local barrelModel = barrel:CreateComponent("StaticModel")
    barrelModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    barrel:SetScale(Vector3(0.04, 0.3, 0.04))
    barrel.rotation = Quaternion(0, 0, -90)
    barrelModel:SetMaterial(mats.metal)
    
    -- ========== 侧面发光舱室 ==========
    for i, zOff in ipairs({0.36, -0.36}) do
        local cabin = hull:CreateChild("Cabin" .. i)
        cabin.position = Vector3(-0.3, 0, zOff)
        local cabinModel = cabin:CreateComponent("StaticModel")
        cabinModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        cabin:SetScale(Vector3(0.8, 0.35, 0.03))
        cabinModel:SetMaterial(mats.accentGlow)
        
        local cabinFrame = hull:CreateChild("CabinFrame" .. i)
        cabinFrame.position = Vector3(-0.3, 0, zOff * 1.02)
        local cabinFrameModel = cabinFrame:CreateComponent("StaticModel")
        cabinFrameModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        cabinFrame:SetScale(Vector3(0.9, 0.4, 0.02))
        cabinFrameModel:SetMaterial(mats.hullDark)
    end
    
    -- ========== 侧翼结构 ==========
    for i, zOff in ipairs({0.45, -0.45}) do
        local wing = hull:CreateChild("Wing" .. i)
        wing.position = Vector3(-0.6, -0.15, zOff)
        local wingModel = wing:CreateComponent("StaticModel")
        wingModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        wing:SetScale(Vector3(1.0, 0.12, 0.2))
        wingModel:SetMaterial(mats.hullLight)
        
        local wingTip = hull:CreateChild("WingTip" .. i)
        wingTip.position = Vector3(-1.0, -0.1, zOff * 1.15)
        local wingTipModel = wingTip:CreateComponent("StaticModel")
        wingTipModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        wingTip:SetScale(Vector3(0.4, 0.15, 0.12))
        wingTipModel:SetMaterial(mats.hullMid)
        
        local pylon = hull:CreateChild("Pylon" .. i)
        pylon.position = Vector3(-0.4, -0.3, zOff * 0.8)
        local pylonModel = pylon:CreateComponent("StaticModel")
        pylonModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        pylon:SetScale(Vector3(0.5, 0.1, 0.08))
        pylonModel:SetMaterial(mats.hullDark)
    end
    
    -- ========== 引擎区（2个大型引擎） ==========
    local engineGroup = hull:CreateChild("Engines")
    engineGroup.position = Vector3(-1.5, 0, 0)
    
    local engineHousing = engineGroup:CreateChild("EngineHousing")
    local engineHousingModel = engineHousing:CreateComponent("StaticModel")
    engineHousingModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    engineHousing:SetScale(Vector3(0.5, 0.6, 0.7))
    engineHousingModel:SetMaterial(mats.hullDark)
    
    for i, yOff in ipairs({0.15, -0.15}) do
        local engineNozzle = engineGroup:CreateChild("EngineNozzle" .. i)
        engineNozzle.position = Vector3(-0.15, yOff, 0)
        local nozzleModel = engineNozzle:CreateComponent("StaticModel")
        nozzleModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        engineNozzle:SetScale(Vector3(0.2, 0.35, 0.2))
        engineNozzle.rotation = Quaternion(0, 0, 90)
        nozzleModel:SetMaterial(mats.metal)
        
        local flame = engineGroup:CreateChild("Flame" .. i)
        flame.position = Vector3(-0.4, yOff, 0)
        local flameModel = flame:CreateComponent("StaticModel")
        flameModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
        local flameScale = Vector3(0.15, 0.5, 0.15)
        flame:SetScale(flameScale)
        flame.rotation = Quaternion(0, 0, 90)
        flameModel:SetMaterial(mats.engine)
        table.insert(flameNodes, {node = flame, baseScale = flameScale})
        
        local glow = engineGroup:CreateChild("Glow" .. i)
        glow.position = Vector3(-0.6, yOff, 0)
        local glowModel = glow:CreateComponent("StaticModel")
        glowModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        local glowScale = Vector3(0.3, 0.22, 0.22)
        glow:SetScale(glowScale)
        glowModel:SetMaterial(mats.engineGlow)
        table.insert(flameNodes, {node = glow, baseScale = glowScale})
    end
    
    -- 引擎点光源
    local engineLightNode = engineGroup:CreateChild("EngineLight")
    engineLightNode.position = Vector3(-0.5, 0, 0)
    local engineLight = engineLightNode:CreateComponent("Light")
    engineLight.lightType = LIGHT_POINT
    local ec = shipConfig.engineColor or {r = 0.3, g = 0.6, b = 1.0}
    engineLight.color = Color(ec.r, ec.g, ec.b)
    engineLight.brightness = 2.0
    engineLight.range = 4.0
    
    -- ========== 装饰细节 ==========
    for i, zOff in ipairs({0.38, -0.38}) do
        local armorPlate = hull:CreateChild("ArmorPlate" .. i)
        armorPlate.position = Vector3(0.6, 0.15, zOff)
        local armorPlateModel = armorPlate:CreateComponent("StaticModel")
        armorPlateModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        armorPlate:SetScale(Vector3(0.6, 0.2, 0.03))
        armorPlateModel:SetMaterial(mats.hullDark)
    end
    
    -- ========== 导航灯 ==========
    local navFront = hull:CreateChild("NavFront")
    navFront.position = Vector3(2.1, 0.05, 0)
    local navFrontModel = navFront:CreateComponent("StaticModel")
    navFrontModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    navFront:SetScale(Vector3(0.05, 0.05, 0.05))
    navFrontModel:SetMaterial(mats.navLight)
    
    for i, zOff in ipairs({0.55, -0.55}) do
        local navWing = hull:CreateChild("NavWing" .. i)
        navWing.position = Vector3(-1.0, -0.08, zOff)
        local navWingModel = navWing:CreateComponent("StaticModel")
        navWingModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        navWing:SetScale(Vector3(0.04, 0.04, 0.04))
        navWingModel:SetMaterial(mats.navLight)
    end
    
    return hull, flameNodes, engineLight
end)

-- ============================================================================
-- SSA-10 多面号 - 多武器型战舰
-- 特点：更宽大的船体，多个武器挂点外露，紫色调
-- ============================================================================

ShipModels.Register("Polyhedron", function(parentNode, shipConfig)
    local mats = ShipModels.CreateMaterials(shipConfig)
    local hull = parentNode:CreateChild("Hull")
    local flameNodes = {}
    
    -- ========== 主船体（更宽厚，适合多武器） ==========
    local mainBody = hull:CreateChild("MainBody")
    local mainBodyModel = mainBody:CreateComponent("StaticModel")
    mainBodyModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    mainBody:SetScale(Vector3(3.2, 0.6, 1.0))  -- 更宽
    mainBodyModel:SetMaterial(mats.hullMid)
    
    -- 中央凸起（武器平台）
    local centerPlatform = hull:CreateChild("CenterPlatform")
    centerPlatform.position = Vector3(0, 0.4, 0)
    local centerPlatformModel = centerPlatform:CreateComponent("StaticModel")
    centerPlatformModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    centerPlatform:SetScale(Vector3(2.0, 0.25, 0.8))
    centerPlatformModel:SetMaterial(mats.hullLight)
    
    -- 船体下装甲
    local lowerHull = hull:CreateChild("LowerHull")
    lowerHull.position = Vector3(0, -0.4, 0)
    local lowerHullModel = lowerHull:CreateComponent("StaticModel")
    lowerHullModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    lowerHull:SetScale(Vector3(2.8, 0.25, 0.9))
    lowerHullModel:SetMaterial(mats.hullDark)
    
    -- ========== 舰首（六边形风格） ==========
    local bow = hull:CreateChild("Bow")
    bow.position = Vector3(1.8, 0, 0)
    local bowModel = bow:CreateComponent("StaticModel")
    bowModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bow:SetScale(Vector3(0.8, 0.5, 0.7))
    bow.rotation = Quaternion(0, 45, 0)
    bowModel:SetMaterial(mats.hullLight)
    
    local bowTip = hull:CreateChild("BowTip")
    bowTip.position = Vector3(2.3, 0, 0)
    local bowTipModel = bowTip:CreateComponent("StaticModel")
    bowTipModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    bowTip:SetScale(Vector3(0.35, 0.5, 0.35))
    bowTip.rotation = Quaternion(0, 0, -90)
    bowTipModel:SetMaterial(mats.accent)
    
    -- ========== 指挥塔（多面体风格） ==========
    local bridge = hull:CreateChild("Bridge")
    bridge.position = Vector3(-0.2, 0.7, 0)
    local bridgeModel = bridge:CreateComponent("StaticModel")
    bridgeModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bridge:SetScale(Vector3(0.8, 0.35, 0.5))
    bridge.rotation = Quaternion(0, 15, 0)
    bridgeModel:SetMaterial(mats.hullMid)
    
    local bridgeTop = hull:CreateChild("BridgeTop")
    bridgeTop.position = Vector3(-0.1, 0.95, 0)
    local bridgeTopModel = bridgeTop:CreateComponent("StaticModel")
    bridgeTopModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bridgeTop:SetScale(Vector3(0.5, 0.2, 0.35))
    bridgeTop.rotation = Quaternion(0, -15, 0)
    bridgeTopModel:SetMaterial(mats.hullDark)
    
    -- ========== 多武器挂架（6对=12个位置） ==========
    local mountPositions = {
        -- 前排
        {x = 1.0, z = 0.4}, {x = 1.0, z = -0.4},
        -- 中前排
        {x = 0.5, z = 0.55}, {x = 0.5, z = -0.55},
        -- 中排
        {x = 0, z = 0.5}, {x = 0, z = -0.5},
        -- 中后排
        {x = -0.5, z = 0.45}, {x = -0.5, z = -0.45},
        -- 后排
        {x = -1.0, z = 0.35}, {x = -1.0, z = -0.35},
        -- 侧翼
        {x = 0.2, z = 0.65}, {x = 0.2, z = -0.65},
    }
    
    for i, pos in ipairs(mountPositions) do
        -- 武器挂架基座
        local mount = hull:CreateChild("WeaponMount" .. i)
        mount.position = Vector3(pos.x, 0.35, pos.z)
        local mountModel = mount:CreateComponent("StaticModel")
        mountModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        mount:SetScale(Vector3(0.12, 0.08, 0.12))
        mountModel:SetMaterial(mats.metal)
        
        -- 发光环（强调色）
        local ring = hull:CreateChild("MountRing" .. i)
        ring.position = Vector3(pos.x, 0.38, pos.z)
        local ringModel = ring:CreateComponent("StaticModel")
        ringModel:SetModel(cache:GetResource("Model", "Models/Torus.mdl"))
        ring:SetScale(Vector3(0.1, 0.1, 0.1))
        ringModel:SetMaterial(mats.accentGlow)
    end
    
    -- ========== 侧翼（更大更厚实） ==========
    for i, zOff in ipairs({0.6, -0.6}) do
        -- 主翼
        local wing = hull:CreateChild("Wing" .. i)
        wing.position = Vector3(-0.3, -0.1, zOff)
        local wingModel = wing:CreateComponent("StaticModel")
        wingModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        wing:SetScale(Vector3(1.8, 0.15, 0.35))
        wingModel:SetMaterial(mats.hullLight)
        
        -- 翼尖稳定器
        local stabilizer = hull:CreateChild("Stabilizer" .. i)
        stabilizer.position = Vector3(-1.2, 0, zOff * 1.2)
        local stabilizerModel = stabilizer:CreateComponent("StaticModel")
        stabilizerModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        stabilizer:SetScale(Vector3(0.5, 0.3, 0.1))
        stabilizerModel:SetMaterial(mats.hullMid)
        
        -- 侧面装甲（多面）
        local sideArmor = hull:CreateChild("SideArmor" .. i)
        sideArmor.position = Vector3(0.3, 0, zOff * 0.85)
        local sideArmorModel = sideArmor:CreateComponent("StaticModel")
        sideArmorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        sideArmor:SetScale(Vector3(1.5, 0.45, 0.08))
        sideArmorModel:SetMaterial(mats.hullDark)
        
        -- 发光条纹
        local stripe = hull:CreateChild("Stripe" .. i)
        stripe.position = Vector3(0.3, 0.1, zOff * 0.88)
        local stripeModel = stripe:CreateComponent("StaticModel")
        stripeModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        stripe:SetScale(Vector3(1.2, 0.06, 0.02))
        stripeModel:SetMaterial(mats.accentGlow)
    end
    
    -- ========== 引擎区（4个中型引擎） ==========
    local engineGroup = hull:CreateChild("Engines")
    engineGroup.position = Vector3(-1.6, 0, 0)
    
    -- 引擎外壳
    local engineHousing = engineGroup:CreateChild("EngineHousing")
    local engineHousingModel = engineHousing:CreateComponent("StaticModel")
    engineHousingModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    engineHousing:SetScale(Vector3(0.5, 0.7, 1.0))
    engineHousingModel:SetMaterial(mats.hullDark)
    
    -- 4个引擎喷口
    local engineOffsets = {
        {y = 0.2, z = 0.3}, {y = 0.2, z = -0.3},
        {y = -0.2, z = 0.3}, {y = -0.2, z = -0.3},
    }
    
    for i, off in ipairs(engineOffsets) do
        local nozzle = engineGroup:CreateChild("Nozzle" .. i)
        nozzle.position = Vector3(-0.15, off.y, off.z)
        local nozzleModel = nozzle:CreateComponent("StaticModel")
        nozzleModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        nozzle:SetScale(Vector3(0.15, 0.25, 0.15))
        nozzle.rotation = Quaternion(0, 0, 90)
        nozzleModel:SetMaterial(mats.metal)
        
        local flame = engineGroup:CreateChild("Flame" .. i)
        flame.position = Vector3(-0.35, off.y, off.z)
        local flameModel = flame:CreateComponent("StaticModel")
        flameModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
        local flameScale = Vector3(0.12, 0.4, 0.12)
        flame:SetScale(flameScale)
        flame.rotation = Quaternion(0, 0, 90)
        flameModel:SetMaterial(mats.engine)
        table.insert(flameNodes, {node = flame, baseScale = flameScale})
    end
    
    -- 引擎光源
    local engineLightNode = engineGroup:CreateChild("EngineLight")
    engineLightNode.position = Vector3(-0.4, 0, 0)
    local engineLight = engineLightNode:CreateComponent("Light")
    engineLight.lightType = LIGHT_POINT
    local ec = shipConfig.engineColor or {r = 0.6, g = 0.4, b = 0.8}
    engineLight.color = Color(ec.r, ec.g, ec.b)
    engineLight.brightness = 2.0
    engineLight.range = 5.0
    
    -- ========== 导航灯 ==========
    local navFront = hull:CreateChild("NavFront")
    navFront.position = Vector3(2.5, 0, 0)
    local navFrontModel = navFront:CreateComponent("StaticModel")
    navFrontModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    navFront:SetScale(Vector3(0.06, 0.06, 0.06))
    navFrontModel:SetMaterial(mats.navLight)
    
    for i, zOff in ipairs({0.75, -0.75}) do
        local navWing = hull:CreateChild("NavWing" .. i)
        navWing.position = Vector3(-1.3, 0.05, zOff)
        local navWingModel = navWing:CreateComponent("StaticModel")
        navWingModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        navWing:SetScale(Vector3(0.04, 0.04, 0.04))
        navWingModel:SetMaterial(mats.navLight)
    end
    
    return hull, flameNodes, engineLight
end)

return ShipModels
