-- ============================================================================
-- 星河战姬 Starkyries - 相机控制器
-- 负责相机跟随、参数计算、屏幕适配
-- ============================================================================

local Settings = require("config.settings")

local CameraController = {}

-- ============================================================================
-- 状态
-- ============================================================================
CameraController.node = nil
CameraController.params = {
    distance = 30,
    visibleWidth = 40,
    visibleHeight = 28,
    lastScreenW = 0,
    lastScreenH = 0,
}

-- ============================================================================
-- 初始化
-- ============================================================================

function CameraController.Init(scene, cameraNode)
    CameraController.node = cameraNode
    CameraController.params = {
        distance = 30,
        visibleWidth = 40,
        visibleHeight = 28,
        lastScreenW = 0,
        lastScreenH = 0,
    }
end

-- ============================================================================
-- 参数更新（屏幕尺寸变化时调用）
-- ============================================================================

function CameraController.UpdateParams()
    local screenW = graphics:GetWidth()
    local screenH = graphics:GetHeight()
    local params = CameraController.params
    
    -- 屏幕尺寸未变化则跳过
    if screenW == params.lastScreenW and screenH == params.lastScreenH then
        return
    end
    params.lastScreenW = screenW
    params.lastScreenH = screenH
    
    local aspectRatio = screenW / screenH
    local visConfig = Settings.VisibleArea
    local camConfig = Settings.Camera
    
    local visibleWidth, visibleHeight
    
    if aspectRatio >= 1 then
        -- 横屏：高度是短边
        visibleHeight = visConfig.MinSize
        visibleWidth = math.min(visConfig.MinSize * aspectRatio, visConfig.MaxSize)
    else
        -- 竖屏：宽度是短边
        visibleWidth = visConfig.MinSize
        visibleHeight = math.min(visConfig.MinSize / aspectRatio, visConfig.MaxSize)
    end
    
    -- 计算相机距离：visibleHeight = 2 * distance * tan(FOV/2)
    local halfFovRad = math.rad(camConfig.FOV / 2)
    local distance = visibleHeight / (2 * math.tan(halfFovRad))
    
    params.distance = distance
    params.visibleWidth = visibleWidth
    params.visibleHeight = visibleHeight
    
    -- 更新相机Z位置
    if CameraController.node then
        local pos = CameraController.node.position
        CameraController.node.position = Vector3(pos.x, pos.y, -distance)
    end
end

-- ============================================================================
-- 相机跟随更新
-- ============================================================================

function CameraController.Update(dt, playerX, playerY)
    if not CameraController.node then return end
    
    -- 检查并更新相机参数（处理屏幕旋转/缩放）
    CameraController.UpdateParams()
    
    local camConfig = Settings.Camera
    local arena = Settings.BattleArea
    local params = CameraController.params
    
    -- 计算相机目标位置（跟随玩家）
    local targetX, targetY = playerX, playerY
    
    -- 限制相机位置，使可视区域不超出竞技场边界
    local halfVisibleW = params.visibleWidth / 2
    local halfVisibleH = params.visibleHeight / 2
    
    -- 相机X边界
    local minCamX = arena.MinX + halfVisibleW
    local maxCamX = arena.MaxX - halfVisibleW
    -- 相机Y边界
    local minCamY = arena.MinY + halfVisibleH
    local maxCamY = arena.MaxY - halfVisibleH
    
    -- 如果竞技场比可视区域小，则居中
    if minCamX > maxCamX then
        targetX = (arena.MinX + arena.MaxX) / 2
    else
        targetX = math.max(minCamX, math.min(maxCamX, targetX))
    end
    
    if minCamY > maxCamY then
        targetY = (arena.MinY + arena.MaxY) / 2
    else
        targetY = math.max(minCamY, math.min(maxCamY, targetY))
    end
    
    -- 平滑跟随
    local currentPos = CameraController.node.position
    local smoothing = camConfig.FollowSmoothing * dt
    smoothing = math.min(smoothing, 1.0)
    
    local newX = currentPos.x + (targetX - currentPos.x) * smoothing
    local newY = currentPos.y + (targetY - currentPos.y) * smoothing
    
    -- 更新相机位置
    CameraController.node.position = Vector3(newX, newY, -params.distance)
end

-- ============================================================================
-- 获取可视区域
-- ============================================================================

function CameraController.GetVisibleArea()
    if not CameraController.node then return nil end
    
    local camPos = CameraController.node.position
    local params = CameraController.params
    local halfW = params.visibleWidth / 2
    local halfH = params.visibleHeight / 2
    
    return {
        minX = camPos.x - halfW,
        maxX = camPos.x + halfW,
        minY = camPos.y - halfH,
        maxY = camPos.y + halfH,
    }
end

-- ============================================================================
-- 获取相机参数
-- ============================================================================

function CameraController.GetParams()
    return CameraController.params
end

-- 重置相机位置（立即移动到目标位置，不使用平滑跟随）
function CameraController.ResetToPosition(x, y)
    if not CameraController.node then return end
    
    CameraController.UpdateParams()
    local params = CameraController.params
    CameraController.node.position = Vector3(x, y, -params.distance)
end

-- 重置相机到中心位置
function CameraController.ResetToCenter()
    CameraController.ResetToPosition(0, 0)
end

function CameraController.GetNode()
    return CameraController.node
end

return CameraController
