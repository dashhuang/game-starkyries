-- ============================================================================
-- 星河战姬 Starkyries - 存档管理器
-- ============================================================================
-- 策略：本地（内存）优先 + 关键时刻云同步
-- - 所有存档操作先写入内存（极快）
-- - 只在关键时刻同步到云端（波次结束、退出商店）
-- ============================================================================

local SaveManager = {}

-- ⚠️ 云存档开关（设为 false 可暂时禁用云存档）
SaveManager.CLOUD_ENABLED = true

-- 本地存储模块（云禁用时使用）
local LocalStorage = require "core.LocalStorage"

-- 存档版本号
SaveManager.VERSION = 1

-- 云变量 key
SaveManager.SAVE_KEY = "game_save_data"
SaveManager.SAVE_FLAG_KEY = "has_save"

-- 波次状态枚举
SaveManager.WaveState = {
    BEFORE_WAVE = "before_wave",
    IN_WAVE = "in_wave",
    AFTER_WAVE = "after_wave",
}

-- ============================================================================
-- 内部状态
-- ============================================================================
local initialized = false
local cloudAvailable = false     -- 云存储是否可用
local hasSaveData = false        -- 是否有存档
local localSaveData = nil        -- 本地存档数据（内存）
local cloudSaveData = nil        -- 云端存档数据（缓存）
local cloudSyncInProgress = false
local localDirty = false         -- 本地数据是否有未同步的修改
local beforeWaveSaveData = nil   -- 波次开始前的备份

-- ============================================================================
-- 序列化/反序列化
-- ============================================================================

local function SerializeValue(value, indent)
    indent = indent or 0
    local t = type(value)
    
    if t == "nil" then
        return "nil"
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "number" then
        return tostring(value)
    elseif t == "string" then
        local escaped = value:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("\r", "\\r")
        return '"' .. escaped .. '"'
    elseif t == "table" then
        local parts = {}
        local spaces = string.rep("  ", indent)
        local innerSpaces = string.rep("  ", indent + 1)
        
        local isArray = true
        local maxIndex = 0
        for k, _ in pairs(value) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                isArray = false
                break
            end
            maxIndex = math.max(maxIndex, k)
        end
        if isArray and maxIndex ~= #value then
            isArray = false
        end
        
        if isArray then
            for i, v in ipairs(value) do
                table.insert(parts, innerSpaces .. SerializeValue(v, indent + 1))
            end
            if #parts == 0 then return "{}" end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. spaces .. "}"
        else
            for k, v in pairs(value) do
                local keyStr
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    keyStr = k
                else
                    keyStr = "[" .. SerializeValue(k, 0) .. "]"
                end
                table.insert(parts, innerSpaces .. keyStr .. " = " .. SerializeValue(v, indent + 1))
            end
            if #parts == 0 then return "{}" end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. spaces .. "}"
        end
    else
        return "nil"
    end
end

local function Serialize(data)
    return "return " .. SerializeValue(data, 0)
end

local function Deserialize(str)
    if not str or str == "" then return nil, "Empty string" end
    local func, err = load(str, "save_data", "t", {})
    if not func then return nil, "Parse error: " .. tostring(err) end
    local success, result = pcall(func)
    if not success then return nil, "Execution error: " .. tostring(result) end
    return result
end

-- ============================================================================
-- 初始化
-- ============================================================================

function SaveManager.Init(callback)
    if initialized then
        if callback then callback(hasSaveData) end
        return
    end
    
    -- 初始化本地存储
    LocalStorage.Init()
    
    -- 检查云存储是否可用（受开关控制）
    cloudAvailable = SaveManager.CLOUD_ENABLED and (clientScore ~= nil)
    
    if not cloudAvailable then
        print("[SaveManager] Cloud disabled, trying local storage...")
        -- 尝试从本地文件加载
        local localData = LocalStorage.LoadGame()
        if localData then
            localSaveData = localData
            hasSaveData = true
            print("[SaveManager] Loaded from local storage (wave " .. (localData.battle and localData.battle.currentWave or "?") .. ")")
        else
            print("[SaveManager] No local save found")
            hasSaveData = false
        end
        initialized = true
        if callback then callback(hasSaveData) end
        return
    end
    
    -- 从云端加载存档
    print("[SaveManager] Loading from cloud...")
    clientScore:Get(SaveManager.SAVE_KEY, {
        ok = function(scores, iscores, sscores)
            local content = scores[SaveManager.SAVE_KEY]
            if content and content ~= "" then
                local data, err = Deserialize(content)
                if data then
                    cloudSaveData = data
                    localSaveData = data  -- 复制到本地
                    hasSaveData = true
                    print("[SaveManager] Loaded from cloud (wave " .. data.battle.currentWave .. ")")
                else
                    print("[SaveManager] Cloud data corrupted: " .. tostring(err))
                    hasSaveData = false
                end
            else
                print("[SaveManager] No cloud save found")
                hasSaveData = false
            end
            initialized = true
            localDirty = false
            if callback then callback(hasSaveData) end
        end,
        error = function(code, reason)
            print("[SaveManager] Cloud load error: " .. tostring(reason))
            initialized = true
            hasSaveData = false
            if callback then callback(false) end
        end,
        timeout = function()
            print("[SaveManager] Cloud load timeout")
            initialized = true
            hasSaveData = false
            if callback then callback(false) end
        end
    })
end

-- ============================================================================
-- 构建存档数据
-- ============================================================================

function SaveManager.BuildSaveData(Game, waveState)
    local p = Game.player
    local b = Game.battle
    
    local saveData = {
        version = SaveManager.VERSION,
        timestamp = os.time(),
        waveState = waveState,
        
        player = {
            shipId = p.shipId,
            shipName = p.shipName,
            captain = p.captain,
            shield = p.shield,
            maxShield = p.maxShield,
            shieldRegen = p.shieldRegen,
            armor = p.armor,
            moveSpeed = p.moveSpeed,
            crystals = p.crystals,
            totalCrystals = p.totalCrystals,
            xp = p.xp,
            totalXp = p.totalXp,
            damageMultiplier = p.damageMultiplier,
            fireRateMultiplier = p.fireRateMultiplier,
            crystalMultiplier = p.crystalMultiplier,
            energyAbsorb = p.energyAbsorb,
            dodgeChance = p.dodgeChance,
            critChance = p.critChance,
            critDamage = p.critDamage,
            rangeMultiplier = p.rangeMultiplier,
            pickupRangeMultiplier = p.pickupRangeMultiplier,
            damageTakenMultiplier = p.damageTakenMultiplier,
            maxWeaponSlots = p.maxWeaponSlots,
            killHeal = p.killHeal,
            xpMultiplier = p.xpMultiplier,
            shopDiscount = p.shopDiscount,
            freeRefreshes = p.freeRefreshes,
            bossDamage = p.bossDamage,
            -- 穿透属性
            piercing = p.piercing,
            piercingDamage = p.piercingDamage,
            hasBerserker = p.hasBerserker,
            hasEmergencyBoost = p.hasEmergencyBoost,
            hasExpShare = p.hasExpShare,
            
            -- 🔴 补充遗漏的升级属性
            -- 专精伤害加成（三大类：近程/弹道/能量）
            meleeDamageBonus = p.meleeDamageBonus,
            ballisticDamageBonus = p.ballisticDamageBonus,
            energyDamageBonus = p.energyDamageBonus,
            closeRangeDamage = p.closeRangeDamage,
            missileDamage = p.missileDamage,
            laserDamage = p.laserDamage,
            summonDamage = p.summonDamage,
            
            -- 战术属性
            deathChainChance = p.deathChainChance,
            burnChance = p.burnChance,
            fullShieldDamageBonus = p.fullShieldDamageBonus,
            lowShieldDamageBonus = p.lowShieldDamageBonus,
            attackRange = p.attackRange,
            luck = p.luck,
            luckBonus = p.luckBonus,
            
            -- 特殊状态
            hasBerserkerBlood = p.hasBerserkerBlood,
            hasDemonPact = p.hasDemonPact,
            
            bridgeLevel = p.bridgeLevel,
            nextUpgradeXp = p.nextUpgradeXp,
            pendingUpgrades = p.pendingUpgrades,
            weapons = {},
            modules = {},
        },
        
        battle = {
            currentWave = b.currentWave,
            totalKills = b.totalKills,
        },
    }
    
    for i, weapon in ipairs(p.weapons) do
        table.insert(saveData.player.weapons, {
            weaponId = weapon.id,  -- 🔴 修复：武器字段是 id 不是 weaponId
            tier = weapon.tier,
            slotIndex = weapon.slotIndex,
            isDrone = weapon.isDrone,
        })
    end
    
    for moduleId, count in pairs(p.modules) do
        saveData.player.modules[moduleId] = count
    end
    
    return saveData
end

-- ============================================================================
-- 本地存档操作（极快）
-- ============================================================================

-- 保存到本地（内存 + 本地文件）
function SaveManager.SaveLocal(Game, waveState)
    localSaveData = SaveManager.BuildSaveData(Game, waveState)
    hasSaveData = true
    localDirty = true
    print("[SaveManager] Saved to local (wave " .. localSaveData.battle.currentWave .. ", state: " .. waveState .. ")")
    
    -- 如果云禁用，同时保存到本地文件
    if not cloudAvailable then
        LocalStorage.SaveGame(localSaveData)
    end
end

-- 保存波次开始前的状态（用于回退）
function SaveManager.SaveBeforeWaveState(Game)
    beforeWaveSaveData = SaveManager.BuildSaveData(Game, SaveManager.WaveState.BEFORE_WAVE)
    print("[SaveManager] Saved before-wave state for wave " .. Game.battle.currentWave)
end

-- ============================================================================
-- 恢复玩家数据（与 BuildSaveData 对应，属性列表只维护一处）
-- ============================================================================

function SaveManager.RestorePlayerData(player, savePlayer)
    local p = player
    local sp = savePlayer
    
    -- 护盾和属性
    p.shield = sp.shield
    p.maxShield = sp.maxShield
    p.shieldRegen = sp.shieldRegen
    p.armor = sp.armor
    p.moveSpeed = sp.moveSpeed
    
    -- 资源
    p.crystals = sp.crystals
    p.totalCrystals = sp.totalCrystals
    p.xp = sp.xp
    p.totalXp = sp.totalXp
    
    -- 属性加成
    p.damageMultiplier = sp.damageMultiplier
    p.fireRateMultiplier = sp.fireRateMultiplier
    p.crystalMultiplier = sp.crystalMultiplier
    p.energyAbsorb = sp.energyAbsorb
    p.dodgeChance = sp.dodgeChance
    p.critChance = sp.critChance
    p.critDamage = sp.critDamage
    
    -- 额外属性
    p.rangeMultiplier = sp.rangeMultiplier
    p.pickupRangeMultiplier = sp.pickupRangeMultiplier
    p.damageTakenMultiplier = sp.damageTakenMultiplier
    p.maxWeaponSlots = sp.maxWeaponSlots
    p.killHeal = sp.killHeal
    
    -- 模块效果属性
    p.xpMultiplier = sp.xpMultiplier
    p.shopDiscount = sp.shopDiscount
    p.freeRefreshes = sp.freeRefreshes
    p.bossDamage = sp.bossDamage
    -- 穿透属性
    p.piercing = sp.piercing
    p.piercingDamage = sp.piercingDamage
    
    -- 特殊状态
    p.hasBerserker = sp.hasBerserker
    p.hasEmergencyBoost = sp.hasEmergencyBoost
    p.hasExpShare = sp.hasExpShare
    
    -- 升级获得的属性（专精伤害，三大类：近程/弹道/能量）
    p.meleeDamageBonus = sp.meleeDamageBonus
    p.ballisticDamageBonus = sp.ballisticDamageBonus
    p.energyDamageBonus = sp.energyDamageBonus
    p.closeRangeDamage = sp.closeRangeDamage
    p.missileDamage = sp.missileDamage
    p.laserDamage = sp.laserDamage
    p.summonDamage = sp.summonDamage
    
    -- 升级获得的属性（战术）
    p.deathChainChance = sp.deathChainChance
    p.burnChance = sp.burnChance
    p.fullShieldDamageBonus = sp.fullShieldDamageBonus
    p.lowShieldDamageBonus = sp.lowShieldDamageBonus
    p.attackRange = sp.attackRange
    p.luck = sp.luck
    p.luckBonus = sp.luckBonus
    
    -- 升级获得的属性（特殊状态）
    p.hasBerserkerBlood = sp.hasBerserkerBlood
    p.hasDemonPact = sp.hasDemonPact
    
    -- 舰桥升级
    p.bridgeLevel = sp.bridgeLevel
    p.nextUpgradeXp = sp.nextUpgradeXp
    p.pendingUpgrades = sp.pendingUpgrades
    
    -- 模块数据
    p.modules = {}
    for moduleId, count in pairs(sp.modules or {}) do
        p.modules[moduleId] = count
    end
    
    print("[SaveManager] Restored player data (level " .. p.bridgeLevel .. ")")
end

-- 获取本地存档
function SaveManager.GetLocalSave()
    return localSaveData
end

-- 检查是否有存档
function SaveManager.HasSave()
    return hasSaveData
end

-- ============================================================================
-- 云同步操作（较慢，只在关键时刻调用）
-- ============================================================================

-- 同步本地数据到云端
function SaveManager.SyncToCloud(callback)
    if not cloudAvailable then
        print("[SaveManager] Cloud sync skipped: not available")
        if callback then callback(false) end
        return
    end
    
    if not localSaveData then
        print("[SaveManager] Cloud sync skipped: no local data")
        if callback then callback(false) end
        return
    end
    
    if not localDirty then
        print("[SaveManager] Cloud sync skipped: no changes")
        if callback then callback(true) end
        return
    end
    
    if cloudSyncInProgress then
        print("[SaveManager] Cloud sync skipped: already in progress")
        if callback then callback(false) end
        return
    end
    
    cloudSyncInProgress = true
    local content = Serialize(localSaveData)
    
    clientScore:BatchSet()
        :Set(SaveManager.SAVE_KEY, content)
        :SetInt(SaveManager.SAVE_FLAG_KEY, 1)
        :Save("云同步", {
            ok = function()
                cloudSyncInProgress = false
                cloudSaveData = localSaveData
                localDirty = false
                print("[SaveManager] Synced to cloud (wave " .. localSaveData.battle.currentWave .. ")")
                if callback then callback(true) end
            end,
            error = function(code, reason)
                cloudSyncInProgress = false
                print("[SaveManager] Cloud sync error: " .. tostring(reason))
                if callback then callback(false) end
            end,
            timeout = function()
                cloudSyncInProgress = false
                print("[SaveManager] Cloud sync timeout")
                if callback then callback(false) end
            end
        })
end

-- 删除存档（本地 + 云端）
function SaveManager.Delete(callback)
    localSaveData = nil
    cloudSaveData = nil
    beforeWaveSaveData = nil
    hasSaveData = false
    localDirty = false
    
    -- 删除本地文件
    LocalStorage.Delete(LocalStorage.SAVE_FILE)
    
    if not cloudAvailable then
        print("[SaveManager] Deleted local save")
        if callback then callback(true) end
        return
    end
    
    clientScore:BatchSet()
        :Delete(SaveManager.SAVE_KEY)
        :SetInt(SaveManager.SAVE_FLAG_KEY, 0)
        :Save("删除存档", {
            ok = function()
                print("[SaveManager] Deleted cloud save")
                if callback then callback(true) end
            end,
            error = function(code, reason)
                print("[SaveManager] Cloud delete error: " .. tostring(reason))
                if callback then callback(false) end
            end
        })
end

-- ============================================================================
-- 存档恢复
-- ============================================================================

function SaveManager.GetRestoreData(callback)
    -- 优先使用本地数据
    local saveData = localSaveData
    
    if not saveData then
        print("[SaveManager] No save data available")
        if callback then callback(nil) end
        return
    end
    
    -- 如果是波次进行中离开的，需要回退
    if saveData.waveState == SaveManager.WaveState.IN_WAVE then
        saveData.needRollback = true
        print("[SaveManager] Save is from mid-wave, will rollback to wave start")
    end
    
    if callback then callback(saveData) end
end

-- ============================================================================
-- 自动存档触发点
-- ============================================================================

-- 波次开始：保存到本地 + 立即云同步
function SaveManager.OnWaveStart(Game)
    SaveManager.SaveBeforeWaveState(Game)
    SaveManager.SaveLocal(Game, SaveManager.WaveState.IN_WAVE)
    SaveManager.SyncToCloud()  -- 关键时刻，立即同步
end

-- 波次结束：保存到本地 + 立即云同步
function SaveManager.OnWaveComplete(Game)
    SaveManager.SaveLocal(Game, SaveManager.WaveState.AFTER_WAVE)
    SaveManager.SyncToCloud()  -- 关键时刻，立即同步
end

-- 商店操作：只保存到本地（不云同步）
function SaveManager.OnShopAction(Game)
    SaveManager.SaveLocal(Game, SaveManager.WaveState.AFTER_WAVE)
    -- 不云同步，等退出商店时再同步
end

-- 退出商店进入下一波前：云同步
function SaveManager.OnExitShop(Game)
    if localDirty then
        SaveManager.SyncToCloud()
    end
end

-- 游戏结束：删除存档
function SaveManager.OnGameEnd()
    SaveManager.Delete()
end

-- 强制云同步（用于游戏暂停或切后台）
function SaveManager.Flush(callback)
    if localDirty then
        SaveManager.SyncToCloud(callback)
    elseif callback then
        callback(true)
    end
end

-- 检查是否有未同步的修改
function SaveManager.IsDirty()
    return localDirty
end

return SaveManager
