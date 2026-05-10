-- ============================================================================
-- 星河战姬 Starkyries - 测试模式模块
-- 提供快速测试功能，跳过正常游戏流程
-- ============================================================================

local TestMode = {}

-- ============================================================================
-- 延迟加载依赖（避免循环依赖）
-- ============================================================================
local Settings, Ships, Weapons, Game, Battle, BridgeUpgrade, Player, Drone
local InputHandler, Callbacks, GameStateManager

local function LoadDependencies()
    if not Ships then
        Settings = require("config.settings")
        Ships = require("config.ships")
        Weapons = require("config.weapons")
        Game = require("core.Game")
        Battle = require("core.Battle")
        BridgeUpgrade = require("core.BridgeUpgrade")
        Player = require("entities.Player")
        Drone = require("entities.Drone")
        InputHandler = require("core.InputHandler")
        Callbacks = require("core.Callbacks")
        GameStateManager = require("core.GameStateManager")
    end
end

-- ============================================================================
-- 内部变量
-- ============================================================================
local scene_ = nil
local applyShipBonusesCallback = nil
local setupCallbacksCallback = nil
local checkPostWaveUpgradesCallback = nil

-- ============================================================================
-- 初始化
-- ============================================================================

---@param options table { scene, applyShipBonuses, setupCallbacks, checkPostWaveUpgrades }
function TestMode.Init(options)
    LoadDependencies()
    scene_ = options.scene
    applyShipBonusesCallback = options.applyShipBonuses
    setupCallbacksCallback = options.setupCallbacks
    checkPostWaveUpgradesCallback = options.checkPostWaveUpgrades
end

-- ============================================================================
-- 测试加成配置（从 Settings 获取）
-- ============================================================================

local function GetWave10Bonuses()
    LoadDependencies()
    return Settings.TestMode.Wave10
end

local function GetWave20Bonuses()
    LoadDependencies()
    return Settings.TestMode.Wave20
end

local function GetWave10ManualBonuses()
    LoadDependencies()
    return Settings.TestMode.Wave10Manual
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

-- 应用测试加成到玩家
local function ApplyTestBonuses(bonuses)
    local p = Game.player
    
    if bonuses.bridgeLevel then
        p.bridgeLevel = bonuses.bridgeLevel
    end
    
    if bonuses.crystals then
        p.crystals = bonuses.crystals
    end
    
    if bonuses.damageMultiplier then
        p.damageMultiplier = (p.damageMultiplier or 1.0) + bonuses.damageMultiplier
    end
    
    if bonuses.fireRateMultiplier then
        p.fireRateMultiplier = (p.fireRateMultiplier or 1.0) + bonuses.fireRateMultiplier
    end
    
    if bonuses.maxShield then
        p.maxShield = (p.maxShield or 100) + bonuses.maxShield
        p.shield = p.maxShield
    end
    
    if bonuses.armor then
        p.armor = (p.armor or 0) + bonuses.armor
    end
    
    if bonuses.critChance then
        p.critChance = (p.critChance or 0.05) + bonuses.critChance
    end
    
    if bonuses.critDamage then
        p.critDamage = (p.critDamage or 1.5) + bonuses.critDamage
    end
end

-- 添加武器到玩家（辅助函数）
local function AddWeaponToPlayer(weaponId, shipConfig)
    if not weaponId then return end
    
    local weaponDef = Weapons.Get(weaponId)
    if not weaponDef then return end
    
    local maxSlots = Game.player.maxWeaponSlots or 6
    local freeSlot = Player.GetFreeSlot(maxSlots)
    if not freeSlot then
        print("[TestMode] 武器槽已满，无法添加武器: " .. weaponId)
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

-- 初始化游戏基础状态
local function InitGameBase(shipConfig)
    InputHandler.SetShipSelectActive(false)
    InputHandler.SetWeaponSelectActive(false)
    InputHandler.SetSelectedShipConfig(shipConfig)
    
    Game.Start(shipConfig.id)
    Battle.Init()
    BridgeUpgrade.Init()
    
    if applyShipBonusesCallback then
        applyShipBonusesCallback(shipConfig)
    end
end

-- ============================================================================
-- 第10波测试模式（需要选船/加点）
-- ============================================================================

function TestMode.StartWave10Test(shipConfig, weaponId)
    LoadDependencies()
    print("[TestMode] Starting Wave 10 test mode...")
    
    InitGameBase(shipConfig)
    
    -- 特殊加成：舰桥等级0，让玩家自己选择全部升级
    local manualBonuses = GetWave10ManualBonuses()
    local p = Game.player
    p.bridgeLevel = manualBonuses.bridgeLevel
    p.crystals = manualBonuses.crystals
    ApplyTestBonuses({
        damageMultiplier = manualBonuses.damageMultiplier,
        fireRateMultiplier = manualBonuses.fireRateMultiplier,
        maxShield = manualBonuses.maxShield,
        armor = manualBonuses.armor,
        critChance = manualBonuses.critChance,
        critDamage = manualBonuses.critDamage,
    })
    
    print(string.format("[TestMode] Wave 10 bonuses applied: DMG +30%%, AS +20%%, Shield +30, Armor +1, Crit +5%%"))
    
    -- 创建玩家战舰
    Player.Create(scene_, shipConfig)
    
    -- 添加战舰自带武器
    if shipConfig.initialWeapon then
        local count = shipConfig.initialWeaponCount or 1
        for i = 1, count do
            AddWeaponToPlayer(shipConfig.initialWeapon, shipConfig)
        end
    end
    
    -- 添加玩家选择的武器
    if weaponId then
        AddWeaponToPlayer(weaponId, shipConfig)
    end
    
    Game.RecalculateWeaponEffects()
    
    if setupCallbacksCallback then
        setupCallbacksCallback()
    end
    
    -- 设置当前波次为9，这样商店退出后会进入第10波
    Battle.currentWave = 9
    local Shop = require("core.Shop")
    Shop.currentWave = 9
    
    -- 给玩家升级机会
    Game.player.pendingUpgrades = manualBonuses.pendingUpgrades or 11
    
    -- 进入升级菜单
    print("[TestMode] Entering upgrade menu and shop before Wave 10...")
    if checkPostWaveUpgradesCallback then
        checkPostWaveUpgradesCallback()
    end
    
    -- 清除测试模式标记
    Game.wave10TestMode = false
end

-- ============================================================================
-- 第10波快速测试（预配置：多面号 + 6×T3集束导弹）
-- ============================================================================

function TestMode.StartWave10Preconfigured()
    LoadDependencies()
    print("[TestMode] Starting Wave 10 preconfigured test...")
    print("[TestMode] Ship: Polyhedron (多面号), Weapons: 6x T3 ClusterMissile")
    
    local shipConfig = Ships.List.Polyhedron
    InitGameBase(shipConfig)
    ApplyTestBonuses(GetWave10Bonuses())
    
    -- 额外增加初始属性
    local p = Game.player
    p.maxShield = (p.maxShield or 100) + 50  -- 额外 +50 护盾
    p.shield = p.maxShield
    p.crystals = (p.crystals or 0) + 200     -- 额外 +200 金钱
    
    print(string.format("[TestMode] Bonuses applied: DMG +30%%, AS +20%%, Shield +30, Armor +1, Crit +5%%"))
    
    -- 创建玩家战舰
    Player.Create(scene_, shipConfig)
    
    -- 添加6个T3集束导弹
    for i = 1, 6 do
        Player.AddWeapon("ClusterMissile", i, 3)
    end
    
    print("[TestMode] Added 6x T3 ClusterMissile to all weapon slots")
    
    Game.RecalculateWeaponEffects()
    
    if setupCallbacksCallback then
        setupCallbacksCallback()
    end
    
    -- 通过超空间跳跃动画开始第10波战斗
    Battle.currentWave = 10
    print("[TestMode] Starting Wave 10 battle with hyperspace animation...")
    GameStateManager.StartBattleWithHyperspace(10)
end

-- ============================================================================
-- 第20波快速测试（预配置：先锋号 + 6×T4速射力场）
-- ============================================================================

function TestMode.StartWave20Preconfigured()
    LoadDependencies()
    print("[TestMode] Starting Wave 20 preconfigured test...")
    print("[TestMode] Ship: Pioneer (先锋号), Weapons: 6x T4 BomberDrone")
    
    local shipConfig = Ships.List.Pioneer
    InitGameBase(shipConfig)
    ApplyTestBonuses(GetWave20Bonuses())
    
    print(string.format("[TestMode] Wave 20 bonuses applied: DMG +60%%, AS +40%%, Shield +60, Armor +2, Crit +10%%"))
    
    -- 创建玩家战舰
    Player.Create(scene_, shipConfig)
    
    -- 添加6个T4轰炸无人机
    local playerX, playerY = Player.GetPosition()
    for i = 1, 6 do
        local weapon = Player.AddWeapon("BomberDrone", i, 4)
        if weapon then
            weapon.isDrone = true
            -- 创建无人机实体
            Drone.Create(scene_, "BomberDrone", 4, playerX, playerY, i - 1)
        end
    end
    
    print("[TestMode] Added 6x T4 BomberDrone to all weapon slots")
    
    Game.RecalculateWeaponEffects()
    
    if setupCallbacksCallback then
        setupCallbacksCallback()
    end
    
    -- 通过超空间跳跃动画开始第20波战斗
    Battle.currentWave = 20
    print("[TestMode] Starting Wave 20 battle with hyperspace animation (BroodQueen Boss)...")
    GameStateManager.StartBattleWithHyperspace(20)
end

-- ============================================================================
-- 敌人测试模式（只生成Boss）
-- ============================================================================

function TestMode.StartEnemyTest()
    LoadDependencies()
    local Debris = require("entities.Debris")
    
    print("[TestMode] Starting Debris test mode...")
    print("[TestMode] Ship: Pioneer (先锋号), Weapons: 1x T1 ParticleMachinegun")
    
    local shipConfig = Ships.List.Pioneer
    InitGameBase(shipConfig)
    -- 不应用额外加成，保持基础状态
    
    -- 创建玩家战舰
    Player.Create(scene_, shipConfig)
    
    -- 添加1个T1粒子机炮
    Player.AddWeapon("ParticleMachinegun", 1, 1)
    
    print("[TestMode] Added 1x T1 ParticleMachinegun")
    
    Game.RecalculateWeaponEffects()
    
    if setupCallbacksCallback then
        setupCallbacksCallback()
    end
    
    -- 设置为第1波，禁用敌人生成
    Battle.currentWave = 1
    Battle.bossOnlyMode = true  -- 阻止小怪生成
    Battle.testBossType = nil   -- 不生成Boss
    
    -- 手动生成5个残骸
    local positions = {
        {x = -8, y = 3},
        {x = -4, y = -2},
        {x = 0, y = 4},
        {x = 5, y = 1},
        {x = 8, y = -3},
    }
    
    -- 测试模式：临时提高补给箱掉落率到100%
    local originalDropRate = Debris.Config.SupplyCrateDrop
    Debris.Config.SupplyCrateDrop = 1.0  -- 100% 掉落
    print("[TestMode] Crate drop rate set to 100% for testing")
    
    for _, pos in ipairs(positions) do
        Debris.Create(scene_, pos.x, pos.y, 1)
    end
    print("[TestMode] Spawned 5 debris for testing")
    
    -- 注意：测试完成后掉落率会保持100%，重启游戏恢复
    
    local Overlays = require("ui.Overlays")
    Battle.StartWave(1)
    Overlays.StartWaveAnnouncement(1)
    Game.SetState(Game.States.PLAYING)
    
    -- 清除测试模式标记
    Game.enemyTestMode = false
end

-- ============================================================================
-- 获取测试加成配置（供外部使用）
-- ============================================================================

function TestMode.GetWave10Bonuses()
    return GetWave10Bonuses()
end

function TestMode.GetWave20Bonuses()
    return GetWave20Bonuses()
end

function TestMode.GetWave10ManualBonuses()
    return GetWave10ManualBonuses()
end

return TestMode
