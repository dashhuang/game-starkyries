-- ============================================================================
-- 星河战姬 Starkyries - UI风格系统
-- 统一的视觉规范和组件库
-- ============================================================================

local NvgHelper = require("render.NvgHelper")
local UISafeArea = require("ui.UISafeArea")
local FrameCache = require("utils.FrameCache")

local UIStyle = {}

-- 导出引用，供外部直接使用
UIStyle.NvgHelper = NvgHelper
UIStyle.SafeArea = UISafeArea

-- ============================================================================
-- 🎨 调色板 - 太空科幻主题
-- ============================================================================

UIStyle.Colors = {
    -- 背景层次
    bg = {
        dark = {r = 8, g = 12, b = 24},         -- 最深背景
        panel = {r = 16, g = 24, b = 40},       -- 面板背景
        card = {r = 24, g = 36, b = 56},        -- 卡片背景
        cardHover = {r = 32, g = 48, b = 72},   -- 卡片悬停
    },
    
    -- 主色调 - 青蓝色系
    primary = {
        main = {r = 60, g = 180, b = 255},      -- 主色
        light = {r = 100, g = 210, b = 255},    -- 亮色
        dark = {r = 30, g = 120, b = 200},      -- 暗色
        glow = {r = 60, g = 180, b = 255},      -- 发光色
    },
    
    -- 强调色 - 紫色系
    accent = {
        main = {r = 160, g = 100, b = 255},     -- 强调色
        light = {r = 200, g = 150, b = 255},    -- 亮色
        dark = {r = 100, g = 60, b = 180},      -- 暗色
    },
    
    -- 功能色
    success = {r = 80, g = 200, b = 120},       -- 成功/正面
    warning = {r = 255, g = 180, b = 60},       -- 警告
    danger = {r = 255, g = 80, b = 80},         -- 危险/负面
    
    -- 文字颜色
    text = {
        primary = {r = 255, g = 255, b = 255},  -- 主文字
        secondary = {r = 180, g = 190, b = 200},-- 次要文字
        muted = {r = 120, g = 130, b = 140},    -- 弱化文字
        highlight = {r = 255, g = 220, b = 100},-- 高亮文字
    },
    
    -- 边框颜色
    border = {
        normal = {r = 60, g = 80, b = 120},     -- 普通边框
        active = {r = 80, g = 180, b = 255},    -- 激活边框
        glow = {r = 60, g = 180, b = 255},      -- 发光边框
    },
    
    -- 进度条颜色
    bar = {
        health = {r = 80, g = 200, b = 120},    -- 生命值
        shield = {r = 60, g = 180, b = 255},    -- 护盾
        energy = {r = 255, g = 200, b = 60},    -- 能量
        exp = {r = 160, g = 100, b = 255},      -- 经验
    },
}

-- ============================================================================
-- 🏆 品质/等级颜色 (武器、模块通用)
-- ============================================================================

UIStyle.TierColors = {
    [1] = {r = 180, g = 180, b = 180, name = "普通"},  -- T1 灰白
    [2] = {r = 100, g = 220, b = 100, name = "精良"},  -- T2 绿色
    [3] = {r = 80, g = 160, b = 255, name = "稀有"},   -- T3 蓝色
    [4] = {r = 180, g = 100, b = 255, name = "传说"},  -- T4 紫色
}

-- 获取品质颜色（带默认值）
function UIStyle.GetTierColor(tier)
    return UIStyle.TierColors[tier] or UIStyle.TierColors[1]
end

-- 获取品质名称
function UIStyle.GetTierName(tier)
    local color = UIStyle.TierColors[tier]
    return color and color.name or "普通"
end

-- ============================================================================
-- 📐 尺寸规范
-- ============================================================================

UIStyle.Sizes = {
    -- 圆角
    radiusSmall = 0.3,    -- 小圆角 (乘以 baseUnit)
    radiusMedium = 0.5,   -- 中圆角
    radiusLarge = 1.0,    -- 大圆角
    
    -- 边框宽度
    borderThin = 1,
    borderNormal = 2,
    borderThick = 3,
    
    -- 内边距
    paddingSmall = 0.5,   -- (乘以 baseUnit)
    paddingMedium = 1.0,
    paddingLarge = 2.0,
    
    -- 字体大小比例（旧版，保留兼容）
    fontTitle = 4.0,      -- 标题
    fontLarge = 2.5,      -- 大号
    fontMedium = 2.0,     -- 中号
    fontSmall = 1.5,      -- 小号
    fontTiny = 1.2,       -- 微小
}

-- ============================================================================
-- 📝 统一字体规范
-- ============================================================================
-- 使用方式: local fonts = UIStyle.GetTypography(sw, sh)
--           nvgFontSize(nvg, fonts.cardTitle)
--
-- 横竖屏使用相同乘数，通过 baseUnit = min(sw, sh) / 40 自动适配屏幕大小
-- 最小像素值限制确保小屏幕可读性

UIStyle.Typography = {
    -- 字体乘数（横竖屏统一，通过 baseUnit 自动适配屏幕大小）
    -- baseUnit = math.min(sw, sh) / 40
    multipliers = {
        -- 页面级
        pageTitle = 3.0,      -- 页面大标题
        pageSubtitle = 1.6,   -- 页面副标题/提示
        
        -- 卡片级
        cardTitle = 1.9,      -- 卡片标题
        cardSubtitle = 1.25,  -- 卡片副标题
        
        -- 内容级
        statLabel = 2.25,     -- 属性标签
        statValue = 2.25,     -- 属性值
        description = 1.8,    -- 描述文字
        
        -- 交互级
        buttonText = 1.6,     -- 按钮文字
        tagText = 1.5,        -- 标签文字
        hintText = 1.8,       -- 提示文字
    },
    
    -- 最小像素值限制（保证小屏幕可读性）
    minPixels = {
        pageTitle = 28,
        pageSubtitle = 18,
        cardTitle = 20,
        cardSubtitle = 16,
        statLabel = 18,
        statValue = 18,
        description = 16,
        buttonText = 18,
        tagText = 14,
        hintText = 16,
    },
}

-- ============================================================================
-- 🔧 辅助函数
-- ============================================================================

-- 颜色转 RGBA
function UIStyle.RGBA(color, alpha)
    alpha = alpha or 255
    return nvgRGBA(color.r, color.g, color.b, alpha)
end

-- 颜色插值
function UIStyle.LerpColor(c1, c2, t)
    return {
        r = c1.r + (c2.r - c1.r) * t,
        g = c1.g + (c2.g - c1.g) * t,
        b = c1.b + (c2.b - c1.b) * t,
    }
end

-- ============================================================================
-- 🚀 优化的颜色设置（使用 NvgHelper 缓存）
-- ============================================================================

--- 设置填充颜色（带缓存优化）
---@param nvg userdata NanoVG 上下文
---@param color table 颜色对象 {r, g, b}
---@param alpha number? 透明度 0-255
function UIStyle.SetFillColor(nvg, color, alpha)
    NvgHelper.SetFillColor(nvg, color.r, color.g, color.b, alpha or 255)
end

--- 设置描边颜色（带缓存优化）
---@param nvg userdata NanoVG 上下文
---@param color table 颜色对象 {r, g, b}
---@param alpha number? 透明度 0-255
function UIStyle.SetStrokeColor(nvg, color, alpha)
    NvgHelper.SetStrokeColor(nvg, color.r, color.g, color.b, alpha or 255)
end

--- 设置字体（带缓存优化）
---@param nvg userdata NanoVG 上下文
---@param size number 字体大小
---@param align number? 对齐方式
function UIStyle.SetFont(nvg, size, align)
    NvgHelper.SetFontSize(nvg, size)
    if align then
        NvgHelper.SetTextAlign(nvg, align)
    end
end

--- 每帧开始时调用，重置状态缓存
function UIStyle.BeginFrame()
    NvgHelper.BeginFrame()
end

-- 获取响应式基准单位
function UIStyle.GetBaseUnit(sw, sh)
    return math.min(sw, sh) / 40
end

-- 获取字体大小表（旧版，保留兼容）
function UIStyle.GetFontSizes(baseUnit)
    return {
        title = baseUnit * UIStyle.Sizes.fontTitle,
        large = baseUnit * UIStyle.Sizes.fontLarge,
        medium = baseUnit * UIStyle.Sizes.fontMedium,
        small = baseUnit * UIStyle.Sizes.fontSmall,
        tiny = baseUnit * UIStyle.Sizes.fontTiny,
    }
end

-- 判断是否竖屏
function UIStyle.IsPortrait(sw, sh)
    return sh >= sw
end

-- ============================================================================
-- 🔴 安全字体大小函数（全局最小值保护）
-- ============================================================================
-- 所有 UI 都应使用此函数或 GetTypography，确保字体不会太小
--
-- 用法1（推荐）: local fonts = UIStyle.GetTypography(sw, sh)
--               nvgFontSize(nvg, fonts.statLabel)
--
-- 用法2（自定义乘数）: nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.5))
--
-- 用法3（指定最小值）: nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.8, 16))

-- 全局最小字体像素值（绝对底线，任何情况下都不能更小）
UIStyle.MIN_FONT_SIZE = 14

-- 安全字体大小函数
-- @param baseUnit 基准单位
-- @param multiplier 乘数
-- @param minSize 可选，自定义最小值（默认使用全局 MIN_FONT_SIZE）
-- @return 保证不小于最小值的字体大小
function UIStyle.FontSize(baseUnit, multiplier, minSize)
    minSize = minSize or UIStyle.MIN_FONT_SIZE
    return math.max(baseUnit * multiplier, minSize)
end

-- 批量获取安全字体大小（用于 HUD 等自定义布局）
-- @param baseUnit 基准单位
-- @param sizes 乘数表，如 {small = 0.8, medium = 1.0, large = 1.5}
-- @return 安全字体大小表
function UIStyle.FontSizes(baseUnit, sizes)
    local result = {}
    for name, multiplier in pairs(sizes) do
        result[name] = UIStyle.FontSize(baseUnit, multiplier)
    end
    return result
end

-- 获取统一字体规范（推荐使用）
-- 返回的字体大小已乘以 baseUnit，可直接用于 nvgFontSize
-- 自动应用最小像素值限制，确保移动端可读性
-- 🔴 性能优化：使用帧缓存，同一帧内只计算一次
function UIStyle.GetTypography(sw, sh)
    -- 确保是整数，避免 string.format %d 报错
    sw, sh = math.floor(sw), math.floor(sh)
    local cacheKey = string.format("typography_%d_%d", sw, sh)
    
    return FrameCache:Get(cacheKey, function()
        local baseUnit = math.min(sw, sh) / 40
        local isPortrait = UIStyle.IsPortrait(sw, sh)
        local mult = UIStyle.Typography.multipliers
        local minPx = UIStyle.Typography.minPixels
        
        -- 辅助函数：计算字体大小并应用最小值限制
        local function calcSize(key)
            local computed = baseUnit * mult[key]
            local minimum = minPx[key] or 10
            return math.max(computed, minimum)
        end
        
        return {
            -- 页面级
            pageTitle = calcSize("pageTitle"),
            pageSubtitle = calcSize("pageSubtitle"),
            
            -- 卡片级
            cardTitle = calcSize("cardTitle"),
            cardSubtitle = calcSize("cardSubtitle"),
            
            -- 内容级
            statLabel = calcSize("statLabel"),
            statValue = calcSize("statValue"),
            description = calcSize("description"),
            
            -- 交互级
            buttonText = calcSize("buttonText"),
            tagText = calcSize("tagText"),
            hintText = calcSize("hintText"),
            
            -- 元数据
            baseUnit = baseUnit,
            isPortrait = isPortrait,
        }
    end)
end

-- ============================================================================
-- 🎯 基础绘制函数
-- ============================================================================

-- 绘制发光效果（模拟）
function UIStyle.DrawGlow(nvg, x, y, w, h, radius, color, intensity)
    intensity = intensity or 0.3
    local layers = 3
    for i = layers, 1, -1 do
        local expand = i * 2
        local alpha = intensity * 255 / i
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x - expand, y - expand, w + expand * 2, h + expand * 2, radius + expand)
        nvgFillColor(nvg, nvgRGBA(color.r, color.g, color.b, alpha))
        nvgFill(nvg)
    end
end

-- 绘制渐变背景
function UIStyle.DrawGradientRect(nvg, x, y, w, h, radius, colorTop, colorBottom, alpha)
    alpha = alpha or 255
    local paint = nvgLinearGradient(nvg, x, y, x, y + h, 
        nvgRGBA(colorTop.r, colorTop.g, colorTop.b, alpha),
        nvgRGBA(colorBottom.r, colorBottom.g, colorBottom.b, alpha))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, radius)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)
end

-- 绘制扫描线效果
function UIStyle.DrawScanlines(nvg, x, y, w, h, spacing, alpha)
    spacing = spacing or 4
    alpha = alpha or 15
    nvgBeginPath(nvg)
    for ly = y, y + h, spacing do
        nvgRect(nvg, x, ly, w, 1)
    end
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, alpha))
    nvgFill(nvg)
end

-- ============================================================================
-- 📦 面板组件
-- ============================================================================

function UIStyle.DrawPanel(nvg, x, y, w, h, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local radius = baseUnit * (options.radius or UIStyle.Sizes.radiusMedium)
    local bgColor = options.bgColor or UIStyle.Colors.bg.panel
    local borderColor = options.borderColor or UIStyle.Colors.border.normal
    local borderWidth = options.borderWidth or UIStyle.Sizes.borderNormal
    local alpha = options.alpha or 240
    local glow = options.glow or false
    local glowColor = options.glowColor or UIStyle.Colors.primary.glow
    
    -- 发光效果
    if glow then
        UIStyle.DrawGlow(nvg, x, y, w, h, radius, glowColor, 0.2)
    end
    
    -- 渐变背景
    local bgTop = UIStyle.LerpColor(bgColor, {r = 255, g = 255, b = 255}, 0.05)
    UIStyle.DrawGradientRect(nvg, x, y, w, h, radius, bgTop, bgColor, alpha)
    
    -- 内发光（顶部高光）
    local highlightPaint = nvgLinearGradient(nvg, x, y, x, y + h * 0.3,
        nvgRGBA(255, 255, 255, 20), nvgRGBA(255, 255, 255, 0))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h * 0.3, radius)
    nvgFillPaint(nvg, highlightPaint)
    nvgFill(nvg)
    
    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, radius)
    nvgStrokeColor(nvg, UIStyle.RGBA(borderColor, 200))
    nvgStrokeWidth(nvg, borderWidth)
    nvgStroke(nvg)
    
    -- 扫描线
    if options.scanlines then
        nvgSave(nvg)
        nvgIntersectScissor(nvg, x, y, w, h)
        UIStyle.DrawScanlines(nvg, x, y, w, h, 3, 10)
        nvgRestore(nvg)
    end
end

-- ============================================================================
-- 🔘 按钮组件
-- ============================================================================

function UIStyle.DrawButton(nvg, x, y, w, h, text, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local radius = baseUnit * (options.radius or UIStyle.Sizes.radiusSmall)
    local fontSize = options.fontSize or baseUnit * UIStyle.Sizes.fontMedium
    local isSelected = options.selected or false
    local isDisabled = options.disabled or false
    local variant = options.variant or "primary"  -- primary, success, danger, ghost
    
    -- 颜色方案
    local bgColor, textColor, borderColor
    if isDisabled then
        bgColor = UIStyle.Colors.bg.card
        textColor = UIStyle.Colors.text.muted
        borderColor = UIStyle.Colors.border.normal
    elseif variant == "success" then
        bgColor = isSelected and UIStyle.Colors.success or UIStyle.LerpColor(UIStyle.Colors.success, UIStyle.Colors.bg.card, 0.6)
        textColor = UIStyle.Colors.text.primary
        borderColor = UIStyle.Colors.success
    elseif variant == "danger" then
        bgColor = isSelected and UIStyle.Colors.danger or UIStyle.LerpColor(UIStyle.Colors.danger, UIStyle.Colors.bg.card, 0.6)
        textColor = UIStyle.Colors.text.primary
        borderColor = UIStyle.Colors.danger
    elseif variant == "ghost" then
        bgColor = isSelected and UIStyle.Colors.bg.cardHover or {r = 0, g = 0, b = 0}
        textColor = UIStyle.Colors.text.secondary
        borderColor = UIStyle.Colors.border.normal
    else  -- primary
        bgColor = isSelected and UIStyle.Colors.primary.dark or UIStyle.Colors.bg.card
        textColor = UIStyle.Colors.text.primary
        borderColor = isSelected and UIStyle.Colors.primary.main or UIStyle.Colors.border.normal
    end
    
    -- 发光（选中时）
    if isSelected and not isDisabled then
        UIStyle.DrawGlow(nvg, x, y, w, h, radius, borderColor, 0.3)
    end
    
    -- 背景渐变
    local bgTop = UIStyle.LerpColor(bgColor, {r = 255, g = 255, b = 255}, 0.1)
    UIStyle.DrawGradientRect(nvg, x, y, w, h, radius, bgTop, bgColor, isDisabled and 150 or 230)
    
    -- 高光
    if not isDisabled then
        local highlightPaint = nvgLinearGradient(nvg, x, y, x, y + h * 0.4,
            nvgRGBA(255, 255, 255, 30), nvgRGBA(255, 255, 255, 0))
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, y, w, h * 0.4, radius)
        nvgFillPaint(nvg, highlightPaint)
        nvgFill(nvg)
    end
    
    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, radius)
    nvgStrokeColor(nvg, UIStyle.RGBA(borderColor, isSelected and 255 or 150))
    nvgStrokeWidth(nvg, isSelected and UIStyle.Sizes.borderNormal or UIStyle.Sizes.borderThin)
    nvgStroke(nvg)
    
    -- 文字
    nvgFontSize(nvg, fontSize)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, UIStyle.RGBA(textColor, isDisabled and 150 or 255))
    nvgText(nvg, x + w / 2, y + h / 2, text)
end

-- ============================================================================
-- 📊 进度条组件
-- ============================================================================

function UIStyle.DrawProgressBar(nvg, x, y, w, h, progress, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local radius = baseUnit * (options.radius or UIStyle.Sizes.radiusSmall)
    local barColor = options.barColor or UIStyle.Colors.bar.shield
    local showText = options.showText
    local fontSize = options.fontSize or baseUnit * UIStyle.Sizes.fontSmall
    
    progress = math.max(0, math.min(1, progress))
    
    -- 背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, radius)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
    nvgFill(nvg)
    
    -- 进度条发光
    if progress > 0 then
        local barW = (w - 4) * progress
        UIStyle.DrawGlow(nvg, x + 2, y + 2, barW, h - 4, radius * 0.6, barColor, 0.2)
    end
    
    -- 进度条渐变
    if progress > 0 then
        local barW = (w - 4) * progress
        local barTop = UIStyle.LerpColor(barColor, {r = 255, g = 255, b = 255}, 0.3)
        UIStyle.DrawGradientRect(nvg, x + 2, y + 2, barW, h - 4, radius * 0.6, barTop, barColor, 220)
        
        -- 高光条
        local highlightPaint = nvgLinearGradient(nvg, x + 2, y + 2, x + 2, y + h / 2,
            nvgRGBA(255, 255, 255, 60), nvgRGBA(255, 255, 255, 0))
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x + 2, y + 2, barW, (h - 4) / 2, radius * 0.6)
        nvgFillPaint(nvg, highlightPaint)
        nvgFill(nvg)
    end
    
    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, radius)
    nvgStrokeColor(nvg, UIStyle.RGBA(UIStyle.Colors.border.normal, 150))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- 文字
    if showText then
        nvgFontSize(nvg, fontSize)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, UIStyle.RGBA(UIStyle.Colors.text.primary, 255))
        nvgText(nvg, x + w / 2, y + h / 2, showText)
    end
end

-- ============================================================================
-- 🃏 卡片组件
-- ============================================================================

function UIStyle.DrawCard(nvg, x, y, w, h, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local radius = baseUnit * (options.radius or UIStyle.Sizes.radiusMedium)
    local isSelected = options.selected or false
    local isDisabled = options.disabled or false
    
    local bgColor = isSelected and UIStyle.Colors.bg.cardHover or UIStyle.Colors.bg.card
    local borderColor = isSelected and UIStyle.Colors.border.active or UIStyle.Colors.border.normal
    
    -- 发光（选中时）
    if isSelected and not isDisabled then
        UIStyle.DrawGlow(nvg, x, y, w, h, radius, UIStyle.Colors.primary.glow, 0.25)
    end
    
    -- 背景渐变
    local bgTop = UIStyle.LerpColor(bgColor, {r = 255, g = 255, b = 255}, 0.08)
    UIStyle.DrawGradientRect(nvg, x, y, w, h, radius, bgTop, bgColor, isDisabled and 150 or 250)
    
    -- 顶部高光
    local highlightPaint = nvgLinearGradient(nvg, x, y, x, y + h * 0.15,
        nvgRGBA(255, 255, 255, 25), nvgRGBA(255, 255, 255, 0))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h * 0.15, radius)
    nvgFillPaint(nvg, highlightPaint)
    nvgFill(nvg)
    
    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, radius)
    nvgStrokeColor(nvg, UIStyle.RGBA(borderColor, isSelected and 255 or 180))
    nvgStrokeWidth(nvg, isSelected and UIStyle.Sizes.borderThick or UIStyle.Sizes.borderThin)
    nvgStroke(nvg)
end

-- ============================================================================
-- 📝 文字样式函数
-- ============================================================================

function UIStyle.DrawTitle(nvg, x, y, text, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local fontSize = options.fontSize or baseUnit * UIStyle.Sizes.fontTitle
    local color = options.color or UIStyle.Colors.primary.light
    local align = options.align or (NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    local glow = options.glow ~= false  -- 默认有发光
    
    -- 发光效果
    if glow then
        nvgFontSize(nvg, fontSize)
        nvgTextAlign(nvg, align)
        nvgFillColor(nvg, nvgRGBA(color.r, color.g, color.b, 50))
        nvgText(nvg, x - 2, y, text)
        nvgText(nvg, x + 2, y, text)
        nvgText(nvg, x, y - 2, text)
        nvgText(nvg, x, y + 2, text)
    end
    
    -- 主文字
    nvgFontSize(nvg, fontSize)
    nvgTextAlign(nvg, align)
    nvgFillColor(nvg, UIStyle.RGBA(color, 255))
    nvgText(nvg, x, y, text)
end

function UIStyle.DrawLabel(nvg, x, y, text, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local fontSize = options.fontSize or baseUnit * UIStyle.Sizes.fontMedium
    local color = options.color or UIStyle.Colors.text.secondary
    local align = options.align or (NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    
    nvgFontSize(nvg, fontSize)
    nvgTextAlign(nvg, align)
    nvgFillColor(nvg, UIStyle.RGBA(color, options.alpha or 255))
    nvgText(nvg, x, y, text)
end

function UIStyle.DrawValue(nvg, x, y, text, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local fontSize = options.fontSize or baseUnit * UIStyle.Sizes.fontMedium
    local color = options.color or UIStyle.Colors.text.primary
    local align = options.align or (NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    
    nvgFontSize(nvg, fontSize)
    nvgTextAlign(nvg, align)
    nvgFillColor(nvg, UIStyle.RGBA(color, options.alpha or 255))
    nvgText(nvg, x, y, text)
end

function UIStyle.DrawHint(nvg, x, y, text, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local fontSize = options.fontSize or baseUnit * UIStyle.Sizes.fontSmall
    local color = options.color or UIStyle.Colors.text.muted
    local align = options.align or (NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    
    nvgFontSize(nvg, fontSize)
    nvgTextAlign(nvg, align)
    nvgFillColor(nvg, UIStyle.RGBA(color, options.alpha or 200))
    nvgText(nvg, x, y, text)
end

-- ============================================================================
-- 🏷️ 标签/徽章组件
-- ============================================================================

function UIStyle.DrawBadge(nvg, x, y, text, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local fontSize = options.fontSize or baseUnit * UIStyle.Sizes.fontTiny
    local color = options.color or UIStyle.Colors.primary.main
    local padding = baseUnit * 0.5
    
    -- 估算文字宽度（中文字符约等于字号，英文约0.6倍）
    nvgFontSize(nvg, fontSize)
    local charCount = 0
    for _ in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
        charCount = charCount + 1
    end
    local textW = charCount * fontSize * 0.7  -- 平均估算
    local textH = fontSize
    
    local badgeW = textW + padding * 2
    local badgeH = textH + padding
    local radius = badgeH / 2
    
    -- 背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, badgeW, badgeH, radius)
    nvgFillColor(nvg, UIStyle.RGBA(color, 200))
    nvgFill(nvg)
    
    -- 文字
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, UIStyle.RGBA(UIStyle.Colors.text.primary, 255))
    nvgText(nvg, x + badgeW / 2, y + badgeH / 2, text)
    
    return badgeW, badgeH
end

-- ============================================================================
-- ➖ 分隔线
-- ============================================================================

function UIStyle.DrawDivider(nvg, x, y, w, options)
    options = options or {}
    local color = options.color or UIStyle.Colors.border.normal
    local gradient = options.gradient ~= false
    
    if gradient then
        -- 渐变分隔线（两端淡出）
        local paint = nvgLinearGradient(nvg, x, y, x + w, y,
            nvgRGBA(color.r, color.g, color.b, 0),
            nvgRGBA(color.r, color.g, color.b, 150))
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, w / 2, 1)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
        
        paint = nvgLinearGradient(nvg, x + w / 2, y, x + w, y,
            nvgRGBA(color.r, color.g, color.b, 150),
            nvgRGBA(color.r, color.g, color.b, 0))
        nvgBeginPath(nvg)
        nvgRect(nvg, x + w / 2, y, w / 2, 1)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    else
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, w, 1)
        nvgFillColor(nvg, UIStyle.RGBA(color, 100))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 🖼️ 图标绘制辅助
-- ============================================================================

function UIStyle.DrawIcon(nvg, x, y, icon, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local fontSize = options.fontSize or baseUnit * UIStyle.Sizes.fontLarge
    local color = options.color or UIStyle.Colors.text.primary
    local align = options.align or (NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    
    nvgFontSize(nvg, fontSize)
    nvgTextAlign(nvg, align)
    nvgFillColor(nvg, UIStyle.RGBA(color, options.alpha or 255))
    nvgText(nvg, x, y, icon)
end

-- ============================================================================
-- 🚀 科技风格组件（统一风格）
-- ============================================================================

-- 绘制切角矩形路径（基础形状）
function UIStyle.DrawCutCornerPath(nvg, x, y, w, h, corner)
    corner = corner or 4
    nvgMoveTo(nvg, x + corner, y)
    nvgLineTo(nvg, x + w - corner, y)
    nvgLineTo(nvg, x + w, y + corner)
    nvgLineTo(nvg, x + w, y + h - corner)
    nvgLineTo(nvg, x + w - corner, y + h)
    nvgLineTo(nvg, x + corner, y + h)
    nvgLineTo(nvg, x, y + h - corner)
    nvgLineTo(nvg, x, y + corner)
    nvgClosePath(nvg)
end

-- 科技风格按钮
function UIStyle.DrawSciFiButton(nvg, x, y, w, h, text, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local cornerSize = baseUnit * 0.35
    local fontSize = options.fontSize or baseUnit * 1.6
    local animTime = options.animTime or 0
    local variant = options.variant or "primary"  -- primary, success, danger, accent
    local disabled = options.disabled or false
    local pressed = options.pressed or false  -- 按下状态
    
    -- 颜色配置（统一主菜单风格：亮蓝紫主色 + 暗蓝次要色）
    local primary = {bg1 = {r=80, g=120, b=200}, bg2 = {r=50, g=80, b=160}, border = {r=120, g=180, b=255}, glow = {r=100, g=160, b=240}}
    local secondary = {bg1 = {r=35, g=50, b=80}, bg2 = {r=25, g=35, b=60}, border = {r=60, g=90, b=140}, glow = {r=50, g=80, b=120}}
    local colors = {
        primary = primary,       -- 主要按钮（亮蓝紫，推荐/确认）
        secondary = secondary,   -- 次要按钮（暗蓝，普通/返回）
        danger = {bg1 = {r=160, g=60, b=60}, bg2 = {r=120, g=40, b=40}, border = {r=255, g=100, b=100}, glow = {r=200, g=80, b=80}},
        accent = {bg1 = {r=120, g=60, b=160}, bg2 = {r=80, g=40, b=120}, border = {r=180, g=120, b=255}, glow = {r=150, g=100, b=200}},
        -- 别名（向后兼容）
        success = primary,
        recommended = primary,
        normal = secondary,
    }
    local c = colors[variant] or primary
    
    if disabled then
        c = {bg1 = {r=50, g=55, b=65}, bg2 = {r=35, g=40, b=50}, border = {r=80, g=90, b=100}, glow = {r=60, g=70, b=80}}
    end
    
    -- 按下状态视觉调整
    local offsetY = pressed and 2 or 0
    local scale = pressed and 0.98 or 1.0
    local actualY = y + offsetY
    
    -- 按下时使用更暗的背景
    if pressed and not disabled then
        c = {
            bg1 = {r = math.floor(c.bg1.r * 0.7), g = math.floor(c.bg1.g * 0.7), b = math.floor(c.bg1.b * 0.7)},
            bg2 = {r = math.floor(c.bg2.r * 0.6), g = math.floor(c.bg2.g * 0.6), b = math.floor(c.bg2.b * 0.6)},
            border = c.border,
            glow = c.glow,
        }
    end
    
    -- 动画参数
    local pulseAlpha = (disabled or pressed) and 0 or (0.25 + 0.12 * math.sin(animTime * 3))
    local scanPos = (animTime * 0.3) % 1
    
    -- 外发光（按下时不显示）
    if not disabled and not pressed then
        for i = 3, 1, -1 do
            nvgBeginPath(nvg)
            UIStyle.DrawCutCornerPath(nvg, x - i * 2, actualY - i * 2, w + i * 4, h + i * 4, cornerSize + i)
            nvgFillColor(nvg, nvgRGBA(c.glow.r, c.glow.g, c.glow.b, pulseAlpha * 180 / i))
            nvgFill(nvg)
        end
    end
    
    -- 按钮背景渐变
    local bgGrad = nvgLinearGradient(nvg, x, actualY, x, actualY + h,
        nvgRGBA(c.bg1.r, c.bg1.g, c.bg1.b, disabled and 180 or 255),
        nvgRGBA(c.bg2.r, c.bg2.g, c.bg2.b, disabled and 180 or 255))
    nvgBeginPath(nvg)
    UIStyle.DrawCutCornerPath(nvg, x, actualY, w, h, cornerSize)
    nvgFillPaint(nvg, bgGrad)
    nvgFill(nvg)
    
    -- 顶部高光（按下时不显示）
    if not pressed then
        local highlightH = h * 0.35
        nvgSave(nvg)
        nvgBeginPath(nvg)
        UIStyle.DrawCutCornerPath(nvg, x, actualY, w, h, cornerSize)
        nvgIntersectScissor(nvg, x, actualY, w, highlightH)
        local topHighlight = nvgLinearGradient(nvg, x, actualY, x, actualY + highlightH,
            nvgRGBA(255, 255, 255, disabled and 20 or 50), nvgRGBA(255, 255, 255, 0))
        nvgFillPaint(nvg, topHighlight)
        nvgFill(nvg)
        nvgRestore(nvg)
    end
    
    -- 扫描线效果（按下时不显示）
    if not disabled and not pressed then
        local scanY = actualY + h * scanPos
        nvgSave(nvg)
        nvgBeginPath(nvg)
        UIStyle.DrawCutCornerPath(nvg, x, actualY, w, h, cornerSize)
        nvgIntersectScissor(nvg, x, scanY - 2, w, 4)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 50))
        nvgFill(nvg)
        nvgRestore(nvg)
    end
    
    -- 边框（按下时更亮）
    nvgBeginPath(nvg)
    UIStyle.DrawCutCornerPath(nvg, x, actualY, w, h, cornerSize)
    nvgStrokeColor(nvg, nvgRGBA(c.border.r, c.border.g, c.border.b, disabled and 100 or (pressed and 255 or 200)))
    nvgStrokeWidth(nvg, pressed and 2.5 or 1.5)
    nvgStroke(nvg)
    
    -- 角落装饰小三角（按下时跟随偏移）
    if not disabled and not pressed then
        local decorSize = baseUnit * 0.2
        nvgFillColor(nvg, nvgRGBA(c.border.r, c.border.g, c.border.b, 180))
        -- 左上
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x, actualY + cornerSize)
        nvgLineTo(nvg, x + cornerSize, actualY)
        nvgLineTo(nvg, x + cornerSize + decorSize, actualY)
        nvgLineTo(nvg, x, actualY + cornerSize + decorSize)
        nvgClosePath(nvg)
        nvgFill(nvg)
        -- 右上
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x + w - cornerSize, actualY)
        nvgLineTo(nvg, x + w, actualY + cornerSize)
        nvgLineTo(nvg, x + w, actualY + cornerSize + decorSize)
        nvgLineTo(nvg, x + w - cornerSize - decorSize, actualY)
        nvgClosePath(nvg)
        nvgFill(nvg)
        -- 左下
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x, actualY + h - cornerSize)
        nvgLineTo(nvg, x + cornerSize, actualY + h)
        nvgLineTo(nvg, x + cornerSize + decorSize, actualY + h)
        nvgLineTo(nvg, x, actualY + h - cornerSize - decorSize)
        nvgClosePath(nvg)
        nvgFill(nvg)
        -- 右下
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x + w, actualY + h - cornerSize)
        nvgLineTo(nvg, x + w - cornerSize, actualY + h)
        nvgLineTo(nvg, x + w - cornerSize - decorSize, actualY + h)
        nvgLineTo(nvg, x + w, actualY + h - cornerSize - decorSize)
        nvgClosePath(nvg)
        nvgFill(nvg)
    end
    
    -- 按钮文字（按下时跟随偏移）
    nvgFontSize(nvg, fontSize)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    -- 阴影
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, disabled and 50 or 100))
    nvgText(nvg, x + w / 2 + 1, actualY + h / 2 + 1, text)
    -- 主文字
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, disabled and 120 or 255))
    nvgText(nvg, x + w / 2, actualY + h / 2, text)
end

-- ============================================================================
-- 返回按钮组件（统一样式）
-- ============================================================================

-- 获取返回按钮的布局参数
function UIStyle.GetBackButtonLayout(baseUnit)
    return {
        x = baseUnit * 1.5,
        y = baseUnit * 1.5,
        w = baseUnit * 5,
        h = baseUnit * 2,
    }
end

-- 绘制返回按钮
function UIStyle.DrawBackButton(nvg, baseUnit, fontSize, pressed)
    local layout = UIStyle.GetBackButtonLayout(baseUnit)
    fontSize = fontSize or UIStyle.FontSize(baseUnit, 1.0)
    
    -- 按下状态：Y偏移、颜色变暗
    local offsetY = pressed and 2 or 0
    local alpha = pressed and 255 or 200
    local brightness = pressed and 0.7 or 1.0
    
    nvgFontSize(nvg, fontSize)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(
        math.floor(150 * brightness),
        math.floor(180 * brightness),
        math.floor(220 * brightness),
        alpha
    ))
    nvgText(nvg, layout.x, layout.y + offsetY, "< 返回")
end

-- 检测返回按钮点击
function UIStyle.IsBackButtonClicked(mx, my, baseUnit)
    local layout = UIStyle.GetBackButtonLayout(baseUnit)
    return mx >= layout.x and mx <= layout.x + layout.w and
           my >= layout.y and my <= layout.y + layout.h
end

-- ============================================================================

-- 科技风格面板
function UIStyle.DrawSciFiPanel(nvg, x, y, w, h, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local cornerSize = baseUnit * (options.cornerSize or 0.5)
    local animTime = options.animTime or 0
    local title = options.title
    local borderColor = options.borderColor or {r = 60, g = 140, b = 200}
    local bgAlpha = options.bgAlpha or 240
    
    -- 外发光（微弱）
    local glowAlpha = 0.1 + 0.05 * math.sin(animTime * 2)
    for i = 2, 1, -1 do
        nvgBeginPath(nvg)
        UIStyle.DrawCutCornerPath(nvg, x - i, y - i, w + i * 2, h + i * 2, cornerSize + i)
        nvgFillColor(nvg, nvgRGBA(borderColor.r, borderColor.g, borderColor.b, glowAlpha * 150 / i))
        nvgFill(nvg)
    end
    
    -- 背景
    local bgGrad = nvgLinearGradient(nvg, x, y, x, y + h,
        nvgRGBA(20, 30, 50, bgAlpha), nvgRGBA(12, 18, 32, bgAlpha))
    nvgBeginPath(nvg)
    UIStyle.DrawCutCornerPath(nvg, x, y, w, h, cornerSize)
    nvgFillPaint(nvg, bgGrad)
    nvgFill(nvg)
    
    -- 顶部高光
    local highlightH = h * 0.1
    nvgSave(nvg)
    nvgBeginPath(nvg)
    UIStyle.DrawCutCornerPath(nvg, x, y, w, h, cornerSize)
    nvgIntersectScissor(nvg, x, y, w, highlightH)
    local topHighlight = nvgLinearGradient(nvg, x, y, x, y + highlightH,
        nvgRGBA(255, 255, 255, 20), nvgRGBA(255, 255, 255, 0))
    nvgFillPaint(nvg, topHighlight)
    nvgFill(nvg)
    nvgRestore(nvg)
    
    -- 边框
    nvgBeginPath(nvg)
    UIStyle.DrawCutCornerPath(nvg, x, y, w, h, cornerSize)
    nvgStrokeColor(nvg, nvgRGBA(borderColor.r, borderColor.g, borderColor.b, 150))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
    
    -- 角落装饰
    local decorSize = baseUnit * 0.15
    nvgFillColor(nvg, nvgRGBA(borderColor.r, borderColor.g, borderColor.b, 200))
    -- 四个角
    local corners = {
        {x, y, 1, 1}, {x + w, y, -1, 1},
        {x, y + h, 1, -1}, {x + w, y + h, -1, -1}
    }
    for _, c in ipairs(corners) do
        local cx, cy, dx, dy = c[1], c[2], c[3], c[4]
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx, cy + dy * cornerSize)
        nvgLineTo(nvg, cx + dx * cornerSize, cy)
        nvgLineTo(nvg, cx + dx * (cornerSize + decorSize), cy)
        nvgLineTo(nvg, cx, cy + dy * (cornerSize + decorSize))
        nvgClosePath(nvg)
        nvgFill(nvg)
    end
    
    -- 标题
    if title then
        local titleH = baseUnit * 2.5
        -- 标题背景
        nvgSave(nvg)
        nvgBeginPath(nvg)
        UIStyle.DrawCutCornerPath(nvg, x, y, w, h, cornerSize)
        nvgIntersectScissor(nvg, x, y, w, titleH)
        local titleBg = nvgLinearGradient(nvg, x, y, x, y + titleH,
            nvgRGBA(borderColor.r, borderColor.g, borderColor.b, 60),
            nvgRGBA(borderColor.r, borderColor.g, borderColor.b, 10))
        nvgFillPaint(nvg, titleBg)
        nvgFill(nvg)
        nvgRestore(nvg)
        
        -- 标题分隔线
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x + baseUnit, y + titleH)
        nvgLineTo(nvg, x + w - baseUnit, y + titleH)
        nvgStrokeColor(nvg, nvgRGBA(borderColor.r, borderColor.g, borderColor.b, 80))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
        
        -- 标题文字
        nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.6))
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        nvgText(nvg, x + w / 2, y + titleH / 2, title)
    end
end

-- 科技风格卡片
function UIStyle.DrawSciFiCard(nvg, x, y, w, h, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local cornerSize = baseUnit * 0.3
    local selected = options.selected or false
    local animTime = options.animTime or 0
    local themeColor = options.themeColor or {r = 60, g = 180, b = 255}
    
    -- 选中时外发光
    if selected then
        local glowAlpha = 0.25 + 0.1 * math.sin(animTime * 3)
        for i = 4, 1, -1 do
            nvgBeginPath(nvg)
            UIStyle.DrawCutCornerPath(nvg, x - i * 2, y - i * 2, w + i * 4, h + i * 4, cornerSize + i)
            nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, glowAlpha * 200 / i))
            nvgFill(nvg)
        end
    end
    
    -- 背景
    nvgBeginPath(nvg)
    UIStyle.DrawCutCornerPath(nvg, x, y, w, h, cornerSize)
    nvgFillColor(nvg, nvgRGBA(18, 25, 40, 250))
    nvgFill(nvg)
    
    -- 顶部高光
    local highlightH = h * 0.08
    nvgSave(nvg)
    nvgBeginPath(nvg)
    UIStyle.DrawCutCornerPath(nvg, x, y, w, h, cornerSize)
    nvgIntersectScissor(nvg, x, y, w, highlightH)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 15))
    nvgFill(nvg)
    nvgRestore(nvg)
    
    -- 边框
    nvgBeginPath(nvg)
    UIStyle.DrawCutCornerPath(nvg, x, y, w, h, cornerSize)
    nvgStrokeColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, selected and 255 or 100))
    nvgStrokeWidth(nvg, selected and 2 or 1)
    nvgStroke(nvg)
    
    -- 选中时的角落装饰
    if selected then
        local decorSize = baseUnit * 0.15
        local alpha = 150 + 50 * math.sin(animTime * 2.5)
        nvgFillColor(nvg, nvgRGBA(themeColor.r, themeColor.g, themeColor.b, alpha))
        local corners = {
            {x, y, 1, 1}, {x + w, y, -1, 1},
            {x, y + h, 1, -1}, {x + w, y + h, -1, -1}
        }
        for _, c in ipairs(corners) do
            local cx, cy, dx, dy = c[1], c[2], c[3], c[4]
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx, cy + dy * cornerSize)
            nvgLineTo(nvg, cx + dx * cornerSize, cy)
            nvgLineTo(nvg, cx + dx * (cornerSize + decorSize), cy)
            nvgLineTo(nvg, cx, cy + dy * (cornerSize + decorSize))
            nvgClosePath(nvg)
            nvgFill(nvg)
        end
    end
end

-- 科技风格进度条（无边框版）
function UIStyle.DrawSciFiProgressBar(nvg, x, y, w, h, progress, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local barColor = options.barColor or {r = 60, g = 200, b = 120}
    local showText = options.showText
    local animTime = options.animTime or 0
    local cornerRadius = h * 0.15  -- 圆角基于高度
    
    progress = math.max(0, math.min(1, progress))
    
    -- 背景槽（深色，无边框）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, cornerRadius)
    nvgFillColor(nvg, nvgRGBA(10, 15, 25, 200))
    nvgFill(nvg)
    
    -- 进度条填充（直接贴合背景）
    if progress > 0 then
        local barW = w * progress
        
        -- 渐变填充
        local barGrad = nvgLinearGradient(nvg, x, y, x, y + h,
            nvgRGBA(math.min(255, barColor.r + 60), math.min(255, barColor.g + 60), math.min(255, barColor.b + 60), 255),
            nvgRGBA(barColor.r, barColor.g, barColor.b, 255))
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, y, barW, h, cornerRadius)
        nvgFillPaint(nvg, barGrad)
        nvgFill(nvg)
        
        -- 高光条
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, y, barW, h * 0.4, cornerRadius)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 50))
        nvgFill(nvg)
    end
    
    -- 文字
    if showText then
        local fontSize = options.fontSize or (h * 0.6)
        nvgFontSize(nvg, fontSize)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        -- 阴影
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 150))
        nvgText(nvg, x + w / 2 + 1, y + h / 2 + 1, showText)
        -- 主文字
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        nvgText(nvg, x + w / 2, y + h / 2, showText)
    end
end

-- ============================================================================
-- 🌟 装饰效果
-- ============================================================================

-- 绘制角落装饰
function UIStyle.DrawCornerDecor(nvg, x, y, w, h, options)
    options = options or {}
    local baseUnit = options.baseUnit or 10
    local size = baseUnit * (options.size or 1.5)
    local color = options.color or UIStyle.Colors.primary.main
    
    -- 四个角的装饰
    local corners = {
        {x, y, 1, 1},           -- 左上
        {x + w, y, -1, 1},      -- 右上
        {x, y + h, 1, -1},      -- 左下
        {x + w, y + h, -1, -1}, -- 右下
    }
    
    nvgStrokeColor(nvg, UIStyle.RGBA(color, 180))
    nvgStrokeWidth(nvg, 2)
    
    for _, corner in ipairs(corners) do
        local cx, cy, dx, dy = corner[1], corner[2], corner[3], corner[4]
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx, cy + dy * size)
        nvgLineTo(nvg, cx, cy)
        nvgLineTo(nvg, cx + dx * size, cy)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- 📱 全屏遮罩
-- ============================================================================

function UIStyle.DrawOverlay(nvg, sw, sh, options)
    options = options or {}
    local alpha = options.alpha or 200
    local color = options.color or UIStyle.Colors.bg.dark
    
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(color.r, color.g, color.b, alpha))
    nvgFill(nvg)
end

return UIStyle
