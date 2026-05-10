-- ============================================================================
-- 星河战姬 Starkyries - 事件总线系统
-- ============================================================================
-- 用于模块间解耦通信，替代直接回调赋值
-- ============================================================================

local EventBus = {}

-- 事件监听器存储
-- { eventName = { {callback, priority, id}, ... } }
local listeners = {}

-- 监听器ID计数器
local listenerIdCounter = 0

-- 性能优化：标记是否正在迭代中
local emitDepth = 0
-- 延迟删除队列 { {eventName, id}, ... }
local pendingRemovals = {}

-- ============================================================================
-- 事件常量定义
-- ============================================================================

EventBus.Events = {
    -- 敌人事件
    ENEMY_DEATH = "enemy:death",           -- (enemy)
    ENEMY_SPAWN = "enemy:spawn",           -- (enemy)
    ENEMY_EXPLODE = "enemy:explode",       -- (x, y, radius, damage, enemyInfo)
    ENEMY_SHOOT = "enemy:shoot",           -- (enemy, targetX, targetY)
    ENEMY_HEAL = "enemy:heal",             -- (healerX, healerY, targetX, targetY, amount)
    BOSS_SPAWN = "boss:spawn",             -- (bossEnemy, spawnType, count)
    BOSS_PHASE_CHANGE = "boss:phaseChange", -- (bossEnemy, newPhase, phaseName)
    
    -- 玩家事件
    PLAYER_DAMAGE = "player:damage",       -- (damage, source)
    PLAYER_HEAL = "player:heal",           -- (amount)
    PLAYER_DEATH = "player:death",         -- ()
    PLAYER_LEVEL_UP = "player:levelUp",    -- (newLevel)
    
    -- 武器/子弹事件
    PROJECTILE_HIT = "projectile:hit",     -- (projectile, enemy)
    PROJECTILE_ENEMY_HIT = "projectile:enemyHit", -- (projectile, damage)
    
    -- 拾取物事件
    PICKUP_COLLECT = "pickup:collect",     -- (pickup)
    CRYSTAL_COLLECT = "crystal:collect",   -- (amount)
    
    -- 无人机事件
    DRONE_FIRE = "drone:fire",             -- (drone, targetX, targetY, damage, isCrit, aoeRadius)
    
    -- 特效事件
    WARP_COMPLETE = "effect:warpComplete", -- (x, y, enemyType)
    
    -- 游戏流程事件
    WAVE_START = "game:waveStart",         -- (waveNumber)
    WAVE_END = "game:waveEnd",             -- (waveNumber)
    GAME_PAUSE = "game:pause",             -- ()
    GAME_RESUME = "game:resume",           -- ()
    GAME_OVER = "game:over",               -- ()
    
    -- UI事件
    SHOP_OPEN = "ui:shopOpen",             -- ()
    SHOP_CLOSE = "ui:shopClose",           -- ()
    ITEM_PURCHASE = "ui:itemPurchase",     -- (item)
}

-- ============================================================================
-- 内部辅助函数
-- ============================================================================

--- 二分查找插入位置（按优先级排序）
---@param list table 监听器列表
---@param priority number 目标优先级
---@return number 插入位置
local function binarySearchInsertPos(list, priority)
    local low, high = 1, #list
    while low <= high do
        local mid = math.floor((low + high) / 2)
        if list[mid].priority < priority then
            low = mid + 1
        else
            high = mid - 1
        end
    end
    return low
end

--- 处理延迟删除队列
local function processPendingRemovals()
    if emitDepth > 0 or #pendingRemovals == 0 then return end
    
    for i = 1, #pendingRemovals do
        local removal = pendingRemovals[i]
        local eventName, targetId = removal[1], removal[2]
        local eventListeners = listeners[eventName]
        if eventListeners then
            for j = #eventListeners, 1, -1 do
                if eventListeners[j].id == targetId then
                    table.remove(eventListeners, j)
                    break
                end
            end
            if #eventListeners == 0 then
                listeners[eventName] = nil
            end
        end
        pendingRemovals[i] = nil
    end
end

-- ============================================================================
-- 公共方法
-- ============================================================================

--- 订阅事件
---@param eventName string 事件名称
---@param callback function 回调函数
---@param priority number? 优先级（数值越小越先执行，默认100）
---@return number 监听器ID，用于取消订阅
function EventBus.On(eventName, callback, priority)
    if not eventName or not callback then
        return -1
    end
    
    priority = priority or 100
    listenerIdCounter = listenerIdCounter + 1
    local id = listenerIdCounter
    
    if not listeners[eventName] then
        listeners[eventName] = {}
    end
    
    local list = listeners[eventName]
    local listener = {
        callback = callback,
        priority = priority,
        id = id,
    }
    
    -- 二分插入保持排序（避免每次 table.sort）
    local pos = binarySearchInsertPos(list, priority)
    table.insert(list, pos, listener)
    
    return id
end

--- 一次性订阅（触发一次后自动取消）
---@param eventName string 事件名称
---@param callback function 回调函数
---@param priority number? 优先级
---@return number 监听器ID
function EventBus.Once(eventName, callback, priority)
    local id
    local wrappedCallback = function(...)
        EventBus.Off(eventName, id)
        callback(...)
    end
    id = EventBus.On(eventName, wrappedCallback, priority)
    return id
end

--- 取消订阅
---@param eventName string 事件名称
---@param idOrCallback number|function 监听器ID或回调函数
function EventBus.Off(eventName, idOrCallback)
    local eventListeners = listeners[eventName]
    if not eventListeners then return end
    
    -- 查找目标监听器
    local targetId = nil
    for i = 1, #eventListeners do
        local listener = eventListeners[i]
        if type(idOrCallback) == "number" then
            if listener.id == idOrCallback then
                targetId = idOrCallback
                break
            end
        else
            if listener.callback == idOrCallback then
                targetId = listener.id
                break
            end
        end
    end
    
    if not targetId then return end
    
    -- 如果正在 Emit 中，延迟删除
    if emitDepth > 0 then
        pendingRemovals[#pendingRemovals + 1] = {eventName, targetId}
        -- 标记为已删除（callback 置 nil）
        for i = 1, #eventListeners do
            if eventListeners[i].id == targetId then
                eventListeners[i].callback = nil
                break
            end
        end
    else
        -- 直接删除
        for i = #eventListeners, 1, -1 do
            if eventListeners[i].id == targetId then
                table.remove(eventListeners, i)
                break
            end
        end
        if #eventListeners == 0 then
            listeners[eventName] = nil
        end
    end
end

--- 发布事件
---@param eventName string 事件名称
---@vararg any 事件参数
function EventBus.Emit(eventName, ...)
    local eventListeners = listeners[eventName]
    if not eventListeners then return end
    
    -- 使用深度计数器代替复制列表
    emitDepth = emitDepth + 1
    
    -- 固定遍历范围，新增的监听器不会被执行
    local count = #eventListeners
    for i = 1, count do
        local listener = eventListeners[i]
        -- 跳过已删除的监听器（callback 为 nil）
        if listener and listener.callback then
            local success, err = pcall(listener.callback, ...)
            if not success then
                print("[EventBus] Error in listener for '" .. eventName .. "': " .. tostring(err))
            end
        end
    end
    
    emitDepth = emitDepth - 1
    
    -- Emit 完成后处理延迟删除
    processPendingRemovals()
end

--- 检查是否有监听器
---@param eventName string 事件名称
---@return boolean
function EventBus.HasListeners(eventName)
    return listeners[eventName] ~= nil and #listeners[eventName] > 0
end

--- 获取监听器数量
---@param eventName string? 事件名称（可选，不传返回总数）
---@return number
function EventBus.GetListenerCount(eventName)
    if eventName then
        return listeners[eventName] and #listeners[eventName] or 0
    end
    
    local count = 0
    for _, eventListeners in pairs(listeners) do
        count = count + #eventListeners
    end
    return count
end

--- 清除指定事件的所有监听器
---@param eventName string 事件名称
function EventBus.Clear(eventName)
    listeners[eventName] = nil
end

--- 清除所有监听器
function EventBus.ClearAll()
    listeners = {}
    listenerIdCounter = 0
    emitDepth = 0
    pendingRemovals = {}
end

--- 获取调试信息
function EventBus.GetDebugInfo()
    local info = {}
    for eventName, eventListeners in pairs(listeners) do
        info[eventName] = #eventListeners
    end
    return info
end

return EventBus
