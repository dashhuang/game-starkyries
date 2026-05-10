--[[
    FrameCache - 通用帧缓存工具
    
    用于缓存同一帧内重复计算的结果，避免每帧多次创建相同的表/计算相同的值。
    
    使用场景：
    - Layout 计算（GetTypography, GetUpgradeLayout, GetHUDLayout 等）
    - UISafeArea.Calculate
    - 任何同一帧内被多次调用但结果相同的函数
    
    用法：
    local FrameCache = require("utils.FrameCache")
    
    -- 方式1：简单键值缓存
    local layout = FrameCache:Get("myLayout", sw, sh, function(sw, sh)
        return { ... }  -- 只在缓存失效时执行
    end)
    
    -- 方式2：带参数的缓存（参数会拼入键）
    local typo = FrameCache:GetWithKey("typography", sw .. "x" .. sh, function()
        return { ... }
    end)
]]

local FrameCache = {
    cache = {},
    currentFrame = -1,
}

-- 获取当前帧号（引擎全局变量）
local function GetCurrentFrame()
    if time then
        return time:GetFrameNumber()
    end
    return 0
end

--- 检查并清理过期缓存（新帧时自动清空）
function FrameCache:_checkFrame()
    local frame = GetCurrentFrame()
    if frame ~= self.currentFrame then
        -- 新的一帧，清空所有缓存
        self.cache = {}
        self.currentFrame = frame
    end
end

--- 获取缓存值，如果不存在则通过 calculator 计算并缓存
---@param key string 缓存键
---@param ... any 传递给 calculator 的参数，最后一个参数必须是 calculator 函数
---@return any 缓存的值或新计算的值
function FrameCache:Get(key, ...)
    self:_checkFrame()
    
    if self.cache[key] ~= nil then
        return self.cache[key]
    end
    
    -- 最后一个参数是 calculator 函数
    local args = {...}
    local calculator = args[#args]
    
    if type(calculator) ~= "function" then
        error("FrameCache:Get() - 最后一个参数必须是 calculator 函数")
    end
    
    -- 移除 calculator，剩余的是传递给它的参数
    args[#args] = nil
    
    local result = calculator(table.unpack(args))
    self.cache[key] = result
    return result
end

--- 使用复合键获取缓存值
---@param prefix string 键前缀
---@param suffix string 键后缀（通常是参数组合，如 "1920x1080"）
---@param calculator function 计算函数（无参数）
---@return any 缓存的值或新计算的值
function FrameCache:GetWithKey(prefix, suffix, calculator)
    self:_checkFrame()
    
    local key = prefix .. "_" .. suffix
    
    if self.cache[key] ~= nil then
        return self.cache[key]
    end
    
    local result = calculator()
    self.cache[key] = result
    return result
end

--- 手动设置缓存值（用于外部计算后缓存）
---@param key string 缓存键
---@param value any 要缓存的值
function FrameCache:Set(key, value)
    self:_checkFrame()
    self.cache[key] = value
end

--- 手动使缓存失效（强制下次重新计算）
---@param key string|nil 缓存键，nil 表示清空所有
function FrameCache:Invalidate(key)
    if key then
        self.cache[key] = nil
    else
        self.cache = {}
    end
end

--- 获取缓存统计信息（调试用）
---@return table 包含缓存键数量的统计信息
function FrameCache:GetStats()
    local count = 0
    for _ in pairs(self.cache) do
        count = count + 1
    end
    return {
        frame = self.currentFrame,
        entryCount = count,
    }
end

return FrameCache
