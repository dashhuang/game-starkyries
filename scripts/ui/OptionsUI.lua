-- ============================================================================
-- 星河战姬 Starkyries - 选项菜单
-- 音量设置、语言选择
-- ============================================================================

local UIStyle = require("ui.UIStyle")
local UIScreen = require("ui.UIScreen")
local UISafeArea = require("ui.UISafeArea")
local TouchInput = require("utils.TouchInput")

local OptionsUI = {}

-- ============================================================================
-- 状态
-- ============================================================================
OptionsUI.visible = false
OptionsUI.onClose = nil
OptionsUI.animTime = 0
OptionsUI.selectedIndex = 1  -- 当前选中项
OptionsUI.showKeyboardFocus = false  -- 只在键盘操作时显示选中框

-- 设置数据
OptionsUI.settings = {
    musicVolume = 70,
    musicEnabled = true,
    sfxVolume = 90,
    sfxEnabled = true,
    languageIndex = 1,  -- 1=简体中文, 2=繁體中文, 3=English
}

-- 语言选项
OptionsUI.languages = {"简体中文", "繁體中文", "English"}

-- 菜单项定义
OptionsUI.menuItems = {
    {id = "music", type = "slider", label = "音乐"},
    {id = "sfx", type = "slider", label = "音效"},
    {id = "language", type = "select", label = "语言"},
    {id = "save", type = "button", label = "保存"},
    {id = "back", type = "button", label = "返回"},
}

-- ============================================================================
-- 初始化
-- ============================================================================

function OptionsUI.Init()
    OptionsUI.animTime = 0
    OptionsUI.selectedIndex = 1
    OptionsUI.showKeyboardFocus = false  -- 默认不显示选中框
    -- 从 Audio 模块读取当前设置
    OptionsUI.LoadSettings()
end

function OptionsUI.LoadSettings()
    -- 尝试从 Audio 模块获取当前音量设置
    local success, Audio = pcall(require, "core.Audio")
    if success and Audio then
        if Audio.GetMusicVolume then
            OptionsUI.settings.musicVolume = math.floor(Audio.GetMusicVolume() * 100)
        end
        if Audio.GetSfxVolume then
            OptionsUI.settings.sfxVolume = math.floor(Audio.GetSfxVolume() * 100)
        end
        if Audio.IsMusicEnabled then
            OptionsUI.settings.musicEnabled = Audio.IsMusicEnabled()
        end
        if Audio.IsSfxEnabled then
            OptionsUI.settings.sfxEnabled = Audio.IsSfxEnabled()
        end
    end
end

function OptionsUI.SaveSettings()
    -- 保存到 Audio 模块
    local success, Audio = pcall(require, "core.Audio")
    if success and Audio then
        if Audio.SetMusicVolume then
            Audio.SetMusicVolume(OptionsUI.settings.musicVolume / 100)
        end
        if Audio.SetSfxVolume then
            Audio.SetSfxVolume(OptionsUI.settings.sfxVolume / 100)
        end
        if Audio.SetMusicEnabled then
            Audio.SetMusicEnabled(OptionsUI.settings.musicEnabled)
        end
        if Audio.SetSfxEnabled then
            Audio.SetSfxEnabled(OptionsUI.settings.sfxEnabled)
        end
    end
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function OptionsUI.Show(onClose)
    OptionsUI.visible = true
    OptionsUI.onClose = onClose
    OptionsUI.Init()
end

function OptionsUI.Hide()
    OptionsUI.visible = false
    if OptionsUI.onClose then
        OptionsUI.onClose()
    end
end

-- ============================================================================
-- 输入处理
-- ============================================================================

function OptionsUI.HandleInput()
    if not OptionsUI.visible then return false end
    
    local item = OptionsUI.menuItems[OptionsUI.selectedIndex]
    
    -- 上下选择
    if input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) then
        OptionsUI.showKeyboardFocus = true  -- 键盘操作时显示选中框
        OptionsUI.selectedIndex = OptionsUI.selectedIndex - 1
        if OptionsUI.selectedIndex < 1 then
            OptionsUI.selectedIndex = #OptionsUI.menuItems
        end
        return true
    end
    
    if input:GetKeyPress(KEY_DOWN) or input:GetKeyPress(KEY_S) then
        OptionsUI.showKeyboardFocus = true  -- 键盘操作时显示选中框
        OptionsUI.selectedIndex = OptionsUI.selectedIndex + 1
        if OptionsUI.selectedIndex > #OptionsUI.menuItems then
            OptionsUI.selectedIndex = 1
        end
        return true
    end
    
    -- 左右调整值
    if input:GetKeyPress(KEY_LEFT) or input:GetKeyPress(KEY_A) then
        OptionsUI.showKeyboardFocus = true  -- 键盘操作时显示选中框
        OptionsUI.AdjustValue(item, -10)
        return true
    end
    
    if input:GetKeyPress(KEY_RIGHT) or input:GetKeyPress(KEY_D) then
        OptionsUI.showKeyboardFocus = true  -- 键盘操作时显示选中框
        OptionsUI.AdjustValue(item, 10)
        return true
    end
    
    -- 确认/切换
    if input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_SPACE) then
        OptionsUI.showKeyboardFocus = true  -- 键盘操作时显示选中框
        OptionsUI.ActivateItem(item)
        return true
    end
    
    -- ESC 返回
    if input:GetKeyPress(KEY_ESCAPE) then
        OptionsUI.Hide()
        return true
    end
    
    return false
end

function OptionsUI.AdjustValue(item, delta)
    if item.type == "slider" then
        if item.id == "music" then
            OptionsUI.settings.musicVolume = math.max(0, math.min(100, OptionsUI.settings.musicVolume + delta))
            OptionsUI.ApplySettingNow("music_volume")
        elseif item.id == "sfx" then
            OptionsUI.settings.sfxVolume = math.max(0, math.min(100, OptionsUI.settings.sfxVolume + delta))
            OptionsUI.ApplySettingNow("sfx_volume")
        end
    elseif item.type == "select" then
        if item.id == "language" then
            local dir = delta > 0 and 1 or -1
            OptionsUI.settings.languageIndex = OptionsUI.settings.languageIndex + dir
            if OptionsUI.settings.languageIndex < 1 then
                OptionsUI.settings.languageIndex = #OptionsUI.languages
            elseif OptionsUI.settings.languageIndex > #OptionsUI.languages then
                OptionsUI.settings.languageIndex = 1
            end
        end
    end
end

function OptionsUI.ActivateItem(item)
    if item.type == "slider" then
        -- 切换开关
        if item.id == "music" then
            OptionsUI.settings.musicEnabled = not OptionsUI.settings.musicEnabled
            OptionsUI.ApplySettingNow("music_enabled")
        elseif item.id == "sfx" then
            OptionsUI.settings.sfxEnabled = not OptionsUI.settings.sfxEnabled
            OptionsUI.ApplySettingNow("sfx_enabled")
        end
    elseif item.type == "select" then
        -- 切换到下一个选项
        OptionsUI.AdjustValue(item, 10)
    elseif item.type == "button" then
        if item.id == "save" then
            OptionsUI.SaveSettings()
            OptionsUI.Hide()
        elseif item.id == "back" then
            OptionsUI.Hide()
        end
    end
end

-- 立即应用单个设置（实时反馈）
function OptionsUI.ApplySettingNow(settingType)
    local success, Audio = pcall(require, "core.Audio")
    if not success or not Audio then return end
    
    if settingType == "music_volume" then
        if Audio.SetMusicVolume then
            Audio.SetMusicVolume(OptionsUI.settings.musicVolume / 100)
        end
    elseif settingType == "sfx_volume" then
        if Audio.SetSfxVolume then
            Audio.SetSfxVolume(OptionsUI.settings.sfxVolume / 100)
        end
    elseif settingType == "music_enabled" then
        if Audio.SetMusicEnabled then
            Audio.SetMusicEnabled(OptionsUI.settings.musicEnabled)
        end
    elseif settingType == "sfx_enabled" then
        if Audio.SetSfxEnabled then
            Audio.SetSfxEnabled(OptionsUI.settings.sfxEnabled)
        end
    end
end

function OptionsUI.HandleTouch(sw, sh)
    if not OptionsUI.visible then return false end
    
    if UIScreen.IsMousePressed() then
        OptionsUI.showKeyboardFocus = false  -- 鼠标/触摸操作时隐藏选中框
        
        -- 获取安全区信息
        local safe = OptionsUI.safeArea or UISafeArea.Calculate(sw, sh)
        
        -- 获取屏幕坐标并检查是否在安全区内
        local screenX = TouchInput.x
        local screenY = TouchInput.y
        
        if not UISafeArea.Contains(safe, screenX, screenY) then
            return false
        end
        
        -- 转换为安全区本地坐标
        local mx, my = UISafeArea.ToLocal(safe, screenX, screenY)
        
        local uw, uh = safe.w, safe.h
        local baseUnit = safe.baseUnit
        
        -- 面板尺寸（与渲染保持一致）
        local panelW = math.min(uw * 0.48, baseUnit * 28)
        local panelH = uh * 0.6
        local panelX = (uw - panelW) / 2
        local panelY = (uh - panelH) / 2
        
        local contentX = panelX + baseUnit * 1.5
        local contentW = panelW - baseUnit * 3
        local contentY = panelY + baseUnit * 4
        local itemH = baseUnit * 3
        local gap = baseUnit * 1.2
        
        -- 检测设置项点击（前3项：音乐、音效、语言）
        for i = 1, 3 do
            local item = OptionsUI.menuItems[i]
            local itemY = contentY + (i - 1) * (itemH + gap)
            
            if my >= itemY and my <= itemY + itemH and
               mx >= contentX and mx <= contentX + contentW then
                OptionsUI.selectedIndex = i
                
                -- 控件区域
                local labelW = baseUnit * 4
                local controlX = contentX + labelW + baseUnit
                local controlW = contentW - labelW - baseUnit * 1.5
                
                if item.type == "slider" then
                    -- 布局与 DrawSlider 一致
                    local toggleW = baseUnit * 2.8
                    local percentW = baseUnit * 3.5
                    local gapSmall = baseUnit * 0.6
                    local gapLarge = baseUnit * 0.8
                    local sliderW = controlW - percentW - toggleW - gapSmall - gapLarge
                    
                    local percentX = controlX + sliderW + gapSmall + percentW
                    local toggleX = percentX + gapLarge
                    
                    if mx >= toggleX then
                        -- 点击开关
                        OptionsUI.ActivateItem(item)
                    elseif mx >= controlX and mx <= controlX + sliderW then
                        -- 点击滑块
                        local ratio = (mx - controlX) / sliderW
                        local value = math.floor(ratio * 100)
                        if item.id == "music" then
                            OptionsUI.settings.musicVolume = math.max(0, math.min(100, value))
                            OptionsUI.ApplySettingNow("music_volume")
                        elseif item.id == "sfx" then
                            OptionsUI.settings.sfxVolume = math.max(0, math.min(100, value))
                            OptionsUI.ApplySettingNow("sfx_volume")
                        end
                    end
                elseif item.type == "select" then
                    OptionsUI.ActivateItem(item)
                end
                return true
            end
        end
        
        -- 检测按钮点击（使用缓存的按钮位置）
        if OptionsUI.saveBtnRect then
            local btn = OptionsUI.saveBtnRect
            if mx >= btn.x and mx <= btn.x + btn.w and
               my >= btn.y and my <= btn.y + btn.h then
                OptionsUI.selectedIndex = 4
                OptionsUI.SaveSettings()
                OptionsUI.Hide()
                return true
            end
        end
        
        if OptionsUI.backBtnRect then
            local btn = OptionsUI.backBtnRect
            if mx >= btn.x and mx <= btn.x + btn.w and
               my >= btn.y and my <= btn.y + btn.h then
                OptionsUI.selectedIndex = 5
                OptionsUI.Hide()
                return true
            end
        end
    end
    
    return false
end

-- ============================================================================
-- 渲染
-- ============================================================================

-- 缓存安全区信息（用于输入处理）
OptionsUI.safeArea = nil

function OptionsUI.Render(nvg, sw, sh)
    if not OptionsUI.visible then return end
    
    OptionsUI.animTime = OptionsUI.animTime + 0.016
    
    -- 半透明遮罩（全屏）
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
    nvgFill(nvg)
    
    -- 计算安全区
    local safe = UISafeArea.Calculate(sw, sh)
    OptionsUI.safeArea = safe
    
    -- 使用安全区尺寸计算布局
    local uw, uh = safe.w, safe.h
    local baseUnit = safe.baseUnit
    local fonts = UIStyle.GetTypography(uw, uh)
    
    -- 进入安全区绘制
    UISafeArea.BeginSafeArea(nvg, safe)
    
    -- 面板（相对于安全区居中）- 加宽以容纳所有控件
    local panelW = math.min(uw * 0.48, baseUnit * 28)
    local panelH = uh * 0.6
    local panelX = (uw - panelW) / 2
    local panelY = (uh - panelH) / 2
    
    UIStyle.DrawSciFiPanel(nvg, panelX, panelY, panelW, panelH, {
        baseUnit = baseUnit,
        animTime = OptionsUI.animTime,
        title = "选项",
    })
    
    -- 内容区域
    local contentX = panelX + baseUnit * 1.5
    local contentW = panelW - baseUnit * 3
    local contentY = panelY + baseUnit * 4
    local itemH = baseUnit * 3
    local gap = baseUnit * 1.2
    
    -- 只绘制设置项（不含按钮）
    for i = 1, 3 do
        local item = OptionsUI.menuItems[i]
        local itemY = contentY + (i - 1) * (itemH + gap)
        local isSelected = OptionsUI.showKeyboardFocus and (i == OptionsUI.selectedIndex)
        
        OptionsUI.DrawMenuItem(nvg, contentX, itemY, contentW, itemH, item, isSelected, baseUnit, fonts)
    end
    
    -- 底部按钮区域
    local btnAreaY = contentY + 3 * (itemH + gap) + baseUnit * 0.5
    local btnW = (contentW - baseUnit * 1.5) / 2
    local btnH = baseUnit * 2.8
    
    -- 保存按钮（有光效）
    local saveSelected = OptionsUI.showKeyboardFocus and (OptionsUI.selectedIndex == 4)
    UIStyle.DrawSciFiButton(nvg, contentX, btnAreaY, btnW, btnH, "保存", {
        baseUnit = baseUnit,
        animTime = OptionsUI.animTime,
        variant = "primary",
        fontSize = fonts.buttonText,
        selected = saveSelected,
    })
    
    -- 返回按钮（无光效）
    local backSelected = OptionsUI.showKeyboardFocus and (OptionsUI.selectedIndex == 5)
    UIStyle.DrawSciFiButton(nvg, contentX + btnW + baseUnit * 1.5, btnAreaY, btnW, btnH, "返回", {
        baseUnit = baseUnit,
        animTime = 0,
        variant = "secondary",
        fontSize = fonts.buttonText,
        selected = backSelected,
    })
    
    -- 缓存按钮位置用于点击检测
    OptionsUI.saveBtnRect = {x = contentX, y = btnAreaY, w = btnW, h = btnH}
    OptionsUI.backBtnRect = {x = contentX + btnW + baseUnit * 1.5, y = btnAreaY, w = btnW, h = btnH}
    
    UISafeArea.EndSafeArea(nvg)
end

function OptionsUI.DrawMenuItem(nvg, x, y, w, h, item, isSelected, baseUnit, fonts)
    -- 选中背景
    if isSelected then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.3)
        nvgFillColor(nvg, nvgRGBA(60, 120, 180, 50))
        nvgFill(nvg)
        
        nvgStrokeColor(nvg, nvgRGBA(80, 180, 255, 150))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
    end
    
    -- 标签（固定宽度）
    local labelW = baseUnit * 4
    nvgFontSize(nvg, fonts.buttonText)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, isSelected and 255 or 200))
    nvgText(nvg, x + baseUnit * 0.5, y + h / 2, item.label)
    
    -- 控件区域（标签右侧）
    local controlX = x + labelW + baseUnit
    local controlW = w - labelW - baseUnit * 1.5
    
    if item.type == "slider" then
        OptionsUI.DrawSlider(nvg, controlX, y + h / 2, controlW, h * 0.35, item, isSelected, baseUnit, fonts)
    elseif item.type == "select" then
        OptionsUI.DrawSelect(nvg, controlX, y, controlW, h, item, isSelected, baseUnit, fonts)
    end
end

function OptionsUI.DrawSlider(nvg, x, y, w, h, item, isSelected, baseUnit, fonts)
    local value, enabled
    if item.id == "music" then
        value = OptionsUI.settings.musicVolume
        enabled = OptionsUI.settings.musicEnabled
    else
        value = OptionsUI.settings.sfxVolume
        enabled = OptionsUI.settings.sfxEnabled
    end
    
    -- 布局计算：[滑块条] [间隙] [百分比] [间隙] [开关]
    local toggleW = baseUnit * 2.8
    local toggleH = baseUnit * 1.4
    local percentW = baseUnit * 3.5  -- 百分比文字宽度
    local gapSmall = baseUnit * 0.6
    local gapLarge = baseUnit * 0.8
    
    -- 滑块条宽度 = 总宽度 - 百分比 - 开关 - 间隙
    local sliderW = w - percentW - toggleW - gapSmall - gapLarge
    local sliderH = h
    local sliderY = y - sliderH / 2
    
    -- 滑块背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, sliderY, sliderW, sliderH, sliderH / 2)
    nvgFillColor(nvg, nvgRGBA(30, 40, 60, 220))
    nvgFill(nvg)
    
    -- 滑块填充
    local fillW = sliderW * (value / 100)
    if fillW > sliderH then  -- 确保圆角正确
        local barColor = enabled and UIStyle.Colors.primary.main or UIStyle.Colors.text.muted
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, sliderY, fillW, sliderH, sliderH / 2)
        nvgFillColor(nvg, nvgRGBA(barColor.r, barColor.g, barColor.b, enabled and 220 or 100))
        nvgFill(nvg)
    elseif fillW > 0 then
        -- 太短时只画圆形
        local barColor = enabled and UIStyle.Colors.primary.main or UIStyle.Colors.text.muted
        nvgBeginPath(nvg)
        nvgCircle(nvg, x + sliderH / 2, y, sliderH / 2)
        nvgFillColor(nvg, nvgRGBA(barColor.r, barColor.g, barColor.b, enabled and 220 or 100))
        nvgFill(nvg)
    end
    
    -- 滑块边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, sliderY, sliderW, sliderH, sliderH / 2)
    nvgStrokeColor(nvg, nvgRGBA(80, 120, 160, 150))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- 百分比文字（右对齐，在滑块和开关之间）
    local percentX = x + sliderW + gapSmall + percentW
    nvgFontSize(nvg, fonts.statValue)
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(220, 230, 240, enabled and 255 or 150))
    nvgText(nvg, percentX, y, value .. "%")
    
    -- 开关
    local toggleX = percentX + gapLarge
    local toggleY = y - toggleH / 2
    
    -- 开关背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, toggleX, toggleY, toggleW, toggleH, toggleH / 2)
    if enabled then
        nvgFillColor(nvg, nvgRGBA(60, 180, 100, 230))
    else
        nvgFillColor(nvg, nvgRGBA(60, 65, 80, 220))
    end
    nvgFill(nvg)
    
    -- 开关边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, toggleX, toggleY, toggleW, toggleH, toggleH / 2)
    nvgStrokeColor(nvg, enabled and nvgRGBA(80, 200, 120, 180) or nvgRGBA(80, 90, 110, 150))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- 开关圆点
    local knobRadius = toggleH / 2 - 3
    local knobX = enabled and (toggleX + toggleW - knobRadius - 4) or (toggleX + knobRadius + 4)
    nvgBeginPath(nvg)
    nvgCircle(nvg, knobX, y, knobRadius)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
    nvgFill(nvg)
end

function OptionsUI.DrawSelect(nvg, x, y, w, h, item, isSelected, baseUnit, fonts)
    local langText = OptionsUI.languages[OptionsUI.settings.languageIndex]
    
    -- 选择框背景
    local boxX = x
    local boxY = y + h * 0.2
    local boxW = w * 0.6
    local boxH = h * 0.6
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, boxX, boxY, boxW, boxH, baseUnit * 0.25)
    nvgFillColor(nvg, nvgRGBA(20, 30, 50, 200))
    nvgFill(nvg)
    
    nvgStrokeColor(nvg, nvgRGBA(80, 120, 160, 150))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- 当前选择文字
    nvgFontSize(nvg, fonts.statValue)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
    nvgText(nvg, boxX + boxW / 2, y + h / 2, langText)
    
    -- 左右箭头提示
    if isSelected then
        nvgFillColor(nvg, nvgRGBA(80, 180, 255, 200))
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(nvg, boxX - baseUnit * 0.3, y + h / 2, "<")
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(nvg, boxX + boxW + baseUnit * 0.3, y + h / 2, ">")
    end
end

return OptionsUI
