-- ============================================================================
-- 星河战姬 Starkyries - 覆盖层UI
-- 舰桥升级、游戏结束、胜利、波次公告
-- 科技风格统一设计
-- 响应式布局：横竖屏自适应
-- ============================================================================
-- 
-- UI 尺寸标准: baseUnit = math.min(sw, sh) / 40
-- 详见: game-doc/docs/6-技术文档/UI_GUIDELINES.md
--
-- 重要: 触摸处理函数中的布局必须与渲染函数保持一致!
-- 
-- ============================================================================

local Waves = require("config.waves")
local ImageLoader = require("utils.ImageLoader")
local UIStyle = require("ui.UIStyle")
local UISafeArea = require("ui.UISafeArea")
local FrameCache = require("utils.FrameCache")
local TouchInput = require("utils.TouchInput")

local Overlays = {}

Overlays.animTime = 0
Overlays.showKeyboardFocus = false  -- 键盘导航模式（预留，当前UI无键盘导航，所有选中为功能性高亮）

-- 属性面板滚动状态
local statsScrollState = {
    offset = 0,        -- 当前滚动偏移（行数）
    maxOffset = 0,     -- 最大滚动偏移
    touchStartY = nil, -- 触摸开始Y坐标
    scrollStartOffset = 0, -- 触摸开始时的偏移
    currentTab = 1,    -- 当前标签页（1=主要，2=次要）
}

-- 升级选项按下状态
Overlays.pressedOptionIndex = nil    -- 当前按下的升级选项索引
Overlays.pressedRefreshBtn = false   -- 刷新按钮是否按下

-- GameOver/Victory 按钮按下状态
Overlays.pressedGameOverBtn = false  -- GameOver 重新开始按钮
Overlays.pressedVictoryBtn = false   -- Victory 返回按钮

-- ============================================================================
-- 响应式布局辅助函数
-- ============================================================================

local function IsPortrait(sw, sh)
    return sh >= sw
end

local function GetPanelLayout(sw, sh, baseUnit, panelType, optionCount)
    local isPortrait = IsPortrait(sw, sh)
    optionCount = optionCount or 4  -- 默认4个选项
    
    -- 获取统一字体规范
    local fonts = UIStyle.GetTypography(sw, sh)
    
    if panelType == "gameOver" or panelType == "victory" then
        if isPortrait then
            -- 竖屏：更宽的面板，更大的字体
            local panelW = sw * 0.9
            local panelH = baseUnit * 18  -- 使用固定baseUnit计算高度
            return {
                isPortrait = true,
                panelW = panelW,
                panelH = panelH,
                panelX = (sw - panelW) / 2,
                panelY = (sh - panelH) / 2,
                fonts = fonts,
            }
        else
            -- 横屏：原布局
            local panelW = (panelType == "victory") and sw * 0.55 or sw * 0.5
            local panelH = sh * 0.55
            return {
                isPortrait = false,
                panelW = panelW,
                panelH = panelH,
                panelX = (sw - panelW) / 2,
                panelY = (sh - panelH) / 2,
                fonts = fonts,
            }
        end
    elseif panelType == "bridgeUpgrade" then
        if isPortrait then
            -- 竖屏：更宽的弹窗，高度根据选项数量动态计算，更大字体
            local popupW = sw * 0.92
            -- 标题 + 等级变化 + 选项 + 提示（放大后需要更多空间）
            local popupH = baseUnit * (7.0 + optionCount * 4.5 + 2.0)
            return {
                isPortrait = true,
                popupW = popupW,
                popupH = popupH,
                popupX = (sw - popupW) / 2,
                popupY = (sh - popupH) / 2,
                fonts = fonts,
            }
        else
            -- 横屏：原布局
            local popupW = sw * 0.5
            local popupH = sh * 0.7
            return {
                isPortrait = false,
                popupW = popupW,
                popupH = popupH,
                popupX = (sw - popupW) / 2,
                popupY = (sh - popupH) / 2,
                fonts = fonts,
            }
        end
    end
end

-- ============================================================================
-- 舰桥升级UI
-- ============================================================================

-- 属性显示配置（参考 Brotato 界面设计）
-- 分为"主要"和"次要"两个标签页
-- valueType: "base" = 基础值（直接显示数值）, "percent" = 加成值（显示 %名称: 数值）

-- 主要属性（核心战斗/生存属性）
-- 主要属性（可通过舰桥升级直接提升的属性）
-- 导出供 PauseUI 等模块共用
Overlays.STATS_PRIMARY = {
    -- ========== 状态 ==========
    {icon = "🎖", name = "舰桥等级", getValue = function(p) return p.bridgeLevel or 0 end, valueType = "base", noColor = true},
    {icon = "💎", name = "晶体", getValue = function(p) return p.crystals or 0 end, valueType = "base", noColor = true},
    {icon = "⭐", name = "经验值", getValue = function(p) return string.format("%d/%d", p.totalXp or 0, p.nextUpgradeXp or 10) end, valueType = "string", noColor = true},
    
    -- ========== 生存类（可升级）==========
    {icon = "🛡", name = "最大护盾", getValue = function(p) return p.maxShield or 0 end, valueType = "base"},
    {icon = "💚", name = "护盾再生", getValue = function(p) 
        local regen = p.shieldRegen or 0
        if regen <= 0 then return "0" end
        -- 公式: HP/s = 0.20 + (shieldRegen - 1) × 0.089
        local hpPerSec = 0.20 + (regen - 1) * 0.089
        return string.format("%.2f", hpPerSec)
    end, valueType = "string", suffix = "/秒"},
    {icon = "🔰", name = "装甲值", getValue = function(p) return p.armor or 0 end, valueType = "base"},
    {icon = "💨", name = "规避率", getValue = function(p) return math.floor((p.dodgeChance or 0) * 100) end, valueType = "percent"},
    {icon = "🔋", name = "能量吸收", getValue = function(p) return math.floor((p.energyAbsorb or 0) * 100) end, valueType = "percent"},
    
    -- ========== 攻击类（可升级）==========
    {icon = "⚔", name = "火力输出", getValue = function(p) return math.floor(((p.damageMultiplier or 1) - 1) * 100) end, valueType = "percent"},
    {icon = "⚡", name = "射击频率", getValue = function(p) return math.floor(((p.fireRateMultiplier or 1) - 1) * 100) end, valueType = "percent"},
    {icon = "🎯", name = "精确打击", getValue = function(p) return math.floor((p.critChance or 0) * 100) end, valueType = "percent"},
    {icon = "📏", name = "射程加成", getValue = function(p) return p.rangeBonus or 0 end, valueType = "base"},
    
    -- ========== 专精类（可升级，固定值加成）==========
    {icon = "🔫", name = "近程伤害", getValue = function(p) return p.meleeDamageBonus or 0 end, valueType = "base"},
    {icon = "🚀", name = "弹道伤害", getValue = function(p) return p.ballisticDamageBonus or 0 end, valueType = "base"},
    {icon = "⚡", name = "能量伤害", getValue = function(p) return p.energyDamageBonus or 0 end, valueType = "base"},
    
    -- ========== 机动与经济（可升级）==========
    {icon = "🏃", name = "引擎推力", getValue = function(p) return math.floor(((p.moveSpeed or 10) / 10 - 1) * 100) end, valueType = "percent"},
    {icon = "🍀", name = "运势", getValue = function(p) return p.luck or 0 end, valueType = "base"},
    {icon = "💎", name = "晶体加成", getValue = function(p) return math.floor(((p.crystalMultiplier or 1) - 1) * 100) end, valueType = "percent"},
}

-- 次要属性（装备/模块提供的特殊效果，不可通过升级直接获得）
Overlays.STATS_SECONDARY = {
    -- ========== 派生战斗属性 ==========
    {icon = "📉", name = "受伤减免", getValue = function(p) return math.floor((1 - (p.damageTakenMultiplier or 1)) * 100) end, valueType = "percent"},
    {icon = "💥", name = "致命伤害", getValue = function(p) return math.floor((p.critDamage or 1.5) * 100) end, valueType = "percent", baseValue = 150},
    {icon = "🤖", name = "召唤伤害", getValue = function(p) return math.floor((p.summonDamage or 0) * 100) end, valueType = "percent"},
    {icon = "👹", name = "Boss伤害", getValue = function(p) return math.floor((p.bossDamage or 0) * 100) end, valueType = "percent"},
    {icon = "🔱", name = "穿透力", getValue = function(p) return p.piercing or 0 end, valueType = "base"},
    {icon = "📊", name = "穿透伤害", getValue = function(p) return math.floor((p.piercingDamage or 1) * 100) end, valueType = "percent", baseValue = 100},
    
    -- ========== 条件触发 ==========
    {icon = "💪", name = "满盾加伤", getValue = function(p) return math.floor((p.fullShieldDamageBonus or 0) * 100) end, valueType = "percent"},
    {icon = "🔻", name = "低血加伤", getValue = function(p) return math.floor((p.lowShieldDamageBonus or 0) * 100) end, valueType = "percent"},
    {icon = "🔥", name = "燃烧几率", getValue = function(p) return math.floor((p.burnChance or 0) * 100) end, valueType = "percent"},
    {icon = "⛓", name = "连锁几率", getValue = function(p) return math.floor((p.deathChainChance or 0) * 100) end, valueType = "percent"},
    
    -- ========== 经济与收益 ==========
    {icon = "🧲", name = "拾取范围", getValue = function(p) return math.floor(((p.pickupRangeMultiplier or 1) - 1) * 100) end, valueType = "percent"},
    {icon = "💰", name = "击杀晶体", getValue = function(p) return p.killCrystalBonus or 0 end, valueType = "base"},
    {icon = "❤️", name = "击杀回复", getValue = function(p) return p.killHeal or 0 end, valueType = "base"},
    {icon = "⭐", name = "经验加成", getValue = function(p) return math.floor(((p.xpMultiplier or 1) - 1) * 100) end, valueType = "percent"},
    {icon = "🏷", name = "商店折扣", getValue = function(p) return math.floor((p.shopDiscount or 0) * 100) end, valueType = "percent"},
    {icon = "🔄", name = "免费刷新", getValue = function(p) return (p.freeRefreshesRemaining or 0) .. "/" .. (p.freeRefreshes or 0) end, valueType = "string"},
    
    -- ========== 装备槽位 ==========
    {icon = "🗡", name = "武器槽位", getValue = function(p) return p.maxWeaponSlots or 6 end, valueType = "base"},
}

function Overlays.RenderBridgeUpgrade(nvg, sw, sh, baseUnit, fontSize, bridgeUpgrade, player, refreshCost)
    Overlays.animTime = Overlays.animTime + 0.016
    
    -- 🔧 防御性检查：确保 player 不为 nil
    if not player then
        player = {}  -- 使用空表作为安全默认值，getValue 函数中的 or 会处理缺失属性
    end
    
    -- 遮罩（全屏绘制）
    UIStyle.DrawOverlay(nvg, sw, sh, {alpha = 200})
    
    -- ========================================================================
    -- 🔴 使用安全区系统（与 GetUpgradeLayout 保持一致）
    -- ========================================================================
    local safe = UISafeArea.Calculate(sw, sh)
    local safeX, safeY, safeW, safeH = safe.x, safe.y, safe.w, safe.h
    baseUnit = safe.baseUnit  -- 使用安全区的 baseUnit
    
    local isPortrait = safe.isPortrait or (sh > sw)
    local isMobile = math.min(safeW, safeH) < 600  -- 小屏幕设备
    local fonts = UIStyle.GetTypography(safeW, safeH)
    
    -- ========================================================================
    -- 响应式布局计算（基于安全区）
    -- ========================================================================
    local totalW, totalH, startX, startY
    local leftPanelW, rightPanelW, panelH, gap
    
    if isPortrait then
        -- 竖屏：上下布局（升级在上，属性在下）
        totalW = safeW * 0.95
        totalH = safeH * 0.90
        startX = safeX + (safeW - totalW) / 2
        startY = safeY + (safeH - totalH) / 2
        leftPanelW = totalW
        rightPanelW = totalW
        panelH = totalH * 0.52  -- 升级面板占更多空间
        gap = baseUnit * 0.5
    else
        -- 横屏：左右布局
        totalW = math.min(safeW * 0.95, baseUnit * 55)  -- 增加总宽度
        totalH = safeH * 0.88
        startX = safeX + (safeW - totalW) / 2
        startY = safeY + (safeH - totalH) / 2
        gap = baseUnit * 0.8
        leftPanelW = totalW * 0.40  -- 属性面板更宽
        rightPanelW = totalW - leftPanelW - gap
        panelH = totalH
    end
    
    -- ========================================================================
    -- 左侧/下方面板：属性列表（带标签页切换）
    -- ========================================================================
    local leftX = startX
    local leftY = isPortrait and (startY + panelH + gap) or startY
    local leftH = isPortrait and (totalH - panelH - gap) or panelH
    
    -- 面板背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, leftX, leftY, leftPanelW, leftH, baseUnit * 0.4)
    nvgFillColor(nvg, nvgRGBA(20, 25, 35, 245))
    nvgFill(nvg)
    
    -- 面板边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, leftX, leftY, leftPanelW, leftH, baseUnit * 0.4)
    nvgStrokeWidth(nvg, 2)
    nvgStrokeColor(nvg, nvgRGBA(60, 70, 90, 200))
    nvgStroke(nvg)
    
    -- 🔴 标题栏布局必须基于字体大小
    local titleFontSize = fonts.cardTitle
    local tabFontSize = fonts.description
    local titlePadding = baseUnit * 0.25
    local tabBtnH = tabFontSize * 1.6  -- 标签按钮高度基于字体
    local titleBarH = titlePadding + titleFontSize + baseUnit * 0.2 + tabBtnH + titlePadding
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, leftX, leftY, leftPanelW, titleBarH, baseUnit * 0.4)
    nvgFillColor(nvg, nvgRGBA(40, 50, 70, 220))
    nvgFill(nvg)
    
    -- 标题（位置基于字体大小）
    nvgFontSize(nvg, titleFontSize)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(200, 210, 220, 255))
    nvgText(nvg, leftX + leftPanelW / 2, leftY + titlePadding, "属性")
    
    -- 标签页按钮（位置基于标题字体大小）
    local tabBtnW = leftPanelW * 0.35
    local tabBtnY = leftY + titlePadding + titleFontSize + baseUnit * 0.15
    local tabGap = baseUnit * 0.5
    local tabStartX = leftX + (leftPanelW - tabBtnW * 2 - tabGap) / 2
    
    local tabs = {"主要", "次要"}
    for i, tabName in ipairs(tabs) do
        local tabX = tabStartX + (i - 1) * (tabBtnW + tabGap)
        local isActive = (statsScrollState.currentTab == i)
        
        -- 标签背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tabX, tabBtnY, tabBtnW, tabBtnH, baseUnit * 0.2)
        if isActive then
            nvgFillColor(nvg, nvgRGBA(80, 100, 140, 255))
        else
            nvgFillColor(nvg, nvgRGBA(50, 60, 80, 200))
        end
        nvgFill(nvg)
        
        -- 标签文字
        nvgFontSize(nvg, fonts.description)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isActive then
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        else
            nvgFillColor(nvg, nvgRGBA(150, 160, 180, 200))
        end
        nvgText(nvg, tabX + tabBtnW / 2, tabBtnY + tabBtnH / 2, tabName)
    end
    
    -- 获取当前标签页的属性列表
    local currentStats = (statsScrollState.currentTab == 1) and Overlays.STATS_PRIMARY or Overlays.STATS_SECONDARY
    
    -- 属性列表（单列布局，固定最小行高 + 滚动支持）
    local statsStartY = leftY + titleBarH + baseUnit * 0.3
    local statsAreaH = leftH - titleBarH - baseUnit * 0.6
    local statCount = #currentStats
    
    -- 使用 Typography 系统的 statLabel 字体大小
    local statFontSize = fonts.statLabel
    
    -- 🔴 关键修复：行高必须基于字体大小，而不是固定 baseUnit 倍数
    -- 属性列表使用紧凑行距（1.25），信息密度优先
    local statRowH = statFontSize * 1.25
    
    -- 计算可见行数和滚动范围
    local visibleRows = math.floor(statsAreaH / statRowH)
    local totalRows = statCount
    statsScrollState.maxOffset = math.max(0, totalRows - visibleRows)
    statsScrollState.offset = math.max(0, math.min(statsScrollState.offset, statsScrollState.maxOffset))
    
    -- 绘制可见的属性行
    local startIdx = math.floor(statsScrollState.offset) + 1
    local endIdx = math.min(startIdx + visibleRows, statCount)
    
    for i = startIdx, endIdx do
        local stat = currentStats[i]
        if not stat then break end
        
        local rowIndex = i - startIdx
        local statX = leftX + baseUnit * 0.4
        local statY = statsStartY + rowIndex * statRowH
        
        -- 超出面板则不绘制
        if statY + statRowH > leftY + leftH - baseUnit * 0.3 then break end
        
        local rawValue = stat.getValue(player)
        local isStringValue = (stat.valueType == "string") or (type(rawValue) == "string")
        local numValue = isStringValue and 0 or (rawValue or 0)
        
        -- 根据 valueType 格式化显示
        local displayName = stat.name
        local displayValue = ""
        
        if stat.valueType == "percent" then
            -- 加成属性：名称前加 %，值显示数字
            displayName = "%" .. stat.name
            -- 处理有基础值的情况（如暴击伤害基础150%）
            if stat.baseValue then
                displayValue = tostring(rawValue)
            else
                displayValue = tostring(numValue)
            end
        elseif stat.valueType == "base" then
            -- 基础属性：直接显示数值
            displayValue = tostring(rawValue) .. (stat.suffix or "")
        else
            -- 字符串类型
            displayValue = tostring(rawValue)
        end
        
        -- 图标（使用较小字体避免挤压）
        local iconFontSize = statFontSize * 0.9
        nvgFontSize(nvg, iconFontSize)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(150, 160, 180, 200))
        nvgText(nvg, statX, statY + statRowH / 2, stat.icon)
        
        -- 属性名（间距基于字体大小，而非固定 baseUnit）
        nvgFontSize(nvg, statFontSize)
        nvgFillColor(nvg, nvgRGBA(180, 185, 195, 220))
        nvgText(nvg, statX + statFontSize * 1.3, statY + statRowH / 2, displayName)
        
        -- 属性值（颜色编码：正值绿色，负值红色，零值白色）
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        if stat.noColor or isStringValue then
            nvgFillColor(nvg, nvgRGBA(220, 225, 235, 255))  -- 白色（无颜色编码）
        elseif numValue > 0 then
            nvgFillColor(nvg, nvgRGBA(100, 220, 100, 255))  -- 绿色
        elseif numValue < 0 then
            nvgFillColor(nvg, nvgRGBA(255, 100, 100, 255))  -- 红色
        else
            nvgFillColor(nvg, nvgRGBA(180, 185, 195, 220))  -- 白色（零值）
        end
        nvgText(nvg, leftX + leftPanelW - baseUnit * 0.5, statY + statRowH / 2, displayValue)
    end
    
    -- 绘制滚动指示器（如果需要滚动）
    if statsScrollState.maxOffset > 0 then
        local scrollBarW = baseUnit * 0.15
        local scrollBarX = leftX + leftPanelW - scrollBarW - baseUnit * 0.15
        local scrollBarY = statsStartY
        local scrollBarH = statsAreaH - baseUnit * 0.3
        
        -- 滚动条背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, scrollBarX, scrollBarY, scrollBarW, scrollBarH, scrollBarW / 2)
        nvgFillColor(nvg, nvgRGBA(40, 50, 60, 100))
        nvgFill(nvg)
        
        -- 滚动条滑块
        local thumbRatio = visibleRows / totalRows
        local thumbH = math.max(baseUnit * 1.0, scrollBarH * thumbRatio)
        local thumbY = scrollBarY + (scrollBarH - thumbH) * (statsScrollState.offset / statsScrollState.maxOffset)
        
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, scrollBarX, thumbY, scrollBarW, thumbH, scrollBarW / 2)
        nvgFillColor(nvg, nvgRGBA(100, 120, 150, 180))
        nvgFill(nvg)
        
        -- 上/下箭头提示
        if statsScrollState.offset > 0 then
            nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.6))
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(150, 160, 180, 200))
            nvgText(nvg, leftX + leftPanelW / 2, statsStartY - baseUnit * 0.2, "▲")
        end
        if statsScrollState.offset < statsScrollState.maxOffset then
            nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.6))
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(150, 160, 180, 200))
            nvgText(nvg, leftX + leftPanelW / 2, leftY + leftH - baseUnit * 0.4, "▼")
        end
    end
    
    -- ========================================================================
    -- 右侧面板：升级选项
    -- ========================================================================
    local rightX = isPortrait and startX or (leftX + leftPanelW + gap)
    local rightY = startY
    local rightH = panelH
    
    -- 面板背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, rightX, rightY, rightPanelW, rightH, baseUnit * 0.4)
    nvgFillColor(nvg, nvgRGBA(20, 25, 35, 240))
    nvgFill(nvg)
    
    -- 面板边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, rightX, rightY, rightPanelW, rightH, baseUnit * 0.4)
    nvgStrokeWidth(nvg, 2)
    nvgStrokeColor(nvg, nvgRGBA(100, 80, 180, 200))
    nvgStroke(nvg)
    
    -- 🔴 标题区域布局基于字体大小
    local upgradeTitleFontSize = fonts.pageTitle
    local upgradeLevelFontSize = fonts.description
    local upgradeTitlePadding = baseUnit * 0.5
    
    -- 标题
    nvgFontSize(nvg, upgradeTitleFontSize)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 220, 100, 255))
    nvgText(nvg, rightX + rightPanelW / 2, rightY + upgradeTitlePadding, "升级!")
    
    -- 等级变化（位置基于标题字体大小）
    nvgFontSize(nvg, upgradeLevelFontSize)
    nvgFillColor(nvg, nvgRGBA(255, 100, 100, 255))
    local levelY = rightY + upgradeTitlePadding + upgradeTitleFontSize + baseUnit * 0.2
    nvgText(nvg, rightX + rightPanelW / 2, levelY, 
        string.format("Lv.%d → Lv.%d", player.bridgeLevel, player.bridgeLevel + 1))
    
    -- 升级选项起始位置（基于标题区域高度）
    local optionAreaStartY = levelY + upgradeLevelFontSize + baseUnit * 0.4
    
    -- 升级选项（点击整个卡片即可选择，无需单独按钮）
    local options = bridgeUpgrade.options or {}
    local selectedIndex = bridgeUpgrade.selectedIndex or 1
    local optionCount = #options
    
    -- 🔴 卡片布局基于字体大小，避免文字重叠
    local optionNameFontSize = fonts.cardTitle * 1.1
    local optionDescFontSize = fonts.cardTitle * 1.0
    local optionPadding = baseUnit * 0.4
    -- 卡片高度 = 上边距 + 名称字体 + 间距 + 描述字体 + 下边距
    local optionH = optionPadding + optionNameFontSize + baseUnit * 0.2 + optionDescFontSize + optionPadding
    local optionGap = baseUnit * 0.4
    local optionW = rightPanelW - baseUnit * 1.6
    local optionStartY = optionAreaStartY  -- 使用基于字体计算的起始位置
    
    for i, option in ipairs(options) do
        local optX = rightX + baseUnit * 0.8
        local optY = optionStartY + (i - 1) * (optionH + optionGap)
        local isSelected = (i == selectedIndex)
        local isPressed = (Overlays.pressedOptionIndex == i)
        
        local tierColor = option.tierColor or {r = 180, g = 180, b = 180}
        local tier = option.tier or 1
        
        -- 按下时的偏移
        local pressOffset = isPressed and 2 or 0
        
        -- 选项卡片背景（悬停/按下效果）
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, optX, optY + pressOffset, optionW, optionH, baseUnit * 0.3)
        if isPressed then
            nvgFillColor(nvg, nvgRGBA(25, 30, 40, 255))  -- 按下时更暗
        elseif isSelected then
            nvgFillColor(nvg, nvgRGBA(55, 60, 80, 255))
        else
            nvgFillColor(nvg, nvgRGBA(35, 40, 55, 255))
        end
        nvgFill(nvg)
        
        -- 卡片边框
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, optX, optY + pressOffset, optionW, optionH, baseUnit * 0.3)
        nvgStrokeWidth(nvg, (isSelected or isPressed) and 2 or 1)
        nvgStrokeColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, (isSelected or isPressed) and 255 or 120))
        nvgStroke(nvg)
        
        -- 左侧品质条
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, optX, optY + pressOffset, baseUnit * 0.3, optionH, baseUnit * 0.15)
        nvgFillColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, isPressed and 180 or 255))
        nvgFill(nvg)
        
        -- 属性名称（位置基于字体大小）
        nvgFontSize(nvg, optionNameFontSize)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(230, 235, 245, isPressed and 200 or 255))
        local nameY = optY + optionPadding + pressOffset
        nvgText(nvg, optX + baseUnit * 0.8, nameY, option.name or "")
        
        -- 属性效果（位置基于名称字体大小）
        nvgFontSize(nvg, optionDescFontSize)
        nvgFillColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, isPressed and 180 or 255))
        local descY = nameY + optionNameFontSize + baseUnit * 0.15
        nvgText(nvg, optX + baseUnit * 0.8, descY, option.desc or "")
        
        -- 品质标签（右上角）
        if option.tierLabel then
            nvgFontSize(nvg, fonts.hintText)
            nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
            nvgFillColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, isPressed and 150 or 200))
            nvgText(nvg, optX + optionW - baseUnit * 0.4, nameY, option.tierLabel)
        end
    end
    
    -- 🔴 刷新按钮大小基于字体
    refreshCost = refreshCost or 1
    local canRefresh = player.crystals >= refreshCost
    local isRefreshPressed = Overlays.pressedRefreshBtn and canRefresh
    
    local refreshFontSize = fonts.description
    local refreshBtnH = refreshFontSize * 1.8  -- 按钮高度基于字体
    local refreshBtnW = refreshFontSize * 6    -- 按钮宽度基于字体
    local refreshBtnX = rightX + (rightPanelW - refreshBtnW) / 2
    local refreshBtnY = rightY + rightH - refreshBtnH - baseUnit * 0.8
    
    -- 按下时的偏移
    local refreshPressOffset = isRefreshPressed and 2 or 0
    
    -- 按钮背景
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
    nvgFontSize(nvg, refreshFontSize)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if canRefresh then
        nvgFillColor(nvg, nvgRGBA(100, 200, 100, isRefreshPressed and 180 or 255))
    else
        nvgFillColor(nvg, nvgRGBA(120, 130, 140, 180))
    end
    nvgText(nvg, refreshBtnX + refreshBtnW / 2, refreshBtnY + refreshBtnH / 2 + refreshPressOffset, 
        string.format("💎 %d  刷新", refreshCost))
end

-- ============================================================================
-- 游戏结束UI
-- ============================================================================

-- GameOver 图片缓存
Overlays.gameOverImage = nil
Overlays.gameOverImageLoaded = false
Overlays.gameOverCaptain = nil  -- 记录当前加载的舰长

-- GameOver 图片加载状态
local gameOverImageCache = {}       -- ImageLoader 缓存
local gameOverPrimaryPath = nil     -- 当前舰长图片路径
local gameOverFallbackPath = nil    -- 后备图片路径
local gameOverCaptainName = nil     -- 当前舰长名称

-- 加载随机 GameOver 图片（根据当前舰长，DWP-safe，每帧调用直到加载完成）
local function LoadRandomGameOverImage(nvg)
    if Overlays.gameOverImageLoaded then return end
    
    -- 首次调用：确定路径
    if not gameOverPrimaryPath then
        local captain = "星遥"
        local Game = require("core.Game")
        if Game.player and Game.player.shipConfig and Game.player.shipConfig.captain then
            captain = Game.player.shipConfig.captain
        end
        local imageIndex = math.random(1, 5)
        gameOverCaptainName = captain
        gameOverPrimaryPath = "image/" .. captain .. "/gameover/" .. imageIndex .. ".jpg"
        gameOverFallbackPath = "image/星遥/gameover/" .. imageIndex .. ".jpg"
    end
    
    -- 尝试主路径
    local img = ImageLoader.GetImage(nvg, gameOverPrimaryPath, gameOverImageCache, "primary")
    if img and img > 0 then
        Overlays.gameOverImage = img
        Overlays.gameOverCaptain = gameOverCaptainName
        Overlays.gameOverImageLoaded = true
        return
    elseif img == -1 then
        -- 主路径失败，尝试后备路径
        local fallbackImg = ImageLoader.GetImage(nvg, gameOverFallbackPath, gameOverImageCache, "fallback")
        if fallbackImg and fallbackImg > 0 then
            Overlays.gameOverImage = fallbackImg
            Overlays.gameOverCaptain = "星遥"
            Overlays.gameOverImageLoaded = true
        elseif fallbackImg == -1 then
            -- 两个都失败了，放弃
            Overlays.gameOverImageLoaded = true
        end
        -- fallbackImg == -2 表示还在下载，下一帧继续
    end
    -- img == -2 表示还在下载，下一帧继续
end

-- 重置 GameOver 图片（在新游戏开始时调用）
function Overlays.ResetGameOverImage()
    if Overlays.gameOverImage and Overlays.gameOverImage > 0 then
        -- 注意：nvgDeleteImage 需要 nvg 上下文，这里标记为需要清理
    end
    Overlays.gameOverImage = nil
    Overlays.gameOverImageLoaded = false
    Overlays.gameOverCaptain = nil
    -- 重置 DWP 状态，确保新游戏重新随机选择图片
    gameOverImageCache = {}
    gameOverPrimaryPath = nil
    gameOverFallbackPath = nil
    gameOverCaptainName = nil
end

-- 预先确定 GameOver 图片路径（在 PreloadGate 前调用）
function Overlays.PrepareGameOverImage(player)
    Overlays.ResetGameOverImage()
    local captain = "星遥"
    if player and player.shipConfig and player.shipConfig.captain then
        captain = player.shipConfig.captain
    end
    local imageIndex = math.random(1, 5)
    gameOverCaptainName = captain
    gameOverPrimaryPath = "image/" .. captain .. "/gameover/" .. imageIndex .. ".jpg"
    gameOverFallbackPath = "image/星遥/gameover/" .. imageIndex .. ".jpg"
end

-- 收集 GameOver 图片路径（供 PreloadGate 使用）
function Overlays.CollectGameOverImagePaths()
    local paths = {}
    if gameOverPrimaryPath then
        table.insert(paths, gameOverPrimaryPath)
    end
    if gameOverFallbackPath and gameOverFallbackPath ~= gameOverPrimaryPath then
        table.insert(paths, gameOverFallbackPath)
    end
    return paths
end

-- 格式化时间（秒 -> 分:秒）
local function FormatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

function Overlays.RenderGameOver(nvg, sw, sh, baseUnit, fontSize, battle)
    Overlays.animTime = Overlays.animTime + 0.016
    
    -- 加载随机图片
    LoadRandomGameOverImage(nvg)
    
    -- 深色遮罩（全屏）
    UIStyle.DrawOverlay(nvg, sw, sh, {alpha = 230})
    
    -- ========== 计算安全区 ==========
    local safe = UISafeArea.Calculate(sw, sh)
    local safeX, safeY, safeW, safeH = safe.x, safe.y, safe.w, safe.h
    local safeBaseUnit = safe.baseUnit
    
    local fonts = UIStyle.GetTypography(safeW, safeH)
    local isPortrait = safe.isPortrait or (sh > sw)
    
    -- ========== 大面板布局（基于安全区）==========
    local panelW, panelH, panelX, panelY
    local imageW, imageH, imageX, imageY
    local statsX, statsY, statsW, statsH
    
    -- 标题区域高度（仅用于竖屏，横屏使用不同布局）
    local titleAreaH = safeBaseUnit * 4
    
    if isPortrait then
        -- 竖屏：标题 → 图片 → 统计 → 按钮（垂直布局）
        panelW = safeW * 0.92
        panelH = safeH * 0.78
        panelX = safeX + (safeW - panelW) / 2
        panelY = safeY + (safeH - panelH) / 2
        
        -- 内容区域（标题下方）
        local contentY = panelY + titleAreaH
        local contentH = panelH - titleAreaH - safeBaseUnit * 4.5  -- 减去按钮区域
        
        -- 图片在上方（保持1:1比例，限制最大尺寸）
        local maxImageSize = math.min(panelW * 0.55, contentH * 0.42)
        imageW = maxImageSize
        imageH = maxImageSize
        imageX = panelX + (panelW - imageW) / 2
        imageY = contentY
        
        -- 统计在下方
        statsX = panelX + safeBaseUnit * 1.5
        statsY = imageY + imageH + safeBaseUnit * 1.2
        statsW = panelW - safeBaseUnit * 3
        statsH = contentH - imageH - safeBaseUnit * 1.2
    else
        -- 横屏：左右布局（标题在图片上方，统计有独立区域）
        panelW = safeW * 0.82
        panelH = safeH * 0.82
        panelX = safeX + (safeW - panelW) / 2
        panelY = safeY + (safeH - panelH) / 2
        
        -- 左侧区域（标题+图片）
        local leftAreaW = (panelW - safeBaseUnit * 3) * 0.45
        local leftAreaX = panelX + safeBaseUnit * 1.5
        
        -- 右侧区域（统计）
        local rightAreaX = leftAreaX + leftAreaW + safeBaseUnit * 2
        local rightAreaW = panelW - leftAreaW - safeBaseUnit * 5.5
        
        -- 内容区域高度（减去底部按钮）
        local contentH = panelH - safeBaseUnit * 5
        
        -- 图片（在左侧区域，标题下方）
        local imgTopMargin = safeBaseUnit * 4  -- 给标题留空间
        local maxImageSize = math.min(leftAreaW, contentH - imgTopMargin)
        imageW = maxImageSize
        imageH = maxImageSize
        imageX = leftAreaX
        imageY = panelY + imgTopMargin + (contentH - imgTopMargin - imageH) / 2
        
        -- 统计（在右侧区域，标题下方）
        local statsTitleH = safeBaseUnit * 5  -- 给标题留足够空间
        statsX = rightAreaX
        statsY = panelY + statsTitleH
        statsW = rightAreaW
        statsH = contentH - statsTitleH + safeBaseUnit * 1.5
    end
    
    -- 使用安全区的 baseUnit
    baseUnit = safeBaseUnit
    
    -- ========== 面板背景 ==========
    -- 外发光
    local glowGrad = nvgBoxGradient(nvg, panelX - 10, panelY - 10, panelW + 20, panelH + 20, 
        baseUnit * 0.8, 30, nvgRGBA(180, 50, 50, 80), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, panelX - 30, panelY - 30, panelW + 60, panelH + 60)
    nvgFillPaint(nvg, glowGrad)
    nvgFill(nvg)
    
    -- 主面板背景
    local panelGrad = nvgLinearGradient(nvg, panelX, panelY, panelX, panelY + panelH,
        nvgRGBA(25, 20, 30, 250), nvgRGBA(15, 12, 20, 250))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, panelX, panelY, panelW, panelH, baseUnit * 0.5)
    nvgFillPaint(nvg, panelGrad)
    nvgFill(nvg)
    
    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, panelX, panelY, panelW, panelH, baseUnit * 0.5)
    nvgStrokeWidth(nvg, 2)
    nvgStrokeColor(nvg, nvgRGBA(180, 60, 60, 200))
    nvgStroke(nvg)
    
    -- ========== 标题（放在统计区域上方）==========
    local titleX, titleY
    if isPortrait then
        -- 竖屏：标题在统计区域上方，居中
        titleX = statsX + statsW / 2
        titleY = statsY - baseUnit * 2.5
    else
        -- 横屏：标题在右侧统计区域上方
        titleX = statsX + statsW / 2
        titleY = panelY + baseUnit * 1.2
    end
    
    nvgFontSize(nvg, fonts.pageTitle * 1.2)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 100, 100, 255))
    nvgText(nvg, titleX, titleY, "战舰损毁")
    
    -- 标题下划线
    local lineY = titleY + fonts.pageTitle * 1.4
    local lineHalfW = math.min(baseUnit * 5, statsW * 0.4)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, titleX - lineHalfW, lineY)
    nvgLineTo(nvg, titleX + lineHalfW, lineY)
    nvgStrokeWidth(nvg, 2)
    local lineGrad = nvgLinearGradient(nvg, titleX - lineHalfW, 0, titleX + lineHalfW, 0,
        nvgRGBA(180, 60, 60, 0), nvgRGBA(180, 60, 60, 255))
    nvgStrokePaint(nvg, lineGrad)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, titleX - lineHalfW, lineY)
    nvgLineTo(nvg, titleX + lineHalfW, lineY)
    local lineGrad2 = nvgLinearGradient(nvg, titleX, 0, titleX + lineHalfW, 0,
        nvgRGBA(180, 60, 60, 255), nvgRGBA(180, 60, 60, 0))
    nvgStrokePaint(nvg, lineGrad2)
    nvgStroke(nvg)
    
    -- ========== 角色图片 ==========
    if Overlays.gameOverImage and Overlays.gameOverImage > 0 then
        -- 图片容器背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, imageX, imageY, imageW, imageH, baseUnit * 0.4)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 150))
        nvgFill(nvg)
        
        -- 绘制图片
        local imgPaint = nvgImagePattern(nvg, imageX, imageY, imageW, imageH, 0, Overlays.gameOverImage, 1.0)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, imageX, imageY, imageW, imageH, baseUnit * 0.4)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)
        
        -- 图片边框
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, imageX, imageY, imageW, imageH, baseUnit * 0.4)
        nvgStrokeWidth(nvg, 2)
        nvgStrokeColor(nvg, nvgRGBA(100, 50, 50, 150))
        nvgStroke(nvg)
        
        -- 底部渐变遮罩（用于文字）
        local maskGrad = nvgLinearGradient(nvg, imageX, imageY + imageH - baseUnit * 3, 
            imageX, imageY + imageH, nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 200))
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, imageX, imageY, imageW, imageH, baseUnit * 0.4)
        nvgFillPaint(nvg, maskGrad)
        nvgFill(nvg)
        
        -- 击毁者信息（显示在图片底部）
        if battle.killedBy then
            nvgFontSize(nvg, fonts.description)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(nvg, nvgRGBA(255, 150, 150, 255))
            nvgText(nvg, imageX + imageW / 2, imageY + imageH - baseUnit * 0.5, 
                "被 " .. battle.killedBy.name .. " 击毁")
        end
    elseif not Overlays.gameOverImageLoaded then
        -- 图片尚在下载，显示骨架屏占位
        ImageLoader.RenderPlaceholder(nvg, imageX, imageY, imageW, imageH, Overlays.animTime, baseUnit * 0.4)
    end
    
    -- ========== 统计面板 ==========
    -- 统计背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, statsX, statsY, statsW, statsH, baseUnit * 0.3)
    nvgFillColor(nvg, nvgRGBA(20, 15, 25, 200))
    nvgFill(nvg)
    
    -- 统计数据
    local statItems = {
        {label = "抵达波次", value = tostring(battle.currentWave or 1), color = {255, 200, 80}},
        {label = "击杀敌人", value = tostring(battle.totalKills or 0), color = {100, 200, 255}},
        {label = "游戏时长", value = FormatTime(battle.playTime or 0), color = {200, 200, 200}},
        {label = "总伤害", value = string.format("%.0f", battle.totalDamageDealt or 0), color = {255, 150, 100}},
        {label = "获得晶体", value = tostring(battle.totalCrystalsEarned or 0), color = {150, 255, 200}},
        {label = "消耗晶体", value = tostring(battle.totalCrystalsSpent or 0), color = {255, 200, 150}},
        {label = "购买次数", value = tostring(battle.totalPurchases or 0), color = {200, 180, 255}},
        {label = "刷新次数", value = tostring(battle.totalRefreshes or 0), color = {180, 200, 255}},
    }
    
    local statPadding = baseUnit * 0.6
    local statRowH = (statsH - statPadding * 2) / #statItems
    local maxRowH = baseUnit * 2.5
    statRowH = math.min(statRowH, maxRowH)
    
    for i, stat in ipairs(statItems) do
        local rowY = statsY + statPadding + (i - 1) * statRowH
        
        -- 交替行背景
        if i % 2 == 0 then
            nvgBeginPath(nvg)
            nvgRect(nvg, statsX + statPadding * 0.5, rowY, statsW - statPadding, statRowH)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 10))
            nvgFill(nvg)
        end
        
        -- 标签
        nvgFontSize(nvg, fonts.statLabel)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(140, 150, 170, 220))
        nvgText(nvg, statsX + statPadding, rowY + statRowH / 2, stat.label)
        
        -- 数值
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(stat.color[1], stat.color[2], stat.color[3], 255))
        nvgText(nvg, statsX + statsW - statPadding, rowY + statRowH / 2, stat.value)
    end
    
    -- ========== 重新开始按钮 ==========
    local btnW = isPortrait and baseUnit * 12 or baseUnit * 10
    local btnH = baseUnit * 2.5
    local btnX = panelX + (panelW - btnW) / 2
    local btnY = panelY + panelH - baseUnit * 4
    
    -- 按钮缓存（用于点击检测）
    Overlays.gameOverBtnRect = {x = btnX, y = btnY, w = btnW, h = btnH}
    
    UIStyle.DrawSciFiButton(nvg, btnX, btnY, btnW, btnH, "重新开始", {
        baseUnit = baseUnit,
        animTime = Overlays.animTime,
        variant = "danger",
        fontSize = fonts.buttonText,
        pressed = Overlays.pressedGameOverBtn,
    })
end

-- ============================================================================
-- 胜利UI
-- ============================================================================

function Overlays.RenderVictory(nvg, sw, sh, baseUnit, fontSize, battle, player)
    Overlays.animTime = Overlays.animTime + 0.016
    
    UIStyle.DrawOverlay(nvg, sw, sh, {alpha = 220, color = {r = 5, g = 15, b = 25}})
    
    -- 获取响应式布局
    local layout = GetPanelLayout(sw, sh, baseUnit, "victory")
    local panelW = layout.panelW
    local panelH = layout.panelH
    local panelX = layout.panelX
    local panelY = layout.panelY
    local fonts = layout.fonts
    local isPortrait = layout.isPortrait
    
    -- 科技风格面板（绿色主题）
    UIStyle.DrawSciFiPanel(nvg, panelX, panelY, panelW, panelH, {
        baseUnit = baseUnit,
        animTime = Overlays.animTime,
        title = "🏆 任务完成! 🏆",
        borderColor = {r = 80, g = 200, b = 120},
    })
    
    -- 分隔线
    nvgBeginPath(nvg)
    local lineY = panelY + baseUnit * 2.5
    nvgMoveTo(nvg, panelX + baseUnit * 1.5, lineY)
    nvgLineTo(nvg, panelX + panelW - baseUnit * 1.5, lineY)
    nvgStrokeColor(nvg, nvgRGBA(80, 200, 120, 100))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- 统计信息（两列）
    local statsY = panelY + baseUnit * 3.5
    local col1X = sw / 2 - (isPortrait and panelW * 0.22 or baseUnit * 4.0)
    local col2X = sw / 2 + (isPortrait and panelW * 0.22 or baseUnit * 4.0)
    
    nvgFontSize(nvg, fonts.statLabel)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(160, 170, 180, 200))
    nvgText(nvg, col1X, statsY, "击杀敌人")
    
    nvgFontSize(nvg, fonts.pageTitle)
    nvgFillColor(nvg, nvgRGBA(255, 200, 80, 255))
    nvgText(nvg, col1X, statsY + baseUnit * 1.0, tostring(battle.totalKills))
    
    nvgFontSize(nvg, fonts.statLabel)
    nvgFillColor(nvg, nvgRGBA(160, 170, 180, 200))
    nvgText(nvg, col2X, statsY, "舰桥等级")
    
    nvgFontSize(nvg, fonts.pageTitle)
    nvgFillColor(nvg, nvgRGBA(180, 120, 255, 255))
    nvgText(nvg, col2X, statsY + baseUnit * 1.0, tostring(player.bridgeLevel))
    
    -- 重新开始按钮
    local btnW = isPortrait and baseUnit * 14.0 or baseUnit * 8.0
    local btnH = isPortrait and baseUnit * 3.0 or baseUnit * 2.0
    local btnX = (sw - btnW) / 2
    local btnY = panelY + panelH - baseUnit * (isPortrait and 5.0 or 3.5)
    
    UIStyle.DrawSciFiButton(nvg, btnX, btnY, btnW, btnH, "再来一局", {
        baseUnit = baseUnit,
        animTime = Overlays.animTime,
        variant = "success",
        fontSize = fonts.buttonText,
        pressed = Overlays.pressedVictoryBtn,
    })
    
    -- 提示（按下时隐藏）
    if not Overlays.pressedVictoryBtn then
        nvgFontSize(nvg, fonts.hintText)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(100, 120, 140, 180))
        nvgText(nvg, sw / 2, panelY + panelH - baseUnit * 1.5, "点击按钮再来一局")
    end
end

-- ============================================================================
-- 波次公告
-- ============================================================================

local waveAnnouncement = {active = false, timer = 0, wave = 0}

function Overlays.StartWaveAnnouncement(waveNum)
    waveAnnouncement.active = true
    waveAnnouncement.timer = 0
    waveAnnouncement.wave = waveNum
end

function Overlays.UpdateWaveAnnouncement(dt)
    if waveAnnouncement.active then
        waveAnnouncement.timer = waveAnnouncement.timer + dt
        if waveAnnouncement.timer >= 2.5 then
            waveAnnouncement.active = false
        end
    end
end

function Overlays.RenderWaveAnnouncement(nvg, sw, sh, baseUnit, fontSize)
    if not waveAnnouncement.active then return end
    
    local duration = 2.5
    local progress = waveAnnouncement.timer / duration
    
    local alpha = 255
    if progress < 0.2 then
        alpha = 255 * (progress / 0.2)
    elseif progress > 0.7 then
        alpha = 255 * (1 - (progress - 0.7) / 0.3)
    end
    
    local scale = 1.0
    if progress < 0.2 then
        scale = 0.5 + 0.5 * (progress / 0.2)
    end
    
    -- 波次标题
    local titleSize = baseUnit * 2.5 * scale
    nvgFontSize(nvg, titleSize)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    
    -- 发光效果
    nvgFillColor(nvg, nvgRGBA(255, 200, 80, alpha * 0.3))
    nvgText(nvg, sw / 2 - 2, sh * 0.4, string.format("波次 %d", waveAnnouncement.wave))
    nvgText(nvg, sw / 2 + 2, sh * 0.4, string.format("波次 %d", waveAnnouncement.wave))
    
    nvgFillColor(nvg, nvgRGBA(255, 200, 80, alpha))
    nvgText(nvg, sw / 2, sh * 0.4, string.format("波次 %d", waveAnnouncement.wave))
    
    local waveConfig = Waves.Get(waveAnnouncement.wave)
    if waveConfig then
        nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.0 * scale))
        nvgFillColor(nvg, nvgRGBA(180, 190, 200, alpha * 0.8))
        nvgText(nvg, sw / 2, sh * 0.5, string.format("持续 %d 秒", waveConfig.duration))
        
        if waveConfig.name then
            nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.8 * scale))
            nvgFillColor(nvg, nvgRGBA(140, 150, 160, alpha * 0.7))
            nvgText(nvg, sw / 2, sh * 0.56, waveConfig.name)
        end
    end
end

-- ============================================================================
-- Boss阶段公告
-- ============================================================================

local bossPhaseAnnouncement = {active = false, timer = 0, phaseName = ""}

function Overlays.ShowBossPhaseAnnouncement(phaseName)
    bossPhaseAnnouncement.active = true
    bossPhaseAnnouncement.timer = 0
    bossPhaseAnnouncement.phaseName = phaseName or "阶段变化"
end

function Overlays.UpdateBossPhaseAnnouncement(dt)
    if bossPhaseAnnouncement.active then
        bossPhaseAnnouncement.timer = bossPhaseAnnouncement.timer + dt
        if bossPhaseAnnouncement.timer >= 2.0 then
            bossPhaseAnnouncement.active = false
        end
    end
end

function Overlays.RenderBossPhaseAnnouncement(nvg, sw, sh, baseUnit, fontSize)
    if not bossPhaseAnnouncement.active then return end
    
    local duration = 2.0
    local progress = bossPhaseAnnouncement.timer / duration
    
    local alpha = 255
    if progress < 0.15 then
        alpha = 255 * (progress / 0.15)
    elseif progress > 0.7 then
        alpha = 255 * (1 - (progress - 0.7) / 0.3)
    end
    
    local scale = 1.0
    if progress < 0.15 then
        scale = 0.6 + 0.4 * (progress / 0.15)
    end
    
    -- Boss阶段
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.5 * scale))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 80, 80, alpha))
    nvgText(nvg, sw / 2, sh * 0.35, "Boss 进入")
    
    -- 阶段名称（带发光）
    local titleSize = baseUnit * 2.0 * scale
    nvgFontSize(nvg, titleSize)
    
    nvgFillColor(nvg, nvgRGBA(255, 200, 80, alpha * 0.4))
    nvgText(nvg, sw / 2 - 2, sh * 0.43, bossPhaseAnnouncement.phaseName)
    nvgText(nvg, sw / 2 + 2, sh * 0.43, bossPhaseAnnouncement.phaseName)
    
    nvgFillColor(nvg, nvgRGBA(255, 200, 80, alpha))
    nvgText(nvg, sw / 2, sh * 0.43, bossPhaseAnnouncement.phaseName)
end

-- ============================================================================
-- 伤害数字渲染
-- ============================================================================

function Overlays.RenderDamageNumbers(nvg, sw, sh, baseUnit, fontSize, damageNumbers, camera)
    for _, num in ipairs(damageNumbers) do
        local worldPos = Vector3(num.x, num.y, 0)
        local screenPos = camera:WorldToScreenPoint(worldPos)
        
        local sx = screenPos.x * sw
        local sy = screenPos.y * sh
        
        local alpha = 255 * (1 - num.timer / num.duration)
        
        nvgFontSize(nvg, UIStyle.FontSize(baseUnit, num.isCrit and 1.2 or 0.9))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        
        if num.text then
            nvgFillColor(nvg, nvgRGBA(180, 190, 200, alpha))
            nvgText(nvg, sx, sy, num.text)
        elseif num.isPlayerDamage then
            -- 玩家受伤 - 红色带发光
            nvgFillColor(nvg, nvgRGBA(255, 80, 80, alpha * 0.5))
            nvgText(nvg, sx - 1, sy, string.format("-%d", math.floor(num.damage)))
            nvgText(nvg, sx + 1, sy, string.format("-%d", math.floor(num.damage)))
            nvgFillColor(nvg, nvgRGBA(255, 80, 80, alpha))
            nvgText(nvg, sx, sy, string.format("-%d", math.floor(num.damage)))
        else
            local color
            if num.isCrit then
                color = {r = 255, g = 200, b = 80}
                -- 暴击发光
                nvgFillColor(nvg, nvgRGBA(color.r, color.g, color.b, alpha * 0.4))
                nvgText(nvg, sx - 1, sy, string.format("%d!", math.floor(num.damage)))
                nvgText(nvg, sx + 1, sy, string.format("%d!", math.floor(num.damage)))
            else
                color = {r = 255, g = 220, b = 100}
            end
            nvgFillColor(nvg, nvgRGBA(color.r, color.g, color.b, alpha))
            nvgText(nvg, sx, sy, string.format("%d%s", math.floor(num.damage), num.isCrit and "!" or ""))
        end
    end
end

-- ============================================================================
-- 舰桥升级触摸处理
-- ============================================================================

-- 获取升级界面布局（供按下/释放共用）
-- 🔴 性能优化：使用帧缓存，同一帧内只计算一次
local function GetUpgradeLayout(sw, sh)
    -- 确保是整数，避免 string.format %d 报错
    local swInt, shInt = math.floor(sw), math.floor(sh)
    local cacheKey = string.format("upgrade_layout_%d_%d", swInt, shInt)
    
    return FrameCache:Get(cacheKey, function()
        -- 🔴 使用安全区系统
        local safe = UISafeArea.Calculate(sw, sh)
        local safeX, safeY, safeW, safeH = safe.x, safe.y, safe.w, safe.h
        local baseUnit = safe.baseUnit
        local isPortrait = safe.isPortrait or (sh > sw)
        
        local totalW, totalH, startX, startY
        local leftPanelW, rightPanelW, panelH, gap
        
        if isPortrait then
            totalW = safeW * 0.95
            totalH = safeH * 0.90
            startX = safeX + (safeW - totalW) / 2
            startY = safeY + (safeH - totalH) / 2
            leftPanelW = totalW
            rightPanelW = totalW
            panelH = totalH * 0.52
            gap = baseUnit * 0.5
        else
            totalW = math.min(safeW * 0.95, baseUnit * 55)  -- 增加总宽度
            totalH = safeH * 0.88
            startX = safeX + (safeW - totalW) / 2
            startY = safeY + (safeH - totalH) / 2
            gap = baseUnit * 0.8
            leftPanelW = totalW * 0.40  -- 属性面板更宽
            rightPanelW = totalW - leftPanelW - gap
            panelH = totalH
        end
        
        local leftX = startX
        local leftY = isPortrait and (startY + panelH + gap) or startY
        local leftH = isPortrait and (totalH - panelH - gap) or panelH
        local rightX = isPortrait and startX or (leftX + leftPanelW + gap)
        local rightY = startY
        local rightH = panelH
        
        return {
            baseUnit = baseUnit,
            isPortrait = isPortrait,
            leftX = leftX, leftY = leftY, leftH = leftH, leftPanelW = leftPanelW,
            rightX = rightX, rightY = rightY, rightH = rightH, rightPanelW = rightPanelW,
            -- 保存安全区信息供字体计算使用
            safeW = safeW, safeH = safeH,
        }
    end)
end

-- 检测点击的升级选项索引
local function GetClickedOptionIndex(mx, my, sw, sh, bridgeUpgrade)
    local layout = GetUpgradeLayout(sw, sh)
    local baseUnit = layout.baseUnit
    local rightX = layout.rightX
    local rightY = layout.rightY
    local rightPanelW = layout.rightPanelW
    
    -- 🔴 使用安全区尺寸获取字体（与渲染保持一致）
    local fonts = UIStyle.GetTypography(layout.safeW, layout.safeH)
    
    -- 标题区域高度计算（与渲染保持一致）
    local upgradeTitleFontSize = fonts.pageTitle
    local upgradeLevelFontSize = fonts.description
    local upgradeTitlePadding = baseUnit * 0.5
    local levelY = rightY + upgradeTitlePadding + upgradeTitleFontSize + baseUnit * 0.2
    local optionAreaStartY = levelY + upgradeLevelFontSize + baseUnit * 0.4
    
    -- 卡片尺寸计算
    local optionNameFontSize = fonts.cardTitle * 1.1
    local optionDescFontSize = fonts.cardTitle * 1.0
    local optionPadding = baseUnit * 0.4
    local optionH = optionPadding + optionNameFontSize + baseUnit * 0.2 + optionDescFontSize + optionPadding
    local optionGap = baseUnit * 0.4
    local optionW = rightPanelW - baseUnit * 1.6
    local optionStartY = optionAreaStartY
    
    local options = bridgeUpgrade.options or {}
    for i, option in ipairs(options) do
        local optX = rightX + baseUnit * 0.8
        local optY = optionStartY + (i - 1) * (optionH + optionGap)
        
        if mx >= optX and mx <= optX + optionW and
           my >= optY and my <= optY + optionH then
            return i
        end
    end
    
    return nil
end

-- 检测是否点击刷新按钮
local function IsClickOnRefreshBtn(mx, my, sw, sh)
    local layout = GetUpgradeLayout(sw, sh)
    local baseUnit = layout.baseUnit
    local rightX = layout.rightX
    local rightH = layout.rightH
    local rightY = layout.rightY
    local rightPanelW = layout.rightPanelW
    
    -- 🔴 使用安全区尺寸获取字体（与渲染保持一致）
    local fonts = UIStyle.GetTypography(layout.safeW, layout.safeH)
    local refreshFontSize = fonts.description
    local refreshBtnH = refreshFontSize * 1.8
    local refreshBtnW = refreshFontSize * 6
    local refreshBtnX = rightX + (rightPanelW - refreshBtnW) / 2
    local refreshBtnY = rightY + rightH - refreshBtnH - baseUnit * 0.8
    
    return mx >= refreshBtnX and mx <= refreshBtnX + refreshBtnW and
           my >= refreshBtnY and my <= refreshBtnY + refreshBtnH
end

function Overlays.HandleBridgeUpgradeTouch(sw, sh, bridgeUpgrade, onSelect, onRefresh, refreshCost, playerCrystals)
    if not bridgeUpgrade.active then 
        Overlays.pressedOptionIndex = nil
        Overlays.pressedRefreshBtn = false
        return false 
    end
    
    local mx = TouchInput.x
    local my = TouchInput.y
    local layout = GetUpgradeLayout(sw, sh)
    local baseUnit = layout.baseUnit
    
    -- 鼠标按下：设置按下状态
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        -- 检查标签页点击（立即生效，无需等待释放）
        -- 🔴 使用安全区尺寸获取字体（与渲染保持一致）
        local fonts = UIStyle.GetTypography(layout.safeW, layout.safeH)
        local titleFontSize = fonts.cardTitle
        local tabFontSize = fonts.description
        local titlePadding = baseUnit * 0.25
        local tabBtnH = tabFontSize * 1.6
        local tabBtnW = layout.leftPanelW * 0.35
        local tabBtnY = layout.leftY + titlePadding + titleFontSize + baseUnit * 0.15
        local tabGap = baseUnit * 0.5
        local tabStartX = layout.leftX + (layout.leftPanelW - tabBtnW * 2 - tabGap) / 2
        
        for i = 1, 2 do
            local tabX = tabStartX + (i - 1) * (tabBtnW + tabGap)
            if mx >= tabX and mx <= tabX + tabBtnW and
               my >= tabBtnY and my <= tabBtnY + tabBtnH then
                if statsScrollState.currentTab ~= i then
                    statsScrollState.currentTab = i
                    statsScrollState.offset = 0
                end
                return true
            end
        end
        
        -- 检查刷新按钮按下
        if IsClickOnRefreshBtn(mx, my, sw, sh) then
            refreshCost = refreshCost or 1
            playerCrystals = playerCrystals or 0
            if playerCrystals >= refreshCost then
                Overlays.pressedRefreshBtn = true
            end
            return true
        end
        
        -- 检查升级选项按下
        local optionIndex = GetClickedOptionIndex(mx, my, sw, sh, bridgeUpgrade)
        if optionIndex then
            Overlays.pressedOptionIndex = optionIndex
            return true
        end
        
        return false
    end
    
    -- 鼠标释放：触发回调
    local UIScreen = require("ui.UIScreen")
    if UIScreen.IsMouseReleased() then
        -- 刷新按钮释放
        if Overlays.pressedRefreshBtn then
            Overlays.pressedRefreshBtn = false
            if IsClickOnRefreshBtn(mx, my, sw, sh) then
                if onRefresh then onRefresh() end
                return true
            end
        end
        
        -- 升级选项释放
        if Overlays.pressedOptionIndex then
            local pressedIndex = Overlays.pressedOptionIndex
            Overlays.pressedOptionIndex = nil
            local currentIndex = GetClickedOptionIndex(mx, my, sw, sh, bridgeUpgrade)
            if currentIndex == pressedIndex then
                if onSelect then onSelect(pressedIndex) end
                return true
            end
        end
    end
    
    return false
end

-- ============================================================================
-- 游戏结束/胜利触摸处理
-- ============================================================================

-- 获取 GameOver 按钮布局（与 RenderGameOver 保持一致，使用安全区）
local function GetGameOverButtonLayoutSafe(sw, sh)
    local safe = UISafeArea.Calculate(sw, sh)
    local safeX, safeY, safeW, safeH = safe.x, safe.y, safe.w, safe.h
    local safeBaseUnit = safe.baseUnit
    local isPortrait = safe.isPortrait or (sh > sw)
    
    -- 面板布局（与 RenderGameOver 一致）
    local panelW, panelH, panelX, panelY
    if isPortrait then
        panelW = safeW * 0.92
        panelH = safeH * 0.78
        panelX = safeX + (safeW - panelW) / 2
        panelY = safeY + (safeH - panelH) / 2
    else
        panelW = safeW * 0.82
        panelH = safeH * 0.82
        panelX = safeX + (safeW - panelW) / 2
        panelY = safeY + (safeH - panelH) / 2
    end
    
    -- 按钮布局（与 RenderGameOver 一致）
    local baseUnit = safeBaseUnit
    local btnW = isPortrait and baseUnit * 12 or baseUnit * 10
    local btnH = baseUnit * 2.5
    local btnX = panelX + (panelW - btnW) / 2
    local btnY = panelY + panelH - baseUnit * 4
    
    return {x = btnX, y = btnY, w = btnW, h = btnH}
end

-- 获取 Victory 按钮布局（保持原有逻辑）
local function GetVictoryButtonLayout(sw, sh)
    local baseUnit = math.min(sw, sh) / 40
    local layout = GetPanelLayout(sw, sh, baseUnit, "victory")
    local isPortrait = layout.isPortrait
    
    local btnW = isPortrait and baseUnit * 14.0 or baseUnit * 8.0
    local btnH = isPortrait and baseUnit * 3.0 or baseUnit * 2.0
    local btnX = (sw - btnW) / 2
    local btnY = layout.panelY + layout.panelH - baseUnit * (isPortrait and 5.0 or 3.5)
    
    return {x = btnX, y = btnY, w = btnW, h = btnH}
end

function Overlays.HandleGameOverTouch(sw, sh, onRestart)
    local mx = TouchInput.x
    local my = TouchInput.y
    local btn = GetGameOverButtonLayoutSafe(sw, sh)
    
    -- 键盘支持：Enter 或 ESC 重新开始
    if input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_KP_ENTER) or input:GetKeyPress(KEY_ESCAPE) then
        if onRestart then onRestart() end
        return true
    end
    
    -- 鼠标按下：设置按下状态
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        if mx >= btn.x and mx <= btn.x + btn.w and
           my >= btn.y and my <= btn.y + btn.h then
            Overlays.pressedGameOverBtn = true
            return true
        end
        return false
    end
    
    -- 鼠标释放：触发回调
    local UIScreen = require("ui.UIScreen")
    if UIScreen.IsMouseReleased() then
        if Overlays.pressedGameOverBtn then
            Overlays.pressedGameOverBtn = false
            if mx >= btn.x and mx <= btn.x + btn.w and
               my >= btn.y and my <= btn.y + btn.h then
                if onRestart then onRestart() end
                return true
            end
        end
    end
    
    return false
end

function Overlays.HandleVictoryTouch(sw, sh, onRestart)
    local mx = TouchInput.x
    local my = TouchInput.y
    local btn = GetVictoryButtonLayout(sw, sh)
    
    -- 键盘支持：Enter 或 ESC 重新开始
    if input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_KP_ENTER) or input:GetKeyPress(KEY_ESCAPE) then
        if onRestart then onRestart() end
        return true
    end
    
    -- 鼠标按下：设置按下状态
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        if mx >= btn.x and mx <= btn.x + btn.w and
           my >= btn.y and my <= btn.y + btn.h then
            Overlays.pressedVictoryBtn = true
            return true
        end
        return false
    end
    
    -- 鼠标释放：触发回调
    local UIScreen = require("ui.UIScreen")
    if UIScreen.IsMouseReleased() then
        if Overlays.pressedVictoryBtn then
            Overlays.pressedVictoryBtn = false
            if mx >= btn.x and mx <= btn.x + btn.w and
               my >= btn.y and my <= btn.y + btn.h then
                if onRestart then onRestart() end
                return true
            end
        end
    end
    
    return false
end

-- ============================================================================
-- 属性面板滚动处理
-- ============================================================================

function Overlays.HandleStatsScroll(sw, sh, bridgeUpgrade)
    if not bridgeUpgrade or not bridgeUpgrade.active then return end
    
    local baseUnit = math.min(sw, sh) / 40
    local isPortrait = sh > sw
    
    -- 计算属性面板区域（与渲染保持一致）
    local totalW, totalH, startX, startY
    local leftPanelW, leftH
    
    if isPortrait then
        totalW = sw * 0.95
        totalH = sh * 0.90
        startX = (sw - totalW) / 2
        startY = (sh - totalH) / 2
        leftPanelW = totalW
        local panelH = totalH * 0.52
        local gap = baseUnit * 0.5
        leftH = totalH - panelH - gap
    else
        totalW = math.min(sw * 0.90, baseUnit * 50)
        totalH = sh * 0.88
        startX = (sw - totalW) / 2
        startY = (sh - totalH) / 2
        local gap = baseUnit * 0.8
        leftPanelW = totalW * 0.35
        leftH = totalH
    end
    
    local leftX = startX
    local leftY = isPortrait and (startY + totalH * 0.52 + baseUnit * 0.5) or startY
    
    local mx = TouchInput.x
    local my = TouchInput.y
    
    -- 检查是否在属性面板区域内
    local inPanel = mx >= leftX and mx <= leftX + leftPanelW and
                    my >= leftY and my <= leftY + leftH
    
    -- 鼠标滚轮滚动（使用正确的API: input.mouseMoveWheel）
    local wheelDelta = input.mouseMoveWheel or 0
    if wheelDelta ~= 0 and inPanel then
        statsScrollState.offset = statsScrollState.offset - wheelDelta * 0.5
        statsScrollState.offset = math.max(0, math.min(statsScrollState.offset, statsScrollState.maxOffset))
    end
    
    -- 触摸拖拽滚动
    if input:GetMouseButtonDown(MOUSEB_LEFT) then
        if inPanel then
            if statsScrollState.touchStartY == nil then
                statsScrollState.touchStartY = my
                statsScrollState.scrollStartOffset = statsScrollState.offset
            else
                local dragDelta = statsScrollState.touchStartY - my
                -- 🔴 行高必须与渲染保持一致（基于字体大小）
                local fonts = UIStyle.GetTypography(sw, sh)
                local statFontSize = fonts.statLabel
                local rowH = math.max((statFontSize or 16) * 1.25, 1)  -- 与渲染一致的紧凑行距，确保不为零
                local scrollDelta = dragDelta / rowH
                statsScrollState.offset = statsScrollState.scrollStartOffset + scrollDelta
                statsScrollState.offset = math.max(0, math.min(statsScrollState.offset, statsScrollState.maxOffset))
            end
        end
    else
        statsScrollState.touchStartY = nil
    end
end

-- 重置滚动状态（升级界面打开时调用）
function Overlays.ResetStatsScroll()
    statsScrollState.offset = 0
    statsScrollState.touchStartY = nil
    statsScrollState.currentTab = 1  -- 默认显示"主要"标签页
end

-- ============================================================================
-- 超空间跳跃消息
-- ============================================================================

local hyperspaceMessage = {
    active = false,
    timer = 0,
    isLeaving = false,  -- true=离开战斗, false=进入战斗
    fading = false,     -- 是否正在渐隐
    fadeTimer = 0,      -- 渐隐计时器
    fadeDuration = 0.5, -- 渐隐持续时间（秒）
}

function Overlays.ShowHyperspaceMessage(isLeaving)
    hyperspaceMessage.active = true
    hyperspaceMessage.timer = 0
    hyperspaceMessage.isLeaving = isLeaving or false
    hyperspaceMessage.fading = false
    hyperspaceMessage.fadeTimer = 0
end

function Overlays.HideHyperspaceMessage()
    -- 开始渐隐而不是立即隐藏
    hyperspaceMessage.fading = true
    hyperspaceMessage.fadeTimer = 0
end

function Overlays.IsHyperspaceMessageActive()
    return hyperspaceMessage.active
end

function Overlays.UpdateHyperspaceMessage(dt)
    if hyperspaceMessage.active then
        hyperspaceMessage.timer = hyperspaceMessage.timer + dt
        
        -- 处理渐隐
        if hyperspaceMessage.fading then
            hyperspaceMessage.fadeTimer = hyperspaceMessage.fadeTimer + dt
            if hyperspaceMessage.fadeTimer >= hyperspaceMessage.fadeDuration then
                hyperspaceMessage.active = false
                hyperspaceMessage.fading = false
            end
        end
    end
end

function Overlays.RenderHyperspaceMessage(nvg, sw, sh, baseUnit, fontSize)
    if not hyperspaceMessage.active then return end
    
    local timer = hyperspaceMessage.timer
    
    -- 渐隐系数（1.0 = 完全显示，0.0 = 完全隐藏）
    local fadeMultiplier = 1.0
    if hyperspaceMessage.fading then
        fadeMultiplier = 1.0 - (hyperspaceMessage.fadeTimer / hyperspaceMessage.fadeDuration)
        fadeMultiplier = math.max(0, fadeMultiplier)
    end
    
    -- 动态效果参数
    local pulseAlpha = 0.7 + 0.3 * math.sin(timer * 8)
    local streakIntensity = math.min(timer / 0.5, 1.0)  -- 0.5秒内渐入
    
    -- 屏幕边缘光晕效果（模拟跃迁隧道）- 渐变范围必须与绘制区域匹配
    local edgeWidth = sw * 0.08  -- 边缘宽度
    local edgeAlpha = 50 * streakIntensity * pulseAlpha * fadeMultiplier  -- 应用渐隐
    
    -- 左边缘（从左向右渐变消失）
    local gradient = nvgLinearGradient(nvg, 0, 0, edgeWidth, 0, 
        nvgRGBA(100, 150, 255, edgeAlpha),
        nvgRGBA(100, 150, 255, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, edgeWidth, sh)
    nvgFillPaint(nvg, gradient)
    nvgFill(nvg)
    
    -- 右边缘（从右向左渐变消失）
    local gradient2 = nvgLinearGradient(nvg, sw, 0, sw - edgeWidth, 0,
        nvgRGBA(100, 150, 255, edgeAlpha),
        nvgRGBA(100, 150, 255, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sw - edgeWidth, 0, edgeWidth, sh)
    nvgFillPaint(nvg, gradient2)
    nvgFill(nvg)
    
    -- 上边缘
    local edgeHeight = sh * 0.06
    local gradientTop = nvgLinearGradient(nvg, 0, 0, 0, edgeHeight,
        nvgRGBA(100, 150, 255, edgeAlpha * 0.7),
        nvgRGBA(100, 150, 255, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, edgeHeight)
    nvgFillPaint(nvg, gradientTop)
    nvgFill(nvg)
    
    -- 下边缘
    local gradientBottom = nvgLinearGradient(nvg, 0, sh, 0, sh - edgeHeight,
        nvgRGBA(100, 150, 255, edgeAlpha * 0.7),
        nvgRGBA(100, 150, 255, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, sh - edgeHeight, sw, edgeHeight)
    nvgFillPaint(nvg, gradientBottom)
    nvgFill(nvg)
    
    -- 中央文字
    local textScale = 1.0 + 0.05 * math.sin(timer * 6)
    local textAlpha = math.min(timer / 0.3, 1.0) * 255 * fadeMultiplier  -- 应用渐隐
    
    -- 文字发光效果
    nvgFontSize(nvg, baseUnit * 2.0 * textScale)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    
    -- 外层发光
    nvgFillColor(nvg, nvgRGBA(100, 180, 255, textAlpha * 0.3))
    nvgText(nvg, sw / 2 - 2, sh * 0.45, "超空间跳跃中...")
    nvgText(nvg, sw / 2 + 2, sh * 0.45, "超空间跳跃中...")
    nvgText(nvg, sw / 2, sh * 0.45 - 2, "超空间跳跃中...")
    nvgText(nvg, sw / 2, sh * 0.45 + 2, "超空间跳跃中...")
    
    -- 主文字
    nvgFillColor(nvg, nvgRGBA(200, 230, 255, textAlpha))
    nvgText(nvg, sw / 2, sh * 0.45, "超空间跳跃中...")
    
    -- 副标题
    nvgFontSize(nvg, baseUnit * 1.0)
    nvgFillColor(nvg, nvgRGBA(150, 180, 220, textAlpha * 0.7))
    local subtitleText = hyperspaceMessage.isLeaving and "正在离开战斗区域" or "正在进入战斗区域"
    nvgText(nvg, sw / 2, sh * 0.52, subtitleText)
    
    -- 绘制一些速度线条（增强跃迁感）
    local lineCount = 20
    nvgStrokeWidth(nvg, 2)
    for i = 1, lineCount do
        local angle = (i / lineCount) * math.pi * 2 + timer * 3
        local dist = sw * 0.3 + (i * 7 + timer * 200) % (sw * 0.4)
        local lineLen = 30 + 50 * streakIntensity
        
        local cx, cy = sw / 2, sh / 2
        local x1 = cx + math.cos(angle) * dist
        local y1 = cy + math.sin(angle) * dist * 0.5  -- 椭圆形分布
        local x2 = cx + math.cos(angle) * (dist + lineLen)
        local y2 = cy + math.sin(angle) * (dist + lineLen) * 0.5
        
        local lineAlpha = (1 - dist / (sw * 0.7)) * 180 * streakIntensity * pulseAlpha * fadeMultiplier  -- 应用渐隐
        
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x1, y1)
        nvgLineTo(nvg, x2, y2)
        nvgStrokeColor(nvg, nvgRGBA(180, 220, 255, lineAlpha))
        nvgStroke(nvg)
    end
end

return Overlays
