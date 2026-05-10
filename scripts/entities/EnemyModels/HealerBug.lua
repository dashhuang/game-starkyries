-- ============================================================================
-- 星河战姬 Starkyries - 治疗舰模型 (HealerBug)
-- 虫族支援单位，水母形态
-- ============================================================================

local Materials = require("render.Materials")

local HealerBug = {}

function HealerBug.Create(hull, def, materials)
    local s = def.scale  -- s 现在直接是视觉大小
    local flameNodes = {}
    
    -- 伞状主体（基准大小 1.0）
    local body = hull:CreateChild("Body")
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    body:SetScale(Vector3(s * 1.0, s * 0.57, s * 1.0))
    body.position = Vector3(0, s * 0.14, 0)
    bodyModel:SetMaterial(materials.body)
    
    -- 治疗光环
    local aura = hull:CreateChild("Aura")
    local auraModel = aura:CreateComponent("StaticModel")
    auraModel:SetModel(cache:GetResource("Model", "Models/Torus.mdl"))
    aura:SetScale(Vector3(s * 1.14, s * 1.14, s * 0.18))
    aura.rotation = Quaternion(90, 0, 0)
    auraModel:SetMaterial(Materials.CreateEmissive(0.3, 1.0, 0.5, 1.5))
    
    -- 触须（4条）
    for i = 1, 4 do
        local angle = (i - 1) * 90
        local rad = math.rad(angle)
        local tentacle = hull:CreateChild("Tentacle" .. i)
        tentacle.position = Vector3(math.cos(rad) * s * 0.29, -s * 0.21, math.sin(rad) * s * 0.29)
        local tentModel = tentacle:CreateComponent("StaticModel")
        tentModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        tentacle:SetScale(Vector3(s * 0.07, s * 0.36, s * 0.07))
        tentModel:SetMaterial(materials.body)
        
        -- 触须末端发光
        local tip = tentacle:CreateChild("Tip")
        tip.position = Vector3(0, -s * 0.18, 0)
        local tipModel = tip:CreateComponent("StaticModel")
        tipModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        tip:SetScale(s * 0.11)
        tipModel:SetMaterial(materials.glow)
    end
    
    -- 核心发光
    local core = hull:CreateChild("Core")
    core.position = Vector3(0, s * 0.18, 0)
    local coreModel = core:CreateComponent("StaticModel")
    coreModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    core:SetScale(s * 0.25)
    coreModel:SetMaterial(materials.glow)
    table.insert(flameNodes, {node = core, baseScale = Vector3(s * 0.25, s * 0.25, s * 0.25)})
    
    return flameNodes
end

return HealerBug
