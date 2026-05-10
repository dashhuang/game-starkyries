-- ============================================================================
-- 星河战姬 Starkyries - 音频系统
-- 背景音乐和游戏音效管理
-- ============================================================================

local Audio = {}

-- ============================================================================
-- 配置
-- ============================================================================
Audio.Config = {
    MasterVolume = 1.0,
    MusicVolume = 0.3,
    SFXVolume = 0.5,
    MusicEnabled = true,
    SFXEnabled = true,
    
    -- 背景音乐
    MusicPath = "audio/music_1767194963898.ogg",
    
    -- 音效文件路径 (全部使用 ElevenLabs AI 生成)
    SFXPaths = {
        -- 通用音效
        explosion = "audio/sfx/explosion.ogg",
        explosionBig = "audio/sfx/explosion_big.ogg",
        pickup = "audio/sfx/pickup.ogg",
        playerHit = "audio/sfx/player_hit.ogg",
        upgrade = "audio/sfx/upgrade.ogg",
        purchase = "audio/sfx/purchase.ogg",
        waveStart = "audio/sfx/wave_start.ogg",
        gameOver = "audio/sfx/game_over.ogg",
        victory = "audio/sfx/victory.ogg",
        click = "audio/sfx/click.ogg",
        confirm = "audio/sfx/confirm.ogg",
        levelup = "audio/sfx/levelup.ogg",
        crit = "audio/sfx/crit.ogg",
        
        -- 武器射击音效（按类型）
        shoot_force_field = "audio/sfx/shoot_force_field.ogg",
        shoot_arc = "audio/sfx/shoot_arc.ogg",
        shoot_missile = "audio/sfx/shoot_missile.ogg",
        shoot_laser = "audio/sfx/shoot_laser.ogg",
        shoot_carrier = "audio/sfx/shoot_carrier.ogg",
        shoot_machinegun = "audio/sfx/shoot_machinegun.ogg",
        
        -- 武器命中音效（按类型）
        hit_force_field = "audio/sfx/hit_force_field.ogg",
        hit_arc = "audio/sfx/hit_arc.ogg",
        hit_missile = "audio/sfx/hit_missile.ogg",
        hit_laser = "audio/sfx/hit_laser.ogg",
        hit_carrier = "audio/sfx/hit_carrier.ogg",
        hit_machinegun = "audio/sfx/hit_machinegun.ogg",
        
        -- 战斗音效
        warpWarning = "audio/sfx/warp_warning.ogg",
        hyperspaceJump = "audio/sfx/hyperspace_jump.ogg",
        bossSpawn = "audio/sfx/boss_spawn.ogg",
        bossPhase = "audio/sfx/boss_phase.ogg",
        
        -- 剧情音效
        storyAlarm = "audio/sfx/story_alarm.ogg",
        
        -- 护盾音效
        shieldRegen = "audio/sfx/shield_regen.ogg",
        shieldBreak = "audio/sfx/shield_break.ogg",
        shieldGain = "audio/sfx/shield_gain.ogg",
        
        -- 商店音效
        shopRefresh = "audio/sfx/shop_refresh.ogg",
        itemLock = "audio/sfx/item_lock.ogg",
        itemUnlock = "audio/sfx/item_unlock.ogg",
        purchaseFail = "audio/sfx/purchase_fail.ogg",
    },
    
    -- 武器类型到音效名称的映射
    WeaponSFXMap = {
        force_field = { shoot = "shoot_force_field", hit = "hit_force_field" },
        arc = { shoot = "shoot_arc", hit = "hit_arc" },
        missile = { shoot = "shoot_missile", hit = "hit_missile" },
        laser = { shoot = "shoot_laser", hit = "hit_laser" },
        carrier = { shoot = "shoot_carrier", hit = "hit_carrier" },
        machinegun = { shoot = "shoot_machinegun", hit = "hit_machinegun" },
    },
    
    -- 音效冷却
    SFXCooldowns = {
        shoot = 0.04,      -- 40ms, ~25次/秒
        hit = 0.02,        -- 20ms, ~50次/秒
        explosion = 0.05,  -- 50ms, ~20次/秒
        pickup = 0.03,     -- 30ms, ~33次/秒
        warp = 0.15,
        shieldRegen = 0.5,
        shieldGain = 0.1,
    }
}

-- ============================================================================
-- 内部状态
-- ============================================================================
local scene = nil
local musicNode = nil
local musicSource = nil
local sfxSounds = {}  -- 缓存的音效
local sfxCooldownTimers = {}
local audioInitialized = false

-- ============================================================================
-- 初始化
-- ============================================================================

function Audio.Init(gameScene)
    if audioInitialized then return end
    
    scene = gameScene
    audioInitialized = true
    
    -- 创建音乐播放节点
    musicNode = scene:CreateChild("MusicNode")
    musicSource = musicNode:CreateComponent("SoundSource")
    musicSource.soundType = "Music"
    musicSource.gain = Audio.Config.MusicVolume * Audio.Config.MasterVolume
    
    -- 预加载所有音效
    for name, path in pairs(Audio.Config.SFXPaths) do
        local sound = cache:GetResource("Sound", path)
        if sound then
            sfxSounds[name] = sound
            print("[Audio] Loaded: " .. name)
        else
            print("[Audio] Warning: Failed to load " .. path)
        end
    end
    
    -- 初始化冷却计时器
    for sfxType, _ in pairs(Audio.Config.SFXCooldowns) do
        sfxCooldownTimers[sfxType] = 0
    end
    
    print("[Audio] Audio system initialized")
end

-- ============================================================================
-- 背景音乐
-- ============================================================================

function Audio.PlayMusic()
    if not musicSource then return end
    
    local music = cache:GetResource("Sound", Audio.Config.MusicPath)
    if music then
        music.looped = true
        musicSource:Play(music)
        print("[Audio] Playing background music")
    end
end

function Audio.StopMusic()
    if musicSource then
        musicSource:Stop()
    end
end

function Audio.SetMusicVolume(volume)
    Audio.Config.MusicVolume = math.max(0, math.min(1, volume))
    if musicSource then
        if Audio.Config.MusicEnabled then
            musicSource.gain = Audio.Config.MusicVolume * Audio.Config.MasterVolume
        else
            musicSource.gain = 0
        end
    end
end

-- ============================================================================
-- 音效播放核心
-- ============================================================================

local function CanPlaySFX(sfxType)
    if not sfxType then return true end
    local cooldown = Audio.Config.SFXCooldowns[sfxType] or 0
    local timer = sfxCooldownTimers[sfxType] or 0
    return timer <= 0
end

local function ResetSFXCooldown(sfxType)
    if not sfxType then return end
    local cooldown = Audio.Config.SFXCooldowns[sfxType] or 0
    sfxCooldownTimers[sfxType] = cooldown
end

-- 播放音效
local function PlaySFX(soundName, cooldownType, gainMult)
    if not scene then 
        print("[Audio] No scene!")
        return 
    end
    if not Audio.Config.SFXEnabled then
        return  -- 音效已禁用
    end
    if not CanPlaySFX(cooldownType) then 
        return  -- 冷却中，静默跳过
    end
    ResetSFXCooldown(cooldownType)
    
    local sound = sfxSounds[soundName]
    if not sound then 
        print("[Audio] Sound not loaded: " .. soundName)
        return 
    end
    
    -- 创建临时音效节点
    local sfxNode = scene:CreateChild("SFX")
    local source = sfxNode:CreateComponent("SoundSource")
    source.soundType = "Effect"
    source.autoRemoveMode = REMOVE_NODE
    
    local gain = (gainMult or 1.0) * Audio.Config.SFXVolume * Audio.Config.MasterVolume
    source:Play(sound, sound.frequency, gain)
end

-- ============================================================================
-- 音效播放接口
-- ============================================================================

function Audio.PlayShoot(weaponType)
    -- 根据武器类型选择射击音效
    local sfxMap = Audio.Config.WeaponSFXMap[weaponType]
    local soundName = sfxMap and sfxMap.shoot or "shoot_force_field"
    PlaySFX(soundName, "shoot", 0.5)
end

function Audio.PlayHit(isCrit, weaponType)
    if isCrit then
        PlaySFX("crit", "hit", 1.0)
    else
        -- 根据武器类型选择命中音效
        local sfxMap = Audio.Config.WeaponSFXMap[weaponType]
        local soundName = sfxMap and sfxMap.hit or "hit_force_field"
        PlaySFX(soundName, "hit", 0.7)
    end
end

function Audio.PlayExplosion(isBoss)
    if isBoss then
        PlaySFX("explosionBig", "explosion", 1.0)
    else
        PlaySFX("explosion", "explosion", 0.9)
    end
end

function Audio.PlayPickup(pickupType)
    PlaySFX("pickup", "pickup", 0.9)
end

function Audio.PlayPlayerHit()
    PlaySFX("playerHit", nil, 1.0)
end

function Audio.PlayUIClick()
    PlaySFX("click", nil, 0.7)
end

function Audio.PlayWaveStart(waveNum)
    PlaySFX("waveStart", nil, 0.8)
end

function Audio.PlayUpgrade()
    PlaySFX("upgrade", nil, 1.0)
end

function Audio.PlayPurchase()
    PlaySFX("purchase", nil, 0.9)
end

function Audio.PlayWarpWarning()
    PlaySFX("warpWarning", "warp", 0.6)
end

function Audio.PlayHyperspaceJump()
    PlaySFX("hyperspaceJump", nil, 0.8)
end

function Audio.PlayBossSpawn()
    PlaySFX("bossSpawn", nil, 0.8)
end

function Audio.PlayBossPhase()
    PlaySFX("bossPhase", nil, 0.7)
end

function Audio.PlayStoryAlarm()
    PlaySFX("storyAlarm", nil, 0.6)
end

function Audio.PlayShieldRegen()
    PlaySFX("shieldRegen", "shieldRegen", 0.3)
end

function Audio.PlayShieldBreak()
    PlaySFX("shieldBreak", nil, 0.9)
end

function Audio.PlayShieldGain()
    PlaySFX("shieldGain", "shieldGain", 0.5)
end

function Audio.PlayShopRefresh()
    PlaySFX("shopRefresh", nil, 0.6)
end

function Audio.PlayItemLock()
    PlaySFX("itemLock", nil, 0.5)
end

function Audio.PlayItemUnlock()
    PlaySFX("itemUnlock", nil, 0.5)
end

function Audio.PlayPurchaseFail()
    PlaySFX("purchaseFail", nil, 0.7)
end

function Audio.PlayGameOver()
    PlaySFX("gameOver", nil, 1.0)
end

function Audio.PlayVictory()
    PlaySFX("victory", nil, 1.0)
end

function Audio.PlayConfirm()
    PlaySFX("confirm", nil, 0.8)
end

function Audio.PlayLevelUp()
    PlaySFX("levelup", nil, 1.0)
end

-- ============================================================================
-- 更新
-- ============================================================================

function Audio.Update(dt)
    -- 更新冷却计时器
    for sfxType, timer in pairs(sfxCooldownTimers) do
        if timer > 0 then
            sfxCooldownTimers[sfxType] = timer - dt
        end
    end
end

-- ============================================================================
-- 音量控制
-- ============================================================================

function Audio.SetMasterVolume(volume)
    Audio.Config.MasterVolume = math.max(0, math.min(1, volume))
    if musicSource then
        musicSource.gain = Audio.Config.MusicVolume * Audio.Config.MasterVolume
    end
end

function Audio.SetSFXVolume(volume)
    Audio.Config.SFXVolume = math.max(0, math.min(1, volume))
end

-- 别名，兼容 OptionsUI 的调用
Audio.SetSfxVolume = Audio.SetSFXVolume

-- ============================================================================
-- 音量获取 (OptionsUI 需要)
-- ============================================================================

function Audio.GetMusicVolume()
    return Audio.Config.MusicVolume
end

function Audio.GetSfxVolume()
    return Audio.Config.SFXVolume
end

function Audio.GetMasterVolume()
    return Audio.Config.MasterVolume
end

-- ============================================================================
-- 启用/禁用控制 (OptionsUI 需要)
-- ============================================================================

function Audio.IsMusicEnabled()
    return Audio.Config.MusicEnabled
end

function Audio.IsSfxEnabled()
    return Audio.Config.SFXEnabled
end

function Audio.SetMusicEnabled(enabled)
    Audio.Config.MusicEnabled = enabled
    if musicSource then
        if enabled then
            musicSource.gain = Audio.Config.MusicVolume * Audio.Config.MasterVolume
        else
            musicSource.gain = 0
        end
    end
end

function Audio.SetSfxEnabled(enabled)
    Audio.Config.SFXEnabled = enabled
end

-- ============================================================================
-- 清理
-- ============================================================================

function Audio.Cleanup()
    Audio.StopMusic()
    
    if musicNode then
        musicNode:Remove()
        musicNode = nil
        musicSource = nil
    end
    
    -- 重置所有状态
    scene = nil
    sfxSounds = {}
    sfxCooldownTimers = {}
    audioInitialized = false
    
    print("[Audio] Audio system cleaned up")
end

return Audio
