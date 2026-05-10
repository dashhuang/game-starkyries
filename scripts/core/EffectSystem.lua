-- ============================================================================
-- 星河战姬 Starkyries - 效果系统
-- 效果执行引擎，负责监听事件并执行对应效果
-- ============================================================================

local EffectSystem = {
    initialized = false,
    debug = false,
    
    -- 统计数据
    stats = {},
    
    -- 订阅取消函数
    unsubscribers = {},
}

-- 延迟加载依赖
local EventBus = nil
local Effects = nil
local Events = nil
local Game = nil
local Enemy = nil

-- ============================================================================
-- 延迟加载依赖模块
-- ============================================================================

local function LoadDependencies()
    if not EventBus then
        EventBus = require("utils.EventBus")
    end
    if not Effects then
        Effects = require("config.effects")
    end
    if not Events then
        Events = require("config.events")
    end
end

local function LoadGameDependencies()
    if not Game then
        Game = require("core.Game")
    end
end

local function LoadEnemyDependencies()
    if not Enemy then
        local success, result = pcall(require, "entities.Enemy")
        if success then
            Enemy = result
        end
    end
end

-- ============================================================================
-- 初始化
-- ============================================================================

---@brief 初始化效果系统，订阅所有效果的触发事件
function EffectSystem.Init()
    if EffectSystem.initialized then
        EffectSystem.Cleanup()
    end
    
    LoadDependencies()
    
    -- 验证效果定义
    local valid, errors = Effects.Validate()
    if not valid then
        for _, err in ipairs(errors) do
            print("[EffectSystem] Warning: " .. err)
        end
    end
    
    -- 收集所有使用的触发事件
    local usedTriggers = {}
    for id, def in pairs(Effects.Definitions) do
        local trigger = def.trigger
        if trigger then
            usedTriggers[trigger] = usedTriggers[trigger] or {}
            table.insert(usedTriggers[trigger], {id = id, def = def})
        end
    end
    
    -- 按优先级排序每个触发器的效果
    for trigger, effects in pairs(usedTriggers) do
        table.sort(effects, function(a, b)
            local prioA = a.def.priority or 0
            local prioB = b.def.priority or 0
            return prioA > prioB
        end)
    end
    
    -- 为每个触发事件订阅处理器
    for trigger, effects in pairs(usedTriggers) do
        local unsubscribe = EventBus.on(trigger, function(eventData)
            EffectSystem.ProcessTrigger(trigger, eventData, effects)
        end)
        table.insert(EffectSystem.unsubscribers, unsubscribe)
        
        if EffectSystem.debug then
            print(string.format("[EffectSystem] Subscribed to '%s' with %d effects", 
                trigger, #effects))
        end
    end
    
    EffectSystem.initialized = true
    
    if EffectSystem.debug then
        print("[EffectSystem] Initialized with " .. #EffectSystem.unsubscribers .. " subscriptions")
    end
end

---@brief 清理效果系统
function EffectSystem.Cleanup()
    for _, unsubscribe in ipairs(EffectSystem.unsubscribers) do
        if type(unsubscribe) == "function" then
            unsubscribe()
        end
    end
    EffectSystem.unsubscribers = {}
    EffectSystem.initialized = false
    
    if EffectSystem.debug then
        print("[EffectSystem] Cleaned up")
    end
end

-- ============================================================================
-- 效果执行
-- ============================================================================

---@brief 处理触发事件
---@param trigger string 触发事件名
---@param eventData table 事件数据
---@param effects table 该触发器关联的效果列表
function EffectSystem.ProcessTrigger(trigger, eventData, effects)
    LoadGameDependencies()
    
    if not Game or not Game.player then
        return
    end
    
    if EffectSystem.debug then
        print(string.format("[EffectSystem] Trigger: %s", trigger))
    end
    
    -- 构建上下文
    local ctx = {
        player = Game.player,
        event = eventData or {},
        debug = EffectSystem.debug,
        emit = function(event, data)
            LoadDependencies()
            EventBus.emit(event, data)
        end,
    }
    
    -- 按优先级执行效果
    for _, effectInfo in ipairs(effects) do
        local id = effectInfo.id
        local def = effectInfo.def
        
        -- 初始化统计
        EffectSystem.stats[id] = EffectSystem.stats[id] or {triggered = 0, executed = 0}
        EffectSystem.stats[id].triggered = EffectSystem.stats[id].triggered + 1
        
        -- 设置上下文中的效果信息
        ctx.effectId = id
        ctx.stackCount = EffectSystem.GetStackCount(id)
        
        -- 检查条件
        local shouldExecute = true
        if def.condition then
            local success, result = pcall(def.condition, ctx)
            if not success then
                print(string.format("[EffectSystem] Error in condition for '%s': %s", id, result))
                shouldExecute = false
            else
                shouldExecute = result
            end
        end
        
        if EffectSystem.debug then
            print(string.format("[EffectSystem]   Checking: %s (condition: %s)", 
                id, tostring(shouldExecute)))
        end
        
        -- 执行效果
        if shouldExecute then
            local success, err = pcall(def.execute, ctx)
            if success then
                EffectSystem.stats[id].executed = EffectSystem.stats[id].executed + 1
                
                if EffectSystem.debug then
                    print(string.format("[EffectSystem]   Executed: %s (stack: %d)", 
                        id, ctx.stackCount))
                end
            else
                print(string.format("[EffectSystem] Error executing '%s': %s", id, err))
            end
        end
    end
end

---@brief 手动触发效果检查
---@param trigger string 触发事件名
---@param eventData table 事件数据
function EffectSystem.CheckTrigger(trigger, eventData)
    LoadDependencies()
    
    -- 收集该触发器的效果
    local effects = {}
    for id, def in pairs(Effects.Definitions) do
        if def.trigger == trigger then
            table.insert(effects, {id = id, def = def})
        end
    end
    
    -- 排序
    table.sort(effects, function(a, b)
        local prioA = a.def.priority or 0
        local prioB = b.def.priority or 0
        return prioA > prioB
    end)
    
    EffectSystem.ProcessTrigger(trigger, eventData, effects)
end

-- ============================================================================
-- 效果叠加层数计算
-- ============================================================================

---@brief 获取效果的叠加层数
---@param effectId string 效果 ID
---@return number 叠加层数
function EffectSystem.GetStackCount(effectId)
    LoadGameDependencies()
    
    if not Game or not Game.player then
        return 0
    end
    
    local p = Game.player
    
    -- 根据效果 ID 映射到玩家属性
    local stackMapping = {
        ["heal_on_kill"] = function() return p.killHeal or 0 end,
        ["demon_pact_heal"] = function() return p.hasDemonPact and 1 or 0 end,
        ["death_chain"] = function() 
            -- 死亡连锁通过概率叠加，每层 +10%
            return math.floor((p.deathChainChance or 0) / 0.10)
        end,
        ["kill_crystal_bonus"] = function() return p.killCrystalBonus or 0 end,
        ["emergency_boost"] = function() return p.hasEmergencyBoost and 1 or 0 end,
        ["demon_pact_drain"] = function() return p.hasDemonPact and 1 or 0 end,
        ["plasma_burn"] = function()
            return math.floor((p.burnChance or 0) / 0.20)
        end,
    }
    
    local getter = stackMapping[effectId]
    if getter then
        return math.max(1, getter())
    end
    
    return 1  -- 默认 1 层
end

-- ============================================================================
-- 特殊效果触发函数
-- ============================================================================

---@brief 连锁伤害
---@param x number 中心 X 坐标
---@param y number 中心 Y 坐标
---@param damage number 伤害值
---@param radius number 范围半径
function EffectSystem.TriggerChainDamage(x, y, damage, radius)
    LoadEnemyDependencies()
    
    if not Enemy or not Enemy.enemies then
        return
    end
    
    local hitCount = 0
    
    for _, enemy in ipairs(Enemy.enemies) do
        if enemy and not enemy.dead then
            local dx = enemy.x - x
            local dy = enemy.y - y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if dist <= radius and dist > 0 then  -- dist > 0 排除自身
                Enemy.TakeDamage(enemy, damage, false)
                hitCount = hitCount + 1
                
                if hitCount >= 3 then  -- 最多连锁 3 个敌人
                    break
                end
            end
        end
    end
    
    if EffectSystem.debug and hitCount > 0 then
        print(string.format("[EffectSystem] Chain damage hit %d enemies", hitCount))
    end
end

---@brief AOE 伤害
---@param x number 中心 X 坐标
---@param y number 中心 Y 坐标
---@param damage number 伤害值
---@param radius number 范围半径
---@param excludeEnemy table 排除的敌人（可选）
function EffectSystem.TriggerAOEDamage(x, y, damage, radius, excludeEnemy)
    LoadEnemyDependencies()
    
    if not Enemy or not Enemy.enemies then
        return
    end
    
    for _, enemy in ipairs(Enemy.enemies) do
        if enemy and not enemy.dead and enemy ~= excludeEnemy then
            local dx = enemy.x - x
            local dy = enemy.y - y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if dist <= radius then
                Enemy.TakeDamage(enemy, damage, false)
            end
        end
    end
end

-- ============================================================================
-- 动态效果管理
-- ============================================================================

---@brief 运行时注册新效果
---@param effectId string 效果 ID
---@param definition table 效果定义
function EffectSystem.Register(effectId, definition)
    LoadDependencies()
    
    Effects.Definitions[effectId] = definition
    
    -- 如果系统已初始化，需要重新订阅
    if EffectSystem.initialized then
        EffectSystem.Init()
    end
    
    if EffectSystem.debug then
        print(string.format("[EffectSystem] Registered effect: %s", effectId))
    end
end

---@brief 移除效果
---@param effectId string 效果 ID
function EffectSystem.Unregister(effectId)
    LoadDependencies()
    
    Effects.Definitions[effectId] = nil
    
    -- 如果系统已初始化，需要重新订阅
    if EffectSystem.initialized then
        EffectSystem.Init()
    end
    
    if EffectSystem.debug then
        print(string.format("[EffectSystem] Unregistered effect: %s", effectId))
    end
end

-- ============================================================================
-- 调试与统计
-- ============================================================================

---@brief 设置调试模式
---@param enabled boolean 是否启用
function EffectSystem.SetDebug(enabled)
    EffectSystem.debug = enabled
    
    LoadDependencies()
    EventBus.setDebug(enabled)
end

---@brief 获取效果执行统计
---@return table 统计数据
function EffectSystem.GetStats()
    return EffectSystem.stats
end

---@brief 重置统计
function EffectSystem.ResetStats()
    EffectSystem.stats = {}
end

---@brief 打印调试信息
function EffectSystem.Debug()
    LoadDependencies()
    
    print("=== EffectSystem Debug ===")
    print(string.format("Initialized: %s", tostring(EffectSystem.initialized)))
    print(string.format("Subscriptions: %d", #EffectSystem.unsubscribers))
    print("")
    
    print("Registered Effects:")
    for id, def in pairs(Effects.Definitions) do
        local stats = EffectSystem.stats[id] or {triggered = 0, executed = 0}
        print(string.format("  %s: trigger=%s, prio=%d, stats=%d/%d", 
            id, 
            def.trigger or "none",
            def.priority or 0,
            stats.executed,
            stats.triggered
        ))
    end
    print("========================")
end

---@brief 获取当前激活的效果（供 UI 显示）
---@return table 激活效果列表
function EffectSystem.GetActiveEffects()
    LoadDependencies()
    LoadGameDependencies()
    
    local active = {}
    
    if not Game or not Game.player then
        return active
    end
    
    for id, def in pairs(Effects.Definitions) do
        local stackCount = EffectSystem.GetStackCount(id)
        if stackCount > 0 then
            table.insert(active, {
                id = id,
                stackCount = stackCount,
                description = def.description,
                category = def.category,
            })
        end
    end
    
    return active
end

---@brief 强制执行效果（测试用）
---@param effectId string 效果 ID
---@param mockEventData table 模拟事件数据
function EffectSystem.ForceExecute(effectId, mockEventData)
    LoadDependencies()
    LoadGameDependencies()
    
    local def = Effects.Definitions[effectId]
    if not def then
        print(string.format("[EffectSystem] Effect '%s' not found", effectId))
        return false
    end
    
    local ctx = {
        player = Game.player,
        event = mockEventData or {},
        effectId = effectId,
        stackCount = EffectSystem.GetStackCount(effectId),
        debug = true,
        emit = function(event, data)
            EventBus.emit(event, data)
        end,
    }
    
    local success, err = pcall(def.execute, ctx)
    if not success then
        print(string.format("[EffectSystem] Error: %s", err))
    end
    
    return success
end

return EffectSystem
