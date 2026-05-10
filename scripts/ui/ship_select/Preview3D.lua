-- ============================================================================
-- 星河战姬 Starkyries - 战舰选择界面 - 3D预览系统
-- ============================================================================

local Ships = require("config.ships")
local ShipModels = require("render.ShipModels")

local Preview3D = {}

-- ============================================================================
-- 状态
-- ============================================================================
Preview3D.scene = nil           -- 预览场景
Preview3D.camera = nil          -- 预览相机
Preview3D.cameraNode = nil      -- 相机节点
Preview3D.shipNode = nil        -- 战舰容器节点
Preview3D.hullNode = nil        -- 战舰Hull节点（用于旋转）
Preview3D.view3D = nil          -- View3D UI组件
Preview3D.modelId = nil         -- 当前预览的战舰ID
Preview3D.rotation = 0          -- 预览旋转角度（yaw）

-- 等距俯视角度（与 Player.lua 一致）
Preview3D.TILT_ANGLE = -25

-- ============================================================================
-- 初始化
-- ============================================================================

function Preview3D.Init()
    -- 清理旧的预览
    Preview3D.Cleanup()
    
    -- 创建预览场景
    Preview3D.scene = Scene()
    Preview3D.scene:CreateComponent("Octree")
    
    -- ========== 与游戏内完全相同的环境设置 ==========
    
    -- Zone: 环境光和雾效（与main.lua一致）
    local zoneNode = Preview3D.scene:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-1000.0, 1000.0)
    zone.ambientColor = Color(0.08, 0.10, 0.15)  -- 太空环境光（较暗，略带蓝色）
    zone.fogColor = Color(0.005, 0.008, 0.02)    -- 更深的太空背景
    zone.fogStart = 200.0
    zone.fogEnd = 500.0
    
    -- 主光源: 模拟远处恒星光照（从右上前方照射，与main.lua一致）
    local sunNode = Preview3D.scene:CreateChild("MainLight")
    sunNode.direction = Vector3(0.5, -0.7, 0.5)
    local sun = sunNode:CreateComponent("Light")
    sun.lightType = LIGHT_DIRECTIONAL
    sun.color = Color(1.0, 0.95, 0.9)  -- 略暖的白光
    sun.brightness = 0.8
    
    -- 辅助光源: 补光（从左下后方，与main.lua一致）
    local fillNode = Preview3D.scene:CreateChild("FillLight")
    fillNode.direction = Vector3(-0.3, 0.5, 0.2)
    local fill = fillNode:CreateComponent("Light")
    fill.lightType = LIGHT_DIRECTIONAL
    fill.color = Color(0.3, 0.4, 0.6)  -- 冷色补光
    fill.brightness = 0.2
    
    -- ========== 相机设置（与游戏内视角一致）==========
    local previewDistance = 8  -- 比游戏近一些，放大战舰
    
    Preview3D.cameraNode = Preview3D.scene:CreateChild("Camera")
    Preview3D.cameraNode.position = Vector3(0, 0, -previewDistance)
    
    Preview3D.camera = Preview3D.cameraNode:CreateComponent("Camera")
    Preview3D.camera.fov = 50  -- 与游戏相同的FOV
    Preview3D.camera.nearClip = 0.5
    Preview3D.camera.farClip = 100
    
    -- 创建战舰容器节点（用于旋转）
    Preview3D.shipNode = Preview3D.scene:CreateChild("ShipContainer")
    
    -- 重置模型ID以强制更新
    Preview3D.modelId = nil
    Preview3D.rotation = 0
end

-- ============================================================================
-- 清理
-- ============================================================================

function Preview3D.Cleanup()
    -- 清理View3D
    if Preview3D.view3D then
        Preview3D.view3D:Remove()
        Preview3D.view3D = nil
    end
    
    -- 清理场景
    if Preview3D.scene then
        Preview3D.scene:Remove()
        Preview3D.scene = nil
    end
    
    Preview3D.camera = nil
    Preview3D.cameraNode = nil
    Preview3D.shipNode = nil
    Preview3D.hullNode = nil
    Preview3D.modelId = nil
end

-- ============================================================================
-- 旋转计算
-- ============================================================================

--- 计算战舰旋转（与游戏内 Player.ComputeRotation 一致）
function Preview3D.ComputeShipRotation(yaw)
    local tiltRot = Quaternion(Preview3D.TILT_ANGLE, Vector3.RIGHT)  -- 俯视角（绕X轴）
    local directionRot = Quaternion(yaw, Vector3.UP)  -- 水平朝向（绕Y轴）
    return tiltRot * directionRot  -- 先倾斜视角，再转方向
end

-- ============================================================================
-- 模型更新
-- ============================================================================

--- 更新预览模型（当选择改变时）
function Preview3D.UpdateModel(shipId)
    if not Preview3D.scene or not Preview3D.shipNode then
        return
    end
    
    -- 如果是同一个模型，不需要重建
    if Preview3D.modelId == shipId then
        return
    end
    
    -- 清除旧模型
    Preview3D.shipNode:RemoveAllChildren()
    
    -- 获取战舰配置
    local shipConfig = Ships.Get(shipId)
    if not shipConfig then
        Preview3D.modelId = nil
        return
    end
    
    -- 创建新模型
    Preview3D.hullNode, _, _ = ShipModels.Create(shipId, Preview3D.shipNode, shipConfig)
    
    -- 应用与游戏内相同的等距俯视旋转
    if Preview3D.hullNode then
        Preview3D.hullNode.rotation = Preview3D.ComputeShipRotation(0)
    end
    
    Preview3D.modelId = shipId
    Preview3D.rotation = 0
end

--- 更新预览旋转（每帧调用）
function Preview3D.UpdateRotation(dt)
    if not Preview3D.hullNode then return end
    
    -- 缓慢旋转（与游戏内转向方式一致，绕Y轴）
    Preview3D.rotation = Preview3D.rotation + dt * 20
    
    -- 使用与游戏相同的等距俯视旋转计算
    Preview3D.hullNode.rotation = Preview3D.ComputeShipRotation(Preview3D.rotation)
end

-- ============================================================================
-- View3D 管理
-- ============================================================================

--- 创建或获取View3D组件
function Preview3D.GetOrCreateView3D(x, y, w, h)
    if not Preview3D.view3D then
        Preview3D.view3D = ui.root:CreateChild("View3D")
        Preview3D.view3D:SetView(Preview3D.scene, Preview3D.camera, false)
        Preview3D.view3D:SetAutoUpdate(true)
    end
    
    -- 更新位置和大小
    Preview3D.view3D:SetPosition(x, y)
    Preview3D.view3D:SetSize(w, h)
    Preview3D.view3D.visible = true
    
    return Preview3D.view3D
end

--- 隐藏View3D
function Preview3D.HideView3D()
    if Preview3D.view3D then
        Preview3D.view3D.visible = false
    end
end

return Preview3D
