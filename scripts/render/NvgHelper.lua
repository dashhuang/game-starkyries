-- ============================================================================
-- 星河战姬 Starkyries - NanoVG 绘制优化辅助
-- ============================================================================
-- 提供批处理和状态缓存优化的绘图工具
-- 与 UIStyle.lua 配合使用，提供底层状态管理
-- ============================================================================

local NvgHelper = {}

-- 状态缓存（减少冗余状态设置）
local stateCache = {
    fillColor = nil,
    strokeColor = nil,
    strokeWidth = nil,
    fontSize = nil,
    fontFace = nil,
    textAlign = nil,
}

-- 统计数据（可选，用于调试）
local stats = {
    fillColorCalls = 0,
    fillColorSkipped = 0,
    strokeColorCalls = 0,
    strokeColorSkipped = 0,
}

--- 获取优化统计（调试用）
function NvgHelper.GetStats()
    return stats
end

--- 重置统计
function NvgHelper.ResetStats()
    stats.fillColorCalls = 0
    stats.fillColorSkipped = 0
    stats.strokeColorCalls = 0
    stats.strokeColorSkipped = 0
end

-- ============================================================================
-- 状态管理（减少冗余 API 调用）
-- ============================================================================

--- 设置填充颜色（带缓存）
---@param nvg userdata NanoVG 上下文
---@param r number 红色 0-255
---@param g number 绿色 0-255
---@param b number 蓝色 0-255
---@param a number? 透明度 0-255，默认255
function NvgHelper.SetFillColor(nvg, r, g, b, a)
    a = a or 255
    local key = r .. "," .. g .. "," .. b .. "," .. a
    stats.fillColorCalls = stats.fillColorCalls + 1
    if stateCache.fillColor ~= key then
        nvgFillColor(nvg, nvgRGBA(r, g, b, a))
        stateCache.fillColor = key
    else
        stats.fillColorSkipped = stats.fillColorSkipped + 1
    end
end

--- 设置填充颜色（颜色对象版本，兼容 UIStyle.Colors 格式）
---@param nvg userdata NanoVG 上下文
---@param color table 颜色对象 {r, g, b}
---@param a number? 透明度 0-255，默认255
function NvgHelper.SetFillColorObj(nvg, color, a)
    NvgHelper.SetFillColor(nvg, color.r, color.g, color.b, a)
end

--- 设置描边颜色（带缓存）
function NvgHelper.SetStrokeColor(nvg, r, g, b, a)
    a = a or 255
    local key = r .. "," .. g .. "," .. b .. "," .. a
    stats.strokeColorCalls = stats.strokeColorCalls + 1
    if stateCache.strokeColor ~= key then
        nvgStrokeColor(nvg, nvgRGBA(r, g, b, a))
        stateCache.strokeColor = key
    else
        stats.strokeColorSkipped = stats.strokeColorSkipped + 1
    end
end

--- 设置描边颜色（颜色对象版本）
---@param nvg userdata NanoVG 上下文
---@param color table 颜色对象 {r, g, b}
---@param a number? 透明度 0-255，默认255
function NvgHelper.SetStrokeColorObj(nvg, color, a)
    NvgHelper.SetStrokeColor(nvg, color.r, color.g, color.b, a)
end

--- 设置描边宽度（带缓存）
function NvgHelper.SetStrokeWidth(nvg, width)
    if stateCache.strokeWidth ~= width then
        nvgStrokeWidth(nvg, width)
        stateCache.strokeWidth = width
    end
end

--- 设置字体大小（带缓存）
function NvgHelper.SetFontSize(nvg, size)
    if stateCache.fontSize ~= size then
        nvgFontSize(nvg, size)
        stateCache.fontSize = size
    end
end

--- 设置文本对齐（带缓存）
function NvgHelper.SetTextAlign(nvg, align)
    if stateCache.textAlign ~= align then
        nvgTextAlign(nvg, align)
        stateCache.textAlign = align
    end
end

--- 设置字体（带缓存）
function NvgHelper.SetFont(nvg, face, size, align)
    if face and stateCache.fontFace ~= face then
        nvgFontFace(nvg, face)
        stateCache.fontFace = face
    end
    if size and stateCache.fontSize ~= size then
        nvgFontSize(nvg, size)
        stateCache.fontSize = size
    end
    if align and stateCache.textAlign ~= align then
        nvgTextAlign(nvg, align)
        stateCache.textAlign = align
    end
end

--- 重置状态缓存（每帧开始时调用）
function NvgHelper.ResetCache()
    stateCache.fillColor = nil
    stateCache.strokeColor = nil
    stateCache.strokeWidth = nil
    stateCache.fontSize = nil
    stateCache.fontFace = nil
    stateCache.textAlign = nil
end

--- 开始新帧（重置缓存 + 统计）
function NvgHelper.BeginFrame()
    NvgHelper.ResetCache()
    -- 可选：每帧重置统计
    -- NvgHelper.ResetStats()
end

-- ============================================================================
-- 批量绘制（减少 BeginPath/Fill 调用）
-- ============================================================================

--- 批量绘制同色矩形
---@param nvg userdata NanoVG 上下文
---@param rects table 矩形列表 {{x, y, w, h}, ...}
---@param r number 红色
---@param g number 绿色
---@param b number 蓝色
---@param a number? 透明度
function NvgHelper.FillRects(nvg, rects, r, g, b, a)
    if #rects == 0 then return end
    
    nvgBeginPath(nvg)
    for _, rect in ipairs(rects) do
        nvgRect(nvg, rect[1], rect[2], rect[3], rect[4])
    end
    NvgHelper.SetFillColor(nvg, r, g, b, a)
    nvgFill(nvg)
end

--- 批量绘制同色圆角矩形
---@param nvg userdata NanoVG 上下文
---@param rects table 矩形列表 {{x, y, w, h, radius}, ...}
---@param r number 红色
---@param g number 绿色
---@param b number 蓝色
---@param a number? 透明度
function NvgHelper.FillRoundRects(nvg, rects, r, g, b, a)
    if #rects == 0 then return end
    
    nvgBeginPath(nvg)
    for _, rect in ipairs(rects) do
        nvgRoundedRect(nvg, rect[1], rect[2], rect[3], rect[4], rect[5] or 0)
    end
    NvgHelper.SetFillColor(nvg, r, g, b, a)
    nvgFill(nvg)
end

--- 批量绘制同色圆形
---@param nvg userdata NanoVG 上下文
---@param circles table 圆形列表 {{cx, cy, radius}, ...}
---@param r number 红色
---@param g number 绿色
---@param b number 蓝色
---@param a number? 透明度
function NvgHelper.FillCircles(nvg, circles, r, g, b, a)
    if #circles == 0 then return end
    
    nvgBeginPath(nvg)
    for _, c in ipairs(circles) do
        nvgCircle(nvg, c[1], c[2], c[3])
    end
    NvgHelper.SetFillColor(nvg, r, g, b, a)
    nvgFill(nvg)
end

-- ============================================================================
-- 常用 UI 组件（组合优化）
-- ============================================================================

--- 绘制带边框的圆角矩形
---@param nvg userdata NanoVG 上下文
---@param x number X坐标
---@param y number Y坐标
---@param w number 宽度
---@param h number 高度
---@param radius number 圆角半径
---@param fillR number 填充红色
---@param fillG number 填充绿色
---@param fillB number 填充蓝色
---@param fillA number 填充透明度
---@param strokeR number? 边框红色
---@param strokeG number? 边框绿色
---@param strokeB number? 边框蓝色
---@param strokeA number? 边框透明度
---@param strokeW number? 边框宽度
function NvgHelper.Panel(nvg, x, y, w, h, radius, fillR, fillG, fillB, fillA, strokeR, strokeG, strokeB, strokeA, strokeW)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, radius)
    NvgHelper.SetFillColor(nvg, fillR, fillG, fillB, fillA)
    nvgFill(nvg)
    
    if strokeR then
        NvgHelper.SetStrokeColor(nvg, strokeR, strokeG, strokeB, strokeA or 255)
        NvgHelper.SetStrokeWidth(nvg, strokeW or 1)
        nvgStroke(nvg)
    end
end

--- 绘制进度条
---@param nvg userdata NanoVG 上下文
---@param x number X坐标
---@param y number Y坐标
---@param w number 宽度
---@param h number 高度
---@param progress number 进度 0-1
---@param bgR number 背景红色
---@param bgG number 背景绿色
---@param bgB number 背景蓝色
---@param bgA number 背景透明度
---@param fgR number 前景红色
---@param fgG number 前景绿色
---@param fgB number 前景蓝色
---@param fgA number 前景透明度
---@param radius number? 圆角半径
function NvgHelper.ProgressBar(nvg, x, y, w, h, progress, bgR, bgG, bgB, bgA, fgR, fgG, fgB, fgA, radius)
    radius = radius or 0
    progress = math.max(0, math.min(1, progress))
    
    -- 背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, radius)
    NvgHelper.SetFillColor(nvg, bgR, bgG, bgB, bgA)
    nvgFill(nvg)
    
    -- 前景
    if progress > 0 then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, y, w * progress, h, radius)
        NvgHelper.SetFillColor(nvg, fgR, fgG, fgB, fgA)
        nvgFill(nvg)
    end
end

--- 绘制带阴影的文本
---@param nvg userdata NanoVG 上下文
---@param x number X坐标
---@param y number Y坐标
---@param text string 文本
---@param r number 文本红色
---@param g number 文本绿色
---@param b number 文本蓝色
---@param a number? 文本透明度
---@param shadowOffset number? 阴影偏移
---@param shadowAlpha number? 阴影透明度
function NvgHelper.TextWithShadow(nvg, x, y, text, r, g, b, a, shadowOffset, shadowAlpha)
    a = a or 255
    shadowOffset = shadowOffset or 2
    shadowAlpha = shadowAlpha or 100
    
    -- 阴影
    NvgHelper.SetFillColor(nvg, 0, 0, 0, shadowAlpha)
    nvgText(nvg, x + shadowOffset, y + shadowOffset, text)
    
    -- 文本
    NvgHelper.SetFillColor(nvg, r, g, b, a)
    nvgText(nvg, x, y, text)
end

-- ============================================================================
-- 批量文本绘制
-- ============================================================================

--- 批量绘制同样式文本
---@param nvg userdata NanoVG 上下文
---@param texts table 文本列表 {{x, y, text}, ...}
---@param r number 红色
---@param g number 绿色
---@param b number 蓝色
---@param a number? 透明度
function NvgHelper.DrawTexts(nvg, texts, r, g, b, a)
    if #texts == 0 then return end
    
    NvgHelper.SetFillColor(nvg, r, g, b, a)
    for _, t in ipairs(texts) do
        nvgText(nvg, t[1], t[2], t[3])
    end
end

-- ============================================================================
-- 渐变辅助
-- ============================================================================

--- 创建垂直渐变并填充矩形
function NvgHelper.FillRectGradientV(nvg, x, y, w, h, topR, topG, topB, topA, botR, botG, botB, botA)
    local gradient = nvgLinearGradient(nvg, x, y, x, y + h,
        nvgRGBA(topR, topG, topB, topA),
        nvgRGBA(botR, botG, botB, botA))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, gradient)
    nvgFill(nvg)
end

--- 创建水平渐变并填充矩形
function NvgHelper.FillRectGradientH(nvg, x, y, w, h, leftR, leftG, leftB, leftA, rightR, rightG, rightB, rightA)
    local gradient = nvgLinearGradient(nvg, x, y, x + w, y,
        nvgRGBA(leftR, leftG, leftB, leftA),
        nvgRGBA(rightR, rightG, rightB, rightA))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, gradient)
    nvgFill(nvg)
end

-- ============================================================================
-- 多行文本渲染（替代 nvgTextBox）
-- ============================================================================

--- 渲染多行文本（自动换行）
--- 由于引擎的 nvgTextBox 可能有问题，使用此函数替代
---@param nvg userdata NanoVG 上下文
---@param x number 起始 X 坐标
---@param y number 起始 Y 坐标
---@param maxWidth number 最大宽度（超出自动换行）
---@param text string 要渲染的文本
---@param lineHeight number? 行高倍数，默认 1.3
---@return number 渲染的总高度
function NvgHelper.TextBox(nvg, x, y, maxWidth, text, lineHeight)
    if not text or text == "" then return 0 end
    
    lineHeight = lineHeight or 1.3
    
    -- 获取当前字体度量
    local ascender, descender, lineh = nvgTextMetrics(nvg)
    local actualLineHeight = lineh * lineHeight
    
    local currentY = y
    local currentLine = ""
    local totalHeight = 0
    
    -- 逐字符处理（支持中文）
    local i = 1
    local len = #text
    
    while i <= len do
        local byte = string.byte(text, i)
        local char
        local charLen
        
        -- UTF-8 字符长度判断
        if byte < 128 then
            charLen = 1
        elseif byte < 224 then
            charLen = 2
        elseif byte < 240 then
            charLen = 3
        else
            charLen = 4
        end
        
        char = string.sub(text, i, i + charLen - 1)
        i = i + charLen
        
        -- 处理换行符
        if char == "\n" then
            if currentLine ~= "" then
                nvgText(nvg, x, currentY, currentLine)
                currentY = currentY + actualLineHeight
                totalHeight = totalHeight + actualLineHeight
            else
                currentY = currentY + actualLineHeight
                totalHeight = totalHeight + actualLineHeight
            end
            currentLine = ""
        else
            -- 测试添加字符后的宽度
            local testLine = currentLine .. char
            local testWidth = nvgTextBounds(nvg, 0, 0, testLine)  -- 直接返回宽度
            
            if testWidth > maxWidth and currentLine ~= "" then
                -- 当前行已满，先渲染当前行
                nvgText(nvg, x, currentY, currentLine)
                currentY = currentY + actualLineHeight
                totalHeight = totalHeight + actualLineHeight
                currentLine = char
            else
                currentLine = testLine
            end
        end
    end
    
    -- 渲染最后一行
    if currentLine ~= "" then
        nvgText(nvg, x, currentY, currentLine)
        totalHeight = totalHeight + actualLineHeight
    end
    
    return totalHeight
end

--- 计算多行文本高度（不渲染）
---@param nvg userdata NanoVG 上下文
---@param maxWidth number 最大宽度
---@param text string 文本
---@param lineHeight number? 行高倍数，默认 1.3
---@return number 总高度
function NvgHelper.TextBoxHeight(nvg, maxWidth, text, lineHeight)
    if not text or text == "" then return 0 end
    
    lineHeight = lineHeight or 1.3
    
    local ascender, descender, lineh = nvgTextMetrics(nvg)
    local actualLineHeight = lineh * lineHeight
    
    local totalHeight = 0
    local currentLine = ""
    
    local i = 1
    local len = #text
    
    while i <= len do
        local byte = string.byte(text, i)
        local charLen
        
        if byte < 128 then
            charLen = 1
        elseif byte < 224 then
            charLen = 2
        elseif byte < 240 then
            charLen = 3
        else
            charLen = 4
        end
        
        local char = string.sub(text, i, i + charLen - 1)
        i = i + charLen
        
        if char == "\n" then
            totalHeight = totalHeight + actualLineHeight
            currentLine = ""
        else
            local testLine = currentLine .. char
            local testWidth = nvgTextBounds(nvg, 0, 0, testLine)  -- 直接返回宽度
            
            if testWidth > maxWidth and currentLine ~= "" then
                totalHeight = totalHeight + actualLineHeight
                currentLine = char
            else
                currentLine = testLine
            end
        end
    end
    
    if currentLine ~= "" then
        totalHeight = totalHeight + actualLineHeight
    end
    
    return totalHeight
end

return NvgHelper
