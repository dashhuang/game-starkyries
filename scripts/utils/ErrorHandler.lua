-- ============================================================================
-- 星河战姬 Starkyries - 错误处理工具模块
-- ============================================================================
-- 
-- 职责：提供统一的错误处理、日志记录和安全调用功能
-- 
-- 功能：
--   - 分级日志：Debug/Info/Warn/Error
--   - 安全调用：SafeCall (pcall封装，带错误日志)
--   - 资源验证：ValidateResource, ValidateModule
--   - 错误限流：同类错误最大记录次数限制
-- 
-- 用法：
--   ErrorHandler.Info("ModuleName", "信息消息")
--   ErrorHandler.Error("ModuleName", "错误消息")
--   local success, result = ErrorHandler.SafeCall(func, "Module", "Operation", args...)
--   ErrorHandler.ValidateResource(resource, "Texture2D", "player.png")
-- 
-- ============================================================================

---@class ErrorHandler
local ErrorHandler = {}

-- ============================================================================
-- 配置
-- ============================================================================
local config = {
    logLevel = "INFO",  -- DEBUG, INFO, WARN, ERROR
    enableStackTrace = true,
    maxErrorsPerType = 10,  -- 同类错误最大记录次数（防止刷屏）
}

-- ============================================================================
-- 内部变量
-- ============================================================================
local errorCounts = {}  -- 错误计数器
local logLevels = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }

-- ============================================================================
-- 日志函数
-- ============================================================================

local function shouldLog(level)
    return logLevels[level] >= logLevels[config.logLevel]
end

local function formatMessage(level, module, message)
    return string.format("[%s][%s] %s", level, module, message)
end

function ErrorHandler.Debug(module, message)
    if shouldLog("DEBUG") then
        print(formatMessage("DEBUG", module, message))
    end
end

function ErrorHandler.Info(module, message)
    if shouldLog("INFO") then
        print(formatMessage("INFO", module, message))
    end
end

function ErrorHandler.Warn(module, message)
    if shouldLog("WARN") then
        print(formatMessage("WARN", module, message))
    end
end

function ErrorHandler.Error(module, message)
    if shouldLog("ERROR") then
        local errorKey = module .. ":" .. message:sub(1, 50)
        errorCounts[errorKey] = (errorCounts[errorKey] or 0) + 1
        
        if errorCounts[errorKey] <= config.maxErrorsPerType then
            print(formatMessage("ERROR", module, message))
            if config.enableStackTrace then
                print(debug.traceback("Stack trace:", 2))
            end
        elseif errorCounts[errorKey] == config.maxErrorsPerType + 1 then
            print(formatMessage("ERROR", module, "...后续相同错误已省略"))
        end
    end
end

-- ============================================================================
-- 安全调用包装器
-- ============================================================================

---@param func function 要执行的函数
---@param module string 模块名称
---@param operation string 操作描述
---@param ... any 函数参数
---@return boolean success 是否成功
---@return any result 结果或错误信息
function ErrorHandler.SafeCall(func, module, operation, ...)
    local args = {...}
    local success, result = pcall(function()
        return func(table.unpack(args))
    end)
    
    if not success then
        ErrorHandler.Error(module, operation .. " 失败: " .. tostring(result))
        return false, result
    end
    
    return true, result
end

---@param func function 要执行的函数
---@param module string 模块名称
---@param operation string 操作描述
---@param default any 失败时的默认值
---@param ... any 函数参数
---@return any result 结果或默认值
function ErrorHandler.SafeCallWithDefault(func, module, operation, default, ...)
    local success, result = ErrorHandler.SafeCall(func, module, operation, ...)
    if success then
        return result
    else
        return default
    end
end

-- ============================================================================
-- 资源加载包装器
-- ============================================================================

---@param cache userdata 资源缓存
---@param resourceType string 资源类型
---@param resourcePath string 资源路径
---@param silent boolean 是否静默失败
---@return userdata|nil resource 资源或nil
function ErrorHandler.LoadResource(cache, resourceType, resourcePath, silent)
    if not cache then
        if not silent then
            ErrorHandler.Error("ResourceLoader", "cache 为 nil")
        end
        return nil
    end
    
    local resource = cache:GetResource(resourceType, resourcePath)
    
    if not resource then
        if not silent then
            ErrorHandler.Warn("ResourceLoader", 
                string.format("资源加载失败: %s (%s)", resourcePath, resourceType))
        end
        return nil
    end
    
    return resource
end

-- ============================================================================
-- 模块加载包装器
-- ============================================================================

---@param modulePath string 模块路径
---@param silent boolean 是否静默失败
---@return table|nil module 模块或nil
function ErrorHandler.RequireModule(modulePath, silent)
    local success, result = pcall(require, modulePath)
    
    if not success then
        if not silent then
            ErrorHandler.Error("ModuleLoader", 
                string.format("模块加载失败: %s - %s", modulePath, tostring(result)))
        end
        return nil
    end
    
    return result
end

-- ============================================================================
-- 断言和验证
-- ============================================================================

---@param condition boolean 条件
---@param module string 模块名称
---@param message string 错误信息
---@return boolean valid 条件是否为真
function ErrorHandler.Assert(condition, module, message)
    if not condition then
        ErrorHandler.Error(module, "断言失败: " .. message)
        return false
    end
    return true
end

---@param value any 要验证的值
---@param module string 模块名称
---@param valueName string 值名称
---@return boolean valid 值是否有效
function ErrorHandler.ValidateNotNil(value, module, valueName)
    if value == nil then
        ErrorHandler.Error(module, valueName .. " 不能为 nil")
        return false
    end
    return true
end

---@param value number 要验证的数字
---@param module string 模块名称
---@param valueName string 值名称
---@param min number 最小值
---@param max number 最大值
---@return boolean valid 值是否在范围内
function ErrorHandler.ValidateRange(value, module, valueName, min, max)
    if type(value) ~= "number" then
        ErrorHandler.Error(module, valueName .. " 必须是数字")
        return false
    end
    
    if value < min or value > max then
        ErrorHandler.Warn(module, 
            string.format("%s 超出范围 [%s, %s]: %s", valueName, min, max, value))
        return false
    end
    
    return true
end

-- ============================================================================
-- 配置
-- ============================================================================

function ErrorHandler.SetLogLevel(level)
    if logLevels[level] then
        config.logLevel = level
    end
end

function ErrorHandler.EnableStackTrace(enabled)
    config.enableStackTrace = enabled
end

function ErrorHandler.ResetErrorCounts()
    errorCounts = {}
end

return ErrorHandler
