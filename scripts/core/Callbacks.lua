-- ============================================================================
-- 星河战姬 Starkyries - 回调系统设置
-- 连接各模块的胶水代码
-- ============================================================================

local Callbacks = {}

-- 依赖引用（在 Setup 时注入）
local deps = {}

-- ============================================================================
-- 设置所有回调
-- ============================================================================

-- 延迟加载残骸系统模块
local Debris = nil
local DebrisPickup = nil

local function GetDebrisModules()
    if not Debris then
        Debris = require("entities.Debris")
        DebrisPickup = require("entities.DebrisPickup")
    end
    return Debris, DebrisPickup
end

function Callbacks.Setup(dependencies)
    deps = dependencies
    
    local scene_ = deps.scene
    local Settings = deps.Settings
    local Weapons = deps.Weapons
    local Modules = deps.Modules
    local Enemies = deps.Enemies
    local Game = deps.Game
    local Battle = deps.Battle
    local Shop = deps.Shop
    local BridgeUpgrade = deps.BridgeUpgrade
    local SaveManager = deps.SaveManager
    local Player = deps.Player
    local Enemy = deps.Enemy
    local Projectile = deps.Projectile
    local Pickup = deps.Pickup
    local Effects = deps.Effects
    local Drone = deps.Drone
    local Overlays = deps.Overlays
    local ShipSelectUI = deps.ShipSelectUI
    local WeaponSelectUI = deps.WeaponSelectUI
    local MainMenuUI = deps.MainMenuUI
    local Audio = deps.Audio
    local CameraController = deps.CameraController
    local InputHandler = deps.InputHandler
    local Math = deps.Math
    local TutorialManager = deps.TutorialManager
    
    -- 主流程函数
    local StartHyperspaceExit = deps.StartHyperspaceExit
    local StartTutorialFirstDefeat = deps.StartTutorialFirstDefeat
    local StartGameWithShip = deps.StartGameWithShip
    local ExitShop = deps.ExitShop
    local RestartGame = deps.RestartGame
    local SelectBridgeUpgrade = deps.SelectBridgeUpgrade
    
    -- ========================================================================
    -- 战斗系统回调
    -- ========================================================================
    
    Battle.onSpawnEnemy = function(enemyType, x, y, fromWarp)
        local scaledStats = Battle.ScaleEnemyStats(Enemies.Get(enemyType))
        Enemy.Create(scene_, enemyType, x, y, scaledStats)
    end
    
    Battle.onWarpWarning = function(x, y, enemyType, delay)
        Effects.CreateWarpWarning(scene_, x, y, enemyType, delay)
        -- Audio.PlayWarpWarning()  -- 音效效果不好，暂时禁用
    end
    
    Battle.onWaveStart = function(waveNum)
        Game.battle.currentWave = waveNum
        Game.ResetWaveCrystals()
        SaveManager.OnWaveStart(Game)
        Overlays.StartWaveAnnouncement(waveNum)
        -- Audio.PlayWaveStart(waveNum)  -- 音效效果不好，暂时禁用
        
        -- 重置无人机状态（防止波次结束后无人机卡在攻击状态）
        local playerX, playerY = Player.GetPosition()
        Drone.ResetAllStates(playerX, playerY)
    end
    
    Battle.onWaveComplete = function(waveNum)
        -- 清理所有弹道（玩家和敌人），包括导弹尾焰
        Projectile.ClearAll()
        
        -- 注意：晶体合并移到超空间离开动画完成后执行（用户看不到合并过程）
        
        local bonus = Game.ApplyWaveEndCrystalBonus()
        if bonus > 0 then
            local collected = Game.battle.waveCrystalsCollected or 0
            print(string.format("[Game] 波次%d结束：收集%d晶体，资源回收+%d", waveNum, collected, bonus))
        end
        
        SaveManager.OnWaveComplete(Game)
        StartHyperspaceExit(waveNum)
    end
    
    Battle.onAllWavesComplete = function()
        Game.Victory()
    end
    
    Battle.getEnemyCount = function() return Enemy.GetCount() end
    Battle.getWarpWarningCount = function() return Effects.GetWarpWarningCount() end
    Battle.getPlayerPosition = function() return Player.GetPosition() end
    Battle.getVisibleArea = function() return CameraController.GetVisibleArea() end
    Battle.clearAllEnemies = function() Enemy.ClearAll() end
    Battle.clearAllWarpWarnings = function() Effects.ClearAllWarpWarnings() end
    Battle.triggerAllEnemiesSelfDestruct = function() Enemy.TriggerAllSelfDestruct() end
    
    Battle.forceRemoveEnemy = function()
        local removed = Enemy.ForceRemoveRandomNonElite()
        if removed then Game.OnKill() end
        return removed
    end
    
    -- ========================================================================
    -- 敌人系统回调
    -- ========================================================================
    
    -- 敌人死亡时立即触发（击退开始前）
    Enemy.onDeath = function(enemy)
        Game.OnKill()
        
        local xpAmount = enemy.dropXp or 5
        Game.AddXp(xpAmount)
        Game.CheckAndAccumulateUpgrades()
        
        -- 记录晶体数量，等击退完成后再掉落
        local drop = enemy.dropCrystal
        local crystalAmount
        if type(drop) == "table" then
            crystalAmount = math.random(drop.min, drop.max)
        else
            crystalAmount = drop or 1
        end
        
        local harvestingBonus = Game.player.harvesting or 0
        if harvestingBonus > 0 then
            crystalAmount = math.ceil(crystalAmount * (1 + harvestingBonus / 100))
        end
        
        -- 保存到敌人对象，onDeathFinish 时使用
        enemy.pendingCrystals = crystalAmount
        
        -- Boss击败检测：触发所有敌人自爆并提前结束波次
        -- 只有主Boss（与波次配置的bossType匹配）才触发
        if enemy.isBoss then
            Battle.OnBossDefeated(enemy.type)
        end
    end
    
    -- 敌人死亡动画结束时触发（击退完成后，在最终位置）
    Enemy.onDeathFinish = function(enemy)
        -- 在最终位置掉落晶体
        local crystalAmount = enemy.pendingCrystals or 1
        Pickup.CreateCrystal(scene_, enemy.node.position.x, enemy.node.position.y, crystalAmount)
        
        -- 在最终位置播放死亡粒子
        local def = Enemies.Get(enemy.type)
        local posX, posY = enemy.node.position.x, enemy.node.position.y
        
        local particleCount = math.floor(8 + enemy.scale * 6)
        if enemy.isBoss then particleCount = 30 end
        local knockbackResist = enemy.knockbackResist or 0
        local hitDirX = enemy.lastHitDirX or 0
        local hitDirY = enemy.lastHitDirY or 0
        Effects.CreateDeathParticles(scene_, posX, posY, enemy.scale, def.glowColor, particleCount, knockbackResist, hitDirX, hitDirY)
        
        Audio.PlayExplosion(enemy.isBoss)
        
        if enemy.isBoss then
            Effects.TriggerScreenShake(0.5, 0.4)
        end
    end
    
    Enemy.onBurnDamage = function(enemy, damage)
        Effects.CreateDamageNumber(enemy.node.position.x, enemy.node.position.y + 0.3, damage, false, nil, false)
    end
    
    Enemy.onBossSpawn = function(bossEnemy, spawnType, count)
        Audio.PlayBossSpawn()
        local bossX, bossY = bossEnemy.node.position.x, bossEnemy.node.position.y
        local area = Settings.BattleArea
        
        for i = 1, count do
            local angle = (i / count) * math.pi * 2 + math.random() * 0.5
            local dist = 3 + math.random() * 2
            local spawnX = Math.Clamp(bossX + math.cos(angle) * dist, area.MinX + 1, area.MaxX - 1)
            local spawnY = Math.Clamp(bossY + math.sin(angle) * dist, area.MinY + 1, area.MaxY - 1)
            
            local scaledStats = Battle.ScaleEnemyStats(Enemies.Get(spawnType))
            Enemy.Create(scene_, spawnType, spawnX, spawnY, scaledStats)
            Effects.CreateExplosion(scene_, spawnX, spawnY, 0.5, 0.3, {r = 0.4, g = 0.9, b = 0.3})
        end
    end
    
    Enemy.onBossPhaseChange = function(bossEnemy, newPhase, phaseName)
        -- 检查是否需要静默（第20波的小Boss不显示阶段变化提示）
        local Waves = require("config.waves")
        local waveConfig = Waves.Get(Battle.currentWave)
        local isSilent = false
        
        if waveConfig and waveConfig.silentAdditionalBosses then
            -- 如果这个Boss不是主Boss类型，则静默
            if bossEnemy.type ~= waveConfig.bossType then
                isSilent = true
            end
        end
        
        if not isSilent then
            Overlays.ShowBossPhaseAnnouncement(phaseName)
            Audio.PlayBossPhase()
        end
        
        Effects.TriggerScreenShake(0.3, 0.2)
        Effects.CreateExplosion(scene_, bossEnemy.node.position.x, bossEnemy.node.position.y, 1.5, 0.5, {r = 0.4, g = 0.9, b = 0.3})
    end
    
    Enemy.onExplode = function(x, y, radius, damage, enemyInfo)
        local playerX, playerY = Player.GetPosition()
        local dist = Math.Distance(x, y, playerX, playerY)
        
        if dist < radius then
            local actualDamage, result = Game.TakeDamage(damage, enemyInfo)
            if result == "dodge" then
                Effects.CreateDamageNumber(playerX, playerY + 1, 0, false, "MISS")
            elseif result == "shield" then
                Effects.CreateDamageNumber(playerX, playerY + 1, 0, false, "SHIELD")
            elseif actualDamage > 0 then
                Effects.CreateDamageNumber(playerX, playerY + 1, actualDamage, false)
            end
        end
        
        -- 使用爆浆特效（自爆虫的绿色爆浆效果）
        local explosionColor = enemyInfo.explosionColor or {r = 0.2, g = 0.9, b = 0.1}
        Effects.CreateSplatterEffect(scene_, x, y, radius, explosionColor)
        Effects.TriggerScreenShake(0.2, 0.2)
    end
    
    Enemy.onHeal = function(healerX, healerY, targetX, targetY, amount)
        Effects.CreateExplosion(scene_, targetX, targetY, 0.3, 0.3, {r = 0.3, g = 1.0, b = 0.4})
        Effects.CreateDamageNumber(targetX, targetY + 0.5, amount, false, "+" .. amount)
    end
    
    Enemy.onShoot = function(enemy, targetX, targetY)
        local pos = enemy.node.position
        local color = enemy.glowColor or {r = 1.0, g = 0.4, b = 0.2}
        local enemyInfo = {id = enemy.id, name = enemy.name, projectileType = enemy.projectileType}
        
        -- 获取弹幕配置（优先使用当前阶段的配置）
        local barrage = nil
        if enemy.bossPhases and enemy.currentPhase then
            local phase = enemy.bossPhases[enemy.currentPhase]
            if phase and phase.barrage then
                barrage = phase.barrage
            end
        end
        -- 如果阶段没有配置，使用基础弹幕配置
        if not barrage and enemy.barrage then
            barrage = enemy.barrage
        end
        
        -- 如果有弹幕配置，使用弹幕模式
        if barrage then
            local bulletCount = barrage.bulletCount or 8
            local bulletSpeed = barrage.bulletSpeed or 10
            local bulletDamage = barrage.bulletDamage or (enemy.damage or 10)
            local rotationOffset = barrage.rotationOffset or 15
            
            -- 初始化弹幕旋转角度
            enemy.barrageAngle = enemy.barrageAngle or 0
            
            local barrageType = barrage.type or "ring"
            
            if barrageType == "ring" then
                -- 环形弹幕：360度均匀发射
                local angleStep = 360 / bulletCount
                for i = 0, bulletCount - 1 do
                    local angle = math.rad(enemy.barrageAngle + i * angleStep)
                    local dx = math.cos(angle)
                    local dy = math.sin(angle)
                    Projectile.CreateEnemyProjectile(scene_, pos.x, pos.y, dx, dy, bulletSpeed, bulletDamage, color, enemyInfo)
                end
                enemy.barrageAngle = enemy.barrageAngle + rotationOffset
                
            elseif barrageType == "spiral" then
                -- 螺旋弹幕：每次发射少量子弹，角度持续偏移
                local arms = barrage.arms or 3
                local angleStep = 360 / arms
                for i = 0, arms - 1 do
                    local angle = math.rad(enemy.barrageAngle + i * angleStep)
                    local dx = math.cos(angle)
                    local dy = math.sin(angle)
                    Projectile.CreateEnemyProjectile(scene_, pos.x, pos.y, dx, dy, bulletSpeed, bulletDamage, color, enemyInfo)
                end
                enemy.barrageAngle = enemy.barrageAngle + rotationOffset
                
            elseif barrageType == "fan" then
                -- 扇形弹幕：向玩家方向发射扇形
                local baseAngle = math.atan2(targetY - pos.y, targetX - pos.x)
                local spreadAngle = barrage.spreadAngle or 60
                local halfSpread = math.rad(spreadAngle / 2)
                local angleStep = spreadAngle / (bulletCount - 1)
                for i = 0, bulletCount - 1 do
                    local angle = baseAngle - halfSpread + math.rad(i * angleStep)
                    local dx = math.cos(angle)
                    local dy = math.sin(angle)
                    Projectile.CreateEnemyProjectile(scene_, pos.x, pos.y, dx, dy, bulletSpeed, bulletDamage, color, enemyInfo)
                end
                
            elseif barrageType == "flower" then
                -- 花形弹幕：多个花瓣，每个花瓣是扇形
                local petals = barrage.petals or 4
                local petalAngle = 360 / petals
                local bulletsPerPetal = math.floor(bulletCount / petals)
                local spreadAngle = barrage.spreadAngle or 30
                
                for p = 0, petals - 1 do
                    local petalBaseAngle = math.rad(enemy.barrageAngle + p * petalAngle)
                    local halfSpread = math.rad(spreadAngle / 2)
                    local angleStep = spreadAngle / math.max(1, bulletsPerPetal - 1)
                    
                    for i = 0, bulletsPerPetal - 1 do
                        local angle = petalBaseAngle - halfSpread + math.rad(i * angleStep)
                        local dx = math.cos(angle)
                        local dy = math.sin(angle)
                        Projectile.CreateEnemyProjectile(scene_, pos.x, pos.y, dx, dy, bulletSpeed, bulletDamage, color, enemyInfo)
                    end
                end
                enemy.barrageAngle = enemy.barrageAngle + rotationOffset
            end
        else
            -- 普通单发射击
            local dx, dy = Math.Normalize(targetX - pos.x, targetY - pos.y)
            local speed = enemy.projectileSpeed or 15
            local damage = enemy.damage or 5
            Projectile.CreateEnemyProjectile(scene_, pos.x, pos.y, dx, dy, speed, damage, color, enemyInfo)
        end
    end
    
    -- ========================================================================
    -- 无人机系统回调
    -- ========================================================================
    
    Drone.onFire = function(drone, targetX, targetY, damage, isCrit, aoeRadius)
        local pos = drone.node.position
        local dirX, dirY = Math.Normalize(targetX - pos.x, targetY - pos.y)
        local playerStats = {
            piercing = Game.player.piercing or 0,
            piercingDamage = Game.player.piercingDamage or 1.0,
            explosionRangeMultiplier = Game.player.explosionRangeMultiplier or 1.0
        }
        Projectile.Create(scene_, pos.x, pos.y, dirX, dirY, drone.weaponId, drone.tier, damage, isCrit, drone.target, playerStats)
    end
    
    -- ========================================================================
    -- 特效系统回调
    -- ========================================================================
    
    Effects.onWarpComplete = function(x, y, enemyType)
        local scaledStats = Battle.ScaleEnemyStats(Enemies.Get(enemyType))
        Enemy.Create(scene_, enemyType, x, y, scaledStats)
        -- 移除爆炸圆圈，传送门消失后直接生成敌人
    end
    
    -- ========================================================================
    -- 拾取系统回调
    -- ========================================================================
    
    Pickup.onCollect = function(pickup)
        if pickup.type == "crystal" then
            Game.AddCrystals(pickup.amount)
            Audio.PlayPickup("crystal")
        elseif pickup.type == "health" then
            Game.Heal(pickup.amount)
            Audio.PlayPickup("health")
        end
    end
    
    -- ========================================================================
    -- 残骸系统回调
    -- ========================================================================
    
    local DebrisMod, DebrisPickupMod = GetDebrisModules()
    
    -- 残骸生成回调
    Battle.onSpawnDebris = function(waveNum, visibleArea)
        DebrisMod.SpawnDebris(scene_, waveNum, visibleArea)
    end
    
    -- 清除残骸回调
    Battle.clearAllDebris = function()
        DebrisMod.ClearAll()
        DebrisPickupMod.ClearUncollected()
    end
    
    -- 残骸被摧毁回调
    DebrisMod.onDestroy = function(debris)
        -- 添加爆炸粒子效果（与敌人相同的碎片飞散效果）
        local particleCount = 10
        local color = {r = 1.0, g = 0.6, b = 0.2}  -- 橙黄色
        Effects.CreateDeathParticles(scene_, debris.x, debris.y, 1.2, color, particleCount, 0, 0, 0)
        Audio.PlayExplosion(false)
    end
    
    -- 残骸掉落护盾电池回调
    DebrisMod.onDropShieldBattery = function(x, y)
        DebrisPickupMod.CreateShieldBattery(scene_, x, y)
    end
    
    -- 残骸掉落晶体回调（直接获得）
    DebrisMod.onDropCrystals = function(x, y, amount)
        Game.AddCrystals(amount)
        Audio.PlayPickup("crystal")
    end
    
    -- 残骸掉落补给箱回调
    DebrisMod.onDropSupplyCrate = function(x, y, crateData)
        DebrisPickupMod.CreateSupplyCrate(scene_, x, y, crateData)
    end
    
    -- 残骸获取玩家位置回调
    DebrisMod.getPlayerPosition = function()
        return Player.GetPosition()
    end
    
    -- 残骸道具数量回调（Brotato 公式: 0.50 + 0.33 × item-count）
    DebrisMod.getDebrisItemCount = function()
        -- 检查玩家是否有残骸相关道具（残骸探测器等）
        -- 目前返回0，等道具系统实现后再连接
        return Game.player.debrisItemCount or 0
    end
    
    -- 能量核心护盾恢复回调
    DebrisPickupMod.onShieldRestore = function(amount)
        Game.Heal(amount)
    end
    
    -- 收集护盾电池回调
    DebrisPickupMod.onCollectBattery = function(battery)
        Audio.PlayPickup("health")  -- 使用治疗音效
    end
    
    -- 收集补给箱回调
    DebrisPickupMod.onCollectCrate = function(crate)
        Audio.PlayUIClick()
    end
    
    -- ========================================================================
    -- 商店系统回调
    -- ========================================================================
    
    Shop.getPlayer = function() return Game.player end
    Shop.onSpendCrystals = function(amount) return Game.SpendCrystals(amount) end
    
    Shop.onPurchaseWeapon = function(weaponId, tier)
        local weaponDef = Weapons.Get(weaponId)
        if not weaponDef then
            return false, "武器定义不存在"
        end
        
        local freeSlot = Player.GetFreeSlot(Game.player.maxWeaponSlots)
        if not freeSlot then
            return false, "没有空闲武器槽"
        end
        
        local weapon = Player.AddWeapon(weaponId, freeSlot, tier, Game.player.shipConfig)
        if not weapon then
            return false, "武器添加失败"
        end
        
        if weaponDef.isDrone then
            local playerX, playerY = Player.GetPosition()
            local droneCount = weaponDef.droneCount or 1
            local existingCount = Drone.GetCountByWeapon(weaponId)
            
            for i = 1, droneCount do
                Drone.Create(scene_, weaponId, tier, playerX, playerY, existingCount + i - 1)
            end
            weapon.isDrone = true
        end
        
        Audio.PlayPurchase()
        Game.RecalculateWeaponEffects()
        SaveManager.OnShopAction(Game)
        
        return true, "购买成功"
    end
    
    Shop.onPurchaseModule = function(moduleId)
        local moduleDef = Modules.GetById(moduleId)
        if moduleDef then
            moduleDef.effect(Game.player)
            Game.player.modules[moduleId] = (Game.player.modules[moduleId] or 0) + 1
            Audio.PlayPurchase()
            SaveManager.OnShopAction(Game)
        end
    end
    
    -- ========================================================================
    -- 舰桥升级回调
    -- ========================================================================
    
    BridgeUpgrade.getPlayer = function() return Game.player end
    BridgeUpgrade.getCurrentWave = function() return Battle.currentWave end
    BridgeUpgrade.spendCrystals = function(amount) return Game.SpendCrystals(amount) end
    BridgeUpgrade.playUpgradeSound = function() Audio.PlayUpgrade() end
    BridgeUpgrade.playClickSound = function() Audio.PlayUIClick() end
    
    -- ========================================================================
    -- 输入处理器回调
    -- ========================================================================
    
    InputHandler.onBackToMainMenu = function()
        print("[Callbacks] onBackToMainMenu called")
        InputHandler.SetShipSelectActive(false)
        InputHandler.SetWeaponSelectActive(false)
        ShipSelectUI.Hide()
        WeaponSelectUI.Hide()
        -- 使用 GameStateManager 显示主菜单（包含正确的回调）
        local GameStateManager = require("core.GameStateManager")
        GameStateManager.ShowMainMenu()
        print("[Callbacks] onBackToMainMenu complete")
    end
    
    InputHandler.onBackToShipSelect = function()
        InputHandler.SetWeaponSelectActive(false)
        InputHandler.SetShipSelectActive(true)
        WeaponSelectUI.Hide()
        ShipSelectUI.Show(function(ship)
            InputHandler.SetShipSelectActive(false)
            InputHandler.SetWeaponSelectActive(true)
            InputHandler.SetSelectedShipConfig(ship)
            WeaponSelectUI.Show(ship, function(weapon)
                InputHandler.SetWeaponSelectActive(false)
                StartGameWithShip(ship, weapon.id)
            end)
        end)
    end
    
    InputHandler.onExitShop = function() ExitShop() end
    InputHandler.onRestart = function() RestartGame() end
    InputHandler.onBridgeUpgradeSelect = function(index) SelectBridgeUpgrade(index) end
    InputHandler.onBridgeUpgradeRefresh = function() BridgeUpgrade.Refresh() end
    
    -- ========================================================================
    -- 游戏系统回调
    -- ========================================================================
    
    Game.onPlayerDeath = function(onComplete)
        Audio.PlayExplosion(true)
        Effects.TriggerScreenShake(0.6, 0.5)
        Player.StartDeathAnimation(scene_, onComplete)
    end
    
    Game.onBeforeGameOver = function()
        if TutorialManager.NeedsFirstDefeatDialogue() then
            StartTutorialFirstDefeat()
            return true
        end
        return false
    end
end

return Callbacks
