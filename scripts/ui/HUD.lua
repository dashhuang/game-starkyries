-- ============================================================================
-- 星河战姬 Starkyries - 游戏内HUD
-- 科技风格统一设计
-- 响应式布局：横竖屏自适应
-- ============================================================================
-- 
-- UI 尺寸标准: baseUnit = math.min(sw, sh) / 40
-- 详见: game-doc/docs/6-技术文档/UI_GUIDELINES.md
-- 
-- ============================================================================

local Weapons = require("config.weapons")
local Waves = require("config.waves")
local UIStyle = require("ui.UIStyle")
local UIScreen = require("ui.UIScreen")
local FrameCache = require("utils.FrameCache")
local UserSettings = require("core.UserSettings")
local TouchInput = require("utils.TouchInput")

local HUD = {}

HUD.animTime = 0
HUD.showKeyboardFocus = false  -- 键盘导航模式（预留，当前HUD为纯展示UI，无交互）
HUD.showWeaponList = true      -- 是否显示武器列表（从云存档加载）
HUD.autoBattleEnabled = false  -- 是否开启自动战斗
HUD.settingsLoaded = false     -- 设置是否已加载

-- ============================================================================
-- 初始化（从云存档加载用户设置）
-- ============================================================================

function HUD.Init()
    if HUD.settingsLoaded then return end
    
    -- 从用户设置加载武器列表展开状态
    if UserSettings.IsInitialized() then
        HUD.showWeaponList = UserSettings.Get("hudWeaponListExpanded")
        HUD.settingsLoaded = true
        print("[HUD] Loaded weapon list state: " .. (HUD.showWeaponList and "expanded" or "collapsed"))
    end
end

-- 按钮区域缓存
HUD.pauseButtonRect = nil
HUD.weaponListButtonRect = nil
HUD.autoBattleButtonRect = nil

-- Tier颜色（统一标准：颜色只表示武器等级）
HUD.TierColors = {
    [1] = {r = 180, g = 180, b = 180},  -- T1 标准型 - 灰白
    [2] = {r = 100, g = 220, b = 100},  -- T2 改良型 - 绿色
    [3] = {r = 80, g = 160, b = 255},   -- T3 精英型 - 蓝色
    [4] = {r = 180, g = 100, b = 255},  -- T4 旗舰型 - 紫色
}



-- ============================================================================
-- 响应式布局辅助函数
-- ============================================================================

local function IsPortrait(sw, sh)
    return sh >= sw
end

-- 🔴 性能优化：使用帧缓存，同一帧内只计算一次
local function GetHUDLayout(sw, sh, baseUnit)
    -- 确保是整数，避免 string.format %d 报错
    local swInt, shInt = math.floor(sw), math.floor(sh)
    local cacheKey = string.format("hud_layout_%d_%d_%d", swInt, shInt, math.floor(baseUnit * 100))
    
    return FrameCache:Get(cacheKey, function()
        local isPortrait = IsPortrait(sw, sh)
        
        if isPortrait then
            -- 竖屏：更宽的面板，更大的字体
            return {
                isPortrait = true,
                fontScale = 1.5,
                -- 护盾条（缩短为原来的 2/3）
                shieldPanelW = sw * 0.58 * 2 / 3,
                shieldPanelH = baseUnit * 3.0,
                -- 武器列表
                weaponPanelW = sw * 0.40,
                weaponPanelX = sw * 0.58,
            }
        else
            -- 横屏：原布局
            return {
                isPortrait = false,
                fontScale = 1.0,
                -- 护盾条（缩短为原来的 2/3）
                shieldPanelW = sw * 0.3 * 2 / 3,
                shieldPanelH = baseUnit * 2.0,
                -- 武器列表
                weaponPanelW = sw * 0.2,
                weaponPanelX = sw * 0.78,
            }
        end
    end)
end

-- ============================================================================
-- 渲染HUD
-- ============================================================================

-- 暂停按钮区域缓存
HUD.pauseButtonRect = nil

function HUD.Render(nvg, sw, sh, baseUnit, fontSize, player, battle, bridgeUpgrade)
    HUD.animTime = HUD.animTime + 0.016
    
    local layout = GetHUDLayout(sw, sh, baseUnit)
    
    -- 左上角：护盾条 → 升级进度条 → 晶体+波次
    HUD.RenderLeftPanel(nvg, sw, sh, baseUnit, fontSize, player, battle, layout)
    
    -- 右上角：功能按钮组（查看武器、自动战斗、暂停）
    HUD.RenderTopRightButtons(nvg, sw, sh, baseUnit, layout)
    
    -- 右上角：武器列表（根据开关显示，位置在按钮下方）
    if HUD.showWeaponList then
        HUD.RenderWeaponList(nvg, sw, sh, baseUnit, fontSize, player, layout)
    end
    
    -- 中上方：波次倒计时
    HUD.RenderWaveTimer(nvg, sw, sh, baseUnit, fontSize, battle, layout)
    
    -- 自动战斗状态提示
    if HUD.autoBattleEnabled then
        HUD.RenderAutoBattleIndicator(nvg, sw, sh, baseUnit, layout)
    end
end

-- ============================================================================
-- 左侧面板：护盾条 + 升级进度条 + 晶体/波次
-- ============================================================================

function HUD.RenderLeftPanel(nvg, sw, sh, baseUnit, fontSize, player, battle, layout)
    local fontScale = layout.fontScale
    local panelX = sw * 0.02
    local panelY = sh * 0.02
    local panelW = layout.shieldPanelW
    local panelH = layout.shieldPanelH
    
    -- ========== 1. 护盾条 ==========
    UIStyle.DrawSciFiPanel(nvg, panelX, panelY, panelW, panelH, {
        baseUnit = baseUnit,
        animTime = HUD.animTime,
        borderColor = {r = 60, g = 180, b = 255},
        bgAlpha = 200,
    })
    
    local barX = panelX + baseUnit * 0.4
    local barY = panelY + baseUnit * 0.4
    local barW = panelW - baseUnit * 0.8
    local barH = baseUnit * 1.0 * fontScale
    
    local shieldRatio = player.shield / player.maxShield
    UIStyle.DrawSciFiProgressBar(nvg, barX, barY, barW, barH, shieldRatio, {
        baseUnit = baseUnit,
        barColor = {r = 60, g = 180, b = 255},
        showText = string.format("🛡 %d / %d", math.floor(player.shield), player.maxShield),
        animTime = HUD.animTime,
        fontSize = UIStyle.FontSize(baseUnit, 1.1 * fontScale, 16),
    })
    
    -- ========== 2. 升级进度条（护盾条下方）==========
    local upgradeY = panelY + panelH + baseUnit * 0.3
    local upgradeH = baseUnit * 1.0 * fontScale
    
    UIStyle.DrawSciFiPanel(nvg, panelX, upgradeY, panelW, upgradeH + baseUnit * 0.8, {
        baseUnit = baseUnit,
        animTime = HUD.animTime,
        borderColor = {r = 160, g = 100, b = 255},
        bgAlpha = 180,
        cornerSize = 0.3,
    })
    
    local nextUpgradeXp = player.nextUpgradeXp or 50
    local totalXp = player.totalXp or 0
    local upgradeProgress = math.min(1, totalXp / nextUpgradeXp)
    
    -- 显示预计等级（当前等级 + 待处理升级次数）
    local pendingUpgrades = player.pendingUpgrades or 0
    local displayLevel = player.bridgeLevel + pendingUpgrades
    local levelText = pendingUpgrades > 0 
        and string.format("Lv.%d→%d ✨%d/%d", player.bridgeLevel, displayLevel, totalXp, nextUpgradeXp)
        or string.format("Lv.%d ✨%d/%d", player.bridgeLevel, totalXp, nextUpgradeXp)
    
    -- 有待升级时进度条变色提示
    local barColor = pendingUpgrades > 0 
        and {r = 255, g = 200, b = 80}  -- 金色：有待升级
        or {r = 160, g = 100, b = 255}  -- 紫色：正常
    
    UIStyle.DrawSciFiProgressBar(nvg, barX, upgradeY + baseUnit * 0.4, barW, upgradeH, upgradeProgress, {
        baseUnit = baseUnit,
        barColor = barColor,
        showText = levelText,
        animTime = HUD.animTime,
        fontSize = UIStyle.FontSize(baseUnit, 1.0 * fontScale, 16),
    })
    
    -- ========== 3. 晶体 + 波次（进度条下方）==========
    local infoY = upgradeY + upgradeH + baseUnit * 1.1
    local infoFontSize = UIStyle.FontSize(baseUnit, 1.2 * fontScale, 16)
    
    -- 晶体显示（左侧）
    nvgFontSize(nvg, infoFontSize)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(100, 180, 255, 255))
    nvgText(nvg, panelX, infoY, string.format("💎 %d", player.crystals))
    
    -- 波次显示（晶体右侧）
    nvgFillColor(nvg, nvgRGBA(255, 200, 80, 255))
    nvgText(nvg, panelX + panelW * 0.5, infoY, 
        string.format("🌊 %d/%d", battle.currentWave, Waves.GetTotalWaves()))
end

-- ============================================================================
-- 武器列表
-- ============================================================================

function HUD.RenderWeaponList(nvg, sw, sh, baseUnit, fontSize, player, layout)
    local fontScale = layout.fontScale
    local panelW = layout.weaponPanelW
    local panelX = layout.weaponPanelX
    -- 武器列表位置在按钮下方，避免重叠
    local btnSize = baseUnit * 2.0 * fontScale
    local panelY = baseUnit * 0.5 + btnSize + baseUnit * 0.5
    local weaponCount = #player.weapons
    -- 🔴 行高必须基于字体大小，避免文字重叠
    local weaponFontSize = UIStyle.FontSize(baseUnit, 1.1 * fontScale, 16)
    local lineHeight = weaponFontSize * 1.3  -- 紧凑行距
    local titleHeight = baseUnit * 1.2 * fontScale  -- 标题区域高度
    local panelH = titleHeight + weaponCount * lineHeight + baseUnit * 0.4
    
    -- 科技风格面板
    UIStyle.DrawSciFiPanel(nvg, panelX, panelY, panelW, panelH, {
        baseUnit = baseUnit,
        animTime = HUD.animTime,
        borderColor = {r = 255, g = 180, b = 60},
        bgAlpha = 180,
    })
    
    -- 标题
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.1 * fontScale, 16))  -- 🔴 增大：0.65 → 1.1
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(140, 150, 160, 200))
    nvgText(nvg, panelX + panelW / 2, panelY + baseUnit * 0.3, "装备武器")
    
    -- 分隔线（基于标题区域高度）
    local separatorY = panelY + titleHeight
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, panelX + baseUnit * 0.4, separatorY)
    nvgLineTo(nvg, panelX + panelW - baseUnit * 0.4, separatorY)
    nvgStrokeColor(nvg, nvgRGBA(255, 180, 60, 60))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- 武器列表（基于字体相对行高）
    local listStartY = separatorY + baseUnit * 0.2
    
    for i, weapon in ipairs(player.weapons) do
        local def = Weapons.Get(weapon.id)
        if def then
            local y = listStartY + (i - 1) * lineHeight
            local tier = weapon.tier or 1
            local tierColor = HUD.TierColors[tier] or HUD.TierColors[1]
            
            -- Tier颜色指示条
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, panelX + baseUnit * 0.3, y, baseUnit * 0.18 * fontScale, baseUnit * 0.7 * fontScale, baseUnit * 0.05)
            nvgFillColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 255))
            nvgFill(nvg)
            
            -- 武器名称（使用Tier颜色）
            nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.1 * fontScale, 16))
            nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 255))
            nvgText(nvg, panelX + baseUnit * 0.7, y, def.name)
            
            -- Tier标签（右侧）
            nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
            nvgFillColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 255))
            nvgText(nvg, panelX + panelW - baseUnit * 0.3, y, "T" .. tier)
        end
    end
end

-- ============================================================================
-- 波次倒计时（中上方）
-- ============================================================================

function HUD.RenderWaveTimer(nvg, sw, sh, baseUnit, fontSize, battle, layout)
    local fontScale = layout.fontScale
    
    local waveDuration = Waves.GetDuration(battle.currentWave)
    local timeLeft = math.max(0, waveDuration - battle.waveTimer)
    
    -- 倒计时颜色（小于10秒变红）
    local timeColor = timeLeft < 10 and {r = 255, g = 80, b = 80} or {r = 255, g = 255, b = 255}
    
    -- 时间数字（大字）
    local baseFontSize = UIStyle.FontSize(baseUnit, 2.5 * fontScale, 28)
    local timeFontSize = baseFontSize
    
    -- 最后10秒跳动效果：每秒跳动一次，时间越少幅度越大
    if timeLeft < 10 then
        -- 取小数部分：刚变化时为1，逐渐减小到0
        local fraction = timeLeft - math.floor(timeLeft)
        -- 跳动曲线：刚变数字时最大，快速衰减
        local pulse = fraction * fraction  -- 平方衰减，开始时1，快速降到0
        -- 跳动幅度：时间越少，跳动越大（10秒+20%，0秒+100%）
        local maxScale = 0.2 + (10 - timeLeft) / 10 * 0.8
        timeFontSize = baseFontSize * (1.0 + pulse * maxScale)
    end
    
    nvgFontSize(nvg, timeFontSize)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    
    local timerY = sh * 0.02
    
    -- 发光效果（时间紧迫时更明显）
    if timeLeft < 10 then
        local glowAlpha = 80 + 40 * math.sin(HUD.animTime * 6)
        nvgFillColor(nvg, nvgRGBA(timeColor.r, timeColor.g, timeColor.b, glowAlpha))
        nvgText(nvg, sw / 2 - 1, timerY, string.format("%d", math.floor(timeLeft)))
        nvgText(nvg, sw / 2 + 1, timerY, string.format("%d", math.floor(timeLeft)))
    end
    
    -- 主文字
    nvgFillColor(nvg, nvgRGBA(timeColor.r, timeColor.g, timeColor.b, 255))
    nvgText(nvg, sw / 2, timerY, string.format("%d", math.floor(timeLeft)))
    
    -- 小标签"剩余时间"
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.9 * fontScale, 12))
    nvgFillColor(nvg, nvgRGBA(150, 160, 180, 180))
    nvgText(nvg, sw / 2, timerY + baseFontSize + baseUnit * 0.1, "剩余时间")
end

-- ============================================================================
-- 右上角功能按钮组
-- ============================================================================

function HUD.RenderTopRightButtons(nvg, sw, sh, baseUnit, layout)
    local fontScale = layout.fontScale
    local btnSize = baseUnit * 2.0 * fontScale
    local btnGap = baseUnit * 0.4
    local btnY = baseUnit * 0.5
    local radius = baseUnit * 0.3
    
    -- 从右到左排列：暂停 | 自动战斗 | 查看武器
    local pauseBtnX = sw - btnSize - baseUnit * 0.5
    local autoBtnX = pauseBtnX - btnSize - btnGap
    local weaponBtnX = autoBtnX - btnSize - btnGap
    
    -- 获取鼠标位置用于检测按下状态
    local mx, my = TouchInput.x, TouchInput.y
    
    -- ========== 1. 查看武器按钮 ==========
    local weaponBtnActive = HUD.showWeaponList
    local weaponPressed = UIScreen.ShouldShowPressed(mx, my, "hud_weapon_list")
    HUD.RenderHUDButton(nvg, weaponBtnX, btnY, btnSize, radius, weaponBtnActive, 
        {r = 255, g = 180, b = 60}, function(cx, cy, iconSize)
        -- 武器列表图标（三条横线）
        local barH = iconSize * 0.15
        local gap = iconSize * 0.25
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - iconSize / 2, cy - gap - barH / 2, iconSize, barH, 2)
        nvgRoundedRect(nvg, cx - iconSize / 2, cy - barH / 2, iconSize, barH, 2)
        nvgRoundedRect(nvg, cx - iconSize / 2, cy + gap - barH / 2, iconSize, barH, 2)
        nvgFillColor(nvg, nvgRGBA(255, 200, 100, weaponBtnActive and 255 or 150))
        nvgFill(nvg)
    end, weaponPressed)
    HUD.weaponListButtonRect = {x = weaponBtnX, y = btnY, w = btnSize, h = btnSize}
    
    -- ========== 2. 自动战斗按钮 ==========
    local autoBtnActive = HUD.autoBattleEnabled
    local autoPressed = UIScreen.ShouldShowPressed(mx, my, "hud_auto_battle")
    HUD.RenderHUDButton(nvg, autoBtnX, btnY, btnSize, radius, autoBtnActive,
        {r = 100, g = 220, b = 100}, function(cx, cy, iconSize)
        -- 自动战斗图标（循环箭头/A字）
        nvgFontSize(nvg, iconSize * 1.2)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(100, 220, 100, autoBtnActive and 255 or 150))
        nvgText(nvg, cx, cy, "A")
    end, autoPressed)
    HUD.autoBattleButtonRect = {x = autoBtnX, y = btnY, w = btnSize, h = btnSize}
    
    -- ========== 3. 暂停按钮 ==========
    local pausePressed = UIScreen.ShouldShowPressed(mx, my, "hud_pause")
    HUD.RenderHUDButton(nvg, pauseBtnX, btnY, btnSize, radius, false,
        {r = 100, g = 150, b = 200}, function(cx, cy, iconSize)
        -- 暂停图标（两条竖线）
        local barW = iconSize * 0.25
        local gap = iconSize * 0.15
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - gap - barW, cy - iconSize / 2, barW, iconSize, 2)
        nvgRoundedRect(nvg, cx + gap, cy - iconSize / 2, barW, iconSize, 2)
        nvgFillColor(nvg, nvgRGBA(200, 220, 255, 255))
        nvgFill(nvg)
    end, pausePressed)
    HUD.pauseButtonRect = {x = pauseBtnX, y = btnY, w = btnSize, h = btnSize}
end

-- 绘制单个HUD按钮
-- @param pressed boolean 是否处于按下状态
function HUD.RenderHUDButton(nvg, x, y, size, radius, active, accentColor, drawIcon, pressed)
    -- 按下状态的视觉调整
    local offsetY = pressed and 2 or 0
    local bgAlpha = pressed and 255 or 200
    local scale = pressed and 0.95 or 1.0
    
    -- 按钮背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y + offsetY, size, size, radius)
    if pressed then
        -- 按下状态：更深的背景
        nvgFillColor(nvg, nvgRGBA(15, 25, 40, bgAlpha))
    elseif active then
        -- 激活状态：使用强调色背景
        nvgFillColor(nvg, nvgRGBA(accentColor.r, accentColor.g, accentColor.b, 60))
    else
        nvgFillColor(nvg, nvgRGBA(30, 40, 60, bgAlpha))
    end
    nvgFill(nvg)
    
    -- 边框
    if pressed then
        nvgStrokeColor(nvg, nvgRGBA(accentColor.r, accentColor.g, accentColor.b, 255))
        nvgStrokeWidth(nvg, 2.5)
    elseif active then
        nvgStrokeColor(nvg, nvgRGBA(accentColor.r, accentColor.g, accentColor.b, 200))
        nvgStrokeWidth(nvg, 2)
    else
        nvgStrokeColor(nvg, nvgRGBA(100, 150, 200, 150))
        nvgStrokeWidth(nvg, 1.5)
    end
    nvgStroke(nvg)
    
    -- 绘制图标（按下时略微下移和缩小）
    local cx = x + size / 2
    local cy = y + size / 2 + offsetY
    local iconSize = size * 0.4 * scale
    drawIcon(cx, cy, iconSize)
end

-- ============================================================================
-- 按钮点击检测
-- ============================================================================

-- 检测暂停按钮点击
function HUD.CheckPauseButtonClick(mx, my)
    if not HUD.pauseButtonRect then return false end
    local r = HUD.pauseButtonRect
    return UIScreen.HitTest(mx, my, r.x, r.y, r.w, r.h)
end

-- 检测查看武器按钮点击
function HUD.CheckWeaponListButtonClick(mx, my)
    if not HUD.weaponListButtonRect then return false end
    local r = HUD.weaponListButtonRect
    return UIScreen.HitTest(mx, my, r.x, r.y, r.w, r.h)
end

-- 检测自动战斗按钮点击
function HUD.CheckAutoBattleButtonClick(mx, my)
    if not HUD.autoBattleButtonRect then return false end
    local r = HUD.autoBattleButtonRect
    return UIScreen.HitTest(mx, my, r.x, r.y, r.w, r.h)
end

-- 切换武器列表显示（并保存到云存档）
function HUD.ToggleWeaponList()
    HUD.showWeaponList = not HUD.showWeaponList
    
    -- 保存到用户设置（云存档）
    UserSettings.Set("hudWeaponListExpanded", HUD.showWeaponList)
    UserSettings.Save()
    
    print("[HUD] Weapon list toggled: " .. (HUD.showWeaponList and "expanded" or "collapsed"))
end

-- 渲染自动战斗状态提示
function HUD.RenderAutoBattleIndicator(nvg, sw, sh, baseUnit, layout)
    local fontScale = layout.fontScale
    local text = "自动战斗中"
    local fontSize = UIStyle.FontSize(baseUnit, 1.2 * fontScale, 14)
    
    -- 位置：屏幕中央偏上
    local x = sw / 2
    local y = sh * 0.12
    
    -- 呼吸动画
    local alpha = 180 + 50 * math.sin(HUD.animTime * 2)
    
    -- 绘制文字
    nvgFontSize(nvg, fontSize)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(100, 200, 255, math.floor(alpha)))
    nvgText(nvg, x, y, text)
end

-- 切换自动战斗
function HUD.ToggleAutoBattle()
    HUD.autoBattleEnabled = not HUD.autoBattleEnabled
end

-- 获取自动战斗状态
function HUD.IsAutoBattleEnabled()
    return HUD.autoBattleEnabled
end

return HUD
