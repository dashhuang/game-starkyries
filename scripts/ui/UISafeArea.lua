-- ============================================================================
-- 星河战姬 Starkyries - UI 安全区模块
-- 横屏 16:9 + 竖屏 9:16 双设计模式
-- ============================================================================
--
-- 设计理念：
--   - 游戏画面：全屏渲染，支持所有长宽比
--   - 横屏UI：针对 16:9 设计，超宽/超窄屏留空
--   - 竖屏UI：针对 9:16 设计，超长/超宽屏留空
--   - 两套UI独立设计，不做响应式适配
--
-- 使用方式：
--   local UISafeArea = require("ui.UISafeArea")
--   local safe = UISafeArea.Calculate(sw, sh)
--   -- safe.isLandscape: true=横屏模式, false=竖屏模式
--   -- 在 safe.x, safe.y, safe.w, safe.h 区域内绘制 UI
--
-- ============================================================================

local FrameCache = require("utils.FrameCache")

local UISafeArea = {}

-- ============================================================================
-- 配置
-- ============================================================================

-- 横屏设计比例 16:9
UISafeArea.LANDSCAPE_RATIO = 16 / 9

-- 竖屏设计比例 9:16
UISafeArea.PORTRAIT_RATIO = 9 / 16

-- 设计分辨率（逻辑参考）
UISafeArea.DESIGN_LANDSCAPE = { w = 1920, h = 1080 }  -- 横屏 16:9
UISafeArea.DESIGN_PORTRAIT = { w = 1080, h = 1920 }   -- 竖屏 9:16

-- 是否启用安全区限制（可全局开关）
UISafeArea.enabled = true

-- 安全区外的遮罩颜色
UISafeArea.maskColor = {r = 8, g = 12, b = 20, a = 255}

-- 调试模式（显示安全区边框）
UISafeArea.debug = false

-- ============================================================================
-- 核心计算
-- ============================================================================

--- 计算安全区（自动判断横屏/竖屏）
--- 🔴 性能优化：使用帧缓存，同一帧内只计算一次
---@param sw number 屏幕宽度
---@param sh number 屏幕高度
---@return table 安全区信息
function UISafeArea.Calculate(sw, sh)
    -- 确保是整数，避免 string.format %d 报错
    local swInt, shInt = math.floor(sw), math.floor(sh)
    local cacheKey = string.format("safe_area_%d_%d", swInt, shInt)
    
    return FrameCache:Get(cacheKey, function()
        local isLandscape = sw > sh
        
        if isLandscape then
            return UISafeArea.CalculateLandscape(sw, sh)
        else
            return UISafeArea.CalculatePortrait(sw, sh)
        end
    end)
end

--- 计算横屏安全区（16:9）
---@param sw number 屏幕宽度
---@param sh number 屏幕高度
---@return table 安全区信息
function UISafeArea.CalculateLandscape(sw, sh)
    -- 如果禁用，返回全屏区域
    if not UISafeArea.enabled then
        return UISafeArea.CreateFullScreen(sw, sh, true)
    end
    
    local screenRatio = sw / sh
    local targetRatio = UISafeArea.LANDSCAPE_RATIO
    local safeW, safeH, safeX, safeY
    local needsMask = false
    
    if screenRatio > targetRatio then
        -- 屏幕比 16:9 更宽（如21:9）→ 左右留空
        safeH = sh
        safeW = sh * targetRatio
        safeX = (sw - safeW) / 2
        safeY = 0
        needsMask = true
    elseif screenRatio < targetRatio then
        -- 屏幕比 16:9 更窄（如4:3）→ 上下留空
        safeW = sw
        safeH = sw / targetRatio
        safeX = 0
        safeY = (sh - safeH) / 2
        needsMask = true
    else
        -- 正好 16:9
        safeW = sw
        safeH = sh
        safeX = 0
        safeY = 0
    end
    
    return UISafeArea.CreateSafeInfo(sw, sh, safeX, safeY, safeW, safeH, true, needsMask)
end

--- 计算竖屏安全区（9:16）
---@param sw number 屏幕宽度
---@param sh number 屏幕高度
---@return table 安全区信息
function UISafeArea.CalculatePortrait(sw, sh)
    -- 如果禁用，返回全屏区域
    if not UISafeArea.enabled then
        return UISafeArea.CreateFullScreen(sw, sh, false)
    end
    
    local screenRatio = sw / sh
    local targetRatio = UISafeArea.PORTRAIT_RATIO
    local safeW, safeH, safeX, safeY
    local needsMask = false
    
    if screenRatio > targetRatio then
        -- 屏幕比 9:16 更宽（如3:4 iPad）→ 左右留空
        safeH = sh
        safeW = sh * targetRatio
        safeX = (sw - safeW) / 2
        safeY = 0
        needsMask = true
    elseif screenRatio < targetRatio then
        -- 屏幕比 9:16 更窄（如9:21瀑布屏）→ 上下留空
        safeW = sw
        safeH = sw / targetRatio
        safeX = 0
        safeY = (sh - safeH) / 2
        needsMask = true
    else
        -- 正好 9:16
        safeW = sw
        safeH = sh
        safeX = 0
        safeY = 0
    end
    
    return UISafeArea.CreateSafeInfo(sw, sh, safeX, safeY, safeW, safeH, false, needsMask)
end

--- 创建安全区信息对象
function UISafeArea.CreateSafeInfo(sw, sh, x, y, w, h, isLandscape, needsMask)
    -- 基准单位：基于安全区短边 / 40
    local baseUnit = math.min(w, h) / 40
    
    -- 缩放因子：相对于设计分辨率
    local design = isLandscape and UISafeArea.DESIGN_LANDSCAPE or UISafeArea.DESIGN_PORTRAIT
    local scale = h / design.h
    
    return {
        -- 安全区位置和尺寸
        x = x,
        y = y,
        w = w,
        h = h,
        
        -- 屏幕原始尺寸
        screenW = sw,
        screenH = sh,
        
        -- 布局信息
        baseUnit = baseUnit,
        scale = scale,
        isLandscape = isLandscape,
        isPortrait = not isLandscape,
        needsMask = needsMask,
        enabled = true,
        
        -- 设计分辨率参考
        designW = design.w,
        designH = design.h,
    }
end

--- 创建全屏信息对象（禁用安全区时）
function UISafeArea.CreateFullScreen(sw, sh, isLandscape)
    local design = isLandscape and UISafeArea.DESIGN_LANDSCAPE or UISafeArea.DESIGN_PORTRAIT
    return {
        x = 0, y = 0,
        w = sw, h = sh,
        screenW = sw, screenH = sh,
        baseUnit = math.min(sw, sh) / 40,
        scale = sh / design.h,
        isLandscape = isLandscape,
        isPortrait = not isLandscape,
        needsMask = false,
        enabled = false,
        designW = design.w,
        designH = design.h,
    }
end

-- ============================================================================
-- 渲染辅助
-- ============================================================================

--- 绘制安全区外的遮罩
---@param nvg userdata NanoVG 上下文
---@param safe table 安全区信息
---@param color table? 可选遮罩颜色 {r, g, b, a}
function UISafeArea.DrawMask(nvg, safe, color)
    if not safe.needsMask then return end
    
    color = color or UISafeArea.maskColor
    nvgFillColor(nvg, nvgRGBA(color.r, color.g, color.b, color.a or 255))
    
    -- 根据留空方向绘制遮罩
    if safe.x > 0 then
        -- 左右留空
        nvgBeginPath(nvg)
        nvgRect(nvg, 0, 0, safe.x, safe.screenH)
        nvgFill(nvg)
        
        nvgBeginPath(nvg)
        nvgRect(nvg, safe.x + safe.w, 0, safe.screenW - safe.x - safe.w, safe.screenH)
        nvgFill(nvg)
    end
    
    if safe.y > 0 then
        -- 上下留空
        nvgBeginPath(nvg)
        nvgRect(nvg, 0, 0, safe.screenW, safe.y)
        nvgFill(nvg)
        
        nvgBeginPath(nvg)
        nvgRect(nvg, 0, safe.y + safe.h, safe.screenW, safe.screenH - safe.y - safe.h)
        nvgFill(nvg)
    end
end

--- 绘制安全区边框（调试用）
---@param nvg userdata NanoVG 上下文
---@param safe table 安全区信息
function UISafeArea.DrawDebugBorder(nvg, safe)
    if not UISafeArea.debug then return end
    
    -- 安全区边框
    nvgBeginPath(nvg)
    nvgRect(nvg, safe.x + 1, safe.y + 1, safe.w - 2, safe.h - 2)
    nvgStrokeColor(nvg, nvgRGBA(0, 255, 0, 200))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
    
    -- 信息文字
    nvgFontSize(nvg, 14)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(0, 255, 0, 255))
    
    local mode = safe.isLandscape and "Landscape 16:9" or "Portrait 9:16"
    local info = string.format("%s | Safe: %.0fx%.0f @ (%.0f,%.0f) | Screen: %.0fx%.0f", 
        mode, safe.w, safe.h, safe.x, safe.y, safe.screenW, safe.screenH)
    nvgText(nvg, safe.x + 10, safe.y + 10, info)
end

--- 开始安全区渲染（设置裁剪 + 坐标偏移）
--- 调用后所有绘制都在安全区内，坐标从(0,0)开始
---@param nvg userdata NanoVG 上下文
---@param safe table 安全区信息
function UISafeArea.BeginSafeArea(nvg, safe)
    nvgSave(nvg)
    nvgTranslate(nvg, safe.x, safe.y)
    nvgScissor(nvg, 0, 0, safe.w, safe.h)
end

--- 结束安全区渲染
---@param nvg userdata NanoVG 上下文
function UISafeArea.EndSafeArea(nvg)
    nvgResetScissor(nvg)
    nvgRestore(nvg)
end

-- ============================================================================
-- 坐标转换
-- ============================================================================

--- 将安全区内坐标转换为屏幕坐标
---@param safe table 安全区信息
---@param localX number 安全区内X
---@param localY number 安全区内Y
---@return number, number 屏幕坐标
function UISafeArea.ToScreen(safe, localX, localY)
    return safe.x + localX, safe.y + localY
end

--- 将屏幕坐标转换为安全区内坐标
---@param safe table 安全区信息
---@param screenX number 屏幕X
---@param screenY number 屏幕Y
---@return number, number 安全区内坐标
function UISafeArea.ToLocal(safe, screenX, screenY)
    return screenX - safe.x, screenY - safe.y
end

--- 检查屏幕坐标是否在安全区内
---@param safe table 安全区信息
---@param screenX number 屏幕X
---@param screenY number 屏幕Y
---@return boolean
function UISafeArea.Contains(safe, screenX, screenY)
    return screenX >= safe.x and screenX <= safe.x + safe.w
       and screenY >= safe.y and screenY <= safe.y + safe.h
end

-- ============================================================================
-- 便捷方法
-- ============================================================================

--- 获取安全区中心点（安全区内坐标）
---@param safe table 安全区信息
---@return number, number
function UISafeArea.GetCenter(safe)
    return safe.w / 2, safe.h / 2
end

--- 获取安全区中心点（屏幕坐标）
---@param safe table 安全区信息
---@return number, number
function UISafeArea.GetScreenCenter(safe)
    return safe.x + safe.w / 2, safe.y + safe.h / 2
end

--- 获取字体大小表（基于安全区）
---@param safe table 安全区信息
---@return table 字体大小表
function UISafeArea.GetTypography(safe)
    local baseUnit = safe.baseUnit
    
    return {
        -- 页面级
        pageTitle = math.max(baseUnit * 3.0, 28),
        pageSubtitle = math.max(baseUnit * 1.6, 18),
        
        -- 卡片级
        cardTitle = math.max(baseUnit * 1.9, 20),
        cardSubtitle = math.max(baseUnit * 1.25, 16),
        
        -- 内容级
        statLabel = math.max(baseUnit * 2.25, 18),
        statValue = math.max(baseUnit * 2.25, 18),
        description = math.max(baseUnit * 1.8, 16),
        
        -- 交互级
        buttonText = math.max(baseUnit * 1.6, 18),
        tagText = math.max(baseUnit * 1.5, 14),
        hintText = math.max(baseUnit * 1.8, 16),
        
        -- 元数据
        baseUnit = baseUnit,
        isLandscape = safe.isLandscape,
        isPortrait = safe.isPortrait,
    }
end

return UISafeArea
