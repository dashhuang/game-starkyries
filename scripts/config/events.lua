-- ============================================================================
-- 星河战姬 Starkyries - 事件定义
-- 定义所有系统事件名称，统一管理避免字符串拼写错误
-- ============================================================================

local Events = {
    -- ========================================================================
    -- 敌人相关事件
    -- ========================================================================
    
    ENEMY_DEATH = "enemy:death",               -- 敌人死亡 (enemy)
    ENEMY_DAMAGE = "enemy:damage",             -- 敌人受伤 (enemy, damage, isCrit)
    ENEMY_SPAWN = "enemy:spawn",               -- 敌人生成 (enemy)
    ENEMY_BURN_DAMAGE = "enemy:burnDamage",    -- 燃烧伤害 (enemy, damage)
    
    -- ========================================================================
    -- Boss相关事件
    -- ========================================================================
    
    BOSS_SPAWN = "boss:spawn",                 -- Boss生成 (bossEnemy, spawnType, count)
    BOSS_PHASE_CHANGE = "boss:phaseChange",    -- Boss阶段变化 (bossEnemy, newPhase, phaseName)
    
    -- ========================================================================
    -- 玩家相关事件
    -- ========================================================================
    
    PLAYER_DAMAGE = "player:damage",           -- 玩家受伤 (damage, result)
    PLAYER_HEAL = "player:heal",               -- 玩家治疗 (amount)
    PLAYER_LEVEL_UP = "player:levelUp",        -- 玩家升级 (newLevel)
    PLAYER_DEATH = "player:death",             -- 玩家死亡 ()
    
    -- ========================================================================
    -- 战斗波次相关事件
    -- ========================================================================
    
    WAVE_START = "battle:waveStart",           -- 波次开始 (waveNum)
    WAVE_COMPLETE = "battle:waveComplete",     -- 波次完成 (waveNum)
    ALL_WAVES_COMPLETE = "battle:allWavesComplete", -- 所有波次完成 ()
    
    -- ========================================================================
    -- 生成相关事件
    -- ========================================================================
    
    SPAWN_ENEMY = "spawn:enemy",               -- 生成敌人请求 (enemyType, x, y, fromWarp)
    WARP_WARNING = "spawn:warpWarning",        -- 跃迁警告 (x, y, enemyType, delay)
    WARP_COMPLETE = "spawn:warpComplete",      -- 跃迁完成 (x, y, enemyType)
    
    -- ========================================================================
    -- 拾取相关事件
    -- ========================================================================
    
    PICKUP_COLLECT = "pickup:collect",         -- 拾取物被收集 (pickup)
    PICKUP_SPAWN = "pickup:spawn",             -- 拾取物生成 (pickup)
    
    -- ========================================================================
    -- 武器相关事件
    -- ========================================================================
    
    WEAPON_FIRE = "weapon:fire",               -- 武器开火 (weapon, target)
    WEAPON_HIT = "weapon:hit",                 -- 武器命中 (weapon, target, damage, isCrit)
    
    -- ========================================================================
    -- 无人机相关事件
    -- ========================================================================
    
    DRONE_FIRE = "drone:fire",                 -- 无人机开火 (drone, targetX, targetY, damage, isCrit)
    
    -- ========================================================================
    -- 商店相关事件
    -- ========================================================================
    
    SHOP_ENTER = "shop:enter",                 -- 进入商店 ()
    SHOP_EXIT = "shop:exit",                   -- 离开商店 ()
    PURCHASE_WEAPON = "shop:purchaseWeapon",   -- 购买武器 (weaponId, tier)
    PURCHASE_MODULE = "shop:purchaseModule",   -- 购买模块 (moduleId)
    
    -- ========================================================================
    -- 升级相关事件
    -- ========================================================================
    
    UPGRADE_START = "upgrade:start",           -- 开始升级选择 ()
    UPGRADE_SELECT = "upgrade:select",         -- 选择升级 (upgradeId)
    UPGRADE_COMPLETE = "upgrade:complete",     -- 升级完成 ()
    
    -- ========================================================================
    -- 游戏状态事件
    -- ========================================================================
    
    GAME_START = "game:start",                 -- 游戏开始 (shipConfig, weaponId)
    GAME_OVER = "game:over",                   -- 游戏结束 ()
    GAME_VICTORY = "game:victory",             -- 游戏胜利 ()
    GAME_RESTART = "game:restart",             -- 游戏重启 ()
    GAME_TICK = "game:tick",                   -- 游戏心跳 (dt) 每秒触发一次，用于周期性效果
    
    -- ========================================================================
    -- 视觉效果事件
    -- ========================================================================
    
    EXPLOSION = "effect:explosion",            -- 爆炸效果 (x, y, scale, duration, color)
    SCREEN_SHAKE = "effect:screenShake",       -- 屏幕震动 (duration, intensity)
    
    -- ========================================================================
    -- 音频事件
    -- ========================================================================
    
    AUDIO_PLAY_SFX = "audio:playSfx",          -- 播放音效 (sfxName)
    AUDIO_PLAY_MUSIC = "audio:playMusic",      -- 播放音乐 (musicName)
}

return Events
