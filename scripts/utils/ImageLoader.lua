-- ============================================================================
-- ImageLoader - DWP-safe NanoVG 图片加载工具
-- 确保图片资源已下载到本地后才创建 NanoVG 图片，避免 DWP 占位符闪烁
-- ============================================================================

local ImageLoader = {}

--- DWP-safe nvgCreateImage：仅在资源已下载到本地时才创建 NVG 图片。
--- 资源未就绪时自动触发异步下载，下载完成后下一帧重试。
--- @param nvg userdata NanoVG 上下文
--- @param path string 资源路径
--- @param imageCache table 缓存表 {[key] = imageHandle}
--- @param cacheKey string|nil 缓存键，默认为 path
--- @return number|nil >0=可用图片句柄, -1=加载失败, -2=下载中
function ImageLoader.GetImage(nvg, path, imageCache, cacheKey)
    cacheKey = cacheKey or path

    local cached = imageCache[cacheKey]
    if cached then
        return cached
    end

    -- 资源已在本地 → 安全创建 NVG 图片
    if cache:Exists(path) then
        local img = nvgCreateImage(nvg, path, 0)
        imageCache[cacheKey] = (img and img > 0) and img or -1
        return imageCache[cacheKey]
    end

    -- 资源不在本地 → 触发异步下载，标记为"下载中"
    imageCache[cacheKey] = -2
    cache:GetResourceAsync("Texture2D", path, function(resource)
        if resource then
            -- 下载完成，清除缓存标记，下一帧渲染时重新走 cache:Exists → nvgCreateImage
            imageCache[cacheKey] = nil
        else
            imageCache[cacheKey] = -1
        end
    end)

    return -2
end

--- 预下载一组图片资源，全部就绪后回调
--- @param paths string[] 资源路径列表
--- @param onComplete function 全部就绪后回调
function ImageLoader.Preload(paths, onComplete)
    if not paths or #paths == 0 then
        if onComplete then onComplete() end
        return
    end

    local total = #paths
    local completed = 0

    local function onOneReady()
        completed = completed + 1
        if completed >= total and onComplete then
            onComplete()
        end
    end

    for _, path in ipairs(paths) do
        if cache:Exists(path) then
            onOneReady()
        else
            cache:GetResourceAsync("Texture2D", path, function(resource)
                onOneReady()
            end)
        end
    end
end

--- 预下载一组图片资源（带进度回调），全部就绪后回调
--- @param paths string[] 资源路径列表
--- @param onComplete function 全部就绪后回调
--- @param onProgress function|nil 每完成一张回调 onProgress(completed, total)
function ImageLoader.Preload2(paths, onComplete, onProgress)
    if not paths or #paths == 0 then
        if onProgress then onProgress(0, 0) end
        if onComplete then onComplete() end
        return
    end

    local total = #paths
    local completed = 0

    local function onOneReady()
        completed = completed + 1
        if onProgress then onProgress(completed, total) end
        if completed >= total and onComplete then
            onComplete()
        end
    end

    for _, path in ipairs(paths) do
        if cache:Exists(path) then
            onOneReady()
        else
            cache:GetResourceAsync("Texture2D", path, function(resource)
                onOneReady()
            end)
        end
    end
end

--- 统一预加载门控：检查缓存 → 全部已缓存直接回调，否则显示 Loading 再回调
--- @param paths string[] 资源路径列表
--- @param onReady function 全部就绪后回调
--- @param statusText string|nil Loading 显示文字，默认 "正在加载资源..."
function ImageLoader.PreloadGate(paths, onReady, statusText)
    local LoadingOverlay = require("ui.LoadingOverlay")

    -- 过滤：只保留未缓存的路径
    local needed = {}
    if paths then
        for _, path in ipairs(paths) do
            if not cache:Exists(path) then
                needed[#needed + 1] = path
            end
        end
    end

    -- 快速路径：全部已缓存
    if #needed == 0 then
        if onReady then onReady() end
        return
    end

    -- 慢速路径：显示 Loading，手动模式
    local text = statusText or "正在加载资源..."
    LoadingOverlay.Show(onReady, text, true)  -- manualComplete=true
    ImageLoader.Preload2(needed, function()
        LoadingOverlay.Complete()
    end, function(completed, total)
        LoadingOverlay.SetProgress(completed, total)
    end)
end

--- 统一骨架屏占位效果（脉冲呼吸 + 从左到右扫光）
--- 适用于所有图片加载中的区域，与圆角矩形裁剪配合使用
--- @param nvg userdata NanoVG 上下文
--- @param x number 左上角 X
--- @param y number 左上角 Y
--- @param w number 宽度
--- @param h number 高度
--- @param animTime number 动画时间（秒）
--- @param cornerRadius number|nil 圆角半径，默认 0
function ImageLoader.RenderPlaceholder(nvg, x, y, w, h, animTime, cornerRadius)
    animTime = animTime or 0
    local r = cornerRadius or 0

    -- 底色
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, r)
    nvgFillColor(nvg, nvgRGBA(20, 25, 35, 200))
    nvgFill(nvg)

    -- 脉冲呼吸
    local pulse = 0.12 + 0.08 * math.sin(animTime * 2.5)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, r)
    nvgFillColor(nvg, nvgRGBA(120, 140, 170, math.floor(pulse * 255)))
    nvgFill(nvg)

    -- 从左到右扫光
    nvgSave(nvg)
    nvgScissor(nvg, x, y, w, h)
    local sweepCycle = (animTime * 0.6) % 1.0
    local sweepX = x - w * 0.3 + (w * 1.6) * sweepCycle
    local sweepW = w * 0.3
    local cy = y + h / 2
    local sweepGrad = nvgLinearGradient(nvg, sweepX, cy, sweepX + sweepW, cy,
        nvgRGBA(255, 255, 255, 0),
        nvgRGBA(255, 255, 255, 35))
    nvgBeginPath(nvg)
    nvgRect(nvg, sweepX, y, sweepW, h)
    nvgFillPaint(nvg, sweepGrad)
    nvgFill(nvg)
    local sweepGrad2 = nvgLinearGradient(nvg, sweepX + sweepW, cy, sweepX + sweepW * 2, cy,
        nvgRGBA(255, 255, 255, 35),
        nvgRGBA(255, 255, 255, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sweepX + sweepW, y, sweepW, h)
    nvgFillPaint(nvg, sweepGrad2)
    nvgFill(nvg)
    nvgRestore(nvg)
end

return ImageLoader
