-- ============================================================================
-- 星河战姬 Starkyries - 商店卡片渲染模块
-- 负责商品卡片和详情弹窗的渲染
-- ============================================================================

local UIStyle = require("ui.UIStyle")
local Weapons = require("config.weapons")
local TagSetBonuses = require("data.TagSetBonuses")
local TouchInput = require("utils.TouchInput")

local ShopCards = {}

-- 品质颜色
ShopCards.TierColors = {
    [1] = {r = 180, g = 180, b = 180},  -- T1 标准型 - 灰白
    [2] = {r = 100, g = 220, b = 100},  -- T2 改良型 - 绿色
    [3] = {r = 80, g = 160, b = 255},   -- T3 精英型 - 蓝色
    [4] = {r = 180, g = 100, b = 255},  -- T4 旗舰型 - 紫色
}

ShopCards.TierNames = {
    [1] = "标准型",
    [2] = "改良型", 
    [3] = "精英型",
    [4] = "旗舰型",
}

-- 图片缓存
ShopCards.weaponImages = {}
ShopCards.moduleImages = {}

-- 详情弹窗滚动状态
ShopCards.detailScrollOffset = 0
ShopCards.detailMaxScrollOffset = 0
ShopCards.isDetailDragging = false
ShopCards.detailDragStartY = 0
ShopCards.detailDragStartScroll = 0

-- 重置详情弹窗滚动
function ShopCards.ResetDetailScroll()
    ShopCards.detailScrollOffset = 0
    ShopCards.detailMaxScrollOffset = 0
    ShopCards.isDetailDragging = false
end

-- 处理详情弹窗滚动输入
function ShopCards.HandleDetailScroll(mx, my, scrollAreaY, scrollAreaH, baseUnit)
    -- 鼠标滚轮
    local wheel = input:GetMouseMoveWheel()
    if wheel ~= 0 then
        local scrollAmount = baseUnit * 4
        ShopCards.detailScrollOffset = ShopCards.detailScrollOffset + wheel * scrollAmount
        ShopCards.detailScrollOffset = math.max(-ShopCards.detailMaxScrollOffset, math.min(0, ShopCards.detailScrollOffset))
        return true
    end
    
    -- 拖拽滚动
    local inScrollArea = my >= scrollAreaY and my <= scrollAreaY + scrollAreaH
    
    if input:GetMouseButtonDown(MOUSEB_LEFT) and ShopCards.isDetailDragging then
        local dy = my - ShopCards.detailDragStartY
        if math.abs(dy) > baseUnit * 0.2 then
            ShopCards.detailScrollOffset = ShopCards.detailDragStartScroll + dy
            ShopCards.detailScrollOffset = math.max(-ShopCards.detailMaxScrollOffset, math.min(0, ShopCards.detailScrollOffset))
        end
    end
    
    if not input:GetMouseButtonDown(MOUSEB_LEFT) then
        ShopCards.isDetailDragging = false
    end
    
    if input:GetMouseButtonPress(MOUSEB_LEFT) and inScrollArea then
        ShopCards.isDetailDragging = true
        ShopCards.detailDragStartY = my
        ShopCards.detailDragStartScroll = ShopCards.detailScrollOffset
    end
    
    return false
end

-- ============================================================================
-- UTF-8 文本处理工具
-- ============================================================================

-- UTF-8 字符串长度（字符数而非字节数）
function ShopCards.Utf8Len(str)
    local len = 0
    local i = 1
    while i <= #str do
        local byte = str:byte(i)
        if byte < 128 then
            i = i + 1
        elseif byte < 224 then
            i = i + 2
        elseif byte < 240 then
            i = i + 3
        else
            i = i + 4
        end
        len = len + 1
    end
    return len
end

-- UTF-8 子字符串（按字符数截取）
function ShopCards.Utf8Sub(str, startChar, endChar)
    local result = {}
    local charIndex = 0
    local i = 1
    while i <= #str do
        local byte = str:byte(i)
        local charLen = 1
        if byte >= 128 then
            if byte < 224 then charLen = 2
            elseif byte < 240 then charLen = 3
            else charLen = 4
            end
        end
        
        charIndex = charIndex + 1
        if charIndex >= startChar and charIndex <= endChar then
            table.insert(result, str:sub(i, i + charLen - 1))
        end
        if charIndex > endChar then break end
        
        i = i + charLen
    end
    return table.concat(result)
end

function ShopCards.WrapText(text, maxChars)
    local lines = {}
    local remaining = text or ""
    
    while ShopCards.Utf8Len(remaining) > 0 do
        local len = ShopCards.Utf8Len(remaining)
        if len <= maxChars then
            table.insert(lines, remaining)
            break
        end
        
        -- 寻找断点（逗号、空格等）
        local breakPoint = maxChars
        for i = maxChars, 1, -1 do
            local c = ShopCards.Utf8Sub(remaining, i, i)
            if c == "，" or c == "," or c == " " or c == "、" or c == "。" then
                breakPoint = i
                break
            end
        end
        
        table.insert(lines, ShopCards.Utf8Sub(remaining, 1, breakPoint))
        remaining = ShopCards.Utf8Sub(remaining, breakPoint + 1, ShopCards.Utf8Len(remaining))
        
        if #lines >= 4 then break end
    end
    
    return lines
end

-- 估算文字宽度（基于字符类型）
function ShopCards.EstimateTextWidth(text, fontSize)
    local width = 0
    local i = 1
    while i <= #text do
        local byte = text:byte(i)
        if byte < 128 then
            width = width + fontSize * 0.55
            i = i + 1
        elseif byte < 224 then
            width = width + fontSize * 0.9
            i = i + 2
        elseif byte < 240 then
            width = width + fontSize
            i = i + 3
        else
            width = width + fontSize * 1.2
            i = i + 4
        end
    end
    return width
end

-- 根据像素宽度动态换行
function ShopCards.WrapTextByWidth(nvg, text, maxWidth, fontSize)
    local lines = {}
    local remaining = text or ""
    fontSize = fontSize or 14
    
    while ShopCards.Utf8Len(remaining) > 0 do
        local textWidth = ShopCards.EstimateTextWidth(remaining, fontSize)
        
        if textWidth <= maxWidth then
            table.insert(lines, remaining)
            break
        end
        
        local len = ShopCards.Utf8Len(remaining)
        local avgCharWidth = textWidth / len
        local estimatedChars = math.floor(maxWidth / avgCharWidth)
        estimatedChars = math.max(1, math.min(estimatedChars, len))
        
        local bestBreak = estimatedChars
        local testStr = ShopCards.Utf8Sub(remaining, 1, bestBreak)
        local testWidth = ShopCards.EstimateTextWidth(testStr, fontSize)
        
        while testWidth > maxWidth and bestBreak > 1 do
            bestBreak = bestBreak - 1
            testStr = ShopCards.Utf8Sub(remaining, 1, bestBreak)
            testWidth = ShopCards.EstimateTextWidth(testStr, fontSize)
        end
        
        local breakPoint = bestBreak
        for i = bestBreak, math.max(1, bestBreak - 5), -1 do
            local c = ShopCards.Utf8Sub(remaining, i, i)
            if c == "，" or c == "," or c == " " or c == "、" or c == "。" or c == "：" or c == "；" then
                breakPoint = i
                break
            end
        end
        
        table.insert(lines, ShopCards.Utf8Sub(remaining, 1, breakPoint))
        remaining = ShopCards.Utf8Sub(remaining, breakPoint + 1, ShopCards.Utf8Len(remaining))
        
        if #lines >= 4 then break end
    end
    
    return lines
end

-- ============================================================================
-- 商品卡片渲染
-- ============================================================================

function ShopCards.RenderItemCard(nvg, x, y, w, h, item, isSelected, canAfford, baseUnit, player, isPortrait, fonts, animTime, isPressed)
    fonts = fonts or UIStyle.GetTypography(w * 2, isPortrait and w * 3 or h * 2)
    animTime = animTime or 0
    isPressed = isPressed or false
    
    -- 按下时的偏移
    local pressOffset = isPressed and 2 or 0
    y = y + pressOffset
    
    -- 确定主题颜色
    local themeColor
    if item.type == "weapon" then
        local tier = item.tier or 1
        themeColor = ShopCards.TierColors[tier] or ShopCards.TierColors[1]
    else
        themeColor = {r = 60, g = 180, b = 255}
    end
    
    -- 按下时颜色变暗
    local colorMult = isPressed and 0.7 or 1.0
    local alphaMult = isPressed and 0.8 or 1.0
    
    -- 选中时外发光（按下时不显示发光）
    if isSelected and not isPressed then
        local glowAlpha = 0.3 + 0.15 * math.sin(animTime * 3)
        for i = 3, 1, -1 do
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, x - i * 2, y - i * 2, w + i * 4, h + i * 4, baseUnit * 0.3 + i)
            nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, glowAlpha * 255 / i))
            nvgFill(nvg)
        end
    end
    
    -- 卡片背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.3)
    local bgAlpha = isPressed and 255 or (isSelected and 255 or 220)
    nvgFillColor(nvg, nvgRGBA(math.floor(18 * colorMult), math.floor(25 * colorMult), math.floor(40 * colorMult), bgAlpha))
    nvgFill(nvg)
    
    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.3)
    nvgStrokeColor(nvg, nvgRGBA(themeColor.r * colorMult, themeColor.g * colorMult, themeColor.b * colorMult, (isSelected or isPressed) and 255 or 80))
    nvgStrokeWidth(nvg, (isSelected or isPressed) and 2 or 1)
    nvgStroke(nvg)
    
    local py = y + h * 0.03
    local centerX = x + w / 2
    local leftX = x + w * 0.06
    local rightX = x + w * 0.94
    
    -- 图标区域（与武器选择界面一致的大小）
    local iconSize = baseUnit * 4.5
    local iconX = centerX - iconSize / 2
    local iconY = py
    local hasIcon = false
    
    -- 尝试加载图片
    if item.type == "weapon" and item.weaponData then
        local weaponId = item.weaponData.id
        local iconPath = "images/weapons/" .. weaponId .. ".jpg"
        
        if not ShopCards.weaponImages[weaponId] then
            local img = nvgCreateImage(nvg, iconPath, 0)
            if img > 0 then
                ShopCards.weaponImages[weaponId] = img
            else
                ShopCards.weaponImages[weaponId] = -1
            end
        end
        
        local img = ShopCards.weaponImages[weaponId]
        if img and img > 0 then
            hasIcon = true
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.25)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 80))
            nvgFill(nvg)
            
            local imgPaint = nvgImagePattern(nvg, iconX, iconY, iconSize, iconSize, 0, img, 1.0)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.25)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)
            
            -- 品质边框
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.25)
            nvgStrokeColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 220))
            nvgStrokeWidth(nvg, 2.5)
            nvgStroke(nvg)
        end
    elseif item.type == "module" then
        local moduleId = item.moduleId or item.id
        local iconPath = "images/modules/" .. moduleId .. ".jpg"
        
        if not ShopCards.moduleImages[moduleId] then
            local img = nvgCreateImage(nvg, iconPath, 0)
            if img > 0 then
                ShopCards.moduleImages[moduleId] = img
            else
                ShopCards.moduleImages[moduleId] = -1
            end
        end
        
        local img = ShopCards.moduleImages[moduleId]
        if img and img > 0 then
            hasIcon = true
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.25)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 80))
            nvgFill(nvg)
            
            local imgPaint = nvgImagePattern(nvg, iconX, iconY, iconSize, iconSize, 0, img, 1.0)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.25)
            nvgFillPaint(nvg, imgPaint)
            nvgFill(nvg)
            
            -- 模块品质边框
            local moduleTier = item.tier or (item.moduleData and item.moduleData.tier) or 1
            local moduleTierColor = ShopCards.TierColors[moduleTier] or ShopCards.TierColors[1]
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.25)
            nvgStrokeColor(nvg, nvgRGBA(moduleTierColor.r, moduleTierColor.g, moduleTierColor.b, 220))
            nvgStrokeWidth(nvg, 2.5)
            nvgStroke(nvg)
        end
    end
    
    -- 没有图片时显示渐变色块
    if not hasIcon then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.25)
        local iconGrad = nvgLinearGradient(nvg, centerX, py, centerX, py + iconSize,
            nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 200),
            nvgRGBA(themeColor.r * 0.5, themeColor.g * 0.5, themeColor.b * 0.5, 200))
        nvgFillPaint(nvg, iconGrad)
        nvgFill(nvg)
    end
    py = py + iconSize + h * 0.02
    
    -- 名称
    nvgFontSize(nvg, fonts.cardTitle)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, isSelected and 255 or 200))
    nvgText(nvg, centerX, py, item.name or "???")
    py = py + fonts.cardTitle * 0.85
    
    -- 品质/类型标签
    if item.type == "weapon" then
        local tier = item.tier or 1
        local tierName = ShopCards.TierNames[tier] or "T" .. tier
        nvgFontSize(nvg, fonts.cardSubtitle)
        nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 200))
        nvgText(nvg, centerX, py, tierName)
    else
        nvgFontSize(nvg, fonts.cardSubtitle)
        nvgFillColor(nvg, nvgRGBA(100, 180, 255, 200))
        nvgText(nvg, centerX, py, "模块")
    end
    py = py + fonts.cardSubtitle * 0.85
    
    -- 分隔线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, leftX, py)
    nvgLineTo(nvg, rightX, py)
    nvgStrokeColor(nvg, nvgRGBA(50, 60, 80, 100))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    py = py + h * 0.02
    
    -- 详细属性
    nvgFontSize(nvg, fonts.statValue)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local statLineHeight = fonts.statValue * 1.35
    local contentWidth = rightX - leftX
    
    -- 计算底部区域位置，用于边界检查
    local bottomY = y + h - h * 0.1
    local maxContentY = bottomY - baseUnit * 0.5  -- 留出安全边距
    
    if item.type == "weapon" and item.weaponData then
        local weapon = item.weaponData
        local tier = item.tier or 1
        local tierMult = ({1.0, 1.25, 1.5, 1.75})[tier] or 1.0
        
        local weaponStatSize = fonts.statValue * 0.72
        nvgFontSize(nvg, weaponStatSize)
        statLineHeight = weaponStatSize * 1.3
        
        -- 伤害
        if py + statLineHeight <= maxContentY then
            local dmg
            if weapon.tierDamage and weapon.tierDamage[tier] then
                dmg = weapon.tierDamage[tier]
            else
                dmg = (weapon.damage or 10) * tierMult
            end
            local dmgText = dmg == math.floor(dmg) and tostring(math.floor(dmg)) or string.format("%.1f", dmg)
            nvgFillColor(nvg, nvgRGBA(255, 100, 100, 255))
            nvgText(nvg, leftX, py, "伤害: " .. dmgText)
            py = py + statLineHeight
        end
        
        -- 攻速（优先使用tierCooldown）
        if py + statLineHeight <= maxContentY then
            local cooldown = weapon.cooldown or 1.0
            if weapon.tierCooldown and weapon.tierCooldown[tier] then
                cooldown = weapon.tierCooldown[tier]
            end
            local attackSpeed = string.format("%.1f", 1.0 / cooldown)
            nvgFillColor(nvg, nvgRGBA(100, 200, 255, 255))
            nvgText(nvg, leftX, py, "攻速: " .. attackSpeed .. "/s")
            py = py + statLineHeight
        end
        
        -- 射程（优先使用tierRange）
        if py + statLineHeight <= maxContentY then
            local rangeVal = weapon.range or 20
            if weapon.tierRange and weapon.tierRange[tier] then
                rangeVal = weapon.tierRange[tier]
            end
            local rangeText = Weapons.GetRangeDescription(rangeVal)
            nvgFillColor(nvg, nvgRGBA(100, 255, 150, 255))
            nvgText(nvg, leftX, py, "射程: " .. rangeText)
            py = py + statLineHeight
        end
        
        -- 武器标签
        if weapon.tags and #weapon.tags > 0 and py + statLineHeight <= maxContentY then
            local tagSize = fonts.tagText * 0.8
            nvgFontSize(nvg, tagSize)
            nvgFillColor(nvg, nvgRGBA(180, 150, 255, 200))
            local tagsText = "标签: " .. table.concat(weapon.tags, " · ")
            local tagLines = ShopCards.WrapTextByWidth(nvg, tagsText, contentWidth, tagSize)
            local tagLineHeight = tagSize * 1.25
            for _, line in ipairs(tagLines) do
                if py + tagLineHeight <= maxContentY then
                    nvgText(nvg, leftX, py, line)
                    py = py + tagLineHeight
                end
            end
        end
        
        -- 特殊效果
        local tagSize = fonts.tagText * 0.9
        nvgFontSize(nvg, tagSize)
        local tagLineHeight = tagSize * 1.3
        if weapon.homing and py + tagLineHeight <= maxContentY then
            nvgFillColor(nvg, nvgRGBA(255, 200, 100, 255))
            nvgText(nvg, leftX, py, "✦ 追踪")
            py = py + tagLineHeight
        end
        if weapon.piercing and py + tagLineHeight <= maxContentY then
            nvgFillColor(nvg, nvgRGBA(200, 100, 255, 255))
            nvgText(nvg, leftX, py, "✦ 穿透")
            py = py + tagLineHeight
        end
        if weapon.aoe and py + tagLineHeight <= maxContentY then
            nvgFillColor(nvg, nvgRGBA(255, 150, 100, 255))
            nvgText(nvg, leftX, py, "✦ 范围伤害")
            py = py + tagLineHeight
        end
        
        if item.canMerge and py + tagLineHeight <= maxContentY then
            nvgFillColor(nvg, nvgRGBA(255, 220, 100, 255))
            nvgText(nvg, leftX, py, "⬆ 可升级")
            py = py + tagLineHeight
        end
    else
        -- 模块描述
        local descSize = fonts.description * 0.9
        nvgFontSize(nvg, descSize)
        local descLineHeight = descSize * 1.3
        local desc = item.description or ""
        
        -- 按逗号分隔每条效果
        local normalizedDesc = desc:gsub("，", ","):gsub("、", ",")
        local effects = {}
        for effect in string.gmatch(normalizedDesc, "[^,]+") do
            local trimmed = effect:match("^%s*(.-)%s*$")
            if trimmed and #trimmed > 0 then
                table.insert(effects, trimmed)
            end
        end
        
        for _, effect in ipairs(effects) do
            if py + descLineHeight > maxContentY then break end
            
            -- 确定颜色
            local color = {150, 160, 180, 200}
            if effect:find("%+") then
                color = {100, 220, 150, 255}
            elseif effect:find("%-") then
                color = {255, 150, 100, 255}
            end
            nvgFillColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4]))
            
            -- 使用折行显示超长文字
            local effectLines = ShopCards.WrapTextByWidth(nvg, effect, contentWidth, descSize)
            for _, line in ipairs(effectLines) do
                if py + descLineHeight > maxContentY then break end
                nvgText(nvg, leftX, py, line)
                py = py + descLineHeight
            end
        end
    end
    
    -- 底部：价格和锁定按钮（使用已计算的 bottomY）
    
    -- 价格
    local price = math.floor(item.price or 0)
    local priceColor = canAfford and {r = 100, g = 220, b = 150} or {r = 255, g = 100, b = 100}
    nvgFontSize(nvg, fonts.statValue)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(priceColor.r, priceColor.g, priceColor.b, 255))
    nvgText(nvg, leftX, bottomY, string.format("💎 %d", price))
    
    -- 锁定按钮（放大以便点击）
    local lockBtnSize = baseUnit * 1.8
    local lockBtnX = rightX - lockBtnSize
    local lockBtnY = bottomY - baseUnit * 0.3
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, lockBtnX, lockBtnY, lockBtnSize, lockBtnSize, baseUnit * 0.25)
    if item.locked then
        nvgFillColor(nvg, nvgRGBA(80, 65, 30, 220))
    else
        nvgFillColor(nvg, nvgRGBA(50, 60, 80, 180))
    end
    nvgFill(nvg)
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, lockBtnX, lockBtnY, lockBtnSize, lockBtnSize, baseUnit * 0.25)
    nvgStrokeWidth(nvg, 1.5)
    if item.locked then
        nvgStrokeColor(nvg, nvgRGBA(255, 200, 60, 200))
    else
        nvgStrokeColor(nvg, nvgRGBA(120, 140, 180, 200))
    end
    nvgStroke(nvg)
    
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.95))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if item.locked then
        nvgFillColor(nvg, nvgRGBA(255, 200, 60, 255))
    else
        nvgFillColor(nvg, nvgRGBA(180, 200, 230, 255))
    end
    nvgText(nvg, lockBtnX + lockBtnSize / 2, lockBtnY + lockBtnSize / 2, item.locked and "🔒" or "🔓")
    
    -- 不可购买遮罩
    if not canAfford then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x + 1, y + 1, w - 2, h - 2, baseUnit * 0.3)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 100))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 详情弹窗渲染（带滚动支持）
-- ============================================================================

function ShopCards.RenderDetailPopup(nvg, layout, item, player, uiState, animTime)
    local baseUnit = layout.baseUnit
    local sw, sh = layout.sw, layout.sh
    local isPortrait = layout.isPortrait
    animTime = animTime or 0
    
    -- 半透明遮罩
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
    nvgFill(nvg)
    
    -- 弹窗尺寸（稍微增大）
    local popupW = baseUnit * (isPortrait and 32 or 38)
    local popupH = baseUnit * (isPortrait and 30 or 34)
    local popupX = (sw - popupW) / 2
    local popupY = (sh - popupH) / 2
    
    local displayItem = item
    local isWeapon = (item.type == "weapon") or (item.weaponId ~= nil) or (item.weaponData ~= nil)
    
    if item.id and not item.name then
        local weaponDef = Weapons.Get(item.id)
        if weaponDef then
            displayItem = {
                name = weaponDef.name,
                tier = item.tier or 1,
                type = "weapon",
                weaponData = weaponDef,
                basePrice = weaponDef.basePrice or 25,
            }
            isWeapon = true
        end
    end
    
    local themeColor
    if isWeapon then
        local tier = displayItem.tier or 1
        themeColor = ShopCards.TierColors[tier] or ShopCards.TierColors[1]
    elseif displayItem.type == "module" then
        local moduleTierColors = {
            [1] = {r = 150, g = 150, b = 150},
            [2] = {r = 100, g = 200, b = 100},
            [3] = {r = 100, g = 150, b = 255},
            [4] = {r = 200, g = 100, b = 255},
        }
        local tier = displayItem.tier or 1
        themeColor = moduleTierColors[tier] or moduleTierColors[1]
    else
        themeColor = {r = 60, g = 180, b = 255}
    end
    
    -- 弹窗背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, popupX, popupY, popupW, popupH, baseUnit * 0.6)
    nvgFillColor(nvg, nvgRGBA(20, 25, 35, 250))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 200))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
    
    local padding = baseUnit * 1.2
    local leftX = popupX + padding
    local rightX = popupX + popupW - padding
    local contentW = rightX - leftX
    local centerX = popupX + popupW / 2
    
    -- ========== 头部区域（紧凑横向布局）==========
    local headerY = popupY + padding
    local iconSize = baseUnit * 4.5
    local iconX = leftX
    local iconY = headerY
    local hasIcon = false
    
    -- 加载图标
    if isWeapon then
        local weapon = displayItem.weaponData or displayItem
        local weaponId = weapon.id
        if weaponId then
            local iconPath = "images/weapons/" .. weaponId .. ".jpg"
            if not ShopCards.weaponImages[weaponId] then
                local img = nvgCreateImage(nvg, iconPath, 0)
                ShopCards.weaponImages[weaponId] = (img and img > 0) and img or -1
            end
            local img = ShopCards.weaponImages[weaponId]
            if img and img > 0 then
                hasIcon = true
                local imgPaint = nvgImagePattern(nvg, iconX, iconY, iconSize, iconSize, 0, img, 1.0)
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.3)
                nvgFillPaint(nvg, imgPaint)
                nvgFill(nvg)
                nvgStrokeColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 200))
                nvgStrokeWidth(nvg, 2)
                nvgStroke(nvg)
            end
        end
    elseif displayItem.type == "module" then
        local moduleId = displayItem.moduleId or displayItem.id
        if moduleId then
            local iconPath = "images/modules/" .. moduleId .. ".jpg"
            if not ShopCards.moduleImages[moduleId] then
                local img = nvgCreateImage(nvg, iconPath, 0)
                ShopCards.moduleImages[moduleId] = (img and img > 0) and img or -1
            end
            local img = ShopCards.moduleImages[moduleId]
            if img and img > 0 then
                hasIcon = true
                local imgPaint = nvgImagePattern(nvg, iconX, iconY, iconSize, iconSize, 0, img, 1.0)
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.3)
                nvgFillPaint(nvg, imgPaint)
                nvgFill(nvg)
                nvgStrokeColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 200))
                nvgStrokeWidth(nvg, 2)
                nvgStroke(nvg)
            end
        end
    end
    
    -- 无图标时显示占位
    if not hasIcon then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.3)
        nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 40))
        nvgFill(nvg)
        nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 2.5, 24))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 200))
        nvgText(nvg, iconX + iconSize/2, iconY + iconSize/2, isWeapon and "🔫" or "📦")
    end
    
    -- 名称和品质（图标右侧）
    local textX = iconX + iconSize + baseUnit * 1.0
    local textY = iconY + baseUnit * 0.3
    
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.8, 18))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 255))
    nvgText(nvg, textX, textY, displayItem.name or "???")
    textY = textY + baseUnit * 2.2
    
    -- 品质/类型标签
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.0, 14))
    if isWeapon then
        local tier = displayItem.tier or 1
        local tierName = ShopCards.TierNames[tier] or ("T" .. tier)
        nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 180))
        nvgText(nvg, textX, textY, tierName)
    elseif displayItem.type == "module" and displayItem.moduleDef then
        local moduleTypeNames = {
            fire_control = "🔥 火控", defense = "🛡 防御", engine = "⚡ 引擎",
            resource = "💎 资源", tactical = "🎯 战术", experimental = "🔬 实验", special = "⭐ 特殊",
        }
        local typeName = moduleTypeNames[displayItem.moduleDef.type] or "📦 模块"
        nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 180))
        nvgText(nvg, textX, textY, typeName)
    end
    
    local headerH = iconSize + baseUnit * 0.5
    
    -- ========== 底部按钮区（固定）==========
    local footerH = baseUnit * 5.5
    local btnY = popupY + popupH - footerH + baseUnit * 0.5
    local btnW = baseUnit * 9
    local btnH = baseUnit * 2.2
    local detailPopupBtns = {}
    
    if uiState.detailSource == "inventory" and isWeapon then
        local tier = displayItem.tier or 1
        
        if uiState.detailMergeTargets and #uiState.detailMergeTargets > 0 and tier < 4 then
            local mergeBtnX = centerX - btnW / 2
            local nextTier = tier + 1
            local nextTierName = ShopCards.TierNames[nextTier] or ("T" .. nextTier)
            
            UIStyle.DrawSciFiButton(nvg, mergeBtnX, btnY, btnW, btnH,
                "⬆ 合成 → " .. nextTierName, {
                baseUnit = baseUnit, animTime = animTime, variant = "primary",
                fontSize = UIStyle.FontSize(baseUnit, 0.95),
            })
            detailPopupBtns.merge = { x = mergeBtnX, y = btnY, w = btnW, h = btnH, targetIndex = uiState.detailMergeTargets[1] }
            btnY = btnY + btnH + baseUnit * 0.4
        end
        
        local recycleBtnX = centerX - btnW / 2
        local recycleValue = math.floor((displayItem.basePrice or 25) * 0.5)
        UIStyle.DrawSciFiButton(nvg, recycleBtnX, btnY, btnW, btnH,
            string.format("回收 +💎%d", recycleValue), {
            baseUnit = baseUnit, animTime = animTime, variant = "danger",
            fontSize = UIStyle.FontSize(baseUnit, 0.95),
        })
        detailPopupBtns.recycle = { x = recycleBtnX, y = btnY, w = btnW, h = btnH, value = recycleValue }
    end
    
    -- 关闭提示
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.85))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(120, 130, 140, 150))
    nvgText(nvg, centerX, popupY + popupH - baseUnit * 1.2, "点击空白处关闭")
    
    -- ========== 可滚动内容区 ==========
    local scrollAreaY = headerY + headerH + baseUnit * 0.5
    local scrollAreaH = popupH - headerH - footerH - padding * 2
    local scrollX = leftX
    local scrollW = contentW - baseUnit * 0.8
    
    -- 分隔线（头部下方）
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, leftX, scrollAreaY - baseUnit * 0.3)
    nvgLineTo(nvg, rightX, scrollAreaY - baseUnit * 0.3)
    nvgStrokeColor(nvg, nvgRGBA(60, 80, 100, 100))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- 计算内容总高度
    local contentH = 0
    local lineH = baseUnit * 1.5
    local smallLineH = baseUnit * 1.2
    
    if isWeapon then
        local weapon = displayItem.weaponData or displayItem
        local tier = displayItem.tier or 1
        
        -- 基础属性 (伤害、冷却、射程)
        contentH = contentH + lineH * 3
        if weapon.ammo then contentH = contentH + lineH end
        contentH = contentH + baseUnit * 0.5
        
        -- 特殊效果
        if weapon.homing then contentH = contentH + smallLineH end
        if weapon.piercing then contentH = contentH + smallLineH end
        if weapon.aoe then contentH = contentH + smallLineH end
        if weapon.burstCount and weapon.burstCount > 1 then contentH = contentH + smallLineH end
        
        -- 武器标签（左右排列）
        local weaponId = weapon.id or displayItem.id
        if weaponId and player and player.weapons then
            local tagInfo = TagSetBonuses.GetWeaponTagInfo(weaponId, player.weapons)
            if #tagInfo > 0 then
                contentH = contentH + baseUnit * 2.0  -- 分隔线 + 标题
                -- 计算所有标签中最大的高度（左右排列时取最大值）
                local maxTagHeight = 0
                for _, info in ipairs(tagInfo) do
                    local tagHeight = smallLineH  -- 标签名
                    local tiers = {2, 3, 4, 5, 6}
                    for _, tierNum in ipairs(tiers) do
                        if info.setDef.bonuses[tierNum] then
                            tagHeight = tagHeight + baseUnit * 1.0
                        end
                    end
                    tagHeight = tagHeight + baseUnit * 0.3
                    if tagHeight > maxTagHeight then
                        maxTagHeight = tagHeight
                    end
                end
                contentH = contentH + maxTagHeight
            end
        end
        
        -- 背景故事
        if weapon.lore then
            contentH = contentH + baseUnit * 2.0  -- 分隔线 + 标题
            local loreLines = ShopCards.WrapTextByWidth(nvg, weapon.lore, scrollW - baseUnit, UIStyle.FontSize(baseUnit, 0.85, 13))
            contentH = contentH + #loreLines * smallLineH
        end
    else
        local moduleDef = displayItem.moduleDef
        if moduleDef then
            contentH = contentH + lineH * 2  -- 类型 + 品质
            contentH = contentH + baseUnit * 1.5  -- 分隔线
            
            -- 效果描述
            local desc = moduleDef.description or ""
            local descLines = ShopCards.WrapTextByWidth(nvg, desc, scrollW, UIStyle.FontSize(baseUnit, 1.0, 14))
            contentH = contentH + lineH + #descLines * smallLineH
            
            if displayItem.count and displayItem.count > 1 then contentH = contentH + lineH end
            if moduleDef.maxStack then contentH = contentH + smallLineH end
            
            -- 背景故事
            if moduleDef.lore then
                contentH = contentH + baseUnit * 2.0
                local loreLines = ShopCards.WrapTextByWidth(nvg, moduleDef.lore, scrollW - baseUnit, UIStyle.FontSize(baseUnit, 0.85, 13))
                contentH = contentH + #loreLines * smallLineH
            end
        end
    end
    
    -- 更新滚动范围
    ShopCards.detailMaxScrollOffset = math.max(0, contentH - scrollAreaH)
    ShopCards.detailScrollOffset = math.max(-ShopCards.detailMaxScrollOffset, math.min(0, ShopCards.detailScrollOffset))
    
    -- 处理滚动输入
    local mx = TouchInput.x
    local my = TouchInput.y
    ShopCards.HandleDetailScroll(mx, my, scrollAreaY, scrollAreaH, baseUnit)
    
    -- 裁剪并绘制滚动内容
    nvgSave(nvg)
    nvgScissor(nvg, popupX + padding * 0.5, scrollAreaY, popupW - padding, scrollAreaH)
    
    local drawY = scrollAreaY + ShopCards.detailScrollOffset
    
    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.0, 14))
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    
    if isWeapon then
        local weapon = displayItem.weaponData or displayItem
        local tier = displayItem.tier or 1
        local tierMult = ({1.0, 1.25, 1.5, 1.75})[tier] or 1.0
        
        -- 伤害
        local dmg = (weapon.tierDamage and weapon.tierDamage[tier]) or ((weapon.damage or 10) * tierMult)
        local dmgText = dmg == math.floor(dmg) and tostring(math.floor(dmg)) or string.format("%.1f", dmg)
        nvgFillColor(nvg, nvgRGBA(255, 120, 120, 255))
        nvgText(nvg, scrollX, drawY, "⚔ 伤害")
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgText(nvg, rightX - baseUnit * 0.5, drawY, dmgText)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        drawY = drawY + lineH
        
        -- 冷却
        local cooldown = (weapon.tierCooldown and weapon.tierCooldown[tier]) or (weapon.cooldown or 1.0)
        nvgFillColor(nvg, nvgRGBA(100, 200, 255, 255))
        nvgText(nvg, scrollX, drawY, "⏱ 冷却时间")
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgText(nvg, rightX - baseUnit * 0.5, drawY, string.format("%.2f秒", cooldown))
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        drawY = drawY + lineH
        
        -- 射程
        local rangeVal = (weapon.tierRange and weapon.tierRange[tier]) or (weapon.range or 20)
        local rangeText = Weapons.GetRangeDescription(rangeVal)
        nvgFillColor(nvg, nvgRGBA(100, 255, 150, 255))
        nvgText(nvg, scrollX, drawY, "📏 射程")
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgText(nvg, rightX - baseUnit * 0.5, drawY, string.format("%s (%.0f)", rangeText, rangeVal))
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        drawY = drawY + lineH
        
        if weapon.ammo then
            nvgFillColor(nvg, nvgRGBA(255, 200, 100, 255))
            nvgText(nvg, scrollX, drawY, "🔋 弹匣")
            nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
            nvgText(nvg, rightX - baseUnit * 0.5, drawY, tostring(weapon.ammo))
            nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            drawY = drawY + lineH
        end
        
        drawY = drawY + baseUnit * 0.3
        
        -- 特殊效果
        nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.9, 13))
        if weapon.homing then
            nvgFillColor(nvg, nvgRGBA(255, 200, 100, 255))
            nvgText(nvg, scrollX, drawY, "✦ 自动追踪")
            drawY = drawY + smallLineH
        end
        if weapon.piercing then
            nvgFillColor(nvg, nvgRGBA(200, 100, 255, 255))
            nvgText(nvg, scrollX, drawY, "✦ 穿透效果")
            drawY = drawY + smallLineH
        end
        if weapon.aoe then
            nvgFillColor(nvg, nvgRGBA(255, 150, 100, 255))
            nvgText(nvg, scrollX, drawY, string.format("✦ 范围伤害 (半径%.1f)", weapon.aoeRadius or 3))
            drawY = drawY + smallLineH
        end
        if weapon.burstCount and weapon.burstCount > 1 then
            nvgFillColor(nvg, nvgRGBA(150, 200, 255, 255))
            nvgText(nvg, scrollX, drawY, string.format("✦ 连发 ×%d", weapon.burstCount))
            drawY = drawY + smallLineH
        end
        
        -- 武器标签（左右排列）
        local weaponId = weapon.id or displayItem.id
        if weaponId and player and player.weapons then
            local tagInfo = TagSetBonuses.GetWeaponTagInfo(weaponId, player.weapons)
            if #tagInfo > 0 then
                drawY = drawY + baseUnit * 0.5
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, scrollX, drawY)
                nvgLineTo(nvg, rightX - baseUnit * 0.5, drawY)
                nvgStrokeColor(nvg, nvgRGBA(60, 80, 100, 100))
                nvgStrokeWidth(nvg, 1)
                nvgStroke(nvg)
                drawY = drawY + baseUnit * 0.6
                
                nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.95, 14))
                nvgFillColor(nvg, nvgRGBA(200, 210, 220, 255))
                nvgText(nvg, scrollX, drawY, "🏷 武器标签")
                drawY = drawY + baseUnit * 1.3
                
                -- 左右排列：计算每列宽度
                local numTags = #tagInfo
                local columnWidth = (scrollW - baseUnit * 0.5) / numTags
                local startY = drawY
                local maxEndY = drawY
                
                for i, info in ipairs(tagInfo) do
                    local setDef = info.setDef
                    local color = setDef.color
                    local colX = scrollX + (i - 1) * columnWidth
                    local colY = startY
                    
                    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.9, 13))
                    nvgFillColor(nvg, info.level > 0 and nvgRGBA(color.r, color.g, color.b, 255) or nvgRGBA(120, 130, 140, 200))
                    nvgText(nvg, colX, colY, string.format("%s %s (%d/6)", setDef.icon, info.tag, info.count))
                    colY = colY + smallLineH
                    
                    nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.8, 12))
                    for _, tierNum in ipairs({2, 3, 4, 5, 6}) do
                        local tierBonus = setDef.bonuses[tierNum]
                        if tierBonus then
                            nvgFillColor(nvg, (info.level == tierNum) and nvgRGBA(100, 255, 150, 255) or nvgRGBA(100, 110, 120, 150))
                            nvgText(nvg, colX + baseUnit * 0.3, colY, string.format("(%d) %s", tierNum, tierBonus.desc))
                            colY = colY + baseUnit * 1.0
                        end
                    end
                    colY = colY + baseUnit * 0.2
                    if colY > maxEndY then maxEndY = colY end
                end
                drawY = maxEndY
            end
        end
        
        -- 背景故事
        if weapon.lore then
            drawY = drawY + baseUnit * 0.5
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, scrollX, drawY)
            nvgLineTo(nvg, rightX - baseUnit * 0.5, drawY)
            nvgStrokeColor(nvg, nvgRGBA(80, 60, 40, 100))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)
            drawY = drawY + baseUnit * 0.6
            
            nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.9, 13))
            nvgFillColor(nvg, nvgRGBA(180, 150, 100, 200))
            nvgText(nvg, scrollX, drawY, "◆ 背景故事")
            drawY = drawY + baseUnit * 1.2
            
            nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.85, 12))
            nvgFillColor(nvg, nvgRGBA(160, 150, 140, 200))
            local loreLines = ShopCards.WrapTextByWidth(nvg, weapon.lore, scrollW - baseUnit, UIStyle.FontSize(baseUnit, 0.85, 12))
            for _, line in ipairs(loreLines) do
                nvgText(nvg, scrollX + baseUnit * 0.3, drawY, line)
                drawY = drawY + smallLineH
            end
        end
    else
        -- 模块详情
        local moduleDef = displayItem.moduleDef
        if moduleDef then
            -- 品质
            local tierNames = {"T1 普通", "T2 进阶", "T3 强力", "T4 改变机制"}
            nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 200))
            nvgText(nvg, scrollX, drawY, "品质: " .. (tierNames[moduleDef.tier] or "T1"))
            drawY = drawY + lineH
            
            -- 分隔线
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, scrollX, drawY)
            nvgLineTo(nvg, rightX - baseUnit * 0.5, drawY)
            nvgStrokeColor(nvg, nvgRGBA(60, 80, 100, 100))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)
            drawY = drawY + baseUnit * 0.8
            
            -- 效果
            nvgFillColor(nvg, nvgRGBA(100, 255, 150, 255))
            nvgText(nvg, scrollX, drawY, "✦ 效果")
            drawY = drawY + baseUnit * 1.2
            
            nvgFillColor(nvg, nvgRGBA(220, 230, 240, 255))
            local desc = moduleDef.description or "提升战舰性能"
            local descLines = ShopCards.WrapTextByWidth(nvg, desc, scrollW, UIStyle.FontSize(baseUnit, 1.0, 14))
            for _, line in ipairs(descLines) do
                nvgText(nvg, scrollX, drawY, line)
                drawY = drawY + smallLineH
            end
            drawY = drawY + baseUnit * 0.3
            
            if displayItem.count and displayItem.count > 1 then
                nvgFillColor(nvg, nvgRGBA(255, 200, 100, 255))
                nvgText(nvg, scrollX, drawY, string.format("持有数量: x%d", displayItem.count))
                drawY = drawY + lineH
            end
            
            if moduleDef.maxStack then
                nvgFillColor(nvg, nvgRGBA(150, 160, 170, 180))
                nvgText(nvg, scrollX, drawY, string.format("最大堆叠: %d", moduleDef.maxStack))
                drawY = drawY + smallLineH
            end
            
            -- 背景故事
            if moduleDef.lore then
                drawY = drawY + baseUnit * 0.5
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, scrollX, drawY)
                nvgLineTo(nvg, rightX - baseUnit * 0.5, drawY)
                nvgStrokeColor(nvg, nvgRGBA(80, 60, 40, 100))
                nvgStrokeWidth(nvg, 1)
                nvgStroke(nvg)
                drawY = drawY + baseUnit * 0.6
                
                nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.9, 13))
                nvgFillColor(nvg, nvgRGBA(180, 150, 100, 200))
                nvgText(nvg, scrollX, drawY, "◆ 背景故事")
                drawY = drawY + baseUnit * 1.2
                
                nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.85, 12))
                nvgFillColor(nvg, nvgRGBA(160, 150, 140, 200))
                local loreLines = ShopCards.WrapTextByWidth(nvg, moduleDef.lore, scrollW - baseUnit, UIStyle.FontSize(baseUnit, 0.85, 12))
                for _, line in ipairs(loreLines) do
                    nvgText(nvg, scrollX + baseUnit * 0.3, drawY, line)
                    drawY = drawY + smallLineH
                end
            end
        end
    end
    
    nvgRestore(nvg)
    
    -- 滚动条
    if ShopCards.detailMaxScrollOffset > 0 then
        local scrollRatio = -ShopCards.detailScrollOffset / ShopCards.detailMaxScrollOffset
        local scrollBarH = math.max(baseUnit * 2, scrollAreaH * (scrollAreaH / contentH))
        local scrollBarY = scrollAreaY + scrollRatio * (scrollAreaH - scrollBarH)
        
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, rightX - baseUnit * 0.3, scrollAreaY, baseUnit * 0.25, scrollAreaH, baseUnit * 0.1)
        nvgFillColor(nvg, nvgRGBA(40, 50, 60, 100))
        nvgFill(nvg)
        
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, rightX - baseUnit * 0.3, scrollBarY, baseUnit * 0.25, scrollBarH, baseUnit * 0.1)
        nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, 180))
        nvgFill(nvg)
    end
    
    return detailPopupBtns
end

return ShopCards
