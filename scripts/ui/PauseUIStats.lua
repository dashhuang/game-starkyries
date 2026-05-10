-- ============================================================================
-- PauseUIStats - 暂停菜单属性面板渲染
-- 从 PauseUI.lua 拆分，负责属性标签页和滚动列表
-- ============================================================================

local UIStyle = require("ui.UIStyle")
local UIScreen = require("ui.UIScreen")
local UISafeArea = require("ui.UISafeArea")
local Overlays = require("ui.Overlays")
local TouchInput = require("utils.TouchInput")

local PauseUIStats = {}

--- 渲染属性面板（与Overlays.RenderBridgeUpgrade共用逻辑）
---@param PauseUI table 主模块引用（读写 state）
function PauseUIStats.Render(nvg, x, y, w, h, baseUnit, fonts, player, PauseUI)
    -- 保存面板区域（用于拖动检测）
    PauseUI.statsPanelRect = {x = x, y = y, w = w, h = h}

    -- 面板背景（与Overlays一致）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.4)
    nvgFillColor(nvg, nvgRGBA(20, 25, 35, 245))
    nvgFill(nvg)

    -- 面板边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.4)
    nvgStrokeWidth(nvg, 2)
    nvgStrokeColor(nvg, nvgRGBA(60, 70, 90, 200))
    nvgStroke(nvg)

    -- 标题栏布局（基于字体大小）
    local titleFontSize = fonts.cardTitle
    local tabFontSize = fonts.description
    local titlePadding = baseUnit * 0.25
    local tabBtnH = tabFontSize * 1.6
    local titleBarH = titlePadding + titleFontSize + baseUnit * 0.2 + tabBtnH + titlePadding

    -- 标题栏背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, titleBarH, baseUnit * 0.4)
    nvgFillColor(nvg, nvgRGBA(40, 50, 70, 220))
    nvgFill(nvg)

    -- 标题
    nvgFontSize(nvg, titleFontSize)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(200, 210, 220, 255))
    nvgText(nvg, x + w / 2, y + titlePadding, "属性")

    -- 标签页按钮
    local tabBtnW = w * 0.35
    local tabBtnY = y + titlePadding + titleFontSize + baseUnit * 0.15
    local tabGap = baseUnit * 0.5
    local tabStartX = x + (w - tabBtnW * 2 - tabGap) / 2

    -- 获取鼠标位置用于按下状态检测
    local safe = PauseUI.safeArea
    local mx, my = nil, nil
    if safe then
        local screenX = TouchInput.x
        local screenY = TouchInput.y
        if UISafeArea.Contains(safe, screenX, screenY) then
            mx, my = UISafeArea.ToLocal(safe, screenX, screenY)
        end
    end

    local tabs = {"主要", "次要"}
    for i, tabName in ipairs(tabs) do
        local tabX = tabStartX + (i - 1) * (tabBtnW + tabGap)
        local isActive = (PauseUI.statsTab == i)
        local buttonId = "pause_tab_" .. i
        local isPressed = mx and my and UIScreen.ShouldShowPressed(mx, my, buttonId)

        -- 按下时的偏移
        local offsetY = isPressed and 1 or 0
        local actualTabY = tabBtnY + offsetY

        -- 标签背景（按下时变暗）
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tabX, actualTabY, tabBtnW, tabBtnH, baseUnit * 0.2)
        if isActive then
            nvgFillColor(nvg, nvgRGBA(isPressed and 60 or 80, isPressed and 80 or 100, isPressed and 110 or 140, 255))
        else
            nvgFillColor(nvg, nvgRGBA(isPressed and 35 or 50, isPressed and 42 or 60, isPressed and 56 or 80, isPressed and 220 or 200))
        end
        nvgFill(nvg)

        -- 标签文字（跟随偏移）
        nvgFontSize(nvg, tabFontSize)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isActive then
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        else
            nvgFillColor(nvg, nvgRGBA(150, 160, 180, 200))
        end
        nvgText(nvg, tabX + tabBtnW / 2, actualTabY + tabBtnH / 2, tabName)

        -- 记录点击区域（使用原始位置）
        table.insert(PauseUI.tabRects, {x = tabX, y = tabBtnY, w = tabBtnW, h = tabBtnH, tab = i})
    end

    -- 获取当前标签页的属性列表（使用Overlays的共享配置）
    local currentStats = (PauseUI.statsTab == 1) and Overlays.STATS_PRIMARY or Overlays.STATS_SECONDARY

    -- 属性列表
    local statsStartY = y + titleBarH + baseUnit * 0.3
    local statsAreaH = h - titleBarH - baseUnit * 0.6
    local statCount = #currentStats

    local statFontSize = fonts.statLabel
    local statRowH = statFontSize * 1.25

    -- 计算可见行数和滚动范围
    local visibleRows = math.floor(statsAreaH / statRowH)
    local totalRows = statCount
    PauseUI.maxScrollOffset = math.max(0, totalRows - visibleRows)
    PauseUI.scrollOffset = math.max(0, math.min(PauseUI.scrollOffset, PauseUI.maxScrollOffset))

    -- 绘制可见的属性行
    local startIdx = math.floor(PauseUI.scrollOffset) + 1
    local endIdx = math.min(startIdx + visibleRows, statCount)

    for i = startIdx, endIdx do
        local stat = currentStats[i]
        if not stat then break end

        local rowIndex = i - startIdx
        local statX = x + baseUnit * 0.4
        local statY = statsStartY + rowIndex * statRowH

        -- 超出面板则不绘制
        if statY + statRowH > y + h - baseUnit * 0.3 then break end

        local rawValue = stat.getValue(player)
        local isStringValue = (stat.valueType == "string") or (type(rawValue) == "string")
        local numValue = isStringValue and 0 or (rawValue or 0)

        -- 根据 valueType 格式化显示
        local displayName = stat.name
        local displayValue = ""

        if stat.valueType == "percent" then
            displayName = "%" .. stat.name
            if stat.baseValue then
                displayValue = tostring(rawValue)
            else
                displayValue = tostring(numValue)
            end
        elseif stat.valueType == "base" then
            displayValue = tostring(rawValue) .. (stat.suffix or "")
        else
            displayValue = tostring(rawValue)
        end

        -- 图标
        local iconFontSize = statFontSize * 0.9
        nvgFontSize(nvg, iconFontSize)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(150, 160, 180, 200))
        nvgText(nvg, statX, statY + statRowH / 2, stat.icon)

        -- 属性名
        nvgFontSize(nvg, statFontSize)
        nvgFillColor(nvg, nvgRGBA(180, 185, 195, 220))
        nvgText(nvg, statX + statFontSize * 1.3, statY + statRowH / 2, displayName)

        -- 属性值（颜色编码）
        -- 对于有 baseValue 的属性，比较与基准值的差值
        local colorValue = numValue
        if stat.baseValue then
            colorValue = numValue - stat.baseValue
        end

        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        if stat.noColor or isStringValue then
            nvgFillColor(nvg, nvgRGBA(220, 225, 235, 255))
        elseif colorValue > 0 then
            nvgFillColor(nvg, nvgRGBA(100, 220, 100, 255))
        elseif colorValue < 0 then
            nvgFillColor(nvg, nvgRGBA(255, 100, 100, 255))
        else
            nvgFillColor(nvg, nvgRGBA(180, 185, 195, 220))
        end
        nvgText(nvg, x + w - baseUnit * 0.5, statY + statRowH / 2, displayValue)
    end

    -- 滚动指示器
    if PauseUI.maxScrollOffset > 0 then
        local scrollBarW = baseUnit * 0.15
        local scrollBarX = x + w - scrollBarW - baseUnit * 0.15
        local scrollBarY = statsStartY
        local scrollBarH = statsAreaH - baseUnit * 0.3

        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, scrollBarX, scrollBarY, scrollBarW, scrollBarH, scrollBarW / 2)
        nvgFillColor(nvg, nvgRGBA(40, 50, 60, 100))
        nvgFill(nvg)

        local thumbRatio = visibleRows / totalRows
        local thumbH = math.max(baseUnit * 1.0, scrollBarH * thumbRatio)
        local thumbY = scrollBarY + (scrollBarH - thumbH) * (PauseUI.scrollOffset / PauseUI.maxScrollOffset)

        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, scrollBarX, thumbY, scrollBarW, thumbH, scrollBarW / 2)
        nvgFillColor(nvg, nvgRGBA(100, 120, 150, 180))
        nvgFill(nvg)
    end
end

return PauseUIStats
