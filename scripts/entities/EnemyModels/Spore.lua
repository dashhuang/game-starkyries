-- ============================================================================
-- 星河战姬 Starkyries - 突击舰模型 (Spore)
-- 虫族快速攻击单位，虫子形态
-- ============================================================================

local Materials = require("render.Materials")

local Spore = {}

function Spore.Create(hull, def, materials)
    local s = def.scale  -- s 现在直接是视觉大小
    local gc = def.glowColor
    local flameNodes = {}
    
    -- 主体：椭圆虫身（基准长度 1.0）
    local body = hull:CreateChild("Body")
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    body:SetScale(Vector3(s * 1.0, s * 0.56, s * 0.5))
    bodyModel:SetMaterial(materials.body)
    
    -- 头部
    local head = hull:CreateChild("Head")
    head.position = Vector3(s * 0.5, s * 0.09, 0)
    local headModel = head:CreateComponent("StaticModel")
    headModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    head:SetScale(Vector3(s * 0.38, s * 0.31, s * 0.31))
    headModel:SetMaterial(materials.body)
    
    -- 双眼
    for i, zOff in ipairs({0.18, -0.18}) do
        local eye = hull:CreateChild("Eye" .. i)
        eye.position = Vector3(s * 0.69, s * 0.16, zOff * s * 0.63)
        local eyeModel = eye:CreateComponent("StaticModel")
        eyeModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        eye:SetScale(s * 0.11)
        eyeModel:SetMaterial(materials.glow)
    end
    
    -- 虫翼（两对）
    local wingMat = Materials.CreatePBR(gc.r * 0.3, gc.g * 0.3, gc.b * 0.3, 0.5, 0.1)
    for i, data in ipairs({{0.15, 0.4}, {-0.3, 0.35}}) do
        for j, zSign in ipairs({1, -1}) do
            local wing = hull:CreateChild("Wing" .. i .. j)
            wing.position = Vector3(data[1] * s * 0.63, s * 0.22, zSign * data[2] * s * 0.63)
            wing.rotation = Quaternion(zSign * 30, 0, zSign * 20)
            local wingModel = wing:CreateComponent("StaticModel")
            wingModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            wing:SetScale(Vector3(s * 0.31, s * 0.02, s * 0.16))
            wingModel:SetMaterial(wingMat)
        end
    end
    
    -- 尾部引擎光
    local tailGlow = hull:CreateChild("TailGlow")
    tailGlow.position = Vector3(-s * 0.5, 0, 0)
    local tailModel = tailGlow:CreateComponent("StaticModel")
    tailModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    tailGlow:SetScale(Vector3(s * 0.13, s * 0.09, s * 0.09))
    tailModel:SetMaterial(materials.engine)
    table.insert(flameNodes, {node = tailGlow, baseScale = Vector3(s * 0.13, s * 0.09, s * 0.09)})
    
    return flameNodes
end

return Spore
