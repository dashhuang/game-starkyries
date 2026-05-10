-- ============================================================================
-- 星河战姬 Starkyries - 自爆虫模型 (SuicideBug)
-- 虫族自爆单位，虫子形态
-- ============================================================================

local Materials = require("render.Materials")

local SuicideBug = {}

function SuicideBug.Create(hull, def, materials)
    local s = def.scale  -- s 现在直接是视觉大小
    local flameNodes = {}
    
    -- 绿色虫体主体（基准长度 1.0）
    local body = hull:CreateChild("Body")
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    body:SetScale(Vector3(s * 1.0, s * 0.5, s * 0.63))
    bodyModel:SetMaterial(materials.body)
    
    -- 腹部节段
    local abdomen = hull:CreateChild("Abdomen")
    abdomen.position = Vector3(-s * 0.44, 0, 0)
    local abdomenModel = abdomen:CreateComponent("StaticModel")
    abdomenModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    abdomen:SetScale(Vector3(s * 0.75, s * 0.56, s * 0.69))
    abdomenModel:SetMaterial(materials.body)
    
    -- 头部
    local head = hull:CreateChild("Head")
    head.position = Vector3(s * 0.56, s * 0.06, 0)
    local headModel = head:CreateComponent("StaticModel")
    headModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    head:SetScale(Vector3(s * 0.31, s * 0.25, s * 0.31))
    headModel:SetMaterial(materials.body)
    
    -- 虫眼（红色，用于闪烁警告）
    local eyeMat = Materials.CreateEmissive(1.0, 0.2, 0.1, 2.0)
    for i, z in ipairs({-0.15, 0.15}) do
        local eye = hull:CreateChild("Eye" .. i)
        eye.position = Vector3(s * 0.69, s * 0.13, s * z * 0.63)
        local eyeModel = eye:CreateComponent("StaticModel")
        eyeModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        eye:SetScale(s * 0.075)
        eyeModel:SetMaterial(eyeMat)
    end
    
    -- 虫腿（6条）
    local legMat = Materials.CreatePBR(0.2, 0.5, 0.15, 0.8, 0.2)
    local legPositions = {
        {x = 0.3, z = 0.4, angle = 30},
        {x = 0, z = 0.45, angle = 0},
        {x = -0.3, z = 0.4, angle = -30},
        {x = 0.3, z = -0.4, angle = -30},
        {x = 0, z = -0.45, angle = 0},
        {x = -0.3, z = -0.4, angle = 30},
    }
    for i, pos in ipairs(legPositions) do
        local leg = hull:CreateChild("Leg" .. i)
        leg.position = Vector3(s * pos.x * 0.63, -s * 0.19, s * pos.z * 0.63)
        local legModel = leg:CreateComponent("StaticModel")
        legModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        leg:SetScale(Vector3(s * 0.038, s * 0.25, s * 0.038))
        leg.rotation = Quaternion(pos.angle, Vector3.FORWARD)
        legModel:SetMaterial(legMat)
    end
    
    -- 膨胀的毒囊（发光，表示即将爆炸）
    local sac = hull:CreateChild("PoisonSac")
    sac.position = Vector3(-s * 0.31, s * 0.19, 0)
    local sacModel = sac:CreateComponent("StaticModel")
    sacModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    sac:SetScale(Vector3(s * 0.38, s * 0.31, s * 0.31))
    sacModel:SetMaterial(materials.glow)
    
    return flameNodes
end

return SuicideBug
