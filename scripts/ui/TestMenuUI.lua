-- ============================================================================
-- 星河战姬 Starkyries - 测试菜单
-- 用于快速跳转到各种测试场景
-- ============================================================================

local UIStyle = require("ui.UIStyle")
local UIScreen = require("ui.UIScreen")
local UISafeArea = require("ui.UISafeArea")
local TouchInput = require("utils.TouchInput")

local TestMenuUI = {}

-- ============================================================================
-- 状态
-- ============================================================================
TestMenuUI.visible = false
TestMenuUI.selectedIndex = 1
TestMenuUI.animTime = 0
TestMenuUI.onClose = nil
TestMenuUI.justShown = false  -- 防止点击按钮后立即关闭

-- 测试选项列表
TestMenuUI.options = {
    { id = "wave10_preconfigured", name = "🎮 第10波快速测试", description = "预配置先锋号+6个T3集束导弹，直接开始第10波", highlight = true },
    { id = "wave20_preconfigured", name = "🎮 第20波快速测试", description = "预配置先锋号+6个T4轰炸无人机，直接开始第20波", highlight = true },
    { id = "wave10_test", name = "第10波测试", description = "直接进入第10波，自带增强属性（需自行选船/加点）" },
    { id = "enemy_test", name = "🎯 残骸测试", description = "先锋号+1个T1粒子机炮，生成5个残骸", highlight = true },
    { id = "dialogue", name = "对话系统测试", description = "测试对话UI和基础逻辑" },
    { id = "reset_tutorial", name = "重置新手引导", description = "重置教程进度，下次开始游戏将播放开场对话" },
    { id = "invincible", name = "无敌模式", description = "开启后血量最低为1，不会死亡", toggle = true },
    { id = "preload_verbose", name = "预加载调试", description = "开启后在控制台输出后台预加载进度信息", toggle = true },
}

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function TestMenuUI.Show(onClose)
    print("[TestMenuUI] Show() called, setting visible = true")
    TestMenuUI.visible = true
    TestMenuUI.selectedIndex = 1
    TestMenuUI.animTime = 0
    TestMenuUI.onClose = onClose
    TestMenuUI.justShown = true  -- 标记刚显示，防止立即被关闭
end

function TestMenuUI.Hide()
    TestMenuUI.visible = false
    if TestMenuUI.onClose then
        TestMenuUI.onClose()
    end
end

function TestMenuUI.IsVisible()
    return TestMenuUI.visible
end

-- ============================================================================
-- 选择测试项
-- ============================================================================

function TestMenuUI.SelectOption(index)
    local option = TestMenuUI.options[index]
    if option then
        -- 返回选中的测试ID，由外部处理具体逻辑
        return option.id
    end
    return nil
end

-- ============================================================================
-- 输入处理
-- ============================================================================

function TestMenuUI.HandleInput()
    if not TestMenuUI.visible then return false end
    
    -- 刚显示时，忽略第一帧的键盘输入（防止 Enter 被处理两次）
    if TestMenuUI.justShown then
        return false
    end
    
    -- 上下选择
    if input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) then
        TestMenuUI.selectedIndex = TestMenuUI.selectedIndex - 1
        if TestMenuUI.selectedIndex < 1 then
            TestMenuUI.selectedIndex = #TestMenuUI.options
        end
        return true
    end
    
    if input:GetKeyPress(KEY_DOWN) or input:GetKeyPress(KEY_S) then
        TestMenuUI.selectedIndex = TestMenuUI.selectedIndex + 1
        if TestMenuUI.selectedIndex > #TestMenuUI.options then
            TestMenuUI.selectedIndex = 1
        end
        return true
    end
    
    -- 确认选择
    if input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_SPACE) then
        local optionId = TestMenuUI.SelectOption(TestMenuUI.selectedIndex)
        if optionId then
            TestMenuUI.HandleTestAction(optionId)
        end
        return true
    end
    
    -- ESC 返回
    if input:GetKeyPress(KEY_ESCAPE) then
        TestMenuUI.Hide()
        return true
    end
    
    return false
end

-- ============================================================================
-- 触摸/鼠标处理
-- ============================================================================

function TestMenuUI.HandleTouch(sw, sh)
    if not TestMenuUI.visible then return false end
    
    -- 刚显示时，等待用户释放触摸后再响应点击
    if TestMenuUI.justShown then
        if not input:GetMouseButtonDown(MOUSEB_LEFT) then
            TestMenuUI.justShown = false
        end
        return false
    end
    
    -- 获取安全区（使用缓存或重新计算）
    local safe = TestMenuUI.safeArea or UISafeArea.Calculate(sw, sh)
    
    -- 获取屏幕坐标
    local screenX = TouchInput.x
    local screenY = TouchInput.y
    
    -- 检查是否在安全区内
    if not UISafeArea.Contains(safe, screenX, screenY) then
        return false
    end
    
    -- 转换到安全区本地坐标
    local mx, my = UISafeArea.ToLocal(safe, screenX, screenY)
    
    -- 使用安全区尺寸
    local uw, uh = safe.w, safe.h
    local baseUnit = safe.baseUnit
    
    if UIScreen.IsMousePressed() then
        -- 全屏布局参数
        local margin = baseUnit * 2
        local headerH = baseUnit * 5
        local footerH = baseUnit * 3
        local contentY = headerH + baseUnit
        local contentH = uh - headerH - footerH - baseUnit * 2
        
        -- 选项列表区域（左侧55%）
        local listX = margin
        local listW = uw * 0.55
        local itemH = baseUnit * 3.5
        local itemGap = baseUnit * 0.5
        
        -- 检查选项点击
        for i, option in ipairs(TestMenuUI.options) do
            local itemY = contentY + (i - 1) * (itemH + itemGap)
            if UIScreen.HitTest(mx, my, listX, itemY, listW, itemH) then
                TestMenuUI.selectedIndex = i
                local optionId = TestMenuUI.SelectOption(i)
                if optionId then
                    TestMenuUI.HandleTestAction(optionId)
                end
                return true
            end
        end
        
        -- 检查关闭按钮（右上角）
        local closeBtnX = uw - baseUnit * 3
        local closeBtnY = headerH / 2
        local closeBtnRadius = baseUnit * 1.2
        -- 使用圆形点击检测
        local dx = mx - closeBtnX
        local dy = my - closeBtnY
        if dx * dx + dy * dy <= closeBtnRadius * closeBtnRadius then
            TestMenuUI.Hide()
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- 处理测试动作（占位，由外部设置具体实现）
-- ============================================================================

TestMenuUI.testHandlers = {}
TestMenuUI.toggleStateGetters = {}  -- 用于获取开关选项当前状态

function TestMenuUI.SetTestHandler(id, handler)
    TestMenuUI.testHandlers[id] = handler
end

function TestMenuUI.SetToggleStateGetter(id, getter)
    TestMenuUI.toggleStateGetters[id] = getter
end

function TestMenuUI.GetToggleState(id)
    local getter = TestMenuUI.toggleStateGetters[id]
    if getter then
        return getter()
    end
    return false
end

function TestMenuUI.HandleTestAction(optionId)
    local handler = TestMenuUI.testHandlers[optionId]
    if handler then
        handler()
        -- 开关选项不关闭菜单，方便多次切换
        local option = nil
        for _, opt in ipairs(TestMenuUI.options) do
            if opt.id == optionId then
                option = opt
                break
            end
        end
        if not (option and option.toggle) then
            TestMenuUI.Hide()
        end
    else
        print("[TestMenuUI] 未实现的测试: " .. optionId)
    end
end

-- ============================================================================
-- 渲染
-- ============================================================================

-- 缓存安全区信息（用于输入处理）
TestMenuUI.safeArea = nil

function TestMenuUI.Render(nvg, sw, sh)
    if not TestMenuUI.visible then return end
    
    TestMenuUI.animTime = TestMenuUI.animTime + 0.016
    
    -- 全屏背景
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(15, 20, 35, 250))
    nvgFill(nvg)
    
    -- 计算安全区
    local safe = UISafeArea.Calculate(sw, sh)
    TestMenuUI.safeArea = safe
    
    -- 使用安全区尺寸
    local uw, uh = safe.w, safe.h
    local baseUnit = safe.baseUnit
    local fonts = UIStyle.GetTypography(uw, uh)
    
    -- 进入安全区绘制
    UISafeArea.BeginSafeArea(nvg, safe)
    
    -- 全屏布局参数（相对于安全区）
    local margin = baseUnit * 2
    local headerH = baseUnit * 5
    local footerH = baseUnit * 3
    
    -- ========== 头部区域 ==========
    -- 标题
    nvgFontSize(nvg, fonts.pageTitle * 1.2)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 200, 100, 255))
    nvgText(nvg, margin, headerH / 2, "🔧 测试菜单")
    
    -- 副标题
    nvgFontSize(nvg, fonts.bodyText)
    nvgFillColor(nvg, nvgRGBA(150, 150, 150, 200))
    nvgText(nvg, margin + baseUnit * 12, headerH / 2, "快速跳转到各种测试场景")
    
    -- 关闭按钮（右上角）
    local closeBtnX = uw - baseUnit * 3
    local closeBtnY = headerH / 2
    nvgBeginPath(nvg)
    nvgCircle(nvg, closeBtnX, closeBtnY, baseUnit * 1.2)
    nvgFillColor(nvg, nvgRGBA(80, 40, 40, 200))
    nvgFill(nvg)
    nvgFontSize(nvg, fonts.cardTitle)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 100, 100, 255))
    nvgText(nvg, closeBtnX, closeBtnY, "✕")
    
    -- 头部分隔线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, margin, headerH)
    nvgLineTo(nvg, uw - margin, headerH)
    nvgStrokeColor(nvg, nvgRGBA(60, 80, 120, 150))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- ========== 内容区域（左侧列表 + 右侧详情）==========
    local contentY = headerH + baseUnit
    local contentH = uh - headerH - footerH - baseUnit * 2
    
    -- 左侧：选项列表（55%宽度）
    local listX = margin
    local listW = uw * 0.55
    local itemH = baseUnit * 3.5
    local itemGap = baseUnit * 0.5
    
    for i, option in ipairs(TestMenuUI.options) do
        local itemY = contentY + (i - 1) * (itemH + itemGap)
        local isSelected = (i == TestMenuUI.selectedIndex)
        
        -- 选项背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, listX, itemY, listW, itemH, baseUnit * 0.4)
        
        if option.highlight then
            -- 高亮选项（推荐）
            if isSelected then
                local pulse = 0.8 + 0.2 * math.sin(TestMenuUI.animTime * 4)
                nvgFillColor(nvg, nvgRGBA(80, 140, 60, math.floor(180 * pulse)))
            else
                nvgFillColor(nvg, nvgRGBA(50, 90, 40, 150))
            end
        elseif isSelected then
            -- 选中状态
            local pulse = 0.7 + 0.3 * math.sin(TestMenuUI.animTime * 3)
            nvgFillColor(nvg, nvgRGBA(60, 100, 180, math.floor(120 * pulse)))
        else
            nvgFillColor(nvg, nvgRGBA(35, 45, 65, 180))
        end
        nvgFill(nvg)
        
        -- 选中边框
        if isSelected then
            nvgStrokeColor(nvg, option.highlight and nvgRGBA(120, 220, 100, 255) or nvgRGBA(100, 180, 255, 255))
            nvgStrokeWidth(nvg, 2)
            nvgStroke(nvg)
        end
        
        -- 选项名称
        nvgFontSize(nvg, fonts.cardTitle)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        
        if option.highlight then
            nvgFillColor(nvg, nvgRGBA(180, 255, 150, 255))
        elseif isSelected then
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        else
            nvgFillColor(nvg, nvgRGBA(200, 200, 200, 255))
        end
        
        -- 如果是开关选项，显示当前状态
        if option.toggle then
            local state = TestMenuUI.GetToggleState(option.id)
            nvgText(nvg, listX + baseUnit, itemY + itemH * 0.35, option.name)
            
            -- 在右侧显示状态
            local stateText = state and "● 开启" or "○ 关闭"
            local stateColor = state and nvgRGBA(100, 255, 100, 255) or nvgRGBA(150, 150, 150, 200)
            nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, stateColor)
            nvgText(nvg, listX + listW - baseUnit, itemY + itemH * 0.35, stateText)
            nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        else
            nvgText(nvg, listX + baseUnit, itemY + itemH * 0.35, option.name)
        end
        
        -- 选项描述
        nvgFontSize(nvg, fonts.description)
        nvgFillColor(nvg, nvgRGBA(140, 150, 170, 200))
        nvgText(nvg, listX + baseUnit, itemY + itemH * 0.72, option.description)
    end
    
    -- 右侧：详情面板（40%宽度）
    local detailX = listX + listW + baseUnit * 2
    local detailW = uw - detailX - margin
    local detailY = contentY
    local detailH = contentH
    
    -- 详情面板背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, detailX, detailY, detailW, detailH, baseUnit * 0.5)
    nvgFillColor(nvg, nvgRGBA(25, 35, 55, 200))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(60, 80, 120, 100))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- 详情标题
    local selectedOption = TestMenuUI.options[TestMenuUI.selectedIndex]
    if selectedOption then
        nvgFontSize(nvg, fonts.cardTitle)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(255, 220, 150, 255))
        nvgText(nvg, detailX + baseUnit, detailY + baseUnit, "📋 测试详情")
        
        -- 详情内容
        nvgFontSize(nvg, fonts.bodyText)
        nvgFillColor(nvg, nvgRGBA(200, 200, 210, 255))
        
        local textY = detailY + baseUnit * 4
        local lineH = baseUnit * 1.8
        
        -- 显示选项名称
        nvgText(nvg, detailX + baseUnit, textY, "名称: " .. (selectedOption.name or ""))
        textY = textY + lineH
        
        -- 显示描述（可能需要换行）
        nvgText(nvg, detailX + baseUnit, textY, "说明:")
        textY = textY + lineH * 0.8
        nvgFontSize(nvg, fonts.description)
        nvgFillColor(nvg, nvgRGBA(160, 170, 190, 220))
        nvgText(nvg, detailX + baseUnit, textY, selectedOption.description or "")
        
        -- 特殊提示
        if selectedOption.id == "wave10_preconfigured" then
            textY = textY + lineH * 2
            nvgFontSize(nvg, fonts.description)
            nvgFillColor(nvg, nvgRGBA(100, 200, 100, 200))
            nvgText(nvg, detailX + baseUnit, textY, "✓ 预配置舰船: 先锋号")
            textY = textY + lineH
            nvgText(nvg, detailX + baseUnit, textY, "✓ 预配置武器: 6×T3等离子喷射器")
            textY = textY + lineH
            nvgText(nvg, detailX + baseUnit, textY, "✓ 直接开始第10波战斗")
        elseif selectedOption.id == "wave20_preconfigured" then
            textY = textY + lineH * 2
            nvgFontSize(nvg, fonts.description)
            nvgFillColor(nvg, nvgRGBA(100, 200, 100, 200))
            nvgText(nvg, detailX + baseUnit, textY, "✓ 预配置舰船: 先锋号")
            textY = textY + lineH
            nvgText(nvg, detailX + baseUnit, textY, "✓ 预配置武器: 6×T4轰炸无人机")
            textY = textY + lineH
            nvgText(nvg, detailX + baseUnit, textY, "✓ 直接开始第20波战斗（虫族女王）")
        elseif selectedOption.id == "enemy_test" then
            textY = textY + lineH * 2
            nvgFontSize(nvg, fonts.description)
            nvgFillColor(nvg, nvgRGBA(100, 200, 100, 200))
            nvgText(nvg, detailX + baseUnit, textY, "✓ 预配置舰船: 先锋号")
            textY = textY + lineH
            nvgText(nvg, detailX + baseUnit, textY, "✓ 预配置武器: 6×T3粒子机炮")
            textY = textY + lineH
            nvgText(nvg, detailX + baseUnit, textY, "✓ 只生成虫族女王Boss")
        end
    end
    
    -- ========== 底部区域 ==========
    -- 底部分隔线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, margin, uh - footerH)
    nvgLineTo(nvg, uw - margin, uh - footerH)
    nvgStrokeColor(nvg, nvgRGBA(60, 80, 120, 150))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- 底部提示
    nvgFontSize(nvg, fonts.bodyText)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(120, 140, 170, 180))
    nvgText(nvg, uw / 2, uh - footerH / 2, "↑↓ 选择  |  Enter/点击 确认  |  ESC 返回")
    
    -- 结束安全区绘制
    UISafeArea.EndSafeArea(nvg)
end

return TestMenuUI
