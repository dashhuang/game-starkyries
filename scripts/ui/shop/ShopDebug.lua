-- ============================================================================
-- 星河战姬 Starkyries - 商店调试面板
-- 提供开发测试用的物品获取功能
-- ============================================================================

local UIStyle = require("ui.UIStyle")
local TouchInput = require("utils.TouchInput")

local ShopDebug = {}

-- 调试面板状态
ShopDebug.showPanel = false
ShopDebug.tab = "weapon"
ShopDebug.scrollOffset = 0
ShopDebug.targetScroll = 0
ShopDebug.hoveredIndex = 0
ShopDebug.layout = nil

-- ============================================================================
-- 公共接口
-- ============================================================================

function ShopDebug.HandleKey()
    if input:GetKeyPress(KEY_T) then
        ShopDebug.showPanel = not ShopDebug.showPanel
        if ShopDebug.showPanel then
            ShopDebug.scrollOffset = 0
            ShopDebug.targetScroll = 0
            ShopDebug.hoveredIndex = 0
        end
        return true
    end
    return false
end

function ShopDebug.IsVisible()
    return ShopDebug.showPanel
end

function ShopDebug.Hide()
    ShopDebug.showPanel = false
end

function ShopDebug.Reset()
    ShopDebug.showPanel = false
    ShopDebug.tab = "weapon"
    ShopDebug.scrollOffset = 0
    ShopDebug.targetScroll = 0
end

-- ============================================================================
-- 渲染
-- ============================================================================

function ShopDebug.Render(nvg, sw, sh, shop, player)
    if not ShopDebug.showPanel then return end
    
    local baseUnit = math.min(sw, sh) / 40
    local waveNum = shop.currentWave or 1
    local luck = player.luck or 0
    
    -- 调用 Shop 的统一概率计算函数
    local weaponItems, moduleItems = shop.GetAllPurchasableItemsWithProbability(waveNum, player)
    
    -- 面板尺寸
    local panelW = sw * 0.85
    local panelH = sh * 0.85
    local panelX = (sw - panelW) / 2
    local panelY = (sh - panelH) / 2
    
    -- 半透明背景遮罩
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 200))
    nvgFill(nvg)
    
    -- 面板背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, panelX, panelY, panelW, panelH, baseUnit * 0.5)
    nvgFillColor(nvg, nvgRGBA(15, 20, 30, 250))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(255, 100, 100, 180))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
    
    -- 标题
    local titleY = panelY + baseUnit * 1.5
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.8))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 100, 100, 255))
    nvgText(nvg, sw / 2, titleY, "调试面板 (T键关闭)")
    
    -- 副标题
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.0))
    nvgFillColor(nvg, nvgRGBA(180, 180, 180, 255))
    nvgText(nvg, sw / 2, titleY + baseUnit * 2, 
        string.format("波次: %d | 运势: %d | 点击物品直接获取", waveNum, luck))
    
    -- 标签页
    local tabY = titleY + baseUnit * 4
    local tabW = panelW * 0.2
    local tabH = baseUnit * 2
    local tabX1 = panelX + panelW * 0.25 - tabW / 2
    local tabX2 = panelX + panelW * 0.75 - tabW / 2
    
    ShopDebug.RenderTab(nvg, tabX1, tabY, tabW, tabH, "武器", #weaponItems, ShopDebug.tab == "weapon", baseUnit)
    ShopDebug.RenderTab(nvg, tabX2, tabY, tabW, tabH, "模块", #moduleItems, ShopDebug.tab == "module", baseUnit)
    
    -- 内容区域
    local contentY = tabY + tabH + baseUnit * 1
    local contentH = panelH - (contentY - panelY) - baseUnit * 2
    local contentX = panelX + baseUnit * 1.5
    local contentW = panelW - baseUnit * 3
    
    -- 裁剪区域
    nvgSave(nvg)
    nvgScissor(nvg, contentX, contentY, contentW, contentH)
    
    local items = ShopDebug.tab == "weapon" and weaponItems or moduleItems
    local itemH = baseUnit * 3.5
    local itemGap = baseUnit * 0.5
    local totalItemsH = #items * (itemH + itemGap)
    local maxScroll = math.max(0, totalItemsH - contentH)
    
    -- 更新滚动
    local scrollDiff = ShopDebug.targetScroll - ShopDebug.scrollOffset
    if math.abs(scrollDiff) > 1 then
        ShopDebug.scrollOffset = ShopDebug.scrollOffset + scrollDiff * 0.15
    else
        ShopDebug.scrollOffset = ShopDebug.targetScroll
    end
    ShopDebug.scrollOffset = math.max(0, math.min(maxScroll, ShopDebug.scrollOffset))
    
    -- 渲染物品列表
    local mx, my = TouchInput.x, TouchInput.y
    ShopDebug.hoveredIndex = 0
    
    for i, item in ipairs(items) do
        local itemY = contentY + (i - 1) * (itemH + itemGap) - ShopDebug.scrollOffset
        
        if itemY + itemH >= contentY and itemY <= contentY + contentH then
            local isHovered = mx >= contentX and mx <= contentX + contentW and
                              my >= itemY and my <= itemY + itemH
            if isHovered then
                ShopDebug.hoveredIndex = i
            end
            
            ShopDebug.RenderItem(nvg, contentX, itemY, contentW, itemH, item, 
                baseUnit, isHovered, ShopDebug.tab, waveNum, player)
        end
    end
    
    nvgRestore(nvg)
    
    -- 滚动条
    if maxScroll > 0 then
        ShopDebug.RenderScrollBar(nvg, panelX + panelW - baseUnit * 1, contentY, 
            baseUnit * 0.4, contentH, ShopDebug.scrollOffset, maxScroll, totalItemsH, baseUnit)
    end
    
    -- 存储布局信息
    ShopDebug.layout = {
        panelX = panelX, panelY = panelY, panelW = panelW, panelH = panelH,
        tabX1 = tabX1, tabX2 = tabX2, tabY = tabY, tabW = tabW, tabH = tabH,
        contentX = contentX, contentY = contentY, contentW = contentW, contentH = contentH,
        itemH = itemH, itemGap = itemGap, maxScroll = maxScroll,
        weaponItems = weaponItems, moduleItems = moduleItems,
    }
end

function ShopDebug.RenderTab(nvg, x, y, w, h, label, count, isActive, baseUnit)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.2)
    if isActive then
        nvgFillColor(nvg, nvgRGBA(80, 60, 120, 220))
    else
        nvgFillColor(nvg, nvgRGBA(40, 45, 55, 180))
    end
    nvgFill(nvg)
    
    if isActive then
        nvgStrokeColor(nvg, nvgRGBA(180, 100, 255, 200))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
    end
    
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.0))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, isActive and 255 or 180))
    nvgText(nvg, x + w / 2, y + h / 2, string.format("%s (%d)", label, count))
end

function ShopDebug.RenderScrollBar(nvg, x, y, w, h, offset, maxScroll, totalH, baseUnit)
    local thumbH = math.max(baseUnit * 2, h * (h / totalH))
    local thumbY = y + (h - thumbH) * (offset / maxScroll)
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.2)
    nvgFillColor(nvg, nvgRGBA(40, 50, 60, 100))
    nvgFill(nvg)
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, thumbY, w, thumbH, baseUnit * 0.2)
    nvgFillColor(nvg, nvgRGBA(100, 150, 200, 180))
    nvgFill(nvg)
end

function ShopDebug.RenderItem(nvg, x, y, w, h, item, baseUnit, isHovered, itemType, waveNum, player)
    -- 背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.3)
    if isHovered then
        nvgFillColor(nvg, nvgRGBA(60, 80, 100, 220))
    else
        nvgFillColor(nvg, nvgRGBA(30, 40, 55, 180))
    end
    nvgFill(nvg)
    
    if isHovered then
        nvgStrokeColor(nvg, nvgRGBA(100, 200, 255, 200))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)
    end
    
    local leftX = x + baseUnit * 0.8
    local rightX = x + w - baseUnit * 0.8
    
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.1))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    
    if itemType == "weapon" then
        if item.isOwned then
            nvgFillColor(nvg, nvgRGBA(255, 220, 100, 255))
        elseif item.isSameType then
            nvgFillColor(nvg, nvgRGBA(150, 220, 255, 255))
        else
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        end
        
        local displayName = item.name
        if item.poolInfo and item.poolInfo ~= "全武器池" then
            displayName = item.name .. "  " .. item.poolInfo
        end
        nvgText(nvg, leftX, y + baseUnit * 0.4, displayName)
        
        nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.8))
        nvgFillColor(nvg, nvgRGBA(150, 160, 180, 200))
        local qualityText = string.format("T1:%.0f%% T2:%.0f%% T3:%.0f%% T4:%.0f%%",
            item.t1Chance * 100, item.t2Chance * 100, item.t3Chance * 100, item.t4Chance * 100)
        nvgText(nvg, leftX, y + baseUnit * 1.5, qualityText)
        
        if item.weaponData and item.weaponData.tags then
            nvgFillColor(nvg, nvgRGBA(180, 150, 255, 180))
            nvgText(nvg, leftX, y + baseUnit * 2.4, table.concat(item.weaponData.tags, " · "))
        end
    else
        local rarityColors = {
            [1] = {180, 180, 180}, [2] = {100, 220, 100},
            [3] = {80, 160, 255}, [4] = {180, 100, 255},
        }
        local rc = rarityColors[item.rarity] or rarityColors[1]
        nvgFillColor(nvg, nvgRGBA(rc[1], rc[2], rc[3], 255))
        nvgText(nvg, leftX, y + baseUnit * 0.4, item.name)
        
        nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.75))
        nvgFillColor(nvg, nvgRGBA(150, 160, 180, 200))
        local desc = item.description or ""
        if #desc > 80 then desc = desc:sub(1, 80) .. "..." end
        nvgText(nvg, leftX, y + baseUnit * 1.5, desc)
        
        local rarityNames = {"普通", "稀有", "史诗", "传说"}
        nvgFillColor(nvg, nvgRGBA(rc[1], rc[2], rc[3], 180))
        local tagBonusText = item.hasTagBonus and " [Tag]" or ""
        nvgText(nvg, leftX, y + baseUnit * 2.3, 
            string.format("%s | 上限:%d | 权重:%.1f%s", 
                rarityNames[item.rarity] or "普通", item.maxStack or 1, item.rarityWeight or 0, tagBonusText))
    end
    
    -- 右侧
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.0))
    nvgFillColor(nvg, nvgRGBA(100, 200, 150, 255))
    nvgText(nvg, rightX, y + baseUnit * 0.4, string.format("%d", item.price))
    
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.8))
    nvgFillColor(nvg, nvgRGBA(255, 200, 100, 200))
    nvgText(nvg, rightX, y + baseUnit * 1.5, string.format("概率: %.2f%%", (item.appearChance or 0) * 100))
    
    if isHovered then
        nvgFillColor(nvg, nvgRGBA(100, 255, 150, 255))
        nvgText(nvg, rightX, y + baseUnit * 2.3, "点击获取")
    end
end

-- ============================================================================
-- 输入处理
-- ============================================================================

function ShopDebug.HandleTouch(player, onAddWeapon, onAddModule)
    if not ShopDebug.showPanel then return false end
    if not input:GetMouseButtonPress(MOUSEB_LEFT) then return false end
    
    local mx, my = TouchInput.x, TouchInput.y
    local layout = ShopDebug.layout
    if not layout then return false end
    
    -- 点击面板外部关闭
    if mx < layout.panelX or mx > layout.panelX + layout.panelW or
       my < layout.panelY or my > layout.panelY + layout.panelH then
        ShopDebug.showPanel = false
        return true
    end
    
    -- 标签页点击
    if my >= layout.tabY and my <= layout.tabY + layout.tabH then
        if mx >= layout.tabX1 and mx <= layout.tabX1 + layout.tabW then
            ShopDebug.tab = "weapon"
            ShopDebug.scrollOffset = 0
            ShopDebug.targetScroll = 0
            return true
        end
        if mx >= layout.tabX2 and mx <= layout.tabX2 + layout.tabW then
            ShopDebug.tab = "module"
            ShopDebug.scrollOffset = 0
            ShopDebug.targetScroll = 0
            return true
        end
    end
    
    -- 物品点击
    if ShopDebug.hoveredIndex > 0 then
        local items = ShopDebug.tab == "weapon" and layout.weaponItems or layout.moduleItems
        local item = items[ShopDebug.hoveredIndex]
        if item then
            if item.type == "weapon" and onAddWeapon then
                onAddWeapon(item.id, 1)
                return true
            elseif item.type == "module" and onAddModule then
                onAddModule(item.id)
                return true
            end
        end
    end
    
    return true
end

function ShopDebug.HandleScroll()
    if not ShopDebug.showPanel then return end
    
    local wheelDelta = input:GetMouseMoveWheel()
    if wheelDelta and wheelDelta ~= 0 then
        local scrollAmount = wheelDelta * 40
        ShopDebug.targetScroll = ShopDebug.targetScroll - scrollAmount
        
        local layout = ShopDebug.layout
        if layout and layout.maxScroll then
            ShopDebug.targetScroll = math.max(0, math.min(layout.maxScroll, ShopDebug.targetScroll))
        end
    end
end

return ShopDebug
