-- ============================================================================
-- 星河战姬 Starkyries - 场景管理
-- ============================================================================

local Settings = require("config.settings")
local Materials = require("render.Materials")

local Scene = {}

-- 场景引用
Scene.scene = nil
Scene.cameraNode = nil
Scene.camera = nil

-- ============================================================================
-- 场景初始化
-- ============================================================================

function Scene.Create()
    -- 创建场景
    Scene.scene = Scene()
    Scene.scene:CreateComponent("Octree")
    Scene.scene:CreateComponent("DebugRenderer")
    
    -- 创建太空光照环境
    -- Zone: 环境光和雾效
    local zoneNode = Scene.scene:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-1000.0, 1000.0)
    zone.ambientColor = Color(0.08, 0.10, 0.15)  -- 太空环境光（较暗，略带蓝色）
    zone.fogColor = Color(0.005, 0.008, 0.02)    -- 更深的太空背景
    zone.fogStart = 200.0
    zone.fogEnd = 500.0
    
    -- 主光源: 模拟远处恒星光照（从右上方照射）
    local sunNode = Scene.scene:CreateChild("MainLight")
    sunNode.direction = Vector3(0.5, -0.7, 0.5)  -- 从右上前方照射
    local sun = sunNode:CreateComponent("Light")
    sun.lightType = LIGHT_DIRECTIONAL
    sun.color = Color(1.0, 0.95, 0.9)            -- 略暖的白光
    sun.brightness = 0.8                          -- 降低亮度
    sun.specularIntensity = 0.8                   -- 高光强度
    
    -- 辅助光源: 补光（从左下方，较弱）
    local fillNode = Scene.scene:CreateChild("FillLight")
    fillNode.direction = Vector3(-0.3, 0.5, 0.2)  -- 从左下后方
    local fill = fillNode:CreateComponent("Light")
    fill.lightType = LIGHT_DIRECTIONAL
    fill.color = Color(0.3, 0.4, 0.6)             -- 冷色补光
    fill.brightness = 0.2                          -- 较弱亮度
    
    -- 创建相机
    Scene.CreateCamera()
    
    return Scene.scene
end

-- 创建相机（横版视角，看向Z轴正方向）
function Scene.CreateCamera()
    local camConfig = Settings.Camera
    
    Scene.cameraNode = Scene.scene:CreateChild("Camera")
    Scene.cameraNode.position = Vector3(0, 0, -camConfig.Distance)
    
    Scene.camera = Scene.cameraNode:CreateComponent("Camera")
    Scene.camera.fov = camConfig.FOV
    Scene.camera.nearClip = camConfig.NearClip
    Scene.camera.farClip = camConfig.FarClip
    
    -- 设置视口
    renderer:SetViewport(0, Viewport:new(Scene.scene, Scene.camera))
    
    return Scene.cameraNode
end

-- ============================================================================
-- 相机控制
-- ============================================================================

-- 相机震动
local shake = {intensity = 0, duration = 0}

function Scene.Shake(intensity, duration)
    shake.intensity = intensity
    shake.duration = duration
end

function Scene.UpdateShake(dt)
    if shake.duration > 0 then
        shake.duration = shake.duration - dt
        local shakeAmount = shake.intensity * (shake.duration / Settings.Visual.ScreenShakeDuration)
        
        local offsetX = (math.random() - 0.5) * 2 * shakeAmount
        local offsetY = (math.random() - 0.5) * 2 * shakeAmount
        
        Scene.cameraNode.position = Vector3(offsetX, offsetY, -Settings.Camera.Distance)
    else
        Scene.cameraNode.position = Vector3(0, 0, -Settings.Camera.Distance)
    end
end

-- 世界坐标转屏幕坐标
function Scene.WorldToScreen(worldPos)
    if Scene.camera then
        local screenPos = Scene.camera:WorldToScreenPoint(worldPos)
        local sw = graphics:GetWidth()
        local sh = graphics:GetHeight()
        return screenPos.x * sw, screenPos.y * sh
    end
    return 0, 0
end

-- ============================================================================
-- 节点创建辅助
-- ============================================================================

-- 创建带模型的节点
function Scene.CreateModelNode(name, modelPath, material, position, scale)
    local node = Scene.scene:CreateChild(name)
    
    if position then
        node.position = position
    end
    
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", modelPath))
    
    if material then
        model:SetMaterial(material)
    end
    
    if scale then
        if type(scale) == "number" then
            node:SetScale(scale)
        else
            node:SetScale(scale)
        end
    end
    
    return node, model
end

-- 创建球体节点
function Scene.CreateSphere(name, material, position, scale)
    return Scene.CreateModelNode(name, "Models/Sphere.mdl", material, position, scale)
end

-- 创建立方体节点
function Scene.CreateBox(name, material, position, scale)
    return Scene.CreateModelNode(name, "Models/Box.mdl", material, position, scale)
end

-- 创建圆柱体节点
function Scene.CreateCylinder(name, material, position, scale)
    return Scene.CreateModelNode(name, "Models/Cylinder.mdl", material, position, scale)
end

-- 创建圆锥体节点
function Scene.CreateCone(name, material, position, scale)
    return Scene.CreateModelNode(name, "Models/Cone.mdl", material, position, scale)
end

-- 创建圆环节点
function Scene.CreateTorus(name, material, position, scale)
    return Scene.CreateModelNode(name, "Models/Torus.mdl", material, position, scale)
end

-- ============================================================================
-- 清理
-- ============================================================================

function Scene.Clear()
    if Scene.scene then
        -- 保留相机和光照，清理其他节点
        local children = {}
        for i = 0, Scene.scene:GetNumChildren() - 1 do
            local child = Scene.scene:GetChild(i)
            local name = child.name
            if name ~= "Camera" and name ~= "LightGroup" then
                table.insert(children, child)
            end
        end
        
        for _, child in ipairs(children) do
            child:Remove()
        end
    end
end

return Scene
