-- ============================================================================
-- 星河战姬 Starkyries - 精英舰模型 (Elite)
-- 机械精英单位，战列舰形态
-- ============================================================================

local Elite = {}

function Elite.Create(hull, def, materials)
    local s = def.scale  -- s 现在直接是视觉大小
    local flameNodes = {}
    
    -- 主船体（基准长度 1.0）
    local body = hull:CreateChild("Body")
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    body:SetScale(Vector3(s * 1.0, s * 0.36, s * 0.43))
    bodyModel:SetMaterial(materials.body)
    
    -- 指挥塔
    local bridge = hull:CreateChild("Bridge")
    bridge.position = Vector3(s * 0.14, s * 0.25, 0)
    local bridgeModel = bridge:CreateComponent("StaticModel")
    bridgeModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bridge:SetScale(Vector3(s * 0.29, s * 0.18, s * 0.25))
    bridgeModel:SetMaterial(materials.dark)
    
    -- 主炮
    local mainGun = hull:CreateChild("MainGun")
    mainGun.position = Vector3(s * 0.43, s * 0.11, 0)
    local mainGunModel = mainGun:CreateComponent("StaticModel")
    mainGunModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    mainGun:SetScale(Vector3(s * 0.09, s * 0.36, s * 0.09))
    mainGun.rotation = Quaternion(0, 0, 90)
    mainGunModel:SetMaterial(materials.dark)
    
    -- 炮口发光
    local muzzleGlow = hull:CreateChild("MuzzleGlow")
    muzzleGlow.position = Vector3(s * 0.61, s * 0.11, 0)
    local muzzleModel = muzzleGlow:CreateComponent("StaticModel")
    muzzleModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    muzzleGlow:SetScale(s * 0.07)
    muzzleModel:SetMaterial(materials.glow)
    
    -- 侧翼装甲
    for i, zSign in ipairs({1, -1}) do
        local wing = hull:CreateChild("Wing" .. i)
        wing.position = Vector3(-s * 0.14, 0, zSign * s * 0.29)
        local wingModel = wing:CreateComponent("StaticModel")
        wingModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        wing:SetScale(Vector3(s * 0.43, s * 0.11, s * 0.18))
        wingModel:SetMaterial(materials.dark)
        
        -- 翼尖武器
        local weapon = wing:CreateChild("Weapon")
        weapon.position = Vector3(s * 0.18, 0, zSign * s * 0.07)
        local weaponModel = weapon:CreateComponent("StaticModel")
        weaponModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        weapon:SetScale(Vector3(s * 0.04, s * 0.14, s * 0.04))
        weapon.rotation = Quaternion(0, 0, 90)
        weaponModel:SetMaterial(materials.dark)
    end
    
    -- 核心能量
    local core = hull:CreateChild("Core")
    core.position = Vector3(0, s * 0.07, 0)
    local coreModel = core:CreateComponent("StaticModel")
    coreModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    core:SetScale(s * 0.14)
    coreModel:SetMaterial(materials.glow)
    
    -- 双引擎
    for i, zOff in ipairs({0.2, -0.2}) do
        local eng = hull:CreateChild("Eng" .. i)
        eng.position = Vector3(-s * 0.5, 0, zOff * s * 0.71)
        local engModel = eng:CreateComponent("StaticModel")
        engModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
        eng:SetScale(Vector3(s * 0.11, s * 0.25, s * 0.11))
        eng.rotation = Quaternion(0, 0, 90)
        engModel:SetMaterial(materials.engine)
        table.insert(flameNodes, {node = eng, baseScale = Vector3(s * 0.11, s * 0.25, s * 0.11)})
    end
    
    return flameNodes
end

return Elite
