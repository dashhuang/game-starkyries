-- ============================================================================
-- 星河战姬 Starkyries - 虫族母舰模型 (BroodMother)
-- Boss，巨型虫母
-- ============================================================================

local Materials = require("render.Materials")

local BroodMother = {}

function BroodMother.Create(hull, def, materials)
    local s = def.scale  -- s 现在直接是视觉大小
    local gc = def.glowColor
    local flameNodes = {}
    
    -- 巨大椭圆主体（基准大小 1.0）
    local body = hull:CreateChild("Body")
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    body:SetScale(Vector3(s * 1.0, s * 0.58, s * 0.67))
    bodyModel:SetMaterial(materials.body)
    
    -- 头部
    local head = hull:CreateChild("Head")
    head.position = Vector3(s * 0.58, s * 0.17, 0)
    local headModel = head:CreateComponent("StaticModel")
    headModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    head:SetScale(Vector3(s * 0.42, s * 0.33, s * 0.38))
    headModel:SetMaterial(materials.body)
    
    -- Boss眼睛（多只）
    for i, data in ipairs({{0.2, 0.15, 0.15}, {0.25, 0.1, -0.15}, {0.15, 0.2, 0}}) do
        local eye = hull:CreateChild("Eye" .. i)
        eye.position = Vector3(s * (0.67 + data[1] * 0.83), s * data[2] * 0.83, s * data[3] * 0.83)
        local eyeModel = eye:CreateComponent("StaticModel")
        eyeModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        eye:SetScale(s * 0.1)
        eyeModel:SetMaterial(materials.glow)
    end
    
    -- 甲壳装甲
    for i = 1, 3 do
        local shell = hull:CreateChild("Shell" .. i)
        shell.position = Vector3(-s * 0.17 * i, s * 0.25, 0)
        local shellModel = shell:CreateComponent("StaticModel")
        shellModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        shell:SetScale(Vector3(s * 0.33, s * 0.13, s * (0.75 - i * 0.125)))
        shellModel:SetMaterial(materials.dark)
    end
    
    -- 巨型翅膀
    local wingMat = Materials.CreatePBR(gc.r * 0.2, gc.g * 0.2, gc.b * 0.2, 0.4, 0.1)
    for i, zSign in ipairs({1, -1}) do
        local wing = hull:CreateChild("BigWing" .. i)
        wing.position = Vector3(0, s * 0.17, zSign * s * 0.42)
        wing.rotation = Quaternion(zSign * 15, 0, zSign * 10)
        local wingModel = wing:CreateComponent("StaticModel")
        wingModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        wing:SetScale(Vector3(s * 0.67, s * 0.025, s * 0.42))
        wingModel:SetMaterial(wingMat)
    end
    
    -- 尾部产卵器
    local tail = hull:CreateChild("Tail")
    tail.position = Vector3(-s * 0.67, -s * 0.08, 0)
    local tailModel = tail:CreateComponent("StaticModel")
    tailModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    tail:SetScale(Vector3(s * 0.42, s * 0.33, s * 0.33))
    tailModel:SetMaterial(materials.body)
    
    -- Boss核心（巨大发光）
    local core = hull:CreateChild("Core")
    core.position = Vector3(0, 0, 0)
    local coreModel = core:CreateComponent("StaticModel")
    coreModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    core:SetScale(s * 0.29)
    coreModel:SetMaterial(Materials.CreateEmissive(gc.r, gc.g, gc.b, 3.0))
    
    -- 多引擎
    for i, data in ipairs({{-0.9, 0.1, 0.3}, {-0.9, 0.1, -0.3}, {-0.9, -0.1, 0}}) do
        local eng = hull:CreateChild("Eng" .. i)
        eng.position = Vector3(s * data[1] * 0.83, s * data[2] * 0.83, s * data[3] * 0.83)
        local engModel = eng:CreateComponent("StaticModel")
        engModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
        eng:SetScale(Vector3(s * 0.13, s * 0.33, s * 0.13))
        eng.rotation = Quaternion(0, 0, 90)
        engModel:SetMaterial(materials.engine)
        table.insert(flameNodes, {node = eng, baseScale = Vector3(s * 0.13, s * 0.33, s * 0.13)})
    end
    
    return flameNodes
end

return BroodMother
