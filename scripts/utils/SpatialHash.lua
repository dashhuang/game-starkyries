-- ============================================================================
-- 星河战姬 Starkyries - 空间哈希分区系统
-- ============================================================================
-- 用于优化范围查询，将 O(n) 降低到 O(1) 平均复杂度
-- 🔴 性能优化版本：数值键、配置缓存、预分配表
-- ============================================================================

local Settings = require("config.settings")

local SpatialHash = {}
SpatialHash.__index = SpatialHash

-- 默认单元格大小（应大于典型查询范围）
local DEFAULT_CELL_SIZE = 10.0

-- 🔴 性能优化：缓存配置值（避免每次查询都读取配置）
local EDGE_COMPENSATION = Settings.Combat.EdgeDistanceCompensation
local MAX_ENEMY_RADIUS = Settings.Combat.MaxEnemyRadius

-- 🔴 性能优化：数值键编码常量（支持 -50000 到 +50000 的坐标范围）
local CELL_KEY_OFFSET = 100000
local CELL_KEY_MULTIPLIER = 200001  -- 必须大于 2 * CELL_KEY_OFFSET

-- ============================================================================
-- 构造函数
-- ============================================================================

---@param cellSize number? 单元格大小，默认10
---@return table SpatialHash实例
function SpatialHash.New(cellSize)
    local self = setmetatable({}, SpatialHash)
    self.cellSize = cellSize or DEFAULT_CELL_SIZE
    self.cells = {}  -- key: numericKey -> value: {entity1, entity2, ...}
    self.entityCells = {}  -- entity -> numericKey (用于快速移除/更新)
    
    -- 🔴 性能优化：预分配复用表
    self._queryResults = {}  -- QueryRange 结果复用
    self._excludeSet = {}    -- 排除集合复用
    
    return self
end

-- ============================================================================
-- 内部方法
-- ============================================================================

-- 🔴 性能优化：计算数值键（避免字符串拼接）
function SpatialHash:_getCellKey(x, y)
    local cellX = math.floor(x / self.cellSize)
    local cellY = math.floor(y / self.cellSize)
    -- 使用数值编码替代字符串键
    return (cellX + CELL_KEY_OFFSET) * CELL_KEY_MULTIPLIER + (cellY + CELL_KEY_OFFSET)
end

-- 获取单元格坐标
function SpatialHash:_getCellCoords(x, y)
    return math.floor(x / self.cellSize), math.floor(y / self.cellSize)
end

-- 获取或创建单元格
function SpatialHash:_getOrCreateCell(key)
    if not self.cells[key] then
        self.cells[key] = {}
    end
    return self.cells[key]
end

-- ============================================================================
-- 公共方法
-- ============================================================================

--- 插入实体到空间哈希
---@param entity table 实体对象
---@param x number X坐标
---@param y number Y坐标
function SpatialHash:Insert(entity, x, y)
    local key = self:_getCellKey(x, y)
    local cell = self:_getOrCreateCell(key)
    
    -- 添加到单元格
    cell[#cell + 1] = entity
    
    -- 记录实体所在单元格
    self.entityCells[entity] = key
end

--- 从空间哈希移除实体
---@param entity table 实体对象
function SpatialHash:Remove(entity)
    local key = self.entityCells[entity]
    if not key then return end
    
    local cell = self.cells[key]
    if cell then
        -- 🔴 性能优化：使用交换删除（O(1)）替代 table.remove（O(n)）
        for i = 1, #cell do
            if cell[i] == entity then
                -- 用最后一个元素替换当前位置
                cell[i] = cell[#cell]
                cell[#cell] = nil
                break
            end
        end
        -- 清理空单元格
        if #cell == 0 then
            self.cells[key] = nil
        end
    end
    
    self.entityCells[entity] = nil
end

--- 更新实体位置
---@param entity table 实体对象
---@param x number 新X坐标
---@param y number 新Y坐标
function SpatialHash:Update(entity, x, y)
    local oldKey = self.entityCells[entity]
    local newKey = self:_getCellKey(x, y)
    
    -- 如果单元格没变，不需要更新
    if oldKey == newKey then return end
    
    -- 从旧单元格移除
    if oldKey then
        local oldCell = self.cells[oldKey]
        if oldCell then
            -- 🔴 性能优化：使用交换删除
            for i = 1, #oldCell do
                if oldCell[i] == entity then
                    oldCell[i] = oldCell[#oldCell]
                    oldCell[#oldCell] = nil
                    break
                end
            end
            if #oldCell == 0 then
                self.cells[oldKey] = nil
            end
        end
    end
    
    -- 添加到新单元格
    local newCell = self:_getOrCreateCell(newKey)
    newCell[#newCell + 1] = entity
    self.entityCells[entity] = newKey
end

--- 查询范围内的实体
--- ⚠️ 注意：返回的表是复用的，下次调用会覆盖内容，如需保留请复制
---@param x number 查询中心X
---@param y number 查询中心Y
---@param range number 查询范围
---@param excludeList table? 排除列表
---@return table 范围内的实体列表 {enemy, dist}
function SpatialHash:QueryRange(x, y, range, excludeList)
    -- 🔴 性能优化：复用结果表
    local results = self._queryResults
    for i = #results, 1, -1 do
        results[i] = nil
    end
    
    -- 🔴 性能优化：复用排除集合
    local excludeSet = self._excludeSet
    for k in pairs(excludeSet) do
        excludeSet[k] = nil
    end
    
    if excludeList then
        for i = 1, #excludeList do
            excludeSet[excludeList[i]] = true
        end
    end
    
    -- 计算需要检查的单元格范围（扩大搜索范围以考虑大型敌人）
    local searchRange = range + MAX_ENEMY_RADIUS
    local minCellX = math.floor((x - searchRange) / self.cellSize)
    local maxCellX = math.floor((x + searchRange) / self.cellSize)
    local minCellY = math.floor((y - searchRange) / self.cellSize)
    local maxCellY = math.floor((y + searchRange) / self.cellSize)
    
    -- 遍历相关单元格
    for cellX = minCellX, maxCellX do
        for cellY = minCellY, maxCellY do
            -- 🔴 性能优化：直接计算数值键
            local key = (cellX + CELL_KEY_OFFSET) * CELL_KEY_MULTIPLIER + (cellY + CELL_KEY_OFFSET)
            local cell = self.cells[key]
            
            if cell then
                for i = 1, #cell do
                    local entity = cell[i]
                    if not excludeSet[entity] then
                        -- 获取实体位置
                        local pos = entity.node and entity.node.position
                        if pos then
                            local dx = pos.x - x
                            local dy = pos.y - y
                            local centerDist = math.sqrt(dx * dx + dy * dy)
                            
                            -- 考虑敌人半径：使用配置的边缘距离补偿系数
                            local entityRadius = (entity.hitRadius or entity.scale or 0) * EDGE_COMPENSATION
                            local edgeDist = centerDist - entityRadius
                            
                            if edgeDist <= range then
                                results[#results + 1] = {
                                    enemy = entity,
                                    dist = edgeDist  -- 返回补偿后的距离
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    
    return results
end

--- 查询最近的实体
---@param x number 查询中心X
---@param y number 查询中心Y
---@param maxRange number 最大范围
---@return table|nil 最近实体
---@return number 距离
function SpatialHash:QueryNearest(x, y, maxRange)
    local nearest = nil
    local nearestEdgeDist = maxRange
    
    -- 计算需要检查的单元格范围（扩大搜索范围以考虑大型敌人）
    local searchRange = maxRange + MAX_ENEMY_RADIUS
    local minCellX = math.floor((x - searchRange) / self.cellSize)
    local maxCellX = math.floor((x + searchRange) / self.cellSize)
    local minCellY = math.floor((y - searchRange) / self.cellSize)
    local maxCellY = math.floor((y + searchRange) / self.cellSize)
    
    -- 遍历相关单元格
    for cellX = minCellX, maxCellX do
        for cellY = minCellY, maxCellY do
            -- 🔴 性能优化：直接计算数值键
            local key = (cellX + CELL_KEY_OFFSET) * CELL_KEY_MULTIPLIER + (cellY + CELL_KEY_OFFSET)
            local cell = self.cells[key]
            
            if cell then
                for i = 1, #cell do
                    local entity = cell[i]
                    local pos = entity.node and entity.node.position
                    if pos then
                        local dx = pos.x - x
                        local dy = pos.y - y
                        local centerDist = math.sqrt(dx * dx + dy * dy)
                        
                        -- 考虑敌人半径：使用配置的边缘距离补偿系数
                        local entityRadius = (entity.hitRadius or entity.scale or 0) * EDGE_COMPENSATION
                        local edgeDist = centerDist - entityRadius
                        
                        if edgeDist < nearestEdgeDist then
                            nearestEdgeDist = edgeDist
                            nearest = entity
                        end
                    end
                end
            end
        end
    end
    
    if nearest then
        return nearest, nearestEdgeDist
    end
    return nil, maxRange
end

--- 清空所有数据
function SpatialHash:Clear()
    self.cells = {}
    self.entityCells = {}
end

--- 获取实体数量
function SpatialHash:GetCount()
    local count = 0
    for _ in pairs(self.entityCells) do
        count = count + 1
    end
    return count
end

--- 调试：获取统计信息
function SpatialHash:GetStats()
    local cellCount = 0
    local maxPerCell = 0
    local totalEntities = 0
    
    for _, cell in pairs(self.cells) do
        cellCount = cellCount + 1
        local n = #cell
        totalEntities = totalEntities + n
        if n > maxPerCell then
            maxPerCell = n
        end
    end
    
    return {
        cellCount = cellCount,
        totalEntities = totalEntities,
        maxPerCell = maxPerCell,
        avgPerCell = cellCount > 0 and (totalEntities / cellCount) or 0
    }
end

return SpatialHash
