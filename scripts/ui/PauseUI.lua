-- ============================================================================
-- 星河战姬 Starkyries - 暂停菜单（主协调器）
-- 状态管理 + 布局分派，渲染与输入委托给子模块
-- ============================================================================
--
-- 子模块：
--   PauseUIStats.lua      - 属性面板渲染
--   PauseUIInventory.lua  - 武器/道具格子渲染 + DPS 计算
--   PauseUIEnemy.lua      - 敌人面板 + 按钮渲染
--   PauseUIInput.lua      - 输入处理（触摸、拖动、滚动）
--
-- ============================================================================

local UIStyle = require("ui.UIStyle")
local UIScreen = require("ui.UIScreen")
local UISafeArea = require("ui.UISafeArea")
local ShopCards = require("ui.shop.ShopCards")
local ImageLoader = require("utils.ImageLoader")

-- 子模块
local PauseUIStats = require("ui.PauseUIStats")
local PauseUIInventory = require("ui.PauseUIInventory")
local PauseUIEnemy = require("ui.PauseUIEnemy")
local PauseUIInput = require("ui.PauseUIInput")

local PauseUI = {}

-- ============================================================================
-- 状态
-- ============================================================================
PauseUI.visible = false
PauseUI.animTime = 0
PauseUI.statsTab = 1  -- 1=主要, 2=次要（与Overlays保持一致）
PauseUI.scrollOffset = 0
PauseUI.maxScrollOffset = 0

-- 拖动滚动状态
PauseUI.isDragging = false
PauseUI.dragStartY = 0
PauseUI.dragStartScroll = 0
PauseUI.statsPanelRect = nil  -- 属性面板区域 {x, y, w, h}

-- 图标缓存
PauseUI.weaponImages = {}
PauseUI.moduleImages = {}

-- 回调
PauseUI.onResume = nil
PauseUI.onMainMenu = nil
PauseUI.onGallery = nil
PauseUI.onSettings = nil
PauseUI.onEndRun = nil

-- 按钮定义
PauseUI.buttons = {
    {id = "resume", text = "继续", variant = "primary"},
    {id = "mainMenu", text = "返回主菜单", variant = "default"},
    {id = "gallery", text = "图鉴", variant = "default"},
    {id = "settings", text = "设置", variant = "default"},
    {id = "endRun", text = "结束本轮游戏", variant = "danger"},
}

-- 按钮区域缓存（用于点击检测）
PauseUI.buttonRects = {}
PauseUI.tabRects = {}
PauseUI.weaponRects = {}  -- 武器格子区域
PauseUI.itemRects = {}    -- 道具格子区域

-- 详情弹窗状态
PauseUI.showDetail = false
PauseUI.detailItem = nil
PauseUI.detailPopupBtns = {}

-- 鼠标状态跟踪（用于释放检测）
PauseUI.wasMouseDown = false

-- 缓存安全区信息（用于输入处理）
PauseUI.safeArea = nil

-- ============================================================================
-- 公共接口
-- ============================================================================

function PauseUI.CollectImagePaths(player)
    local paths = {}
    if not player then return paths end
    -- 装备的武器图标
    if player.weapons then
        for _, weapon in ipairs(player.weapons) do
            if weapon.id then
                paths[#paths + 1] = "images/weapons/" .. weapon.id .. ".jpg"
            end
        end
    end
    -- 装备的模块图标
    if player.modules then
        for moduleId, count in pairs(player.modules) do
            if count > 0 then
                paths[#paths + 1] = "images/modules/" .. moduleId .. ".jpg"
            end
        end
    end
    return paths
end

function PauseUI.Show(player)
    local paths = PauseUI.CollectImagePaths(player)
    ImageLoader.PreloadGate(paths, function()
        PauseUI.visible = true
        PauseUI.animTime = 0
        PauseUI.statsTab = 1
        PauseUI.scrollOffset = 0
        PauseUI.showDetail = false
        PauseUI.detailItem = nil
    end, "正在加载暂停菜单...")
end

function PauseUI.Hide()
    PauseUI.visible = false
end

function PauseUI.IsVisible()
    return PauseUI.visible
end

-- ============================================================================
-- 渲染
-- ============================================================================

function PauseUI.Render(nvg, sw, sh, baseUnit, fontSize, player, battle, enemies)
    if not PauseUI.visible then return end

    PauseUI.animTime = PauseUI.animTime + 0.016
    PauseUI.buttonRects = {}
    PauseUI.tabRects = {}
    PauseUI.weaponRects = {}
    PauseUI.itemRects = {}

    -- 防御性检查
    player = player or {}
    battle = battle or {}
    enemies = enemies or {}

    -- 缓存player引用（用于详情弹窗）
    PauseUI.cachedPlayer = player

    -- 遮罩（全屏）
    UIStyle.DrawOverlay(nvg, sw, sh, {alpha = 200})

    -- 计算安全区
    local safe = UISafeArea.Calculate(sw, sh)
    PauseUI.safeArea = safe

    -- 使用安全区尺寸
    local uw, uh = safe.w, safe.h
    local correctBaseUnit = safe.baseUnit
    local isPortrait = safe.isPortrait
    local fonts = UIStyle.GetTypography(uw, uh)

    -- 进入安全区绘制
    UISafeArea.BeginSafeArea(nvg, safe)

    if isPortrait then
        PauseUI.RenderPortrait(nvg, uw, uh, correctBaseUnit, fonts, player, battle, enemies)
    else
        PauseUI.RenderLandscape(nvg, uw, uh, correctBaseUnit, fonts, player, battle, enemies)
    end

    -- 渲染详情弹窗（在主内容之上）
    if PauseUI.showDetail and PauseUI.detailItem then
        local layout = {
            sw = uw,
            sh = uh,
            baseUnit = correctBaseUnit,
            isPortrait = isPortrait,
        }
        local uiState = { detailSource = "pause" }
        PauseUI.detailPopupBtns = ShopCards.RenderDetailPopup(nvg, layout, PauseUI.detailItem, player, uiState, PauseUI.animTime)
    end

    UISafeArea.EndSafeArea(nvg)
end

-- 横屏布局
function PauseUI.RenderLandscape(nvg, sw, sh, baseUnit, fonts, player, battle, enemies)
    local totalW = math.min(sw * 0.92, baseUnit * 55)
    local totalH = sh * 0.90
    local startX = (sw - totalW) / 2
    local startY = (sh - totalH) / 2

    local gap = baseUnit * 0.6
    local leftW = totalW * 0.32   -- 属性面板
    local rightW = totalW * 0.22  -- 敌人+按钮
    local centerW = totalW - leftW - rightW - gap * 2

    -- 左侧：属性面板（委托给 PauseUIStats）
    PauseUIStats.Render(nvg, startX, startY, leftW, totalH, baseUnit, fonts, player, PauseUI)

    -- 中间：波次 + 武器 + 道具（委托给 PauseUIInventory）
    local centerX = startX + leftW + gap
    PauseUIInventory.RenderCenterPanel(nvg, centerX, startY, centerW, totalH, baseUnit, fonts, player, battle, PauseUI)

    -- 右侧：敌人 + 按钮（委托给 PauseUIEnemy）
    local rightX = centerX + centerW + gap
    PauseUIEnemy.RenderRightPanel(nvg, rightX, startY, rightW, totalH, baseUnit, fonts, enemies, battle, PauseUI)
end

-- 竖屏布局
function PauseUI.RenderPortrait(nvg, sw, sh, baseUnit, fonts, player, battle, enemies)
    local totalW = sw * 0.95
    local startX = (sw - totalW) / 2
    local gap = baseUnit * 0.4

    -- 上部：属性（紧凑）
    local statsH = sh * 0.35
    PauseUIStats.Render(nvg, startX, sh * 0.02, totalW, statsH, baseUnit, fonts, player, PauseUI)

    -- 中部：波次+武器+道具
    local centerY = sh * 0.02 + statsH + gap
    local centerH = sh * 0.35
    PauseUIInventory.RenderCenterPanel(nvg, startX, centerY, totalW, centerH, baseUnit, fonts, player, battle, PauseUI)

    -- 下部：敌人+按钮（并排）
    local bottomY = centerY + centerH + gap
    local bottomH = sh - bottomY - sh * 0.02
    local halfW = (totalW - gap) / 2

    PauseUIEnemy.RenderEnemyPanel(nvg, startX, bottomY, halfW, bottomH, baseUnit, fonts, enemies, battle)
    PauseUIEnemy.RenderButtons(nvg, startX + halfW + gap, bottomY, halfW, bottomH, baseUnit, fonts, PauseUI)
end

-- ============================================================================
-- 输入处理（委托给 PauseUIInput）
-- ============================================================================

function PauseUI.HandleTouch(sw, sh)
    return PauseUIInput.HandleTouch(sw, sh, PauseUI)
end

function PauseUI.HandleScroll(delta)
    PauseUIInput.HandleScroll(delta, PauseUI)
end

return PauseUI
