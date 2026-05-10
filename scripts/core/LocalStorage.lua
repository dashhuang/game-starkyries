-- ============================================================================
-- 星河战姬 Starkyries - 本地存储模块
-- 提供本地持久化存储，作为云存储的备用方案
-- ============================================================================

local LocalStorage = {}

-- 存储文件名
LocalStorage.SAVE_FILE = "starkyries_save.json"
LocalStorage.TUTORIAL_FILE = "starkyries_tutorial.json"

-- 内部状态
local fileSystemAvailable = false
local savePath = ""
local cachedData = {}  -- 内存缓存

-- ============================================================================
-- 初始化
-- ============================================================================

function LocalStorage.Init()
    -- UrhoX 沙箱自动按"项目+用户"隔离存档目录，脚本只需使用相对路径
    local fs = fileSystem or GetFileSystem()
    if not fs then
        print("[LocalStorage] FileSystem not available")
        return false
    end

    savePath = ""  -- 相对路径，引擎自动路由到沙箱目录
    fileSystemAvailable = true
    print("[LocalStorage] Initialized (sandboxed storage)")
    return true
end

-- ============================================================================
-- 检查是否可用
-- ============================================================================

function LocalStorage.IsAvailable()
    return fileSystemAvailable
end

-- ============================================================================
-- 保存数据
-- ============================================================================

function LocalStorage.Save(key, data)
    -- 更新内存缓存
    cachedData[key] = data
    
    if not fileSystemAvailable then
        print("[LocalStorage] File system unavailable, data cached in memory only")
        return false
    end
    
    -- 序列化为 JSON
    local jsonStr = LocalStorage.Encode(data)
    if not jsonStr then
        print("[LocalStorage] Failed to encode data")
        return false
    end
    
    -- 写入文件
    local filePath = savePath .. key
    local file = File:new()
    
    if file:Open(filePath, FILE_WRITE) then
        file:WriteString(jsonStr)
        file:Close()
        print("[LocalStorage] Saved: " .. key)
        return true
    else
        print("[LocalStorage] Failed to open file for writing: " .. filePath)
        return false
    end
end

-- ============================================================================
-- 加载数据
-- ============================================================================

function LocalStorage.Load(key, defaultValue)
    -- 先检查内存缓存
    if cachedData[key] ~= nil then
        return cachedData[key]
    end
    
    if not fileSystemAvailable then
        return defaultValue
    end
    
    local filePath = savePath .. key
    local fs = fileSystem or GetFileSystem()
    
    if not fs:FileExists(filePath) then
        return defaultValue
    end
    
    local file = File:new()
    if file:Open(filePath, FILE_READ) then
        local content = ""
        while not file:IsEof() do
            local line = file:ReadLine()
            content = content .. line
        end
        file:Close()
        
        local data = LocalStorage.Decode(content)
        if data then
            cachedData[key] = data
            print("[LocalStorage] Loaded: " .. key)
            return data
        end
    end
    
    return defaultValue
end

-- ============================================================================
-- 删除数据
-- ============================================================================

function LocalStorage.Delete(key)
    cachedData[key] = nil
    
    if not fileSystemAvailable then
        return true
    end
    
    local filePath = savePath .. key
    local fs = fileSystem or GetFileSystem()
    
    if fs:FileExists(filePath) then
        return fs:Delete(filePath)
    end
    
    return true
end

-- ============================================================================
-- JSON 编码/解码（简单实现）
-- ============================================================================

function LocalStorage.Encode(data)
    if type(data) ~= "table" then
        return tostring(data)
    end
    
    local parts = {}
    local isArray = (#data > 0)
    
    for k, v in pairs(data) do
        local key = isArray and "" or ('"' .. tostring(k) .. '":')
        local value
        
        if type(v) == "string" then
            value = '"' .. v:gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
        elseif type(v) == "number" then
            value = tostring(v)
        elseif type(v) == "boolean" then
            value = v and "true" or "false"
        elseif type(v) == "table" then
            value = LocalStorage.Encode(v)
        else
            value = "null"
        end
        
        table.insert(parts, key .. value)
    end
    
    if isArray then
        return "[" .. table.concat(parts, ",") .. "]"
    else
        return "{" .. table.concat(parts, ",") .. "}"
    end
end

function LocalStorage.Decode(str)
    if not str or str == "" then
        return nil
    end
    
    -- 使用 UrhoX 的 JSONFile 解析
    local jsonFile = JSONFile:new()
    if jsonFile:FromString(str) then
        local root = jsonFile:GetRoot()
        return LocalStorage.JSONValueToLua(root)
    end
    
    return nil
end

function LocalStorage.JSONValueToLua(jsonValue)
    if jsonValue:IsNull() then
        return nil
    elseif jsonValue:IsBool() then
        return jsonValue:GetBool()
    elseif jsonValue:IsNumber() then
        return jsonValue:GetDouble()
    elseif jsonValue:IsString() then
        return jsonValue:GetString()
    elseif jsonValue:IsArray() then
        local arr = {}
        local size = jsonValue:Size()
        for i = 0, size - 1 do
            arr[i + 1] = LocalStorage.JSONValueToLua(jsonValue[i])
        end
        return arr
    elseif jsonValue:IsObject() then
        local obj = {}
        local jsonObj = jsonValue:GetObject()
        -- 注意：UrhoX 的 JSONObject 遍历方式可能不同
        -- 这里简化处理，实际可能需要调整
        return obj
    end
    return nil
end

-- ============================================================================
-- 便捷方法：保存/加载游戏存档
-- ============================================================================

function LocalStorage.SaveGame(saveData)
    return LocalStorage.Save(LocalStorage.SAVE_FILE, saveData)
end

function LocalStorage.LoadGame()
    return LocalStorage.Load(LocalStorage.SAVE_FILE, nil)
end

-- ============================================================================
-- 便捷方法：保存/加载教程进度
-- ============================================================================

function LocalStorage.SaveTutorial(tutorialData)
    return LocalStorage.Save(LocalStorage.TUTORIAL_FILE, tutorialData)
end

function LocalStorage.LoadTutorial()
    return LocalStorage.Load(LocalStorage.TUTORIAL_FILE, {
        openingCompleted = false,
        firstDefeatCompleted = false
    })
end

return LocalStorage
