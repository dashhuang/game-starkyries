-- ============================================================================
-- LoadingOverlay - DWP 资源下载等待遮罩
-- 在场景切换时调用 Show(onReady)，自动观察后台下载并展示进度
-- ============================================================================

local LoadingOverlay = {}

local nvg_ = nil
local active_ = false
local progress_ = 0          -- 0..1
local completed_ = 0
local total_ = 0
local bytes_ = 0
local minDisplayTime_ = 0.3   -- 最少展示秒数，避免一闪而过
local elapsed_ = 0            -- 累计经过时间（用引擎 dt 计时，避免 os.clock 兼容问题）
local onReadyCallback_ = nil
local statusText_ = "正在加载资源..."
local pendingFinish_ = false  -- 下载已完成，等最短时间过后结束
local finishHooks_ = {}       -- 外部注册的完成钩子（每次结束时全部调用）

-- ============================================================================
-- 初始化（在 main.lua 中调用一次，传入 NanoVG 上下文）
-- ============================================================================
function LoadingOverlay.Init(nvg)
    nvg_ = nvg
    -- 不单独订阅 Update（全局 SubscribeToEvent 同事件只能有一个处理函数）
    -- 由 main.lua 的 HandleUpdate 调用 LoadingOverlay.Update(dt)
end

-- ============================================================================
-- 是否正在显示
-- ============================================================================
function LoadingOverlay.IsActive()
    return active_
end

-- ============================================================================
-- 入参 onReady：下载结束后回调（即使没有任何下载也会回调）
-- 入参 statusText：可选，显示文字
-- 入参 manualComplete：可选，true 时不自动观察下载，由调用方手动调用 Complete()
-- ============================================================================
function LoadingOverlay.Show(onReady, statusText, manualComplete)
    if active_ then
        -- 已在显示，叠加回调
        local prev = onReadyCallback_
        onReadyCallback_ = function()
            if prev then prev() end
            if onReady then onReady() end
        end
        return
    end

    active_ = true
    progress_ = 0
    completed_ = 0
    total_ = 0
    bytes_ = 0
    elapsed_ = 0
    onReadyCallback_ = onReady
    statusText_ = statusText or "正在加载资源..."
    pendingFinish_ = false

    log:Write(LOG_INFO, "[LoadingOverlay] Show() called, statusText=" .. statusText_ .. ", manual=" .. tostring(manualComplete or false))

    if not manualComplete then
        -- 自动模式：启动 DWP 观察
        cache:ObserveDownloads(
            function(completed, total, downloadedBytes)
                completed_ = completed or 0
                total_ = total or 0
                bytes_ = downloadedBytes or 0
                if total_ > 0 then
                    progress_ = completed_ / total_
                end
            end,
            function(downloadedBytes)
                log:Write(LOG_INFO, "[LoadingOverlay] ObserveDownloads onComplete fired")
                bytes_ = downloadedBytes or bytes_
                progress_ = 1
                LoadingOverlay._tryFinish()
            end
        )
    end
    -- 手动模式：等待调用方调用 Complete() 或 SetProgress()
end

-- ============================================================================
-- 手动模式接口
-- ============================================================================

---手动更新进度（manualComplete 模式下使用）
function LoadingOverlay.SetProgress(completed, total)
    completed_ = completed or 0
    total_ = total or 0
    if total_ > 0 then
        progress_ = completed_ / total_
    end
end

---手动标记完成（manualComplete 模式下使用）
function LoadingOverlay.Complete()
    if not active_ then return end
    progress_ = 1
    LoadingOverlay._tryFinish()
end

-- ============================================================================
-- 内部：尝试结束（可能因 minDisplayTime 延后）
-- ============================================================================
function LoadingOverlay._tryFinish()
    if not active_ then return end
    pendingFinish_ = true
    log:Write(LOG_INFO, "[LoadingOverlay] _tryFinish → pendingFinish set, elapsed=" .. string.format("%.3f", elapsed_))
    -- 实际结束在 LoadingOverlay_OnUpdate 中根据时间判断
end

function LoadingOverlay._finishNow()
    log:Write(LOG_INFO, "[LoadingOverlay] _finishNow() → calling onReadyCallback, elapsed=" .. string.format("%.3f", elapsed_))
    active_ = false
    pendingFinish_ = false
    local cb = onReadyCallback_
    onReadyCallback_ = nil
    if cb then
        local ok, err = pcall(cb)
        if not ok then
            log:Write(LOG_ERROR, "[LoadingOverlay] onReadyCallback ERROR: " .. tostring(err))
        end
    end
    -- 通知所有外部完成钩子（如 BackgroundPreloader.Resume）
    for i = 1, #finishHooks_ do
        local hok, herr = pcall(finishHooks_[i])
        if not hok then
            log:Write(LOG_ERROR, "[LoadingOverlay] finishHook[" .. i .. "] ERROR: " .. tostring(herr))
        end
    end
end

-- ============================================================================
-- 外部钩子：注册一个每次 LoadingOverlay 结束时都会调用的回调
-- ============================================================================
function LoadingOverlay.OnFinish(callback)
    if type(callback) == "function" then
        finishHooks_[#finishHooks_ + 1] = callback
    end
end

-- ============================================================================
-- Update 处理：由 main.lua HandleUpdate 每帧调用
-- ============================================================================
function LoadingOverlay.Update(dt)
    if not active_ then return end
    elapsed_ = elapsed_ + dt
    if pendingFinish_ and elapsed_ >= minDisplayTime_ then
        LoadingOverlay._finishNow()
    end
end

-- ============================================================================
-- 渲染遮罩（由 RenderManager 在 nvgBeginFrame / nvgEndFrame 之间调用）
-- ============================================================================
function LoadingOverlay.Render(nvg, sw, sh)
    if not active_ then return end

    -- 半透明全屏遮罩
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(5, 8, 18, 230))
    nvgFill(nvg)

    -- 标题文字
    nvgFontFace(nvg, "sans")
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    local titleSize = math.max(20, sh * 0.035)
    nvgFontSize(nvg, titleSize)
    nvgFillColor(nvg, nvgRGBA(180, 220, 255, 255))
    nvgText(nvg, sw * 0.5, sh * 0.45, statusText_)

    -- 进度条
    local barW = sw * 0.4
    local barH = math.max(6, sh * 0.012)
    local barX = (sw - barW) * 0.5
    local barY = sh * 0.52

    -- 进度条底
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX, barY, barW, barH, barH * 0.5)
    nvgFillColor(nvg, nvgRGBA(40, 50, 70, 255))
    nvgFill(nvg)

    -- 进度条填充
    if progress_ > 0 then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, barY, barW * progress_, barH, barH * 0.5)
        nvgFillColor(nvg, nvgRGBA(100, 200, 255, 255))
        nvgFill(nvg)
    end

    -- 数字进度
    local infoSize = math.max(12, sh * 0.018)
    nvgFontSize(nvg, infoSize)
    nvgFillColor(nvg, nvgRGBA(150, 180, 210, 200))

    local infoText
    if total_ > 0 then
        if bytes_ > 0 then
            local kb = math.floor(bytes_ / 1024)
            infoText = string.format("%d / %d  (%d KB)", completed_, total_, kb)
        else
            infoText = string.format("%d / %d", completed_, total_)
        end
    else
        infoText = "准备中..."
    end
    nvgText(nvg, sw * 0.5, barY + barH + sh * 0.025, infoText)
end

return LoadingOverlay
