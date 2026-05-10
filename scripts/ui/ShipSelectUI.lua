-- ============================================================================
-- 星河战姬 Starkyries - 战舰选择界面
-- 新布局：左侧图标网格 + 右侧详情面板
-- 安全区设计：横屏16:9 / 竖屏9:16
-- ============================================================================

local Ships = require("config.ships")
local UIStyle = require("ui.UIStyle")
local UISafeArea = require("ui.UISafeArea")
local UIScreen = require("ui.UIScreen")
local Preview3D = require("ui.ship_select.Preview3D")
local StatsManager = require("core.StatsManager")

local ShipSelectUI = {}

-- ============================================================================
-- 状态
-- ============================================================================
ShipSelectUI.visible = false
ShipSelectUI.selectedShipId = nil
ShipSelectUI.selectedCategory = 1
ShipSelectUI.onSelect = nil
ShipSelectUI.animTime = 0

-- 战舰分类
ShipSelectUI.Categories = {
    {id = "assault", name = "突击舰", code = "SSA"},
    {id = "firepower", name = "火力舰", code = "SSB"},
    {id = "defense", name = "防御舰", code = "SSC"},
    {id = "special", name = "特种舰", code = "SSD"},
    {id = "support", name = "支援舰", code = "SSE"},
    {id = "flagship", name = "旗舰", code = "SSF"},
}

-- 按分类组织的战舰
ShipSelectUI.shipsByCategory = {}

-- 战舰主题色配置
ShipSelectUI.ShipThemeColors = {
    ["新手友好"] = {r = 60, g = 180, b = 255},
    ["高风险高回报"] = {r = 255, g = 80, b = 80},
    ["攻速DPS"] = {r = 255, g = 200, b = 60},
    ["坦克防御"] = {r = 80, g = 200, b = 120},
    ["多武器"] = {r = 180, g = 100, b = 255},
}

-- 分类颜色
ShipSelectUI.CategoryColors = {
    assault = {r = 255, g = 100, b = 100},   -- 红
    firepower = {r = 255, g = 180, b = 60},  -- 橙
    defense = {r = 80, g = 200, b = 120},    -- 绿
    special = {r = 180, g = 100, b = 255},   -- 紫
    support = {r = 100, g = 200, b = 255},   -- 青
    flagship = {r = 255, g = 215, b = 0},    -- 金
}

-- 舰长头像缓存
ShipSelectUI.captainImages = {}
ShipSelectUI.nvgContext = nil

-- ============================================================================
-- 初始化
-- ============================================================================

function ShipSelectUI.Init()
    ShipSelectUI.animTime = 0
    ShipSelectUI.selectedCategory = 1
    
    -- 按分类组织战舰
    ShipSelectUI.shipsByCategory = {}
    for _, cat in ipairs(ShipSelectUI.Categories) do
        ShipSelectUI.shipsByCategory[cat.id] = {}
    end
    
    local allShips = Ships.GetAll()
    for _, ship in ipairs(allShips) do
        local code = ship.code or ""
        local prefix = string.sub(code, 1, 3)
        
        for _, cat in ipairs(ShipSelectUI.Categories) do
            if prefix == cat.code then
                table.insert(ShipSelectUI.shipsByCategory[cat.id], ship)
                break
            end
        end
    end
    
    -- 默认选中第一个分类的第一艘战舰
    local firstCat = ShipSelectUI.Categories[1]
    local firstCatShips = ShipSelectUI.shipsByCategory[firstCat.id]
    if firstCatShips and #firstCatShips > 0 then
        ShipSelectUI.selectedShipId = firstCatShips[1].id
    end
    
    -- 初始化3D预览（使用独立模块）
    Preview3D.Init()
end

function ShipSelectUI.Show(callback)
    ShipSelectUI.visible = true
    ShipSelectUI.onSelect = callback
    ShipSelectUI.Init()
end

function ShipSelectUI.Hide()
    ShipSelectUI.visible = false
    
    -- 🔴 关键：完整清理 3D 预览，释放 Scene 和 View3D 内存
    -- 不只是隐藏，因为下次 Show() 会重新创建
    Preview3D.Cleanup()
    print("[ShipSelectUI] Hide with cleanup")
end

-- 每帧更新（在主循环中调用）
function ShipSelectUI.Update(dt)
    if not ShipSelectUI.visible then return end
    
    -- 更新动画时间
    ShipSelectUI.animTime = ShipSelectUI.animTime + dt
    
    -- 更新3D预览旋转
    Preview3D.UpdateRotation(dt)
    
    -- 更新预览模型（如果选择改变）
    if ShipSelectUI.selectedShipId then
        Preview3D.UpdateModel(ShipSelectUI.selectedShipId)
    end
end

-- ============================================================================
-- 获取选中的战舰
-- ============================================================================

function ShipSelectUI.GetSelectedShip()
    if not ShipSelectUI.selectedShipId then return nil end
    return Ships.Get(ShipSelectUI.selectedShipId)
end

-- 检查战舰是否解锁
function ShipSelectUI.IsShipUnlocked(ship)
    if not ship then return false end
    local condition = ship.unlockCondition or "default"
    if condition == "default" then
        return true
    elseif condition == "collect_5000_crystals" then
        local stats = StatsManager.GetStats()
        return (stats.totalCrystalsEarned or 0) >= 5000
    end
    return false
end

-- 获取战舰解锁进度 (0.0 ~ 1.0)
function ShipSelectUI.GetUnlockProgress(ship)
    if not ship then return 0 end
    local condition = ship.unlockCondition or "default"
    if condition == "default" then
        return 1.0
    elseif condition == "collect_5000_crystals" then
        local stats = StatsManager.GetStats()
        local earned = stats.totalCrystalsEarned or 0
        return math.min(1.0, earned / 5000)
    end
    return 0
end

-- ============================================================================
-- 输入处理
-- ============================================================================

-- 获取网格列数（根据屏幕方向）
function ShipSelectUI.GetGridCols()
    local graphics = GetGraphics()
    local sw = graphics:GetWidth()
    local sh = graphics:GetHeight()
    return (sh > sw) and 6 or 5  -- 竖屏6列，横屏5列
end

-- 获取当前选中战舰在分类中的索引
function ShipSelectUI.GetSelectedIndexInCategory()
    local cat = ShipSelectUI.Categories[ShipSelectUI.selectedCategory]
    local ships = ShipSelectUI.shipsByCategory[cat.id] or {}
    
    for i, ship in ipairs(ships) do
        if ship.id == ShipSelectUI.selectedShipId then
            return i
        end
    end
    return 1
end

-- 根据索引选择战舰
function ShipSelectUI.SelectShipByIndex(index)
    local cat = ShipSelectUI.Categories[ShipSelectUI.selectedCategory]
    local ships = ShipSelectUI.shipsByCategory[cat.id] or {}
    
    if #ships == 0 then return end
    
    -- 边界处理
    if index < 1 then index = 1 end
    if index > #ships then index = #ships end
    
    ShipSelectUI.selectedShipId = ships[index].id
end

function ShipSelectUI.HandleInput()
    if not ShipSelectUI.visible then return false end
    
    -- Q/E 切换分类
    if input:GetKeyPress(KEY_Q) then
        ShipSelectUI.selectedCategory = ShipSelectUI.selectedCategory - 1
        if ShipSelectUI.selectedCategory < 1 then
            ShipSelectUI.selectedCategory = #ShipSelectUI.Categories
        end
        ShipSelectUI.SelectFirstShipInCategory()
        return true
    end
    
    if input:GetKeyPress(KEY_E) then
        ShipSelectUI.selectedCategory = ShipSelectUI.selectedCategory + 1
        if ShipSelectUI.selectedCategory > #ShipSelectUI.Categories then
            ShipSelectUI.selectedCategory = 1
        end
        ShipSelectUI.SelectFirstShipInCategory()
        return true
    end
    
    -- 方向键/WASD 选择战舰
    local currentIndex = ShipSelectUI.GetSelectedIndexInCategory()
    local cols = ShipSelectUI.GetGridCols()
    
    if input:GetKeyPress(KEY_LEFT) or input:GetKeyPress(KEY_A) then
        ShipSelectUI.SelectShipByIndex(currentIndex - 1)
        return true
    end
    
    if input:GetKeyPress(KEY_RIGHT) or input:GetKeyPress(KEY_D) then
        ShipSelectUI.SelectShipByIndex(currentIndex + 1)
        return true
    end
    
    if input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) then
        ShipSelectUI.SelectShipByIndex(currentIndex - cols)
        return true
    end
    
    if input:GetKeyPress(KEY_DOWN) or input:GetKeyPress(KEY_S) then
        ShipSelectUI.SelectShipByIndex(currentIndex + cols)
        return true
    end
    
    -- 确认选择
    if input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_SPACE) then
        local ship = ShipSelectUI.GetSelectedShip()
        if ship and ShipSelectUI.IsShipUnlocked(ship) and ShipSelectUI.onSelect then
            ShipSelectUI.onSelect(ship)
            ShipSelectUI.Hide()
        end
        return true
    end
    
    -- ESC 返回
    if input:GetKeyPress(KEY_ESCAPE) then
        ShipSelectUI.Hide()
        return true, "back"
    end
    
    return false
end

function ShipSelectUI.SelectFirstShipInCategory()
    local cat = ShipSelectUI.Categories[ShipSelectUI.selectedCategory]
    local ships = ShipSelectUI.shipsByCategory[cat.id]
    if ships and #ships > 0 then
        ShipSelectUI.selectedShipId = ships[1].id
    end
end

function ShipSelectUI.HandleTouch(sw, sh)
    if not ShipSelectUI.visible then return false end
    
    -- 区分按下和释放
    if UIScreen.IsMousePressed() then
        return UIScreen.HandleTouch(sw, sh, ShipSelectUI, ShipSelectUI.OnPress)
    elseif UIScreen.IsMouseReleased() then
        return UIScreen.HandleTouch(sw, sh, ShipSelectUI, ShipSelectUI.OnRelease)
    end
    
    return false
end

--- 按下事件处理（设置按钮状态）
function ShipSelectUI.OnPress(mx, my, uw, uh, safe)
    local baseUnit = safe.baseUnit
    local layout = ShipSelectUI.GetLayout(uw, uh, baseUnit)
    
    -- 返回按钮按下（使用 UIStyle 统一布局）
    local backLayout = UIStyle.GetBackButtonLayout(baseUnit)
    if UIScreen.CheckButtonPress(mx, my, "ship_back", backLayout.x, backLayout.y - backLayout.h/2, backLayout.w, backLayout.h) then
        return true
    end
    
    if layout.isPortrait then
        return ShipSelectUI.HandlePressPortrait(mx, my, baseUnit, layout)
    else
        return ShipSelectUI.HandlePressLandscape(mx, my, baseUnit, layout)
    end
end

--- 释放事件处理（触发回调）
function ShipSelectUI.OnRelease(mx, my, uw, uh, safe)
    local baseUnit = safe.baseUnit
    local layout = ShipSelectUI.GetLayout(uw, uh, baseUnit)
    
    -- 返回按钮释放
    if UIScreen.CheckButtonRelease(mx, my, "ship_back") then
        return true, "back"
    end
    
    if layout.isPortrait then
        return ShipSelectUI.HandleReleasePortrait(mx, my, baseUnit, layout)
    else
        return ShipSelectUI.HandleReleaseLandscape(mx, my, baseUnit, layout)
    end
end

-- 横屏按下处理（设置按钮状态）
function ShipSelectUI.HandlePressLandscape(mx, my, baseUnit, layout)
    -- 检测战舰图标点击（立即选中，不需要等释放）
    local gridY = layout.contentY + baseUnit * 1.2
    local iconSize = baseUnit * 6  -- 放大50%（与渲染保持一致）
    local iconGap = baseUnit * 0.8
    local cols = 3  -- 图标变大后减少列数
    local gridX = layout.leftPanelX + baseUnit
    
    local ships = Ships.GetAll()
    
    for i, ship in ipairs(ships) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local iconX = gridX + col * (iconSize + iconGap)
        local iconY = gridY + row * (iconSize + iconGap + baseUnit * 1.5)
        
        if UIScreen.HitTest(mx, my, iconX, iconY, iconSize, iconSize) then
            ShipSelectUI.selectedShipId = ship.id
            return true
        end
    end
    
    -- 检测出击按钮按下
    local btnW = layout.rightPanelW * 0.5
    local btnH = baseUnit * 2.8
    local btnX = layout.rightPanelX + (layout.rightPanelW - btnW) / 2
    local btnY = layout.contentY + layout.contentH - btnH - baseUnit * 1.5
    
    if UIScreen.CheckButtonPress(mx, my, "ship_launch", btnX, btnY, btnW, btnH) then
        return true
    end
    
    return false
end

-- 横屏释放处理（触发回调）
function ShipSelectUI.HandleReleaseLandscape(mx, my, baseUnit, layout)
    -- 检测出击按钮释放
    if UIScreen.CheckButtonRelease(mx, my, "ship_launch") then
        local ship = ShipSelectUI.GetSelectedShip()
        if ship and ShipSelectUI.IsShipUnlocked(ship) and ShipSelectUI.onSelect then
            ShipSelectUI.onSelect(ship)
            ShipSelectUI.Hide()
        end
        return true
    end
    
    return false
end

-- 竖屏按下处理（设置按钮状态）
function ShipSelectUI.HandlePressPortrait(mx, my, baseUnit, layout)
    local x = layout.bottomPanelX
    local y = layout.bottomPanelY
    local w = layout.bottomPanelW
    local h = layout.bottomPanelH
    
    -- 获取屏幕尺寸用于按钮计算
    local graphics = GetGraphics()
    local sw = graphics:GetWidth()
    local sh = graphics:GetHeight()
    
    -- 网格参数（与渲染保持一致）
    local ships = Ships.GetAll()
    local cols = 4  -- 图标变大后减少列数
    local rows = math.ceil(#ships / cols)
    local iconSize = baseUnit * 6.75  -- 放大50%（原4.5 -> 6.75）
    local iconGap = baseUnit * 0.6
    local rowHeight = iconSize + iconGap + baseUnit * 1.2
    
    -- 按钮参数
    local btnW = sw * 0.6
    local btnH = sh * 0.065
    local btnGap = baseUnit * 1.5
    
    -- 计算垂直居中
    local gridH = rows * rowHeight
    local totalContentH = gridH + btnGap + btnH
    local contentStartY = y + (h - totalContentH) / 2
    contentStartY = math.max(contentStartY, y + baseUnit)
    
    local gridX = x + (w - cols * (iconSize + iconGap) + iconGap) / 2
    local gridY = contentStartY
    
    -- 检测战舰图标点击
    for i, ship in ipairs(ships) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local iconX = gridX + col * (iconSize + iconGap)
        local iconY = gridY + row * rowHeight
        
        if UIScreen.HitTest(mx, my, iconX, iconY, iconSize, iconSize) then
            ShipSelectUI.selectedShipId = ship.id
            return true
        end
    end
    
    -- 检测出击按钮按下
    local btnX = x + (w - btnW) / 2
    local btnY = gridY + gridH + btnGap
    
    if UIScreen.CheckButtonPress(mx, my, "ship_launch_portrait", btnX, btnY, btnW, btnH) then
        return true
    end
    
    return false
end

-- 竖屏释放处理（触发回调）
function ShipSelectUI.HandleReleasePortrait(mx, my, baseUnit, layout)
    -- 检测出击按钮释放
    if UIScreen.CheckButtonRelease(mx, my, "ship_launch_portrait") then
        local ship = ShipSelectUI.GetSelectedShip()
        if ship and ShipSelectUI.IsShipUnlocked(ship) and ShipSelectUI.onSelect then
            ShipSelectUI.onSelect(ship)
            ShipSelectUI.Hide()
        end
        return true
    end
    
    return false
end

-- ============================================================================
-- 布局计算
-- ============================================================================

function ShipSelectUI.GetLayout(sw, sh, baseUnit)
    local padding = baseUnit * 1.5
    local titleH = sh * 0.12  -- 标题区域占屏幕12%（参考武器选择界面）
    local gap = baseUnit * 1.2  -- 面板间距
    
    local isPortrait = sh > sw
    local contentY = titleH
    local contentH = sh - titleH - padding
    
    if isPortrait then
        -- 竖屏布局：上方预览+详情，下方选择网格
        -- 上下面板比例 4:3（上方占 4/7 ≈ 57%）
        local bottomPadding = baseUnit * 1.5
        local availableH = contentH - bottomPadding
        local topPanelH = availableH * (4 / 7)  -- 上方面板占 4/7
        local bottomPanelH = availableH - topPanelH - gap
        
        return {
            isPortrait = true,
            padding = padding,
            titleH = titleH,
            gap = gap,
            contentY = contentY,
            contentH = contentH,
            -- 上方面板（预览+详情）
            topPanelX = padding,
            topPanelY = contentY,
            topPanelW = sw - padding * 2,
            topPanelH = topPanelH,
            -- 下方面板（选择网格）
            bottomPanelX = padding,
            bottomPanelY = contentY + topPanelH + gap,
            bottomPanelW = sw - padding * 2,
            bottomPanelH = bottomPanelH,
        }
    else
        -- 横屏布局：左侧选择网格，右侧预览+详情
        -- 3个图标一行：(3×6 + 2×0.8 + 2×1) baseUnit = 21.6 baseUnit = sw × 0.304
        local leftPanelW = sw * 0.304
        local rightPanelX = padding + leftPanelW + gap
        local rightPanelW = sw - rightPanelX - padding
        
        return {
            isPortrait = false,
            padding = padding,
            titleH = titleH,
            gap = gap,
            contentY = contentY,
            contentH = contentH,
            -- 左面板（选择网格）
            leftPanelX = padding,
            leftPanelW = leftPanelW,
            -- 右面板（预览+详情）
            rightPanelX = rightPanelX,
            rightPanelW = rightPanelW,
        }
    end
end

-- ============================================================================
-- 渲染
-- ============================================================================

-- 缓存安全区信息（用于输入处理）
ShipSelectUI.safeArea = nil

function ShipSelectUI.Render(nvg, sw, sh)
    if not ShipSelectUI.visible then return end
    
    -- 使用 UIScreen 标准渲染流程
    UIScreen.Render(nvg, sw, sh, ShipSelectUI, {
        drawBackground = ShipSelectUI.DrawFullscreenBackground,
        drawContent = ShipSelectUI.DrawContent,
        useMask = false,  -- 战舰选择背景全屏显示，不绘制遮罩
    })
end

--- 全屏背景绘制
function ShipSelectUI.DrawFullscreenBackground(nvg, sw, sh, baseUnit)
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(8, 12, 24, 255))
    nvgFill(nvg)
    
    -- 全屏背景装饰
    ShipSelectUI.DrawBackground(nvg, sw, sh, baseUnit)
end

--- 安全区内容绘制
function ShipSelectUI.DrawContent(nvg, uw, uh, baseUnit, fonts, safe)
    local layout = ShipSelectUI.GetLayout(uw, uh, baseUnit)
    
    -- 获取鼠标位置检测按下状态
    local mx, my = UIScreen.GetLocalMouse(ShipSelectUI, uw, uh)
    local backPressed = mx and my and UIScreen.ShouldShowPressed(mx, my, "ship_back")
    
    -- 返回按钮（使用统一组件）
    UIStyle.DrawBackButton(nvg, baseUnit, fonts.buttonText * 0.9, backPressed)
    
    -- 标题
    nvgFontSize(nvg, fonts.pageTitle)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg, uw / 2, layout.titleH / 2, "选择战舰")
    
    if layout.isPortrait then
        -- 竖屏：上方预览+详情，下方选择网格
        ShipSelectUI.RenderPortraitTopPanel(nvg, uw, uh, baseUnit, layout, fonts, safe)
        ShipSelectUI.RenderPortraitBottomPanel(nvg, uw, uh, baseUnit, layout, fonts)
    else
        -- 横屏：左侧选择网格，右侧预览+详情
        ShipSelectUI.RenderLeftPanel(nvg, uw, uh, baseUnit, layout, fonts)
        ShipSelectUI.RenderRightPanel(nvg, uw, uh, baseUnit, layout, fonts, safe)
    end
end

-- ============================================================================
-- 背景装饰
-- ============================================================================

function ShipSelectUI.DrawBackground(nvg, sw, sh, baseUnit)
    -- 电路线装饰
    nvgStrokeColor(nvg, nvgRGBA(30, 50, 80, 60))
    nvgStrokeWidth(nvg, 1)
    
    -- 水平线
    for y = sh * 0.1, sh * 0.9, sh * 0.15 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, 0, y)
        nvgLineTo(nvg, sw, y)
        nvgStroke(nvg)
    end
    
    -- 垂直线
    for x = sw * 0.1, sw * 0.9, sw * 0.2 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x, 0)
        nvgLineTo(nvg, x, sh)
        nvgStroke(nvg)
    end
    
    -- 角落装饰
    UIStyle.DrawCornerDecor(nvg, baseUnit, baseUnit, sw - baseUnit * 2, sh - baseUnit * 2, {
        baseUnit = baseUnit,
        size = 3,
        color = UIStyle.Colors.primary.main,
    })
end

-- ============================================================================
-- 左侧面板：战舰图标网格
-- ============================================================================

function ShipSelectUI.RenderLeftPanel(nvg, sw, sh, baseUnit, layout, fonts)
    local x = layout.leftPanelX
    local y = layout.contentY
    local w = layout.leftPanelW
    local h = layout.contentH
    
    -- 面板背景
    UIStyle.DrawSciFiPanel(nvg, x, y, w, h, {
        baseUnit = baseUnit,
        animTime = ShipSelectUI.animTime,
        borderColor = {r = 60, g = 100, b = 150},
        bgAlpha = 220,
    })
    
    -- 直接显示所有战舰（不再按分类）
    local gridY = y + baseUnit * 1.2
    local iconSize = baseUnit * 6  -- 放大50%（原4 -> 6）
    local iconGap = baseUnit * 0.8
    local cols = 3  -- 图标变大后减少列数
    local gridX = x + baseUnit
    
    -- 获取所有战舰
    local ships = Ships.GetAll()
    local defaultColor = {r = 60, g = 180, b = 255}
    
    for i, ship in ipairs(ships) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local iconX = gridX + col * (iconSize + iconGap)
        local iconY = gridY + row * (iconSize + iconGap + baseUnit * 1.5)
        
        local isSelected = (ship.id == ShipSelectUI.selectedShipId)
        local isUnlocked = ShipSelectUI.IsShipUnlocked(ship)
        local themeColor = ShipSelectUI.ShipThemeColors[ship.role] or defaultColor
        
        ShipSelectUI.RenderShipIcon(nvg, iconX, iconY, iconSize, ship, isSelected, isUnlocked, baseUnit, fonts, themeColor)
    end
    
    -- 统计信息
    local unlockedCount = 0
    for _, s in ipairs(ships) do
        if ShipSelectUI.IsShipUnlocked(s) then
            unlockedCount = unlockedCount + 1
        end
    end
    
    local statY = y + h - baseUnit * 2
    nvgFontSize(nvg, fonts.statLabel)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(150, 160, 180, 200))
    nvgText(nvg, x + w / 2, statY, string.format("已解锁: %d/%d", unlockedCount, #ships))
end

-- ============================================================================
-- 战舰图标
-- ============================================================================

function ShipSelectUI.RenderShipIcon(nvg, x, y, size, ship, isSelected, isUnlocked, baseUnit, fonts, catColor)
    local themeColor = ShipSelectUI.ShipThemeColors[ship.role] or catColor
    
    -- 保存 nvg 上下文用于清理
    ShipSelectUI.nvgContext = nvg
    
    -- 选中外发光
    if isSelected then
        local glowAlpha = 0.3 + 0.15 * math.sin(ShipSelectUI.animTime * 3)
        for i = 3, 1, -1 do
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, x - i * 2, y - i * 2, size + i * 4, size + i * 4, baseUnit * 0.4 + i)
            nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, glowAlpha * 200 / i))
            nvgFill(nvg)
        end
    end
    
    -- 图标背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, size, size, baseUnit * 0.4)
    if isUnlocked then
        nvgFillColor(nvg, nvgRGBA(25, 35, 55, 250))
    else
        nvgFillColor(nvg, nvgRGBA(20, 25, 35, 250))
    end
    nvgFill(nvg)
    
    -- 绘制舰长头像或编号
    local hasPortrait = false
    if isUnlocked and ship.captainPortrait then
        -- 延迟加载舰长头像
        if not ShipSelectUI.captainImages[ship.id] then
            local img = nvgCreateImage(nvg, ship.captainPortrait, 0)
            if img and img > 0 then
                ShipSelectUI.captainImages[ship.id] = img
            end
        end
        
        local img = ShipSelectUI.captainImages[ship.id]
        if img and img > 0 then
            hasPortrait = true
            -- 绘制头像（圆角裁剪效果）
            local padding = baseUnit * 0.3
            local imgX = x + padding
            local imgY = y + padding
            local imgSize = size - padding * 2
            
            local imgPaint = nvgImagePattern(nvg, imgX, imgY, imgSize, imgSize, 0, img, isUnlocked and 1.0 or 0.4)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, imgX, imgY, imgSize, imgSize, baseUnit * 0.3)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)
        end
    end
    
    -- 没有头像时显示编号
    if not hasPortrait then
        local codeNum = string.sub(ship.code or "", 5, 6)  -- 取编号部分如 "01"
        nvgFontSize(nvg, size * 0.35)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        
        if isUnlocked then
            nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 255))
        else
            nvgFillColor(nvg, nvgRGBA(80, 90, 100, 150))
        end
        nvgText(nvg, x + size / 2, y + size / 2 - baseUnit * 0.3, codeNum)
    end
    
    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, size, size, baseUnit * 0.4)
    if isSelected then
        nvgStrokeColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 255))
        nvgStrokeWidth(nvg, 2.5)
    else
        nvgStrokeColor(nvg, nvgRGBA(60, 80, 120, isUnlocked and 180 or 80))
        nvgStrokeWidth(nvg, 1.5)
    end
    nvgStroke(nvg)
    
    -- 未解锁显示锁图标
    if not isUnlocked then
        nvgFontSize(nvg, size * 0.25)
        nvgFillColor(nvg, nvgRGBA(100, 110, 120, 200))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(nvg, x + size / 2, y + size / 2, "🔒")
    end
    
    -- 战舰名称（图标下方）
    local shortName = string.sub(ship.name, 1, 6)  -- 取前两个中文字
    nvgFontSize(nvg, fonts.tagText * 0.85)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(200, 210, 220, isUnlocked and 255 or 120))
    nvgText(nvg, x + size / 2, y + size + baseUnit * 0.3, shortName)
end

-- ============================================================================
-- 右侧面板：战舰详情
-- ============================================================================

function ShipSelectUI.RenderRightPanel(nvg, sw, sh, baseUnit, layout, fonts, safe)
    local x = layout.rightPanelX
    local y = layout.contentY
    local w = layout.rightPanelW
    local h = layout.contentH
    
    local ship = ShipSelectUI.GetSelectedShip()
    local isUnlocked = ship and ShipSelectUI.IsShipUnlocked(ship)
    local themeColor = ship and (ShipSelectUI.ShipThemeColors[ship.role] or {r = 60, g = 180, b = 255}) or {r = 60, g = 180, b = 255}
    
    -- 面板背景
    UIStyle.DrawSciFiPanel(nvg, x, y, w, h, {
        baseUnit = baseUnit,
        animTime = ShipSelectUI.animTime,
        borderColor = themeColor,
        bgAlpha = 230,
    })
    
    if not ship then
        nvgFontSize(nvg, fonts.cardTitle)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(100, 110, 130, 200))
        nvgText(nvg, x + w / 2, y + h / 2, "请选择一艘战舰")
        return
    end
    
    -- 布局区域
    local leftCol = x + baseUnit * 1.5
    local leftColW = w * 0.35
    local rightCol = leftCol + leftColW + baseUnit
    local rightColW = w - leftColW - baseUnit * 4
    local contentY = y + baseUnit * 1.5
    
    -- ========== 左列：3D预览区域 + 基本信息 ==========
    
    -- 3D预览区域
    local portraitH = h * 0.45
    local portraitW = leftColW
    
    -- 绘制预览区域背景和边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, leftCol, contentY, portraitW, portraitH, baseUnit * 0.5)
    nvgFillColor(nvg, nvgRGBA(8, 12, 20, 240))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 120))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
    
    -- View3D 使用屏幕坐标系，需要加上安全区偏移
    local view3dX = math.floor(leftCol + safe.x)
    local view3dY = math.floor(contentY + safe.y)
    local view3dW = math.floor(portraitW)
    local view3dH = math.floor(portraitH)
    
    if isUnlocked and Preview3D.scene and Preview3D.camera then
        -- 显示3D预览（使用屏幕坐标）
        Preview3D.GetOrCreateView3D(view3dX, view3dY, view3dW, view3dH)
    else
        -- 隐藏3D预览，显示占位
        Preview3D.HideView3D()
        
        nvgFontSize(nvg, fonts.cardSubtitle)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(80, 90, 100, 150))
        nvgText(nvg, leftCol + portraitW / 2, contentY + portraitH / 2, "???")
    end
    
    -- 基本信息（立绘下方）
    local infoY = contentY + portraitH + baseUnit * 1.2
    
    -- 战舰编号
    nvgFontSize(nvg, fonts.statLabel)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(120, 130, 150, 200))
    nvgText(nvg, leftCol + portraitW / 2, infoY, ship.code or "")
    infoY = infoY + baseUnit * 1.8
    
    -- 战舰名称
    nvgFontSize(nvg, fonts.cardTitle * 1.1)
    nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 255))
    nvgText(nvg, leftCol + portraitW / 2, infoY, isUnlocked and ship.name or "???")
    infoY = infoY + baseUnit * 2.2
    
    -- 舰长
    nvgFontSize(nvg, fonts.cardSubtitle)
    nvgFillColor(nvg, nvgRGBA(180, 190, 200, 220))
    nvgText(nvg, leftCol + portraitW / 2, infoY, "舰长: " .. (isUnlocked and (ship.captain or "") or "???"))
    infoY = infoY + baseUnit * 2
    
    -- 角色标签（宽度适应中文文本，最多5个字如"高风险高回报"）
    local roleText = isUnlocked and (ship.role or "") or "???"
    nvgFontSize(nvg, fonts.tagText)
    -- 估算宽度：中文字符约等于字体大小，加上左右padding
    local charCount = math.max(3, #roleText / 3)  -- UTF-8中文约3字节一个字
    local tagW = fonts.tagText * charCount + baseUnit * 2
    local tagH = baseUnit * 1.8
    local tagX = leftCol + (portraitW - tagW) / 2
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, tagX, infoY, tagW, tagH, baseUnit * 0.3)
    nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 40))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 180))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 255))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, tagX + tagW / 2, infoY + tagH / 2, roleText)
    
    -- ========== 右列：属性详情 ==========
    
    local detailY = contentY
    local maxTextW = rightColW - baseUnit * 0.5  -- 限制文本宽度
    local descFontSize = fonts.description * 0.82  -- 描述文字
    local labelFontSize = fonts.statLabel * 0.88
    local titleGap = baseUnit * 2.2      -- 标题到内容的间距（增大以区分层级）
    local lineHeight = baseUnit * 1.5    -- 内容行高
    local sectionGap = baseUnit * 1.2    -- 段落间距
    
    if isUnlocked then
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        
        -- 加成（仅有内容时显示）
        if ship.bonuses and #ship.bonuses > 0 then
            nvgFontSize(nvg, labelFontSize)
            nvgFillColor(nvg, nvgRGBA(80, 200, 120, 255))
            nvgText(nvg, rightCol, detailY, "[ 加成 ]")
            detailY = detailY + titleGap
            
            nvgFontSize(nvg, descFontSize)
            for _, bonus in ipairs(ship.bonuses) do
                nvgFillColor(nvg, nvgRGBA(100, 220, 140, 255))
                nvgText(nvg, rightCol, detailY, "+")
                ShipSelectUI.DrawTruncatedText(nvg, rightCol + descFontSize, detailY, bonus.desc, maxTextW - descFontSize)
                detailY = detailY + lineHeight
            end
            detailY = detailY + sectionGap
        end
        
        -- 减益（仅有内容时显示）
        if ship.penalties and #ship.penalties > 0 then
            nvgFontSize(nvg, labelFontSize)
            nvgFillColor(nvg, nvgRGBA(255, 100, 100, 255))
            nvgText(nvg, rightCol, detailY, "[ 减益 ]")
            detailY = detailY + titleGap
            
            nvgFontSize(nvg, descFontSize)
            for _, penalty in ipairs(ship.penalties) do
                nvgFillColor(nvg, nvgRGBA(255, 120, 120, 255))
                nvgText(nvg, rightCol, detailY, "-")
                ShipSelectUI.DrawTruncatedText(nvg, rightCol + descFontSize, detailY, penalty.desc, maxTextW - descFontSize)
                detailY = detailY + lineHeight
            end
            detailY = detailY + sectionGap
        end
        
        -- 初始武器（仅有内容时显示）
        local Weapons = require("config.weapons")
        local initWeapon = Weapons.Get(ship.initialWeapon)
        if initWeapon then
            nvgFontSize(nvg, labelFontSize)
            nvgFillColor(nvg, nvgRGBA(255, 200, 80, 255))
            nvgText(nvg, rightCol, detailY, "[ 初始武器 ]")
            detailY = detailY + titleGap
            
            nvgFontSize(nvg, descFontSize)
            nvgFillColor(nvg, nvgRGBA(255, 220, 100, 255))
            local weaponText = initWeapon.name
            if ship.initialWeaponCount and ship.initialWeaponCount > 1 then
                weaponText = weaponText .. " x" .. ship.initialWeaponCount
            end
            ShipSelectUI.DrawTruncatedText(nvg, rightCol, detailY, weaponText, maxTextW)
            detailY = detailY + lineHeight + sectionGap
        end
        
        -- 特殊能力（仅有内容时显示）
        if ship.special and next(ship.special) then
            nvgFontSize(nvg, labelFontSize)
            nvgFillColor(nvg, nvgRGBA(180, 120, 255, 255))
            nvgText(nvg, rightCol, detailY, "[ 特殊能力 ]")
            detailY = detailY + titleGap
            
            nvgFontSize(nvg, descFontSize)
            nvgFillColor(nvg, nvgRGBA(200, 160, 255, 220))
            
            if ship.special.damageBonus then
                ShipSelectUI.DrawTruncatedText(nvg, rightCol, detailY, string.format("* 火力 +%d%%", ship.special.damageBonus * 100), maxTextW)
                detailY = detailY + lineHeight
            end
            if ship.special.damagePerWeaponPenalty then
                ShipSelectUI.DrawTruncatedText(nvg, rightCol, detailY, string.format("* 每武器 %d%%", ship.special.damagePerWeaponPenalty * 100), maxTextW)
                detailY = detailY + lineHeight
            end
            if ship.special.crystalBonus then
                ShipSelectUI.DrawTruncatedText(nvg, rightCol, detailY, string.format("* 晶体 +%d%%", ship.special.crystalBonus * 100), maxTextW)
                detailY = detailY + lineHeight
            end
        end
        
    else
        -- 未解锁：显示解锁条件
        nvgFontSize(nvg, fonts.statLabel)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(255, 180, 60, 255))
        nvgText(nvg, rightCol, detailY, "解锁条件")
        detailY = detailY + baseUnit * 2
        
        nvgFontSize(nvg, fonts.description)
        nvgFillColor(nvg, nvgRGBA(200, 190, 150, 220))
        
        local condition = ship.unlockCondition or "未知"
        if condition == "default" then
            nvgText(nvg, rightCol, detailY, "・默认解锁")
        elseif condition == "collect_5000_crystals" then
            nvgText(nvg, rightCol, detailY, "・收集5000能量晶体")
        else
            nvgText(nvg, rightCol, detailY, "・" .. condition)
        end
        detailY = detailY + baseUnit * 2.5
        
        -- 解锁进度条（示例）
        nvgFontSize(nvg, fonts.statLabel)
        nvgFillColor(nvg, nvgRGBA(150, 160, 180, 180))
        nvgText(nvg, rightCol, detailY, "当前进度:")
        detailY = detailY + baseUnit * 1.5
        
        -- 进度条
        local barW = rightColW * 0.8
        local barH = baseUnit * 1.2
        local progress = ShipSelectUI.GetUnlockProgress(ship)
        
        UIStyle.DrawSciFiProgressBar(nvg, rightCol, detailY, barW, barH, progress, {
            baseUnit = baseUnit,
            barColor = {r = 255, g = 180, b = 60},
            animTime = ShipSelectUI.animTime,
            showText = string.format("%d%%", progress * 100),
            fontSize = fonts.tagText,
        })
    end
    
    -- ========== 出击按钮（与武器选择界面一致）==========
    local btnW = sw * 0.2
    local btnH = sh * 0.06
    local btnX = x + (w - btnW) / 2
    local btnY = y + h - btnH - baseUnit * 1.5
    
    -- 检查按钮是否被按下
    local mx, my = UIScreen.GetLocalMouse(ShipSelectUI, sw, sh)
    local launchPressed = mx and my and UIScreen.ShouldShowPressed(mx, my, "ship_launch")
    
    UIStyle.DrawSciFiButton(nvg, btnX, btnY, btnW, btnH, isUnlocked and "出击" or "未解锁", {
        baseUnit = baseUnit,
        animTime = ShipSelectUI.animTime,
        variant = isUnlocked and "success" or "primary",
        disabled = not isUnlocked,
        fontSize = fonts.buttonText,
        pressed = launchPressed and isUnlocked,
    })
    

end

-- ============================================================================
-- 竖屏布局：上方面板（3D预览 + 详情）
-- ============================================================================

function ShipSelectUI.RenderPortraitTopPanel(nvg, sw, sh, baseUnit, layout, fonts, safe)
    local x = layout.topPanelX
    local y = layout.topPanelY
    local w = layout.topPanelW
    local h = layout.topPanelH
    
    local ship = ShipSelectUI.GetSelectedShip()
    local isUnlocked = ship and ShipSelectUI.IsShipUnlocked(ship)
    local themeColor = ship and (ShipSelectUI.ShipThemeColors[ship.role] or {r = 60, g = 180, b = 255}) or {r = 60, g = 180, b = 255}
    
    -- 面板背景
    UIStyle.DrawSciFiPanel(nvg, x, y, w, h, {
        baseUnit = baseUnit,
        animTime = ShipSelectUI.animTime,
        borderColor = themeColor,
        bgAlpha = 230,
    })
    
    if not ship then
        nvgFontSize(nvg, fonts.cardTitle)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(100, 110, 130, 200))
        nvgText(nvg, x + w / 2, y + h / 2, "请选择一艘战舰")
        return
    end
    
    -- ========== 布局：类似横屏，左列预览+信息，右列属性 ==========
    local leftColX = x + baseUnit * 1.5
    local leftColW = w * 0.32
    local rightColX = leftColX + leftColW + baseUnit * 1.5
    local rightColW = w - leftColW - baseUnit * 5
    local contentY = y + baseUnit
    
    -- ========== 左列：3D预览 + 基本信息 ==========
    
    -- 3D预览区域（正方形，尽量大）
    local previewSize = math.min(leftColW, h * 0.55)
    local previewX = leftColX + (leftColW - previewSize) / 2
    local previewY = contentY
    
    -- 绘制预览区域背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, previewX, previewY, previewSize, previewSize, baseUnit * 0.5)
    nvgFillColor(nvg, nvgRGBA(8, 12, 20, 240))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 120))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
    
    -- View3D 使用屏幕坐标系，需要加上安全区偏移
    local view3dX = math.floor(previewX + safe.x)
    local view3dY = math.floor(previewY + safe.y)
    local view3dW = math.floor(previewSize)
    local view3dH = math.floor(previewSize)
    
    if isUnlocked and Preview3D.scene and Preview3D.camera then
        Preview3D.GetOrCreateView3D(view3dX, view3dY, view3dW, view3dH)
    else
        Preview3D.HideView3D()
        nvgFontSize(nvg, fonts.cardSubtitle)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(80, 90, 100, 150))
        nvgText(nvg, previewX + previewSize / 2, previewY + previewSize / 2, "???")
    end
    
    -- 基本信息（预览下方，居中）
    local infoY = previewY + previewSize + baseUnit * 0.8
    local infoCenterX = leftColX + leftColW / 2
    
    -- 战舰编号
    nvgFontSize(nvg, fonts.statLabel * 0.9)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(120, 130, 150, 200))
    nvgText(nvg, infoCenterX, infoY, ship.code or "")
    infoY = infoY + baseUnit * 1.3
    
    -- 战舰名称
    nvgFontSize(nvg, fonts.cardTitle * 0.95)
    nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 255))
    nvgText(nvg, infoCenterX, infoY, isUnlocked and ship.name or "???")
    infoY = infoY + baseUnit * 1.8
    
    -- 舰长
    nvgFontSize(nvg, fonts.cardSubtitle * 0.9)
    nvgFillColor(nvg, nvgRGBA(180, 190, 200, 220))
    nvgText(nvg, infoCenterX, infoY, "舰长: " .. (isUnlocked and (ship.captain or "") or "???"))
    infoY = infoY + baseUnit * 1.6
    
    -- 角色标签
    local roleText = isUnlocked and (ship.role or "") or "???"
    nvgFontSize(nvg, fonts.tagText * 0.9)
    local charCount = math.max(3, #roleText / 3)
    local tagW = fonts.tagText * 0.9 * charCount + baseUnit * 1.5
    local tagH = baseUnit * 1.5
    local tagX = infoCenterX - tagW / 2
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, tagX, infoY, tagW, tagH, baseUnit * 0.3)
    nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 40))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 180))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 255))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, infoCenterX, infoY + tagH / 2, roleText)
    
    -- ========== 右列：属性详情 ==========
    local detailY = contentY
    local maxTextW = rightColW - baseUnit * 0.5  -- 文字最大宽度
    local descFontSize = fonts.description * 0.82
    local labelFontSize = fonts.statLabel * 0.85
    local titleGap = baseUnit * 2.0      -- 标题到内容的间距（竖屏稍小）
    local lineHeight = baseUnit * 1.4    -- 内容行高
    local sectionGap = baseUnit * 1.0    -- 段落间距
    
    if isUnlocked then
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        
        -- 加成（仅有内容时显示）
        if ship.bonuses and #ship.bonuses > 0 then
            nvgFontSize(nvg, labelFontSize)
            nvgFillColor(nvg, nvgRGBA(80, 200, 120, 255))
            nvgText(nvg, rightColX, detailY, "[ 加成 ]")
            detailY = detailY + titleGap
            
            nvgFontSize(nvg, descFontSize)
            for _, bonus in ipairs(ship.bonuses) do
                nvgFillColor(nvg, nvgRGBA(100, 220, 140, 255))
                nvgText(nvg, rightColX, detailY, "+")
                ShipSelectUI.DrawTruncatedText(nvg, rightColX + descFontSize, detailY, bonus.desc, maxTextW - descFontSize)
                detailY = detailY + lineHeight
            end
            detailY = detailY + sectionGap
        end
        
        -- 减益（仅有内容时显示）
        if ship.penalties and #ship.penalties > 0 then
            nvgFontSize(nvg, labelFontSize)
            nvgFillColor(nvg, nvgRGBA(255, 100, 100, 255))
            nvgText(nvg, rightColX, detailY, "[ 减益 ]")
            detailY = detailY + titleGap
            
            nvgFontSize(nvg, descFontSize)
            for _, penalty in ipairs(ship.penalties) do
                nvgFillColor(nvg, nvgRGBA(255, 120, 120, 255))
                nvgText(nvg, rightColX, detailY, "-")
                ShipSelectUI.DrawTruncatedText(nvg, rightColX + descFontSize, detailY, penalty.desc, maxTextW - descFontSize)
                detailY = detailY + lineHeight
            end
            detailY = detailY + sectionGap
        end
        
        -- 初始武器（仅有内容时显示）
        local Weapons = require("config.weapons")
        local initWeapon = Weapons.Get(ship.initialWeapon)
        if initWeapon then
            nvgFontSize(nvg, labelFontSize)
            nvgFillColor(nvg, nvgRGBA(255, 200, 80, 255))
            nvgText(nvg, rightColX, detailY, "[ 初始武器 ]")
            detailY = detailY + titleGap
            
            nvgFontSize(nvg, descFontSize)
            nvgFillColor(nvg, nvgRGBA(255, 220, 100, 255))
            local weaponText = initWeapon.name
            if ship.initialWeaponCount and ship.initialWeaponCount > 1 then
                weaponText = weaponText .. " x" .. ship.initialWeaponCount
            end
            ShipSelectUI.DrawTruncatedText(nvg, rightColX, detailY, weaponText, maxTextW)
            detailY = detailY + lineHeight + sectionGap
        end
        
        -- 特殊能力（仅有内容时显示）
        if ship.special and next(ship.special) then
            nvgFontSize(nvg, labelFontSize)
            nvgFillColor(nvg, nvgRGBA(180, 120, 255, 255))
            nvgText(nvg, rightColX, detailY, "[ 特殊能力 ]")
            detailY = detailY + titleGap
            
            nvgFontSize(nvg, descFontSize)
            nvgFillColor(nvg, nvgRGBA(200, 160, 255, 220))
            
            if ship.special.damageBonus then
                ShipSelectUI.DrawTruncatedText(nvg, rightColX, detailY, string.format("* 火力 +%d%%", ship.special.damageBonus * 100), maxTextW)
                detailY = detailY + lineHeight
            end
            if ship.special.damagePerWeaponPenalty then
                ShipSelectUI.DrawTruncatedText(nvg, rightColX, detailY, string.format("* 每武器 %d%%", ship.special.damagePerWeaponPenalty * 100), maxTextW)
                detailY = detailY + lineHeight
            end
            if ship.special.crystalBonus then
                ShipSelectUI.DrawTruncatedText(nvg, rightColX, detailY, string.format("* 晶体 +%d%%", ship.special.crystalBonus * 100), maxTextW)
                detailY = detailY + lineHeight
            end
        end
    else
        -- 未解锁状态
        nvgFontSize(nvg, fonts.cardSubtitle)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(100, 110, 130, 150))
        nvgText(nvg, rightColX + rightColW / 2, y + h / 2, "解锁后查看详情")
    end
end

-- 绘制截断文本的辅助函数（使用字符估算，无需nvgTextBounds）
function ShipSelectUI.DrawTruncatedText(nvg, x, y, text, maxWidth)
    -- 估算文本宽度：计算UTF-8字符数，每字符约等于当前字体大小
    local function countUtf8Chars(str)
        local count = 0
        local i = 1
        while i <= #str do
            local byte = string.byte(str, i)
            if byte < 0x80 then
                i = i + 1
            elseif byte < 0xE0 then
                i = i + 2
            elseif byte < 0xF0 then
                i = i + 3
            else
                i = i + 4
            end
            count = count + 1
        end
        return count
    end
    
    -- 获取当前字体大小（通过检查状态来估算）
    -- 假设调用前已设置了字体大小，这里用一个合理的默认值
    local charWidth = 14  -- 估算每个字符的平均宽度
    local charCount = countUtf8Chars(text)
    local estimatedWidth = charCount * charWidth
    
    if estimatedWidth <= maxWidth then
        nvgText(nvg, x, y, text)
    else
        -- 计算最大可显示字符数
        local maxChars = math.floor(maxWidth / charWidth) - 1  -- -1 给省略号留空间
        if maxChars < 3 then maxChars = 3 end
        
        -- 截取前N个UTF-8字符
        local truncated = ""
        local count = 0
        local i = 1
        while i <= #text and count < maxChars do
            local byte = string.byte(text, i)
            local charLen = 1
            if byte >= 0xF0 then
                charLen = 4
            elseif byte >= 0xE0 then
                charLen = 3
            elseif byte >= 0xC0 then
                charLen = 2
            end
            truncated = truncated .. string.sub(text, i, i + charLen - 1)
            i = i + charLen
            count = count + 1
        end
        
        nvgText(nvg, x, y, truncated .. "…")
    end
end

-- ============================================================================
-- 竖屏布局：下方面板（分类标签 + 战舰选择网格 + 出击按钮）
-- ============================================================================

function ShipSelectUI.RenderPortraitBottomPanel(nvg, sw, sh, baseUnit, layout, fonts)
    local x = layout.bottomPanelX
    local y = layout.bottomPanelY
    local w = layout.bottomPanelW
    local h = layout.bottomPanelH
    
    -- 面板背景
    UIStyle.DrawSciFiPanel(nvg, x, y, w, h, {
        baseUnit = baseUnit,
        animTime = ShipSelectUI.animTime,
        borderColor = {r = 60, g = 100, b = 150},
        bgAlpha = 220,
    })
    
    -- 战舰图标网格参数
    local ships = Ships.GetAll()
    local cols = 4  -- 图标变大后减少列数
    local rows = math.ceil(#ships / cols)
    
    -- 图标尺寸（放大50%）
    local iconSize = baseUnit * 6.75  -- 放大50%（原4.5 -> 6.75）
    local iconGap = baseUnit * 0.6
    local rowHeight = iconSize + iconGap + baseUnit * 1.2  -- 图标+间距+名字
    
    -- 按钮参数
    local btnW = sw * 0.6
    local btnH = sh * 0.065
    local btnGap = baseUnit * 1.5  -- 图标和按钮之间的间距
    
    -- 计算内容总高度
    local gridH = rows * rowHeight
    local totalContentH = gridH + btnGap + btnH
    
    -- 垂直居中偏移
    local contentStartY = y + (h - totalContentH) / 2
    contentStartY = math.max(contentStartY, y + baseUnit)  -- 至少留一点顶部边距
    
    -- 绘制战舰图标
    local gridX = x + (w - cols * (iconSize + iconGap) + iconGap) / 2
    local gridY = contentStartY
    local defaultColor = {r = 60, g = 180, b = 255}
    
    for i, ship in ipairs(ships) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local iconX = gridX + col * (iconSize + iconGap)
        local iconY = gridY + row * rowHeight
        
        local isSelected = (ship.id == ShipSelectUI.selectedShipId)
        local isUnlocked = ShipSelectUI.IsShipUnlocked(ship)
        
        ShipSelectUI.RenderShipIcon(nvg, iconX, iconY, iconSize, ship, isSelected, isUnlocked, baseUnit, fonts, defaultColor)
    end
    
    -- 出击按钮（紧跟在图标下方）
    local selectedShip = ShipSelectUI.GetSelectedShip()
    local isUnlocked = selectedShip and ShipSelectUI.IsShipUnlocked(selectedShip)
    local btnX = x + (w - btnW) / 2
    local btnY = gridY + gridH + btnGap
    
    -- 检查按钮是否被按下
    local mx, my = UIScreen.GetLocalMouse(ShipSelectUI, sw, sh)
    local launchPressed = mx and my and UIScreen.ShouldShowPressed(mx, my, "ship_launch_portrait")
    
    UIStyle.DrawSciFiButton(nvg, btnX, btnY, btnW, btnH, isUnlocked and "出击" or "未解锁", {
        baseUnit = baseUnit,
        animTime = ShipSelectUI.animTime,
        variant = isUnlocked and "success" or "primary",
        disabled = not isUnlocked,
        fontSize = fonts.buttonText,
        pressed = launchPressed and isUnlocked,
    })
end

-- ============================================================================
-- 完整清理（退出游戏或切换场景时调用）
-- ============================================================================

function ShipSelectUI.Cleanup()
    print("[ShipSelectUI] Cleanup called")
    Preview3D.Cleanup()
    
    -- 释放舰长头像资源
    if ShipSelectUI.nvgContext then
        for shipId, img in pairs(ShipSelectUI.captainImages) do
            if img and img > 0 then
                nvgDeleteImage(ShipSelectUI.nvgContext, img)
            end
        end
    end
    ShipSelectUI.captainImages = {}
    ShipSelectUI.nvgContext = nil
    
    ShipSelectUI.visible = false
    ShipSelectUI.selectedShipId = nil
    ShipSelectUI.onSelect = nil
    ShipSelectUI.shipsByCategory = {}
    ShipSelectUI.safeArea = nil
end

return ShipSelectUI
