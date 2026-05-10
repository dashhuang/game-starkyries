-- ============================================================================
-- 星河战姬 Starkyries - 主菜单界面
-- 科技风格 - 电路板装饰 + 星空背景 + 动态效果
-- ============================================================================
--
-- UI安全区设计：
--   横屏: 16:9 设计，超宽/窄屏留空
--   竖屏: 9:16 设计，超长/宽屏留空
--
-- ============================================================================

local UIStyle = require("ui.UIStyle")
local UISafeArea = require("ui.UISafeArea")
local UIScreen = require("ui.UIScreen")

local MainMenuUI = {}

-- ============================================================================
-- 状态
-- ============================================================================
MainMenuUI.visible = false
MainMenuUI.selectedIndex = 1
MainMenuUI.onStartGame = nil
MainMenuUI.onContinue = nil
MainMenuUI.onOptions = nil
MainMenuUI.onGallery = nil
MainMenuUI.onTest = nil
MainMenuUI.animTime = 0
MainMenuUI.hasSaveData = false  -- 是否有存档
MainMenuUI.showKeyboardFocus = false  -- 只在键盘操作时显示选中框

-- ============================================================================
-- 布局配置（独立调整，互不影响）
-- ============================================================================
MainMenuUI.Layout = {
    -- Logo 配置
    LOGO_WIDTH = 0.85,         -- Logo 宽度占屏幕宽度的比例
    LOGO_ASPECT = 913 / 502,   -- Logo 宽高比（宽/高）= 1.82
    LOGO_CENTER_Y = 0.28,      -- Logo 中心在屏幕高度的位置（0=顶部, 1=底部）
    
    -- 按钮配置（基于 baseUnit 的相对大小，横屏竖屏视觉比例一致）
    BTN_START_Y = 0.6,         -- 按钮区域起始位置（屏幕高度的比例）
    BTN_W_RATIO = 0.3,         -- 按钮宽度（安全区宽度的比例）
    BTN_H_UNITS = 2.8,         -- 按钮高度（baseUnit 的倍数）
    BTN_H_UNITS_COMPACT = 2.4, -- 按钮高度（>4个按钮时）
    BTN_GAP_UNITS = 1.2,       -- 按钮间距（baseUnit 的倍数）
    BTN_GAP_UNITS_COMPACT = 0.8, -- 按钮间距（>4个按钮时）
    BTN_FONT_UNITS = 1.2,      -- 按钮文字大小（baseUnit 的倍数）
}

-- 按钮列表
MainMenuUI.buttons = {}

-- 星空背景粒子
MainMenuUI.stars = {}

-- 流动光线
MainMenuUI.flowLines = {}

-- 标题动画
MainMenuUI.titlePulse = 0

-- Logo 图片
MainMenuUI.logoImage = nil
MainMenuUI.logoLoaded = false
MainMenuUI.nvg = nil  -- NanoVG 上下文引用（用于清理）

-- 安全区缓存（用于输入处理）
MainMenuUI.safeArea = nil

-- ============================================================================
-- 版本号
-- ============================================================================
MainMenuUI.VERSION = "v1.0.0"

-- ============================================================================
-- 初始化
-- ============================================================================

function MainMenuUI.Init()
    MainMenuUI.animTime = 0
    MainMenuUI.selectedIndex = 1
    MainMenuUI.titlePulse = 0
    MainMenuUI.showKeyboardFocus = false  -- 默认不显示选中框
    
    -- 初始化按钮列表
    MainMenuUI.UpdateButtons()
    
    -- 优化：只在首次或被清理后才初始化星空和光线
    -- 避免每次 Show() 都重新创建
    if #MainMenuUI.stars == 0 then
        MainMenuUI.InitStars()
    end
    
    if #MainMenuUI.flowLines == 0 then
        MainMenuUI.InitFlowLines()
    end
end

function MainMenuUI.UpdateButtons()
    MainMenuUI.buttons = {}
    
    -- 有存档时：继续游戏排第一且推荐
    -- 无存档时：开始游戏排第一且推荐
    if MainMenuUI.hasSaveData then
        table.insert(MainMenuUI.buttons, {
            id = "continue",
            text = "继续游戏",
            callback = MainMenuUI.onContinue,
            recommended = true,  -- 推荐按钮
        })
        table.insert(MainMenuUI.buttons, {
            id = "start",
            text = "开始游戏",
            callback = MainMenuUI.onStartGame,
        })
    else
        table.insert(MainMenuUI.buttons, {
            id = "start",
            text = "开始游戏",
            callback = MainMenuUI.onStartGame,
            recommended = true,  -- 推荐按钮
        })
    end
    
    table.insert(MainMenuUI.buttons, {
        id = "options",
        text = "选项",
        callback = MainMenuUI.onOptions,
    })
    
    table.insert(MainMenuUI.buttons, {
        id = "gallery",
        text = "图鉴",
        callback = MainMenuUI.onGallery,
    })
end

function MainMenuUI.InitStars()
    MainMenuUI.stars = {}
    for i = 1, 100 do
        table.insert(MainMenuUI.stars, {
            x = math.random(),
            y = math.random(),
            size = 0.5 + math.random() * 1.5,
            brightness = 0.3 + math.random() * 0.7,
            twinkleSpeed = 1 + math.random() * 2,
            twinkleOffset = math.random() * math.pi * 2,
        })
    end
end

function MainMenuUI.InitFlowLines()
    MainMenuUI.flowLines = {}
    for i = 1, 6 do
        table.insert(MainMenuUI.flowLines, {
            progress = math.random(),
            speed = 0.05 + math.random() * 0.1,
            pathIndex = i,
            alpha = 0.3 + math.random() * 0.4,
        })
    end
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function MainMenuUI.Show(callbacks)
    print("[MainMenuUI] Show called")
    callbacks = callbacks or {}
    MainMenuUI.visible = true
    MainMenuUI.onStartGame = callbacks.onStartGame
    MainMenuUI.onContinue = callbacks.onContinue
    MainMenuUI.onOptions = callbacks.onOptions
    MainMenuUI.onGallery = callbacks.onGallery
    MainMenuUI.onTest = callbacks.onTest
    MainMenuUI.hasSaveData = callbacks.hasSaveData or false
    MainMenuUI.Init()
    print("[MainMenuUI] Show complete, visible = " .. tostring(MainMenuUI.visible))
end

function MainMenuUI.Hide()
    MainMenuUI.visible = false
end

-- 清理资源（在退出游戏或切换场景时调用）
function MainMenuUI.Cleanup()
    -- 🔴 关键：释放 NanoVG 图片内存
    if MainMenuUI.nvg and MainMenuUI.logoImage and MainMenuUI.logoImage > 0 then
        nvgDeleteImage(MainMenuUI.nvg, MainMenuUI.logoImage)
        print("[MainMenuUI] Deleted logo image")
    end
    MainMenuUI.logoImage = nil
    MainMenuUI.logoLoaded = false
    MainMenuUI.nvg = nil
    MainMenuUI.visible = false
    MainMenuUI.stars = {}
    MainMenuUI.flowLines = {}
    MainMenuUI.safeArea = nil
end

-- ============================================================================
-- 输入处理
-- ============================================================================

function MainMenuUI.HandleInput()
    if not MainMenuUI.visible then return false end
    
    -- 上下选择（允许选择禁用按钮，只是不能点击）
    if input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) then
        MainMenuUI.showKeyboardFocus = true  -- 键盘操作时显示选中框
        MainMenuUI.selectedIndex = MainMenuUI.selectedIndex - 1
        if MainMenuUI.selectedIndex < 1 then
            MainMenuUI.selectedIndex = #MainMenuUI.buttons
        end
        return true
    end
    
    if input:GetKeyPress(KEY_DOWN) or input:GetKeyPress(KEY_S) then
        MainMenuUI.showKeyboardFocus = true  -- 键盘操作时显示选中框
        MainMenuUI.selectedIndex = MainMenuUI.selectedIndex + 1
        if MainMenuUI.selectedIndex > #MainMenuUI.buttons then
            MainMenuUI.selectedIndex = 1
        end
        return true
    end
    
    -- 确认（禁用按钮不能点击）
    if input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_SPACE) then
        MainMenuUI.showKeyboardFocus = true  -- 键盘操作时显示选中框
        local btn = MainMenuUI.buttons[MainMenuUI.selectedIndex]
        if btn and not btn.disabled and btn.callback then
            btn.callback()
            return true
        end
    end
    
    return false
end

function MainMenuUI.HandleTouch(sw, sh)
    if not MainMenuUI.visible then return false end
    
    -- 鼠标按下：检测按钮按下状态
    if UIScreen.IsMousePressed() then
        MainMenuUI.showKeyboardFocus = false  -- 鼠标/触摸操作时隐藏选中框
        return UIScreen.HandleTouch(sw, sh, MainMenuUI, MainMenuUI.OnPress)
    end
    
    -- 鼠标释放：检测按钮触发
    if UIScreen.IsMouseReleased() then
        return UIScreen.HandleTouch(sw, sh, MainMenuUI, MainMenuUI.OnRelease)
    end
    
    return false
end

--- 鼠标按下处理（设置按钮按下状态）
function MainMenuUI.OnPress(mx, my, uw, uh, safe)
    local L = MainMenuUI.Layout
    local baseUnit = safe.baseUnit
    
    -- 按钮尺寸
    local btnW = uw * L.BTN_W_RATIO
    local btnCount = #MainMenuUI.buttons
    local btnH = baseUnit * (btnCount > 4 and L.BTN_H_UNITS_COMPACT or L.BTN_H_UNITS)
    local gap = baseUnit * (btnCount > 4 and L.BTN_GAP_UNITS_COMPACT or L.BTN_GAP_UNITS)
    
    -- 按钮位置
    local startY = uh * L.BTN_START_Y
    local btnX = (uw - btnW) / 2
    
    for i, btn in ipairs(MainMenuUI.buttons) do
        local btnY = startY + (i - 1) * (btnH + gap)
        local buttonId = "mainmenu_" .. btn.id
        
        if UIScreen.CheckButtonPress(mx, my, buttonId, btnX, btnY, btnW, btnH) then
            MainMenuUI.selectedIndex = i
            return true
        end
    end
    
    -- 版本号点击区域（隐藏入口）
    local versionW = baseUnit * 6
    local versionH = baseUnit * 2
    local versionX = uw - baseUnit * 1.5 - versionW
    local versionY = uh - baseUnit * 1 - versionH
    
    if UIScreen.CheckButtonPress(mx, my, "mainmenu_version", versionX, versionY, versionW, versionH) then
        return true
    end
    
    return false
end

--- 鼠标释放处理（触发按钮回调）
function MainMenuUI.OnRelease(mx, my, uw, uh, safe)
    local baseUnit = safe.baseUnit
    
    -- 检查按钮点击
    for i, btn in ipairs(MainMenuUI.buttons) do
        local buttonId = "mainmenu_" .. btn.id
        
        if UIScreen.CheckButtonRelease(mx, my, buttonId) then
            if not btn.disabled and btn.callback then
                btn.callback()
            end
            return true
        end
    end
    
    -- 检查版本号点击（隐藏入口）
    if UIScreen.CheckButtonRelease(mx, my, "mainmenu_version") then
        if MainMenuUI.onTest then
            MainMenuUI.onTest()
        end
        return true
    end
    
    return false
end

-- ============================================================================
-- 渲染
-- ============================================================================

function MainMenuUI.Render(nvg, sw, sh)
    if not MainMenuUI.visible then return end
    
    -- 保存 NanoVG 上下文引用（用于 Cleanup 释放图片）
    MainMenuUI.nvg = nvg
    
    -- 更新动画状态
    MainMenuUI.animTime = MainMenuUI.animTime + 0.016
    MainMenuUI.titlePulse = MainMenuUI.titlePulse + 0.016
    
    -- 更新流动光线
    for _, line in ipairs(MainMenuUI.flowLines) do
        line.progress = line.progress + line.speed * 0.016
        if line.progress > 1 then line.progress = 0 end
    end
    
    -- 使用 UIScreen 标准渲染流程
    UIScreen.Render(nvg, sw, sh, MainMenuUI, {
        drawBackground = MainMenuUI.DrawFullscreenBackground,
        drawContent = MainMenuUI.DrawContent,
        useMask = false,  -- 主菜单背景全屏显示，不绘制遮罩
    })
end

--- 全屏背景绘制（在安全区外也绘制）
function MainMenuUI.DrawFullscreenBackground(nvg, sw, sh, baseUnit)
    MainMenuUI.DrawBackground(nvg, sw, sh, baseUnit)
    MainMenuUI.DrawStars(nvg, sw, sh, baseUnit)
end

--- 安全区内容绘制
function MainMenuUI.DrawContent(nvg, uw, uh, baseUnit, fonts, safe)
    -- 装饰电路
    MainMenuUI.DrawCircuitDecor(nvg, uw, uh, baseUnit)
    
    -- 流动光线
    MainMenuUI.DrawFlowLines(nvg, uw, uh, baseUnit)
    
    -- 标题
    MainMenuUI.DrawTitle(nvg, uw, uh, baseUnit, fonts)
    
    -- 菜单按钮
    MainMenuUI.DrawButtons(nvg, uw, uh, baseUnit, fonts)
    
    -- 用户ID（左下角）
    MainMenuUI.DrawUserId(nvg, uw, uh, baseUnit, fonts)
    
    -- 版本号（右下角）
    MainMenuUI.DrawVersion(nvg, uw, uh, baseUnit, fonts)
end

-- ============================================================================
-- 背景绘制
-- ============================================================================

function MainMenuUI.DrawBackground(nvg, sw, sh, baseUnit)
    -- 深空渐变背景（蓝紫色调，匹配 Logo）
    local bgGrad = nvgLinearGradient(nvg, 0, 0, 0, sh,
        nvgRGBA(12, 16, 32, 255),   -- 顶部：深蓝紫
        nvgRGBA(6, 10, 22, 255))    -- 底部：更深
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillPaint(nvg, bgGrad)
    nvgFill(nvg)
    
    -- 径向渐变（中心蓝紫微亮，匹配 Logo）
    local centerGlow = nvgRadialGradient(nvg, sw / 2, sh * 0.35, 0, sh * 0.6,
        nvgRGBA(40, 60, 120, 25),   -- 蓝紫色光晕
        nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillPaint(nvg, centerGlow)
    nvgFill(nvg)
end

function MainMenuUI.DrawStars(nvg, sw, sh, baseUnit)
    for _, star in ipairs(MainMenuUI.stars) do
        local twinkle = 0.5 + 0.5 * math.sin(MainMenuUI.animTime * star.twinkleSpeed + star.twinkleOffset)
        local alpha = star.brightness * twinkle * 255
        
        local x = star.x * sw
        local y = star.y * sh
        local size = star.size
        
        -- 星光
        nvgBeginPath(nvg)
        nvgCircle(nvg, x, y, size)
        nvgFillColor(nvg, nvgRGBA(200, 220, 255, alpha))
        nvgFill(nvg)
        
        -- 大星星加发光
        if star.size > 1.2 then
            local glow = nvgRadialGradient(nvg, x, y, 0, size * 3,
                nvgRGBA(150, 180, 255, alpha * 0.3),
                nvgRGBA(150, 180, 255, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, x, y, size * 3)
            nvgFillPaint(nvg, glow)
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- 装饰电路
-- ============================================================================

function MainMenuUI.DrawCircuitDecor(nvg, sw, sh, baseUnit)
    local lineColor = nvgRGBA(40, 80, 120, 60)
    local nodeColor = nvgRGBA(60, 120, 180, 100)
    
    nvgStrokeColor(nvg, lineColor)
    nvgStrokeWidth(nvg, 1.5)
    
    -- 左上角电路
    MainMenuUI.DrawCornerCircuit(nvg, 0, 0, baseUnit, 1, 1, lineColor, nodeColor)
    -- 右上角电路
    MainMenuUI.DrawCornerCircuit(nvg, sw, 0, baseUnit, -1, 1, lineColor, nodeColor)
    -- 左下角电路
    MainMenuUI.DrawCornerCircuit(nvg, 0, sh, baseUnit, 1, -1, lineColor, nodeColor)
    -- 右下角电路
    MainMenuUI.DrawCornerCircuit(nvg, sw, sh, baseUnit, -1, -1, lineColor, nodeColor)
    
    -- 中央装饰线
    local midY = sh * 0.38
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sw * 0.15, midY)
    nvgLineTo(nvg, sw * 0.35, midY)
    nvgStroke(nvg)
    
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sw * 0.65, midY)
    nvgLineTo(nvg, sw * 0.85, midY)
    nvgStroke(nvg)
    
    -- 装饰节点
    nvgFillColor(nvg, nodeColor)
    nvgBeginPath(nvg)
    nvgCircle(nvg, sw * 0.35, midY, 3)
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, sw * 0.65, midY, 3)
    nvgFill(nvg)
end

function MainMenuUI.DrawCornerCircuit(nvg, ox, oy, baseUnit, dx, dy, lineColor, nodeColor)
    nvgStrokeColor(nvg, lineColor)
    nvgStrokeWidth(nvg, 1.5)
    
    -- L形主线
    local len1, len2 = baseUnit * 10, baseUnit * 8
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, ox, oy + dy * len1)
    nvgLineTo(nvg, ox, oy)
    nvgLineTo(nvg, ox + dx * len2, oy)
    nvgStroke(nvg)
    
    -- 分支
    nvgStrokeWidth(nvg, 1)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, ox + dx * baseUnit * 3, oy)
    nvgLineTo(nvg, ox + dx * baseUnit * 3, oy + dy * baseUnit * 3)
    nvgLineTo(nvg, ox + dx * baseUnit * 5, oy + dy * baseUnit * 3)
    nvgStroke(nvg)
    
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, ox, oy + dy * baseUnit * 4)
    nvgLineTo(nvg, ox + dx * baseUnit * 4, oy + dy * baseUnit * 4)
    nvgLineTo(nvg, ox + dx * baseUnit * 4, oy + dy * baseUnit * 7)
    nvgStroke(nvg)
    
    -- 节点
    local nodes = {
        {ox + dx * baseUnit * 3, oy},
        {ox, oy + dy * baseUnit * 4},
        {ox + dx * baseUnit * 5, oy + dy * baseUnit * 3},
        {ox + dx * baseUnit * 4, oy + dy * baseUnit * 7},
    }
    
    local glowAlpha = 60 + 30 * math.sin(MainMenuUI.animTime * 2)
    nvgFillColor(nvg, nvgRGBA(60, 140, 200, glowAlpha))
    
    for _, node in ipairs(nodes) do
        nvgBeginPath(nvg)
        nvgCircle(nvg, node[1], node[2], 4)
        nvgFill(nvg)
        
        nvgBeginPath(nvg)
        nvgCircle(nvg, node[1], node[2], 2)
        nvgFillColor(nvg, nodeColor)
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 流动光线
-- ============================================================================

function MainMenuUI.DrawFlowLines(nvg, sw, sh, baseUnit)
    -- 定义流动路径
    local paths = {
        {{sw * 0.15, sh * 0.38}, {sw * 0.35, sh * 0.38}},
        {{sw * 0.85, sh * 0.38}, {sw * 0.65, sh * 0.38}},
        {{0, sh * 0.5}, {sw * 0.1, sh * 0.5}},
        {{sw, sh * 0.5}, {sw * 0.9, sh * 0.5}},
        {{sw * 0.3, 0}, {sw * 0.3, sh * 0.08}},
        {{sw * 0.7, sh}, {sw * 0.7, sh * 0.92}},
    }
    
    for i, line in ipairs(MainMenuUI.flowLines) do
        local path = paths[line.pathIndex]
        if path then
            local t = line.progress
            local x = path[1][1] + (path[2][1] - path[1][1]) * t
            local y = path[1][2] + (path[2][2] - path[1][2]) * t
            
            -- 拖尾
            for j = 4, 1, -1 do
                local tt = t - j * 0.03
                if tt >= 0 then
                    local tx = path[1][1] + (path[2][1] - path[1][1]) * tt
                    local ty = path[1][2] + (path[2][2] - path[1][2]) * tt
                    local alpha = line.alpha * (5 - j) * 40
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, tx, ty, 2 - j * 0.3)
                    nvgFillColor(nvg, nvgRGBA(100, 180, 255, alpha))
                    nvgFill(nvg)
                end
            end
            
            -- 主光点
            nvgBeginPath(nvg)
            nvgCircle(nvg, x, y, 3)
            nvgFillColor(nvg, nvgRGBA(150, 220, 255, line.alpha * 255))
            nvgFill(nvg)
            
            -- 发光
            local glow = nvgRadialGradient(nvg, x, y, 0, 10,
                nvgRGBA(100, 180, 255, line.alpha * 150),
                nvgRGBA(100, 180, 255, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, x, y, 10)
            nvgFillPaint(nvg, glow)
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- 标题绘制
-- ============================================================================

function MainMenuUI.DrawTitle(nvg, sw, sh, baseUnit, fonts)
    -- DWP-safe: 仅在资源已下载到本地时创建 NVG 图片，避免占位符闪烁
    if not MainMenuUI.logoLoaded then
        if cache:Exists("image/logo.png") then
            MainMenuUI.logoImage = nvgCreateImage(nvg, "image/logo.png", 0)
            MainMenuUI.logoLoaded = true
        end
        -- 资源未就绪时不创建，下一帧重试
    end
    
    local L = MainMenuUI.Layout
    
    -- Logo 尺寸和位置（支持非正方形，适配横竖屏）
    local isPortrait = sh > sw
    local logoW
    if isPortrait then
        logoW = sw * L.LOGO_WIDTH  -- 竖屏：按屏幕宽度 85%
    else
        logoW = sh * L.LOGO_WIDTH  -- 横屏：按屏幕高度 85%（保持 Logo 不会太大）
    end
    local logoH = logoW / L.LOGO_ASPECT
    local logoX = (sw - logoW) / 2
    local logoCenterY = sh * L.LOGO_CENTER_Y
    local logoY = logoCenterY - logoH / 2
    
    -- 绘制 Logo 图片
    if MainMenuUI.logoImage and MainMenuUI.logoImage > 0 then
        -- 极微弱的呼吸动画
        local pulse = 1.0 + 0.005 * math.sin(MainMenuUI.titlePulse * 0.8)
        local actualW = logoW * pulse
        local actualH = logoH * pulse
        local actualX = (sw - actualW) / 2
        local actualY = logoCenterY - actualH / 2
        
        -- 绘制 Logo（无发光效果）
        local imgPaint = nvgImagePattern(nvg, actualX, actualY, actualW, actualH, 0, MainMenuUI.logoImage, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, actualX, actualY, actualW, actualH)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)
    else
        -- 回退：如果图片加载失败，显示文字标题
        local titleY = sh * 0.20
        
        nvgFontSize(nvg, fonts.pageTitle * 1.8)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        nvgText(nvg, sw / 2, titleY, "星河战姬")
        
        local subY = titleY + fonts.pageTitle * 1.2
        nvgFontSize(nvg, fonts.pageSubtitle * 1.4)
        nvgFillColor(nvg, nvgRGBA(100, 160, 220, 200))
        nvgText(nvg, sw / 2, subY, "STARKYRIES")
    end
end

-- ============================================================================
-- 按钮绘制
-- ============================================================================

function MainMenuUI.DrawButtons(nvg, sw, sh, baseUnit, fonts)
    local L = MainMenuUI.Layout
    
    -- 按钮尺寸（基于 baseUnit 的相对大小）
    local btnW = sw * L.BTN_W_RATIO
    local btnCount = #MainMenuUI.buttons
    local btnH = baseUnit * (btnCount > 4 and L.BTN_H_UNITS_COMPACT or L.BTN_H_UNITS)
    local gap = baseUnit * (btnCount > 4 and L.BTN_GAP_UNITS_COMPACT or L.BTN_GAP_UNITS)
    local fontSize = baseUnit * L.BTN_FONT_UNITS
    
    -- 按钮位置（独立配置）
    local startY = sh * L.BTN_START_Y
    local btnX = (sw - btnW) / 2
    
    -- 获取鼠标在安全区的本地坐标（用于按下状态检测）
    local mx, my = UIScreen.GetLocalMouse(MainMenuUI, sw, sh)
    
    for i, btn in ipairs(MainMenuUI.buttons) do
        local btnY = startY + (i - 1) * (btnH + gap)
        -- 键盘选中状态
        local isKeyboardSelected = MainMenuUI.showKeyboardFocus and (i == MainMenuUI.selectedIndex)
        
        -- 只有 2 种颜色：推荐色 和 普通色
        local variant = btn.recommended and "recommended" or "normal"
        
        -- 检查按钮是否处于按下状态
        local buttonId = "mainmenu_" .. btn.id
        local isPressed = mx and my and UIScreen.ShouldShowPressed(mx, my, buttonId)
        
        -- 光效逻辑：键盘操作时跟随选中，否则显示在推荐按钮上
        local showGlowAnim = MainMenuUI.showKeyboardFocus and isKeyboardSelected or (not MainMenuUI.showKeyboardFocus and btn.recommended)
        
        -- 使用统一的科技风格按钮（固定字体大小）
        UIStyle.DrawSciFiButton(nvg, btnX, btnY, btnW, btnH, btn.text, {
            baseUnit = baseUnit,
            animTime = showGlowAnim and MainMenuUI.animTime or 0,
            variant = variant,
            disabled = btn.disabled,
            fontSize = fontSize,
            pressed = isPressed,
        })
    end
end

-- ============================================================================
-- 用户ID（左下角）
-- ============================================================================

function MainMenuUI.DrawUserId(nvg, sw, sh, baseUnit, fonts)
    -- 获取用户ID
    local userId = clientScore and clientScore.userId or nil
    if not userId then return end
    
    local idText = "ID: " .. tostring(userId)
    
    nvgFontSize(nvg, fonts.hintText)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_BOTTOM)
    nvgFillColor(nvg, nvgRGBA(80, 100, 120, 180))
    nvgText(nvg, baseUnit * 1.5, sh - baseUnit * 1, idText)
end

-- ============================================================================
-- 版本号（右下角）
-- ============================================================================

function MainMenuUI.DrawVersion(nvg, sw, sh, baseUnit, fonts)
    nvgFontSize(nvg, fonts.hintText)
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    nvgFillColor(nvg, nvgRGBA(80, 100, 120, 180))
    nvgText(nvg, sw - baseUnit * 1.5, sh - baseUnit * 1, MainMenuUI.VERSION)
end

return MainMenuUI
