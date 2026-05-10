-- ============================================================================
-- 星河战姬 Starkyries - 爆破舰模型 (SuicideBot)
-- 海盗自爆单位，炸弹形态
-- ============================================================================

local Materials = require("render.Materials")

local SuicideBot = {}

function SuicideBot.Create(hull, def, materials)
    local s = def.scale
    local flameNodes = {}
    
    -- 圆形炸弹主体（加大）
    local body = hull:CreateChild("Body")
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    body:SetScale(Vector3(s * 1.5, s * 1.3, s * 1.1))
    bodyModel:SetMaterial(materials.body)
    
    -- 危险条纹（用小方块模拟，加大）
    local stripeMat = Materials.CreatePBR(0.1, 0.1, 0.1, 0.9, 0.1)
    for i = 1, 3 do
        local stripe = hull:CreateChild("Stripe" .. i)
        stripe.position = Vector3((i - 2) * s * 0.45, s * 0.1, 0)
        local stripeModel = stripe:CreateComponent("StaticModel")
        stripeModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        stripe:SetScale(Vector3(s * 0.12, s * 0.9, s * 1.15))
        stripeModel:SetMaterial(stripeMat)
    end
    
    -- 引信/头部（加大）
    local fuse = hull:CreateChild("Fuse")
    fuse.position = Vector3(s * 0.8, s * 0.25, 0)
    local fuseModel = fuse:CreateComponent("StaticModel")
    fuseModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    fuse:SetScale(Vector3(s * 0.25, s * 0.4, s * 0.25))
    fuse.rotation = Quaternion(0, 0, -90)
    fuseModel:SetMaterial(materials.dark)
    
    -- 闪烁警告灯（加大）
    local warning = hull:CreateChild("Warning")
    warning.position = Vector3(s * 1.0, s * 0.25, 0)
    local warningModel = warning:CreateComponent("StaticModel")
    warningModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    warning:SetScale(s * 0.18)
    warningModel:SetMaterial(Materials.CreateEmissive(1.0, 0.2, 0.1, 3.0))
    
    -- 小型推进器（加大）
    local thruster = hull:CreateChild("Thruster")
    thruster.position = Vector3(-s * 0.8, 0, 0)
    local thrusterModel = thruster:CreateComponent("StaticModel")
    thrusterModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    thruster:SetScale(Vector3(s * 0.25, s * 0.5, s * 0.25))
    thruster.rotation = Quaternion(0, 0, 90)
    thrusterModel:SetMaterial(materials.engine)
    table.insert(flameNodes, {node = thruster, baseScale = Vector3(s * 0.25, s * 0.5, s * 0.25)})
    
    return flameNodes
end

return SuicideBot
