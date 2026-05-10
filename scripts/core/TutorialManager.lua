-- ============================================================================
-- 星河战姬 Starkyries - 教程/引导管理器
-- 管理新手引导进度和剧情对话触发
-- ============================================================================

local TutorialManager = {}

-- 云变量 key
TutorialManager.TUTORIAL_KEY = "tutorial_progress"

-- 教程进度状态
TutorialManager.Progress = {
    openingCompleted = false,      -- 开场对话完成
    firstDefeatCompleted = false,  -- 首次战败对话完成
}

-- 内部状态
local initialized = false
local cloudAvailable = false

-- 引用 SaveManager 的云存档开关
local SaveManager = require "core.SaveManager"
local LocalStorage = require "core.LocalStorage"

-- ============================================================================
-- 初始化
-- ============================================================================

function TutorialManager.Init(callback)
    if initialized then
        if callback then callback() end
        return
    end
    
    -- 检查云存储是否可用（使用 SaveManager 的统一开关）
    cloudAvailable = SaveManager.CLOUD_ENABLED and (clientScore ~= nil)
    
    if not cloudAvailable then
        print("[TutorialManager] Cloud disabled, trying local storage...")
        -- 尝试从本地文件加载
        local localData = LocalStorage.LoadTutorial()
        if localData then
            TutorialManager.Progress.openingCompleted = localData.openingCompleted or false
            TutorialManager.Progress.firstDefeatCompleted = localData.firstDefeatCompleted or false
            print("[TutorialManager] Loaded from local: opening=" .. tostring(TutorialManager.Progress.openingCompleted) ..
                  ", firstDefeat=" .. tostring(TutorialManager.Progress.firstDefeatCompleted))
        end
        initialized = true
        if callback then callback() end
        return
    end
    
    -- 从云端加载教程进度
    print("[TutorialManager] Loading tutorial progress...")
    clientScore:Get(TutorialManager.TUTORIAL_KEY, {
        ok = function(scores, iscores, sscores)
            -- 使用 iscores 获取整数值
            local progressValue = iscores[TutorialManager.TUTORIAL_KEY]
            if progressValue and progressValue > 0 then
                -- 解析位掩码：bit0=opening, bit1=firstDefeat
                TutorialManager.Progress.openingCompleted = (progressValue & 1) ~= 0
                TutorialManager.Progress.firstDefeatCompleted = (progressValue & 2) ~= 0
                print("[TutorialManager] Loaded: value=" .. progressValue .. 
                      ", opening=" .. tostring(TutorialManager.Progress.openingCompleted) ..
                      ", firstDefeat=" .. tostring(TutorialManager.Progress.firstDefeatCompleted))
            else
                print("[TutorialManager] No progress found, starting fresh")
            end
            initialized = true
            if callback then callback() end
        end,
        error = function(code, reason)
            print("[TutorialManager] Load error: " .. tostring(reason))
            initialized = true
            if callback then callback() end
        end,
        timeout = function()
            print("[TutorialManager] Load timeout")
            initialized = true
            if callback then callback() end
        end
    })
end

-- ============================================================================
-- 保存进度到云端
-- ============================================================================

function TutorialManager.Save()
    -- 如果云禁用，保存到本地文件
    if not cloudAvailable then
        LocalStorage.SaveTutorial(TutorialManager.Progress)
        print("[TutorialManager] Saved to local storage")
        return
    end
    
    -- 使用位掩码存储进度：bit0=opening, bit1=firstDefeat
    local progressValue = 0
    if TutorialManager.Progress.openingCompleted then
        progressValue = progressValue + 1  -- bit 0
    end
    if TutorialManager.Progress.firstDefeatCompleted then
        progressValue = progressValue + 2  -- bit 1
    end
    
    clientScore:BatchSet()
        :SetInt(TutorialManager.TUTORIAL_KEY, progressValue)
        :Save("教程进度", {
            ok = function()
                print("[TutorialManager] Progress saved: " .. progressValue)
            end,
            error = function(code, reason)
                print("[TutorialManager] Save error: " .. tostring(reason))
            end
        })
end

-- ============================================================================
-- 查询接口
-- ============================================================================

-- 是否需要播放开场对话（第一次进入游戏）
function TutorialManager.NeedsOpeningDialogue()
    return not TutorialManager.Progress.openingCompleted
end

-- 是否需要播放首次战败对话
function TutorialManager.NeedsFirstDefeatDialogue()
    return not TutorialManager.Progress.firstDefeatCompleted
end

-- 是否是全新玩家（没有完成任何教程）
function TutorialManager.IsNewPlayer()
    return not TutorialManager.Progress.openingCompleted
end

-- ============================================================================
-- 标记完成
-- ============================================================================

-- 标记开场对话完成
function TutorialManager.CompleteOpening()
    TutorialManager.Progress.openingCompleted = true
    TutorialManager.Save()
    print("[TutorialManager] Opening dialogue completed")
end

-- 标记首次战败对话完成
function TutorialManager.CompleteFirstDefeat()
    TutorialManager.Progress.firstDefeatCompleted = true
    TutorialManager.Save()
    print("[TutorialManager] First defeat dialogue completed")
end

-- ============================================================================
-- 重置（用于测试）
-- ============================================================================

function TutorialManager.Reset()
    TutorialManager.Progress.openingCompleted = false
    TutorialManager.Progress.firstDefeatCompleted = false
    -- 删除本地文件
    LocalStorage.Delete(LocalStorage.TUTORIAL_FILE)
    TutorialManager.Save()
    print("[TutorialManager] Progress reset")
end

return TutorialManager
