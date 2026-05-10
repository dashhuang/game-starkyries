-- ============================================================================
-- 星河战姬 Starkyries - 战斗系统
-- 波次管理、分组刷怪（对标Brotato）
-- ============================================================================

local Settings = require("config.settings")
local Waves = require("config.waves")
local Enemies = require("config.enemies")
local Math = require("utils.Math")
local Game = require("core.Game")

local Battle = {}

-- ============================================================================
-- 状态
-- ============================================================================
Battle.currentWave = 1
Battle.waveTimer = 0
Battle.waveActive = false
Battle.waveCompleteDelay = 0

-- 分组刷怪状态：记录每个组的上次刷新时间
-- groupSpawnStates[groupIndex] = { lastSpawnTime = number or nil, hasSpawned = boolean }
Battle.groupSpawnStates = {}

-- Boss状态
Battle.bossSpawned = false
Battle.bossDefeated = false       -- Boss是否被击败（用于触发提前结束）
Battle.bossDefeatedTimer = 0      -- Boss击败后的延迟计时器

-- 残骸系统状态
Battle.debrisSpawnTimer = 0       -- 残骸生成计时器
Battle.debrisSpawnInterval = Settings.Combat.DebrisSpawnInterval   -- 残骸生成间隔

-- 回调函数
Battle.onSpawnEnemy = nil      -- function(enemyType, x, y, fromWarp)
Battle.onWarpWarning = nil     -- function(x, y, enemyType, delay)
Battle.onWaveStart = nil       -- function(waveNum)
Battle.onWaveComplete = nil    -- function(waveNum)
Battle.onAllWavesComplete = nil  -- function()
Battle.getEnemyCount = nil     -- function() return count
Battle.getWarpWarningCount = nil -- function() return count
Battle.getPlayerPosition = nil  -- function() return x, y
Battle.getVisibleArea = nil    -- function() return {minX, maxX, minY, maxY}
Battle.forceRemoveEnemy = nil  -- function() 强制移除一只非精英/非Boss敌舰（不掉落，计入击杀）
Battle.clearAllEnemies = nil   -- function() 清除所有敌人
Battle.clearAllWarpWarnings = nil -- function() 清除所有跃迁预警
Battle.triggerAllEnemiesSelfDestruct = nil -- function() 触发所有敌人自爆（Boss击败时）

-- 残骸系统回调
Battle.onSpawnDebris = nil     -- function(waveNum, visibleArea) 生成残骸
Battle.clearAllDebris = nil    -- function() 清除所有残骸

-- ============================================================================
-- 初始化
-- ============================================================================

function Battle.Init()
    Battle.currentWave = 1
    Battle.waveTimer = 0
    Battle.waveActive = false
    Battle.waveCompleteDelay = 0
    Battle.groupSpawnStates = {}
    Battle.bossSpawned = false
    Battle.bossDefeated = false
    Battle.bossDefeatedTimer = 0
    Battle.bossOnlyMode = false  -- 敌人测试模式：只生成Boss
    Battle.testBossType = nil    -- 测试模式：指定Boss类型
    Battle.debrisSpawnTimer = 0  -- 残骸生成计时器重置
end

-- ============================================================================
-- 波次管理
-- ============================================================================

function Battle.StartWave(waveNum)
    Battle.currentWave = waveNum
    Battle.waveTimer = 0
    Battle.waveActive = true
    Battle.waveCompleteDelay = 0
    Battle.bossSpawned = false
    Battle.bossDefeated = false
    Battle.bossDefeatedTimer = 0
    
    -- 重置所有分组刷怪状态
    Battle.groupSpawnStates = {}
    local groups = Waves.GetSpawnGroups(waveNum)
    for i = 1, #groups do
        Battle.groupSpawnStates[i] = {
            lastSpawnTime = nil,  -- nil 表示还未首次刷新
            hasSpawned = false,
        }
    end
    
    if Battle.onWaveStart then
        Battle.onWaveStart(waveNum)
    end
end

function Battle.Update(dt)
    if not Battle.waveActive then return end
    
    local waveConfig = Waves.Get(Battle.currentWave)
    if not waveConfig then
        -- 所有波次完成
        if Battle.onAllWavesComplete then
            Battle.onAllWavesComplete()
        end
        Battle.waveActive = false
        return
    end
    
    -- Boss击败后的延迟结束处理
    if Battle.bossDefeated then
        Battle.bossDefeatedTimer = Battle.bossDefeatedTimer + dt
        
        -- 1秒后结束波次
        if Battle.bossDefeatedTimer >= Settings.Combat.BossDefeatDelay then
            Battle.waveActive = false
            
            -- 清除跃迁预警
            if Battle.clearAllWarpWarnings then
                Battle.clearAllWarpWarnings()
            end
            
            -- 清除未摧毁的残骸
            if Battle.clearAllDebris then
                Battle.clearAllDebris()
            end
            
            -- 重置残骸生成计时器
            Battle.debrisSpawnTimer = 0
            
            if Battle.onWaveComplete then
                Battle.onWaveComplete(Battle.currentWave)
            end
        end
        return  -- Boss击败后不再刷怪
    end
    
    Battle.waveTimer = Battle.waveTimer + dt
    -- 更新游戏时长统计
    if Game.battle then
        Game.battle.playTime = (Game.battle.playTime or 0) + dt
    end
    local waveDuration = Waves.GetDuration(Battle.currentWave)
    
    -- 波次结束检查
    if Battle.waveTimer >= waveDuration then
        -- 时间到，立即结束波次
        Battle.waveActive = false
        
        -- 清除跃迁预警（敌人保留，在跃迁动画中飞离）
        if Battle.clearAllWarpWarnings then
            Battle.clearAllWarpWarnings()
        end
        
        -- 清除未摧毁的残骸
        if Battle.clearAllDebris then
            Battle.clearAllDebris()
        end
        
        -- 重置残骸生成计时器
        Battle.debrisSpawnTimer = 0
        
        if Battle.onWaveComplete then
            Battle.onWaveComplete(Battle.currentWave)
        end
    else
        -- 波次进行中：分组刷怪
        Battle.UpdateGroupSpawning()
        
        -- 残骸生成（每10秒生成一次）
        Battle.debrisSpawnTimer = Battle.debrisSpawnTimer + dt
        if Battle.debrisSpawnTimer >= Battle.debrisSpawnInterval then
            Battle.debrisSpawnTimer = Battle.debrisSpawnTimer - Battle.debrisSpawnInterval
            if Battle.onSpawnDebris then
                local visibleArea = nil
                if Battle.getVisibleArea then
                    visibleArea = Battle.getVisibleArea()
                end
                Battle.onSpawnDebris(Battle.currentWave, visibleArea)
            end
        end
        
        -- Boss生成检查
        if waveConfig.isBossWave and not Battle.bossSpawned then
            local bossSpawnTime = waveConfig.bossSpawnTime or 5
            if Battle.waveTimer >= bossSpawnTime then
                Battle.SpawnBoss()
                Battle.bossSpawned = true
            end
        end
        
        -- 检查是否超出上限（100只），超出则强制移除
        Battle.EnforceEnemyLimit()
    end
end

-- ============================================================================
-- Boss击败处理
-- ============================================================================

-- 当Boss被击败时调用
-- 完全由波次配置驱动：如果波次配置了 bossType，击杀该类型敌人会触发提前结束
-- @param bossType 被击杀的敌人类型
function Battle.OnBossDefeated(bossType)
    local waveConfig = Waves.Get(Battle.currentWave)
    if not waveConfig then return end
    
    -- 纯配置驱动：只检查波次是否配置了 bossType
    -- 如果没有配置 bossType，这个敌人就是普通敌人，不触发任何效果
    if not waveConfig.bossType then return end
    
    -- 检查击杀的敌人是否是配置的Boss类型
    if bossType ~= waveConfig.bossType then
        return  -- 不是配置的Boss，不触发提前结束
    end
    
    -- 标记Boss已击败
    Battle.bossDefeated = true
    Battle.bossDefeatedTimer = 0
    
    -- 触发所有敌人自爆
    if Battle.triggerAllEnemiesSelfDestruct then
        Battle.triggerAllEnemiesSelfDestruct()
    end
    
    -- 清除跃迁预警（不再生成新敌人）
    if Battle.clearAllWarpWarnings then
        Battle.clearAllWarpWarnings()
    end
end

-- ============================================================================
-- 分组刷怪系统（核心逻辑）
-- ============================================================================

function Battle.UpdateGroupSpawning()
    -- 敌人测试模式：跳过小怪生成
    if Battle.bossOnlyMode then return end
    
    local groups = Waves.GetSpawnGroups(Battle.currentWave)
    if not groups or #groups == 0 then return end
    
    local elapsedTime = Battle.waveTimer
    
    for i, group in ipairs(groups) do
        local state = Battle.groupSpawnStates[i]
        if not state then
            state = { lastSpawnTime = nil, hasSpawned = false }
            Battle.groupSpawnStates[i] = state
        end
        
        -- 检查是否应该刷新这个组
        local shouldSpawn = false
        
        if state.lastSpawnTime == nil then
            -- 首次刷新检查：是否达到 spawn_timing
            if elapsedTime >= group.spawn_timing then
                shouldSpawn = true
            end
        elseif group.repeating_interval then
            -- 重复刷新检查：是否达到下次刷新时间
            if elapsedTime >= state.lastSpawnTime + group.repeating_interval then
                shouldSpawn = true
            end
        end
        
        if shouldSpawn then
            -- 概率检查（如吞噬机3%概率、走私船10%概率）
            local spawnChance = group.spawnChance or 1.0
            if math.random() <= spawnChance then
                -- 执行刷新
                local count = math.random(group.min_number, group.max_number)
                for j = 1, count do
                    local enemyType = Waves.RandomEnemy(group.enemies)
                    if enemyType then
                        Battle.SpawnEnemyOfType(enemyType, group.spawn_edge)
                    end
                end
            end
            
            -- 更新状态
            state.lastSpawnTime = elapsedTime
            state.hasSpawned = true
        end
    end
end

-- ============================================================================
-- 敌人生成
-- ============================================================================

-- 生成指定类型的敌人
function Battle.SpawnEnemyOfType(enemyType, forceEdge)
    if not Battle.onSpawnEnemy then return end
    
    local waveConfig = Waves.Get(Battle.currentWave)
    local warpChance = waveConfig and waveConfig.warpChance or 0.2
    
    -- 决定生成方式：边缘 or 跃迁
    local useWarp = false
    if forceEdge then
        useWarp = false  -- 强制边缘生成
    else
        useWarp = math.random() < warpChance
    end
    
    local arena = Settings.BattleArea
    local margin = Settings.Spawn.Margin
    local x, y
    
    -- 获取当前可视区域
    local visible = nil
    if Battle.getVisibleArea then
        visible = Battle.getVisibleArea()
    end
    if not visible then
        visible = {
            minX = arena.MinX,
            maxX = arena.MaxX,
            minY = arena.MinY,
            maxY = arena.MaxY
        }
    end
    
    if useWarp then
        -- 跃迁生成：在可视区域内随机位置（但不能太靠近玩家）
        local playerX, playerY = 0, 0
        if Battle.getPlayerPosition then
            playerX, playerY = Battle.getPlayerPosition()
        end
        
        local minDist = Settings.Spawn.MinWarpDistance
        
        -- 可视区域内缩一点边距
        local warpMargin = Settings.SpawnMargins.WarpMargin
        local warpMinX = visible.minX + warpMargin
        local warpMaxX = visible.maxX - warpMargin
        local warpMinY = visible.minY + warpMargin
        local warpMaxY = visible.maxY - warpMargin
        
        for attempt = 1, 10 do
            x = Math.RandomRange(warpMinX, warpMaxX)
            y = Math.RandomRange(warpMinY, warpMaxY)
            
            local dist = Math.Distance(x, y, playerX, playerY)
            if dist >= minDist then
                break
            end
        end
        
        -- 确保跃迁位置在竞技场内
        x = math.max(arena.MinX, math.min(arena.MaxX, x))
        y = math.max(arena.MinY, math.min(arena.MaxY, y))
        
        -- 创建跃迁预警
        if Battle.onWarpWarning then
            Battle.onWarpWarning(x, y, enemyType, Settings.Spawn.WarpWarningTime)
        end
    else
        -- 边缘生成：在可视区域外 + margin 处生成
        local side = math.random(4)
        if side == 1 then      -- 右边
            x = visible.maxX + margin
            y = Math.RandomRange(visible.minY, visible.maxY)
        elseif side == 2 then  -- 左边
            x = visible.minX - margin
            y = Math.RandomRange(visible.minY, visible.maxY)
        elseif side == 3 then  -- 上边
            x = Math.RandomRange(visible.minX, visible.maxX)
            y = visible.maxY + margin
        else                   -- 下边
            x = Math.RandomRange(visible.minX, visible.maxX)
            y = visible.minY - margin
        end
        
        -- 确保生成位置不超出竞技场边界
        local arenaMargin = Settings.SpawnMargins.ArenaMargin
        x = math.max(arena.MinX - arenaMargin, math.min(arena.MaxX + arenaMargin, x))
        y = math.max(arena.MinY - arenaMargin, math.min(arena.MaxY + arenaMargin, y))
        
        -- 直接生成敌人
        Battle.onSpawnEnemy(enemyType, x, y, false)
    end
end

-- 旧的随机敌人生成（保留兼容）
function Battle.SpawnEnemy()
    local waveConfig = Waves.Get(Battle.currentWave)
    if not waveConfig then return end
    
    -- 从所有组的敌人中随机选择
    local groups = Waves.GetSpawnGroups(Battle.currentWave)
    local allEnemies = {}
    for _, group in ipairs(groups) do
        for _, enemy in ipairs(group.enemies) do
            table.insert(allEnemies, enemy)
        end
    end
    
    if #allEnemies == 0 then return end
    
    local enemyType = allEnemies[math.random(#allEnemies)]
    Battle.SpawnEnemyOfType(enemyType, false)
end

-- BOSS 生成
function Battle.SpawnBoss()
    local waveConfig = Waves.Get(Battle.currentWave)
    
    -- 测试模式：使用指定的Boss类型
    local bossType = Battle.testBossType
    if not bossType then
        if not waveConfig or not waveConfig.isBossWave then return end
        bossType = waveConfig.bossType
    end
    if not bossType then return end
    
    local area = Settings.BattleArea
    
    -- BOSS 从右侧生成
    local x = area.MaxX + 5
    local y = 0
    
    if Battle.onSpawnEnemy then
        Battle.onSpawnEnemy(bossType, x, y, false)
    end
    
    -- 多BOSS波（如果有）
    if waveConfig.additionalBosses then
        for i, additionalBossType in ipairs(waveConfig.additionalBosses) do
            local bossY = (i % 2 == 0) and 5 or -5
            if Battle.onSpawnEnemy then
                Battle.onSpawnEnemy(additionalBossType, x, bossY, false)
            end
        end
    end
end

-- ============================================================================
-- 敌人数量上限管理
-- ============================================================================

function Battle.EnforceEnemyLimit()
    local maxEnemies = Settings.Combat.MaxEnemies
    if not Battle.getEnemyCount or not Battle.forceRemoveEnemy then
        return
    end
    
    local currentCount = Battle.getEnemyCount()
    while currentCount > maxEnemies do
        local removed = Battle.forceRemoveEnemy()
        if not removed then
            break  -- 无法移除更多（可能只剩精英/Boss）
        end
        currentCount = Battle.getEnemyCount()
    end
end

-- ============================================================================
-- 难度缩放（纯线性，完全对标Brotato）
-- ============================================================================

function Battle.GetEnemyScaling()
    return Waves.GetScaling(Battle.currentWave)
end

-- 缩放敌人属性（纯线性公式，完全对标Brotato）
-- 公式：
--   敌舰护盾 = 基础护盾 + (每波护盾增量 × (当前波次 - 1))
--   敌舰伤害 = 基础伤害 + (每波伤害增量 × (当前波次 - 1))
--   敌舰速度 = 基础速度（不随波次变化）
function Battle.ScaleEnemyStats(enemyDef)
    local waveNum = Battle.currentWave
    
    -- 纯线性成长公式（对标Brotato）
    local hpPerWave = enemyDef.hpPerWave or 0
    local damagePerWave = enemyDef.damagePerWave or 0
    
    -- 护盾 = 基础 + (perWave × (波次 - 1))
    local hp = enemyDef.hp + (hpPerWave * (waveNum - 1))
    -- 伤害 = 基础 + (perWave × (波次 - 1))
    local damage = enemyDef.damage + (damagePerWave * (waveNum - 1))
    -- 速度 = 基础速度（不随波次变化，Brotato原版设计）
    local speed = enemyDef.moveSpeed
    
    -- TODO: 危险等级加成（见文档 6.4.2 节）
    -- 危险3: +12% HP/伤害
    -- 危险4: +26% HP/伤害
    -- 危险5: +40% HP/伤害
    
    return {
        hp = math.floor(hp),
        damage = math.floor(damage),
        moveSpeed = speed,
    }
end

-- ============================================================================
-- 工具函数
-- ============================================================================

function Battle.GetCurrentWave()
    return Battle.currentWave
end

function Battle.GetTotalWaves()
    return Waves.GetTotalWaves()
end

function Battle.GetWaveConfig()
    return Waves.Get(Battle.currentWave)
end

function Battle.GetWaveDuration()
    return Waves.GetDuration(Battle.currentWave)
end

function Battle.GetTimeRemaining()
    local duration = Waves.GetDuration(Battle.currentWave)
    return math.max(0, duration - Battle.waveTimer)
end

function Battle.GetTimeElapsed()
    return Battle.waveTimer
end

function Battle.IsWaveActive()
    return Battle.waveActive
end

function Battle.IsBossWave()
    return Waves.IsBossWave(Battle.currentWave)
end

function Battle.GetFactionName()
    return Waves.GetFactionName(Battle.currentWave)
end

-- ============================================================================
-- 调试函数
-- ============================================================================

function Battle.PrintSpawnStatus()
    local groups = Waves.GetSpawnGroups(Battle.currentWave)
    print(string.format("=== 波次 %d 刷怪状态 (%.1fs) ===", Battle.currentWave, Battle.waveTimer))
    for i, group in ipairs(groups) do
        local state = Battle.groupSpawnStates[i] or {}
        local enemies = table.concat(group.enemies, ",")
        local status = state.lastSpawnTime and string.format("已刷@%.1fs", state.lastSpawnTime) or "未刷"
        print(string.format("  组%d [%s]: timing=%.1f, interval=%s, %d-%d只, %s",
            i, enemies,
            group.spawn_timing,
            group.repeating_interval and string.format("%.1f", group.repeating_interval) or "一次性",
            group.min_number, group.max_number,
            status
        ))
    end
end

return Battle
