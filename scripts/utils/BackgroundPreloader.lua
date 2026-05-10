-- ============================================================================
-- BackgroundPreloader - 后台资源逐个预下载
-- 进入主菜单后启动，按优先级顺序逐个下载所有游戏图片资源
-- 与 ImageLoader / DialogueUI 安全网通过 cache:Exists() 自然去重，互不冲突
-- ============================================================================

local DialogueData = require("data.DialogueData")
local Ships = require("config.ships")
local Weapons = require("config.weapons")
local Modules = require("config.modules")
local LoadingOverlay = require("ui.LoadingOverlay")

local BackgroundPreloader = {}

local queue = {}        -- 有序路径列表
local queueIndex = 0    -- 当前下载位置
local active = false
local downloading = false
local paused = false    -- 前台正在下载时暂停
local hookRegistered = false  -- OnFinish 钩子是否已注册
local currentPath = ""  -- 当前正在下载的路径
local finished = false  -- 全部完成标记
local verbose = false   -- 调试输出开关，默认静默
local stats = { total = 0, completed = 0, skipped = 0, failed = 0 }

--- 仅在 verbose 模式下 print
local function dbg(msg)
    if verbose then print(msg) end
end

-- ============================================================================
-- 路径收集：从游戏数据模块动态收集所有图片路径（按优先级排序、全局去重）
-- ============================================================================
local function CollectAllPaths()
    local paths = {}
    local seen = {}

    local function add(path)
        if path and not seen[path] then
            seen[path] = true
            paths[#paths + 1] = path
        end
    end

    --- 从对话数据中提取图片路径
    local function addDialogue(dialogueId)
        local data = DialogueData.Get(dialogueId)
        if not data then return end
        for i = 1, #data do
            add(data[i].image)
        end
    end

    --- 添加舰长 gameover 图片（1-5）
    local function addGameOverImages(captain)
        for i = 1, 5 do
            add("image/" .. captain .. "/gameover/" .. i .. ".jpg")
        end
    end

    -- 优先级 1：开场教程对话（新玩家最先用到）
    addDialogue("Tutorial_Opening")

    -- 优先级 2：舰长头像（选船界面需要）
    for _, ship in pairs(Ships.List) do
        add(ship.captainPortrait)
    end

    -- 优先级 3：武器图标（选武器、商店、暂停菜单等多处需要）
    for id, _ in pairs(Weapons.List) do
        add("images/weapons/" .. id .. ".jpg")
    end

    -- 优先级 4：模块图标（商店、暂停菜单、开箱等多处需要）
    for _, m in ipairs(Modules.List) do
        if m.id then
            add("images/modules/" .. m.id .. ".jpg")
        end
    end

    -- 优先级 5：首次战败对话
    addDialogue("Tutorial_FirstDefeat")

    -- 优先级 6：默认舰长的战败图
    local defaultShip = Ships.GetDefault()
    if defaultShip then
        addGameOverImages(defaultShip.captain)
    end

    -- 优先级 7：其余所有对话（日常、事件等）
    local handledIds = { Tutorial_Opening = true, Tutorial_FirstDefeat = true }
    local allIds = DialogueData.GetAllIds()
    for _, id in ipairs(allIds) do
        if not handledIds[id] then
            addDialogue(id)
        end
    end

    -- 优先级末：非默认舰长的战败图
    local defaultCaptain = defaultShip and defaultShip.captain or ""
    for _, ship in pairs(Ships.List) do
        if ship.captain ~= defaultCaptain then
            addGameOverImages(ship.captain)
        end
    end

    -- 过滤：只保留构建引用中实际存在的可下载资源，避免下载不存在的路径报错
    local dm = GetDownloadManager()
    if dm then
        local valid = {}
        local filtered = 0
        for i = 1, #paths do
            if dm:CanResolve(paths[i]) then
                valid[#valid + 1] = paths[i]
            else
                filtered = filtered + 1
            end
        end
        if filtered > 0 then
            dbg(string.format("[BackgroundPreloader] 过滤了 %d 个不可下载的路径", filtered))
        end
        return valid
    end

    return paths
end

-- ============================================================================
-- 逐个下载引擎：一次只下载一个资源，下载完再取下一个
-- 前台 LoadingOverlay 活跃时自动暂停，结束后自动恢复
-- ============================================================================
local function DownloadNext()
    if not active or downloading then return end

    -- 前台正在加载 → 让路，暂停后台下载
    if LoadingOverlay.IsActive() then
        if not paused then
            paused = true
            dbg("[BackgroundPreloader] 前台加载中，暂停后台下载")
        end
        return
    end

    while queueIndex < #queue do
        queueIndex = queueIndex + 1
        local path = queue[queueIndex]
        local progress = queueIndex .. "/" .. #queue

        if cache:Exists(path) then
            -- 已在本地（被实时逻辑或之前的下载完成），跳过
            stats.skipped = stats.skipped + 1
            log:Write(LOG_DEBUG, "[BackgroundPreloader] [" .. progress .. "] 跳过(已缓存): " .. path)
        else
            -- 下载前再检查一次前台状态
            if LoadingOverlay.IsActive() then
                paused = true
                queueIndex = queueIndex - 1  -- 回退，下次恢复时重新处理
                dbg("[BackgroundPreloader] 前台加载中，暂停后台下载")
                return
            end

            -- 需要下载，启动异步下载
            currentPath = path
            downloading = true
            log:Write(LOG_DEBUG, "[BackgroundPreloader] [" .. progress .. "] 开始下载: " .. path)
            cache:GetResourceAsync("Texture2D", path, function(resource)
                downloading = false
                if resource then
                    stats.completed = stats.completed + 1
                    log:Write(LOG_DEBUG, "[BackgroundPreloader] [" .. progress .. "] 下载完成: " .. path)
                else
                    stats.failed = stats.failed + 1
                    log:Write(LOG_WARNING, "[BackgroundPreloader] [" .. progress .. "] 下载失败: " .. path)
                end
                currentPath = ""
                -- 继续下一个
                DownloadNext()
            end)
            return  -- 等待回调，不继续 while 循环
        end
    end

    -- 队列全部处理完毕
    active = false
    finished = true
    currentPath = ""
    local summary = string.format("[BackgroundPreloader] 全部完成: %d 总计, %d 下载, %d 跳过, %d 失败",
        stats.total, stats.completed, stats.skipped, stats.failed)
    dbg(summary)
    log:Write(LOG_DEBUG, summary)
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 开始后台预加载（幂等，重复调用无效）
function BackgroundPreloader.Start()
    if active then return end

    -- 注册 LoadingOverlay 完成钩子（只注册一次）
    if not hookRegistered then
        hookRegistered = true
        LoadingOverlay.OnFinish(function()
            BackgroundPreloader.Resume()
        end)
    end

    queue = CollectAllPaths()
    queueIndex = 0
    active = true
    downloading = false
    paused = false
    finished = false
    currentPath = ""
    stats = { total = #queue, completed = 0, skipped = 0, failed = 0 }

    local msg = string.format("[BackgroundPreloader] 启动: %d 个资源待预加载", #queue)
    dbg(msg)
    log:Write(LOG_DEBUG, msg)
    DownloadNext()
end

--- 前台加载结束后恢复后台下载
function BackgroundPreloader.Resume()
    if not active or not paused then return end
    paused = false
    dbg("[BackgroundPreloader] 前台加载结束，恢复后台下载")
    DownloadNext()
end

--- 是否正在运行
function BackgroundPreloader.IsActive()
    return active
end

--- 获取当前状态（供调试 UI 显示）
--- @return table { active, paused, finished, downloading, currentPath, processed, total, completed, skipped, failed }
function BackgroundPreloader.GetStats()
    return {
        active = active,
        paused = paused,
        finished = finished,
        downloading = downloading,
        currentPath = currentPath,
        processed = queueIndex,
        total = stats.total,
        completed = stats.completed,
        skipped = stats.skipped,
        failed = stats.failed,
    }
end

--- 设置调试输出开关
--- @param enabled boolean
function BackgroundPreloader.SetVerbose(enabled)
    verbose = enabled
    if enabled then
        print("[BackgroundPreloader] 调试输出已开启")
    end
end

--- 获取调试输出开关状态
function BackgroundPreloader.IsVerbose()
    return verbose
end

return BackgroundPreloader
