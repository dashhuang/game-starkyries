-- ============================================================================
-- 星河战姬 Starkyries - 炮艇模型 (PirateGun)
-- 海盗远程单位，武装舰船
-- ============================================================================

local Materials = require("render.Materials")

local PirateGun = {}

function PirateGun.Create(hull, def, materials)
    local s = def.scale  -- s 现在直接是视觉大小
    local flameNodes = {}
    
    -- 主船体（基准长度 1.0）
    local body = hull:CreateChild("Body")
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    body:SetScale(Vector3(s * 1.0, s * 0.33, s * 0.47))
    bodyModel:SetMaterial(materials.body)
    
    -- 驾驶舱
    local cockpit = hull:CreateChild("Cockpit")
    cockpit.position = Vector3(s * 0.27, s * 0.22, 0)
    local cockpitModel = cockpit:CreateComponent("StaticModel")
    cockpitModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    cockpit:SetScale(Vector3(s * 0.27, s * 0.17, s * 0.2))
    cockpitModel:SetMaterial(Materials.CreatePBR(0.2, 0.3, 0.4, 0.3, 0.1))
    
    -- 双炮塔
    for i, zOff in ipairs({0.6, -0.6}) do
        local turret = hull:CreateChild("Turret" .. i)
        turret.position = Vector3(s * 0.3, s * 0.1, zOff * s * 0.33)
        local turretModel = turret:CreateComponent("StaticModel")
        turretModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        turret:SetScale(Vector3(s * 0.07, s * 0.23, s * 0.07))
        turret.rotation = Quaternion(0, 0, 90)
        turretModel:SetMaterial(materials.dark)
        
        -- 炮口发光
        local muzzle = turret:CreateChild("Muzzle")
        muzzle.position = Vector3(0, s * 0.12, 0)
        local muzzleModel = muzzle:CreateComponent("StaticModel")
        muzzleModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        muzzle:SetScale(s * 0.06)
        muzzleModel:SetMaterial(materials.glow)
    end
    
    -- 侧翼
    for i, zSign in ipairs({1, -1}) do
        local wing = hull:CreateChild("Wing" .. i)
        wing.position = Vector3(-s * 0.1, 0, zSign * s * 0.28)
        local wingModel = wing:CreateComponent("StaticModel")
        wingModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        wing:SetScale(Vector3(s * 0.33, s * 0.05, s * 0.17))
        wingModel:SetMaterial(materials.dark)
    end
    
    -- 引擎
    local engine = hull:CreateChild("Engine")
    engine.position = Vector3(-s * 0.5, 0, 0)
    local engineModel = engine:CreateComponent("StaticModel")
    engineModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    engine:SetScale(Vector3(s * 0.13, s * 0.23, s * 0.13))
    engine.rotation = Quaternion(0, 0, 90)
    engineModel:SetMaterial(materials.engine)
    table.insert(flameNodes, {node = engine, baseScale = Vector3(s * 0.13, s * 0.23, s * 0.13)})
    
    return flameNodes
end

return PirateGun
