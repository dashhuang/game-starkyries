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
local CrateOpenUI, LoadingOverlay

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
    
    -- 加载遮罩显示期间，绘制遮罩后立即结束帧
    if LoadingOverlay and LoadingOverlay.IsActive() then
        LoadingOverlay.Render(nvg_, sw, sh)
        nvgEndFrame(nvg_)
        return
    end
    
    -- 教程/剧情对话界面（最高优先级）
    if DialogueUI.IsVisible() then
        DialogueUI.Render(nvg_, sw, sh)
        nvgEndFrame(nvg_)
        return
    end
    
    -- 主菜单界面
    if inputHandler_.mainMenuActive then
        RenderManager.RenderMainMenu(sw, sh)
        nvgEndFrame(nvg_)
        return
    end
    
    -- 战舰选择界面
    if inputHandler_.shipSelectActive then
        ShipSelectUI.Render(nvg_, sw, sh)
        nvgEndFrame(nvg_)
        return
    end
    
    -- 武器选择界面
    if inputHandler_.weaponSelectActive then
        WeaponSelectUI.Render(nvg_, sw, sh)
        nvgEndFrame(nvg_)
        return
    end
    
    -- 游戏状态渲染
    RenderManager.RenderGameState(sw, sh, baseUnit, fontSize)
    
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
-- 获取 NanoVG 上下文
-- ============================================================================

function RenderManager.GetNvg()
    return nvg_
end

return RenderManager
