-- ============================================================================
-- 星河战姬 Starkyries - 补给箱开箱界面
-- 波次结束后显示，在商店界面之前
-- ============================================================================

local UIStyle = require("ui.UIStyle")
local UISafeArea = require("ui.UISafeArea")
local UIScreen = require("ui.UIScreen")
local Modules = require("config.modules")
local ShopCards = require("ui.shop.ShopCards")
local TouchInput = require("utils.TouchInput")
local ImageLoader = require("utils.ImageLoader")

local CrateOpenUI = {}

-- 图片缓存（使用 ShopCards 的缓存）
CrateOpenUI.moduleImages = ShopCards.moduleImages

-- 状态
CrateOpenUI.crates = {}           -- 待开箱列表
CrateOpenUI.selectedIndex = 0     -- 当前选中
CrateOpenUI.animTime = 0
CrateOpenUI.pressedBtn = nil      -- 按下的按钮

-- 回调
CrateOpenUI.onGetItem = nil       -- function(crateData) 获取物品
CrateOpenUI.onRecycleItem = nil   -- function(crateData) 回收物品
CrateOpenUI.onComplete = nil      -- function() 所有箱子处理完成

-- 品质颜色
local TierColors = {
    [1] = {r = 180, g = 180, b = 180, name = "普通"},
    [2] = {r = 100, g = 220, b = 100, name = "精良"},
    [3] = {r = 80, g = 160, b = 255, name = "稀有"},
    [4] = {r = 180, g = 100, b = 255, name = "传说"},
}

-- ============================================================================
-- 初始化
-- ============================================================================

function CrateOpenUI.Init(crates, player)
    print(string.format("[CrateOpenUI] Init called with %d crates", #crates))
    CrateOpenUI.crates = {}
    
    -- 处理每个箱子，生成实际内容
    for i, crateData in ipairs(crates) do
        print(string.format("[CrateOpenUI] Processing crate %d: type=%s", i, crateData and crateData.type or "nil"))
        local processedCrate = CrateOpenUI.ProcessCrate(crateData, player)
        table.insert(CrateOpenUI.crates, processedCrate)
    end
    
    print(string.format("[CrateOpenUI] After processing: %d crates", #CrateOpenUI.crates))
    CrateOpenUI.selectedIndex = #CrateOpenUI.crates > 0 and 1 or 0
    CrateOpenUI.animTime = 0
end

-- 处理箱子内容（生成具体模块）
-- 补给箱只包含模块，不含武器和晶体
function CrateOpenUI.ProcessCrate(crateData, player)
    local processed = {
        type = "module",  -- 补给箱只含模块
        tier = crateData.tier or 1,
    }
    
    -- 从对应等级模块池随机选择一个模块
    local tier = crateData.tier or 1
    local tierModules = Modules.GetByTier(tier)
    
    if #tierModules > 0 then
        local mod = tierModules[math.random(#tierModules)]
        processed.moduleId = mod.id
        processed.moduleName = mod.name
        processed.description = mod.description or ""
        processed.price = mod.price or (15 * tier)
        processed.moduleDef = mod  -- 保存完整模块定义供渲染详情
    else
        -- 没有找到对应等级模块，尝试降级
        for fallbackTier = tier - 1, 1, -1 do
            local fallbackPool = Modules.GetByTier(fallbackTier)
            if #fallbackPool > 0 then
                local mod = fallbackPool[math.random(#fallbackPool)]
                processed.moduleId = mod.id
                processed.moduleName = mod.name
                processed.description = mod.description or ""
                processed.price = mod.price or (15 * fallbackTier)
                processed.tier = fallbackTier
                processed.moduleDef = mod
                break
            end
        end
    end
    
    return processed
end

-- ============================================================================
-- 主渲染
-- ============================================================================

function CrateOpenUI.Render(nvg, sw, sh, baseUnit, fontSize, player)
    CrateOpenUI.animTime = CrateOpenUI.animTime + 0.016
    CrateOpenUI._player = player  -- 缓存供回调使用
    
    UIScreen.Render(nvg, sw, sh, CrateOpenUI, {
        drawBackground = CrateOpenUI.DrawBackground,
        drawContent = CrateOpenUI.DrawContent,
        useMask = false,
    })
end

-- 全屏背景
function CrateOpenUI.DrawBackground(nvg, sw, sh, baseUnit)
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(8, 14, 26, 245))
    nvgFill(nvg)
end

-- 内容绘制
function CrateOpenUI.DrawContent(nvg, uw, uh, baseUnit, fonts, safe)
    local player = CrateOpenUI._player
    local isPortrait = safe.isPortrait
    
    -- 计算布局
    local layout = CrateOpenUI.CalculateLayout(uw, uh, baseUnit, isPortrait)
    layout.fonts = fonts
    
    -- 标题
    CrateOpenUI.RenderHeader(nvg, layout)
    
    -- 箱子列表
    if #CrateOpenUI.crates > 0 then
        CrateOpenUI.RenderCrateList(nvg, layout, player)
    else
        -- 无箱子提示
        nvgFontSize(nvg, fonts.pageSubtitle)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(150, 160, 170, 200))
        nvgText(nvg, uw / 2, uh / 2, "本波次没有收集到补给箱")
    end
    
    -- 底部按钮
    CrateOpenUI.RenderBottomButtons(nvg, layout)
    
    -- 缓存布局供输入处理使用
    CrateOpenUI._layout = layout
end

-- ============================================================================
-- 布局计算
-- ============================================================================

function CrateOpenUI.CalculateLayout(sw, sh, baseUnit, isPortrait)
    local layout = {
        sw = sw,
        sh = sh,
        baseUnit = baseUnit,
        isPortrait = isPortrait,
        padding = sw * 0.03,
    }
    
    -- 标题区域（包含主标题和副标题）
    layout.headerY = sh * 0.05
    layout.headerH = sh * 0.12  -- 增加高度以容纳副标题
    
    -- 内容区域（从标题区域下方开始）
    layout.contentY = layout.headerY + layout.headerH + baseUnit * 0.5
    layout.contentH = sh * 0.65
    
    -- 箱子卡片
    if isPortrait then
        layout.columns = 2
        layout.cardW = (sw - layout.padding * 3) / 2
        layout.cardH = sh * 0.25
    else
        layout.columns = math.min(4, #CrateOpenUI.crates)
        layout.columns = math.max(1, layout.columns)
        local maxCardW = sw * 0.22
        layout.cardW = math.min(maxCardW, (sw - layout.padding * (layout.columns + 1)) / layout.columns)
        layout.cardH = sh * 0.55
    end
    layout.cardGap = baseUnit * 0.8
    
    -- 底部按钮区域
    layout.bottomY = sh * 0.88
    layout.bottomH = sh * 0.10
    layout.btnW = sw * 0.35
    layout.btnH = baseUnit * 2.5
    
    return layout
end

-- ============================================================================
-- 标题
-- ============================================================================

function CrateOpenUI.RenderHeader(nvg, layout)
    local fonts = layout.fonts
    local sw, sh = layout.sw, layout.sh
    
    -- 标题
    nvgFontSize(nvg, fonts.pageTitle)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(100, 180, 255, 255))
    nvgText(nvg, sw / 2, layout.headerY, "补给箱")
    
    -- 副标题
    nvgFontSize(nvg, fonts.pageSubtitle)
    nvgFillColor(nvg, nvgRGBA(150, 160, 170, 200))
    local subtitle = string.format("收集了 %d 个补给箱", #CrateOpenUI.crates)
    nvgText(nvg, sw / 2, layout.headerY + fonts.pageTitle + 5, subtitle)
end

-- ============================================================================
-- 箱子列表
-- ============================================================================

function CrateOpenUI.RenderCrateList(nvg, layout, player)
    local crates = CrateOpenUI.crates
    local fonts = layout.fonts
    local baseUnit = layout.baseUnit
    
    -- 计算起始位置（居中）
    local totalW = layout.columns * layout.cardW + (layout.columns - 1) * layout.cardGap
    local startX = (layout.sw - totalW) / 2
    
    -- 保存按钮区域供点击检测
    CrateOpenUI._crateButtons = {}
    
    for i, crate in ipairs(crates) do
        local col = (i - 1) % layout.columns
        local row = math.floor((i - 1) / layout.columns)
        
        local x = startX + col * (layout.cardW + layout.cardGap)
        local y = layout.contentY + row * (layout.cardH + layout.cardGap)
        
        local isSelected = (i == CrateOpenUI.selectedIndex)
        
        -- 绘制箱子卡片
        CrateOpenUI.RenderCrateCard(nvg, x, y, layout.cardW, layout.cardH, crate, i, isSelected, layout, player)
    end
end

-- 绘制单个箱子卡片（与补给站风格一致）
function CrateOpenUI.RenderCrateCard(nvg, x, y, w, h, crate, index, isSelected, layout, player)
    local fonts = layout.fonts
    local baseUnit = layout.baseUnit
    
    -- 获取品质颜色
    local tierColor = TierColors[crate.tier] or TierColors[1]
    
    -- 选中时外发光
    if isSelected then
        local glowAlpha = 0.3 + 0.15 * math.sin(CrateOpenUI.animTime * 3)
        for i = 3, 1, -1 do
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, x - i * 2, y - i * 2, w + i * 4, h + i * 4, baseUnit * 0.3 + i)
            nvgFillColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, glowAlpha * 255 / i))
            nvgFill(nvg)
        end
    end
    
    -- 卡片背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.3)
    nvgFillColor(nvg, nvgRGBA(18, 25, 40, isSelected and 255 or 220))
    nvgFill(nvg)
    
    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.3)
    nvgStrokeColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, isSelected and 255 or 80))
    nvgStrokeWidth(nvg, isSelected and 2 or 1)
    nvgStroke(nvg)
    
    local py = y + h * 0.03
    local centerX = x + w / 2
    local leftX = x + w * 0.06
    local rightX = x + w * 0.94
    
    -- 图标区域
    local iconSize = baseUnit * 4.0
    local iconX = centerX - iconSize / 2
    local iconY = py
    local hasIcon = false
    
    -- 尝试加载模块图片
    local moduleId = crate.moduleId
    if moduleId then
        local iconPath = "images/modules/" .. moduleId .. ".jpg"
        
        local img = ImageLoader.GetImage(nvg, iconPath, CrateOpenUI.moduleImages, moduleId)
        if img and img > 0 then
            hasIcon = true
            -- 图片背景
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.25)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 80))
            nvgFill(nvg)
            
            -- 图片
            local imgPaint = nvgImagePattern(nvg, iconX, iconY, iconSize, iconSize, 0, img, 1.0)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.25)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)
            
            -- 品质边框
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.25)
            nvgStrokeColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 220))
            nvgStrokeWidth(nvg, 2.5)
            nvgStroke(nvg)
        end
    end
    
    -- 没有图片时显示骨架屏占位
    if not hasIcon then
        ImageLoader.RenderPlaceholder(nvg, iconX, iconY, iconSize, iconSize, CrateOpenUI.animTime, baseUnit * 0.25)
    end
    py = py + iconSize + h * 0.02
    
    -- 模块名称
    nvgFontSize(nvg, fonts.cardTitle)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, isSelected and 255 or 200))
    nvgText(nvg, centerX, py, crate.moduleName or "未知模块")
    py = py + fonts.cardTitle * 0.85
    
    -- 品质标签
    local tierName = tierColor.name or "普通"
    nvgFontSize(nvg, fonts.cardSubtitle)
    nvgFillColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 200))
    nvgText(nvg, centerX, py, tierName)
    py = py + fonts.cardSubtitle * 0.85
    
    -- 分隔线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, leftX, py)
    nvgLineTo(nvg, rightX, py)
    nvgStrokeColor(nvg, nvgRGBA(50, 60, 80, 100))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    py = py + h * 0.015
    
    -- 详细属性/效果
    local statSize = fonts.statValue * 0.80
    nvgFontSize(nvg, statSize)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local statLineHeight = statSize * 1.3
    local contentWidth = rightX - leftX
    
    -- 计算底部固定区域：按钮 + 回收价值
    local btnH = baseUnit * 1.8
    local btnY = y + h - btnH - baseUnit * 0.4
    local recycleY = btnY - statLineHeight - baseUnit * 0.3
    local maxContentY = recycleY - baseUnit * 0.2
    
    -- 模块描述（解析效果）
    local desc = crate.description or ""
    local normalizedDesc = desc:gsub("，", ","):gsub("、", ",")
    local effects = {}
    for effect in string.gmatch(normalizedDesc, "[^,]+") do
        local trimmed = effect:match("^%s*(.-)%s*$")
        if trimmed and #trimmed > 0 then
            table.insert(effects, trimmed)
        end
    end
    
    -- 显示效果列表（自动截断超长文字）
    for _, effect in ipairs(effects) do
        if py + statLineHeight > maxContentY then break end
        
        -- 确定颜色
        local color = {150, 160, 180, 200}
        if effect:find("%+") then
            color = {100, 220, 150, 255}  -- 正面效果绿色
        elseif effect:find("%-") then
            color = {255, 150, 100, 255}  -- 负面效果橙色
        end
        nvgFillColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4]))
        
        -- 截断超长文字（UTF-8 感知）
        local displayText = effect
        local xmin, _, xmax, _ = nvgTextBounds(nvg, leftX, py, effect)
        local textWidth = (xmax or 0) - (xmin or 0)
        
        if textWidth > contentWidth then
            -- 将字符串按 UTF-8 字符拆分
            local chars = {}
            for char in effect:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                table.insert(chars, char)
            end
            
            -- 二分查找合适的截断长度（基于字符数）
            local ellipsis = "..."
            local maxLen = #chars
            local minLen = 1
            while minLen < maxLen do
                local midLen = math.floor((minLen + maxLen + 1) / 2)
                local testText = table.concat(chars, "", 1, midLen) .. ellipsis
                local txmin, _, txmax, _ = nvgTextBounds(nvg, leftX, py, testText)
                local testWidth = (txmax or 0) - (txmin or 0)
                if testWidth <= contentWidth then
                    minLen = midLen
                else
                    maxLen = midLen - 1
                end
            end
            displayText = table.concat(chars, "", 1, minLen) .. ellipsis
        end
        
        nvgText(nvg, leftX, py, displayText)
        py = py + statLineHeight
    end
    
    -- 回收价值（固定位置，在按钮上方）
    local recycleRate = 0.25 + ((player and player.recycleEfficiency) or 0)
    local recycleValue = math.floor((crate.price or 15) * recycleRate)
    nvgFontSize(nvg, statSize)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 200, 100, 200))
    nvgText(nvg, leftX, recycleY, string.format("回收: %d 💎", recycleValue))
    
    -- 按钮区域
    local btnW = (w - baseUnit * 1.5) / 2
    
    -- "获取" 按钮
    local getBtnX = x + baseUnit * 0.5
    local getBtnPressed = (CrateOpenUI.pressedBtn == "get_" .. index)
    UIStyle.DrawSciFiButton(nvg, getBtnX, btnY, btnW, btnH, "获取", {
        baseUnit = baseUnit,
        variant = "primary",
        animTime = CrateOpenUI.animTime,
        pressed = getBtnPressed,
    })
    
    -- 保存按钮区域
    CrateOpenUI._crateButtons[index] = {
        getBtn = {x = getBtnX, y = btnY, w = btnW, h = btnH},
    }
    
    -- "回收" 按钮
    local recycleBtnX = x + w - baseUnit * 0.5 - btnW
    local recycleBtnPressed = (CrateOpenUI.pressedBtn == "recycle_" .. index)
    UIStyle.DrawSciFiButton(nvg, recycleBtnX, btnY, btnW, btnH, "回收", {
        baseUnit = baseUnit,
        variant = "secondary",
        animTime = CrateOpenUI.animTime,
        pressed = recycleBtnPressed,
    })
    CrateOpenUI._crateButtons[index].recycleBtn = {x = recycleBtnX, y = btnY, w = btnW, h = btnH}
end

-- ============================================================================
-- 底部按钮
-- ============================================================================

function CrateOpenUI.RenderBottomButtons(nvg, layout)
    -- 只有一个或零个补给箱时不显示批量按钮
    if #CrateOpenUI.crates <= 1 then
        CrateOpenUI._bottomButtons = {}
        return
    end
    
    local baseUnit = layout.baseUnit
    local sw = layout.sw
    
    local btnY = layout.bottomY
    local btnW = layout.btnW
    local btnH = layout.btnH
    local gap = baseUnit * 2
    
    -- 全部获取
    local getAllX = sw / 2 - btnW - gap / 2
    local getAllPressed = (CrateOpenUI.pressedBtn == "get_all")
    UIStyle.DrawSciFiButton(nvg, getAllX, btnY, btnW, btnH, "全部获取", {
        baseUnit = baseUnit,
        variant = "primary",
        animTime = CrateOpenUI.animTime,
        pressed = getAllPressed,
    })
    
    -- 全部回收
    local recycleAllX = sw / 2 + gap / 2
    local recycleAllPressed = (CrateOpenUI.pressedBtn == "recycle_all")
    UIStyle.DrawSciFiButton(nvg, recycleAllX, btnY, btnW, btnH, "全部回收", {
        baseUnit = baseUnit,
        variant = "secondary",
        animTime = CrateOpenUI.animTime,
        pressed = recycleAllPressed,
    })
    
    -- 保存按钮区域
    CrateOpenUI._bottomButtons = {
        getAll = {x = getAllX, y = btnY, w = btnW, h = btnH},
        recycleAll = {x = recycleAllX, y = btnY, w = btnW, h = btnH},
    }
end

-- ============================================================================
-- 输入处理
-- ============================================================================

function CrateOpenUI.HandleMouseDown(mx, my)
    local layout = CrateOpenUI._layout
    if not layout then return false end
    
    -- 检查箱子按钮
    for i, btns in pairs(CrateOpenUI._crateButtons or {}) do
        if btns.getBtn then
            local btn = btns.getBtn
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                CrateOpenUI.pressedBtn = "get_" .. i
                return true
            end
        end
        if btns.recycleBtn then
            local btn = btns.recycleBtn
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                CrateOpenUI.pressedBtn = "recycle_" .. i
                return true
            end
        end
    end
    
    -- 检查底部按钮
    local bottomBtns = CrateOpenUI._bottomButtons
    if bottomBtns then
        if bottomBtns.getAll then
            local btn = bottomBtns.getAll
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                CrateOpenUI.pressedBtn = "get_all"
                return true
            end
        end
        if bottomBtns.recycleAll then
            local btn = bottomBtns.recycleAll
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                CrateOpenUI.pressedBtn = "recycle_all"
                return true
            end
        end
    end
    
    return false
end

function CrateOpenUI.HandleMouseUp(mx, my)
    local pressedBtn = CrateOpenUI.pressedBtn
    CrateOpenUI.pressedBtn = nil
    
    if not pressedBtn then return false end
    
    -- 处理单个箱子按钮
    if string.match(pressedBtn, "^get_(%d+)$") then
        local index = tonumber(string.match(pressedBtn, "^get_(%d+)$"))
        if index and CrateOpenUI.crates[index] then
            CrateOpenUI.GetCrate(index)
            return true
        end
    elseif string.match(pressedBtn, "^recycle_(%d+)$") then
        local index = tonumber(string.match(pressedBtn, "^recycle_(%d+)$"))
        if index and CrateOpenUI.crates[index] then
            CrateOpenUI.RecycleCrate(index)
            return true
        end
    elseif pressedBtn == "get_all" then
        CrateOpenUI.GetAllCrates()
        return true
    elseif pressedBtn == "recycle_all" then
        CrateOpenUI.RecycleAllCrates()
        return true
    end
    
    return false
end

-- 状态追踪
CrateOpenUI._wasMouseDown = false

-- 统一触摸/鼠标输入处理（由 main.lua 调用）
function CrateOpenUI.HandleTouch(sw, sh)
    local isMouseDown = input:GetMouseButtonDown(MOUSEB_LEFT)
    
    -- 获取安全区信息并转换坐标
    local safe = CrateOpenUI.safeArea
    if not safe then
        CrateOpenUI._wasMouseDown = isMouseDown
        return
    end
    
    -- 屏幕坐标转换为安全区本地坐标
    local screenX = TouchInput.x
    local screenY = TouchInput.y
    local mx = screenX - safe.x
    local my = screenY - safe.y
    
    -- 鼠标按下
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        CrateOpenUI.HandleMouseDown(mx, my)
    end
    
    -- 鼠标释放（从按下变为未按下）
    if CrateOpenUI._wasMouseDown and not isMouseDown then
        CrateOpenUI.HandleMouseUp(mx, my)
    end
    
    CrateOpenUI._wasMouseDown = isMouseDown
end

-- ============================================================================
-- 箱子操作
-- ============================================================================

-- 获取单个箱子
function CrateOpenUI.GetCrate(index)
    local crate = CrateOpenUI.crates[index]
    if not crate then return end
    
    if CrateOpenUI.onGetItem then
        CrateOpenUI.onGetItem(crate)
    end
    
    table.remove(CrateOpenUI.crates, index)
    CrateOpenUI.CheckComplete()
end

-- 回收单个箱子（补给箱只含模块，都可回收）
function CrateOpenUI.RecycleCrate(index)
    local crate = CrateOpenUI.crates[index]
    if not crate then return end
    
    if CrateOpenUI.onRecycleItem then
        CrateOpenUI.onRecycleItem(crate)
    end
    
    table.remove(CrateOpenUI.crates, index)
    CrateOpenUI.CheckComplete()
end

-- 全部获取
function CrateOpenUI.GetAllCrates()
    while #CrateOpenUI.crates > 0 do
        local crate = CrateOpenUI.crates[1]
        if CrateOpenUI.onGetItem then
            CrateOpenUI.onGetItem(crate)
        end
        table.remove(CrateOpenUI.crates, 1)
    end
    CrateOpenUI.CheckComplete()
end

-- 全部回收（补给箱只含模块，都可回收）
function CrateOpenUI.RecycleAllCrates()
    while #CrateOpenUI.crates > 0 do
        local crate = CrateOpenUI.crates[1]
        if CrateOpenUI.onRecycleItem then
            CrateOpenUI.onRecycleItem(crate)
        end
        table.remove(CrateOpenUI.crates, 1)
    end
    CrateOpenUI.CheckComplete()
end

-- 检查是否全部处理完成
function CrateOpenUI.CheckComplete()
    if #CrateOpenUI.crates == 0 then
        if CrateOpenUI.onComplete then
            CrateOpenUI.onComplete()
        end
    end
end

-- ============================================================================
-- 状态查询
-- ============================================================================

function CrateOpenUI.HasCrates()
    return #CrateOpenUI.crates > 0
end

function CrateOpenUI.GetCrateCount()
    return #CrateOpenUI.crates
end

return CrateOpenUI
