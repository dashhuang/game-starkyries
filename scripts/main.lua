-- ============================================================================
-- 星河战姬 Starkyries - 主入口
-- 模块化架构版本 v3.0
-- ============================================================================

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- 加载模块
-- ============================================================================

-- 配置
local Settings = require("config.settings")
local Ships = require("config.ships")
local Weapons = require("config.weapons")
local Modules = require("config.modules")
local Enemies = require("config.enemies")
local Waves = require("config.waves")

-- 工具
local Math = require("utils.Math")
local TouchInput = require("utils.TouchInput")

-- 渲染
local Materials = require("render.Materials")
local Background = require("render.Background")

-- 核心系统
local Game = require("core.Game")
local Battle = require("core.Battle")
local Shop = require("core.Shop")
local Audio = require("core.Audio")
local GameLoop = require("core.GameLoop")
local CameraController = require("core.CameraController")
local InputHandler = require("core.InputHandler")
local BridgeUpgrade = require("core.BridgeUpgrade")
local SaveManager = require("core.SaveManager")
local TutorialManager = require("core.TutorialManager")
local UserSettings = require("core.UserSettings")
local Callbacks = require("core.Callbacks")

-- 新模块
local GameStateManager = require("core.GameStateManager")
local RenderManager = require("core.RenderManager")
local TestMode = require("test.TestMode")

-- AI
local AutoBattle = require("ai.AutoBattle")

-- 实体
local Player = require("entities.Player")
local Enemy = require("entities.Enemy")
local Projectile = require("entities.Projectile")
local Pickup = require("entities.Pickup")
local Effects = require("entities.Effects")
local Drone = require("entities.Drone")

-- UI
local UIStyle = require("ui.UIStyle")
local UIScreen = require("ui.UIScreen")
local HUD = require("ui.HUD")
local ShopUI = require("ui.ShopUI")
local Overlays = require("ui.Overlays")
local PauseUI = require("ui.PauseUI")
local MainMenuUI = require("ui.MainMenuUI")
local OptionsUI = require("ui.OptionsUI")
local GalleryUI = require("ui.GalleryUI")
local ShipSelectUI = require("ui.ShipSelectUI")
local WeaponSelectUI = require("ui.WeaponSelectUI")
local TestMenuUI = require("ui.TestMenuUI")
local DialogueTestUI = require("ui.DialogueTestUI")
local VirtualJoystick = require("ui.VirtualJoystick")
local DialogueUI = require("ui.DialogueUI")
local CrateOpenUI = require("ui.CrateOpenUI")
local LoadingOverlay = require("ui.LoadingOverlay")

-- 数据
local DialogueData = require("data.DialogueData")

-- ============================================================================
-- 全局变量
-- ============================================================================
local scene_ = nil
local cameraNode_ = nil
local nvg = nil

-- ============================================================================
-- 场景创建
-- ============================================================================

local function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")
    
    -- 创建太空光照环境
    local zoneNode = scene_:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-1000.0, 1000.0)
    zone.ambientColor = Color(0.08, 0.10, 0.15)
    zone.fogColor = Color(0.005, 0.008, 0.02)
    zone.fogStart = 200.0
    zone.fogEnd = 500.0
    
    -- 主光源
    local sunNode = scene_:CreateChild("MainLight")
    sunNode.direction = Vector3(0.5, -0.7, 0.5)
    local sun = sunNode:CreateComponent("Light")
    sun.lightType = LIGHT_DIRECTIONAL
    sun.color = Color(1.0, 0.95, 0.9)
    sun.brightness = 0.8
    sun.specularIntensity = 0.8
    
    -- 辅助光源
    local fillNode = scene_:CreateChild("FillLight")
    fillNode.direction = Vector3(-0.3, 0.5, 0.2)
    local fill = fillNode:CreateComponent("Light")
    fill.lightType = LIGHT_DIRECTIONAL
    fill.color = Color(0.3, 0.4, 0.6)
    fill.brightness = 0.2
    
    -- 创建相机
    local camConfig = Settings.Camera
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 0, -30)
    
    local camera = cameraNode_:CreateComponent("Camera")
    camera.fov = camConfig.FOV
    camera.nearClip = camConfig.NearClip
    camera.farClip = camConfig.FarClip
    
    renderer:SetViewport(0, Viewport:new(scene_, camera))
    
    CameraController.Init(scene_, cameraNode_)
    
    return scene_
end

-- ============================================================================
-- 设置回调（供模块使用）
-- ============================================================================

local function SetupCallbacks()
    Callbacks.Setup({
        scene = scene_,
        Settings = Settings,
        Weapons = Weapons,
        Modules = Modules,
        Enemies = Enemies,
        Game = Game,
        Battle = Battle,
        Shop = Shop,
        BridgeUpgrade = BridgeUpgrade,
        SaveManager = SaveManager,
        Player = Player,
        Enemy = Enemy,
        Projectile = Projectile,
        Pickup = Pickup,
        Effects = Effects,
        Drone = Drone,
        Overlays = Overlays,
        ShipSelectUI = ShipSelectUI,
        WeaponSelectUI = WeaponSelectUI,
        MainMenuUI = MainMenuUI,
        Audio = Audio,
        CameraController = CameraController,
        InputHandler = InputHandler,
        Math = Math,
        TutorialManager = TutorialManager,
        
        -- 使用 GameStateManager 的函数
        StartHyperspaceExit = function(waveNum)
            GameStateManager.StartHyperspaceExit(waveNum)
        end,
        StartTutorialFirstDefeat = function()
            GameStateManager.StartTutorialFirstDefeat()
        end,
        StartGameWithShip = function(ship, weaponId)
            GameStateManager.StartGameWithShip(ship, weaponId)
        end,
        ExitShop = function()
            GameStateManager.ExitShop()
        end,
        RestartGame = function()
            GameStateManager.RestartGame(InitGame)
        end,
        SelectBridgeUpgrade = function(index)
            GameStateManager.SelectBridgeUpgrade(index)
        end,
    })
end

-- ============================================================================
-- 应用战舰特殊加成
-- ============================================================================

local function ApplyShipBonuses(shipConfig)
    local p = Game.player
    
    if shipConfig.shield then
        p.maxShield = shipConfig.shield
        p.shield = shipConfig.shield
    end
    if shipConfig.armor then p.armor = shipConfig.armor end
    if shipConfig.moveSpeed then p.moveSpeed = shipConfig.moveSpeed end
    if shipConfig.energyAbsorb then p.energyAbsorb = shipConfig.energyAbsorb end
    if shipConfig.dodgeCap then p.dodgeCap = shipConfig.dodgeCap end
    
    if shipConfig.special then
        local s = shipConfig.special
        if s.fireRateBonus then
            p.fireRateMultiplier = p.fireRateMultiplier + s.fireRateBonus
        end
        if s.damageBonus then
            p.damageMultiplier = p.damageMultiplier + s.damageBonus
        end
        if s.crystalBonus then
            p.crystalMultiplier = p.crystalMultiplier + s.crystalBonus
        end
        if s.berserkerMode then
            p.hasBerserkerMode = true
            p.berserkerFireRatePerLoss = s.fireRatePerShieldLoss or 0.005
        end
        if s.weaponDamagePenaltyPerSlot then
            p.weaponDamagePenaltyPerSlot = s.weaponDamagePenaltyPerSlot
        end
    end
    
    if shipConfig.maxWeaponSlots then
        p.maxWeaponSlots = shipConfig.maxWeaponSlots
    end
    
    p.shipConfig = shipConfig
end

-- ============================================================================
-- 初始化游戏
-- ============================================================================

function InitGame()
    Background.Create(scene_)
    InputHandler.Init()
    
    -- 设置 UI 导航回调（在游戏开始前就需要）
    InputHandler.onBackToMainMenu = function()
        print("[Main] onBackToMainMenu triggered")
        InputHandler.SetShipSelectActive(false)
        InputHandler.SetWeaponSelectActive(false)
        ShipSelectUI.Hide()
        WeaponSelectUI.Hide()
        GameStateManager.ShowMainMenu()
    end
    
    InputHandler.onBackToShipSelect = function()
        print("[Main] onBackToShipSelect triggered")
        InputHandler.SetWeaponSelectActive(false)
        InputHandler.SetShipSelectActive(true)
        WeaponSelectUI.Hide()
        ShipSelectUI.Show(function(ship)
            InputHandler.SetShipSelectActive(false)
            InputHandler.SetWeaponSelectActive(true)
            InputHandler.SetSelectedShipConfig(ship)
            WeaponSelectUI.Show(ship, function(weapon)
                InputHandler.SetWeaponSelectActive(false)
                LoadingOverlay.Show(function()
                    GameStateManager.StartGameWithShip(ship, weapon.id)
                end, "战舰整备中...")
            end)
        end)
    end
    
    -- StatsManager 延迟加载
    local StatsManager = require("core.StatsManager")
    
    TutorialManager.Init(function()
        -- 初始化统计管理器
        StatsManager.Init(function(statsData)
            print("[Main] StatsManager initialized, games played: " .. (statsData and statsData.totalGamesPlayed or 0))
        end)
        
        -- 初始化用户设置（HUD 状态等）
        UserSettings.Init(function(settings)
            print("[Main] UserSettings initialized")
            -- 初始化 HUD（加载武器列表展开状态）
            HUD.Init()
        end)
        
        SaveManager.Init(function(hasSaveData)
            MainMenuUI.Show({
                hasSaveData = hasSaveData,
                onStartGame = function()
                    if SaveManager.HasSave() then
                        SaveManager.Delete()
                    end
                    
                    if TutorialManager.NeedsOpeningDialogue() then
                        InputHandler.SetMainMenuActive(false)
                        MainMenuUI.Hide()
                        LoadingOverlay.Show(function()
                            GameStateManager.StartTutorialOpening()
                        end, "正在初始化战姬系统...")
                        return
                    end
                    
                    InputHandler.SetMainMenuActive(false)
                    InputHandler.SetShipSelectActive(true)
                    MainMenuUI.Hide()
                    
                    ShipSelectUI.Show(function(ship)
                        InputHandler.SetShipSelectActive(false)
                        InputHandler.SetWeaponSelectActive(true)
                        InputHandler.SetSelectedShipConfig(ship)
                        
                        WeaponSelectUI.Show(ship, function(weapon)
                            InputHandler.SetWeaponSelectActive(false)
                            LoadingOverlay.Show(function()
                                GameStateManager.StartGameWithShip(ship, weapon.id)
                            end, "战舰整备中...")
                        end)
                    end)
                end,
                onContinue = function()
                    LoadingOverlay.Show(function()
                        GameStateManager.ContinueFromSave()
                    end, "正在恢复存档...")
                end,
                onOptions = function()
                    InputHandler.SetOptionsActive(true)
                    OptionsUI.Show(function()
                        InputHandler.SetOptionsActive(false)
                    end)
                end,
                onGallery = function()
                    InputHandler.SetGalleryActive(true)
                    GalleryUI.Show(function()
                        InputHandler.SetGalleryActive(false)
                    end)
                end,
                onTest = function()
                    print("[Main] onTest callback triggered!")
                    TestMenuUI.Show()
                end,
            })
        end)
    end)
end

-- ============================================================================
-- 主循环
-- ============================================================================

function Start()
    math.randomseed(os.time())
    
    nvg = nvgCreate(1)
    nvgCreateFont(nvg, "sans", "Fonts/MiSans-Regular.ttf")
    
    TouchInput.Init()
    
    VirtualJoystick.Init({
        forceEnable = true,
        positionX = 0.15,
        positionY = 0.78,
    })
    
    CreateScene()
    
    -- 初始化模块
    GameStateManager.Init({
        scene = scene_,
        setupCallbacks = SetupCallbacks,
        DialogueData = DialogueData,
    })
    
    RenderManager.Init(nvg, cameraNode_, InputHandler)
    LoadingOverlay.Init(nvg)
    
    TestMode.Init({
        scene = scene_,
        applyShipBonuses = ApplyShipBonuses,
        setupCallbacks = SetupCallbacks,
        checkPostWaveUpgrades = function()
            GameStateManager.CheckPostWaveUpgrades()
        end,
    })
    
    Audio.Init(scene_)
    Audio.PlayMusic()
    
    InitGame()
    
    -- 设置测试菜单处理器
    TestMenuUI.SetTestHandler("dialogue", function()
        DialogueTestUI.Show(nil, scene_)
    end)
    
    TestMenuUI.SetTestHandler("reset_tutorial", function()
        TutorialManager.Reset()
        print("[Test] Tutorial progress reset - next game start will show opening dialogue")
    end)
    
    TestMenuUI.SetTestHandler("invincible", function()
        Game.debugInvincible = not Game.debugInvincible
        print("[Test] Invincible mode: " .. (Game.debugInvincible and "ON" or "OFF"))
    end)
    TestMenuUI.SetToggleStateGetter("invincible", function()
        return Game.debugInvincible
    end)
    
    -- 第10波快速测试（预配置）
    TestMenuUI.SetTestHandler("wave10_preconfigured", function()
        print("[Test] Wave 10 preconfigured test - starting directly...")
        InputHandler.SetMainMenuActive(false)
        MainMenuUI.Hide()
        TestMode.StartWave10Preconfigured()
    end)
    
    -- 第20波快速测试（预配置）
    TestMenuUI.SetTestHandler("wave20_preconfigured", function()
        print("[Test] Wave 20 preconfigured test - starting directly...")
        InputHandler.SetMainMenuActive(false)
        MainMenuUI.Hide()
        TestMode.StartWave20Preconfigured()
    end)
    
    -- 第10波测试
    TestMenuUI.SetTestHandler("wave10_test", function()
        Game.wave10TestMode = true
        print("[Test] Wave 10 test mode enabled - selecting ship...")
        InputHandler.SetMainMenuActive(false)
        MainMenuUI.Hide()
        InputHandler.SetShipSelectActive(true)
        
        ShipSelectUI.Show(function(ship)
            InputHandler.SetShipSelectActive(false)
            InputHandler.SetWeaponSelectActive(true)
            
            WeaponSelectUI.Show(ship, function(weapon)
                InputHandler.SetWeaponSelectActive(false)
                TestMode.StartWave10Test(ship, weapon.id)
            end)
        end)
    end)
    
    -- 敌人测试（只生成虫母舰Boss）
    TestMenuUI.SetTestHandler("enemy_test", function()
        Game.enemyTestMode = true
        print("[Test] Enemy test mode - starting directly with preconfigured setup...")
        InputHandler.SetMainMenuActive(false)
        MainMenuUI.Hide()
        TestMode.StartEnemyTest()
    end)
    
    -- 设置暂停菜单回调
    PauseUI.onResume = function()
        PauseUI.Hide()
    end
    
    PauseUI.onMainMenu = function()
        PauseUI.Hide()
        GameStateManager.ReturnToMainMenu(InitGame)
    end
    
    PauseUI.onGallery = function()
        InputHandler.SetGalleryActive(true)
        GalleryUI.Show(function()
            InputHandler.SetGalleryActive(false)
        end)
    end
    
    PauseUI.onSettings = function()
        InputHandler.SetOptionsActive(true)
        OptionsUI.Show(function()
            InputHandler.SetOptionsActive(false)
        end)
    end
    
    PauseUI.onEndRun = function()
        PauseUI.Hide()
        Game.GameOver()
    end
    
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PreRenderUI", "HandlePreRenderUI")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    
    TouchInput.Update()
    Audio.Update(dt)
    
    -- [临时] 音效测试：7=确认音 8=升级音
    if input:GetKeyPress(KEY_7) then Audio.PlayConfirm() end
    if input:GetKeyPress(KEY_8) then Audio.PlayLevelUp() end
    
    local sw = graphics:GetWidth()
    local sh = graphics:GetHeight()
    VirtualJoystick.Update(sw, sh)
    
    -- 加载遮罩：每帧更新计时（必须在 IsActive 判断前调用，否则永远无法结束）
    LoadingOverlay.Update(dt)

    -- 加载遮罩显示期间，仅更新背景，跳过所有游戏逻辑
    if LoadingOverlay.IsActive() then
        Background.Update(dt)
        UIScreen.UpdateMouseState()
        return
    end
    
    local bridgeState = BridgeUpgrade.GetState()
    
    -- 教程/剧情对话UI处理
    if DialogueUI.IsVisible() then
        DialogueUI.Update(dt)
        DialogueUI.HandleInput()
        DialogueUI.HandleTouch(sw, sh)
        Background.Update(dt)
        UIScreen.UpdateMouseState()
        return
    end
    
    -- 对话测试UI输入处理
    if DialogueTestUI.IsVisible() then
        DialogueTestUI.Update(dt)
        DialogueTestUI.HandleInput()
        DialogueTestUI.HandleTouch(sw, sh)
        Background.Update(dt)
        UIScreen.UpdateMouseState()
        return
    end
    
    -- 测试菜单输入处理
    if TestMenuUI.IsVisible() then
        TestMenuUI.HandleInput()
        TestMenuUI.HandleTouch(sw, sh)
        Background.Update(dt)
        UIScreen.UpdateMouseState()
        return
    end
    
    -- 输入处理
    local inputState = InputHandler.Update(dt, Game.currentState, bridgeState)
    
    -- 菜单界面
    if inputState == "main_menu" or inputState == "options" or inputState == "gallery" 
       or inputState == "ship_select" or inputState == "weapon_select" then
        Background.Update(dt)
        if inputState == "ship_select" then
            ShipSelectUI.Update(dt)
        end
        UIScreen.UpdateMouseState()
        return
    end
    
    -- 暂停菜单
    if PauseUI.IsVisible() then
        if InputHandler.optionsActive then
            OptionsUI.HandleInput(sw, sh)
            Background.Update(dt)
            UIScreen.UpdateMouseState()
            return
        end
        
        if InputHandler.galleryActive then
            GalleryUI.HandleInput(sw, sh)
            Background.Update(dt)
            UIScreen.UpdateMouseState()
            return
        end
        
        local wheelDelta = input:GetMouseMoveWheel()
        if wheelDelta and wheelDelta ~= 0 then
            PauseUI.HandleScroll(-wheelDelta * 2)
        end
        
        -- 使用 HandleTouch 统一处理输入（自动进行安全区坐标转换）
        PauseUI.HandleTouch(sw, sh)
        
        if input:GetKeyPress(KEY_ESCAPE) then
            PauseUI.Hide()
        end
        
        Background.Update(dt)
        UIScreen.UpdateMouseState()
        return
    end
    
    -- 补给箱开箱界面
    if Game.currentState == Game.States.CRATE_OPEN then
        CrateOpenUI.HandleTouch(sw, sh)
        Background.Update(dt)
        UIScreen.UpdateMouseState()
        return
    end
    
    -- HUD按钮（暂停、查看武器、自动战斗）- 按下/释放模式
    if Game.currentState == Game.States.PLAYING and not bridgeState.active then
        local mx, my = TouchInput.x, TouchInput.y
        
        -- 鼠标按下：检测按钮按下
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            local r = HUD.pauseButtonRect
            if r and UIScreen.CheckButtonPress(mx, my, "hud_pause", r.x, r.y, r.w, r.h) then
                -- 按下暂停按钮
            end
            
            r = HUD.weaponListButtonRect
            if r and UIScreen.CheckButtonPress(mx, my, "hud_weapon_list", r.x, r.y, r.w, r.h) then
                -- 按下武器列表按钮
            end
            
            r = HUD.autoBattleButtonRect
            if r and UIScreen.CheckButtonPress(mx, my, "hud_auto_battle", r.x, r.y, r.w, r.h) then
                -- 按下自动战斗按钮
            end
        end
        
        -- 鼠标释放：检测按钮触发
        if UIScreen.IsMouseReleased() then
            if UIScreen.CheckButtonRelease(mx, my, "hud_pause") then
                Audio.PlayUIClick()
                PauseUI.Show()
                UIScreen.UpdateMouseState()
                return
            end
            
            if UIScreen.CheckButtonRelease(mx, my, "hud_weapon_list") then
                HUD.ToggleWeaponList()
                UIScreen.UpdateMouseState()
                return
            end
            
            if UIScreen.CheckButtonRelease(mx, my, "hud_auto_battle") then
                local enabled = AutoBattle.Toggle()
                HUD.autoBattleEnabled = enabled
                UIScreen.UpdateMouseState()
                return
            end
        end
        
        if input:GetKeyPress(KEY_ESCAPE) then
            PauseUI.Show()
            UIScreen.UpdateMouseState()
            return
        end
    end
    
    -- 游戏逻辑
    if Game.currentState == Game.States.PLAYING and not bridgeState.active then
        if input:GetKeyPress(KEY_T) then
            local enabled = AutoBattle.Toggle()
            HUD.autoBattleEnabled = enabled
            print("[AutoBattle] " .. (enabled and "已开启" or "已关闭"))
        end
        
        local moveX, moveY
        local playerX, playerY = Player.GetPosition()
        
        if AutoBattle.IsEnabled() then
            moveX, moveY = AutoBattle.Update(dt, playerX, playerY)
        else
            moveX, moveY = InputHandler.GetMovementInput()
        end
        
        GameLoop.UpdatePlayer(dt, moveX, moveY)
        
        playerX, playerY = Player.GetPosition()
        CameraController.Update(dt, playerX, playerY)
        GameLoop.UpdateWeapons(dt, scene_)
        Player.UpdateWeaponFlash(dt)
        GameLoop.UpdateEntities(dt, playerX, playerY, scene_)
        Battle.Update(dt)
        
        Game.battle.currentWave = Battle.currentWave
        Game.battle.waveTimer = Battle.waveTimer
        
        GameLoop.CheckCollisions(scene_)
    end
    
    -- 视觉效果更新
    GameLoop.UpdateEffects(dt, cameraNode_)
    Background.Update(dt)
    
    -- 玩家死亡动画
    if Game.currentState == Game.States.PLAYER_DEATH then
        Player.UpdateDeathAnimation(dt)
    end
    
    -- 跃迁离开准备阶段
    GameStateManager.UpdateHyperspaceExitPrep(dt)
    
    -- 跃迁离开时更新实体飞离效果
    if Background.IsInHyperspace() and Background.GetHyperspaceMode() == "exit" then
        local state = Background.GetHyperspaceState()
        Enemy.UpdateHyperspaceExit(state.speed, state.stretch)
        Projectile.UpdateHyperspaceExit(state.speed, state.stretch)
        Pickup.UpdateHyperspaceExit(state.speed, state.stretch)
    end
    
    Overlays.UpdateWaveAnnouncement(dt)
    Overlays.UpdateBossPhaseAnnouncement(dt)
    Overlays.UpdateHyperspaceMessage(dt)
    
    -- 更新鼠标状态（用于下一帧的释放检测）
    UIScreen.UpdateMouseState()
end

function HandlePreRenderUI(eventType, eventData)
    RenderManager.Render()
end
