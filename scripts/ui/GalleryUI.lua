-- ============================================================================
-- 星河战姬 Starkyries - 图鉴系统
-- 成就、武器、模块、敌人收集记录
-- ============================================================================

local UIStyle = require("ui.UIStyle")
local UIScreen = require("ui.UIScreen")
local UISafeArea = require("ui.UISafeArea")
local NvgHelper = require("render.NvgHelper")
local Weapons = require("config.weapons")
local Modules = require("config.modules")
local Enemies = require("config.enemies")
local TagSetBonuses = require("data.TagSetBonuses")
local StatsManager = require("core.StatsManager")
local TouchInput = require("utils.TouchInput")
local ImageLoader = require("utils.ImageLoader")

local GalleryUI = {}

-- ============================================================================
-- 状态
-- ============================================================================
GalleryUI.visible = false
GalleryUI.onClose = nil
GalleryUI.animTime = 0
GalleryUI.showKeyboardFocus = false  -- 只在键盘操作时显示选中框

-- 分类
GalleryUI.categories = {
    {id = "stats", label = "统计", icon = ""},
    {id = "achievements", label = "成就", icon = ""},
    {id = "weapons", label = "武器", icon = ""},
    {id = "modules", label = "模块", icon = ""},
    {id = "enemies", label = "敌人", icon = ""},
}
GalleryUI.selectedCategory = 1
GalleryUI.selectedItem = 1
GalleryUI.scrollOffset = 0
GalleryUI.maxScrollOffset = 0
GalleryUI.isDragging = false
GalleryUI.dragStartY = 0
GalleryUI.dragStartScroll = 0
GalleryUI.hasDragged = false
GalleryUI.pendingSelectItem = nil

-- 详情区域滚动
GalleryUI.detailScrollOffset = 0
GalleryUI.detailMaxScrollOffset = 0
GalleryUI.isDetailDragging = false
GalleryUI.detailDragStartY = 0
GalleryUI.detailDragStartScroll = 0

-- 布局计算（确保HandleInput和Render一致）
function GalleryUI.GetLayout(uw, uh, baseUnit)
    local margin = baseUnit * 1.5
    local backLayout = UIStyle.GetBackButtonLayout(baseUnit)
    local tabY = backLayout.y - baseUnit * 1.25
    local tabH = baseUnit * 2.5
    local tabTotalW = uw * 0.5
    local tabStartX = (uw - tabTotalW) / 2
    local tabW = tabTotalW / #GalleryUI.categories
    
    local contentY = tabY + tabH + baseUnit * 1.0
    local contentH = uh - contentY - baseUnit * 1.5
    
    -- 判断是否竖屏
    local isPortrait = uh > uw
    
    local listX, listW, listY, listH
    local detailX, detailW, detailY, detailH
    local itemH, itemGap
    
    if isPortrait then
        -- 竖屏：上下布局
        listX = margin
        listW = uw - margin * 2
        listY = contentY
        listH = contentH * 0.35  -- 上方列表占35%
        
        detailX = margin
        detailW = uw - margin * 2
        detailY = listY + listH + baseUnit * 0.8
        detailH = contentH - listH - baseUnit * 0.8
        
        itemH = baseUnit * 2.2
        itemGap = baseUnit * 0.3
    else
        -- 横屏：左右布局
        listX = margin
        listW = uw * 0.28
        listY = contentY
        listH = contentH
        
        detailX = listX + listW + baseUnit * 1.5
        detailW = uw - detailX - margin
        detailY = contentY
        detailH = contentH
        
        itemH = baseUnit * 2.5
        itemGap = baseUnit * 0.4
    end
    
    return {
        margin = margin,
        backLayout = backLayout,
        tabY = tabY,
        tabH = tabH,
        tabTotalW = tabTotalW,
        tabStartX = tabStartX,
        tabW = tabW,
        contentY = contentY,
        contentH = contentH,
        listX = listX,
        listW = listW,
        listY = listY,
        listH = listH,
        detailX = detailX,
        detailW = detailW,
        detailY = detailY,
        detailH = detailH,
        itemH = itemH,
        itemGap = itemGap,
        isPortrait = isPortrait,
    }
end

-- 解锁数据（模拟，实际应从存档读取）
GalleryUI.unlocked = {
    achievements = {},
    weapons = {},
    modules = {},
    enemies = {},
}

-- 图标缓存
GalleryUI.weaponImages = {}
GalleryUI.moduleImages = {}
GalleryUI.enemyImages = {}

-- ============================================================================
-- 初始化
-- ============================================================================

function GalleryUI.Init()
    GalleryUI.animTime = 0
    GalleryUI.selectedCategory = 1
    GalleryUI.selectedItem = 1
    GalleryUI.scrollOffset = 0
    GalleryUI.maxScrollOffset = 0
    GalleryUI.isDragging = false
    GalleryUI.hasDragged = false
    GalleryUI.pendingSelectItem = nil
    GalleryUI.showKeyboardFocus = false
    
    -- 加载解锁数据
    GalleryUI.LoadUnlockedData()
end

function GalleryUI.LoadUnlockedData()
    -- 暂时将所有内容标记为已解锁（演示用）
    -- 实际应从存档系统读取
    
    -- 武器（Weapons.List 是 key-value 表）
    GalleryUI.unlocked.weapons = {}
    for id, _ in pairs(Weapons.List) do
        GalleryUI.unlocked.weapons[id] = true
    end
    
    -- 模块（Modules.List 是数组）
    GalleryUI.unlocked.modules = {}
    for _, m in ipairs(Modules.List) do
        GalleryUI.unlocked.modules[m.id] = true
    end
    
    -- 敌人（Enemies.List 是 key-value 表）
    GalleryUI.unlocked.enemies = {}
    for id, _ in pairs(Enemies.List) do
        GalleryUI.unlocked.enemies[id] = true
    end
    
    -- 成就（暂时为空）
    GalleryUI.unlocked.achievements = {}
end

-- ============================================================================
-- 获取当前分类的项目列表
-- ============================================================================

function GalleryUI.GetCurrentItems()
    local cat = GalleryUI.categories[GalleryUI.selectedCategory]
    local items = {}
    
    if cat.id == "stats" then
        -- 玩家统计数据
        local stats = StatsManager.GetStats()
        table.insert(items, {
            id = "games_played",
            name = "累计出击次数",
            desc = "母舰航行日志的扉页写道：「每一次出击，都是向着故土的又一次叩问。」五百年了，没有人记得地球的模样，但每一艘战舰的升空，都在延续着这份执念。",
            unlocked = true,
            value = stats.totalGamesPlayed or 0,
        })
        table.insert(items, {
            id = "enemies_killed",
            name = "击毁敌舰数量",
            desc = "帝国的追兵、失控的机械、深空的原生者……在这片星海中，敌人从不缺席。零曾说：「每一个数字背后，都是一个本不必发生的故事。」",
            unlocked = true,
            value = stats.totalEnemiesKilled or 0,
        })
        table.insert(items, {
            id = "crystals_earned",
            name = "获得晶体",
            desc = "晶体是星际流浪者的血液。它从敌舰的残骸中闪烁而出，仿佛是宇宙对幸存者微薄的馈赠。有人说，晶体的光芒里藏着死者最后的体温。",
            unlocked = true,
            value = stats.totalCrystalsEarned or 0,
        })
        table.insert(items, {
            id = "crystals_spent",
            name = "消耗晶体",
            desc = "「自由是有代价的。」帝国如此宣称，却从不告诉人们代价由谁来付。而在母舰的补给站里，每一颗消耗的晶体，都是用生命换来的选择权。",
            unlocked = true,
            value = stats.totalCrystalsSpent or 0,
        })
        table.insert(items, {
            id = "hyperspace_jumps",
            name = "空间跳跃次数",
            desc = "每一次跳跃，都是一次与虚空的赌博。星图上的坐标渐渐远离帝国的疆域，也越来越接近那个被遗忘的名字。创世遗迹……或者说，回家的路。",
            unlocked = true,
            value = stats.totalHyperspaceJumps or 0,
        })
        table.insert(items, {
            id = "play_time",
            name = "累计航行时长",
            desc = "在超光速的折跃中，时间是最先被扭曲的东西。母舰上的时钟与银河标准时间早已脱节。但对流浪者而言，重要的从来不是过了多久，而是还要走多远。",
            unlocked = true,
            value = stats.totalPlayTime or 0,
            valueFormatted = StatsManager.FormatPlayTime(stats.totalPlayTime or 0),
        })
        table.insert(items, {
            id = "highest_wave",
            name = "最远航迹",
            desc = "星遥在舰桥上标记了这个数字。「这是我们走得最远的一次，」她说，「总有一天，这里会写着100。然后我们就能……」她没有说完。没有人知道终点是什么样子。",
            unlocked = true,
            value = stats.highestWave or 0,
        })
        table.insert(items, {
            id = "victories",
            name = "抵达次数",
            desc = "所谓的「胜利」，不过是又一次安全抵达了跳跃终点。真正的胜利，是找到创世遗迹的那一天。在那之前，每一次生还，都只是漫长旅途中的一小步。",
            unlocked = true,
            value = stats.totalVictories or 0,
        })
    elseif cat.id == "weapons" then
        -- Weapons.List 是 key-value 表
        for id, w in pairs(Weapons.List) do
            table.insert(items, {
                id = id,
                name = w.name,
                desc = w.description or "",
                unlocked = GalleryUI.unlocked.weapons[id] or false,
                data = w,
            })
        end
        -- 按名称排序
        table.sort(items, function(a, b) return a.name < b.name end)
    elseif cat.id == "modules" then
        -- Modules.List 是数组
        for _, m in ipairs(Modules.List) do
            table.insert(items, {
                id = m.id,
                name = m.name,
                desc = m.description or "",
                unlocked = GalleryUI.unlocked.modules[m.id] or false,
                data = m,
            })
        end
    elseif cat.id == "enemies" then
        -- Enemies.List 是 key-value 表
        for id, e in pairs(Enemies.List) do
            table.insert(items, {
                id = id,
                name = e.name,
                desc = e.description or (e.isBoss and "Boss" or "普通敌人"),
                unlocked = GalleryUI.unlocked.enemies[id] or false,
                data = e,
            })
        end
        -- 按名称排序
        table.sort(items, function(a, b) return a.name < b.name end)
    elseif cat.id == "achievements" then
        -- 成就系统暂未实现
        table.insert(items, {
            id = "placeholder",
            name = "敬请期待",
            desc = "成就系统开发中...",
            unlocked = false,
        })
    end
    
    return items
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function GalleryUI.CollectImagePaths()
    local paths = {}
    -- 武器图标（Weapons.List 是 key-value 表）
    for id, _ in pairs(Weapons.List) do
        paths[#paths + 1] = "images/weapons/" .. id .. ".jpg"
    end
    -- 模块图标（Modules.List 是数组）
    for _, m in ipairs(Modules.List) do
        paths[#paths + 1] = "images/modules/" .. m.id .. ".jpg"
    end
    -- 敌人图标（Enemies.List 是 key-value 表）
    for id, _ in pairs(Enemies.List) do
        paths[#paths + 1] = "images/enemies/" .. id .. ".jpg"
    end
    return paths
end

function GalleryUI.Show(onClose)
    local paths = GalleryUI.CollectImagePaths()
    ImageLoader.PreloadGate(paths, function()
        GalleryUI.visible = true
        GalleryUI.onClose = onClose
        GalleryUI.Init()
    end, "正在加载图鉴数据...")
end

function GalleryUI.Hide()
    GalleryUI.visible = false
    if GalleryUI.onClose then
        GalleryUI.onClose()
    end
end

-- ============================================================================
-- 输入处理
-- ============================================================================

function GalleryUI.HandleInput()
    if not GalleryUI.visible then return false end
    
    -- 左右切换分类
    if input:GetKeyPress(KEY_LEFT) or input:GetKeyPress(KEY_A) then
        GalleryUI.showKeyboardFocus = true  -- 键盘操作时显示选中框
        GalleryUI.selectedCategory = GalleryUI.selectedCategory - 1
        if GalleryUI.selectedCategory < 1 then
            GalleryUI.selectedCategory = #GalleryUI.categories
        end
        GalleryUI.selectedItem = 1
        GalleryUI.scrollOffset = 0
        return true
    end
    
    if input:GetKeyPress(KEY_RIGHT) or input:GetKeyPress(KEY_D) then
        GalleryUI.showKeyboardFocus = true  -- 键盘操作时显示选中框
        GalleryUI.selectedCategory = GalleryUI.selectedCategory + 1
        if GalleryUI.selectedCategory > #GalleryUI.categories then
            GalleryUI.selectedCategory = 1
        end
        GalleryUI.selectedItem = 1
        GalleryUI.scrollOffset = 0
        return true
    end
    
    -- 上下选择项目
    local items = GalleryUI.GetCurrentItems()
    
    if input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) then
        GalleryUI.showKeyboardFocus = true  -- 键盘操作时显示选中框
        GalleryUI.selectedItem = GalleryUI.selectedItem - 1
        if GalleryUI.selectedItem < 1 then
            GalleryUI.selectedItem = #items
        end
        return true
    end
    
    if input:GetKeyPress(KEY_DOWN) or input:GetKeyPress(KEY_S) then
        GalleryUI.showKeyboardFocus = true  -- 键盘操作时显示选中框
        GalleryUI.selectedItem = GalleryUI.selectedItem + 1
        if GalleryUI.selectedItem > #items then
            GalleryUI.selectedItem = 1
        end
        return true
    end
    
    -- ESC 或 Enter 返回
    if input:GetKeyPress(KEY_ESCAPE) or input:GetKeyPress(KEY_RETURN) then
        GalleryUI.Hide()
        return true
    end
    
    return false
end

function GalleryUI.HandleTouch(sw, sh)
    if not GalleryUI.visible then return false end
    
    -- 获取安全区信息
    local safe = GalleryUI.safeArea or UISafeArea.Calculate(sw, sh)
    
    -- 获取屏幕坐标
    local screenX = TouchInput.x
    local screenY = TouchInput.y
    
    -- 检查是否在安全区内
    if not UISafeArea.Contains(safe, screenX, screenY) then
        -- 安全区外释放拖动
        if GalleryUI.isDragging then
            GalleryUI.isDragging = false
            GalleryUI.hasDragged = false
        end
        return false
    end
    
    -- 转换为安全区本地坐标
    local mx, my = UISafeArea.ToLocal(safe, screenX, screenY)
    
    local uw, uh = safe.w, safe.h
    local baseUnit = safe.baseUnit
    
    -- 使用共享布局计算
    local layout = GalleryUI.GetLayout(uw, uh, baseUnit)
    local tabY = layout.tabY
    local tabH = layout.tabH
    local listX = layout.listX
    local listY = layout.listY
    local listW = layout.listW
    local listH = layout.listH
    
    -- 详情区域布局
    local detailX = layout.detailX
    local detailW = layout.detailW
    local detailY = layout.detailY
    local detailH = layout.detailH
    
    -- 判断鼠标在哪个区域
    local inListArea = UIScreen.HitTest(mx, my, listX, listY, listW, listH)
    local inDetailArea = UIScreen.HitTest(mx, my, detailX, detailY, detailW, detailH)
    
    -- 鼠标滚轮滚动
    local wheel = input:GetMouseMoveWheel()
    if wheel ~= 0 then
        local scrollAmount = baseUnit * 3
        if inDetailArea then
            -- 详情区域滚动
            GalleryUI.detailScrollOffset = GalleryUI.detailScrollOffset + wheel * scrollAmount
            GalleryUI.detailScrollOffset = math.max(-GalleryUI.detailMaxScrollOffset, math.min(0, GalleryUI.detailScrollOffset))
        else
            -- 列表区域滚动
            GalleryUI.scrollOffset = GalleryUI.scrollOffset + wheel * scrollAmount
            GalleryUI.scrollOffset = math.max(-GalleryUI.maxScrollOffset, math.min(0, GalleryUI.scrollOffset))
        end
        return true
    end
    
    -- 列表拖拽滚动处理
    if input:GetMouseButtonDown(MOUSEB_LEFT) and GalleryUI.isDragging then
        local dy = my - GalleryUI.dragStartY
        if math.abs(dy) > baseUnit * 0.3 then
            GalleryUI.hasDragged = true
            GalleryUI.scrollOffset = GalleryUI.dragStartScroll + dy
            GalleryUI.scrollOffset = math.max(-GalleryUI.maxScrollOffset, math.min(0, GalleryUI.scrollOffset))
        end
    end
    
    -- 详情区域拖拽滚动处理
    if input:GetMouseButtonDown(MOUSEB_LEFT) and GalleryUI.isDetailDragging then
        local dy = my - GalleryUI.detailDragStartY
        if math.abs(dy) > baseUnit * 0.3 then
            GalleryUI.detailScrollOffset = GalleryUI.detailDragStartScroll + dy
            GalleryUI.detailScrollOffset = math.max(-GalleryUI.detailMaxScrollOffset, math.min(0, GalleryUI.detailScrollOffset))
        end
    end
    
    -- 鼠标释放检测
    local mouseDown = input:GetMouseButtonDown(MOUSEB_LEFT)
    if not mouseDown then
        -- 列表拖拽释放
        if GalleryUI.isDragging then
            if GalleryUI.pendingSelectItem and not GalleryUI.hasDragged then
                GalleryUI.selectedItem = GalleryUI.pendingSelectItem
                GalleryUI.detailScrollOffset = 0  -- 切换项目时重置详情滚动
            end
            GalleryUI.pendingSelectItem = nil
            GalleryUI.isDragging = false
            GalleryUI.hasDragged = false
        end
        -- 详情拖拽释放
        if GalleryUI.isDetailDragging then
            GalleryUI.isDetailDragging = false
        end
    end
    
    if UIScreen.IsMousePressed() then
        GalleryUI.showKeyboardFocus = false
        GalleryUI.hasDragged = false  -- 重置拖拽标记
        
        -- 检测分类标签点击
        for i, cat in ipairs(GalleryUI.categories) do
            local tabX = layout.tabStartX + (i - 1) * layout.tabW
            if UIScreen.HitTest(mx, my, tabX, tabY, layout.tabW, tabH) then
                GalleryUI.selectedCategory = i
                GalleryUI.selectedItem = 1
                GalleryUI.scrollOffset = 0
                GalleryUI.detailScrollOffset = 0  -- 重置详情滚动
                return true
            end
        end
        
        -- 检测左上角返回按钮
        local backLayout = layout.backLayout
        if UIScreen.HitTest(mx, my, backLayout.x, backLayout.y - backLayout.h/2, backLayout.w, backLayout.h) then
            GalleryUI.Hide()
            return true
        end
        
        -- 检测列表区域点击（准备拖拽或选择项目）
        if inListArea then
            GalleryUI.isDragging = true
            GalleryUI.dragStartY = my
            GalleryUI.dragStartScroll = GalleryUI.scrollOffset
            
            -- 立即检测项目点击
            local itemH = layout.itemH
            local gap = layout.itemGap
            local items = GalleryUI.GetCurrentItems()
            
            for i, item in ipairs(items) do
                local itemY = listY + (i - 1) * (itemH + gap) + GalleryUI.scrollOffset
                if my >= itemY and my <= itemY + itemH and
                   itemY >= listY and itemY + itemH <= listY + listH then
                    GalleryUI.pendingSelectItem = i
                    break
                end
            end
            return true
        end
        
        -- 检测详情区域点击（准备拖拽滚动）
        if inDetailArea then
            GalleryUI.isDetailDragging = true
            GalleryUI.detailDragStartY = my
            GalleryUI.detailDragStartScroll = GalleryUI.detailScrollOffset
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- 渲染
-- ============================================================================

-- 缓存安全区信息（用于输入处理）
GalleryUI.safeArea = nil

function GalleryUI.Render(nvg, sw, sh)
    if not GalleryUI.visible then return end
    
    GalleryUI.animTime = GalleryUI.animTime + 0.016
    
    -- 全屏背景
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(8, 12, 20, 245))
    nvgFill(nvg)
    
    -- 计算安全区
    local safe = UISafeArea.Calculate(sw, sh)
    GalleryUI.safeArea = safe
    
    -- 使用安全区尺寸
    local uw, uh = safe.w, safe.h
    local baseUnit = safe.baseUnit
    local fonts = UIStyle.GetTypography(uw, uh)
    
    -- 使用共享布局计算
    local layout = GalleryUI.GetLayout(uw, uh, baseUnit)
    
    -- 进入安全区绘制
    UISafeArea.BeginSafeArea(nvg, safe)
    
    -- 分类标签（顶部，与返回按钮对齐）
    GalleryUI.DrawCategoryTabs(nvg, layout.tabStartX, layout.tabY, layout.tabTotalW, baseUnit, fonts)
    
    -- 列表区域（竖屏上方，横屏左侧）
    GalleryUI.DrawItemList(nvg, layout.listX, layout.listY, layout.listW, layout.listH, baseUnit, fonts)
    
    -- 详情区域（竖屏下方，横屏右侧）
    GalleryUI.DrawItemDetail(nvg, layout.detailX, layout.detailY, layout.detailW, layout.detailH, baseUnit, fonts)
    
    -- 左上角返回按钮
    local mx, my = UIScreen.GetLocalMouse(GalleryUI, uw, uh)
    local backLayout = layout.backLayout
    local backPressed = mx and my and UIScreen.HitTest(mx, my, backLayout.x, backLayout.y - backLayout.h/2, backLayout.w, backLayout.h) and input:GetMouseButtonDown(MOUSEB_LEFT)
    UIStyle.DrawBackButton(nvg, baseUnit, fonts.buttonText * 0.9, backPressed)
    
    UISafeArea.EndSafeArea(nvg)
end

function GalleryUI.DrawCategoryTabs(nvg, x, y, totalW, baseUnit, fonts)
    local tabW = totalW / #GalleryUI.categories
    local tabH = baseUnit * 2.5
    
    for i, cat in ipairs(GalleryUI.categories) do
        local tabX = x + (i - 1) * tabW
        -- 当前分类始终高亮（功能性状态指示）
        local isCurrentCategory = (i == GalleryUI.selectedCategory)
        
        -- 标签背景（当前分类始终高亮）
        if isCurrentCategory then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, tabX + baseUnit * 0.3, y, tabW - baseUnit * 0.6, tabH, baseUnit * 0.3)
            nvgFillColor(nvg, nvgRGBA(60, 140, 200, 80))
            nvgFill(nvg)
            
            nvgStrokeColor(nvg, nvgRGBA(80, 180, 255, 200))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)
        end
        
        -- 标签文字
        nvgFontSize(nvg, fonts.buttonText)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, isCurrentCategory and nvgRGBA(255, 255, 255, 255) or nvgRGBA(150, 160, 170, 200))
        nvgText(nvg, tabX + tabW / 2, y + tabH / 2, cat.label)
    end
    
    -- 底部分隔线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, x + baseUnit, y + tabH + baseUnit * 0.3)
    nvgLineTo(nvg, x + totalW - baseUnit, y + tabH + baseUnit * 0.3)
    nvgStrokeColor(nvg, nvgRGBA(60, 100, 140, 100))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
end

function GalleryUI.DrawItemList(nvg, x, y, w, h, baseUnit, fonts)
    local items = GalleryUI.GetCurrentItems()
    -- 使用与布局一致的参数
    local itemH = baseUnit * 2.5
    local gap = baseUnit * 0.4
    
    -- 计算最大滚动量
    local totalHeight = #items * (itemH + gap) - gap
    GalleryUI.maxScrollOffset = math.max(0, totalHeight - h)
    
    -- 列表区域背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.3)
    nvgFillColor(nvg, nvgRGBA(15, 22, 35, 180))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(40, 60, 90, 100))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- 裁剪区域
    nvgSave(nvg)
    nvgScissor(nvg, x, y, w, h)
    
    for i, item in ipairs(items) do
        local itemY = y + (i - 1) * (itemH + gap) + GalleryUI.scrollOffset
        
        -- 跳过不可见项
        if itemY + itemH < y or itemY > y + h then
            goto continue
        end
        
        -- 当前选中项
        local isSelected = (i == GalleryUI.selectedItem)
        
        -- 项目背景
        if isSelected then
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, x + baseUnit * 0.3, itemY, w - baseUnit * 0.6, itemH, baseUnit * 0.2)
            nvgFillColor(nvg, nvgRGBA(60, 140, 200, 80))
            nvgFill(nvg)
            
            nvgStrokeColor(nvg, nvgRGBA(80, 180, 255, 180))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)
        end
        
        -- 项目名称
        nvgFontSize(nvg, fonts.statValue)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        
        local cat = GalleryUI.categories[GalleryUI.selectedCategory]
        
        if item.unlocked then
            -- 统计分类：显示名称 + 数值
            if cat.id == "stats" then
                -- 名称
                nvgFillColor(nvg, isSelected and nvgRGBA(255, 255, 255, 255) or nvgRGBA(200, 210, 220, 220))
                nvgText(nvg, x + baseUnit * 0.8, itemY + itemH / 2, item.name)
                -- 数值（右对齐）
                nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                local displayValue = item.valueFormatted or tostring(item.value or 0)
                nvgFillColor(nvg, nvgRGBA(100, 220, 180, 255))
                nvgText(nvg, x + w - baseUnit * 0.8, itemY + itemH / 2, displayValue)
            else
                nvgFillColor(nvg, isSelected and nvgRGBA(255, 255, 255, 255) or nvgRGBA(200, 210, 220, 220))
                nvgText(nvg, x + baseUnit * 0.8, itemY + itemH / 2, item.name)
            end
        else
            nvgFillColor(nvg, nvgRGBA(100, 110, 120, 150))
            nvgText(nvg, x + baseUnit * 0.8, itemY + itemH / 2, "???")
        end
        
        ::continue::
    end
    
    nvgRestore(nvg)
    
    -- 滚动条
    if GalleryUI.maxScrollOffset > 0 then
        local scrollRatio = -GalleryUI.scrollOffset / GalleryUI.maxScrollOffset
        scrollRatio = math.max(0, math.min(1, scrollRatio))
        
        local scrollBarH = math.max(baseUnit * 2, h * (h / totalHeight))
        local scrollBarY = y + scrollRatio * (h - scrollBarH)
        
        -- 滚动条轨道
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x + w - baseUnit * 0.5, y + baseUnit * 0.3, baseUnit * 0.35, h - baseUnit * 0.6, baseUnit * 0.15)
        nvgFillColor(nvg, nvgRGBA(30, 45, 60, 100))
        nvgFill(nvg)
        
        -- 滚动条滑块
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x + w - baseUnit * 0.5, scrollBarY, baseUnit * 0.35, scrollBarH, baseUnit * 0.15)
        nvgFillColor(nvg, nvgRGBA(80, 140, 200, 180))
        nvgFill(nvg)
    end
end

function GalleryUI.DrawItemDetail(nvg, x, y, w, h, baseUnit, fonts)
    local items = GalleryUI.GetCurrentItems()
    local item = items[GalleryUI.selectedItem]
    
    if not item then return end
    
    -- 详情面板背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.4)
    nvgFillColor(nvg, nvgRGBA(15, 22, 35, 200))
    nvgFill(nvg)
    
    nvgStrokeColor(nvg, nvgRGBA(50, 80, 120, 100))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    local padding = baseUnit * 0.8
    
    if not item.unlocked then
        -- 未解锁提示
        nvgFontSize(nvg, fonts.cardTitle)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(100, 110, 120, 150))
        nvgText(nvg, x + w / 2, y + h / 2, "未解锁")
        return
    end
    
    -- ============ 顶部区域：大图标 + 名称/类型 ============
    local cat = GalleryUI.categories[GalleryUI.selectedCategory]
    local iconSize = baseUnit * 8  -- 更大的图标
    local iconX = x + padding
    local iconY = y + padding
    local hasDetailIcon = false
    
    if item.id then
        local imageCache = nil
        local iconPath = nil
        
        if cat.id == "weapons" then
            imageCache = GalleryUI.weaponImages
            iconPath = "images/weapons/" .. item.id .. ".jpg"
        elseif cat.id == "modules" then
            imageCache = GalleryUI.moduleImages
            iconPath = "images/modules/" .. item.id .. ".jpg"
        elseif cat.id == "enemies" then
            imageCache = GalleryUI.enemyImages
            iconPath = "images/enemies/" .. item.id .. ".jpg"
        end
        
        if imageCache and iconPath then
            local img = ImageLoader.GetImage(nvg, iconPath, imageCache, item.id)
            
            if img and img > 0 then
                hasDetailIcon = true
                local imgPaint = nvgImagePattern(nvg, iconX, iconY, iconSize, iconSize, 0, img, 1.0)
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.3)
                nvgFillPaint(nvg, imgPaint)
                nvgFill(nvg)
                
                -- 图标边框（品质色）
                local tierColor = {r = 80, g = 140, b = 200}
                if item.data and item.data.tier then
                    tierColor = UIStyle.GetTierColor(item.data.tier)
                end
                nvgStrokeColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 200))
                nvgStrokeWidth(nvg, 2)
                nvgStroke(nvg)
            elseif img == -2 then
                -- 下载中：显示骨架屏占位，保留图标区域布局
                hasDetailIcon = true
                ImageLoader.RenderPlaceholder(nvg, iconX, iconY, iconSize, iconSize, GalleryUI.animTime, baseUnit * 0.3)
            end
        end
    end
    
    -- 图标右侧的文字区域
    local textX = hasDetailIcon and (iconX + iconSize + padding) or (x + padding)
    local textW = hasDetailIcon and (w - iconSize - padding * 3) or (w - padding * 2)
    local textY = iconY
    
    -- 名称（大字）
    nvgFontSize(nvg, fonts.cardTitle * 1.2)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(80, 180, 255, 255))
    nvgText(nvg, textX, textY, item.name)
    textY = textY + fonts.cardTitle * 1.2 + baseUnit * 0.5
    
    -- 武器标签（和商店一致）
    if cat.id == "weapons" and item.data and item.data.tags then
        local tagTexts = {}
        for _, tag in ipairs(item.data.tags) do
            local setDef = TagSetBonuses.Sets[tag]
            if setDef then
                table.insert(tagTexts, setDef.icon .. " " .. tag)
            end
        end
        if #tagTexts > 0 then
            nvgFontSize(nvg, fonts.statLabel)
            nvgFillColor(nvg, nvgRGBA(180, 200, 220, 220))
            nvgText(nvg, textX, textY, table.concat(tagTexts, "  "))
            textY = textY + fonts.statLabel + baseUnit * 0.5
        end
    elseif cat.id == "modules" and item.data then
        local rarityNames = {"普通", "稀有", "史诗"}
        local typeText = (rarityNames[item.data.rarity] or "普通") .. " · " .. (item.data.type or "被动")
        nvgFontSize(nvg, fonts.statLabel)
        nvgFillColor(nvg, nvgRGBA(140, 150, 160, 200))
        nvgText(nvg, textX, textY, typeText)
        textY = textY + fonts.statLabel + baseUnit * 0.5
    elseif cat.id == "enemies" and item.data then
        local typeText = item.data.isBoss and "Boss" or (item.data.isElite and "精英敌人" or "普通敌人")
        nvgFontSize(nvg, fonts.statLabel)
        nvgFillColor(nvg, nvgRGBA(140, 150, 160, 200))
        nvgText(nvg, textX, textY, typeText)
        textY = textY + fonts.statLabel + baseUnit * 0.5
    elseif cat.id == "stats" then
        -- 统计数据：显示大数值
        local displayValue = item.valueFormatted or tostring(item.value or 0)
        nvgFontSize(nvg, fonts.cardTitle * 2.5)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(100, 220, 180, 255))
        nvgText(nvg, textX, textY, displayValue)
        textY = textY + fonts.cardTitle * 2.5 + baseUnit * 0.5
    end
    
    -- 核心属性（紧凑横向显示）- 统计分类跳过
    local statsText = GalleryUI.GetCompactStats(item, cat.id)
    if statsText ~= "" then
        nvgFontSize(nvg, fonts.statValue)
        nvgFillColor(nvg, nvgRGBA(200, 210, 220, 230))
        nvgText(nvg, textX, textY, statsText)
    end
    
    -- ============ 中部分隔线 ============
    local separatorY = iconY + iconSize + baseUnit * 0.8
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, x + padding, separatorY)
    nvgLineTo(nvg, x + w - padding, separatorY)
    nvgStrokeColor(nvg, nvgRGBA(60, 100, 140, 80))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- ============ 下部可滚动区域 ============
    local scrollAreaY = separatorY + baseUnit * 0.5
    local scrollAreaH = h - (scrollAreaY - y) - padding
    local scrollX = x + padding
    local scrollW = w - padding * 2 - baseUnit * 0.8  -- 留出滚动条空间
    
    -- 计算内容总高度
    local contentStartY = 0
    local py = contentStartY
    
    -- 描述文字高度（使用 NvgHelper 计算，与渲染一致）
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, fonts.description)
    local descH = NvgHelper.TextBoxHeight(nvg, scrollW, item.desc or "")
    py = py + descH + baseUnit * 0.8
    
    -- 背景故事高度（如果有lore）
    local loreH = 0
    local loreText = item.data and item.data.lore
    if loreText then
        nvgFontSize(nvg, fonts.description * 0.9)
        loreH = NvgHelper.TextBoxHeight(nvg, scrollW, loreText) + baseUnit * 0.5  -- 包含分隔线
        py = py + loreH + baseUnit * 0.5
    end
    
    -- 套装效果高度（双列布局）
    local setContentH = 0
    if cat.id == "weapons" and item.data and item.data.tags and #item.data.tags > 0 then
        setContentH = baseUnit * 0.8 + fonts.statLabel + baseUnit * 0.5  -- 分隔线 + 标题
        local colW = scrollW / 2
        local maxColH = 0
        
        for idx, tag in ipairs(item.data.tags) do
            local setDef = TagSetBonuses.Sets[tag]
            if setDef then
                local tagH = fonts.statValue + baseUnit * 0.3
                local tiers = {2, 3, 4, 5, 6}
                for _, tierNum in ipairs(tiers) do
                    if setDef.bonuses[tierNum] then
                        tagH = tagH + fonts.description * 0.85 + baseUnit * 0.1
                    end
                end
                tagH = tagH + baseUnit * 0.4
                maxColH = math.max(maxColH, tagH)
                
                -- 每两个标签换行
                if idx % 2 == 0 then
                    setContentH = setContentH + maxColH
                    maxColH = 0
                end
            end
        end
        -- 处理奇数个标签的情况
        if #item.data.tags % 2 == 1 then
            setContentH = setContentH + maxColH
        end
    end
    py = py + setContentH
    
    local totalContentH = py
    GalleryUI.detailMaxScrollOffset = math.max(0, totalContentH - scrollAreaH)
    GalleryUI.detailScrollOffset = math.max(-GalleryUI.detailMaxScrollOffset, math.min(0, GalleryUI.detailScrollOffset))
    
    -- 裁剪滚动区域
    nvgSave(nvg)
    nvgScissor(nvg, x + padding, scrollAreaY, w - padding * 2, scrollAreaH)
    
    local drawY = scrollAreaY + GalleryUI.detailScrollOffset
    
    -- 描述文字
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, fonts.description)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    -- 统计分类使用背景故事风格的暖灰色
    if cat.id == "stats" then
        nvgFillColor(nvg, nvgRGBA(160, 150, 140, 200))
    else
        nvgFillColor(nvg, nvgRGBA(180, 190, 200, 220))
    end
    local renderedDescH = NvgHelper.TextBox(nvg, scrollX, drawY, scrollW, item.desc or "")
    drawY = drawY + renderedDescH + baseUnit * 0.8
    
    -- 背景故事（如果有lore）
    if loreText then
        -- 分隔线
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, scrollX, drawY)
        nvgLineTo(nvg, scrollX + scrollW, drawY)
        nvgStrokeColor(nvg, nvgRGBA(80, 60, 40, 100))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
        drawY = drawY + baseUnit * 0.5
        
        -- 故事内容（魂系风格，暖灰色营造神秘感）
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, fonts.description * 0.9)
        nvgFillColor(nvg, nvgRGBA(160, 150, 140, 200))
        local loreTextH = NvgHelper.TextBox(nvg, scrollX, drawY, scrollW, loreText)
        drawY = drawY + loreTextH + baseUnit * 0.5
    end
    
    -- 武器套装效果（双列横向布局）
    if cat.id == "weapons" and item.data and item.data.tags and #item.data.tags > 0 then
        -- 分隔线
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, scrollX, drawY)
        nvgLineTo(nvg, scrollX + scrollW, drawY)
        nvgStrokeColor(nvg, nvgRGBA(60, 80, 100, 100))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
        drawY = drawY + baseUnit * 0.6
        
        -- 标题
        nvgFontSize(nvg, fonts.statLabel)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(180, 200, 220, 200))
        nvgText(nvg, scrollX, drawY, "套装效果")
        drawY = drawY + fonts.statLabel + baseUnit * 0.5
        
        -- 双列布局
        local colW = scrollW / 2
        local rowStartY = drawY
        local col = 0
        local maxRowH = 0
        
        for idx, tag in ipairs(item.data.tags) do
            local setDef = TagSetBonuses.Sets[tag]
            if setDef then
                local color = setDef.color
                local colX = scrollX + col * colW
                local tagY = rowStartY
                
                -- 标签名称
                nvgFontSize(nvg, fonts.statValue * 0.95)
                nvgFillColor(nvg, nvgRGBA(color.r, color.g, color.b, 255))
                nvgText(nvg, colX, tagY, setDef.icon .. " " .. tag)
                tagY = tagY + fonts.statValue * 0.95 + baseUnit * 0.2
                
                -- 各等级效果（紧凑显示）
                nvgFontSize(nvg, fonts.description * 0.8)
                local tiers = {2, 3, 4, 5, 6}
                for _, tierNum in ipairs(tiers) do
                    local tierBonus = setDef.bonuses[tierNum]
                    if tierBonus then
                        nvgFillColor(nvg, nvgRGBA(120, 130, 140, 200))
                        nvgText(nvg, colX + baseUnit * 0.5, tagY, string.format("(%d) %s", tierNum, tierBonus.desc))
                        tagY = tagY + fonts.description * 0.8 + baseUnit * 0.08
                    end
                end
                
                local thisTagH = tagY - rowStartY + baseUnit * 0.3
                maxRowH = math.max(maxRowH, thisTagH)
                
                col = col + 1
                if col >= 2 then
                    col = 0
                    rowStartY = rowStartY + maxRowH
                    maxRowH = 0
                end
            end
        end
    end
    
    nvgRestore(nvg)
    
    -- 滚动条
    if GalleryUI.detailMaxScrollOffset > 0 then
        local scrollRatio = -GalleryUI.detailScrollOffset / GalleryUI.detailMaxScrollOffset
        scrollRatio = math.max(0, math.min(1, scrollRatio))
        
        local scrollBarH = math.max(baseUnit * 2, scrollAreaH * (scrollAreaH / totalContentH))
        local scrollBarY = scrollAreaY + scrollRatio * (scrollAreaH - scrollBarH)
        
        -- 滚动条轨道
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x + w - padding - baseUnit * 0.4, scrollAreaY, baseUnit * 0.3, scrollAreaH, baseUnit * 0.15)
        nvgFillColor(nvg, nvgRGBA(30, 45, 60, 100))
        nvgFill(nvg)
        
        -- 滚动条滑块
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x + w - padding - baseUnit * 0.4, scrollBarY, baseUnit * 0.3, scrollBarH, baseUnit * 0.15)
        nvgFillColor(nvg, nvgRGBA(80, 140, 200, 180))
        nvgFill(nvg)
    end
end

-- 获取紧凑格式的属性文本
function GalleryUI.GetCompactStats(item, catId)
    if not item.data then return "" end
    
    local parts = {}
    
    if catId == "weapons" then
        if item.data.damage then
            table.insert(parts, "伤害 " .. item.data.damage)
        end
        if item.data.cooldown then
            table.insert(parts, "射速 " .. string.format("%.1f/s", 1 / item.data.cooldown))
        end
        if item.data.range then
            table.insert(parts, "射程 " .. string.format("%.0fm", item.data.range))
        end
    elseif catId == "modules" then
        if item.data.price then
            table.insert(parts, item.data.price .. " 晶体")
        end
        if item.data.maxStack and item.data.maxStack > 1 then
            table.insert(parts, "可堆叠×" .. item.data.maxStack)
        end
    elseif catId == "enemies" then
        if item.data.hp then
            table.insert(parts, "HP " .. item.data.hp)
        end
        if item.data.damage then
            table.insert(parts, "伤害 " .. item.data.damage)
        end
    end
    
    return table.concat(parts, " · ")
end

function GalleryUI.DrawWeaponStats(nvg, x, y, w, weapon, baseUnit, fonts)
    -- 计算射速（1/冷却时间）
    local fireRate = weapon.cooldown and string.format("%.1f/s", 1 / weapon.cooldown) or "?"
    local stats = {
        {"伤害", weapon.damage or "?"},
        {"射速", fireRate},
        {"射程", weapon.range and string.format("%.0fm", weapon.range) or "?"},
        {"类型", weapon.type or "?"},
        {"价格", weapon.price and (weapon.price .. " 晶体") or "?"},
    }
    
    GalleryUI.DrawStatList(nvg, x, y, w, stats, baseUnit, fonts)
end

function GalleryUI.DrawModuleStats(nvg, x, y, w, module, baseUnit, fonts)
    -- 稀有度显示
    local rarityNames = {"普通", "稀有", "史诗"}
    local rarityName = rarityNames[module.rarity] or "普通"
    
    local stats = {
        {"类型", module.type or "被动"},
        {"稀有度", rarityName},
        {"价格", module.price and (module.price .. " 晶体") or "?"},
        {"堆叠上限", module.maxStack or 1},
    }
    
    GalleryUI.DrawStatList(nvg, x, y, w, stats, baseUnit, fonts)
end

function GalleryUI.DrawEnemyStats(nvg, x, y, w, enemy, baseUnit, fonts)
    local stats = {
        {"生命值", enemy.hp or "?"},
        {"伤害", enemy.damage or "?"},
        {"移速", enemy.moveSpeed and string.format("%.1f", enemy.moveSpeed) or "?"},
        {"类型", enemy.isBoss and "Boss" or (enemy.isElite and "精英" or "普通")},
    }
    
    GalleryUI.DrawStatList(nvg, x, y, w, stats, baseUnit, fonts)
end

function GalleryUI.DrawStatList(nvg, x, y, w, stats, baseUnit, fonts)
    local lineH = fonts.statLabel * 1.8  -- 行高 = 字体 × 1.8
    
    for i, stat in ipairs(stats) do
        local ly = y + (i - 1) * lineH
        
        -- 标签
        nvgFontSize(nvg, fonts.statLabel)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(120, 130, 140, 200))
        nvgText(nvg, x, ly, stat[1] .. ":")
        
        -- 值（标签后留足空间）
        local labelWidth = fonts.statLabel * 4.5  -- 标签宽度
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
        nvgText(nvg, x + labelWidth, ly, tostring(stat[2]))
    end
end

return GalleryUI
