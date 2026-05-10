-- ============================================================================
-- 星河战姬 Starkyries - 护盾舰模型 (Carapace)
-- 机械重装单位，坦克形态
-- ============================================================================

local Carapace = {}

function Carapace.Create(hull, def, materials)
    local s = def.scale
    local flameNodes = {}
    
    -- 厚重主体
    local body = hull:CreateChild("Body")
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    body:SetScale(Vector3(s * 1.0, s * 0.6, s * 0.7))
    bodyModel:SetMaterial(materials.body)
    
    -- 前装甲
    local armor = hull:CreateChild("Armor")
    armor.position = Vector3(s * 0.5, 0, 0)
    local armorModel = armor:CreateComponent("StaticModel")
    armorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    armor:SetScale(Vector3(s * 0.2, s * 0.7, s * 0.8))
    armorModel:SetMaterial(materials.dark)
    
    -- 护盾发生器（顶部发光环）
    local shield = hull:CreateChild("Shield")
    shield.position = Vector3(0, s * 0.35, 0)
    local shieldModel = shield:CreateComponent("StaticModel")
    shieldModel:SetModel(cache:GetResource("Model", "Models/Torus.mdl"))
    shield:SetScale(Vector3(s * 0.5, s * 0.5, s * 0.1))
    shield.rotation = Quaternion(90, 0, 0)
    shieldModel:SetMaterial(materials.glow)
    
    -- 核心
    local core = hull:CreateChild("Core")
    core.position = Vector3(0, s * 0.1, 0)
    local coreModel = core:CreateComponent("StaticModel")
    coreModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    core:SetScale(s * 0.25)
    coreModel:SetMaterial(materials.glow)
    
    -- 双引擎
    for i, zOff in ipairs({0.25, -0.25}) do
        local eng = hull:CreateChild("Eng" .. i)
        eng.position = Vector3(-s * 0.5, 0, zOff * s)
        local engModel = eng:CreateComponent("StaticModel")
        engModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        eng:SetScale(Vector3(s * 0.15, s * 0.25, s * 0.15))
        eng.rotation = Quaternion(0, 0, 90)
        engModel:SetMaterial(materials.engine)
        table.insert(flameNodes, {node = eng, baseScale = Vector3(s * 0.15, s * 0.25, s * 0.15)})
    end
    
    return flameNodes
end

return Carapace
