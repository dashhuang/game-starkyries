-- ============================================================================
-- VoiceManager - 对话配音管理器
-- 用于加载和播放 ElevenLabs 生成的角色配音
-- ============================================================================

local VoiceManager = {}
VoiceManager.__index = VoiceManager

-- 配置
local CONFIG = {
    voicePath = "audio/voice/",           -- 配音文件根目录
    mappingFile = "audio/voice/mapping.json",  -- 映射文件（可选）
    defaultVolume = 1.0,
    fadeTime = 0.2,
}

-- ============================================================================
-- 初始化
-- ============================================================================

function VoiceManager:new(scene)
    local instance = setmetatable({}, VoiceManager)

    instance.scene = scene
    instance.currentSound = nil
    instance.soundSource = nil
    instance.voiceMapping = {}

    -- 创建音频节点
    instance.audioNode = scene:CreateChild("VoiceAudio")
    instance.soundSource = instance.audioNode:CreateComponent("SoundSource")
    instance.soundSource.soundType = SOUND_VOICE

    -- 尝试加载映射文件
    instance:loadMapping()

    return instance
end

function VoiceManager:loadMapping()
    -- 尝试加载 JSON 映射文件
    local file = cache:GetFile(CONFIG.mappingFile)
    if file then
        local content = file:ReadString()
        file:Close()
        
        -- 简单的 JSON 解析（基础实现）
        -- 实际项目中建议使用 json.lua 库
        self.voiceMapping = self:parseSimpleJson(content) or {}
    end
end

function VoiceManager:parseSimpleJson(content)
    -- 简单 JSON 解析，仅支持本工具生成的格式
    -- 生产环境建议使用完整的 JSON 库
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

-- ============================================================================
-- 播放配音
-- ============================================================================

---@param dialogueId string 对话 ID，如 "tutorial/Opening"
---@param lineIndex number 台词索引（从 0 开始）
---@param callback function|nil 播放完成回调（可选）
function VoiceManager:play(dialogueId, lineIndex, callback)
    -- 停止当前播放
    self:stop()
    
    -- 获取音频路径
    local voicePath = self:getVoicePath(dialogueId, lineIndex)
    if not voicePath then
        Log:Write(LOG_WARNING, "VoiceManager: 未找到配音 - " .. dialogueId .. "/" .. lineIndex)
        if callback then callback() end
        return false
    end
    
    -- 加载音频
    local sound = cache:GetResource("Sound", voicePath)
    if not sound then
        Log:Write(LOG_WARNING, "VoiceManager: 加载配音失败 - " .. voicePath)
        if callback then callback() end
        return false
    end
    
    -- 播放
    self.soundSource:Play(sound)
    self.soundSource.gain = CONFIG.defaultVolume
    self.currentSound = sound
    
    -- 设置完成回调
    if callback then
        local duration = sound.length
        -- 使用延迟调用回调
        self.scene:GetComponent("LuaScriptInstance"):DelayedExecute(duration, false, callback)
    end
    
    return true
end

---@param dialogueId string 对话 ID
---@param lineIndex number 台词索引
---@return string|nil 音频文件路径
function VoiceManager:getVoicePath(dialogueId, lineIndex)
    -- 优先从映射表查找
    if self.voiceMapping[dialogueId] and self.voiceMapping[dialogueId][lineIndex] then
        return CONFIG.voicePath .. self.voiceMapping[dialogueId][lineIndex]
    end
    
    -- 回退：尝试按命名规则查找
    -- 格式: audio/voice/dialogue_id/XXX_角色名.mp3
    -- 由于不知道角色名，这里返回 nil
    return nil
end

function VoiceManager:stop()
    if self.soundSource then
        self.soundSource:Stop()
    end
    self.currentSound = nil
end

function VoiceManager:setVolume(volume)
    CONFIG.defaultVolume = volume
    if self.soundSource then
        self.soundSource.gain = volume
    end
end

function VoiceManager:isPlaying()
    return self.soundSource and self.soundSource.playing
end

-- ============================================================================
-- 便捷方法：与对话系统集成
-- ============================================================================

-- 为对话数据自动添加配音路径
---@param dialogueId string 对话 ID
---@param dialogueData table 对话数据数组
function VoiceManager:attachVoicePaths(dialogueId, dialogueData)
    local lineIndex = 0
    
    for i, entry in ipairs(dialogueData) do
        -- 只处理有角色的条目
        if entry.speaker and entry.speaker ~= "" then
            local voicePath = self:getVoicePath(dialogueId, lineIndex)
            if voicePath then
                entry.voicePath = voicePath
            end
            lineIndex = lineIndex + 1
        end
    end
    
    return dialogueData
end

-- ============================================================================
-- 模块导出
-- ============================================================================

return VoiceManager
