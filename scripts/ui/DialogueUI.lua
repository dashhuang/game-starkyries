-- ============================================================================
-- 星河战姬 Starkyries - 对话系统 UI
-- 用于剧情模式的对话展示
-- ============================================================================
--[[
使用方式：
    local DialogueUI = require("ui.DialogueUI")
    
    -- 播放一段对话
    DialogueUI.Play({
        { speaker = "艾琳", text = "指挥官，敌舰来袭！", image = "image/scene_bridge.jpg" },
        { speaker = "指挥官", text = "全员战斗准备！", effect = "shake" },
    }, function()
        print("对话结束")
    end)
]]

local UIStyle = require("ui.UIStyle")
local Audio = require("core.Audio")
local NvgHelper = require("render.NvgHelper")
local TouchInput = require("utils.TouchInput")

local DialogueUI = {}

-- ============================================================================
-- 配置常量
-- ============================================================================

DialogueUI.Config = {
    -- 打字机效果
    charDelay = 0.03,           -- 每个字符的延迟（秒）
    fastCharDelay = 0.005,      -- 快进时的延迟
    
    -- 图片裁剪（Cover模式下，横屏时裁掉多余部分的比例）
    defaultCropTop = 0.15,      -- 默认裁掉顶部15%
    
    -- 对话框样式
    boxHeightRatio = 0.28,      -- 对话框高度占屏幕比例
    boxMargin = 2,              -- 对话框边距（baseUnit倍数）
    
    -- 效果
    shakeDuration = 0.3,        -- 震动持续时间
    shakeIntensity = 8,         -- 震动强度（像素）
    
    -- 语音配置
    voiceEnabled = true,        -- 是否启用语音
    voicePath = "audio/voice/", -- 语音文件根目录
    voiceVolume = 1.0,          -- 语音音量
    voiceFormat = ".ogg",       -- 语音文件格式（引擎只支持 ogg）
}

-- ============================================================================
-- 状态
-- ============================================================================

DialogueUI.visible = false
DialogueUI.animTime = 0
DialogueUI.onComplete = nil

-- 对话数据
DialogueUI.dialogueData = nil         -- 当前对话序列
DialogueUI.currentIndex = 1           -- 当前对话索引
DialogueUI.displayedText = ""         -- 已显示的文字
DialogueUI.charIndex = 0              -- 当前字符索引（UTF-8字符计数）
DialogueUI.charTimer = 0              -- 字符显示计时器
DialogueUI.isTyping = false           -- 是否正在打字
DialogueUI.isFastForward = false      -- 是否快进

-- 图片管理
DialogueUI.images = {}                -- 已加载的图片缓存 { [path] = nvgImage }
DialogueUI.currentImage = nil         -- 当前显示的图片路径
DialogueUI.currentCropTop = 0.15      -- 当前图片的顶部裁剪比例
DialogueUI.currentImageDesc = nil     -- 当前图片的描述（用于占位符显示）

-- 效果状态
DialogueUI.shakeTimer = 0             -- 震动计时器
DialogueUI.shakeOffset = { x = 0, y = 0 }

-- 跳过功能状态
DialogueUI.showingSummary = false     -- 是否正在显示剧情简介
DialogueUI.dialogueSummary = nil      -- 当前对话的简介
DialogueUI.skipButtonHover = false    -- 跳过按钮悬停状态
DialogueUI.confirmButtonHover = false -- 确认按钮悬停状态
DialogueUI.cancelButtonHover = false  -- 取消按钮悬停状态

-- 按钮按下状态
DialogueUI.pressedSkipButton = false      -- 跳过按钮按下状态
DialogueUI.pressedConfirmButton = false   -- 确认按钮按下状态
DialogueUI.pressedCancelButton = false    -- 取消按钮按下状态

-- NanoVG 上下文（需要在第一次渲染时获取）
DialogueUI.nvg = nil

-- 语音相关
DialogueUI.voiceMapping = nil         -- 语音映射表
DialogueUI.voiceMappingLoaded = false -- 是否已加载映射
DialogueUI.currentDialogueId = nil    -- 当前对话 ID（用于查找语音）
DialogueUI.voiceLineIndex = 0         -- 当前语音行索引（只计算有speaker的行）
DialogueUI.soundSource = nil          -- 音频源组件
DialogueUI.audioNode = nil            -- 音频节点

-- ============================================================================
-- 语音系统
-- ============================================================================

---加载语音映射文件
function DialogueUI.LoadVoiceMapping()
    if DialogueUI.voiceMappingLoaded then return end
    
    local mappingPath = DialogueUI.Config.voicePath .. "mapping.json"
    
    -- 检查文件是否存在
    if not cache:Exists(mappingPath) then
        print("[DialogueUI] 语音映射文件不存在: " .. mappingPath)
        DialogueUI.voiceMappingLoaded = true
        return
    end
    
    local file = cache:GetFile(mappingPath)
    if file then
        local content = file:ReadString()
        file:Close()
        
        -- 简单 JSON 解析
        DialogueUI.voiceMapping = DialogueUI.ParseVoiceMapping(content)
        print("[DialogueUI] 语音映射加载成功")
    end
    
    DialogueUI.voiceMappingLoaded = true
end

---解析语音映射 JSON
function DialogueUI.ParseVoiceMapping(content)
    local result = {}
    
    -- 匹配 "dialogue_id": { "index": "path", ... }
    for dialogueId, inner in content:gmatch('"([^"]+)":%s*{([^}]+)}') do
        result[dialogueId] = {}
        for index, path in inner:gmatch('"(%d+)":%s*"([^"]+)"') do
            result[dialogueId][tonumber(index)] = path
        end
    end
    
    return result
end

---初始化音频组件
function DialogueUI.InitAudio(gameScene)
    if DialogueUI.audioNode then return end
    
    if not gameScene then
        print("[DialogueUI] 警告: 无法初始化音频，未提供 scene")
        return
    end
    
    DialogueUI.audioNode = gameScene:CreateChild("DialogueVoice")
    DialogueUI.soundSource = DialogueUI.audioNode:CreateComponent("SoundSource")
    DialogueUI.soundSource.soundType = SOUND_VOICE
    DialogueUI.soundSource.gain = DialogueUI.Config.voiceVolume
    
    print("[DialogueUI] 语音系统初始化完成")
end

---播放当前行的语音
function DialogueUI.PlayVoice()
    if not DialogueUI.Config.voiceEnabled then return end
    if not DialogueUI.soundSource then return end
    if not DialogueUI.voiceMapping then return end
    if not DialogueUI.currentDialogueId then return end
    
    -- 获取语音路径
    local dialogueMapping = DialogueUI.voiceMapping[DialogueUI.currentDialogueId]
    if not dialogueMapping then return end
    
    local voiceFile = dialogueMapping[DialogueUI.voiceLineIndex]
    if not voiceFile then return end
    
    local fullPath = DialogueUI.Config.voicePath .. voiceFile
    
    -- 检查文件是否存在
    if not cache:Exists(fullPath) then
        print("[DialogueUI] 语音文件不存在: " .. fullPath)
        return
    end
    
    -- 加载并播放
    local sound = cache:GetResource("Sound", fullPath)
    if sound then
        DialogueUI.soundSource:Stop()
        DialogueUI.soundSource:Play(sound)
        print("[DialogueUI] 播放语音: " .. voiceFile)
    end
end

---停止语音播放
function DialogueUI.StopVoice()
    if DialogueUI.soundSource then
        DialogueUI.soundSource:Stop()
    end
end

---设置语音音量
function DialogueUI.SetVoiceVolume(volume)
    DialogueUI.Config.voiceVolume = volume
    if DialogueUI.soundSource then
        DialogueUI.soundSource.gain = volume
    end
end

---启用/禁用语音
function DialogueUI.SetVoiceEnabled(enabled)
    DialogueUI.Config.voiceEnabled = enabled
    if not enabled then
        DialogueUI.StopVoice()
    end
end

-- ============================================================================
-- 公开 API
-- ============================================================================

---提取对话数据中所有唯一图片路径
---@param dialogues table 对话数据数组
---@return string[] imagePaths 唯一图片路径列表
function DialogueUI.CollectImagePaths(dialogues)
    if not dialogues then return {} end
    local seen = {}
    local paths = {}
    for i = 1, #dialogues do
        local img = dialogues[i].image
        if img and not seen[img] then
            seen[img] = true
            paths[#paths + 1] = img
        end
    end
    return paths
end

---预加载对话中所有图片资源（DWP 兼容）
---在进入剧情前调用，确保所有图片下载完成后再开始播放
---@param dialogues table 对话数据数组
---@param onComplete function 所有图片就绪后的回调
---@param onProgress function? 可选进度回调 onProgress(completed, total)
function DialogueUI.PreloadImages(dialogues, onComplete, onProgress)
    local paths = DialogueUI.CollectImagePaths(dialogues)
    if #paths == 0 then
        log:Write(LOG_INFO, "[DialogueUI] PreloadImages: no images to preload")
        if onComplete then onComplete() end
        return
    end

    local total = #paths
    local completed = 0
    log:Write(LOG_INFO, "[DialogueUI] PreloadImages: " .. total .. " images to preload")

    local function onOneReady(path, success)
        completed = completed + 1
        if not success then
            log:Write(LOG_WARNING, "[DialogueUI] PreloadImages: failed " .. tostring(path))
        end
        if onProgress then onProgress(completed, total) end
        if completed >= total then
            log:Write(LOG_INFO, "[DialogueUI] PreloadImages: all done")
            if onComplete then onComplete() end
        end
    end

    for _, path in ipairs(paths) do
        if cache:Exists(path) then
            onOneReady(path, true)
        else
            cache:GetResourceAsync("Texture2D", path, function(resource)
                onOneReady(path, resource ~= nil)
            end)
        end
    end
end

---播放对话序列
---@param dialogues table 对话数据数组（可包含 summary 字段作为剧情简介）
---@param onComplete function? 完成回调
---@param options table? 可选参数 { dialogueId = "tutorial/Opening", scene = scene }
function DialogueUI.Play(dialogues, onComplete, options)
    if not dialogues or #dialogues == 0 then
        print("[DialogueUI] 错误：对话数据为空")
        if onComplete then onComplete() end
        return
    end
    
    DialogueUI.visible = true
    DialogueUI.dialogueData = dialogues
    DialogueUI.currentIndex = 1
    DialogueUI.onComplete = onComplete
    DialogueUI.animTime = 0
    DialogueUI.showingSummary = false
    DialogueUI.skipButtonHover = false
    
    -- 提取剧情简介（如果有）
    DialogueUI.dialogueSummary = dialogues.summary or nil
    
    -- 语音系统初始化
    options = options or {}
    DialogueUI.currentDialogueId = options.dialogueId
    DialogueUI.voiceLineIndex = 0
    
    -- 加载语音映射
    DialogueUI.LoadVoiceMapping()
    
    -- 初始化音频（如果提供了 scene）
    if options.scene then
        DialogueUI.InitAudio(options.scene)
    end
    
    DialogueUI.ShowCurrentLine()
end

---停止对话
function DialogueUI.Stop()
    DialogueUI.visible = false
    DialogueUI.dialogueData = nil
    DialogueUI.currentIndex = 1
    DialogueUI.displayedText = ""
    DialogueUI.isTyping = false
end

---是否正在显示
---@return boolean
function DialogueUI.IsVisible()
    return DialogueUI.visible
end

---是否正在打字
---@return boolean
function DialogueUI.IsTyping()
    return DialogueUI.isTyping
end

-- ============================================================================
-- 内部方法 - 对话控制
-- ============================================================================

function DialogueUI.ShowCurrentLine()
    if not DialogueUI.dialogueData then return end
    
    local line = DialogueUI.dialogueData[DialogueUI.currentIndex]
    if not line then
        -- 对话结束
        DialogueUI.OnDialogueEnd()
        return
    end
    
    -- 重置打字状态
    DialogueUI.displayedText = ""
    DialogueUI.charIndex = 0
    DialogueUI.charTimer = 0
    DialogueUI.isTyping = true
    DialogueUI.isFastForward = false
    
    -- 处理图片切换
    if line.image then
        DialogueUI.currentImage = line.image
        DialogueUI.currentCropTop = line.cropTop or DialogueUI.Config.defaultCropTop
        DialogueUI.currentImageDesc = line.imageDesc  -- 图片描述（用于占位符）
    end
    
    -- 处理效果
    if line.effect then
        DialogueUI.TriggerEffect(line.effect)
    end
    
    -- 播放音效
    if line.sfx then
        DialogueUI.PlaySFX(line.sfx)
    end
    
    -- 播放语音（只有有 speaker 的行才播放）
    if line.speaker and line.speaker ~= "" then
        DialogueUI.PlayVoice()
        DialogueUI.voiceLineIndex = DialogueUI.voiceLineIndex + 1
    end
end

function DialogueUI.AdvanceDialogue()
    if not DialogueUI.dialogueData then return end
    
    local line = DialogueUI.dialogueData[DialogueUI.currentIndex]
    if not line then return end
    
    -- 如果正在打字，先完成当前文字
    if DialogueUI.isTyping then
        DialogueUI.displayedText = line.text
        DialogueUI.charIndex = DialogueUI.GetUtf8Length(line.text)
        DialogueUI.isTyping = false
        return
    end
    
    -- 进入下一行
    DialogueUI.currentIndex = DialogueUI.currentIndex + 1
    DialogueUI.ShowCurrentLine()
end

function DialogueUI.OnDialogueEnd()
    DialogueUI.visible = false
    DialogueUI.dialogueData = nil
    DialogueUI.showingSummary = false
    DialogueUI.dialogueSummary = nil
    
    -- 停止语音播放
    DialogueUI.StopVoice()
    DialogueUI.currentDialogueId = nil
    DialogueUI.voiceLineIndex = 0
    
    -- 🔴 关键：对话结束时自动清理图片缓存，释放 GPU 内存
    DialogueUI.ClearImageCache()
    
    if DialogueUI.onComplete then
        DialogueUI.onComplete()
        DialogueUI.onComplete = nil
    end
end

---跳过对话，显示剧情简介
function DialogueUI.SkipDialogue()
    -- 停止当前语音
    DialogueUI.StopVoice()
    
    if DialogueUI.showingSummary then
        -- 已经在显示简介，直接结束
        DialogueUI.OnDialogueEnd()
        return
    end
    
    if DialogueUI.dialogueSummary then
        -- 有简介，显示简介界面
        DialogueUI.showingSummary = true
        DialogueUI.isTyping = false
    else
        -- 没有简介，直接结束
        DialogueUI.OnDialogueEnd()
    end
end

-- ============================================================================
-- 内部方法 - 效果
-- ============================================================================

function DialogueUI.TriggerEffect(effectName)
    if effectName == "shake" then
        DialogueUI.shakeTimer = DialogueUI.Config.shakeDuration
    end
    -- 可扩展其他效果
end

-- 播放剧情音效
function DialogueUI.PlaySFX(sfxName)
    if sfxName == "alarm" then
        Audio.PlayStoryAlarm()
    elseif sfxName == "explosion" then
        Audio.PlayExplosion(false)
    elseif sfxName == "explosion_big" then
        Audio.PlayExplosion(true)
    elseif sfxName == "confirm" then
        Audio.PlayConfirm()
    elseif sfxName == "hyperspace" then
        Audio.PlayHyperspaceJump()
    end
    -- 可扩展其他音效
end

function DialogueUI.UpdateEffects(dt)
    -- 震动效果
    if DialogueUI.shakeTimer > 0 then
        DialogueUI.shakeTimer = DialogueUI.shakeTimer - dt
        local intensity = DialogueUI.Config.shakeIntensity
        DialogueUI.shakeOffset.x = (math.random() - 0.5) * 2 * intensity
        DialogueUI.shakeOffset.y = (math.random() - 0.5) * 2 * intensity
    else
        DialogueUI.shakeOffset.x = 0
        DialogueUI.shakeOffset.y = 0
    end
end

-- ============================================================================
-- 内部方法 - UTF-8 处理
-- ============================================================================

function DialogueUI.GetUtf8Length(str)
    local len = 0
    local i = 1
    while i <= #str do
        local byte = string.byte(str, i)
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

function DialogueUI.GetUtf8Substring(str, charCount)
    local byteIndex = 0
    local charIndex = 0
    while byteIndex < #str and charIndex < charCount do
        local byte = string.byte(str, byteIndex + 1)
        if byte < 128 then
            byteIndex = byteIndex + 1
        elseif byte < 224 then
            byteIndex = byteIndex + 2
        elseif byte < 240 then
            byteIndex = byteIndex + 3
        else
            byteIndex = byteIndex + 4
        end
        charIndex = charIndex + 1
    end
    return string.sub(str, 1, byteIndex)
end

-- ============================================================================
-- 更新
-- ============================================================================

function DialogueUI.Update(dt)
    if not DialogueUI.visible then return end
    
    DialogueUI.animTime = DialogueUI.animTime + dt
    DialogueUI.UpdateEffects(dt)
    
    -- 打字机效果
    if DialogueUI.isTyping and DialogueUI.dialogueData then
        local line = DialogueUI.dialogueData[DialogueUI.currentIndex]
        if line and line.text then
            local delay = DialogueUI.isFastForward 
                and DialogueUI.Config.fastCharDelay 
                or DialogueUI.Config.charDelay
            
            DialogueUI.charTimer = DialogueUI.charTimer + dt
            
            while DialogueUI.charTimer >= delay do
                DialogueUI.charTimer = DialogueUI.charTimer - delay
                DialogueUI.charIndex = DialogueUI.charIndex + 1
                DialogueUI.displayedText = DialogueUI.GetUtf8Substring(line.text, DialogueUI.charIndex)
                
                if DialogueUI.charIndex >= DialogueUI.GetUtf8Length(line.text) then
                    DialogueUI.isTyping = false
                    break
                end
            end
        end
    end
end

-- ============================================================================
-- 输入处理
-- ============================================================================

function DialogueUI.HandleInput()
    if not DialogueUI.visible then return false end
    
    -- 如果正在显示简介，确认或取消
    if DialogueUI.showingSummary then
        -- 回车/空格：确认跳过
        if input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_RETURN) then
            DialogueUI.OnDialogueEnd()
            return true
        end
        -- ESC：取消，返回对话
        if input:GetKeyPress(KEY_ESCAPE) then
            DialogueUI.showingSummary = false
            return true
        end
        return false
    end
    
    -- 空格/回车：推进对话
    if input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_RETURN) then
        DialogueUI.AdvanceDialogue()
        return true
    end
    
    -- ESC：跳过对话（显示简介）
    if input:GetKeyPress(KEY_ESCAPE) then
        DialogueUI.SkipDialogue()
        return true
    end
    
    return false
end

function DialogueUI.HandleTouch(sw, sh)
    if not DialogueUI.visible then 
        -- 重置所有按下状态
        DialogueUI.pressedSkipButton = false
        DialogueUI.pressedConfirmButton = false
        DialogueUI.pressedCancelButton = false
        return false 
    end
    
    local mouseX = TouchInput.x
    local mouseY = TouchInput.y
    local baseUnit = math.min(sw, sh) / 40
    
    -- 获取 UIScreen 用于检测鼠标释放
    local UIScreen = require("ui.UIScreen")
    
    -- 如果正在显示简介，检查确认/取消按钮
    if DialogueUI.showingSummary then
        -- 计算按钮位置（与渲染保持一致）
        local boxW = math.min(sw * 0.85, baseUnit * 35)
        local boxH = baseUnit * 18
        local boxX = (sw - boxW) / 2
        local boxY = (sh - boxH) / 2
        
        local btnW = baseUnit * 8
        local btnH = baseUnit * 2.5
        local btnGap = baseUnit * 2
        local btnY = boxY + boxH - baseUnit * 4.5
        
        local confirmBtnX = sw / 2 - btnW - btnGap / 2
        local cancelBtnX = sw / 2 + btnGap / 2
        
        -- 检查确认按钮悬停
        local onConfirmBtn = mouseX >= confirmBtnX and mouseX <= confirmBtnX + btnW
            and mouseY >= btnY and mouseY <= btnY + btnH
        DialogueUI.confirmButtonHover = onConfirmBtn
        
        -- 检查取消按钮悬停
        local onCancelBtn = mouseX >= cancelBtnX and mouseX <= cancelBtnX + btnW
            and mouseY >= btnY and mouseY <= btnY + btnH
        DialogueUI.cancelButtonHover = onCancelBtn
        
        -- 按下检测
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            if onConfirmBtn then
                DialogueUI.pressedConfirmButton = true
                return true
            elseif onCancelBtn then
                DialogueUI.pressedCancelButton = true
                return true
            end
        end
        
        -- 释放检测
        if UIScreen.IsMouseReleased() then
            if DialogueUI.pressedConfirmButton then
                DialogueUI.pressedConfirmButton = false
                if onConfirmBtn then
                    Audio.PlayConfirm()
                    DialogueUI.OnDialogueEnd()
                    return true
                end
            end
            if DialogueUI.pressedCancelButton then
                DialogueUI.pressedCancelButton = false
                if onCancelBtn then
                    Audio.PlayUIClick()
                    DialogueUI.showingSummary = false
                    return true
                end
            end
        end
        
        return false
    end
    
    -- 检查跳过按钮
    local skipBtnW = baseUnit * 5
    local skipBtnH = baseUnit * 2
    local skipBtnX = sw - skipBtnW - baseUnit
    local skipBtnY = baseUnit
    
    local onSkipBtn = mouseX >= skipBtnX and mouseX <= skipBtnX + skipBtnW
        and mouseY >= skipBtnY and mouseY <= skipBtnY + skipBtnH
    DialogueUI.skipButtonHover = onSkipBtn
    
    -- 按下检测
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        if onSkipBtn then
            DialogueUI.pressedSkipButton = true
            return true
        end
        -- 普通点击：推进对话（立即生效，无需释放）
        DialogueUI.AdvanceDialogue()
        return true
    end
    
    -- 跳过按钮释放检测
    if UIScreen.IsMouseReleased() then
        if DialogueUI.pressedSkipButton then
            DialogueUI.pressedSkipButton = false
            if onSkipBtn then
                Audio.PlayUIClick()
                DialogueUI.SkipDialogue()
                return true
            end
        end
    end
    
    return false
end

-- ============================================================================
-- 渲染
-- ============================================================================

function DialogueUI.Render(nvg, sw, sh)
    if not DialogueUI.visible then return end
    
    DialogueUI.nvg = nvg
    
    -- 设置字体（必须！）
    nvgFontFace(nvg, "sans")
    
    local baseUnit = math.min(sw, sh) / 40
    local fonts = UIStyle.GetTypography(sw, sh)
    
    -- 如果正在显示简介，渲染简介界面
    if DialogueUI.showingSummary then
        DialogueUI.RenderSummaryScreen(nvg, sw, sh, baseUnit, fonts)
        return
    end
    
    -- 应用震动偏移
    if DialogueUI.shakeOffset.x ~= 0 or DialogueUI.shakeOffset.y ~= 0 then
        nvgSave(nvg)
        nvgTranslate(nvg, DialogueUI.shakeOffset.x, DialogueUI.shakeOffset.y)
    end
    
    -- 渲染场景图片
    DialogueUI.RenderSceneImage(nvg, sw, sh)
    
    -- 渲染对话框
    if DialogueUI.dialogueData then
        DialogueUI.RenderDialogueBox(nvg, sw, sh, baseUnit, fonts)
    end
    
    -- 恢复震动偏移
    if DialogueUI.shakeOffset.x ~= 0 or DialogueUI.shakeOffset.y ~= 0 then
        nvgRestore(nvg)
    end
    
    -- 渲染跳过按钮（在震动效果之外）
    DialogueUI.RenderSkipButton(nvg, sw, sh, baseUnit, fonts)
end

function DialogueUI.RenderSceneImage(nvg, sw, sh)
    if not DialogueUI.currentImage then
        -- 无图片时显示纯色背景
        nvgBeginPath(nvg)
        nvgRect(nvg, 0, 0, sw, sh)
        nvgFillColor(nvg, nvgRGBA(10, 15, 25, 255))
        nvgFill(nvg)
        return
    end
    
    -- 延迟加载图片（兼容 DWP 边玩边下模式）
    local img = DialogueUI.images[DialogueUI.currentImage]
    if not img then
        if cache:Exists(DialogueUI.currentImage) then
            -- 资源已在本地，直接创建 NanoVG 图片
            img = nvgCreateImage(nvg, DialogueUI.currentImage, 0)
            if img and img > 0 then
                DialogueUI.images[DialogueUI.currentImage] = img
            else
                DialogueUI.images[DialogueUI.currentImage] = -1
            end
        else
            -- DWP 模式：资源尚未下载，发起异步加载
            -- 标记为 -2 表示"下载中"，避免重复发起请求
            DialogueUI.images[DialogueUI.currentImage] = -2
            local imagePath = DialogueUI.currentImage
            cache:GetResourceAsync("Texture2D", imagePath, function(resource)
                if resource then
                    -- 下载完成，清除标记，下一帧 RenderSceneImage 会重新尝试 nvgCreateImage
                    DialogueUI.images[imagePath] = nil
                    log:Write(LOG_INFO, "[DialogueUI] DWP image ready: " .. imagePath)
                else
                    -- 真正加载失败
                    DialogueUI.images[imagePath] = -1
                    log:Write(LOG_WARNING, "[DialogueUI] DWP image failed: " .. imagePath)
                end
            end)
            img = -2
        end
    end
    
    if not img or img <= 0 then
        -- 图片加载失败或下载中，显示占位符
        DialogueUI.RenderImagePlaceholder(nvg, sw, sh)
        return
    end
    
    -- Cover模式渲染（假设图片为1:1方形，可根据实际调整）
    local imgW, imgH = 1024, 1024
    
    local scaleX = sw / imgW
    local scaleY = sh / imgH
    local scale = math.max(scaleX, scaleY)
    
    local scaledW = imgW * scale
    local scaledH = imgH * scale
    
    local offsetX = (sw - scaledW) / 2
    local offsetY
    
    local isLandscape = sw > sh
    if isLandscape then
        local extraH = scaledH - sh
        offsetY = -extraH * DialogueUI.currentCropTop
    else
        offsetY = (sh - scaledH) / 2
    end
    
    local imgPaint = nvgImagePattern(nvg, offsetX, offsetY, scaledW, scaledH, 0, img, 1.0)
    
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillPaint(nvg, imgPaint)
    nvgFill(nvg)
end

-- 渲染图片占位符（图片不存在时显示）
function DialogueUI.RenderImagePlaceholder(nvg, sw, sh)
    local baseUnit = math.min(sw, sh) / 40
    
    -- 灰色背景
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(40, 45, 55, 255))
    nvgFill(nvg)
    
    -- 网格线装饰（表示占位）
    nvgStrokeColor(nvg, nvgRGBA(60, 65, 75, 255))
    nvgStrokeWidth(nvg, 1)
    local gridSize = baseUnit * 4
    for x = 0, sw, gridSize do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x, 0)
        nvgLineTo(nvg, x, sh)
        nvgStroke(nvg)
    end
    for y = 0, sh, gridSize do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, 0, y)
        nvgLineTo(nvg, sw, y)
        nvgStroke(nvg)
    end
    
    -- 中央信息框
    local boxW = math.min(sw * 0.8, baseUnit * 30)
    local boxH = baseUnit * 12
    local boxX = (sw - boxW) / 2
    local boxY = (sh - boxH) / 2 - baseUnit * 4  -- 稍微往上，避开对话框
    
    -- 信息框背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, boxX, boxY, boxW, boxH, baseUnit * 0.5)
    nvgFillColor(nvg, nvgRGBA(25, 30, 40, 230))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(100, 110, 130, 200))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
    
    -- 图标（图片占位符符号）
    nvgFontSize(nvg, baseUnit * 3)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(120, 130, 150, 200))
    nvgText(nvg, sw / 2, boxY + baseUnit * 2.5, "🖼️")
    
    -- 图片路径
    nvgFontSize(nvg, baseUnit * 1.4)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(180, 190, 210, 255))
    local imagePath = DialogueUI.currentImage or "未指定"
    nvgText(nvg, sw / 2, boxY + baseUnit * 5, "📁 " .. imagePath)
    
    -- 图片描述
    if DialogueUI.currentImageDesc then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, baseUnit * 1.2)
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(255, 220, 120, 255))
        NvgHelper.TextBox(nvg, boxX + baseUnit, boxY + baseUnit * 7.5, boxW - baseUnit * 2, "💡 " .. DialogueUI.currentImageDesc)
    else
        nvgFontSize(nvg, baseUnit * 1.2)
        nvgFillColor(nvg, nvgRGBA(150, 160, 180, 180))
        nvgText(nvg, sw / 2, boxY + baseUnit * 8, "（无描述）")
    end
end

function DialogueUI.RenderDialogueBox(nvg, sw, sh, baseUnit, fonts)
    local line = DialogueUI.dialogueData[DialogueUI.currentIndex]
    if not line then return end
    
    local cfg = DialogueUI.Config
    
    -- 对话框尺寸和位置
    local boxH = sh * cfg.boxHeightRatio
    local boxMargin = baseUnit * cfg.boxMargin
    local boxY = sh - boxH - boxMargin
    local boxX = boxMargin
    local boxW = sw - boxMargin * 2
    
    -- 对话框背景（半透明）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, boxX, boxY, boxW, boxH, baseUnit * 0.5)
    nvgFillColor(nvg, nvgRGBA(15, 25, 45, 220))
    nvgFill(nvg)
    
    -- 对话框边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, boxX, boxY, boxW, boxH, baseUnit * 0.5)
    nvgStrokeColor(nvg, nvgRGBA(80, 140, 220, 180))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
    
    -- 说话者名字
    local speaker = line.speaker or "???"
    local nameW = baseUnit * 6
    local nameH = baseUnit * 1.8
    local nameX = boxX + baseUnit * 1
    local nameY = boxY - nameH * 0.5
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, nameX, nameY, nameW, nameH, baseUnit * 0.3)
    nvgFillColor(nvg, nvgRGBA(40, 80, 140, 255))
    nvgFill(nvg)
    
    nvgStrokeColor(nvg, nvgRGBA(100, 180, 255, 200))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
    
    nvgFontSize(nvg, fonts.cardTitle)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg, nameX + nameW / 2, nameY + nameH / 2, speaker)
    
    -- 对话文字（使用 description 字段）
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, fonts.description)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(230, 235, 245, 255))
    
    local textX = boxX + baseUnit * 1.5
    local textY = boxY + baseUnit * 1.5
    local textW = boxW - baseUnit * 3
    
    NvgHelper.TextBox(nvg, textX, textY, textW, DialogueUI.displayedText)
    
    -- 继续提示（打字完成后显示）
    if not DialogueUI.isTyping then
        local arrowAlpha = 150 + 100 * math.sin(DialogueUI.animTime * 4)
        nvgFontSize(nvg, fonts.cardTitle)
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, arrowAlpha))
        nvgText(nvg, boxX + boxW - baseUnit * 1, boxY + boxH - baseUnit * 0.8, "▼")
    end
end

-- ============================================================================
-- 跳过按钮和简介界面
-- ============================================================================

function DialogueUI.RenderSkipButton(nvg, sw, sh, baseUnit, fonts)
    local btnW = baseUnit * 5
    local btnH = baseUnit * 2
    local btnX = sw - btnW - baseUnit
    local btnY = baseUnit
    
    local isPressed = DialogueUI.pressedSkipButton
    local pressOffset = isPressed and 2 or 0
    
    -- 按钮背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, btnX, btnY + pressOffset, btnW, btnH, baseUnit * 0.3)
    
    if isPressed then
        nvgFillColor(nvg, nvgRGBA(28, 35, 49, 220))  -- 按下时更暗
    elseif DialogueUI.skipButtonHover then
        nvgFillColor(nvg, nvgRGBA(80, 100, 140, 220))
    else
        nvgFillColor(nvg, nvgRGBA(40, 50, 70, 180))
    end
    nvgFill(nvg)
    
    -- 按钮边框
    nvgStrokeColor(nvg, nvgRGBA(120, 150, 200, isPressed and 100 or 150))
    nvgStrokeWidth(nvg, isPressed and 1.5 or 1)
    nvgStroke(nvg)
    
    -- 按钮文字
    nvgFontSize(nvg, baseUnit * 1.2)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(200, 210, 230, isPressed and 180 or 255))
    nvgText(nvg, btnX + btnW / 2, btnY + btnH / 2 + pressOffset, "跳过")
end

function DialogueUI.RenderSummaryScreen(nvg, sw, sh, baseUnit, fonts)
    -- 半透明黑色背景
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(10, 15, 25, 240))
    nvgFill(nvg)
    
    -- 中央内容框
    local boxW = math.min(sw * 0.85, baseUnit * 35)
    local boxH = baseUnit * 18
    local boxX = (sw - boxW) / 2
    local boxY = (sh - boxH) / 2
    
    -- 内容框背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, boxX, boxY, boxW, boxH, baseUnit * 0.8)
    nvgFillColor(nvg, nvgRGBA(25, 35, 55, 250))
    nvgFill(nvg)
    
    -- 内容框边框
    nvgStrokeColor(nvg, nvgRGBA(80, 140, 220, 200))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
    
    -- 标题
    nvgFontSize(nvg, baseUnit * 2)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(100, 180, 255, 255))
    nvgText(nvg, sw / 2, boxY + baseUnit * 1.5, "📖 剧情简介")
    
    -- 分隔线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, boxX + baseUnit * 2, boxY + baseUnit * 4.5)
    nvgLineTo(nvg, boxX + boxW - baseUnit * 2, boxY + baseUnit * 4.5)
    nvgStrokeColor(nvg, nvgRGBA(80, 100, 140, 150))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    
    -- 简介内容
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, baseUnit * 1.4)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(220, 230, 245, 255))
    
    local textX = boxX + baseUnit * 2
    local textY = boxY + baseUnit * 6
    local textW = boxW - baseUnit * 4
    
    local summary = DialogueUI.dialogueSummary or "（无简介）"
    NvgHelper.TextBox(nvg, textX, textY, textW, summary)
    
    -- 确认和取消按钮（统一科幻风格）
    local btnW = baseUnit * 8
    local btnH = baseUnit * 2.5
    local btnGap = baseUnit * 2
    local btnY = boxY + boxH - baseUnit * 4.5
    
    local confirmBtnX = sw / 2 - btnW - btnGap / 2
    local cancelBtnX = sw / 2 + btnGap / 2
    
    -- 确认按钮按下状态
    local confirmPressed = DialogueUI.pressedConfirmButton
    local confirmPressOffset = confirmPressed and 2 or 0
    
    -- 确认按钮（主色调 - 亮蓝）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, confirmBtnX, btnY + confirmPressOffset, btnW, btnH, baseUnit * 0.4)
    if confirmPressed then
        nvgFillColor(nvg, nvgRGBA(28, 63, 105, 255))  -- 按下时更暗
    elseif DialogueUI.confirmButtonHover then
        nvgFillColor(nvg, nvgRGBA(50, 110, 170, 255))
    else
        nvgFillColor(nvg, nvgRGBA(40, 90, 150, 255))
    end
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(80, 180, 255, confirmPressed and 140 or 200))
    nvgStrokeWidth(nvg, confirmPressed and 2 or 1.5)
    nvgStroke(nvg)
    
    nvgFontSize(nvg, baseUnit * 1.4)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, confirmPressed and 180 or 255))
    nvgText(nvg, confirmBtnX + btnW / 2, btnY + btnH / 2 + confirmPressOffset, "确认")
    
    -- 取消按钮按下状态
    local cancelPressed = DialogueUI.pressedCancelButton
    local cancelPressOffset = cancelPressed and 2 or 0
    
    -- 取消按钮（次要色调 - 暗蓝）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cancelBtnX, btnY + cancelPressOffset, btnW, btnH, baseUnit * 0.4)
    if cancelPressed then
        nvgFillColor(nvg, nvgRGBA(24, 35, 56, 255))  -- 按下时更暗
    elseif DialogueUI.cancelButtonHover then
        nvgFillColor(nvg, nvgRGBA(45, 60, 90, 255))
    else
        nvgFillColor(nvg, nvgRGBA(35, 50, 80, 255))
    end
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(60, 100, 150, cancelPressed and 140 or 200))
    nvgStrokeWidth(nvg, cancelPressed and 2 or 1.5)
    nvgStroke(nvg)
    
    nvgFontSize(nvg, baseUnit * 1.4)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(200, 210, 230, cancelPressed and 140 or 255))
    nvgText(nvg, cancelBtnX + btnW / 2, btnY + btnH / 2 + cancelPressOffset, "取消")
end

-- ============================================================================
-- 清理
-- ============================================================================

function DialogueUI.ClearImageCache()
    -- 清理图片缓存（在场景切换时调用）
    -- 🔴 关键：必须调用 nvgDeleteImage 释放 GPU 内存
    if DialogueUI.nvg then
        for path, img in pairs(DialogueUI.images) do
            if img and img > 0 then
                nvgDeleteImage(DialogueUI.nvg, img)
                print("[DialogueUI] Deleted image: " .. path)
            end
        end
    end
    DialogueUI.images = {}
    DialogueUI.currentImage = nil
    DialogueUI.currentImageDesc = nil
end

-- 完整清理（包括所有状态）
function DialogueUI.Cleanup()
    DialogueUI.ClearImageCache()
    DialogueUI.visible = false
    DialogueUI.dialogueData = nil
    DialogueUI.onComplete = nil
    DialogueUI.showingSummary = false
    DialogueUI.dialogueSummary = nil
    DialogueUI.nvg = nil
end

return DialogueUI
