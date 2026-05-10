-- ============================================================================
-- 星河战姬 Starkyries - 虫族女王模型 (BroodQueen)
-- 最终Boss，巨型虫母（3倍体型）
-- ============================================================================

local Materials = require("render.Materials")

local BroodQueen = {}

function BroodQueen.Create(hull, def, materials)
    local s = def.scale  -- s 现在直接是视觉大小
    local gc = def.glowColor
    local flameNodes = {}
    
    -- 巨大椭圆主体（基准大小 1.0）
    local body = hull:CreateChild("Body")
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    body:SetScale(Vector3(s * 1.0, s * 0.62, s * 0.69))
    bodyModel:SetMaterial(materials.body)
    
    -- 王冠状头部
    local head = hull:CreateChild("Head")
    head.position = Vector3(s * 0.62, s * 0.23, 0)
    local headModel = head:CreateComponent("StaticModel")
    headModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    head:SetScale(Vector3(s * 0.46, s * 0.38, s * 0.42))
    headModel:SetMaterial(materials.body)
    
    -- 头冠装饰（女王特征）
    for i, zPos in ipairs({0.2, 0, -0.2}) do
        local crown = hull:CreateChild("Crown" .. i)
        crown.position = Vector3(s * 0.77, s * 0.38, s * zPos * 0.77)
        local crownModel = crown:CreateComponent("StaticModel")
        crownModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
        crown:SetScale(Vector3(s * 0.06, s * 0.19, s * 0.06))
        crown.rotation = Quaternion(0, 0, -30)
        crownModel:SetMaterial(materials.glow)
    end
    
    -- Boss眼睛（6只）
    local eyePositions = {
        {0.2, 0.2, 0.2}, {0.25, 0.15, -0.2}, {0.15, 0.25, 0},
        {0.3, 0.1, 0.1}, {0.3, 0.1, -0.1}, {0.2, 0.3, 0}
    }
    for i, data in ipairs(eyePositions) do
        local eye = hull:CreateChild("Eye" .. i)
        eye.position = Vector3(s * (0.65 + data[1] * 0.77), s * data[2] * 0.77, s * data[3] * 0.77)
        local eyeModel = eye:CreateComponent("StaticModel")
        eyeModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        eye:SetScale(s * 0.077)
        eyeModel:SetMaterial(materials.glow)
    end
    
    -- 甲壳装甲（更厚重）
    for i = 1, 4 do
        local shell = hull:CreateChild("Shell" .. i)
        shell.position = Vector3(-s * 0.115 * i, s * 0.27, 0)
        local shellModel = shell:CreateComponent("StaticModel")
        shellModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        shell:SetScale(Vector3(s * 0.35, s * 0.14, s * (0.77 - i * 0.09)))
        shellModel:SetMaterial(materials.dark)
    end
    
    -- 巨型翅膀（4对，女王特征）
    local wingMat = Materials.CreatePBR(gc.r * 0.3, gc.g * 0.1, gc.b * 0.3, 0.3, 0.15)
    for i, zSign in ipairs({1, -1}) do
        -- 主翅膀
        local wing = hull:CreateChild("BigWing" .. i)
        wing.position = Vector3(0, s * 0.19, zSign * s * 0.42)
        wing.rotation = Quaternion(zSign * 20, 0, zSign * 15)
        local wingModel = wing:CreateComponent("StaticModel")
        wingModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        wing:SetScale(Vector3(s * 0.69, s * 0.03, s * 0.46))
        wingModel:SetMaterial(wingMat)
        
        -- 副翅膀
        local wing2 = hull:CreateChild("SmallWing" .. i)
        wing2.position = Vector3(-s * 0.23, s * 0.115, zSign * s * 0.35)
        wing2.rotation = Quaternion(zSign * 10, 0, zSign * 20)
        local wingModel2 = wing2:CreateComponent("StaticModel")
        wingModel2:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        wing2:SetScale(Vector3(s * 0.38, s * 0.023, s * 0.27))
        wingModel2:SetMaterial(wingMat)
    end
    
    -- 尾部产卵器（更大）
    local tail = hull:CreateChild("Tail")
    tail.position = Vector3(-s * 0.69, -s * 0.115, 0)
    local tailModel = tail:CreateComponent("StaticModel")
    tailModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    tail:SetScale(Vector3(s * 0.46, s * 0.38, s * 0.38))
    tailModel:SetMaterial(materials.body)
    
    -- 尾刺
    local tailSpike = hull:CreateChild("TailSpike")
    tailSpike.position = Vector3(-s * 1.0, -s * 0.077, 0)
    local tailSpikeModel = tailSpike:CreateComponent("StaticModel")
    tailSpikeModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    tailSpike:SetScale(Vector3(s * 0.115, s * 0.31, s * 0.115))
    tailSpike.rotation = Quaternion(0, 0, 90)
    tailSpikeModel:SetMaterial(materials.glow)
    
    -- Boss核心（巨大发光，女王紫色）
    local core = hull:CreateChild("Core")
    core.position = Vector3(0, 0, 0)
    local coreModel = core:CreateComponent("StaticModel")
    coreModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    core:SetScale(s * 0.31)
    coreModel:SetMaterial(Materials.CreateEmissive(gc.r, gc.g, gc.b, 4.0))
    
    -- 环绕核心的能量环
    local ring = hull:CreateChild("Ring")
    ring.position = Vector3(0, 0, 0)
    local ringModel = ring:CreateComponent("StaticModel")
    ringModel:SetModel(cache:GetResource("Model", "Models/Torus.mdl"))
    ring:SetScale(Vector3(s * 0.38, s * 0.38, s * 0.077))
    ringModel:SetMaterial(Materials.CreateEmissive(gc.r, gc.g, gc.b, 2.0))
    
    -- 多引擎（6个）
    local enginePositions = {
        {-1.0, 0.15, 0.35}, {-1.0, 0.15, -0.35},
        {-1.0, -0.1, 0.2}, {-1.0, -0.1, -0.2},
        {-1.0, 0, 0.5}, {-1.0, 0, -0.5}
    }
    for i, data in ipairs(enginePositions) do
        local eng = hull:CreateChild("Eng" .. i)
        eng.position = Vector3(s * data[1] * 0.77, s * data[2] * 0.77, s * data[3] * 0.77)
        local engModel = eng:CreateComponent("StaticModel")
        engModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
        eng:SetScale(Vector3(s * 0.09, s * 0.27, s * 0.09))
        eng.rotation = Quaternion(0, 0, 90)
        engModel:SetMaterial(materials.engine)
        table.insert(flameNodes, {node = eng, baseScale = Vector3(s * 0.09, s * 0.27, s * 0.09)})
    end
    
    return flameNodes
end

return BroodQueen
