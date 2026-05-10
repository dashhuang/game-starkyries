-- ============================================================================
-- 星河战姬 Starkyries - 游戏状态管理器
-- 管理游戏状态转换、初始化、重启等流程
-- ============================================================================

local GameStateManager = {}

-- ============================================================================
-- 错误处理
-- ============================================================================
local ErrorHandler = require("utils.ErrorHandler")
local MODULE_NAME = "GameStateManager"

-- ============================================================================
-- 延迟加载依赖
-- ============================================================================
local Settings, Ships, Weapons, Modules, Game, Battle, Shop, Audio, BridgeUpgrade
local SaveManager, TutorialManager, StatsManager, Player, Enemy, Projectile, Pickup
local Effects, Drone, Background, CameraController, InputHandler
local MainMenuUI, ShipSelectUI, WeaponSelectUI, OptionsUI, GalleryUI
local TestMenuUI, DialogueUI, Overlays, Materials
local Debris, DebrisPickup, CrateOpenUI
local LoadingOverlay = require("ui.LoadingOverlay")
local ImageLoader = require("utils.ImageLoader")

local function LoadDependencies()
    if not Settings then
        local success, err = pcall(function()
            Settings = require("config.settings")
            Ships = require("config.ships")
            Weapons = require("config.weapons")
            Modules = require("config.modules")
            Game = require("core.Game")
            Battle = require("core.Battle")
            Shop = require("core.Shop")
            Audio = require("core.Audio")
            BridgeUpgrade = require("core.BridgeUpgrade")
            SaveManager = require("core.SaveManager")
            TutorialManager = require("core.TutorialManager")
            StatsManager = require("core.StatsManager")
            Player = require("entities.Player")
            Enemy = require("entities.Enemy")
            Projectile = require("entities.Projectile")
            Pickup = require("entities.Pickup")
            Effects = require("entities.Effects")
            Drone = require("entities.Drone")
            Debris = require("entities.Debris")
            DebrisPickup = require("entities.DebrisPickup")
            Background = require("render.Background")
            CameraController = require("core.CameraController")
            InputHandler = require("core.InputHandler")
            MainMenuUI = require("ui.MainMenuUI")
            ShipSelectUI = require("ui.ShipSelectUI")
            WeaponSelectUI = require("ui.WeaponSelectUI")
            OptionsUI = require("ui.OptionsUI")
            GalleryUI = require("ui.GalleryUI")
            TestMenuUI = require("ui.TestMenuUI")
            DialogueUI = require("ui.DialogueUI")
            Overlays = require("ui.Overlays")
            CrateOpenUI = require("ui.CrateOpenUI")
            Materials = require("render.Materials")
        end)
        
        if not success then
            ErrorHandler.Error(MODULE_NAME, "加载依赖模块失败: " .. tostring(err))
        end
    end
end

-- ============================================================================
-- 内部变量
-- ============================================================================
local scene_ = nil
local setupCallbacksFunc_ = nil
local dialogueData_ = nil

-- ============================================================================
-- 初始化
-- ============================================================================

---@param options table { scene, setupCallbacks, DialogueData }
function GameStateManager.Init(options)
    LoadDependencies()
    scene_ = options.scene
    setupCallbacksFunc_ = options.setupCallbacks
    dialogueData_ = options.DialogueData
end

-- ============================================================================
-- 应用战舰特殊加成
-- ============================================================================

function GameStateManager.ApplyShipBonuses(shipConfig)
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
-- 添加武器辅助函数
-- ============================================================================

local function AddWeaponToPlayer(weaponId)
    if not weaponId then return end
    
    local weaponDef = Weapons.Get(weaponId)
    if not weaponDef then return end
    
    local maxSlots = Game.player.maxWeaponSlots or 6
    local freeSlot = Player.GetFreeSlot(maxSlots)
    if not freeSlot then
        print("[GameStateManager] 武器槽已满，无法添加武器: " .. weaponId)
        return
    end
    
    if weaponDef.isDrone then
        local playerX, playerY = Player.GetPosition()
        local droneCount = weaponDef.droneCount or 1
        
        for i = 1, droneCount do
            Drone.Create(scene_, weaponId, 1, playerX, playerY, #Game.player.weapons + i - 1)
        end
        
        local weapon = Player.AddWeapon(weaponId, freeSlot, 1)
        if weapon then
            weapon.isDrone = true
        end
    else
        Player.AddWeapon(weaponId, freeSlot, 1)
    end
end

-- ============================================================================
-- 开始游戏（选择战舰后）
-- ============================================================================

function GameStateManager.StartGameWithShip(shipConfig, weaponId)
    LoadDependencies()
    
    -- 验证参数
    if not shipConfig then
        ErrorHandler.Error(MODULE_NAME, "StartGameWithShip: shipConfig 不能为 nil")
        return false
    end
    
    if not scene_ then
        ErrorHandler.Error(MODULE_NAME, "StartGameWithShip: 场景未初始化")
        return false
    end
    
    local success, err = pcall(function()
        InputHandler.SetShipSelectActive(false)
        InputHandler.SetWeaponSelectActive(false)
        InputHandler.SetSelectedShipConfig(shipConfig)
        
        -- 初始化游戏状态
        Game.Start(shipConfig.id)
        Battle.Init()
        BridgeUpgrade.Init()
        Shop.ResetForNewGame()
        
        -- 记录游戏开始统计
        StatsManager.OnGameStart()
        
        -- 应用战舰特殊加成
        GameStateManager.ApplyShipBonuses(shipConfig)
        
        -- 创建玩家战舰
        Player.Create(scene_, shipConfig)
        
        -- 1. 添加战舰自带的初始武器
        if shipConfig.initialWeapon then
            local count = shipConfig.initialWeaponCount or 1
            for i = 1, count do
                AddWeaponToPlayer(shipConfig.initialWeapon)
            end
        end
        
        -- 2. 添加玩家选择的武器
        if weaponId then
            AddWeaponToPlayer(weaponId)
        end
        
        -- 重新计算武器效果
        Game.RecalculateWeaponEffects()
        
        -- 设置回调
        if setupCallbacksFunc_ then
            setupCallbacksFunc_()
        end
    end)
    
    if not success then
        ErrorHandler.Error(MODULE_NAME, "StartGameWithShip 失败: " .. tostring(err))
        return false
    end
    
    -- 开始第一波（带超空间跳跃动画）
    GameStateManager.StartBattleWithHyperspace(1)
    return true
end

-- ============================================================================
-- 超空间跳跃入场动画
-- ============================================================================

function GameStateManager.StartBattleWithHyperspace(waveNum)
    -- 设置超空间跳跃状态
    Game.SetState(Game.States.HYPERSPACE)
    
    -- 清除所有子弹和武器特效
    Projectile.ClearAll()
    
    -- 重置玩家位置和相机到地图中心
    Player.ResetToCenter()
    CameraController.ResetToCenter()
    
    -- 显示跃迁提示
    Overlays.ShowHyperspaceMessage()
    
    -- 播放超空间跳跃音效
    Audio.PlayHyperspaceJump()
    
    -- 开始超空间跳跃动画
    Background.StartHyperspace(function()
        -- 动画完成后开始战斗
        Pickup.ResetPositions()
        
        Battle.StartWave(waveNum)
        Overlays.StartWaveAnnouncement(waveNum)
        Game.SetState(Game.States.PLAYING)
    end, function()
        -- 减速阶段开始时，渐隐超空间提示
        Overlays.HideHyperspaceMessage()
    end)
end

-- ============================================================================
-- 超空间跃迁离开动画
-- ============================================================================

local hyperspaceExitWaveNum = 0
local hyperspaceExitPrep = {
    active = false,
    timer = 0,
    duration = 0.1,
}

function GameStateManager.StartHyperspaceExit(waveNum)
    hyperspaceExitWaveNum = waveNum
    
    Game.SetState(Game.States.HYPERSPACE)
    
    hyperspaceExitPrep.active = true
    hyperspaceExitPrep.timer = 0
    Player.SetDirection("UP")
end

function GameStateManager.UpdateHyperspaceExitPrep(dt)
    if not hyperspaceExitPrep.active then return end
    
    hyperspaceExitPrep.timer = hyperspaceExitPrep.timer + dt
    
    Player.UpdateRotationFast(dt)
    
    if hyperspaceExitPrep.timer >= hyperspaceExitPrep.duration then
        hyperspaceExitPrep.active = false
        
        Overlays.ShowHyperspaceMessage(true)
        
        Enemy.StartHyperspaceExit()
        Projectile.StartHyperspaceExit()
        Pickup.StartHyperspaceExit()
        
        local Waves = require("config.waves")
        
        -- 播放超空间跳跃音效
        Audio.PlayHyperspaceJump()
        
        Background.StartHyperspaceExit(function()
            Enemy.StopHyperspaceExit()
            Projectile.StopHyperspaceExit()
            Pickup.StopHyperspaceExit()
            
            Enemy.ClearAll()
            Projectile.ClearAll()
            
            local mergeResult = Pickup.MergeCrystals(scene_, 2)
            if mergeResult.merged > 0 then
                print(string.format("[Pickup] 波次%d结束：合并%d个晶体为%d个", hyperspaceExitWaveNum, mergeResult.merged, mergeResult.created))
            end
            
            Pickup.HideAll()
            
            -- 记录空间跳跃统计
            StatsManager.OnHyperspaceJump()
            
            if hyperspaceExitWaveNum >= Waves.GetTotalWaves() then
                -- 游戏胜利，保存统计
                StatsManager.OnVictory()
                StatsManager.OnGameEnd(Game.battle.playTime, hyperspaceExitWaveNum)
                Game.Victory()
            else
                GameStateManager.CheckPostWaveUpgrades()
            end
        end, function()
            Overlays.HideHyperspaceMessage()
        end)
    end
end

-- ============================================================================
-- 商店系统
-- ============================================================================

function GameStateManager.EnterShop()
    LoadDependencies()
    Shop.Init(Battle.currentWave)
    Game.SetState(Game.States.SHOP)
    Audio.PlayUIClick()
end

function GameStateManager.ExitShop()
    SaveManager.OnExitShop(Game)
    
    Player.SetDirection("UP")
    
    GameStateManager.StartBattleWithHyperspace(Battle.currentWave + 1)
end

-- ============================================================================
-- 舰桥升级
-- ============================================================================

function GameStateManager.CheckPostWaveUpgrades()
    print("[GameStateManager] CheckPostWaveUpgrades called")
    -- 先检查是否有待开启的补给箱
    if DebrisPickup.HasPendingCrates() then
        print("[GameStateManager] HasPendingCrates returned true, starting CrateOpenUI")
        GameStateManager.StartCrateOpenUI()
        return
    end
    print("[GameStateManager] No pending crates, proceeding to upgrades/shop")
    
    if Game.HasPendingUpgrades() then
        GameStateManager.StartBridgeUpgradeUI()
    else
        GameStateManager.EnterShop()
    end
end

-- ============================================================================
-- 补给箱开箱界面
-- ============================================================================

function GameStateManager.StartCrateOpenUI()
    print("[GameStateManager] StartCrateOpenUI called")
    LoadDependencies()
    
    local collectedCrates = DebrisPickup.GetCollectedCrates()
    print(string.format("[GameStateManager] Got %d collected crates", #collectedCrates))
    if #collectedCrates == 0 then
        -- 没有箱子，跳过
        print("[GameStateManager] No crates, skipping to ContinueAfterCrates")
        GameStateManager.ContinueAfterCrates()
        return
    end
    
    -- 先初始化开箱UI（确定模块内容和图片路径）
    CrateOpenUI.Init(collectedCrates, Game.player)
    
    -- 收集模块图片路径
    local paths = {}
    for _, crate in ipairs(CrateOpenUI.crates) do
        if crate.moduleId then
            table.insert(paths, "images/modules/" .. crate.moduleId .. ".jpg")
        end
    end

    -- 预加载后显示开箱界面
    ImageLoader.PreloadGate(paths, function()
        Game.SetState(Game.States.CRATE_OPEN)

        -- 设置回调
        CrateOpenUI.onGetItem = function(crateData)
            GameStateManager.HandleGetCrateItem(crateData)
        end

        CrateOpenUI.onRecycleItem = function(crateData)
            GameStateManager.HandleRecycleCrateItem(crateData)
        end

        CrateOpenUI.onComplete = function()
            -- 清空已收集列表
            DebrisPickup.ClearCollectedCrates()
            -- 继续流程
            GameStateManager.ContinueAfterCrates()
        end

        Audio.PlayUIClick()
    end, "正在准备补给箱...")
end

-- 获取箱子物品
function GameStateManager.HandleGetCrateItem(crateData)
    LoadDependencies()
    
    if crateData.type == "crystals" then
        -- 晶体直接添加
        Game.AddCrystals(crateData.amount)
        Audio.PlayPickup("crystal")
    elseif crateData.type == "item" then
        if crateData.itemType == "weapon" then
            -- 添加武器
            local weaponDef = Weapons.Get(crateData.itemId)
            if weaponDef then
                local freeSlot = Player.GetFreeSlot(Game.player.maxWeaponSlots)
                if freeSlot then
                    local tier = crateData.tier or 1
                    local weapon = Player.AddWeapon(crateData.itemId, freeSlot, tier, Game.player.shipConfig)
                    
                    if weaponDef.isDrone and weapon then
                        local playerX, playerY = Player.GetPosition()
                        local droneCount = weaponDef.droneCount or 1
                        local existingCount = Drone.GetCountByWeapon(crateData.itemId)
                        for i = 1, droneCount do
                            Drone.Create(scene_, crateData.itemId, tier, playerX, playerY, existingCount + i - 1)
                        end
                        weapon.isDrone = true
                    end
                    
                    Game.RecalculateWeaponEffects()
                    Audio.PlayPurchase()
                else
                    -- 没有空位，转为晶体
                    local recycleValue = math.floor((crateData.price or 15) * 0.5)
                    Game.AddCrystals(recycleValue)
                    Audio.PlayPickup("crystal")
                end
            end
        elseif crateData.itemType == "module" then
            -- 添加模块
            local moduleDef = Modules.GetById(crateData.itemId)
            if moduleDef then
                moduleDef.effect(Game.player)
                Game.player.modules[crateData.itemId] = (Game.player.modules[crateData.itemId] or 0) + 1
                Audio.PlayPurchase()
            end
        end
    end
end

-- 回收箱子物品
function GameStateManager.HandleRecycleCrateItem(crateData)
    LoadDependencies()
    
    if crateData.type ~= "item" then return end
    
    -- 计算回收价值：基础25% + 回收效率加成
    local recycleRate = 0.25 + (Game.player.recycleEfficiency or 0)
    local recycleValue = math.floor((crateData.price or 15) * recycleRate)
    
    Game.AddCrystals(recycleValue)
    Audio.PlayPickup("crystal")
end

-- 开箱完成后继续流程
function GameStateManager.ContinueAfterCrates()
    if Game.HasPendingUpgrades() then
        GameStateManager.StartBridgeUpgradeUI()
    else
        GameStateManager.EnterShop()
    end
end

function GameStateManager.StartBridgeUpgradeUI()
    BridgeUpgrade.Start(Game)
    Overlays.ResetStatsScroll()
end

function GameStateManager.SelectBridgeUpgrade(index)
    local hasMore = BridgeUpgrade.Select(index, Game)
    if not hasMore then
        GameStateManager.EnterShop()
    end
end

-- ============================================================================
-- 游戏重启
-- ============================================================================

function GameStateManager.RestartGame(initGameCallback)
    LoadDependencies()
    
    -- 清理所有实体
    Enemy.ClearAll()
    Projectile.ClearAll()
    Pickup.ClearAll()
    Effects.ClearAll()
    Drone.ClearAll()
    Debris.ClearAll()
    DebrisPickup.ClearAll()
    Player.Destroy()
    Background.Clear()
    
    -- 清理缓存
    Audio.Cleanup()
    Materials.ClearCache()
    DialogueUI.Cleanup()
    
    -- 重新初始化音频
    Audio.Init(scene_)
    Audio.PlayMusic()
    
    BridgeUpgrade.Init()
    
    if initGameCallback then
        initGameCallback()
    end
end

function GameStateManager.ReturnToMainMenu(initGameCallback)
    LoadDependencies()
    
    -- 清理所有实体
    Enemy.ClearAll()
    Projectile.ClearAll()
    Pickup.ClearAll()
    Effects.ClearAll()
    Drone.ClearAll()
    Debris.ClearAll()
    DebrisPickup.ClearAll()
    Player.Destroy()
    Background.Clear()
    
    -- 清理缓存
    Audio.Cleanup()
    Materials.ClearCache()
    DialogueUI.Cleanup()
    
    -- 重新初始化音频
    Audio.Init(scene_)
    Audio.PlayMusic()
    
    -- 重新创建背景
    Background.Create(scene_)
    
    -- 重置游戏状态
    Game.SetState(Game.States.PLAYING)
    
    -- 返回主菜单
    InputHandler.SetMainMenuActive(true)
    
    -- 显示主菜单UI
    GameStateManager.ShowMainMenu(initGameCallback)
end

-- ============================================================================
-- 显示主菜单
-- ============================================================================

function GameStateManager.ShowMainMenu(initGameCallback)
    LoadDependencies()
    
    print("[GameStateManager] ShowMainMenu called")
    
    -- 设置输入状态
    InputHandler.SetMainMenuActive(true)
    print("[GameStateManager] InputHandler.mainMenuActive = " .. tostring(InputHandler.mainMenuActive))
    
    local hasSaveData = SaveManager.HasSave()
    print("[GameStateManager] hasSaveData = " .. tostring(hasSaveData))
    
    MainMenuUI.Show({
        hasSaveData = hasSaveData,
        onStartGame = function()
            if SaveManager.HasSave() then
                SaveManager.Delete()
            end
            
            if TutorialManager.NeedsOpeningDialogue() then
                InputHandler.SetMainMenuActive(false)
                MainMenuUI.Hide()
                GameStateManager.StartTutorialOpening()
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
                    GameStateManager.StartGameWithShip(ship, weapon.id)
                end)
            end)
        end,
        onContinue = function()
            GameStateManager.ContinueFromSave()
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
            TestMenuUI.Show()
        end,
    })
end

-- ============================================================================
-- 教程系统
-- ============================================================================

function GameStateManager.StartTutorialOpening()
    print("[Tutorial] Starting opening dialogue...")
    
    local dialogueDataModule = dialogueData_ or require("data.DialogueData")
    local dialogueDataContent = dialogueDataModule.Get("Tutorial_Opening")
    
    if not dialogueDataContent then
        print("[Tutorial] Warning: Tutorial_Opening dialogue not found, skipping")
        TutorialManager.CompleteOpening()
        GameStateManager.StartTutorialGame()
        return
    end
    
    -- Play 内部自动预加载图片，下载完成后才开始对话
    DialogueUI.Play(dialogueDataContent, function()
        print("[Tutorial] Opening dialogue completed")
        TutorialManager.CompleteOpening()
        GameStateManager.StartTutorialGame()
    end, { dialogueId = "Tutorial_Opening", scene = scene_ })
end

function GameStateManager.StartTutorialGame()
    print("[Tutorial] Starting game with default ship and weapon...")
    -- 注：战败剧情图片由 BackgroundPreloader 统一后台预加载，DialogueUI.Play 内部有安全网兜底

    local defaultShip = Ships.GetDefault()
    local defaultWeaponId = "ParticleMachinegun"
    
    GameStateManager.StartGameWithShip(defaultShip, defaultWeaponId)
end

function GameStateManager.StartTutorialFirstDefeat()
    print("[Tutorial] Starting first defeat dialogue...")
    
    local dialogueDataModule = dialogueData_ or require("data.DialogueData")
    local dialogueDataContent = dialogueDataModule.Get("Tutorial_FirstDefeat")
    
    if not dialogueDataContent then
        print("[Tutorial] Warning: Tutorial_FirstDefeat dialogue not found, skipping")
        TutorialManager.CompleteFirstDefeat()
        Game.ForceGameOver()
        return
    end
    
    -- Play 内部自动预加载图片，下载完成后才开始对话
    DialogueUI.Play(dialogueDataContent, function()
        print("[Tutorial] First defeat dialogue completed")
        TutorialManager.CompleteFirstDefeat()
        Game.ForceGameOver()
    end, { dialogueId = "Tutorial_FirstDefeat", scene = scene_ })
end

-- ============================================================================
-- 从存档继续游戏
-- ============================================================================

function GameStateManager.ContinueFromSave()
    SaveManager.GetRestoreData(function(saveData)
        if not saveData then
            ErrorHandler.Warn(MODULE_NAME, "ContinueFromSave: 没有有效的存档数据")
            return
        end
        
        local success, err = pcall(function()
            local waveToStart = saveData.battle.currentWave
            if saveData.needRollback then
                ErrorHandler.Info(MODULE_NAME, "回滚到波次开始状态")
            end
            
            InputHandler.SetMainMenuActive(false)
            MainMenuUI.Hide()
            
            local shipConfig = Ships.Get(saveData.player.shipId) or Ships.GetDefault()
            if not shipConfig then
                error("无法获取战舰配置: " .. tostring(saveData.player.shipId))
            end
            
            InputHandler.SetSelectedShipConfig(shipConfig)
            
            Game.InitPlayer(shipConfig.id)
            Game.InitBattle()
            Battle.Init()
            BridgeUpgrade.Init()
            
            SaveManager.RestorePlayerData(Game.player, saveData.player)
            local p = Game.player
            
            p.shipConfig = shipConfig
            
            Player.Create(scene_, shipConfig)
            
            for _, weaponData in ipairs(saveData.player.weapons or {}) do
                local weaponDef = Weapons.Get(weaponData.weaponId)
                
                if weaponDef and weaponDef.isDrone then
                    local playerX, playerY = Player.GetPosition()
                    local droneCount = weaponDef.droneCount or 1
                    local existingCount = Drone.GetCountByWeapon(weaponData.weaponId)
                    
                    for i = 1, droneCount do
                        Drone.Create(scene_, weaponData.weaponId, weaponData.tier, playerX, playerY, existingCount + i - 1)
                    end
                    
                    local weapon = Player.AddWeapon(weaponData.weaponId, weaponData.slotIndex, weaponData.tier, shipConfig)
                    if weapon then
                        weapon.isDrone = true
                    end
                else
                    Player.AddWeapon(weaponData.weaponId, weaponData.slotIndex, weaponData.tier, shipConfig)
                end
            end
            
            Game.RecalculateWeaponEffects()
            
            Game.battle.currentWave = saveData.battle.currentWave
            Game.battle.totalKills = saveData.battle.totalKills
            
            if setupCallbacksFunc_ then
                setupCallbacksFunc_()
            end
            
            if saveData.waveState == SaveManager.WaveState.AFTER_WAVE then
                ErrorHandler.Info(MODULE_NAME, "从商店状态继续，波次 " .. waveToStart)
                Battle.currentWave = waveToStart
                
                if p.pendingUpgrades > 0 then
                    GameStateManager.StartBridgeUpgradeUI()
                else
                    GameStateManager.EnterShop()
                end
            else
                ErrorHandler.Info(MODULE_NAME, "从波次 " .. waveToStart .. " 继续")
                GameStateManager.StartBattleWithHyperspace(waveToStart)
            end
        end)
        
        if not success then
            ErrorHandler.Error(MODULE_NAME, "ContinueFromSave 失败: " .. tostring(err))
            -- 返回主菜单
            InputHandler.SetMainMenuActive(true)
        end
    end)
end

return GameStateManager
