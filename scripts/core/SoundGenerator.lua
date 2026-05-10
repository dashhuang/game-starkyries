-- ============================================================================
-- 星河战姬 Starkyries - 程序化音效生成器
-- 生成简单的 8-bit 风格游戏音效
-- ============================================================================

local SoundGenerator = {}

-- 采样率
local SAMPLE_RATE = 22050

-- ============================================================================
-- WAV 文件写入工具
-- ============================================================================

-- 写入 16-bit 小端整数
local function writeInt16(value)
    value = math.floor(value)
    if value < 0 then value = value + 65536 end
    local low = value % 256
    local high = math.floor(value / 256) % 256
    return string.char(low, high)
end

-- 写入 32-bit 小端整数
local function writeInt32(value)
    value = math.floor(value)
    local b1 = value % 256
    local b2 = math.floor(value / 256) % 256
    local b3 = math.floor(value / 65536) % 256
    local b4 = math.floor(value / 16777216) % 256
    return string.char(b1, b2, b3, b4)
end

-- 生成 WAV 文件数据
local function createWavFile(samples)
    local numSamples = #samples
    local dataSize = numSamples * 2  -- 16-bit = 2 bytes per sample
    local fileSize = 36 + dataSize
    
    local wav = {}
    
    -- RIFF 头
    table.insert(wav, "RIFF")
    table.insert(wav, writeInt32(fileSize))
    table.insert(wav, "WAVE")
    
    -- fmt 子块
    table.insert(wav, "fmt ")
    table.insert(wav, writeInt32(16))          -- 子块大小
    table.insert(wav, writeInt16(1))           -- PCM 格式
    table.insert(wav, writeInt16(1))           -- 单声道
    table.insert(wav, writeInt32(SAMPLE_RATE)) -- 采样率
    table.insert(wav, writeInt32(SAMPLE_RATE * 2)) -- 字节率
    table.insert(wav, writeInt16(2))           -- 块对齐
    table.insert(wav, writeInt16(16))          -- 位深度
    
    -- data 子块
    table.insert(wav, "data")
    table.insert(wav, writeInt32(dataSize))
    
    -- 音频数据
    for i = 1, numSamples do
        local sample = math.floor(samples[i] * 32767)
        sample = math.max(-32768, math.min(32767, sample))
        table.insert(wav, writeInt16(sample))
    end
    
    return table.concat(wav)
end

-- ============================================================================
-- 波形生成器
-- ============================================================================

-- 正弦波
local function sine(phase)
    return math.sin(phase * 2 * math.pi)
end

-- 方波
local function square(phase)
    return phase < 0.5 and 1 or -1
end

-- 锯齿波
local function sawtooth(phase)
    return 2 * phase - 1
end

-- 三角波
local function triangle(phase)
    return 4 * math.abs(phase - 0.5) - 1
end

-- 噪声
local function noise()
    return math.random() * 2 - 1
end

-- ============================================================================
-- 音效生成函数
-- ============================================================================

-- 生成激光射击音效
function SoundGenerator.GenerateLaser(duration, startFreq, endFreq)
    duration = duration or 0.1
    startFreq = startFreq or 880
    endFreq = endFreq or 220
    
    local samples = {}
    local numSamples = math.floor(SAMPLE_RATE * duration)
    local phase = 0
    
    for i = 1, numSamples do
        local t = (i - 1) / numSamples
        local freq = startFreq + (endFreq - startFreq) * t
        local envelope = 1 - t  -- 线性衰减
        
        phase = phase + freq / SAMPLE_RATE
        phase = phase - math.floor(phase)
        
        local sample = square(phase) * envelope * 0.5
        samples[i] = sample
    end
    
    return createWavFile(samples)
end

-- 生成爆炸音效
function SoundGenerator.GenerateExplosion(duration, intensity)
    duration = duration or 0.3
    intensity = intensity or 1.0
    
    local samples = {}
    local numSamples = math.floor(SAMPLE_RATE * duration)
    
    for i = 1, numSamples do
        local t = (i - 1) / numSamples
        -- 快速衰减包络
        local envelope = math.exp(-t * 8) * intensity
        -- 低频噪声 + 一点正弦波
        local freq = 60 + math.random() * 40
        local phase = (i - 1) * freq / SAMPLE_RATE
        local sample = (noise() * 0.7 + sine(phase) * 0.3) * envelope
        samples[i] = sample * 0.6
    end
    
    return createWavFile(samples)
end

-- 生成拾取音效（上升音调）
function SoundGenerator.GeneratePickup(duration)
    duration = duration or 0.15
    
    local samples = {}
    local numSamples = math.floor(SAMPLE_RATE * duration)
    local phase = 0
    
    for i = 1, numSamples do
        local t = (i - 1) / numSamples
        -- 上升频率
        local freq = 400 + t * 800
        -- 淡入淡出包络
        local envelope = math.sin(t * math.pi)
        
        phase = phase + freq / SAMPLE_RATE
        phase = phase - math.floor(phase)
        
        local sample = (sine(phase) * 0.6 + triangle(phase) * 0.4) * envelope * 0.5
        samples[i] = sample
    end
    
    return createWavFile(samples)
end

-- 生成命中音效
function SoundGenerator.GenerateHit(duration, freq)
    duration = duration or 0.08
    freq = freq or 300
    
    local samples = {}
    local numSamples = math.floor(SAMPLE_RATE * duration)
    local phase = 0
    
    for i = 1, numSamples do
        local t = (i - 1) / numSamples
        local envelope = math.exp(-t * 20)
        
        phase = phase + freq / SAMPLE_RATE
        phase = phase - math.floor(phase)
        
        -- 混合波形
        local sample = (square(phase) * 0.3 + noise() * 0.7) * envelope * 0.4
        samples[i] = sample
    end
    
    return createWavFile(samples)
end

-- 生成暴击音效
function SoundGenerator.GenerateCritHit(duration)
    duration = duration or 0.12
    
    local samples = {}
    local numSamples = math.floor(SAMPLE_RATE * duration)
    local phase = 0
    
    for i = 1, numSamples do
        local t = (i - 1) / numSamples
        local freq = 600 - t * 200
        local envelope = math.exp(-t * 15)
        
        phase = phase + freq / SAMPLE_RATE
        phase = phase - math.floor(phase)
        
        local sample = (square(phase) * 0.5 + sine(phase * 2) * 0.3 + noise() * 0.2) * envelope * 0.5
        samples[i] = sample
    end
    
    return createWavFile(samples)
end

-- 生成玩家受伤音效
function SoundGenerator.GeneratePlayerHit(duration)
    duration = duration or 0.2
    
    local samples = {}
    local numSamples = math.floor(SAMPLE_RATE * duration)
    local phase = 0
    
    for i = 1, numSamples do
        local t = (i - 1) / numSamples
        local freq = 150 + math.sin(t * 30) * 50
        local envelope = math.exp(-t * 5)
        
        phase = phase + freq / SAMPLE_RATE
        phase = phase - math.floor(phase)
        
        local sample = (sawtooth(phase) * 0.5 + noise() * 0.5) * envelope * 0.5
        samples[i] = sample
    end
    
    return createWavFile(samples)
end

-- 生成升级音效（琶音上升）
function SoundGenerator.GenerateUpgrade(duration)
    duration = duration or 0.4
    
    local samples = {}
    local numSamples = math.floor(SAMPLE_RATE * duration)
    local phase = 0
    
    -- 琶音频率序列 (C-E-G-C)
    local notes = {262, 330, 392, 523}
    local noteLen = numSamples / #notes
    
    for i = 1, numSamples do
        local t = (i - 1) / numSamples
        local noteIndex = math.floor((i - 1) / noteLen) + 1
        noteIndex = math.min(noteIndex, #notes)
        local freq = notes[noteIndex]
        
        local localT = ((i - 1) % noteLen) / noteLen
        local envelope = (1 - localT) * (1 - t * 0.5)
        
        phase = phase + freq / SAMPLE_RATE
        phase = phase - math.floor(phase)
        
        local sample = (sine(phase) * 0.6 + triangle(phase) * 0.4) * envelope * 0.4
        samples[i] = sample
    end
    
    return createWavFile(samples)
end

-- 生成购买音效
function SoundGenerator.GeneratePurchase(duration)
    duration = duration or 0.15
    
    local samples = {}
    local numSamples = math.floor(SAMPLE_RATE * duration)
    local phase = 0
    
    for i = 1, numSamples do
        local t = (i - 1) / numSamples
        local freq = 600 + t * 400
        local envelope = math.sin(t * math.pi) * 0.8
        
        phase = phase + freq / SAMPLE_RATE
        phase = phase - math.floor(phase)
        
        local sample = triangle(phase) * envelope * 0.4
        samples[i] = sample
    end
    
    return createWavFile(samples)
end

-- 生成波次开始音效
function SoundGenerator.GenerateWaveStart(duration)
    duration = duration or 0.5
    
    local samples = {}
    local numSamples = math.floor(SAMPLE_RATE * duration)
    local phase1, phase2 = 0, 0
    
    for i = 1, numSamples do
        local t = (i - 1) / numSamples
        local envelope = math.sin(t * math.pi)
        
        phase1 = phase1 + 220 / SAMPLE_RATE
        phase2 = phase2 + 330 / SAMPLE_RATE
        phase1 = phase1 - math.floor(phase1)
        phase2 = phase2 - math.floor(phase2)
        
        local sample = (sine(phase1) + sine(phase2) * 0.7) * envelope * 0.3
        samples[i] = sample
    end
    
    return createWavFile(samples)
end

-- 生成游戏结束音效
function SoundGenerator.GenerateGameOver(duration)
    duration = duration or 0.8
    
    local samples = {}
    local numSamples = math.floor(SAMPLE_RATE * duration)
    local phase = 0
    
    -- 下降音阶
    local notes = {392, 330, 262, 196}
    local noteLen = numSamples / #notes
    
    for i = 1, numSamples do
        local t = (i - 1) / numSamples
        local noteIndex = math.floor((i - 1) / noteLen) + 1
        noteIndex = math.min(noteIndex, #notes)
        local freq = notes[noteIndex]
        
        local localT = ((i - 1) % noteLen) / noteLen
        local envelope = (1 - localT * 0.7)
        
        phase = phase + freq / SAMPLE_RATE
        phase = phase - math.floor(phase)
        
        local sample = (sine(phase) * 0.5 + sawtooth(phase) * 0.3) * envelope * 0.4
        samples[i] = sample
    end
    
    return createWavFile(samples)
end

-- 生成胜利音效
function SoundGenerator.GenerateVictory(duration)
    duration = duration or 0.6
    
    local samples = {}
    local numSamples = math.floor(SAMPLE_RATE * duration)
    local phase = 0
    
    -- 上升琶音
    local notes = {262, 330, 392, 523, 659}
    local noteLen = numSamples / #notes
    
    for i = 1, numSamples do
        local t = (i - 1) / numSamples
        local noteIndex = math.floor((i - 1) / noteLen) + 1
        noteIndex = math.min(noteIndex, #notes)
        local freq = notes[noteIndex]
        
        local localT = ((i - 1) % noteLen) / noteLen
        local envelope = (1 - localT * 0.5)
        
        phase = phase + freq / SAMPLE_RATE
        phase = phase - math.floor(phase)
        
        local sample = (sine(phase) * 0.5 + triangle(phase) * 0.5) * envelope * 0.4
        samples[i] = sample
    end
    
    return createWavFile(samples)
end

-- 生成 UI 点击音效
function SoundGenerator.GenerateClick(duration)
    duration = duration or 0.05
    
    local samples = {}
    local numSamples = math.floor(SAMPLE_RATE * duration)
    local phase = 0
    
    for i = 1, numSamples do
        local t = (i - 1) / numSamples
        local freq = 800
        local envelope = math.exp(-t * 30)
        
        phase = phase + freq / SAMPLE_RATE
        phase = phase - math.floor(phase)
        
        local sample = triangle(phase) * envelope * 0.3
        samples[i] = sample
    end
    
    return createWavFile(samples)
end

-- ============================================================================
-- 生成并保存所有音效
-- ============================================================================

function SoundGenerator.GenerateAllSounds(outputDir)
    outputDir = outputDir or "audio/sfx"
    
    local sounds = {
        { name = "laser", generator = SoundGenerator.GenerateLaser },
        { name = "explosion", generator = SoundGenerator.GenerateExplosion },
        { name = "explosion_big", generator = function() return SoundGenerator.GenerateExplosion(0.5, 1.5) end },
        { name = "pickup", generator = SoundGenerator.GeneratePickup },
        { name = "hit", generator = SoundGenerator.GenerateHit },
        { name = "crit", generator = SoundGenerator.GenerateCritHit },
        { name = "player_hit", generator = SoundGenerator.GeneratePlayerHit },
        { name = "upgrade", generator = SoundGenerator.GenerateUpgrade },
        { name = "purchase", generator = SoundGenerator.GeneratePurchase },
        { name = "wave_start", generator = SoundGenerator.GenerateWaveStart },
        { name = "game_over", generator = SoundGenerator.GenerateGameOver },
        { name = "victory", generator = SoundGenerator.GenerateVictory },
        { name = "click", generator = SoundGenerator.GenerateClick },
    }
    
    local generated = {}
    
    for _, sound in ipairs(sounds) do
        local wavData = sound.generator()
        local filename = outputDir .. "/" .. sound.name .. ".wav"
        generated[sound.name] = {
            filename = filename,
            data = wavData
        }
    end
    
    return generated
end

return SoundGenerator
