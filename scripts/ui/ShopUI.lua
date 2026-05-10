-- ============================================================================
-- 星河战姬 Starkyries - 商店UI（补给站）
-- 安全区设计：横屏16:9 / 竖屏9:16
-- ============================================================================
-- 
-- UI安全区设计：
--   横屏: 16:9 设计，超宽/窄屏留空
--   竖屏: 9:16 设计，超长/宽屏留空
-- 
-- ============================================================================

local UIStyle = require("ui.UIStyle")
local UISafeArea = require("ui.UISafeArea")
local UIScreen = require("ui.UIScreen")
local Weapons = require("config.weapons")
local Modules = require("config.modules")
local TagSetBonuses = require("data.TagSetBonuses")
local ShopDebug = require("ui.shop.ShopDebug")
local ShopCards = require("ui.shop.ShopCards")
local FrameCache = require("utils.FrameCache")
local ImageLoader = require("utils.ImageLoader")
local TouchInput = require("utils.TouchInput")

local ShopUI = {}

-- 使用 ShopCards 的品质颜色和名称
ShopUI.TierColors = ShopCards.TierColors
ShopUI.TierNames = ShopCards.TierNames

ShopUI.animTime = 0

-- UI状态
ShopUI.selectedItemIndex = 0      -- 当前选中的商品（0=无）

-- ============================================================================
-- 调试面板状态
-- ============================================================================
ShopUI.showDebugPanel = false     -- 是否显示调试面板
ShopUI.debugTab = "weapon"        -- 调试面板标签页: "weapon" / "module"
ShopUI.debugScrollOffset = 0      -- 调试面板滚动位置
ShopUI.debugTargetScroll = 0      -- 调试面板目标滚动位置
ShopUI.debugHoveredIndex = 0      -- 鼠标悬停的物品索引
ShopUI.inventoryTab = "weapon"    -- 底部标签页: "weapon" / "module"
ShopUI.selectedInventoryIndex = 0 -- 当前选中的已装备物品
ShopUI.showDetail = false         -- 是否显示详情弹窗
ShopUI.detailItem = nil           -- 详情弹窗显示的物品
ShopUI.detailMergeTargets = {}    -- 详情弹窗中的可合并目标列表
ShopUI.showKeyboardFocus = false  -- 键盘导航模式（预留，当前UI无键盘导航，所有选中为功能性高亮）

-- 滚动（竖屏模式）
ShopUI.scrollOffset = 0
ShopUI.targetScrollOffset = 0
ShopUI.isDragging = false

-- 商品按下状态
ShopUI.pressedShopItemIndex = nil   -- 当前按下的商品索引
ShopUI.pressedLockBtnIndex = nil    -- 当前按下的锁定按钮索引
ShopUI.dragStartY = 0
ShopUI.dragStartOffset = 0
ShopUI.lastDragY = 0
ShopUI.dragVelocity = 0

-- 武器合成状态
ShopUI.mergeMode = false           -- 是否处于合成选择模式
ShopUI.mergeSourceIndex = 0        -- 合成源武器索引
ShopUI.mergeTargetIndex = 0        -- 合成目标武器索引



-- ============================================================================
-- 响应式布局判断
-- ============================================================================

function ShopUI.IsPortrait(sw, sh)
    return sh >= sw
end

-- ============================================================================
-- 主渲染函数
-- ============================================================================

-- 缓存安全区信息（用于输入处理）
ShopUI.safeArea = nil

-- 临时存储渲染参数（供回调使用）
ShopUI._renderShop = nil
ShopUI._renderPlayer = nil

function ShopUI.Render(nvg, sw, sh, baseUnit, fontSize, shop, player)
    ShopUI.animTime = ShopUI.animTime + 0.016
    
    -- 🔧 防御性检查：确保参数有效
    if not shop then shop = {items = {}, currentWave = 1} end
    if not player then player = {crystals = 0, weapons = {}, modules = {}} end
    
    -- 存储参数供回调使用
    ShopUI._renderShop = shop
    ShopUI._renderPlayer = player
    
    UIScreen.Render(nvg, sw, sh, ShopUI, {
        drawBackground = ShopUI.DrawFullscreenBackground,
        drawContent = ShopUI.DrawContent,
        useMask = false,
    })
end

-- 全屏背景绘制（不受安全区限制）
function ShopUI.DrawFullscreenBackground(nvg, sw, sh, baseUnit)
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(10, 16, 28, 250))
    nvgFill(nvg)
end

-- 安全区内容绘制
function ShopUI.DrawContent(nvg, uw, uh, baseUnit, fonts, safe)
    local shop = ShopUI._renderShop
    local player = ShopUI._renderPlayer
    local isPortrait = safe.isPortrait
    
    -- 响应式布局计算（基于安全区尺寸）
    local layout = ShopUI.CalculateLayout(uw, uh, baseUnit, isPortrait)
    layout.fonts = fonts  -- 传递给子渲染函数
    
    -- 顶部标题栏
    ShopUI.RenderHeader(nvg, layout, shop, player)
    
    if isPortrait then
        -- 竖屏布局
        ShopUI.RenderPortrait(nvg, layout, shop, player)
    else
        -- 横屏布局
        ShopUI.RenderLandscape(nvg, layout, shop, player)
    end
    
    -- 详情弹窗（如果打开）
    if ShopUI.showDetail and ShopUI.detailItem then
        local uiState = {
            detailSource = ShopUI.detailSource,
            detailIndex = ShopUI.detailIndex,
            detailMergeTargets = ShopUI.detailMergeTargets,
        }
        ShopUI.detailPopupBtns = ShopCards.RenderDetailPopup(nvg, layout, ShopUI.detailItem, player, uiState, ShopUI.animTime)
    end
end

-- ============================================================================
-- 响应式布局计算
-- ============================================================================

-- 🔴 性能优化：使用帧缓存，同一帧内只计算一次
function ShopUI.CalculateLayout(sw, sh, baseUnit, isPortrait)
    -- 确保是整数，避免 string.format %d 报错
    local swInt, shInt = math.floor(sw), math.floor(sh)
    local cacheKey = string.format("shop_layout_%d_%d_%d_%s", 
        swInt, shInt, math.floor(baseUnit * 100), tostring(isPortrait))
    
    return FrameCache:Get(cacheKey, function()
        local layout = {}
        
        layout.sw = sw
        layout.sh = sh
        layout.baseUnit = baseUnit
        layout.isPortrait = isPortrait
        layout.padding = sw * 0.03
        
        if isPortrait then
            -- 竖屏布局（优化版：4张卡片完整显示无滚动）
            layout.headerHeight = sh * 0.09
            layout.contentX = layout.padding
            layout.contentY = layout.headerHeight
            layout.contentW = sw - layout.padding * 2
            
            -- 商品卡片（2列×2行，确保完整显示）
            layout.columns = 2
            layout.cardW = (layout.contentW - layout.padding) / 2
            layout.cardH = sh * 0.295  -- 调整卡片高度以适应2行
            layout.cardGapX = layout.padding
            layout.cardGapY = sh * 0.008
            
            -- 商品区域（精确计算：2行卡片 + 1个间距）
            layout.shopY = layout.headerHeight
            layout.shopHeight = layout.cardH * 2 + layout.cardGapY
            
            -- 无需滚动
            layout.totalContentHeight = layout.shopHeight
            layout.maxScroll = 0
            
            -- 底部区域
            layout.bottomY = layout.shopY + layout.shopHeight + sh * 0.01
            layout.bottomH = sh - layout.bottomY
            
            -- 主按钮（出发）- 底部全宽
            layout.primaryBtnW = sw * 0.92
            layout.primaryBtnH = sh * 0.055
            -- 次要按钮（刷新）
            layout.secondaryBtnW = sw * 0.24
            layout.secondaryBtnH = sh * 0.042
        else
            -- 横屏布局（原有逻辑）
            layout.contentX = layout.padding
            layout.contentY = sh * 0.12
            layout.contentW = sw - layout.padding * 2
            layout.contentH = sh * 0.75
            
            layout.cardW = sw * 0.215
            layout.cardH = sh * 0.52
            layout.cardGap = sw * 0.015
            
            local totalCardsW = layout.cardW * 4 + layout.cardGap * 3
            layout.cardsStartX = (sw - totalCardsW) / 2
            layout.shopY = sh * 0.15
            
            layout.bottomY = sh * 0.72
            layout.bottomH = sh * 0.22
            
            layout.maxScroll = 0  -- 横屏不需要滚动
        end
        
        return layout
    end)
end

-- ============================================================================
-- 顶部标题栏
-- ============================================================================

function ShopUI.RenderHeader(nvg, layout, shop, player)
    local baseUnit = layout.baseUnit
    local sw, sh = layout.sw, layout.sh
    local centerX = sw / 2
    local isPortrait = layout.isPortrait
    local fonts = layout.fonts
    
    -- 装饰线条
    local lineY = isPortrait and (sh * 0.11) or (sh * 0.12)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sw * 0.05, lineY)
    nvgLineTo(nvg, sw * 0.95, lineY)
    nvgStrokeColor(nvg, nvgRGBA(40, 70, 100, 80))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- 标题（使用统一字体规范）
    local waveNum = shop.currentWave or 1
    nvgFontSize(nvg, fonts.pageTitle * 0.7)  -- 商店标题略小于页面主标题
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg, centerX, sh * 0.025, "补给站")
    
    -- 波次信息
    nvgFontSize(nvg, fonts.pageSubtitle)
    nvgFillColor(nvg, nvgRGBA(100, 180, 255, 200))
    nvgText(nvg, centerX, sh * (isPortrait and 0.065 or 0.075), string.format("第 %d 波（共20波）", waveNum))
    
    -- 右上角晶体显示
    nvgFontSize(nvg, fonts.cardTitle)
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(100, 180, 255, 255))  -- 蓝色
    nvgText(nvg, sw * 0.95, sh * (isPortrait and 0.03 or 0.04), string.format("💎 %d", player.crystals or 0))
end

-- ============================================================================
-- 横屏布局渲染
-- ============================================================================

function ShopUI.RenderLandscape(nvg, layout, shop, player)
    -- 商品卡片区域
    ShopUI.RenderShopItemsLandscape(nvg, layout, shop, player)
    
    -- 底部区域
    ShopUI.RenderBottomSectionLandscape(nvg, layout, shop, player)
end

function ShopUI.RenderShopItemsLandscape(nvg, layout, shop, player)
    local items = shop.items or {}
    local baseUnit = layout.baseUnit
    local fonts = layout.fonts
    
    for i, item in ipairs(items) do
        if not item.sold then  -- 跳过已售出的物品
            local cardX = layout.cardsStartX + (i - 1) * (layout.cardW + layout.cardGap)
            local cardY = layout.shopY
            local isSelected = (ShopUI.selectedItemIndex == i)
            local canAfford = (player.crystals or 0) >= (item.price or 0)
            local isPressed = (ShopUI.pressedShopItemIndex == i)
            
            ShopCards.RenderItemCard(nvg, cardX, cardY, layout.cardW, layout.cardH, 
                item, isSelected, canAfford, baseUnit, player, false, fonts, ShopUI.animTime, isPressed)
        end
    end
end

-- ============================================================================
-- 竖屏布局渲染
-- ============================================================================

function ShopUI.RenderPortrait(nvg, layout, shop, player)
    local baseUnit = layout.baseUnit
    local sw, sh = layout.sw, layout.sh
    local fonts = layout.fonts
    
    -- 更新滚动
    ShopUI.UpdateScroll(0.016, layout)
    
    -- 商品区域（可滚动）
    nvgSave(nvg)
    nvgScissor(nvg, 0, layout.shopY, sw, layout.shopHeight)
    
    local items = shop.items or {}
    for i, item in ipairs(items) do
        if not item.sold then  -- 跳过已售出的物品
            local col = (i - 1) % layout.columns
            local row = math.floor((i - 1) / layout.columns)
            
            local cardX = layout.contentX + col * (layout.cardW + layout.cardGapX)
            local cardY = layout.shopY + row * (layout.cardH + layout.cardGapY) - ShopUI.scrollOffset
            
            -- 只渲染可见的卡片
            if cardY + layout.cardH > layout.shopY - layout.cardH and 
               cardY < layout.shopY + layout.shopHeight + layout.cardH then
                local isSelected = (ShopUI.selectedItemIndex == i)
                local canAfford = (player.crystals or 0) >= (item.price or 0)
                local isPressed = (ShopUI.pressedShopItemIndex == i)
                
                ShopCards.RenderItemCard(nvg, cardX, cardY, layout.cardW, layout.cardH, 
                    item, isSelected, canAfford, baseUnit, player, true, fonts, ShopUI.animTime, isPressed)
            end
        end
    end
    
    nvgRestore(nvg)
    
    -- 滚动条
    if layout.maxScroll > 0 then
        ShopUI.DrawScrollBar(nvg, layout)
    end
    
    -- 底部区域
    ShopUI.RenderBottomSectionPortrait(nvg, layout, shop, player)
end

-- ============================================================================
-- 滚动控制
-- ============================================================================

function ShopUI.UpdateScroll(dt, layout)
    if not layout.isPortrait then return end
    
    if not ShopUI.isDragging and math.abs(ShopUI.dragVelocity) > 1 then
        ShopUI.scrollOffset = ShopUI.scrollOffset + ShopUI.dragVelocity * dt
        ShopUI.dragVelocity = ShopUI.dragVelocity * 0.92
        
        if ShopUI.scrollOffset < 0 then
            ShopUI.scrollOffset = 0
            ShopUI.dragVelocity = 0
        elseif ShopUI.scrollOffset > layout.maxScroll then
            ShopUI.scrollOffset = layout.maxScroll
            ShopUI.dragVelocity = 0
        end
        
        ShopUI.targetScrollOffset = ShopUI.scrollOffset
    else
        local diff = ShopUI.targetScrollOffset - ShopUI.scrollOffset
        if math.abs(diff) > 0.5 then
            ShopUI.scrollOffset = ShopUI.scrollOffset + diff * 0.15
        else
            ShopUI.scrollOffset = ShopUI.targetScrollOffset
        end
    end
end

function ShopUI.DrawScrollBar(nvg, layout)
    local barX = layout.sw - layout.baseUnit * 0.8
    local barY = layout.shopY
    local barH = layout.shopHeight
    local barW = layout.baseUnit * 0.3
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX, barY, barW, barH, barW / 2)
    nvgFillColor(nvg, nvgRGBA(40, 50, 60, 100))
    nvgFill(nvg)
    
    -- 🔧 防御性检查：确保不除零
    local totalContentHeight = layout.totalContentHeight or 1
    local maxScroll = layout.maxScroll or 1
    local thumbRatio = layout.shopHeight / math.max(totalContentHeight, 1)
    local thumbH = math.max(barH * thumbRatio, layout.baseUnit * 2)
    local scrollRatio = ShopUI.scrollOffset / math.max(maxScroll, 1)
    local thumbY = barY + (barH - thumbH) * scrollRatio
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX, thumbY, barW, thumbH, barW / 2)
    nvgFillColor(nvg, nvgRGBA(100, 180, 255, 180))
    nvgFill(nvg)
end

-- ============================================================================
-- 底部区域（横屏）
-- ============================================================================

function ShopUI.RenderBottomSectionLandscape(nvg, layout, shop, player)
    local baseUnit = layout.baseUnit
    local sw, sh = layout.sw, layout.sh
    local bottomY = layout.bottomY
    local fonts = layout.fonts
    
    -- 装饰线条
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sw * 0.05, bottomY)
    nvgLineTo(nvg, sw * 0.95, bottomY)
    nvgStrokeColor(nvg, nvgRGBA(40, 70, 100, 80))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    local contentX = sw * 0.05
    local contentW = sw * 0.9
    bottomY = bottomY + sh * 0.015
    
    -- 左侧：标签页
    local tabW = sw * 0.1
    local tabH = sh * 0.035
    local tabY = bottomY
    
    local weaponCount = player.weapons and #player.weapons or 0
    local maxWeapons = player.maxWeaponSlots or 6
    ShopUI.RenderTab(nvg, contentX, tabY, tabW, tabH, 
        string.format("武器(%d/%d)", weaponCount, maxWeapons),
        ShopUI.inventoryTab == "weapon", baseUnit)
    
    local moduleCount = 0
    if player.modules then
        for _, count in pairs(player.modules) do
            moduleCount = moduleCount + count
        end
    end
    ShopUI.RenderTab(nvg, contentX + tabW + sw * 0.01, tabY, tabW, tabH,
        string.format("模块(%d)", moduleCount),
        ShopUI.inventoryTab == "module", baseUnit)
    
    -- 已装备物品展示区
    local inventoryY = tabY + tabH + sh * 0.01
    local inventoryH = sh * 0.12
    local inventoryW = sw * 0.55
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, contentX, inventoryY, inventoryW, inventoryH, baseUnit * 0.2)
    nvgFillColor(nvg, nvgRGBA(15, 20, 30, 180))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(40, 60, 80, 100))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    if ShopUI.inventoryTab == "weapon" then
        ShopUI.RenderInventoryWeapons(nvg, contentX, inventoryY, inventoryW, inventoryH, baseUnit, player)
    else
        ShopUI.RenderInventoryModules(nvg, contentX, inventoryY, inventoryW, inventoryH, baseUnit, player)
    end
    
    -- 右侧：操作按钮
    local btnX = contentX + inventoryW + sw * 0.02
    local btnW = sw * 0.28
    local btnH = sh * 0.05
    
    -- 获取鼠标位置用于按下状态检测
    local mx, my = UIScreen.GetLocalMouse(ShopUI, sw, sh)
    
    local refreshCost = 1
    if shop.GetRefreshCost then
        refreshCost = shop.GetRefreshCost()
    end
    local canRefresh = (player.crystals or 0) >= refreshCost
    local refreshPressed = mx and my and UIScreen.ShouldShowPressed(mx, my, "shop_refresh")
    local isRefreshPressed = refreshPressed and canRefresh
    
    -- 按下时的偏移
    local refreshPressOffset = isRefreshPressed and 2 or 0
    
    -- 刷新按钮背景（与升级界面一致）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, btnX, inventoryY + refreshPressOffset, btnW, btnH, baseUnit * 0.3)
    if isRefreshPressed then
        nvgFillColor(nvg, nvgRGBA(40, 45, 60, 255))
    elseif canRefresh then
        nvgFillColor(nvg, nvgRGBA(60, 65, 80, 255))
    else
        nvgFillColor(nvg, nvgRGBA(40, 45, 55, 200))
    end
    nvgFill(nvg)
    
    -- 刷新按钮边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, btnX, inventoryY + refreshPressOffset, btnW, btnH, baseUnit * 0.3)
    nvgStrokeWidth(nvg, isRefreshPressed and 2 or 1)
    nvgStrokeColor(nvg, nvgRGBA(80, 90, 110, isRefreshPressed and 255 or 200))
    nvgStroke(nvg)
    
    -- 刷新按钮文字
    nvgFontSize(nvg, fonts.buttonText * 0.85)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if canRefresh then
        nvgFillColor(nvg, nvgRGBA(100, 200, 100, isRefreshPressed and 180 or 255))
    else
        nvgFillColor(nvg, nvgRGBA(120, 130, 140, 180))
    end
    nvgText(nvg, btnX + btnW / 2, inventoryY + btnH / 2 + refreshPressOffset, 
        string.format("💎 %d  刷新", refreshCost))
    
    local waveNum = shop.currentWave or 1
    local continueY = inventoryY + btnH + sh * 0.015
    local continueH = btnH * 1.2
    local continuePressed = mx and my and UIScreen.ShouldShowPressed(mx, my, "shop_continue")
    
    UIStyle.DrawSciFiButton(nvg, btnX, continueY, btnW, continueH,
        string.format("出发 (第%d波)", waveNum + 1), {
        baseUnit = baseUnit,
        animTime = ShopUI.animTime,
        variant = "success",
        fontSize = fonts.buttonText,
        pressed = continuePressed,
    })
end

-- ============================================================================
-- 底部区域（竖屏）- 优化版
-- ============================================================================

function ShopUI.RenderBottomSectionPortrait(nvg, layout, shop, player)
    local baseUnit = layout.baseUnit
    local sw, sh = layout.sw, layout.sh
    local bottomY = layout.bottomY
    local fonts = layout.fonts
    
    -- 装饰线条
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sw * 0.05, bottomY)
    nvgLineTo(nvg, sw * 0.95, bottomY)
    nvgStrokeColor(nvg, nvgRGBA(40, 70, 100, 80))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    local contentX = sw * 0.04
    local contentW = sw * 0.92
    bottomY = bottomY + sh * 0.008
    
    -- ===== 第一行：标签页 + 刷新按钮 =====
    local tabW = sw * 0.26
    local tabH = sh * 0.042
    local tabY = bottomY
    local tabFontSize = UIStyle.FontSize(baseUnit, 1.0)  -- 使用标准字体大小
    
    local weaponCount = player.weapons and #player.weapons or 0
    local maxWeapons = player.maxWeaponSlots or 6
    ShopUI.RenderTabPortrait(nvg, contentX, tabY, tabW, tabH, 
        string.format("武器(%d/%d)", weaponCount, maxWeapons),
        ShopUI.inventoryTab == "weapon", baseUnit, tabFontSize)
    
    local moduleCount = 0
    if player.modules then
        for _, count in pairs(player.modules) do
            moduleCount = moduleCount + count
        end
    end
    ShopUI.RenderTabPortrait(nvg, contentX + tabW + sw * 0.015, tabY, tabW, tabH,
        string.format("模块(%d)", moduleCount),
        ShopUI.inventoryTab == "module", baseUnit, tabFontSize)
    
    -- 获取鼠标位置用于按下状态检测
    local mx, my = UIScreen.GetLocalMouse(ShopUI, sw, sh)
    
    -- 刷新按钮（右侧，清晰可读）
    local refreshCost = 1
    if shop.GetRefreshCost then
        refreshCost = shop.GetRefreshCost()
    end
    local canRefresh = (player.crystals or 0) >= refreshCost
    
    local refreshBtnW = sw * 0.18
    local refreshBtnH = tabH
    local refreshBtnX = contentX + contentW - refreshBtnW
    local refreshBtnY = tabY
    local refreshPressed = mx and my and UIScreen.ShouldShowPressed(mx, my, "shop_refresh")
    local isRefreshPressed = refreshPressed and canRefresh
    
    -- 按下时的偏移
    local refreshPressOffset = isRefreshPressed and 2 or 0
    
    -- 按钮背景（与升级界面一致）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, refreshBtnX, refreshBtnY + refreshPressOffset, refreshBtnW, refreshBtnH, baseUnit * 0.3)
    if isRefreshPressed then
        nvgFillColor(nvg, nvgRGBA(40, 45, 60, 255))  -- 按下时更暗
    elseif canRefresh then
        nvgFillColor(nvg, nvgRGBA(60, 65, 80, 255))
    else
        nvgFillColor(nvg, nvgRGBA(40, 45, 55, 200))
    end
    nvgFill(nvg)
    
    -- 按钮边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, refreshBtnX, refreshBtnY + refreshPressOffset, refreshBtnW, refreshBtnH, baseUnit * 0.3)
    nvgStrokeWidth(nvg, isRefreshPressed and 2 or 1)
    nvgStrokeColor(nvg, nvgRGBA(80, 90, 110, isRefreshPressed and 255 or 200))
    nvgStroke(nvg)
    
    -- 晶体图标和费用
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.0))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if canRefresh then
        nvgFillColor(nvg, nvgRGBA(100, 200, 100, isRefreshPressed and 180 or 255))
    else
        nvgFillColor(nvg, nvgRGBA(120, 130, 140, 180))
    end
    nvgText(nvg, refreshBtnX + refreshBtnW / 2, refreshBtnY + refreshBtnH / 2 + refreshPressOffset, 
        string.format("💎 %d  刷新", refreshCost))
    
    -- ===== 第二行：已装备物品展示区 =====
    local inventoryY = tabY + tabH + sh * 0.008
    local inventoryH = sh * 0.082
    local inventoryW = contentW
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, contentX, inventoryY, inventoryW, inventoryH, baseUnit * 0.2)
    nvgFillColor(nvg, nvgRGBA(15, 20, 30, 180))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(40, 60, 80, 100))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    if ShopUI.inventoryTab == "weapon" then
        ShopUI.RenderInventoryWeapons(nvg, contentX, inventoryY, inventoryW, inventoryH, baseUnit, player)
    else
        ShopUI.RenderInventoryModules(nvg, contentX, inventoryY, inventoryW, inventoryH, baseUnit, player)
    end
    
    -- ===== 第三行：主按钮（出发）- 底部居中，全宽突出 =====
    local waveNum = shop.currentWave or 1
    local primaryBtnW = layout.primaryBtnW
    local primaryBtnH = layout.primaryBtnH
    local primaryBtnX = (sw - primaryBtnW) / 2
    local primaryBtnY = inventoryY + inventoryH + sh * 0.018
    local continuePressed = mx and my and UIScreen.ShouldShowPressed(mx, my, "shop_continue")
    
    UIStyle.DrawSciFiButton(nvg, primaryBtnX, primaryBtnY, primaryBtnW, primaryBtnH,
        string.format("出发（第%d波）", waveNum + 1), {
        baseUnit = baseUnit,
        animTime = ShopUI.animTime,
        variant = "success",
        fontSize = UIStyle.FontSize(baseUnit, 1.2),
        pressed = continuePressed,
    })
end

-- ============================================================================
-- 标签页渲染（统一函数，支持可选字体大小）
-- ============================================================================

function ShopUI.RenderTab(nvg, x, y, w, h, text, isActive, baseUnit, fontSize)
    -- 字体大小：传入则使用，否则使用默认值
    fontSize = fontSize or UIStyle.FontSize(baseUnit, 1.0)
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.15)
    
    if isActive then
        nvgFillColor(nvg, nvgRGBA(50, 80, 120, 200))
    else
        nvgFillColor(nvg, nvgRGBA(25, 35, 50, 150))
    end
    nvgFill(nvg)
    
    if isActive then
        nvgStrokeColor(nvg, nvgRGBA(100, 180, 255, 150))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    end
    
    nvgFontSize(nvg, fontSize)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(isActive and 255 or 140, isActive and 255 or 150, isActive and 255 or 160, 255))
    nvgText(nvg, x + w / 2, y + h / 2, text)
end

-- 兼容旧调用（将被废弃）
ShopUI.RenderTabPortrait = ShopUI.RenderTab

-- ============================================================================
-- 已装备武器渲染
-- ============================================================================

function ShopUI.RenderInventoryWeapons(nvg, x, y, w, h, baseUnit, player)
    local weapons = player.weapons or {}
    local itemSize = h * 0.8
    local gap = itemSize * 0.15
    local startX = x + w * 0.02
    local startY = y + (h - itemSize) / 2
    
    -- 检测可合成的武器
    local mergeableMap = ShopUI.FindMergeableWeapons(weapons)
    
    for i, weapon in ipairs(weapons) do
        local itemX = startX + (i - 1) * (itemSize + gap)
        local itemY = startY
        
        if itemX + itemSize > x + w - w * 0.02 then break end
        
        local isSelected = (ShopUI.selectedInventoryIndex == i and ShopUI.inventoryTab == "weapon")
        local tier = weapon.tier or 1
        local tierColor = ShopUI.TierColors[tier] or ShopUI.TierColors[1]
        
        -- 检查合成模式状态
        local isMergeSource = (ShopUI.mergeMode and ShopUI.mergeSourceIndex == i)
        local isMergeTarget = (ShopUI.mergeMode and ShopUI.mergeSourceIndex > 0 and 
            ShopUI.CanMergeWeapons(weapons, ShopUI.mergeSourceIndex, i))
        local canMerge = mergeableMap[i] ~= nil
        
        -- 武器图标
        local def = Weapons.Get(weapon.id)
        local hasIcon = false
        
        if weapon.id then
            local iconPath = "images/weapons/" .. weapon.id .. ".jpg"
            local img = ImageLoader.GetImage(nvg, iconPath, ShopCards.weaponImages, weapon.id)
            
            if img and img > 0 then
                hasIcon = true
                -- 图标占满整个格子
                local imgPaint = nvgImagePattern(nvg, itemX, itemY, itemSize, itemSize, 0, ShopCards.weaponImages[weapon.id], 1.0)
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, itemX, itemY, itemSize, itemSize, baseUnit * 0.15)
                nvgFillPaint(nvg, imgPaint)
                nvgFill(nvg)
                
                -- 品质边框（边框颜色表示等级）
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, itemX, itemY, itemSize, itemSize, baseUnit * 0.15)
                if isMergeSource then
                    nvgStrokeColor(nvg, nvgRGBA(255, 200, 50, 255))
                    nvgStrokeWidth(nvg, 3)
                elseif isMergeTarget then
                    nvgStrokeColor(nvg, nvgRGBA(100, 255, 100, 255))
                    nvgStrokeWidth(nvg, 3)
                else
                    nvgStrokeColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 255))
                    nvgStrokeWidth(nvg, 2.5)
                end
                nvgStroke(nvg)
            end
        end
        
        -- 没有图标时显示骨架屏占位
        if not hasIcon then
            ImageLoader.RenderPlaceholder(nvg, itemX, itemY, itemSize, itemSize, ShopUI.animTime, baseUnit * 0.15)
        end
        
        -- 合成提示图标（右上角显示升级标记）
        if canMerge and not ShopUI.mergeMode then
            local iconSize = itemSize * 0.28
            local iconCenterX = itemX + itemSize - iconSize / 2 - itemSize * 0.08
            local iconCenterY = itemY + iconSize / 2 + itemSize * 0.08
            local iconRadius = iconSize / 2
            
            -- 外发光效果
            for k = 3, 1, -1 do
                nvgBeginPath(nvg)
                nvgCircle(nvg, iconCenterX, iconCenterY, iconRadius + k * 1.5)
                nvgFillColor(nvg, nvgRGBA(100, 200, 255, 40 / k))
                nvgFill(nvg)
            end
            
            -- 背景渐变（深蓝到青色）
            local bgGrad = nvgLinearGradient(nvg, 
                iconCenterX, iconCenterY - iconRadius,
                iconCenterX, iconCenterY + iconRadius,
                nvgRGBA(40, 120, 180, 240),
                nvgRGBA(30, 80, 140, 240))
            nvgBeginPath(nvg)
            nvgCircle(nvg, iconCenterX, iconCenterY, iconRadius)
            nvgFillPaint(nvg, bgGrad)
            nvgFill(nvg)
            
            -- 边框高光
            nvgBeginPath(nvg)
            nvgCircle(nvg, iconCenterX, iconCenterY, iconRadius)
            nvgStrokeColor(nvg, nvgRGBA(120, 200, 255, 200))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)
            
            -- 向上箭头图标（使用矢量绘制）
            local arrowH = iconRadius * 0.9
            local arrowW = iconRadius * 0.7
            local arrowY = iconCenterY - arrowH * 0.1
            
            nvgBeginPath(nvg)
            -- 箭头三角形
            nvgMoveTo(nvg, iconCenterX, arrowY - arrowH * 0.5)
            nvgLineTo(nvg, iconCenterX + arrowW * 0.6, arrowY + arrowH * 0.1)
            nvgLineTo(nvg, iconCenterX - arrowW * 0.6, arrowY + arrowH * 0.1)
            nvgClosePath(nvg)
            -- 箭头尾巴
            nvgRect(nvg, iconCenterX - arrowW * 0.25, arrowY + arrowH * 0.05, arrowW * 0.5, arrowH * 0.45)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
            nvgFill(nvg)
        end
    end
    
    local maxSlots = player.maxWeaponSlots or 6
    for i = #weapons + 1, maxSlots do
        local itemX = startX + (i - 1) * (itemSize + gap)
        local itemY = startY
        
        if itemX + itemSize > x + w - w * 0.02 then break end
        
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, itemX, itemY, itemSize, itemSize, baseUnit * 0.15)
        nvgStrokeColor(nvg, nvgRGBA(40, 50, 60, 100))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
        
        nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.8))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(40, 50, 60, 100))
        nvgText(nvg, itemX + itemSize / 2, itemY + itemSize / 2, "+")
    end
end

-- ============================================================================
-- 已装备模块渲染
-- ============================================================================

function ShopUI.RenderInventoryModules(nvg, x, y, w, h, baseUnit, player)
    local modules = player.modules or {}
    local itemSize = h * 0.8
    local gap = itemSize * 0.15
    local startX = x + w * 0.02
    local startY = y + (h - itemSize) / 2
    
    -- 品质颜色（与ShopCards保持一致）
    local tierColors = {
        [1] = {r = 150, g = 150, b = 150},  -- T1 灰色
        [2] = {r = 100, g = 200, b = 100},  -- T2 绿色
        [3] = {r = 100, g = 150, b = 255},  -- T3 蓝色
        [4] = {r = 200, g = 100, b = 255},  -- T4 紫色
    }
    
    local i = 1
    for moduleId, count in pairs(modules) do
        if count > 0 then
            local itemX = startX + (i - 1) * (itemSize + gap)
            local itemY = startY
            
            if itemX + itemSize > x + w - w * 0.02 then break end
            
            local isSelected = (ShopUI.selectedInventoryIndex == i and ShopUI.inventoryTab == "module")
            local moduleDef = Modules.GetById(moduleId)
            local tier = moduleDef and moduleDef.tier or 1
            local tierColor = tierColors[tier] or tierColors[1]
            
            -- 模块图标
            local hasIcon = false
            
            if moduleId then
                local iconPath = "images/modules/" .. moduleId .. ".jpg"
                local img = ImageLoader.GetImage(nvg, iconPath, ShopCards.moduleImages, moduleId)
                
                if img and img > 0 then
                    hasIcon = true
                    -- 图标占满整个格子
                    local imgPaint = nvgImagePattern(nvg, itemX, itemY, itemSize, itemSize, 0, ShopCards.moduleImages[moduleId], 1.0)
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, itemX, itemY, itemSize, itemSize, baseUnit * 0.15)
                    nvgFillPaint(nvg, imgPaint)
                    nvgFill(nvg)
                    
                    -- 品质边框（边框颜色表示等级）
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, itemX, itemY, itemSize, itemSize, baseUnit * 0.15)
                    nvgStrokeColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 255))
                    nvgStrokeWidth(nvg, 2.5)
                    nvgStroke(nvg)
                end
            end
            
            -- 没有图标时显示骨架屏占位
            if not hasIcon then
                ImageLoader.RenderPlaceholder(nvg, itemX, itemY, itemSize, itemSize, ShopUI.animTime, baseUnit * 0.15)
            end
            
            -- 数量标记（右下角）
            if count > 1 then
                nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.5))
                nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
                nvgText(nvg, itemX + itemSize - itemSize * 0.08, itemY + itemSize - itemSize * 0.05, "x" .. count)
            end
            
            i = i + 1
        end
    end
    
    if i == 1 then
        nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.7))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(80, 90, 100, 150))
        nvgText(nvg, x + w / 2, y + h / 2, "暂无模块")
    end
end

-- ============================================================================
-- 触摸/点击处理
-- ============================================================================

-- 临时存储触摸回调参数
ShopUI._touchCallbacks = nil

function ShopUI.HandleTouch(sw, sh, shop, onBuy, onRefresh, onContinue, onLock, onRecycle, player, onMerge)
    -- 获取安全区信息
    local safe = ShopUI.safeArea or UISafeArea.Calculate(sw, sh)
    
    -- 存储回调参数供 OnPress/OnRelease 使用
    ShopUI._touchCallbacks = {
        shop = shop,
        player = player,
        onBuy = onBuy,
        onRefresh = onRefresh,
        onContinue = onContinue,
        onLock = onLock,
        onRecycle = onRecycle,
        onMerge = onMerge,
    }
    
    -- 鼠标按下：设置按钮按下状态
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        return UIScreen.HandleTouch(sw, sh, ShopUI, ShopUI.OnPress)
    end
    
    -- 鼠标释放：触发按钮回调
    if UIScreen.IsMouseReleased() then
        return UIScreen.HandleTouch(sw, sh, ShopUI, ShopUI.OnRelease)
    end
    
    -- 处理拖动（竖屏滚动）
    ShopUI.HandleDrag(sw, sh, safe)
    return false
end

-- 按下回调（设置按钮按下状态）
function ShopUI.OnPress(mx, my, uw, uh, safe)
    local cb = ShopUI._touchCallbacks
    if not cb then return false end
    
    local baseUnit = safe.baseUnit
    local isPortrait = safe.isPortrait
    local layout = ShopUI.CalculateLayout(uw, uh, baseUnit, isPortrait)
    
    -- 如果详情弹窗打开，检测弹窗按钮
    if ShopUI.showDetail then
        -- 合并按钮
        if ShopUI.detailPopupBtns and ShopUI.detailPopupBtns.merge then
            local btn = ShopUI.detailPopupBtns.merge
            if UIScreen.CheckButtonPress(mx, my, "shop_detail_merge", btn.x, btn.y, btn.w, btn.h) then
                return true
            end
        end
        -- 回收按钮
        if ShopUI.detailPopupBtns and ShopUI.detailPopupBtns.recycle then
            local btn = ShopUI.detailPopupBtns.recycle
            if UIScreen.CheckButtonPress(mx, my, "shop_detail_recycle", btn.x, btn.y, btn.w, btn.h) then
                return true
            end
        end
        return true  -- 点击弹窗区域消费事件
    end
    
    if isPortrait then
        return ShopUI.HandlePressPortrait(mx, my, layout, cb.shop, cb.player)
    else
        return ShopUI.HandlePressLandscape(mx, my, layout, cb.shop, cb.player)
    end
end

-- 释放回调（触发按钮回调）
function ShopUI.OnRelease(mx, my, uw, uh, safe)
    local cb = ShopUI._touchCallbacks
    if not cb then return false end
    
    local baseUnit = safe.baseUnit
    local isPortrait = safe.isPortrait
    local layout = ShopUI.CalculateLayout(uw, uh, baseUnit, isPortrait)
    
    -- 如果详情弹窗打开
    if ShopUI.showDetail then
        -- 合并按钮释放
        if UIScreen.CheckButtonRelease(mx, my, "shop_detail_merge") then
            if ShopUI.detailPopupBtns and ShopUI.detailPopupBtns.merge then
                local btn = ShopUI.detailPopupBtns.merge
                if cb.onMerge and ShopUI.detailSource == "inventory" and btn.targetIndex then
                    cb.onMerge(ShopUI.detailIndex, btn.targetIndex)
                end
            end
            ShopUI.showDetail = false
            ShopUI.detailItem = nil
            ShopUI.detailMergeTargets = {}
            return true
        end
        
        -- 回收按钮释放
        if UIScreen.CheckButtonRelease(mx, my, "shop_detail_recycle") then
            if ShopUI.detailPopupBtns and ShopUI.detailPopupBtns.recycle then
                local btn = ShopUI.detailPopupBtns.recycle
                if cb.onRecycle and ShopUI.detailSource == "inventory" then
                    cb.onRecycle(ShopUI.detailIndex, btn.value)
                end
            end
            ShopUI.showDetail = false
            ShopUI.detailItem = nil
            return true
        end
        
        -- 点击弹窗外关闭
        ShopUI.showDetail = false
        ShopUI.detailItem = nil
        return true
    end
    
    if isPortrait then
        return ShopUI.HandleReleasePortrait(mx, my, layout, cb.shop, cb.onBuy, cb.onRefresh, cb.onContinue, cb.onLock, cb.player, cb.onMerge)
    else
        return ShopUI.HandleReleaseLandscape(mx, my, layout, cb.shop, cb.onBuy, cb.onRefresh, cb.onContinue, cb.onLock, cb.player, cb.onMerge)
    end
end

function ShopUI.HandleDrag(sw, sh, safe)
    -- 使用传入的安全区信息，或重新计算
    safe = safe or ShopUI.safeArea or UISafeArea.Calculate(sw, sh)
    
    local isPortrait = safe.isPortrait
    if not isPortrait then return end
    
    local baseUnit = safe.baseUnit
    local layout = ShopUI.CalculateLayout(safe.w, safe.h, baseUnit, isPortrait)
    
    -- 获取屏幕坐标并转换为安全区本地坐标
    local screenY = TouchInput.y
    local _, my = UISafeArea.ToLocal(safe, 0, screenY)
    
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        if my >= layout.shopY and my <= layout.shopY + layout.shopHeight then
            ShopUI.isDragging = true
            ShopUI.dragStartY = my
            ShopUI.dragStartOffset = ShopUI.scrollOffset
            ShopUI.lastDragY = my
            ShopUI.dragVelocity = 0
        end
    end
    
    if ShopUI.isDragging and input:GetMouseButtonDown(MOUSEB_LEFT) then
        local deltaY = my - ShopUI.lastDragY
        ShopUI.dragVelocity = -deltaY / 0.016
        ShopUI.lastDragY = my
        
        local totalDrag = ShopUI.dragStartY - my
        ShopUI.scrollOffset = ShopUI.dragStartOffset + totalDrag
        
        local elastic = layout.cardH * 0.3
        ShopUI.scrollOffset = math.max(-elastic, 
            math.min(layout.maxScroll + elastic, ShopUI.scrollOffset))
        ShopUI.targetScrollOffset = ShopUI.scrollOffset
    end
    
    if not input:GetMouseButtonDown(MOUSEB_LEFT) and ShopUI.isDragging then
        ShopUI.isDragging = false
        
        if ShopUI.scrollOffset < 0 then
            ShopUI.targetScrollOffset = 0
            ShopUI.dragVelocity = 0
        elseif ShopUI.scrollOffset > layout.maxScroll then
            ShopUI.targetScrollOffset = layout.maxScroll
            ShopUI.dragVelocity = 0
        else
            ShopUI.targetScrollOffset = ShopUI.scrollOffset
        end
    end
end

-- ============================================================================
-- 按下处理（设置按钮按下状态）
-- ============================================================================

function ShopUI.HandlePressPortrait(mx, my, layout, shop, player)
    local baseUnit = layout.baseUnit
    local sw, sh = layout.sw, layout.sh
    local items = shop.items or {}
    
    -- 检查商品卡片按下
    for i, item in ipairs(items) do
        if not item.sold then
            local col = (i - 1) % layout.columns
            local row = math.floor((i - 1) / layout.columns)
            
            local cardX = layout.contentX + col * (layout.cardW + layout.cardGapX)
            local cardY = layout.shopY + row * (layout.cardH + layout.cardGapY) - ShopUI.scrollOffset
            
            -- 锁定按钮（与 ShopCards 渲染一致）
            local lockBtnSize = baseUnit * 1.8
            local rightX = cardX + layout.cardW * 0.94
            local lockBtnX = rightX - lockBtnSize
            local lockBtnY = cardY + layout.cardH - layout.cardH * 0.1 - baseUnit * 0.3
            
            if mx >= lockBtnX and mx <= lockBtnX + lockBtnSize and
               my >= lockBtnY and my <= lockBtnY + lockBtnSize and
               my >= layout.shopY and my <= layout.shopY + layout.shopHeight then
                ShopUI.pressedLockBtnIndex = i
                return true
            end
            
            -- 卡片区域
            if mx >= cardX and mx <= cardX + layout.cardW and
               my >= cardY and my <= cardY + layout.cardH and
               my >= layout.shopY and my <= layout.shopY + layout.shopHeight then
                ShopUI.pressedShopItemIndex = i
                return true
            end
        end
    end
    
    -- 标签页区域
    local tabW = sw * 0.26
    local tabH = sh * 0.042
    local tabY = layout.bottomY + sh * 0.008
    local contentX = sw * 0.04
    local contentW = sw * 0.92
    
    -- 武器标签
    if UIScreen.CheckButtonPress(mx, my, "shop_tab_weapon", contentX, tabY, tabW, tabH) then
        return true
    end
    
    -- 模块标签
    if UIScreen.CheckButtonPress(mx, my, "shop_tab_module", contentX + tabW + sw * 0.015, tabY, tabW, tabH) then
        return true
    end
    
    -- 刷新按钮
    local refreshBtnW = sw * 0.18
    local refreshBtnH = tabH
    local refreshBtnX = contentX + contentW - refreshBtnW
    if UIScreen.CheckButtonPress(mx, my, "shop_refresh", refreshBtnX, tabY, refreshBtnW, refreshBtnH) then
        return true
    end
    
    -- 主按钮（出发）
    local inventoryY = tabY + tabH + sh * 0.008
    local inventoryH = sh * 0.082
    local primaryBtnW = layout.primaryBtnW
    local primaryBtnH = layout.primaryBtnH
    local primaryBtnX = (sw - primaryBtnW) / 2
    local primaryBtnY = inventoryY + inventoryH + sh * 0.018
    if UIScreen.CheckButtonPress(mx, my, "shop_continue", primaryBtnX, primaryBtnY, primaryBtnW, primaryBtnH) then
        return true
    end
    
    return false
end

function ShopUI.HandlePressLandscape(mx, my, layout, shop, player)
    local baseUnit = layout.baseUnit
    local sw, sh = layout.sw, layout.sh
    local items = shop.items or {}
    
    -- 检查商品卡片按下
    for i, item in ipairs(items) do
        if not item.sold then
            local cardX = layout.cardsStartX + (i - 1) * (layout.cardW + layout.cardGap)
            local cardY = layout.shopY
            
            -- 锁定按钮（与 ShopCards 渲染一致）
            local lockBtnSize = baseUnit * 1.8
            local rightX = cardX + layout.cardW * 0.94
            local lockBtnX = rightX - lockBtnSize
            local lockBtnY = cardY + layout.cardH - layout.cardH * 0.1 - baseUnit * 0.3
            
            if mx >= lockBtnX and mx <= lockBtnX + lockBtnSize and
               my >= lockBtnY and my <= lockBtnY + lockBtnSize then
                ShopUI.pressedLockBtnIndex = i
                return true
            end
            
            -- 卡片区域
            if mx >= cardX and mx <= cardX + layout.cardW and
               my >= cardY and my <= cardY + layout.cardH then
                ShopUI.pressedShopItemIndex = i
                return true
            end
        end
    end
    
    -- 标签页
    local contentX = sw * 0.05
    local tabW = sw * 0.1
    local tabH = sh * 0.035
    local tabY = layout.bottomY + sh * 0.015
    
    -- 武器标签
    if UIScreen.CheckButtonPress(mx, my, "shop_tab_weapon", contentX, tabY, tabW, tabH) then
        return true
    end
    
    -- 模块标签
    if UIScreen.CheckButtonPress(mx, my, "shop_tab_module", contentX + tabW + sw * 0.01, tabY, tabW, tabH) then
        return true
    end
    
    -- 按钮区域
    local inventoryW = sw * 0.55
    local btnX = contentX + inventoryW + sw * 0.02
    local btnW = sw * 0.28
    local btnH = sh * 0.05
    local inventoryY = tabY + tabH + sh * 0.01
    
    -- 刷新按钮
    if UIScreen.CheckButtonPress(mx, my, "shop_refresh", btnX, inventoryY, btnW, btnH) then
        return true
    end
    
    -- 出发按钮
    local continueY = inventoryY + btnH + sh * 0.015
    local continueH = btnH * 1.2
    if UIScreen.CheckButtonPress(mx, my, "shop_continue", btnX, continueY, btnW, continueH) then
        return true
    end
    
    return false
end

-- ============================================================================
-- 释放处理（触发按钮回调）
-- ============================================================================

function ShopUI.HandleReleasePortrait(mx, my, layout, shop, onBuy, onRefresh, onContinue, onLock, player, onMerge)
    local baseUnit = layout.baseUnit
    local sw, sh = layout.sw, layout.sh
    local items = shop.items or {}
    
    -- 检查锁定按钮释放
    if ShopUI.pressedLockBtnIndex then
        local pressedIndex = ShopUI.pressedLockBtnIndex
        ShopUI.pressedLockBtnIndex = nil
        
        local item = items[pressedIndex]
        if item and not item.sold then
            local col = (pressedIndex - 1) % layout.columns
            local row = math.floor((pressedIndex - 1) / layout.columns)
            local cardX = layout.contentX + col * (layout.cardW + layout.cardGapX)
            local cardY = layout.shopY + row * (layout.cardH + layout.cardGapY) - ShopUI.scrollOffset
            
            local lockBtnSize = baseUnit * 1.8
            local rightX = cardX + layout.cardW * 0.94
            local lockBtnX = rightX - lockBtnSize
            local lockBtnY = cardY + layout.cardH - layout.cardH * 0.1 - baseUnit * 0.3
            
            if mx >= lockBtnX and mx <= lockBtnX + lockBtnSize and
               my >= lockBtnY and my <= lockBtnY + lockBtnSize and
               my >= layout.shopY and my <= layout.shopY + layout.shopHeight then
                ShopUI.mergeMode = false
                ShopUI.mergeSourceIndex = 0
                ShopUI.selectedInventoryIndex = 0
                if onLock then onLock(pressedIndex) end
                return true
            end
        end
    end
    
    -- 检查商品卡片释放
    if ShopUI.pressedShopItemIndex then
        local pressedIndex = ShopUI.pressedShopItemIndex
        ShopUI.pressedShopItemIndex = nil
        
        local item = items[pressedIndex]
        if item and not item.sold then
            local col = (pressedIndex - 1) % layout.columns
            local row = math.floor((pressedIndex - 1) / layout.columns)
            local cardX = layout.contentX + col * (layout.cardW + layout.cardGapX)
            local cardY = layout.shopY + row * (layout.cardH + layout.cardGapY) - ShopUI.scrollOffset
            
            if mx >= cardX and mx <= cardX + layout.cardW and
               my >= cardY and my <= cardY + layout.cardH and
               my >= layout.shopY and my <= layout.shopY + layout.shopHeight then
                ShopUI.mergeMode = false
                ShopUI.mergeSourceIndex = 0
                ShopUI.selectedInventoryIndex = 0
                ShopUI.selectedItemIndex = pressedIndex
                if onBuy then onBuy(pressedIndex) end
                return true
            end
        end
    end
    
    -- 标签页（使用CheckButtonRelease）
    local tabW = sw * 0.26
    local tabH = sh * 0.042
    local tabY = layout.bottomY + sh * 0.008
    local contentX = sw * 0.04
    local contentW = sw * 0.92
    
    if UIScreen.CheckButtonRelease(mx, my, "shop_tab_weapon") then
        ShopUI.inventoryTab = "weapon"
        ShopUI.selectedInventoryIndex = 0
        ShopUI.mergeMode = false  -- 切换标签时退出合成模式
        return true
    end
    
    if UIScreen.CheckButtonRelease(mx, my, "shop_tab_module") then
        ShopUI.inventoryTab = "module"
        ShopUI.selectedInventoryIndex = 0
        ShopUI.mergeMode = false  -- 切换标签时退出合成模式
        return true
    end
    
    -- 刷新按钮
    if UIScreen.CheckButtonRelease(mx, my, "shop_refresh") then
        if onRefresh then onRefresh() end
        return true
    end
    
    -- 已装备物品
    local inventoryY = tabY + tabH + sh * 0.008
    local inventoryH = sh * 0.082
    local inventoryW = contentW
    
    if mx >= contentX and mx <= contentX + inventoryW and
       my >= inventoryY and my <= inventoryY + inventoryH then
        local itemSize = inventoryH * 0.8
        local gap = itemSize * 0.15
        local startX = contentX + inventoryW * 0.02
        local clickIndex = math.floor((mx - startX) / (itemSize + gap)) + 1
        
        if ShopUI.inventoryTab == "weapon" and player and player.weapons then
            if clickIndex >= 1 and clickIndex <= #player.weapons then
                local weapons = player.weapons
                local mergeableMap = ShopUI.FindMergeableWeapons(weapons)
                
                -- 点击武器：直接显示详情（合并操作在详情弹窗中进行）
                ShopUI.mergeMode = false
                ShopUI.mergeSourceIndex = 0
                ShopUI.selectedInventoryIndex = clickIndex
                ShopUI.detailItem = weapons[clickIndex]
                ShopUI.detailSource = "inventory"
                ShopUI.detailIndex = clickIndex
                -- 记录可合并目标（供详情弹窗使用）
                ShopUI.detailMergeTargets = mergeableMap[clickIndex] or {}
                ShopCards.ResetDetailScroll()
                ShopUI.showDetail = true
                return true
            end
        elseif ShopUI.inventoryTab == "module" and player and player.modules then
            local moduleList = {}
            for moduleId, count in pairs(player.modules) do
                if count > 0 then
                    table.insert(moduleList, {id = moduleId, count = count})
                end
            end
            if clickIndex >= 1 and clickIndex <= #moduleList then
                local moduleEntry = moduleList[clickIndex]
                local moduleDef = Modules.GetById(moduleEntry.id)
                if moduleDef then
                    ShopUI.selectedInventoryIndex = clickIndex
                    -- 构建详情项（模拟商店物品结构）
                    ShopUI.detailItem = {
                        type = "module",
                        id = moduleEntry.id,
                        name = moduleDef.name,
                        description = moduleDef.description,
                        tier = moduleDef.tier,
                        moduleType = moduleDef.type,
                        count = moduleEntry.count,
                        -- 模块完整数据
                        moduleDef = moduleDef,
                    }
                    ShopUI.detailSource = "inventory_module"
                    ShopUI.detailIndex = clickIndex
                    ShopUI.detailMergeTargets = {}
                    ShopCards.ResetDetailScroll()
                    ShopUI.showDetail = true
                end
                return true
            end
        end
    end
    
    -- 主按钮（出发）
    if UIScreen.CheckButtonRelease(mx, my, "shop_continue") then
        if onContinue then onContinue() end
        return true
    end
    
    return false
end

function ShopUI.HandleReleaseLandscape(mx, my, layout, shop, onBuy, onRefresh, onContinue, onLock, player, onMerge)
    local baseUnit = layout.baseUnit
    local sw, sh = layout.sw, layout.sh
    local items = shop.items or {}
    
    -- 检查锁定按钮释放
    if ShopUI.pressedLockBtnIndex then
        local pressedIndex = ShopUI.pressedLockBtnIndex
        ShopUI.pressedLockBtnIndex = nil
        
        local item = items[pressedIndex]
        if item and not item.sold then
            local cardX = layout.cardsStartX + (pressedIndex - 1) * (layout.cardW + layout.cardGap)
            local cardY = layout.shopY
            
            local lockBtnSize = baseUnit * 1.8
            local rightX = cardX + layout.cardW * 0.94
            local lockBtnX = rightX - lockBtnSize
            local lockBtnY = cardY + layout.cardH - layout.cardH * 0.1 - baseUnit * 0.3
            
            if mx >= lockBtnX and mx <= lockBtnX + lockBtnSize and
               my >= lockBtnY and my <= lockBtnY + lockBtnSize then
                ShopUI.mergeMode = false
                ShopUI.mergeSourceIndex = 0
                ShopUI.selectedInventoryIndex = 0
                if onLock then onLock(pressedIndex) end
                return true
            end
        end
    end
    
    -- 检查商品卡片释放
    if ShopUI.pressedShopItemIndex then
        local pressedIndex = ShopUI.pressedShopItemIndex
        ShopUI.pressedShopItemIndex = nil
        
        local item = items[pressedIndex]
        if item and not item.sold then
            local cardX = layout.cardsStartX + (pressedIndex - 1) * (layout.cardW + layout.cardGap)
            local cardY = layout.shopY
            
            if mx >= cardX and mx <= cardX + layout.cardW and
               my >= cardY and my <= cardY + layout.cardH then
                ShopUI.mergeMode = false
                ShopUI.mergeSourceIndex = 0
                ShopUI.selectedInventoryIndex = 0
                ShopUI.selectedItemIndex = pressedIndex
                if onBuy then onBuy(pressedIndex) end
                return true
            end
        end
    end
    
    -- 标签页（使用CheckButtonRelease）
    local contentX = sw * 0.05
    local tabW = sw * 0.1
    local tabH = sh * 0.035
    local tabY = layout.bottomY + sh * 0.015
    
    if UIScreen.CheckButtonRelease(mx, my, "shop_tab_weapon") then
        ShopUI.inventoryTab = "weapon"
        ShopUI.selectedInventoryIndex = 0
        ShopUI.mergeMode = false  -- 切换标签时退出合成模式
        return true
    end
    
    if UIScreen.CheckButtonRelease(mx, my, "shop_tab_module") then
        ShopUI.inventoryTab = "module"
        ShopUI.selectedInventoryIndex = 0
        ShopUI.mergeMode = false  -- 切换标签时退出合成模式
        return true
    end
    
    -- 已装备物品
    local inventoryY = tabY + tabH + sh * 0.01
    local inventoryH = sh * 0.12
    local inventoryW = sw * 0.55
    
    if mx >= contentX and mx <= contentX + inventoryW and
       my >= inventoryY and my <= inventoryY + inventoryH then
        local itemSize = inventoryH * 0.8
        local gap = itemSize * 0.15
        local startX = contentX + inventoryW * 0.02
        local clickIndex = math.floor((mx - startX) / (itemSize + gap)) + 1
        
        if ShopUI.inventoryTab == "weapon" and player and player.weapons then
            if clickIndex >= 1 and clickIndex <= #player.weapons then
                local weapons = player.weapons
                local mergeableMap = ShopUI.FindMergeableWeapons(weapons)
                
                -- 点击武器：直接显示详情（合并操作在详情弹窗中进行）
                ShopUI.mergeMode = false
                ShopUI.mergeSourceIndex = 0
                ShopUI.selectedInventoryIndex = clickIndex
                ShopUI.detailItem = weapons[clickIndex]
                ShopUI.detailSource = "inventory"
                ShopUI.detailIndex = clickIndex
                -- 记录可合并目标（供详情弹窗使用）
                ShopUI.detailMergeTargets = mergeableMap[clickIndex] or {}
                ShopCards.ResetDetailScroll()
                ShopUI.showDetail = true
                return true
            end
        elseif ShopUI.inventoryTab == "module" and player and player.modules then
            local moduleList = {}
            for moduleId, count in pairs(player.modules) do
                if count > 0 then
                    table.insert(moduleList, {id = moduleId, count = count})
                end
            end
            if clickIndex >= 1 and clickIndex <= #moduleList then
                local moduleEntry = moduleList[clickIndex]
                local moduleDef = Modules.GetById(moduleEntry.id)
                if moduleDef then
                    ShopUI.selectedInventoryIndex = clickIndex
                    -- 构建详情项（模拟商店物品结构）
                    ShopUI.detailItem = {
                        type = "module",
                        id = moduleEntry.id,
                        name = moduleDef.name,
                        description = moduleDef.description,
                        tier = moduleDef.tier,
                        moduleType = moduleDef.type,
                        count = moduleEntry.count,
                        -- 模块完整数据
                        moduleDef = moduleDef,
                    }
                    ShopUI.detailSource = "inventory_module"
                    ShopUI.detailIndex = clickIndex
                    ShopUI.detailMergeTargets = {}
                    ShopCards.ResetDetailScroll()
                    ShopUI.showDetail = true
                end
                return true
            end
        end
    end
    
    -- 刷新按钮
    if UIScreen.CheckButtonRelease(mx, my, "shop_refresh") then
        if onRefresh then onRefresh() end
        return true
    end
    
    -- 出发按钮
    if UIScreen.CheckButtonRelease(mx, my, "shop_continue") then
        if onContinue then onContinue() end
        return true
    end
    
    return false
end

-- ============================================================================
-- 工具函数
-- ============================================================================

-- 🔴 性能优化：武器合成缓存（只在武器列表变化时重新计算）
ShopUI._mergeCache = {
    weapons = nil,      -- 缓存的武器列表引用
    count = 0,          -- 武器数量
    signature = "",     -- 武器签名（id+tier组合）
    result = {},        -- 缓存的结果
}

--- 检测武器是否可以与其他武器合成
--- @param weapons table 武器列表
--- @return table mergeableMap 可合成映射表 {[index] = {partnerIndices}}
function ShopUI.FindMergeableWeapons(weapons)
    if not weapons or #weapons < 2 then
        return {}
    end
    
    -- 生成武器签名用于缓存验证
    local signature = ""
    for i = 1, #weapons do
        local w = weapons[i]
        if w then
            signature = signature .. (w.id or "") .. (w.tier or 0) .. ","
        end
    end
    
    -- 检查缓存是否有效
    local cache = ShopUI._mergeCache
    if cache.weapons == weapons and cache.count == #weapons and cache.signature == signature then
        return cache.result
    end
    
    -- 重新计算
    local mergeableMap = {}
    for i = 1, #weapons do
        local w1 = weapons[i]
        if w1 and w1.tier and w1.tier < 4 then  -- T4无法合成
            for j = i + 1, #weapons do
                local w2 = weapons[j]
                -- 同ID + 同Tier + Tier<4
                if w2 and w1.id == w2.id and w1.tier == w2.tier then
                    -- 记录双向可合成关系
                    mergeableMap[i] = mergeableMap[i] or {}
                    table.insert(mergeableMap[i], j)
                    mergeableMap[j] = mergeableMap[j] or {}
                    table.insert(mergeableMap[j], i)
                end
            end
        end
    end
    
    -- 更新缓存
    cache.weapons = weapons
    cache.count = #weapons
    cache.signature = signature
    cache.result = mergeableMap
    
    return mergeableMap
end

--- 检测指定武器是否可以与某个目标合成
--- @param weapons table 武器列表
--- @param sourceIndex number 源武器索引
--- @param targetIndex number 目标武器索引
--- @return boolean 是否可以合成
function ShopUI.CanMergeWeapons(weapons, sourceIndex, targetIndex)
    if not weapons or sourceIndex == targetIndex then
        return false
    end
    
    local w1 = weapons[sourceIndex]
    local w2 = weapons[targetIndex]
    
    if not w1 or not w2 then
        return false
    end
    
    -- 同ID + 同Tier + Tier<4
    return w1.id == w2.id and w1.tier == w2.tier and w1.tier < 4
end


-- ============================================================================
-- 调试面板 - 委托给 ShopDebug 模块
-- ============================================================================

function ShopUI.HandleDebugKey()
    local result = ShopDebug.HandleKey()
    -- 同步状态到 ShopUI（InputHandler 检查此属性）
    ShopUI.showDebugPanel = ShopDebug.IsVisible()
    return result
end

function ShopUI.RenderDebugPanel(nvg, sw, sh, shop, player)
    ShopDebug.Render(nvg, sw, sh, shop, player)
end

function ShopUI.HandleDebugPanelTouch(player, onAddWeapon, onAddModule)
    return ShopDebug.HandleTouch(player, onAddWeapon, onAddModule)
end

function ShopUI.HandleDebugPanelScroll()
    ShopDebug.HandleScroll()
end

function ShopUI.Reset()
    ShopUI.selectedItemIndex = 0
    ShopUI.inventoryTab = "weapon"
    ShopUI.selectedInventoryIndex = 0
    ShopUI.showDetail = false
    ShopUI.detailItem = nil
    ShopUI.detailMergeTargets = {}
    ShopUI.scrollOffset = 0
    ShopUI.targetScrollOffset = 0
    ShopUI.isDragging = false
    ShopUI.dragVelocity = 0
    ShopUI.showKeyboardFocus = false
    -- 重置合成状态
    ShopUI.mergeMode = false
    ShopUI.mergeSourceIndex = 0
    ShopUI.mergeTargetIndex = 0
    -- 重置安全区缓存
    ShopUI.safeArea = nil
    -- 重置调试面板
    ShopDebug.Reset()
end

return ShopUI
