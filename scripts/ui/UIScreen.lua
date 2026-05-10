-- ============================================================================
-- 星河战姬 Starkyries - UI 屏幕基础模块
-- 封装安全区渲染和输入处理的通用逻辑
-- ============================================================================
--
-- 使用方式：
--   local UIScreen = require("ui.UIScreen")
--   
--   -- 在 Render 中：
--   UIScreen.Render(nvg, sw, sh, MyUI, {
--       drawBackground = MyUI.DrawBackground,  -- 全屏背景（可选）
--       drawContent = MyUI.DrawContent,        -- 安全区内容（必需）
--   })
--   
--   -- 在 HandleTouch 中：
--   UIScreen.HandleTouch(sw, sh, MyUI, MyUI.OnTouch)
--
-- ============================================================================

local UISafeArea = require("ui.UISafeArea")
local UIStyle = require("ui.UIStyle")
local TouchInput = require("utils.TouchInput")

local UIScreen = {}

-- ============================================================================
-- 按钮按下状态管理
-- ============================================================================
-- 实现按下/释放交互模式：
-- 1. 用户按下时，按钮进入pressed状态，显示按下效果
-- 2. 用户释放时，如果仍在按钮上，才触发点击事件
-- 3. 用户拖拽离开后释放，不触发点击

UIScreen.pressedButtonId = nil      -- 当前被按下的按钮ID
UIScreen.pressedButtonRect = nil    -- 被按下按钮的区域 {x, y, w, h}

-- 点击防抖配置
UIScreen.lastClickTime = 0          -- 上次成功点击的时间
UIScreen.debounceTime = 0.15        -- 防抖间隔（秒），防止快速连点

--- 开始按下按钮（在 MouseDown 时调用）
---@param buttonId string 按钮唯一标识
---@param rect table 按钮区域 {x, y, w, h}
function UIScreen.BeginPress(buttonId, rect)
    UIScreen.pressedButtonId = buttonId
    UIScreen.pressedButtonRect = rect
end

--- 取消按下状态（在需要时调用）
function UIScreen.CancelPress()
    UIScreen.pressedButtonId = nil
    UIScreen.pressedButtonRect = nil
end

--- 结束按下并检查是否触发点击（在 MouseUp 时调用）
---@param mx number 鼠标X
---@param my number 鼠标Y
---@param buttonId string 按钮唯一标识
---@return boolean 是否应该触发点击
function UIScreen.EndPress(mx, my, buttonId)
    print(string.format("[UIScreen.EndPress] buttonId=%s, pressedId=%s", 
        tostring(buttonId), tostring(UIScreen.pressedButtonId)))
    
    if UIScreen.pressedButtonId ~= buttonId then
        print("[UIScreen.EndPress] SKIP: buttonId mismatch")
        return false
    end
    
    local r = UIScreen.pressedButtonRect
    local triggered = r and UIScreen.HitTest(mx, my, r.x, r.y, r.w, r.h)
    print(string.format("[UIScreen.EndPress] HitTest=%s", tostring(triggered)))
    
    -- 清除按下状态
    UIScreen.pressedButtonId = nil
    UIScreen.pressedButtonRect = nil
    
    -- 防抖检查：如果距离上次点击时间太短，忽略此次点击
    if triggered then
        local now = time.elapsedTime  -- 使用引擎时间，而非 os.clock()
        local timeSince = now - UIScreen.lastClickTime
        print(string.format("[UIScreen.EndPress] now=%.3f lastClick=%.3f timeSince=%.3f debounce=%.3f", 
            now, UIScreen.lastClickTime, timeSince, UIScreen.debounceTime))
        if timeSince < UIScreen.debounceTime then
            print("[UIScreen.EndPress] BLOCKED by debounce!")
            return false  -- 防抖：忽略快速连点
        end
        UIScreen.lastClickTime = now
    end
    
    print(string.format("[UIScreen.EndPress] RESULT: %s", tostring(triggered)))
    return triggered
end

--- 检查按钮是否正在被按下
---@param buttonId string 按钮唯一标识
---@return boolean
function UIScreen.IsButtonPressed(buttonId)
    return UIScreen.pressedButtonId == buttonId
end

--- 检查鼠标是否在被按下的按钮上（用于视觉反馈）
---@param mx number 鼠标X
---@param my number 鼠标Y
---@param buttonId string 按钮唯一标识
---@return boolean 是否显示按下效果
function UIScreen.ShouldShowPressed(mx, my, buttonId)
    if UIScreen.pressedButtonId ~= buttonId then
        return false
    end
    local r = UIScreen.pressedButtonRect
    return r and UIScreen.HitTest(mx, my, r.x, r.y, r.w, r.h)
end

--- 每帧更新（在没有鼠标按住时自动清除状态）
function UIScreen.UpdateButtonState()
    if UIScreen.pressedButtonId and not input:GetMouseButtonDown(MOUSEB_LEFT) then
        UIScreen.pressedButtonId = nil
        UIScreen.pressedButtonRect = nil
    end
end

--- 处理按钮的按下检测（便捷方法，在 MouseDown 时使用）
---@param mx number 鼠标X
---@param my number 鼠标Y
---@param buttonId string 按钮唯一标识
---@param x number 按钮X
---@param y number 按钮Y
---@param w number 按钮宽度
---@param h number 按钮高度
---@return boolean 是否按下了此按钮
function UIScreen.CheckButtonPress(mx, my, buttonId, x, y, w, h)
    if UIScreen.HitTest(mx, my, x, y, w, h) then
        UIScreen.BeginPress(buttonId, {x = x, y = y, w = w, h = h})
        return true
    end
    return false
end

--- 处理按钮的释放检测（便捷方法，在 MouseUp 时使用）
---@param mx number 鼠标X
---@param my number 鼠标Y
---@param buttonId string 按钮唯一标识
---@return boolean 是否应该触发点击
function UIScreen.CheckButtonRelease(mx, my, buttonId)
    return UIScreen.EndPress(mx, my, buttonId)
end

-- ============================================================================
-- 默认背景
-- ============================================================================

--- 默认深空背景
function UIScreen.DefaultBackground(nvg, sw, sh, baseUnit)
    -- 深空渐变
    local bgGrad = nvgLinearGradient(nvg, 0, 0, 0, sh,
        nvgRGBA(12, 16, 32, 255),
        nvgRGBA(6, 10, 22, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillPaint(nvg, bgGrad)
    nvgFill(nvg)
end

--- 纯色深色背景
function UIScreen.SolidBackground(nvg, sw, sh, baseUnit)
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(10, 16, 28, 250))
    nvgFill(nvg)
end

-- ============================================================================
-- 渲染流程
-- ============================================================================

--- 标准渲染流程
---@param nvg userdata NanoVG 上下文
---@param sw number 屏幕宽度
---@param sh number 屏幕高度
---@param screen table UI模块（用于缓存 safeArea）
---@param options table 渲染选项
---  - drawBackground: function(nvg, sw, sh, baseUnit) 全屏背景绘制
---  - drawContent: function(nvg, uw, uh, baseUnit, fonts, safe) 安全区内容绘制
---  - useMask: boolean 是否绘制安全区外遮罩（默认false）
---@return table safe 安全区信息
function UIScreen.Render(nvg, sw, sh, screen, options)
    options = options or {}
    
    -- 计算并缓存安全区
    local safe = UISafeArea.Calculate(sw, sh)
    screen.safeArea = safe
    
    -- 1. 全屏背景层
    if options.drawBackground then
        options.drawBackground(nvg, sw, sh, safe.baseUnit)
    else
        UIScreen.SolidBackground(nvg, sw, sh, safe.baseUnit)
    end
    
    -- 2. 安全区外遮罩（可选，默认不绘制）
    if options.useMask then
        UISafeArea.DrawMask(nvg, safe)
    end
    
    -- 3. 安全区内容
    UISafeArea.BeginSafeArea(nvg, safe)
    
    local uw, uh = safe.w, safe.h
    local baseUnit = safe.baseUnit
    local fonts = UISafeArea.GetTypography(safe)
    
    if options.drawContent then
        options.drawContent(nvg, uw, uh, baseUnit, fonts, safe)
    end
    
    UISafeArea.EndSafeArea(nvg)
    
    -- 4. 调试边框
    UISafeArea.DrawDebugBorder(nvg, safe)
    
    return safe
end

-- ============================================================================
-- 输入处理
-- ============================================================================

--- 标准触摸/点击处理
---@param sw number 屏幕宽度
---@param sh number 屏幕高度
---@param screen table UI模块（包含 safeArea 缓存）
---@param onTouch function(mx, my, uw, uh, safe) 处理函数，接收安全区本地坐标
---@return boolean 是否处理了输入
function UIScreen.HandleTouch(sw, sh, screen, onTouch)
    -- 获取安全区（优先使用缓存）
    local safe = screen.safeArea or UISafeArea.Calculate(sw, sh)
    
    -- 获取屏幕坐标
    local screenX = TouchInput.x
    local screenY = TouchInput.y
    
    -- 检查是否在安全区内
    if not UISafeArea.Contains(safe, screenX, screenY) then
        return false
    end
    
    -- 转换为安全区本地坐标
    local mx, my = UISafeArea.ToLocal(safe, screenX, screenY)
    
    -- 调用处理函数
    if onTouch then
        return onTouch(mx, my, safe.w, safe.h, safe)
    end
    
    return false
end

-- 鼠标状态跟踪（用于释放检测）
UIScreen.wasMouseDown = false

--- 检查鼠标按下（便捷方法）
---@return boolean
function UIScreen.IsMousePressed()
    return input:GetMouseButtonPress(MOUSEB_LEFT)
end

--- 检查鼠标释放（便捷方法）
--- 需要每帧调用 UpdateMouseState() 来更新状态
---@return boolean
function UIScreen.IsMouseReleased()
    local isDown = input:GetMouseButtonDown(MOUSEB_LEFT)
    -- 上一帧按下，这一帧松开 = 释放
    if UIScreen.wasMouseDown and not isDown then
        return true
    end
    return false
end

--- 更新鼠标状态（需要在每帧结束时调用）
function UIScreen.UpdateMouseState()
    UIScreen.wasMouseDown = input:GetMouseButtonDown(MOUSEB_LEFT)
end

--- 检查鼠标按住（便捷方法）
---@return boolean
function UIScreen.IsMouseDown()
    return input:GetMouseButtonDown(MOUSEB_LEFT)
end

--- 获取鼠标在安全区内的本地坐标
---@param screen table UI模块（包含 safeArea 缓存）
---@param sw number 屏幕宽度（备用）
---@param sh number 屏幕高度（备用）
---@return number|nil mx 本地X（如果在安全区外返回nil）
---@return number|nil my 本地Y
---@return table safe 安全区信息
function UIScreen.GetLocalMouse(screen, sw, sh)
    local safe = screen.safeArea or UISafeArea.Calculate(sw, sh)
    local screenX = TouchInput.x
    local screenY = TouchInput.y
    
    if not UISafeArea.Contains(safe, screenX, screenY) then
        return nil, nil, safe
    end
    
    local mx, my = UISafeArea.ToLocal(safe, screenX, screenY)
    return mx, my, safe
end

-- ============================================================================
-- 布局辅助
-- ============================================================================

--- 计算居中位置
---@param containerW number 容器宽度
---@param itemW number 项目宽度
---@return number x 居中的X坐标
function UIScreen.CenterX(containerW, itemW)
    return (containerW - itemW) / 2
end

--- 计算居中位置
---@param containerH number 容器高度
---@param itemH number 项目高度
---@return number y 居中的Y坐标
function UIScreen.CenterY(containerH, itemH)
    return (containerH - itemH) / 2
end

--- 计算垂直列表布局
---@param startY number 起始Y
---@param itemH number 项目高度
---@param gap number 间距
---@param index number 索引（从1开始）
---@return number y 项目Y坐标
function UIScreen.ListY(startY, itemH, gap, index)
    return startY + (index - 1) * (itemH + gap)
end

--- 计算网格布局位置
---@param startX number 起始X
---@param startY number 起始Y
---@param itemW number 项目宽度
---@param itemH number 项目高度
---@param gapX number 横向间距
---@param gapY number 纵向间距
---@param columns number 列数
---@param index number 索引（从1开始）
---@return number x, number y 项目坐标
function UIScreen.GridXY(startX, startY, itemW, itemH, gapX, gapY, columns, index)
    local col = (index - 1) % columns
    local row = math.floor((index - 1) / columns)
    local x = startX + col * (itemW + gapX)
    local y = startY + row * (itemH + gapY)
    return x, y
end

--- 检查点击是否命中矩形区域
---@param mx number 鼠标X
---@param my number 鼠标Y
---@param x number 矩形X
---@param y number 矩形Y
---@param w number 矩形宽度
---@param h number 矩形高度
---@return boolean
function UIScreen.HitTest(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

return UIScreen
