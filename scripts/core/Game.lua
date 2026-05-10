-- ============================================================================
-- 星河战姬 Starkyries - 游戏状态管理
-- ============================================================================

local Settings = require("config.settings")
local Ships = require("config.ships")

-- TagSetBonuses 延迟加载（避免循环依赖）
local TagSetBonuses = nil
local function GetTagSetBonuses()
    if not TagSetBonuses then
        TagSetBonuses = require("data.TagSetBonuses")
    end
    return TagSetBonuses
end

local Game = {}

-- 调试选项
Game.debugInvincible = false  -- 无敌模式（血量最低为1）

-- Player 延迟加载（避免循环依赖）
local Player = nil
local function GetPlayer()
    if not Player then
        Player = require("entities.Player")
    end
    return Player
end

-- Overlays 延迟加载（避免循环依赖）
local Overlays = nil
local function GetOverlays()
    if not Overlays then
        Overlays = require("ui.Overlays")
    end
    return Overlays
end

-- SaveManager 延迟加载（避免循环依赖）
local SaveManager = nil
local function GetSaveManager()
    if not SaveManager then
        SaveManager = require("core.SaveManager")
    end
    return SaveManager
end

-- 音频模块延迟加载（避免循环依赖）
local Audio = nil
local function GetAudio()
    if not Audio then
        Audio = require("core.Audio")
    end
    return Audio
end

-- StatsManager 延迟加载（避免循环依赖）
local StatsManager = nil
local function GetStatsManager()
    if not StatsManager then
        StatsManager = require("core.StatsManager")
    end
    return StatsManager
end

-- ============================================================================
-- 游戏状态枚举
-- ============================================================================
Game.States = {
    PLAYING = 1,
    PAUSED = 2,
    SHOP = 3,
    BRIDGE_UPGRADE = 4,
    GAME_OVER = 5,
    VICTORY = 6,
    MENU = 7,
    HYPERSPACE = 8,      -- 超空间跳跃动画
    PLAYER_DEATH = 9,    -- 玩家死亡动画
    CRATE_OPEN = 10      -- 补给箱开箱界面
}

-- 当前状态
Game.currentState = Game.States.PLAYING

-- ============================================================================
-- 玩家数据
-- ============================================================================
Game.player = {}

-- 初始化玩家数据
function Game.InitPlayer(shipId)
    local shipConfig = Ships.Get(shipId) or Ships.GetDefault()
    local defaults = Settings.DefaultPlayerStats
    
    Game.player = {
        -- 战舰信息
        shipId = shipConfig.id,
        shipName = shipConfig.name,
        captain = shipConfig.captain,
        
        -- 护盾和防御
        shield = shipConfig.shield,
        maxShield = shipConfig.shield,
        shieldRegen = shipConfig.shieldRegen,
        armor = shipConfig.armor,
        
        -- 移动
        moveSpeed = shipConfig.moveSpeed,
        
        -- 资源
        crystals = Settings.InitialResources.crystals,  -- 初始晶体（对标Brotato：30）
        totalCrystals = 0,     -- 累计晶体（统计用）
        xp = 0,                -- 当前经验值
        totalXp = 0,           -- 累计经验值（用于舰桥升级）
        
        -- 状态
        facingRight = true,
        invincibleTime = 0,
        
        -- 属性加成
        damageMultiplier = defaults.damageMultiplier,
        fireRateMultiplier = defaults.fireRateMultiplier,
        crystalMultiplier = defaults.crystalMultiplier,
        energyAbsorb = defaults.energyAbsorb,
        dodgeChance = defaults.dodgeChance,
        critChance = defaults.critChance,
        critDamage = defaults.critDamage,
        
        -- 额外属性
        rangeMultiplier = 1.0,
        pickupRangeMultiplier = 1.0,
        damageTakenMultiplier = 1.0,
        maxWeaponSlots = #shipConfig.weaponSlots,
        killHeal = 0,
        killCrystalBonus = 0,  -- 击毁+晶体（来自粒子机炮等武器）
        
        -- 穿透属性（通过模块获得）
        piercing = 0,           -- 额外穿透次数（+1穿透=可穿透1个额外敌舰）
        piercingDamage = 1.0,   -- 穿透伤害系数（默认100%，-20%则为0.8）
        
        -- 模块效果属性（通过道具获得，非升级选项）
        xpMultiplier = 1.0,      -- 经验加成（经验强化器模块）
        shopDiscount = 0,        -- 商店折扣（经济学家模块）
        freeRefreshes = 0,       -- 免费刷新次数（危险兔子模块）
        bossDamage = 0,          -- Boss额外伤害（银弹模块）
        
        -- 特殊状态
        hasBerserker = false,
        hasEmergencyBoost = false,
        hasExpShare = false,
        
        -- 装备
        -- 🔧 统一数据源：直接引用 Player.weapons，避免双数组同步问题
        weapons = GetPlayer().weapons,  -- 与 Player.weapons 是同一个数组
        modules = {},  -- {moduleId = count}
        
        -- 舰桥升级（基于经验值）
        bridgeLevel = 0,
        nextUpgradeXp = 16,  -- 首次升级需要16经验 = (1+3)²（会在CheckAndAccumulateUpgrades中更新）
        pendingUpgrades = 0,  -- 待处理的升级次数
        
        -- 战舰配置引用
        shipConfig = shipConfig,
    }
    
    -- 应用战舰特殊能力
    if shipConfig.special then
        Game.ApplyShipSpecial(shipConfig.special)
    end
    
    return Game.player
end

-- 应用战舰特殊能力
function Game.ApplyShipSpecial(special)
    -- 通用加成（所有战舰都可能有）
    if special.crystalBonus then
        Game.player.crystalMultiplier = Game.player.crystalMultiplier + special.crystalBonus
    end
    if special.critBonus then
        Game.player.critChance = Game.player.critChance + special.critBonus
    end
    
    -- 特殊能力（需要 id 标识）
    if special.id == "berserker" then
        Game.player.hasBerserker = true
    end
    -- 其他特殊能力在战斗中触发
end

-- ============================================================================
-- 武器标签套装效果
-- ============================================================================

-- 存储当前套装加成（用于显示和重新计算）
Game.tagSetBonuses = {}

-- 重新计算并应用武器标签套装效果
-- 应在武器添加、移除、合并后调用
function Game.RecalculateTagSetBonuses()
    local p = Game.player
    if not p or not p.weapons then return end
    
    local TSB = GetTagSetBonuses()
    
    -- 先移除旧的套装加成（11个套装效果）
    local oldBonuses = Game.tagSetBonuses
    if oldBonuses then
        if oldBonuses.meleeDamageBonus then p.meleeDamageBonus = (p.meleeDamageBonus or 0) - oldBonuses.meleeDamageBonus end
        if oldBonuses.energyAbsorb then p.energyAbsorb = (p.energyAbsorb or 0) - oldBonuses.energyAbsorb end
        if oldBonuses.evasion then p.dodgeChance = (p.dodgeChance or 0) - oldBonuses.evasion end
        if oldBonuses.armor then p.armor = (p.armor or 0) - oldBonuses.armor end
        if oldBonuses.maxShield then
            p.maxShield = (p.maxShield or 0) - oldBonuses.maxShield
            if p.shield > p.maxShield then p.shield = p.maxShield end
        end
        if oldBonuses.rangeBonus then p.rangeBonus = (p.rangeBonus or 0) - oldBonuses.rangeBonus end
        if oldBonuses.explosionRange then p.explosionRangeMultiplier = (p.explosionRangeMultiplier or 1) - oldBonuses.explosionRange end
        if oldBonuses.energyDamageBonus then p.energyDamageBonus = (p.energyDamageBonus or 0) - oldBonuses.energyDamageBonus end
        if oldBonuses.engineering then p.engineering = (p.engineering or 0) - oldBonuses.engineering end
        if oldBonuses.shieldRegen then p.shieldRegen = (p.shieldRegen or 0) - oldBonuses.shieldRegen end
        if oldBonuses.critChance then p.critChance = (p.critChance or 0) - oldBonuses.critChance end
        if oldBonuses.harvesting then p.harvesting = (p.harvesting or 0) - oldBonuses.harvesting end
        if oldBonuses.damageMultiplier then p.damageMultiplier = (p.damageMultiplier or 1) - oldBonuses.damageMultiplier end
    end
    
    -- 计算新的套装加成
    local newBonuses = TSB.CalculateTotalBonuses(p.weapons)
    Game.tagSetBonuses = newBonuses
    
    -- 应用新的套装加成（11个套装效果）
    if newBonuses.meleeDamageBonus > 0 then p.meleeDamageBonus = (p.meleeDamageBonus or 0) + newBonuses.meleeDamageBonus end
    if newBonuses.energyAbsorb > 0 then p.energyAbsorb = (p.energyAbsorb or 0) + newBonuses.energyAbsorb end
    if newBonuses.evasion > 0 then p.dodgeChance = (p.dodgeChance or 0) + newBonuses.evasion end
    if newBonuses.armor ~= 0 then p.armor = (p.armor or 0) + newBonuses.armor end  -- 虚灵套装可能为负数
    if newBonuses.maxShield > 0 then
        p.maxShield = (p.maxShield or 0) + newBonuses.maxShield
        -- 增加最大护盾时也增加当前护盾
        p.shield = math.min((p.shield or 0) + newBonuses.maxShield, p.maxShield)
    end
    if newBonuses.rangeBonus > 0 then p.rangeBonus = (p.rangeBonus or 0) + newBonuses.rangeBonus end  -- 单位：米
    if newBonuses.explosionRange > 0 then p.explosionRangeMultiplier = (p.explosionRangeMultiplier or 1) + newBonuses.explosionRange end
    if newBonuses.energyDamageBonus > 0 then p.energyDamageBonus = (p.energyDamageBonus or 0) + newBonuses.energyDamageBonus end
    if newBonuses.engineering > 0 then p.engineering = (p.engineering or 0) + newBonuses.engineering end
    if newBonuses.shieldRegen > 0 then p.shieldRegen = (p.shieldRegen or 0) + newBonuses.shieldRegen end
    if newBonuses.critChance > 0 then p.critChance = (p.critChance or 0) + newBonuses.critChance end
    if newBonuses.harvesting > 0 then p.harvesting = (p.harvesting or 0) + newBonuses.harvesting end
    if newBonuses.damageMultiplier > 0 then p.damageMultiplier = (p.damageMultiplier or 1) + newBonuses.damageMultiplier end
    
    -- 调试输出
    local TSBModule = GetTagSetBonuses()
    local activeSets = TSBModule.GetActiveSetBonuses(p.weapons)
    local activeCount = 0
    for tag, data in pairs(activeSets) do
        if data.level > 0 then
            activeCount = activeCount + 1
            print(string.format("[TagSet] %s: %d件 (Lv%d) - %s", tag, data.count, data.level, data.bonus and data.bonus.desc or ""))
        end
    end
    if activeCount > 0 then
        print(string.format("[TagSet] 共激活 %d 个套装效果", activeCount))
    end
end

-- 获取当前激活的套装效果（用于UI显示）
function Game.GetActiveTagSetBonuses()
    local p = Game.player
    if not p or not p.weapons then return {} end
    
    local TSB = GetTagSetBonuses()
    return TSB.GetActiveSetBonuses(p.weapons)
end

-- ============================================================================
-- 战斗数据
-- ============================================================================
Game.battle = {}

function Game.InitBattle()
    Game.battle = {
        currentWave = 1,
        waveTimer = 0,
        spawnTimer = 0,
        totalKills = 0,
        waveActive = false,
        waveCompleteDelay = 0,
        waveCrystalsCollected = 0,  -- 本波收集的晶体（用于波次结束时计算资源回收加成）
        killedBy = nil,  -- 击毁玩家的敌人信息 {id, name}
        -- 实时DPS统计
        totalDamageDealt = 0,       -- 累计总伤害
        damageHistory = {},         -- 伤害历史记录 {timestamp, damage}
        realtimeDPS = 0,            -- 实时DPS（滚动窗口计算）
        -- 战斗统计
        totalCrystalsEarned = 0,    -- 总获得晶体
        totalCrystalsSpent = 0,     -- 总消耗晶体
        totalRefreshes = 0,         -- 总刷新次数
        totalPurchases = 0,         -- 总购买次数
        totalWeaponsBought = 0,     -- 购买武器数量
        totalModulesBought = 0,     -- 购买模块数量
        playTime = 0,               -- 游戏时长（秒）
    }
    return Game.battle
end

-- ============================================================================
-- 实时DPS统计
-- ============================================================================

-- 记录造成的伤害（每次对敌人造成伤害时调用）
function Game.RecordDamage(damage)
    if not Game.battle then return end
    
    Game.battle.totalDamageDealt = (Game.battle.totalDamageDealt or 0) + damage
    
    -- 记录到历史（用于滚动窗口计算）
    local timestamp = Game.battle.waveTimer or 0
    table.insert(Game.battle.damageHistory, {time = timestamp, damage = damage})
end

-- 更新实时DPS（在Game.Update中调用）
local DPS_WINDOW = 5.0  -- 5秒滚动窗口

function Game.UpdateRealtimeDPS()
    if not Game.battle or not Game.battle.damageHistory then return end
    
    local now = Game.battle.waveTimer or 0
    local windowStart = now - DPS_WINDOW
    local history = Game.battle.damageHistory
    
    -- 原地过滤过期记录（避免创建新表）
    local totalInWindow = 0
    local writeIdx = 1
    
    for readIdx = 1, #history do
        local record = history[readIdx]
        if record.time >= windowStart then
            totalInWindow = totalInWindow + record.damage
            if writeIdx ~= readIdx then
                history[writeIdx] = record
            end
            writeIdx = writeIdx + 1
        end
    end
    
    -- 清除尾部多余元素
    for i = writeIdx, #history do
        history[i] = nil
    end
    
    -- 计算DPS（窗口内伤害 / 实际经过时间）
    local elapsed = math.min(now, DPS_WINDOW)  -- 开局不足5秒时用实际时间
    if elapsed > 0.1 then
        Game.battle.realtimeDPS = totalInWindow / elapsed
    else
        Game.battle.realtimeDPS = 0
    end
end

-- 获取实时DPS
function Game.GetRealtimeDPS()
    return Game.battle and Game.battle.realtimeDPS or 0
end

-- ============================================================================
-- 状态管理
-- ============================================================================

function Game.SetState(newState)
    local oldState = Game.currentState
    Game.currentState = newState
    
    -- 状态变化回调
    if Game.onStateChange then
        Game.onStateChange(oldState, newState)
    end
end

function Game.GetState()
    return Game.currentState
end

function Game.IsPlaying()
    return Game.currentState == Game.States.PLAYING
end

function Game.IsPaused()
    return Game.currentState == Game.States.PAUSED or 
           Game.currentState == Game.States.BRIDGE_UPGRADE
end

-- ============================================================================
-- 游戏流程
-- ============================================================================

function Game.Start(shipId)
    Game.InitPlayer(shipId or "Pioneer")
    Game.InitBattle()
    Game.SetState(Game.States.PLAYING)
    
    -- 重置 GameOver 图片缓存（确保使用当前舰长的图片）
    GetOverlays().ResetGameOverImage()
end

function Game.Restart()
    Game.Start(Game.player.shipId)
end

-- 开始玩家死亡动画（由 main.lua 实现具体动画）
Game.onPlayerDeath = nil  -- function(onComplete) 回调

-- 游戏结束前的拦截回调（用于教程首次战败对话）
-- 返回 true 表示已拦截，不执行默认 GameOver
Game.onBeforeGameOver = nil  -- function() -> boolean

function Game.StartPlayerDeath()
    Game.SetState(Game.States.PLAYER_DEATH)
    if Game.onPlayerDeath then
        Game.onPlayerDeath(function()
            Game.GameOver()
        end)
    else
        -- 如果没有设置动画回调，直接结束
        Game.GameOver()
    end
end

function Game.GameOver()
    -- 检查是否有拦截回调（如教程首次战败对话）
    if Game.onBeforeGameOver then
        local intercepted = Game.onBeforeGameOver()
        if intercepted then
            return  -- 已被拦截，不执行默认逻辑
        end
    end
    
    Game.SetState(Game.States.GAME_OVER)
    GetAudio().PlayGameOver()
    
    -- 保存跨局统计
    local finalWave = Game.battle and Game.battle.currentWave or 1
    local playTime = Game.battle and Game.battle.playTime or 0
    GetStatsManager().OnGameEnd(playTime, finalWave)
    
    -- 游戏结束时清除存档
    GetSaveManager().OnGameEnd()
end

-- 强制进入 GameOver 状态（跳过拦截检查，用于教程对话结束后）
function Game.ForceGameOver()
    Game.SetState(Game.States.GAME_OVER)
    GetAudio().PlayGameOver()
    
    -- 保存跨局统计
    local finalWave = Game.battle and Game.battle.currentWave or 1
    local playTime = Game.battle and Game.battle.playTime or 0
    GetStatsManager().OnGameEnd(playTime, finalWave)
    
    GetSaveManager().OnGameEnd()
end

function Game.Victory()
    Game.SetState(Game.States.VICTORY)
    GetAudio().PlayVictory()
    -- 胜利时清除存档
    GetSaveManager().OnGameEnd()
end

-- ============================================================================
-- 玩家属性操作
-- ============================================================================

-- 受伤
-- @param damage 伤害值
-- @param enemyInfo 可选，造成伤害的敌人信息 {id, name}
function Game.TakeDamage(damage, enemyInfo)
    -- 完美防御：周期性无敌
    if Game.player.perfectDefenseActive then
        return 0, "perfect_defense"
    end
    
    -- 闪避判定（基础闪避 + 紧急闪避 + 幻影模块）
    local totalDodge = Game.player.dodgeChance or 0
    
    -- 紧急闪避：护盾<30%时额外+20%闪避
    if Game.player.hasEmergencyDodge then
        local healthRatio = Game.player.shield / Game.player.maxShield
        local threshold = Game.player.emergencyDodgeThreshold or 0.30
        if healthRatio < threshold then
            totalDodge = totalDodge + (Game.player.emergencyDodgeBonus or 0.20)
        end
    end
    
    -- 幻影模块：受伤后3秒内额外+15%闪避
    if Game.player.hasPhantomModule and Game.player.phantomTimer and Game.player.phantomTimer > 0 then
        totalDodge = totalDodge + (Game.player.phantomDodgeBonus or 0.15)
    end
    
    if math.random() < totalDodge then
        return 0, "dodge"
    end
    
    -- 装甲减伤
    local actualDamage = math.max(1, damage - Game.player.armor)
    
    -- 受伤加成
    actualDamage = actualDamage * Game.player.damageTakenMultiplier
    
    -- 扣除护盾
    Game.player.shield = Game.player.shield - actualDamage
    
    -- 无敌时间
    Game.player.invincibleTime = Settings.Combat.InvincibleTime
    
    -- 触发受击闪白
    GetPlayer().TriggerHitFlash()
    
    -- ========== 受伤触发的模块效果 ==========
    
    -- 充能器：受伤重置计时器
    if Game.player.hasCharger then
        Game.player.chargerTimer = 0
    end
    
    -- 幻影模块：受伤后获得+15%闪避3秒
    if Game.player.hasPhantomModule then
        Game.player.phantomTimer = Game.player.phantomDuration or 3.0
    end
    
    -- 愤怒激活：受伤时+10%伤害持续3秒
    if Game.player.hasRageActivate then
        Game.player.rageActivateTimer = Game.player.rageActivateDuration or 3.0
    end
    
    -- 紧急加速：受伤时+30%速度持续2秒
    if Game.player.hasEmergencyBoost then
        Game.player.emergencyBoostTimer = Game.player.emergencyBoostDuration or 2.0
    end
    
    -- 反应装甲：受伤时返还伤害给攻击者
    if Game.player.hasReactiveArmor and enemyInfo then
        -- 返还伤害在Enemy模块中处理（需要知道是哪个敌人）
        Game.player.reactiveArmorPending = {
            damage = Game.player.reactiveArmorDamage or 2,
            enemyInfo = enemyInfo
        }
    end
    
    -- 反击协议：受伤时返还5伤害
    if Game.player.hasCounterProtocol and enemyInfo then
        Game.player.counterProtocolPending = {
            damage = Game.player.counterProtocolDamage or 5,
            enemyInfo = enemyInfo
        }
    end
    
    -- 无敌模式：血量最低为1
    if Game.debugInvincible and Game.player.shield <= 0 then
        Game.player.shield = 1
        return actualDamage, "hit"
    end
    
    -- 死亡检查
    if Game.player.shield <= 0 then
        -- 紧急护盾（每波1次，恢复护盾）
        if Game.player.hasEmergencyShield and not Game.player.emergencyShieldUsedThisWave then
            Game.player.emergencyShieldUsedThisWave = true
            local restoreAmount = Game.player.emergencyShieldAmount or 15
            Game.player.shield = restoreAmount
            
            -- 视觉反馈
            local PlayerMod = require("entities.Player")
            PlayerMod.TriggerHitFlash()  -- 闪白提示
            
            -- 给予短暂无敌时间
            Game.player.invincibleTime = 1.0
            
            return actualDamage, "emergency_shield"
        end
        
        -- 传送装置免死（每波1次）
        if Game.player.hasTeleporter and not Game.player.teleporterUsedThisWave then
            Game.player.teleporterUsedThisWave = true
            Game.player.shield = 1  -- 保留1点护盾
            
            -- 传送到安全位置（地图中心偏移随机位置）
            local PlayerMod = require("entities.Player")
            local safeX = (math.random() - 0.5) * 6  -- -3 到 3
            local safeY = (math.random() - 0.5) * 4  -- -2 到 2
            PlayerMod.SetPosition(safeX, safeY)
            
            -- 传送视觉效果
            local Effects = require("entities.Effects")
            if Effects.CreateTeleportEffect then
                Effects.CreateTeleportEffect(Game.scene, safeX, safeY)
            end
            
            -- 播放传送音效
            local AudioMod = require("core.Audio")
            if AudioMod.PlayTeleport then
                AudioMod.PlayTeleport()
            end
            
            -- 给予短暂无敌时间
            Game.player.invincibleTime = 1.5
            
            return actualDamage, "teleport"
        end
        
        -- 播放护盾破碎音效
        local AudioMod = require("core.Audio")
        AudioMod.PlayShieldBreak()
        
        -- 记录击毁玩家的敌人
        if enemyInfo and Game.battle then
            Game.battle.killedBy = {
                id = enemyInfo.id,
                name = enemyInfo.name or enemyInfo.id,
            }
        end
        Game.StartPlayerDeath()
    end
    
    return actualDamage, "hit"
end

-- 治疗
function Game.Heal(amount)
    Game.player.shield = math.min(Game.player.shield + amount, Game.player.maxShield)
end

-- 直接伤害（忽略无敌时间和装甲，用于自伤效果如恶魔契约）
function Game.DirectDamage(amount)
    Game.player.shield = Game.player.shield - amount
    
    -- 无敌模式：血量最低为1
    if Game.debugInvincible and Game.player.shield <= 0 then
        Game.player.shield = 1
        return
    end
    
    -- 死亡检查
    if Game.player.shield <= 0 then
        Game.StartPlayerDeath()
    end
end

-- 获得晶体（货币，用于商店购买）
-- 注意：crystalMultiplier 不在此处应用，而是在波次结束时统一结算
function Game.AddCrystals(amount)
    Game.player.crystals = Game.player.crystals + amount
    Game.player.totalCrystals = Game.player.totalCrystals + amount
    -- 记录本波收集的晶体（用于波次结束时计算资源回收加成）
    if Game.battle then
        Game.battle.waveCrystalsCollected = (Game.battle.waveCrystalsCollected or 0) + amount
        Game.battle.totalCrystalsEarned = (Game.battle.totalCrystalsEarned or 0) + amount
    end
    -- 更新跨局统计
    GetStatsManager().OnCrystalsEarned(amount)
    return amount
end

-- 波次结束时应用资源回收加成（对标Brotato收获机制）
-- 公式：bonus = waveCrystalsCollected × (crystalMultiplier - 1)
function Game.ApplyWaveEndCrystalBonus()
    if not Game.battle or not Game.player then return 0 end
    
    local collected = Game.battle.waveCrystalsCollected or 0
    local multiplier = Game.player.crystalMultiplier or 1.0
    local bonusRate = multiplier - 1.0  -- 例如 1.05 → 0.05 (5%)
    
    if bonusRate > 0 and collected > 0 then
        local bonus = math.floor(collected * bonusRate)
        if bonus > 0 then
            Game.player.crystals = Game.player.crystals + bonus
            Game.player.totalCrystals = Game.player.totalCrystals + bonus
            return bonus
        end
    end
    
    return 0
end

-- 重置本波晶体收集计数（新波次开始时调用）
function Game.ResetWaveCrystals()
    if Game.battle then
        Game.battle.waveCrystalsCollected = 0
    end
    -- 重置每波可用1次的模块状态
    if Game.player then
        Game.player.teleporterUsedThisWave = false
        Game.player.emergencyShieldUsedThisWave = false
        
        -- 重置击杀叠层（每波从0开始）
        Game.player.killingInstinctStacks = 0
        Game.player.frenzyStacks = 0
        Game.player.burstModeKillCount = 0
        Game.player.burstModeReady = false
        Game.player.multiKillCount = 0
        Game.player.multiKillTimer = 0
        
        -- 重置临时效果计时器
        Game.player.combatStimulantTimer = 0
        Game.player.rageActivateTimer = 0
        Game.player.phantomTimer = 0
        Game.player.emergencyBoostTimer = 0
        Game.player.chargerTimer = 0
        
        -- 完美防御计时器保持（不按波重置）
    end
end

-- 获得经验值（击杀自动获取，用于舰桥升级）
function Game.AddXp(amount)
    local actualAmount = math.floor(amount * (Game.player.xpMultiplier or 1))
    Game.player.xp = Game.player.xp + actualAmount
    Game.player.totalXp = Game.player.totalXp + actualAmount
    return actualAmount
end

-- 消耗晶体
function Game.SpendCrystals(amount)
    if Game.player.crystals >= amount then
        Game.player.crystals = Game.player.crystals - amount
        -- 更新跨局统计
        GetStatsManager().OnCrystalsSpent(amount)
        if Game.battle then
            Game.battle.totalCrystalsSpent = (Game.battle.totalCrystalsSpent or 0) + amount
        end
        return true
    end
    return false
end

-- 击杀回复
function Game.OnKill()
    Game.battle.totalKills = Game.battle.totalKills + 1
    
    -- 更新跨局统计
    GetStatsManager().OnEnemyKilled(1)
    
    -- 击杀回血
    if Game.player.killHeal > 0 then
        Game.Heal(Game.player.killHeal)
    end
    
    -- 恶魔契约：击毁敌舰+1护盾
    if Game.player.hasDemonContract then
        local heal = Game.player.demonContractKillHeal or 1
        Game.Heal(heal)
    end
    
    -- 战舰特殊：帝国威能
    local special = Game.player.shipConfig.special
    if special and special.id == "imperial_might" then
        if math.random() < (special.chance or 0) then
            Game.Heal(special.healAmount or 5)
        end
    end
    
    -- ========== 击杀触发模块效果 ==========
    
    -- 杀戮本能：击毁叠加伤害（上限10层）
    if Game.player.hasKillingInstinct then
        Game.player.killingInstinctStacks = math.min(
            (Game.player.killingInstinctStacks or 0) + 1,
            Game.player.killingInstinctMaxStacks or 10
        )
    end
    
    -- 狂热模式：击毁叠加射速（上限15层）
    if Game.player.hasFrenzyMode then
        Game.player.frenzyStacks = math.min(
            (Game.player.frenzyStacks or 0) + 1,
            Game.player.frenzyMaxStacks or 15
        )
    end
    
    -- 战斗兴奋剂：击毁触发射速提升
    if Game.player.hasCombatStimulant then
        Game.player.combatStimulantTimer = Game.player.combatStimulantDuration or 3.0
    end
    
    -- 多杀奖励：1秒内连杀3个+5晶体
    if Game.player.hasMultiKillBonus then
        if Game.player.multiKillTimer and Game.player.multiKillTimer > 0 then
            -- 在窗口期内，计数+1
            Game.player.multiKillCount = (Game.player.multiKillCount or 0) + 1
            if Game.player.multiKillCount >= 3 then
                local bonus = Game.player.multiKillCrystalBonus or 5
                Game.AddCrystals(bonus)
                Game.player.multiKillCount = 0  -- 重置计数
            end
        else
            -- 新的连杀窗口
            Game.player.multiKillCount = 1
        end
        Game.player.multiKillTimer = 1.0  -- 1秒窗口
    end
    
    -- 财运亨通：击毁时5%几率+3晶体
    if Game.player.hasFortune then
        local chance = Game.player.fortuneCrystalChance or 0.05
        -- 运势加成：每点运势+0.25%几率
        local luck = Game.player.luck or 0
        chance = chance + luck * 0.0025
        if math.random() < chance then
            local amount = Game.player.fortuneCrystalAmount or 3
            Game.AddCrystals(amount)
        end
    end
    
    -- 爆发模式：击毁10敌舰后下次攻击+100%伤害
    if Game.player.hasBurstMode then
        Game.player.burstModeKillCount = (Game.player.burstModeKillCount or 0) + 1
        local requirement = Game.player.burstModeKillRequirement or 10
        if Game.player.burstModeKillCount >= requirement then
            Game.player.burstModeReady = true
            Game.player.burstModeKillCount = 0
        end
    end
end

-- ============================================================================
-- 武器效果聚合
-- ============================================================================

-- 重新计算所有装备武器的特殊效果
-- 在添加/移除武器后调用
function Game.RecalculateWeaponEffects()
    local Weapons = require("config.weapons")
    
    -- 重置武器相关属性（保留基础值和模块加成）
    local baseKillCrystalBonus = 0  -- 基础值（可从模块获得）
    local baseShieldOnKill = 0       -- 护盾冲击等武器效果
    
    -- 遍历所有装备武器，累加效果
    for _, weapon in ipairs(Game.player.weapons) do
        local weaponDef = Weapons.Get(weapon.id)
        if weaponDef then
            -- 粒子机炮：击毁+1晶体
            if weaponDef.crystalOnKill then
                baseKillCrystalBonus = baseKillCrystalBonus + weaponDef.crystalOnKill
            end
            
            -- 护盾冲击：击毁+护盾（上限由武器定义）
            if weaponDef.shieldOnKill then
                baseShieldOnKill = baseShieldOnKill + weaponDef.shieldOnKill
            end
        end
    end
    
    -- 应用计算结果
    Game.player.killCrystalBonus = baseKillCrystalBonus
    -- 注意：shieldOnKill 已有 kill_on_shield 效果处理，这里只累加值
    -- 如果需要也可以添加类似处理
    
    -- 重新计算武器标签套装效果
    Game.RecalculateTagSetBonuses()
end

-- 计算狂战士伤害加成
function Game.GetBerserkerBonus()
    if Game.player.hasBerserker then
        local healthRatio = Game.player.shield / Game.player.maxShield
        return 1 + (1 - healthRatio) * 0.5  -- 血量越低伤害越高，最高+50%
    end
    return 1.0
end

-- ============================================================================
-- 模块效果计算函数（供 GameLoop 使用）
-- ============================================================================

-- 获取有效伤害乘数（包含所有模块效果）
function Game.GetEffectiveDamageMultiplier()
    local mult = Game.player.damageMultiplier or 1.0
    
    -- 杀戮本能：每层+3%伤害
    if Game.player.hasKillingInstinct then
        local stacks = Game.player.killingInstinctStacks or 0
        local perStack = Game.player.killingInstinctDamagePerStack or 0.03
        mult = mult + (stacks * perStack)
    end
    
    -- 愤怒芯片：每损失1%护盾+1%伤害
    if Game.player.hasRageChip then
        local healthRatio = Game.player.shield / Game.player.maxShield
        local missingPercent = (1 - healthRatio) * 100
        local perPercent = Game.player.rageDamagePerMissingShieldPercent or 0.01
        mult = mult + (missingPercent * perPercent)
    end
    
    -- 狂战士之血：护盾越低伤害越高（最高+50%）
    if Game.player.hasBerserkerBlood then
        local healthRatio = Game.player.shield / Game.player.maxShield
        local maxBonus = Game.player.berserkerMaxDamageBonus or 0.50
        mult = mult + ((1 - healthRatio) * maxBonus)
    end
    
    -- 愤怒激活：受伤后3秒内+10%伤害
    if Game.player.hasRageActivate and Game.player.rageActivateTimer and Game.player.rageActivateTimer > 0 then
        mult = mult + (Game.player.rageActivateDamageBonus or 0.10)
    end
    
    -- 模块化装甲：每2装甲+1%伤害
    if Game.player.hasModularArmor then
        local armor = Game.player.armor or 0
        local perArmor = Game.player.modularArmorDamagePerArmor or 0.005
        mult = mult + (armor * perArmor)
    end
    
    -- 速度狂魔：每5%速度+2%伤害
    if Game.player.hasSpeedDemon then
        -- 计算相对于基础速度的速度百分比
        local baseSpeed = 5.0  -- 假设基础速度为5
        local currentSpeed = Game.player.moveSpeed or baseSpeed
        local speedPercent = (currentSpeed / baseSpeed - 1) * 100  -- 超出基础的百分比
        local perSpeed = Game.player.speedDemonDamagePerSpeed or 0.004
        if speedPercent > 0 then
            mult = mult + (speedPercent * perSpeed)
        end
    end
    
    -- 鹰眼系统：每10火力范围+1%伤害
    if Game.player.hasEagleEye then
        local range = Game.player.attackRange or 0
        local perRange = Game.player.eagleEyeDamagePerRange or 0.001
        mult = mult + (range * perRange)
    end
    
    -- 满血奖励：护盾满时+25%伤害
    if Game.player.fullShieldDamageBonus and Game.player.fullShieldDamageBonus > 0 then
        if Game.player.shield >= Game.player.maxShield then
            mult = mult + Game.player.fullShieldDamageBonus
        end
    end
    
    -- 低血爆发：护盾<30%时+50%伤害
    if Game.player.lowShieldDamageBonus and Game.player.lowShieldDamageBonus > 0 then
        local threshold = Game.player.lowShieldThreshold or 0.30
        local healthRatio = Game.player.shield / Game.player.maxShield
        if healthRatio < threshold then
            mult = mult + Game.player.lowShieldDamageBonus
        end
    end
    
    -- 孤注一掷：单武器时伤害+30%
    if Game.player.hasAllIn then
        local weaponCount = #(Game.player.weapons or {})
        if weaponCount == 1 then
            mult = mult + (Game.player.allInDamageBonus or 0.30)
        end
    end
    
    -- 爆发模式：下次攻击+100%伤害（一次性）
    if Game.player.burstModeReady then
        mult = mult + (Game.player.burstModeDamageBonus or 1.00)
        -- 注意：消耗标记需要在实际造成伤害后清除
    end
    
    return mult
end

-- 消耗爆发模式加成（在造成伤害后调用）
function Game.ConsumeBurstMode()
    if Game.player.burstModeReady then
        Game.player.burstModeReady = false
        return true
    end
    return false
end

-- 获取有效射速乘数（包含所有模块效果）
function Game.GetEffectiveFireRateMultiplier()
    local mult = Game.player.fireRateMultiplier or 1.0
    
    -- 狂热模式：每层+2%射速
    if Game.player.hasFrenzyMode then
        local stacks = Game.player.frenzyStacks or 0
        local perStack = Game.player.frenzyFireRatePerStack or 0.02
        mult = mult + (stacks * perStack)
    end
    
    -- 战斗兴奋剂：击杀后3秒内+15%射速
    if Game.player.hasCombatStimulant and Game.player.combatStimulantTimer and Game.player.combatStimulantTimer > 0 then
        mult = mult + (Game.player.combatStimulantFireRateBonus or 0.15)
    end
    
    -- 狂战士模式（战舰特性）：每损失1%护盾+0.5%射速
    if Game.player.hasBerserkerMode then
        local healthRatio = Game.player.shield / Game.player.maxShield
        local missingPercent = (1 - healthRatio) * 100
        local perPercent = Game.player.berserkerFireRatePerLoss or 0.005
        mult = mult + (missingPercent * perPercent)
    end
    
    return mult
end

-- 获取有效移动速度（包含紧急加速等临时效果）
function Game.GetEffectiveMoveSpeed()
    local speed = Game.player.moveSpeed or 5.0
    
    -- 紧急加速：受伤后2秒内+30%速度
    if Game.player.hasEmergencyBoost and Game.player.emergencyBoostTimer and Game.player.emergencyBoostTimer > 0 then
        speed = speed * (1 + (Game.player.emergencyBoostAmount or 0.30))
    end
    
    return speed
end

-- 获取处决者暴击加成（针对低血量敌人）
-- @param enemyHealthRatio 敌人当前血量比例 (0-1)
function Game.GetExecutionerCritBonus(enemyHealthRatio)
    if Game.player.hasExecutioner then
        local threshold = Game.player.executionerThreshold or 0.20
        if enemyHealthRatio < threshold then
            return Game.player.executionerCritBonus or 0.30
        end
    end
    return 0
end

-- ============================================================================
-- 舰桥升级
-- ============================================================================

-- 获取升级到指定等级所需的单级经验值
-- 公式：(等级 + 3)²（与Brotato Wiki完全一致）
-- @param level 等级（1-based）
-- @return 该等级所需经验值
function Game.GetXpForLevel(level)
    return (level + 3) * (level + 3)
end

-- 获取升级到指定等级所需的累计经验值
-- @param targetLevel 目标等级（1-based）
-- @return 累计经验值
function Game.GetCumulativeXpForLevel(targetLevel)
    local cumulative = 0
    for level = 1, targetLevel do
        cumulative = cumulative + Game.GetXpForLevel(level)
    end
    return cumulative
end

-- 检查并累计待升级次数（战斗中调用，不立即触发）
-- 基于累计经验值判断升级
function Game.CheckAndAccumulateUpgrades()
    local nextLevel = Game.player.bridgeLevel + Game.player.pendingUpgrades + 1
    local nextUpgradeXp = Game.GetCumulativeXpForLevel(nextLevel)
    
    while Game.player.totalXp >= nextUpgradeXp do
        Game.player.pendingUpgrades = Game.player.pendingUpgrades + 1
        nextLevel = nextLevel + 1
        nextUpgradeXp = Game.GetCumulativeXpForLevel(nextLevel)
    end
    
    -- 更新下一级所需经验（用于UI显示）
    Game.player.nextUpgradeXp = nextUpgradeXp
end

-- 检查是否有待处理的升级
function Game.HasPendingUpgrades()
    return Game.player.pendingUpgrades > 0
end

-- 开始处理一次升级（波次结束后调用）
function Game.StartBridgeUpgrade()
    if Game.player.pendingUpgrades > 0 then
        Game.SetState(Game.States.BRIDGE_UPGRADE)
        return true
    end
    return false
end

-- 完成一次升级选择
function Game.CompleteBridgeUpgrade()
    Game.player.bridgeLevel = Game.player.bridgeLevel + 1
    Game.player.pendingUpgrades = Game.player.pendingUpgrades - 1
    
    -- 检查是否还有更多升级
    if Game.player.pendingUpgrades > 0 then
        -- 保持在升级状态，等待下一次选择
        return true  -- 还有更多升级
    else
        -- 所有升级完成，进入商店
        return false  -- 没有更多升级
    end
end

-- 兼容旧接口（已废弃）
function Game.CheckBridgeUpgrade()
    return false  -- 不再战斗中触发
end

function Game.TriggerBridgeUpgrade()
    -- 已废弃，使用 StartBridgeUpgrade
end

-- ============================================================================
-- 更新
-- ============================================================================

function Game.Update(dt)
    -- 更新无敌时间
    if Game.player.invincibleTime > 0 then
        Game.player.invincibleTime = Game.player.invincibleTime - dt
    end
    
    -- ========== 模块计时器更新 ==========
    
    -- 战斗兴奋剂计时器（击杀触发的临时射速提升）
    if Game.player.combatStimulantTimer and Game.player.combatStimulantTimer > 0 then
        Game.player.combatStimulantTimer = Game.player.combatStimulantTimer - dt
    end
    
    -- 多杀奖励计时器（1.5秒窗口）
    if Game.player.multiKillTimer and Game.player.multiKillTimer > 0 then
        Game.player.multiKillTimer = Game.player.multiKillTimer - dt
        if Game.player.multiKillTimer <= 0 then
            Game.player.multiKillCount = 0  -- 重置连杀计数
        end
    end
    
    -- 愤怒激活计时器（受伤触发的临时伤害提升）
    if Game.player.rageActivateTimer and Game.player.rageActivateTimer > 0 then
        Game.player.rageActivateTimer = Game.player.rageActivateTimer - dt
    end
    
    -- 幻影模块计时器（受伤触发的临时闪避提升）
    if Game.player.phantomTimer and Game.player.phantomTimer > 0 then
        Game.player.phantomTimer = Game.player.phantomTimer - dt
    end
    
    -- 紧急加速计时器（受伤触发的临时速度提升）
    if Game.player.emergencyBoostTimer and Game.player.emergencyBoostTimer > 0 then
        Game.player.emergencyBoostTimer = Game.player.emergencyBoostTimer - dt
    end
    
    -- 完美防御计时器（周期性无敌）
    if Game.player.hasPerfectDefense then
        Game.player.perfectDefenseTimer = (Game.player.perfectDefenseTimer or 0) + dt
        local interval = Game.player.perfectDefenseInterval or 10.0
        local duration = Game.player.perfectDefenseDuration or 1.0
        
        if Game.player.perfectDefenseTimer >= interval then
            Game.player.perfectDefenseTimer = Game.player.perfectDefenseTimer - interval
            Game.player.perfectDefenseActive = true
            Game.player.perfectDefenseActiveTimer = duration
        end
        
        if Game.player.perfectDefenseActive then
            Game.player.perfectDefenseActiveTimer = Game.player.perfectDefenseActiveTimer - dt
            if Game.player.perfectDefenseActiveTimer <= 0 then
                Game.player.perfectDefenseActive = false
            end
        end
    end
    
    -- 充能器计时器（5秒未受伤后护盾再生×3）
    if Game.player.hasCharger then
        Game.player.chargerTimer = (Game.player.chargerTimer or 0) + dt
    end
    
    -- 恶魔契约持续扣血（每秒损失护盾）
    if Game.player.hasDemonContract then
        local drain = Game.player.demonContractDrain or 1
        Game.player.shield = math.max(1, Game.player.shield - drain * dt)  -- 不会直接扣死
    end
    
    -- 护盾回复（持续回复，递减效应公式）
    -- 公式: HP/s = 0.20 + (shieldRegen - 1) × 0.089
    if Game.player.shieldRegen > 0 and Game.player.shield < Game.player.maxShield then
        local regenPerSecond = 0.20 + (Game.player.shieldRegen - 1) * 0.089
        
        -- 充能器加成：5秒未受伤后护盾再生×3
        if Game.player.hasCharger then
            local delay = Game.player.chargerDelay or 5.0
            if (Game.player.chargerTimer or 0) >= delay then
                regenPerSecond = regenPerSecond * (Game.player.chargerRegenMultiplier or 3)
            end
        end
        
        Game.player.shield = math.min(
            Game.player.shield + regenPerSecond * dt,
            Game.player.maxShield
        )
    end
    
    -- 更新实时DPS统计
    Game.UpdateRealtimeDPS()
end

return Game
