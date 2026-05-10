-- ============================================================================
-- 星河战姬 Starkyries - 统计数据管理器
-- ============================================================================
-- 管理跨局累计统计数据（与单局存档分开）
-- 这些数据永久保存，不会因游戏结束而清除
-- ============================================================================

local StatsManager = {}

-- ⚠️ 云存档开关（与 SaveManager 共享设置）
StatsManager.CLOUD_ENABLED = true

-- 本地存储模块
local LocalStorage = require "core.LocalStorage"

-- 存档版本号
StatsManager.VERSION = 1

-- 云变量 key 前缀（每个统计项单独存储为整数）
StatsManager.KEY_PREFIX = "stats_"
StatsManager.KEYS = {
    "totalGamesPlayed",
    "totalEnemiesKilled", 
    "totalCrystalsEarned",
    "totalCrystalsSpent",
    "totalHyperspaceJumps",
    "totalPlayTime",
    "highestWave",
    "totalVictories",
}

-- ============================================================================
-- 内部状态
-- ============================================================================
local initialized = false
local cloudAvailable = false
local statsData = nil           -- 统计数据
local cloudSyncInProgress = false
local localDirty = false        -- 是否有未同步的修改

-- 本地存储文件名
local STATS_FILE = "starkyries_stats.json"

-- ============================================================================
-- 默认统计数据
-- ============================================================================
local function GetDefaultStats()
    return {
        version = StatsManager.VERSION,
        
        -- 累计游戏次数
        totalGamesPlayed = 0,
        
        -- 击毁敌机数量（总计）
        totalEnemiesKilled = 0,
        
        -- 晶体统计
        totalCrystalsEarned = 0,    -- 获得晶体
        totalCrystalsSpent = 0,     -- 消耗晶体
        
        -- 空间跳跃次数（波次完成次数）
        totalHyperspaceJumps = 0,
        
        -- 累计游戏时长（秒）
        totalPlayTime = 0,
        
        -- 最高波次记录
        highestWave = 0,
        
        -- 胜利次数
        totalVictories = 0,
        
        -- 最后更新时间
        lastUpdated = os.time(),
    }
end

-- ============================================================================
-- 序列化/反序列化（复用 SaveManager 的格式）
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
    local func, err = load(str, "stats_data", "t", {})
    if not func then return nil, "Parse error: " .. tostring(err) end
    local success, result = pcall(func)
    if not success then return nil, "Execution error: " .. tostring(result) end
    return result
end

-- ============================================================================
-- 初始化
-- ============================================================================

function StatsManager.Init(callback)
    if initialized then
        if callback then callback(statsData) end
        return
    end
    
    -- 初始化本地存储
    LocalStorage.Init()
    
    -- 检查云存储是否可用
    cloudAvailable = StatsManager.CLOUD_ENABLED and (clientScore ~= nil)
    
    if not cloudAvailable then
        print("[StatsManager] Cloud disabled, trying local storage...")
        -- 尝试从本地文件加载
        local localData = LocalStorage.Load(STATS_FILE, nil)
        if localData then
            statsData = localData
            print("[StatsManager] Loaded from local storage")
        else
            statsData = GetDefaultStats()
            print("[StatsManager] No stats found, using defaults")
        end
        initialized = true
        if callback then callback(statsData) end
        return
    end
    
    -- 从云端加载统计（使用 BatchGet 读取多个整数）
    print("[StatsManager] Loading from cloud...")
    local batchGet = clientScore:BatchGet()
    for _, key in ipairs(StatsManager.KEYS) do
        batchGet:Key(StatsManager.KEY_PREFIX .. key)
    end
    batchGet:Fetch({
        ok = function(scores, iscores, sscores)
            statsData = GetDefaultStats()
            local hasData = false
            for _, key in ipairs(StatsManager.KEYS) do
                local cloudKey = StatsManager.KEY_PREFIX .. key
                local value = iscores[cloudKey]
                if value and value > 0 then
                    statsData[key] = value
                    hasData = true
                end
            end
            if hasData then
                print("[StatsManager] Loaded from cloud (games: " .. (statsData.totalGamesPlayed or 0) .. ")")
            else
                print("[StatsManager] No cloud stats found, using defaults")
            end
            initialized = true
            localDirty = false
            if callback then callback(statsData) end
        end,
        error = function(code, reason)
            print("[StatsManager] Cloud load error: " .. tostring(reason))
            -- 尝试从本地加载作为备份
            local localData = LocalStorage.Load(STATS_FILE, nil)
            if localData then
                statsData = localData
                print("[StatsManager] Fallback to local storage")
            else
                statsData = GetDefaultStats()
            end
            initialized = true
            if callback then callback(statsData) end
        end,
        timeout = function()
            print("[StatsManager] Cloud load timeout")
            statsData = GetDefaultStats()
            initialized = true
            if callback then callback(statsData) end
        end
    })
end

-- ============================================================================
-- 获取统计数据
-- ============================================================================

function StatsManager.GetStats()
    return statsData or GetDefaultStats()
end

function StatsManager.IsInitialized()
    return initialized
end

-- ============================================================================
-- 统计更新函数
-- ============================================================================

-- 开始新游戏
function StatsManager.OnGameStart()
    if not statsData then return end
    statsData.totalGamesPlayed = statsData.totalGamesPlayed + 1
    statsData.lastUpdated = os.time()
    localDirty = true
    print("[StatsManager] Game started (total: " .. statsData.totalGamesPlayed .. ")")
end

-- 击毁敌机
function StatsManager.OnEnemyKilled(count)
    if not statsData then return end
    count = count or 1
    statsData.totalEnemiesKilled = statsData.totalEnemiesKilled + count
    localDirty = true
end

-- 获得晶体
function StatsManager.OnCrystalsEarned(amount)
    if not statsData then return end
    amount = amount or 0
    if amount > 0 then
        statsData.totalCrystalsEarned = statsData.totalCrystalsEarned + amount
        localDirty = true
    end
end

-- 消耗晶体
function StatsManager.OnCrystalsSpent(amount)
    if not statsData then return end
    amount = amount or 0
    if amount > 0 then
        statsData.totalCrystalsSpent = statsData.totalCrystalsSpent + amount
        localDirty = true
    end
end

-- 空间跳跃（波次完成）
function StatsManager.OnHyperspaceJump()
    if not statsData then return end
    statsData.totalHyperspaceJumps = statsData.totalHyperspaceJumps + 1
    localDirty = true
    print("[StatsManager] Hyperspace jump (total: " .. statsData.totalHyperspaceJumps .. ")")
end

-- 更新游戏时长
function StatsManager.AddPlayTime(seconds)
    if not statsData then return end
    statsData.totalPlayTime = statsData.totalPlayTime + seconds
    localDirty = true
end

-- 更新最高波次
function StatsManager.UpdateHighestWave(wave)
    if not statsData then return end
    if wave > statsData.highestWave then
        statsData.highestWave = wave
        localDirty = true
        print("[StatsManager] New highest wave: " .. wave)
    end
end

-- 游戏胜利
function StatsManager.OnVictory()
    if not statsData then return end
    statsData.totalVictories = statsData.totalVictories + 1
    statsData.lastUpdated = os.time()
    localDirty = true
    print("[StatsManager] Victory! (total: " .. statsData.totalVictories .. ")")
end

-- 游戏结束（保存当局游戏时长）
function StatsManager.OnGameEnd(sessionPlayTime, finalWave)
    if not statsData then return end
    
    -- 添加本局游戏时长
    if sessionPlayTime and sessionPlayTime > 0 then
        statsData.totalPlayTime = statsData.totalPlayTime + sessionPlayTime
    end
    
    -- 更新最高波次
    if finalWave then
        StatsManager.UpdateHighestWave(finalWave)
    end
    
    statsData.lastUpdated = os.time()
    localDirty = true
    
    -- 立即同步到云端
    StatsManager.SyncToCloud()
end

-- ============================================================================
-- 云同步操作
-- ============================================================================

function StatsManager.SyncToCloud(callback)
    if not statsData then
        if callback then callback(false) end
        return
    end
    
    -- 先保存到本地
    LocalStorage.Save(STATS_FILE, statsData)
    
    if not cloudAvailable then
        print("[StatsManager] Cloud sync skipped: not available")
        localDirty = false
        if callback then callback(true) end
        return
    end
    
    if not localDirty then
        print("[StatsManager] Cloud sync skipped: no changes")
        if callback then callback(true) end
        return
    end
    
    if cloudSyncInProgress then
        print("[StatsManager] Cloud sync skipped: already in progress")
        if callback then callback(false) end
        return
    end
    
    cloudSyncInProgress = true
    
    -- 使用 BatchSet 存储多个整数值
    local batchSet = clientScore:BatchSet()
    for _, key in ipairs(StatsManager.KEYS) do
        local cloudKey = StatsManager.KEY_PREFIX .. key
        local value = statsData[key] or 0
        batchSet:SetInt(cloudKey, math.floor(value))
    end
    batchSet:Save("stats_sync", {
        ok = function()
            cloudSyncInProgress = false
            localDirty = false
            print("[StatsManager] Synced to cloud")
            if callback then callback(true) end
        end,
        error = function(code, reason)
            cloudSyncInProgress = false
            print("[StatsManager] Cloud sync error: " .. tostring(reason))
            if callback then callback(false) end
        end,
        timeout = function()
            cloudSyncInProgress = false
            print("[StatsManager] Cloud sync timeout")
            if callback then callback(false) end
        end
    })
end

-- 强制同步（用于游戏暂停或切后台）
function StatsManager.Flush(callback)
    if localDirty then
        StatsManager.SyncToCloud(callback)
    elseif callback then
        callback(true)
    end
end

-- 检查是否有未同步的修改
function StatsManager.IsDirty()
    return localDirty
end

-- ============================================================================
-- 格式化输出（用于 UI 显示）
-- ============================================================================

-- 格式化时间为 "XXh XXm" 格式
function StatsManager.FormatPlayTime(seconds)
    seconds = seconds or 0
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    else
        return string.format("%dm", minutes)
    end
end

-- 格式化大数字（如 1234567 -> "1.23M"）
function StatsManager.FormatNumber(num)
    num = num or 0
    if num >= 1000000 then
        return string.format("%.2fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

-- 获取格式化的统计摘要
function StatsManager.GetStatsSummary()
    local stats = StatsManager.GetStats()
    return {
        gamesPlayed = stats.totalGamesPlayed,
        enemiesKilled = stats.totalEnemiesKilled,
        crystalsEarned = stats.totalCrystalsEarned,
        crystalsSpent = stats.totalCrystalsSpent,
        hyperspaceJumps = stats.totalHyperspaceJumps,
        playTime = stats.totalPlayTime,
        playTimeFormatted = StatsManager.FormatPlayTime(stats.totalPlayTime),
        highestWave = stats.highestWave,
        victories = stats.totalVictories,
    }
end

return StatsManager
