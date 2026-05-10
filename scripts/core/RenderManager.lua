-- ============================================================================
-- 星河战姬 Starkyries - 渲染管理器
-- 统一管理所有 NanoVG UI 渲染
-- ============================================================================

local RenderManager = {}

-- ============================================================================
-- 延迟加载依赖
-- ============================================================================
local UIStyle, HUD, ShopUI, Overlays, PauseUI, MainMenuUI, OptionsUI
local GalleryUI, ShipSelectUI, WeaponSelectUI, TestMenuUI, DialogueTestUI
local VirtualJoystick, DialogueUI, BridgeUpgrade, Game, Shop, Enemy, Effects
local CrateOpenUI, LoadingOverlay, BackgroundPreloader

local function LoadDependencies()
    if not UIStyle then
        UIStyle = require("ui.UIStyle")
        HUD = require("ui.HUD")
        ShopUI = require("ui.ShopUI")
        Overlays = require("ui.Overlays")
        PauseUI = require("ui.PauseUI")
        MainMenuUI = require("ui.MainMenuUI")
        OptionsUI = require("ui.OptionsUI")
        GalleryUI = require("ui.GalleryUI")
        ShipSelectUI = require("ui.ShipSelectUI")
        WeaponSelectUI = require("ui.WeaponSelectUI")
        TestMenuUI = require("ui.TestMenuUI")
        DialogueTestUI = require("ui.DialogueTestUI")
        VirtualJoystick = require("ui.VirtualJoystick")
        DialogueUI = require("ui.DialogueUI")
        BridgeUpgrade = require("core.BridgeUpgrade")
        Game = require("core.Game")
        Shop = require("core.Shop")
        Enemy = require("entities.Enemy")
        Effects = require("entities.Effects")
        CrateOpenUI = require("ui.CrateOpenUI")
        LoadingOverlay = require("ui.LoadingOverlay")
        BackgroundPreloader = require("utils.BackgroundPreloader")
    end
end

-- ============================================================================
-- 内部变量
-- ============================================================================
local nvg_ = nil
local cameraNode_ = nil
local inputHandler_ = nil

-- ============================================================================
-- 初始化
-- ============================================================================

---@param nvg userdata NanoVG 上下文
---@param cameraNode userdata 相机节点
---@param inputHandler table InputHandler 模块引用
function RenderManager.Init(nvg, cameraNode, inputHandler)
    LoadDependencies()
    nvg_ = nvg
    cameraNode_ = cameraNode
    inputHandler_ = inputHandler
end

-- ============================================================================
-- 主渲染函数
-- ============================================================================

function RenderManager.Render()
    if not nvg_ then return end
    
    local graphics = GetGraphics()
    local sw = graphics:GetWidth()
    local sh = graphics:GetHeight()
    
    nvgBeginFrame(nvg_, sw, sh, 1.0)
    UIStyle.BeginFrame()  -- 重置 NvgHelper 状态缓存
    
    local baseUnit = math.min(sw, sh) / 40
    local fontSize = {
        title = baseUnit * 1.6,
        large = baseUnit * 1.0,
        medium = baseUnit * 0.8,
        small = baseUnit * 0.6,
    }
    
    nvgFontFace(nvg_, "sans")
    
    -- 加载遮罩显示期间，绘制遮罩后立即结束帧（遮罩上不叠加调试信息）
    if LoadingOverlay and LoadingOverlay.IsActive() then
        LoadingOverlay.Render(nvg_, sw, sh)
        nvgEndFrame(nvg_)
        return
    end
    
    -- 教程/剧情对话界面（最高优先级）
    if DialogueUI.IsVisible() then
        DialogueUI.Render(nvg_, sw, sh)
    elseif inputHandler_.mainMenuActive then
        RenderManager.RenderMainMenu(sw, sh)
    elseif inputHandler_.shipSelectActive then
        ShipSelectUI.Render(nvg_, sw, sh)
    elseif inputHandler_.weaponSelectActive then
        WeaponSelectUI.Render(nvg_, sw, sh)
    else
        -- 游戏状态渲染
        RenderManager.RenderGameState(sw, sh, baseUnit, fontSize)
    end
    
    -- 调试：后台下载状态指示器（叠加在所有界面上）
    RenderManager.RenderDownloadStatus(sw, sh)
    
    nvgEndFrame(nvg_)
end

-- ============================================================================
-- 主菜单渲染
-- ============================================================================

function RenderManager.RenderMainMenu(sw, sh)
    MainMenuUI.Render(nvg_, sw, sh)
    
    -- 选项界面（覆盖在主菜单上）
    if inputHandler_.optionsActive then
        OptionsUI.Render(nvg_, sw, sh)
    end
    
    -- 图鉴界面（覆盖在主菜单上）
    if inputHandler_.galleryActive then
        GalleryUI.Render(nvg_, sw, sh)
    end
    
    -- 测试菜单（覆盖在主菜单上）
    if TestMenuUI.IsVisible() then
        TestMenuUI.Render(nvg_, sw, sh)
    end
    
    -- 对话测试UI（覆盖在所有UI上）
    if DialogueTestUI.IsVisible() then
        DialogueTestUI.Render(nvg_, sw, sh)
    end
end

-- ============================================================================
-- 游戏状态渲染
-- ============================================================================

function RenderManager.RenderGameState(sw, sh, baseUnit, fontSize)
    local bridgeState = BridgeUpgrade.GetState()
    
    if Game.currentState == Game.States.PLAYING then
        HUD.Render(nvg_, sw, sh, baseUnit, fontSize, Game.player, Game.battle, bridgeState)
        if not bridgeState.active then
            VirtualJoystick.Render(nvg_, sw, sh)
        end
    elseif Game.currentState == Game.States.SHOP then
        ShopUI.Render(nvg_, sw, sh, baseUnit, fontSize, Shop, Game.player)
        ShopUI.RenderDebugPanel(nvg_, sw, sh, Shop, Game.player)
    elseif Game.currentState == Game.States.GAME_OVER then
        Overlays.RenderGameOver(nvg_, sw, sh, baseUnit, fontSize, Game.battle)
    elseif Game.currentState == Game.States.VICTORY then
        Overlays.RenderVictory(nvg_, sw, sh, baseUnit, fontSize, Game.battle, Game.player)
    elseif Game.currentState == Game.States.CRATE_OPEN then
        CrateOpenUI.Render(nvg_, sw, sh, baseUnit, fontSize, Game.player)
    end
    
    -- 舰桥升级弹窗
    if bridgeState.active then
        Overlays.RenderBridgeUpgrade(nvg_, sw, sh, baseUnit, fontSize, bridgeState, Game.player, BridgeUpgrade.GetRefreshCost())
    end
    
    -- 伤害数字
    if cameraNode_ then
        local camera = cameraNode_:GetComponent("Camera")
        Overlays.RenderDamageNumbers(nvg_, sw, sh, baseUnit, fontSize, Effects.GetDamageNumbers(), camera)
    end
    
    -- 波次公告
    Overlays.RenderWaveAnnouncement(nvg_, sw, sh, baseUnit, fontSize)
    Overlays.RenderBossPhaseAnnouncement(nvg_, sw, sh, baseUnit, fontSize)
    
    -- 超空间跳跃效果
    Overlays.RenderHyperspaceMessage(nvg_, sw, sh, baseUnit, fontSize)
    
    -- 暂停菜单（覆盖在游戏界面上）
    if PauseUI.IsVisible() then
        PauseUI.Render(nvg_, sw, sh, baseUnit, fontSize, Game.player, Game.battle, Enemy.GetList())
        
        -- 选项界面（覆盖在暂停菜单上）
        if inputHandler_.optionsActive then
            OptionsUI.Render(nvg_, sw, sh)
        end
        
        -- 图鉴界面（覆盖在暂停菜单上）
        if inputHandler_.galleryActive then
            GalleryUI.Render(nvg_, sw, sh)
        end
    end
end

-- ============================================================================
-- 后台下载状态指示器（右下角半透明小面板）
-- ============================================================================

function RenderManager.RenderDownloadStatus(sw, sh)
    if not BackgroundPreloader then return end

    -- verbose 关闭时不渲染面板
    if not BackgroundPreloader.IsVerbose() then return end

    local s = BackgroundPreloader.GetStats()

    -- 未启动过且未完成 → 不显示
    if not s.active and not s.finished then return end

    local nvg = nvg_
    local fs = math.max(11, math.min(sw, sh) * 0.016)  -- 字号
    local pad = fs * 0.6
    local lineH = fs * 1.35

    -- 状态文字
    local statusLabel
    if s.finished then
        statusLabel = "预加载完成"
    elseif s.paused then
        statusLabel = "预加载暂停(前台优先)"
    elseif s.downloading then
        statusLabel = "预加载中..."
    else
        statusLabel = "预加载等待"
    end

    local progressText = string.format("%d/%d  下载:%d 跳过:%d 失败:%d",
        s.processed, s.total, s.completed, s.skipped, s.failed)

    -- 当前文件名（截短显示）
    local fileText = ""
    if s.currentPath ~= "" then
        local name = s.currentPath
        if #name > 30 then
            name = "..." .. name:sub(-27)
        end
        fileText = name
    end

    -- 计算面板尺寸
    local lines = 2
    if fileText ~= "" then lines = 3 end
    local panelH = pad * 2 + lineH * lines
    local panelW = math.max(sw * 0.22, 200)
    local panelX = sw - panelW - pad * 2
    local panelY = sh - panelH - pad * 2

    -- 半透明背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, panelX, panelY, panelW, panelH, 6)
    nvgFillColor(nvg, nvgRGBA(8, 12, 24, 180))
    nvgFill(nvg)

    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, panelX, panelY, panelW, panelH, 6)
    nvgStrokeColor(nvg, nvgRGBA(60, 180, 255, s.finished and 60 or 120))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 文字
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, fs)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

    local tx = panelX + pad
    local ty = panelY + pad

    -- 第 1 行：状态
    local statusColor = s.finished and nvgRGBA(80, 200, 120, 220)
        or s.paused and nvgRGBA(255, 180, 60, 220)
        or nvgRGBA(100, 210, 255, 220)
    nvgFillColor(nvg, statusColor)
    nvgText(nvg, tx, ty, statusLabel)
    ty = ty + lineH

    -- 第 2 行：进度数字
    nvgFillColor(nvg, nvgRGBA(180, 190, 200, 200))
    nvgText(nvg, tx, ty, progressText)
    ty = ty + lineH

    -- 第 3 行：当前文件（如果有）
    if fileText ~= "" then
        nvgFillColor(nvg, nvgRGBA(120, 130, 140, 180))
        nvgFontSize(nvg, fs * 0.85)
        nvgText(nvg, tx, ty, fileText)
    end

    -- 进度条
    local barH = 3
    local barY = panelY + panelH - barH
    local progress = s.total > 0 and s.processed / s.total or 0

    nvgBeginPath(nvg)
    nvgRect(nvg, panelX, barY, panelW, barH)
    nvgFillColor(nvg, nvgRGBA(30, 40, 60, 200))
    nvgFill(nvg)

    if progress > 0 then
        nvgBeginPath(nvg)
        nvgRect(nvg, panelX, barY, panelW * progress, barH)
        nvgFillColor(nvg, s.finished and nvgRGBA(80, 200, 120, 200) or nvgRGBA(60, 180, 255, 200))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 获取 NanoVG 上下文
-- ============================================================================

function RenderManager.GetNvg()
    return nvg_
end

return RenderManager
