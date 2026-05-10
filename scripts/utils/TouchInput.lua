-- ============================================================================
-- TouchInput - 触摸/鼠标位置缓存
-- 解决移动端触控弹起时 input.mousePosition 无效的问题
-- 通过订阅 Touch 事件缓存坐标，保证弹起瞬间位置仍然可用
-- ============================================================================

local TouchInput = {}

--- 缓存的鼠标/触摸位置（始终有效，即使触控弹起）
TouchInput.x = 0
TouchInput.y = 0

--- 是否检测到过触摸设备（用于区分桌面端和移动端）
TouchInput.isTouchDevice = false

--- 初始化：订阅触摸事件
function TouchInput.Init()
    SubscribeToEvent("TouchBegin", "TouchInput_OnTouchBegin")
    SubscribeToEvent("TouchMove", "TouchInput_OnTouchMove")
    SubscribeToEvent("TouchEnd", "TouchInput_OnTouchEnd")
end

--- 每帧更新（在 HandleUpdate 开头调用）
--- 桌面端：始终同步 input.mousePosition（支持 hover、滚轮等无点击场景）
--- 移动端：仅在触摸活跃时同步，弹起后保留缓存坐标
function TouchInput.Update()
    if TouchInput.isTouchDevice then
        -- 移动端：仅在触摸活跃时从 input.mousePosition 同步
        if input.numTouches > 0 then
            TouchInput.x = input.mousePosition.x
            TouchInput.y = input.mousePosition.y
        end
        -- 触控弹起时不更新，保留 TouchEnd 事件缓存的坐标
    else
        -- 桌面端：始终同步（mousePosition 始终有效）
        TouchInput.x = input.mousePosition.x
        TouchInput.y = input.mousePosition.y
    end
end

-- ============================================================================
-- 事件回调（全局函数，SubscribeToEvent 需要字符串函数名）
-- ============================================================================

function TouchInput_OnTouchBegin(eventType, eventData)
    TouchInput.isTouchDevice = true
    TouchInput.x = eventData["X"]:GetInt()
    TouchInput.y = eventData["Y"]:GetInt()
end

function TouchInput_OnTouchMove(eventType, eventData)
    TouchInput.x = eventData["X"]:GetInt()
    TouchInput.y = eventData["Y"]:GetInt()
end

function TouchInput_OnTouchEnd(eventType, eventData)
    TouchInput.x = eventData["X"]:GetInt()
    TouchInput.y = eventData["Y"]:GetInt()
end

return TouchInput
