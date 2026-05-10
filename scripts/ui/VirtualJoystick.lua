-- ============================================================================
-- 星河战姬 Starkyries - 虚拟摇杆（浮动模式）
-- 移动端触摸输入控制
-- 用户在屏幕任意位置开始拖动时显示，松开后隐藏
-- ============================================================================

local TouchInput = require("utils.TouchInput")

local VirtualJoystick = {}

-- ============================================================================
-- 配置
-- ============================================================================
VirtualJoystick.config = {
    -- 外圈半径（相对于屏幕短边的比例）
    outerRadiusRatio = 0.1,
    -- 内圈半径（相对于外圈的比例）
    innerRadiusRatio = 0.4,
    -- 死区（0-1）
    deadZone = 0.15,
    -- 透明度
    alphaActive = 200,
    -- 淡出时间
    fadeOutTime = 0.15,
    -- 拖动阈值（像素），超过此距离才显示摇杆
    dragThreshold = 10,
}

-- ============================================================================
-- 状态
-- ============================================================================
VirtualJoystick.enabled = false
VirtualJoystick.active = false       -- 是否正在触摸
VirtualJoystick.dragging = false     -- 是否已开始拖动（超过阈值）
VirtualJoystick.visible = false      -- 是否显示（用于淡出效果）
VirtualJoystick.touchId = -1         -- 当前触摸ID
VirtualJoystick.startX = 0           -- 触摸起始X
VirtualJoystick.startY = 0           -- 触摸起始Y
VirtualJoystick.centerX = 0          -- 摇杆中心X（屏幕坐标）
VirtualJoystick.centerY = 0          -- 摇杆中心Y（屏幕坐标）
VirtualJoystick.stickX = 0           -- 摇杆位置X（-1到1）
VirtualJoystick.stickY = 0           -- 摇杆位置Y（-1到1）
VirtualJoystick.outerRadius = 0      -- 外圈半径（像素）
VirtualJoystick.innerRadius = 0      -- 内圈半径（像素）
VirtualJoystick.fadeAlpha = 0        -- 当前透明度（用于淡出）
VirtualJoystick.screenWidth = 0
VirtualJoystick.screenHeight = 0

-- ============================================================================
-- 初始化
-- ============================================================================

function VirtualJoystick.Init(options)
    options = options or {}
    
    -- 合并配置
    for k, v in pairs(options) do
        if VirtualJoystick.config[k] ~= nil then
            VirtualJoystick.config[k] = v
        end
    end
    
    -- 检测是否为移动端（触摸设备）
    VirtualJoystick.enabled = input.touchEmulation or input.numTouches > 0
    
    -- 也可以手动启用
    if options.forceEnable then
        VirtualJoystick.enabled = true
    end
end

-- ============================================================================
-- 启用/禁用
-- ============================================================================

function VirtualJoystick.SetEnabled(enabled)
    VirtualJoystick.enabled = enabled
    if not enabled then
        VirtualJoystick.Reset()
    end
end

function VirtualJoystick.IsEnabled()
    return VirtualJoystick.enabled
end

-- ============================================================================
-- 重置状态
-- ============================================================================

function VirtualJoystick.Reset()
    VirtualJoystick.active = false
    VirtualJoystick.dragging = false
    VirtualJoystick.touchId = -1
    VirtualJoystick.stickX = 0
    VirtualJoystick.stickY = 0
end

-- ============================================================================
-- 更新（每帧调用）
-- ============================================================================

function VirtualJoystick.Update(sw, sh)
    if not VirtualJoystick.enabled then return end
    
    VirtualJoystick.screenWidth = sw
    VirtualJoystick.screenHeight = sh
    
    -- 计算摇杆大小
    local baseSize = math.min(sw, sh)
    VirtualJoystick.outerRadius = baseSize * VirtualJoystick.config.outerRadiusRatio
    VirtualJoystick.innerRadius = VirtualJoystick.outerRadius * VirtualJoystick.config.innerRadiusRatio
    
    local threshold = VirtualJoystick.config.dragThreshold
    
    -- 处理触摸输入
    local touchCount = input.numTouches
    
    -- 如果当前有活动触摸，检查是否还存在
    if VirtualJoystick.active and VirtualJoystick.touchId >= 0 then
        local found = false
        for i = 0, touchCount - 1 do
            local touch = input:GetTouch(i)
            if touch.touchID == VirtualJoystick.touchId then
                found = true
                local tx, ty = touch.position.x, touch.position.y
                
                -- 检查是否超过拖动阈值
                if not VirtualJoystick.dragging then
                    local dx = tx - VirtualJoystick.startX
                    local dy = ty - VirtualJoystick.startY
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist >= threshold then
                        -- 开始拖动，显示摇杆
                        VirtualJoystick.dragging = true
                        VirtualJoystick.visible = true
                        VirtualJoystick.fadeAlpha = VirtualJoystick.config.alphaActive
                        VirtualJoystick.centerX = VirtualJoystick.startX
                        VirtualJoystick.centerY = VirtualJoystick.startY
                    end
                end
                
                -- 更新摇杆位置
                if VirtualJoystick.dragging then
                    VirtualJoystick.UpdateStickPosition(tx, ty)
                end
                break
            end
        end
        
        -- 触摸结束
        if not found then
            VirtualJoystick.Reset()
        end
    end
    
    -- 寻找新的触摸（全屏任意位置）
    if not VirtualJoystick.active then
        for i = 0, touchCount - 1 do
            local touch = input:GetTouch(i)
            VirtualJoystick.active = true
            VirtualJoystick.dragging = false  -- 还未开始拖动
            VirtualJoystick.touchId = touch.touchID
            VirtualJoystick.startX = touch.position.x
            VirtualJoystick.startY = touch.position.y
            VirtualJoystick.stickX = 0
            VirtualJoystick.stickY = 0
            break
        end
    end
    
    -- 鼠标模拟（用于桌面测试）
    if not VirtualJoystick.active and input:GetMouseButtonPress(MOUSEB_LEFT) then
        local mx = TouchInput.x
        local my = TouchInput.y
        
        VirtualJoystick.active = true
        VirtualJoystick.dragging = false
        VirtualJoystick.touchId = -999  -- 特殊ID表示鼠标
        VirtualJoystick.startX = mx
        VirtualJoystick.startY = my
        VirtualJoystick.stickX = 0
        VirtualJoystick.stickY = 0
    elseif VirtualJoystick.touchId == -999 then
        if input:GetMouseButtonDown(MOUSEB_LEFT) then
            local mx = TouchInput.x
            local my = TouchInput.y
            
            -- 检查是否超过拖动阈值
            if not VirtualJoystick.dragging then
                local dx = mx - VirtualJoystick.startX
                local dy = my - VirtualJoystick.startY
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist >= threshold then
                    VirtualJoystick.dragging = true
                    VirtualJoystick.visible = true
                    VirtualJoystick.fadeAlpha = VirtualJoystick.config.alphaActive
                    VirtualJoystick.centerX = VirtualJoystick.startX
                    VirtualJoystick.centerY = VirtualJoystick.startY
                end
            end
            
            if VirtualJoystick.dragging then
                VirtualJoystick.UpdateStickPosition(mx, my)
            end
        else
            VirtualJoystick.Reset()
        end
    end
    
    -- 更新淡出效果
    if not VirtualJoystick.active and VirtualJoystick.visible then
        VirtualJoystick.fadeAlpha = VirtualJoystick.fadeAlpha - (VirtualJoystick.config.alphaActive / VirtualJoystick.config.fadeOutTime) * (1/60)
        if VirtualJoystick.fadeAlpha <= 0 then
            VirtualJoystick.fadeAlpha = 0
            VirtualJoystick.visible = false
        end
    end
end

-- ============================================================================
-- 更新摇杆位置
-- ============================================================================

function VirtualJoystick.UpdateStickPosition(touchX, touchY)
    local dx = touchX - VirtualJoystick.centerX
    local dy = touchY - VirtualJoystick.centerY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    -- 限制在外圈范围内
    local maxDist = VirtualJoystick.outerRadius
    if dist > maxDist then
        dx = dx * maxDist / dist
        dy = dy * maxDist / dist
        dist = maxDist
    end
    
    -- 归一化到 -1 到 1
    VirtualJoystick.stickX = dx / maxDist
    VirtualJoystick.stickY = -dy / maxDist  -- Y轴反转（屏幕Y向下，游戏Y向上）
    
    -- 应用死区
    local magnitude = math.sqrt(VirtualJoystick.stickX * VirtualJoystick.stickX + 
                                VirtualJoystick.stickY * VirtualJoystick.stickY)
    if magnitude < VirtualJoystick.config.deadZone then
        VirtualJoystick.stickX = 0
        VirtualJoystick.stickY = 0
    else
        -- 重新映射死区外的值
        local factor = (magnitude - VirtualJoystick.config.deadZone) / (1 - VirtualJoystick.config.deadZone)
        factor = factor / magnitude  -- 归一化
        VirtualJoystick.stickX = VirtualJoystick.stickX * factor
        VirtualJoystick.stickY = VirtualJoystick.stickY * factor
    end
end

-- ============================================================================
-- 获取输入值
-- ============================================================================

function VirtualJoystick.GetX()
    if not VirtualJoystick.enabled then return 0 end
    return VirtualJoystick.stickX
end

function VirtualJoystick.GetY()
    if not VirtualJoystick.enabled then return 0 end
    return VirtualJoystick.stickY
end

function VirtualJoystick.GetDirection()
    return VirtualJoystick.GetX(), VirtualJoystick.GetY()
end

function VirtualJoystick.IsActive()
    return VirtualJoystick.active
end

-- ============================================================================
-- 渲染
-- ============================================================================

function VirtualJoystick.Render(nvg, sw, sh)
    if not VirtualJoystick.enabled then return end
    if not VirtualJoystick.visible then return end
    
    local cx = VirtualJoystick.centerX
    local cy = VirtualJoystick.centerY
    local outerR = VirtualJoystick.outerRadius
    local innerR = VirtualJoystick.innerRadius
    
    local alpha = VirtualJoystick.fadeAlpha
    if alpha <= 0 then return end
    
    -- 外圈背景
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, outerR)
    nvgFillColor(nvg, nvgRGBA(30, 40, 60, alpha * 0.5))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(80, 120, 180, alpha * 0.8))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
    
    -- 方向指示线（十字）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - outerR * 0.5, cy)
    nvgLineTo(nvg, cx + outerR * 0.5, cy)
    nvgMoveTo(nvg, cx, cy - outerR * 0.5)
    nvgLineTo(nvg, cx, cy + outerR * 0.5)
    nvgStrokeColor(nvg, nvgRGBA(60, 90, 140, alpha * 0.4))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- 内圈（摇杆球）
    local stickOffsetX = VirtualJoystick.stickX * (outerR - innerR)
    local stickOffsetY = -VirtualJoystick.stickY * (outerR - innerR)  -- Y轴反转
    
    local stickCx = cx + stickOffsetX
    local stickCy = cy + stickOffsetY
    
    -- 摇杆球阴影
    nvgBeginPath(nvg)
    nvgCircle(nvg, stickCx + 2, stickCy + 2, innerR)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, alpha * 0.25))
    nvgFill(nvg)
    
    -- 摇杆球主体
    nvgBeginPath(nvg)
    nvgCircle(nvg, stickCx, stickCy, innerR)
    
    -- 渐变填充
    local gradient = nvgRadialGradient(nvg, stickCx - innerR * 0.3, stickCy - innerR * 0.3, 
                                       innerR * 0.2, innerR,
                                       nvgRGBA(120, 160, 220, alpha),
                                       nvgRGBA(60, 90, 140, alpha))
    nvgFillPaint(nvg, gradient)
    nvgFill(nvg)
    
    -- 摇杆球边框
    nvgStrokeColor(nvg, nvgRGBA(100, 150, 200, alpha * 0.9))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
end

return VirtualJoystick
