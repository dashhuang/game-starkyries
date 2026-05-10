-- ============================================================================
-- 星河战姬 Starkyries - 通用对象池系统
-- ============================================================================
-- 用于减少对象创建/销毁开销，复用场景节点和组件
-- ============================================================================

local ObjectPool = {}
ObjectPool.__index = ObjectPool

-- ============================================================================
-- 构造函数
-- ============================================================================

--- 创建对象池
--- options.maxSize: 池最大容量（默认100）
--- options.createFunc: 创建新对象的函数 function(scene) -> object
--- options.resetFunc: 重置对象的函数 function(object)
--- options.destroyFunc: 销毁对象的函数 function(object)
---@param options table 配置选项
---@return table ObjectPool实例
function ObjectPool.New(options)
    local self = setmetatable({}, ObjectPool)
    
    self.maxSize = options.maxSize or 100
    self.createFunc = options.createFunc
    self.resetFunc = options.resetFunc
    self.destroyFunc = options.destroyFunc
    
    self.pool = {}           -- 可用对象池
    self.activeCount = 0     -- 活跃对象数量
    self.totalCreated = 0    -- 总创建数量（统计用）
    self.reuseCount = 0      -- 复用次数（统计用）
    
    return self
end

-- ============================================================================
-- 公共方法
-- ============================================================================

--- 从池中获取对象
---@param scene table 场景对象
---@return table 对象
function ObjectPool:Acquire(scene)
    local obj
    
    if #self.pool > 0 then
        -- 从池中取出
        obj = table.remove(self.pool)
        self.reuseCount = self.reuseCount + 1
        
        -- 启用节点
        if obj.node then
            obj.node:SetEnabled(true)
        end
    else
        -- 创建新对象
        if self.createFunc then
            obj = self.createFunc(scene)
            self.totalCreated = self.totalCreated + 1
        else
            obj = {}
        end
    end
    
    self.activeCount = self.activeCount + 1
    return obj
end

--- 归还对象到池
---@param obj table 要归还的对象
function ObjectPool:Release(obj)
    if not obj then return end
    
    self.activeCount = self.activeCount - 1
    
    -- 池已满，销毁对象
    if #self.pool >= self.maxSize then
        if self.destroyFunc then
            self.destroyFunc(obj)
        elseif obj.node then
            obj.node:Remove()
        end
        return
    end
    
    -- 重置对象状态
    if self.resetFunc then
        self.resetFunc(obj)
    end
    
    -- 禁用节点（不从场景移除）
    if obj.node then
        obj.node:SetEnabled(false)
    end
    
    -- 放入池中
    table.insert(self.pool, obj)
end

--- 清空池（销毁所有对象）
function ObjectPool:Clear()
    for _, obj in ipairs(self.pool) do
        if self.destroyFunc then
            self.destroyFunc(obj)
        elseif obj.node then
            obj.node:Remove()
        end
    end
    
    self.pool = {}
    self.activeCount = 0
end

--- 预热池（预先创建对象）
---@param scene table 场景对象
---@param count number 预创建数量
function ObjectPool:Warmup(scene, count)
    for i = 1, count do
        if #self.pool >= self.maxSize then
            break
        end
        
        if self.createFunc then
            local obj = self.createFunc(scene)
            self.totalCreated = self.totalCreated + 1
            
            -- 禁用并放入池
            if obj.node then
                obj.node:SetEnabled(false)
            end
            table.insert(self.pool, obj)
        end
    end
end

--- 获取统计信息
function ObjectPool:GetStats()
    return {
        poolSize = #self.pool,
        activeCount = self.activeCount,
        totalCreated = self.totalCreated,
        reuseCount = self.reuseCount,
        reuseRate = self.totalCreated > 0 and (self.reuseCount / (self.totalCreated + self.reuseCount)) or 0
    }
end

-- ============================================================================
-- 简单节点池（用于纯视觉效果）
-- ============================================================================

local NodePool = {}
NodePool.__index = NodePool

---@param scene table 场景对象
---@param modelPath string 模型路径
---@param maxSize number 最大容量
---@return table NodePool实例
function NodePool.New(scene, modelPath, maxSize)
    local self = setmetatable({}, NodePool)
    
    self.scene = scene
    self.modelPath = modelPath
    self.maxSize = maxSize or 50
    self.pool = {}
    
    return self
end

--- 获取节点
---@return Node 场景节点
function NodePool:Acquire()
    local node
    
    if #self.pool > 0 then
        node = table.remove(self.pool)
        node:SetEnabled(true)
    else
        node = self.scene:CreateChild("PooledNode")
        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", self.modelPath))
    end
    
    return node
end

--- 归还节点
---@param node Node 场景节点
function NodePool:Release(node)
    if not node then return end
    
    if #self.pool >= self.maxSize then
        node:Remove()
        return
    end
    
    node:SetEnabled(false)
    table.insert(self.pool, node)
end

--- 清空池
function NodePool:Clear()
    for _, node in ipairs(self.pool) do
        node:Remove()
    end
    self.pool = {}
end

-- ============================================================================
-- 导出
-- ============================================================================

return {
    ObjectPool = ObjectPool,
    NodePool = NodePool,
}
