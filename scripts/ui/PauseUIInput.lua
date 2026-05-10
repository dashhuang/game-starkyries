-- ============================================================================
-- PauseUIInput - 暂停菜单输入处理
-- 从 PauseUI.lua 拆分，负责触摸/鼠标输入、拖动滚动
-- ============================================================================

local UIScreen = require("ui.UIScreen")
local UISafeArea = require("ui.UISafeArea")
local TouchInput = require("utils.TouchInput")
local ShopCards = require("ui.shop.ShopCards")

local PauseUIInput = {}

-- ============================================================================
-- 统一触摸处理入口（带安全区转换）
-- ============================================================================

function PauseUIInput.HandleTouch(sw, sh, PauseUI)
    if not PauseUI.visible then
        PauseUI.wasMouseDown = false
        return false
    end

    -- 获取安全区信息
    local safe = PauseUI.safeArea or UISafeArea.Calculate(sw, sh)

    -- 获取屏幕坐标
    local screenX = TouchInput.x
    local screenY = TouchInput.y

    -- 当前鼠标状态
    local isMouseDown = input:GetMouseButtonDown(MOUSEB_LEFT)
    local isMousePress = input:GetMouseButtonPress(MOUSEB_LEFT)
    local isMouseRelease = PauseUI.wasMouseDown and not isMouseDown

    -- 更新状态（在处理之前）
    local wasDown = PauseUI.wasMouseDown
    PauseUI.wasMouseDown = isMouseDown

    -- 检查是否在安全区内
    if not UISafeArea.Contains(safe, screenX, screenY) then
        if isMouseRelease then
            UIScreen.CancelPress()
        end
        return false
    end

    -- 转换为安全区本地坐标
    local mx, my = UISafeArea.ToLocal(safe, screenX, screenY)

    -- 处理鼠标按下（设置按下状态）
    if isMousePress then
        return PauseUIInput.HandlePress(mx, my, PauseUI)
    end

    -- 处理鼠标释放（触发点击）
    if isMouseRelease then
        return PauseUIInput.HandleRelease(mx, my, PauseUI)
    end

    -- 处理拖动
    if isMouseDown then
        if PauseUI.isDragging then
            PauseUIInput.UpdateDrag(my, PauseUI)
        elseif PauseUIInput.IsInStatsPanel(mx, my, PauseUI) then
            PauseUIInput.StartDrag(my, PauseUI)
        end
    else
        if PauseUI.isDragging then
            PauseUIInput.EndDrag(PauseUI)
        end
    end

    return false
end

-- ============================================================================
-- 处理鼠标按下（设置按钮按下状态）
-- ============================================================================

function PauseUIInput.HandlePress(mx, my, PauseUI)
    -- 如果详情弹窗打开，检查弹窗内的按钮
    if PauseUI.showDetail then
        if PauseUI.detailPopupBtns then
            for _, btn in ipairs(PauseUI.detailPopupBtns) do
                local buttonId = "pause_detail_" .. (btn.id or "close")
                if UIScreen.CheckButtonPress(mx, my, buttonId, btn.x, btn.y, btn.w, btn.h) then
                    return true
                end
            end
        end
        return true  -- 阻止穿透到下层
    end

    -- 检查武器格子按下
    for i, cell in ipairs(PauseUI.weaponRects) do
        local buttonId = "pause_weapon_" .. i
        if UIScreen.CheckButtonPress(mx, my, buttonId, cell.x, cell.y, cell.w, cell.h) then
            return true
        end
    end

    -- 检查道具格子按下
    for i, cell in ipairs(PauseUI.itemRects) do
        local buttonId = "pause_item_" .. i
        if UIScreen.CheckButtonPress(mx, my, buttonId, cell.x, cell.y, cell.w, cell.h) then
            return true
        end
    end

    -- 检查标签页按下
    for _, tab in ipairs(PauseUI.tabRects) do
        local buttonId = "pause_tab_" .. tab.tab
        if UIScreen.CheckButtonPress(mx, my, buttonId, tab.x, tab.y, tab.w, tab.h) then
            return true
        end
    end

    -- 检查按钮按下
    for _, btn in ipairs(PauseUI.buttonRects) do
        local buttonId = "pause_" .. btn.id
        if UIScreen.CheckButtonPress(mx, my, buttonId, btn.x, btn.y, btn.w, btn.h) then
            return true
        end
    end

    return false
end

-- ============================================================================
-- 处理鼠标释放（触发点击）
-- ============================================================================

function PauseUIInput.HandleRelease(mx, my, PauseUI)
    print(string.format("[PauseUI] HandleRelease mx=%.1f my=%.1f pressedId=%s",
        mx, my, tostring(UIScreen.pressedButtonId)))

    -- 如果详情弹窗打开，检查弹窗内的按钮或关闭弹窗
    if PauseUI.showDetail then
        local closedByButton = false

        if PauseUI.detailPopupBtns then
            for _, btn in ipairs(PauseUI.detailPopupBtns) do
                local buttonId = "pause_detail_" .. (btn.id or "close")
                if UIScreen.CheckButtonRelease(mx, my, buttonId) then
                    PauseUI.showDetail = false
                    PauseUI.detailItem = nil
                    closedByButton = true
                    break
                end
            end
        end

        -- 点击弹窗外部也关闭
        if not closedByButton then
            PauseUI.showDetail = false
            PauseUI.detailItem = nil
        end

        return true  -- 阻止穿透
    end

    -- 检查武器格子释放
    for i, cell in ipairs(PauseUI.weaponRects) do
        local buttonId = "pause_weapon_" .. i
        if UIScreen.CheckButtonRelease(mx, my, buttonId) then
            PauseUI.detailItem = {
                type = "weapon",
                id = cell.weapon.id,
                tier = cell.weapon.tier or 1,
                weaponData = cell.weaponDef,
            }
            PauseUI.showDetail = true
            return true
        end
    end

    -- 检查道具格子释放
    for i, cell in ipairs(PauseUI.itemRects) do
        local buttonId = "pause_item_" .. i
        if UIScreen.CheckButtonRelease(mx, my, buttonId) then
            PauseUI.detailItem = {
                type = "module",
                id = cell.item.id,
                name = cell.moduleDef and cell.moduleDef.name or cell.item.id,
                tier = cell.moduleDef and cell.moduleDef.tier or 1,
                moduleDef = cell.moduleDef,
                moduleType = cell.moduleDef and cell.moduleDef.type,
                description = cell.moduleDef and cell.moduleDef.description,
            }
            PauseUI.showDetail = true
            return true
        end
    end

    -- 检查标签页释放
    for _, tab in ipairs(PauseUI.tabRects) do
        local buttonId = "pause_tab_" .. tab.tab
        if UIScreen.CheckButtonRelease(mx, my, buttonId) then
            PauseUI.statsTab = tab.tab
            PauseUI.scrollOffset = 0
            return true
        end
    end

    -- 检查按钮释放
    for _, btn in ipairs(PauseUI.buttonRects) do
        local buttonId = "pause_" .. btn.id
        if UIScreen.CheckButtonRelease(mx, my, buttonId) then
            if btn.id == "resume" and PauseUI.onResume then
                PauseUI.onResume()
            elseif btn.id == "mainMenu" and PauseUI.onMainMenu then
                PauseUI.onMainMenu()
            elseif btn.id == "gallery" and PauseUI.onGallery then
                PauseUI.onGallery()
            elseif btn.id == "settings" and PauseUI.onSettings then
                PauseUI.onSettings()
            elseif btn.id == "endRun" and PauseUI.onEndRun then
                PauseUI.onEndRun()
            end
            return true
        end
    end

    return false
end

-- ============================================================================
-- 滚动与拖动
-- ============================================================================

function PauseUIInput.HandleScroll(delta, PauseUI)
    PauseUI.scrollOffset = math.max(0, math.min(PauseUI.scrollOffset + delta, PauseUI.maxScrollOffset))
end

function PauseUIInput.IsInStatsPanel(mx, my, PauseUI)
    local r = PauseUI.statsPanelRect
    if not r then return false end
    return UIScreen.HitTest(mx, my, r.x, r.y, r.w, r.h)
end

function PauseUIInput.StartDrag(my, PauseUI)
    PauseUI.isDragging = true
    PauseUI.dragStartY = my
    PauseUI.dragStartScroll = PauseUI.scrollOffset
end

function PauseUIInput.UpdateDrag(my, PauseUI)
    if not PauseUI.isDragging then return end
    local deltaY = PauseUI.dragStartY - my
    local scrollPerPixel = 0.05
    local newScroll = PauseUI.dragStartScroll + deltaY * scrollPerPixel
    PauseUI.scrollOffset = math.max(0, math.min(newScroll, PauseUI.maxScrollOffset))
end

function PauseUIInput.EndDrag(PauseUI)
    PauseUI.isDragging = false
end

return PauseUIInput
