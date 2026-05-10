-- ============================================================================
-- 星河战姬 Starkyries - 用户设置管理器
-- ============================================================================
-- 用于保存用户偏好设置（如 HUD 状态），独立于游戏存档
-- 使用 clientScore 云存储（整数值：1=true, 0=false）
-- ============================================================================

local UserSettings = {}

-- 云变量键名映射
local CLOUD_KEYS = {
    hudWeaponListExpanded = "user_hud_weapon_list",  -- 1=展开, 0=收起
}

-- 默认设置
local defaultSettings = {
    hudWeaponListExpanded = true,  -- HUD 武器列表默认展开
}

-- 内部状态
local initialized = false
local cloudAvailable = false
local currentSettings = nil
local dirty = false

-- ============================================================================
-- 初始化
-- ============================================================================

function UserSettings.Init(callback)
    if initialized then
        if callback then callback(currentSettings) end
        return
    end
    
    -- 检查云存储是否可用
    cloudAvailable = (clientScore ~= nil)
    
    if not cloudAvailable then
        print("[UserSettings] Cloud not available, using defaults")
        currentSettings = UserSettings.CopyDefaults()
        initialized = true
        if callback then callback(currentSettings) end
        return
    end
    
    -- 从云端加载设置
    print("[UserSettings] Loading from cloud...")
    local keys = {}
    for _, cloudKey in pairs(CLOUD_KEYS) do
        table.insert(keys, cloudKey)
    end
    
    -- 批量获取所有设置
    local batchGet = clientScore:BatchGet()
    for _, cloudKey in pairs(CLOUD_KEYS) do
        batchGet:Key(cloudKey)
    end
    
    batchGet:Fetch({
        ok = function(scores, iscores, sscores)
            currentSettings = {}
            for settingKey, cloudKey in pairs(CLOUD_KEYS) do
                local value = iscores[cloudKey]
                if value ~= nil then
                    -- 整数转布尔：1=true, 0=false
                    currentSettings[settingKey] = (value == 1)
                else
                    -- 使用默认值
                    currentSettings[settingKey] = defaultSettings[settingKey]
                end
            end
            initialized = true
            dirty = false
            print("[UserSettings] Loaded from cloud: hudWeaponListExpanded=" .. tostring(currentSettings.hudWeaponListExpanded))
            if callback then callback(currentSettings) end
        end,
        error = function(code, reason)
            print("[UserSettings] Cloud load error: " .. tostring(reason))
            currentSettings = UserSettings.CopyDefaults()
            initialized = true
            if callback then callback(currentSettings) end
        end,
        timeout = function()
            print("[UserSettings] Cloud load timeout")
            currentSettings = UserSettings.CopyDefaults()
            initialized = true
            if callback then callback(currentSettings) end
        end
    })
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

function UserSettings.CopyDefaults()
    local copy = {}
    for k, v in pairs(defaultSettings) do
        copy[k] = v
    end
    return copy
end

-- ============================================================================
-- 获取/设置
-- ============================================================================

function UserSettings.Get(key)
    if not currentSettings then
        return defaultSettings[key]
    end
    return currentSettings[key]
end

function UserSettings.Set(key, value)
    if not currentSettings then
        currentSettings = UserSettings.CopyDefaults()
    end
    
    if currentSettings[key] ~= value then
        currentSettings[key] = value
        dirty = true
        print("[UserSettings] Set " .. key .. " = " .. tostring(value))
    end
end

-- ============================================================================
-- 保存
-- ============================================================================

function UserSettings.Save(callback)
    if not dirty then
        if callback then callback(true) end
        return
    end
    
    if not currentSettings then
        if callback then callback(false) end
        return
    end
    
    if not cloudAvailable then
        print("[UserSettings] Cloud not available, cannot save")
        dirty = false
        if callback then callback(false) end
        return
    end
    
    -- 保存到云端（布尔转整数：true=1, false=0）
    local batchSet = clientScore:BatchSet()
    for settingKey, cloudKey in pairs(CLOUD_KEYS) do
        local value = currentSettings[settingKey]
        local intValue = value and 1 or 0
        batchSet:SetInt(cloudKey, intValue)
    end
    
    batchSet:Save("用户设置", {
        ok = function()
            dirty = false
            print("[UserSettings] Saved to cloud")
            if callback then callback(true) end
        end,
        error = function(code, reason)
            print("[UserSettings] Cloud save error: " .. tostring(reason))
            if callback then callback(false) end
        end,
        timeout = function()
            print("[UserSettings] Cloud save timeout")
            if callback then callback(false) end
        end
    })
end

-- ============================================================================
-- 便捷方法
-- ============================================================================

function UserSettings.IsInitialized()
    return initialized
end

function UserSettings.IsDirty()
    return dirty
end

return UserSettings
