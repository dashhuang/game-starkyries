-- ============================================================================
-- 星河战姬 Starkyries - 游戏主循环
-- 负责武器更新、碰撞检测、实体更新调度
-- ============================================================================

local Settings = require("config.settings")
local Weapons = require("config.weapons")
local Enemies = require("config.enemies")
local Math = require("utils.Math")

local GameLoop = {}

-- ============================================================================
-- 依赖模块（延迟加载避免循环依赖）
-- ============================================================================
local Player, Enemy, Projectile, Pickup, Drone, Effects, Audio, Game, Debris, DebrisPickup

local function LoadDependencies()
    if not Player then
        Player = require("entities.Player")
        Enemy = require("entities.Enemy")
        Projectile = require("entities.Projectile")
        Pickup = require("entities.Pickup")
        Drone = require("entities.Drone")
        Effects = require("entities.Effects")
        Audio = require("core.Audio")
        Game = require("core.Game")
        Debris = require("entities.Debris")
        DebrisPickup = require("entities.DebrisPickup")
    end
end

-- ============================================================================
-- 武器系统更新
-- ============================================================================

-- 本帧已被同类武器瞄准的敌人（用于智能目标分配）
local frameTargetedEnemies = {}

-- 同类武器轮询发射控制（weaponId -> {nextIndex, lastFireTime}）
local weaponFireQueue = {}
-- 武器系统内部时间（用于发射间隔计算）
local weaponSystemTime = 0

-- 预分配可复用表（避免每帧 GC）
local _nearbyTargets = {}  -- 复用的目标列表

function GameLoop.UpdateWeapons(dt, scene)
    LoadDependencies()
    
    local playerX, playerY = Player.GetPosition()
    local shipConfig = Game.player.shipConfig
    if not shipConfig then return end
    
    -- 更新武器系统时间
    weaponSystemTime = weaponSystemTime + dt
    
    -- 每帧开始时清空目标追踪表（复用表，避免 GC）
    for k in pairs(frameTargetedEnemies) do
        frameTargetedEnemies[k] = nil
    end
    
    for _, weapon in ipairs(Game.player.weapons) do
        local weaponDef = Weapons.Get(weapon.id)
        if not weaponDef then goto continue end
        
        -- 跳过无人机武器（由 Drone 模块处理）
        if weaponDef.isDrone then goto continue end
        
        -- 获取武器世界位置
        -- 武器槽位配置: x=前后方向, y=高度(2D忽略), z=左右方向
        local slot = shipConfig.weaponSlots[weapon.slotIndex]
        if not slot then goto continue end
        
        local slotX = slot.x
        local slotZ = slot.z or 0  -- 左右偏移（用于2D的Y坐标）
        if not Game.player.facingRight then
            slotX = -slotX
            slotZ = -slotZ  -- 翻转左右方向
        end
        local weaponX = playerX + slotX
        local weaponY = playerY + slotZ  -- 使用 z（左右）而非 y（高度）
        
        -- 计算有效射程
        -- 弹道套装：射程加成（rangeBonus是绝对米数，如0.3表示+0.3米）
        -- 优先使用tierRange（如追踪导弹 10/11/12/14m），否则用基础range
        local baseRange = weaponDef.range
        if weaponDef.tierRange and weaponDef.tierRange[weapon.tier] then
            baseRange = weaponDef.tierRange[weapon.tier]
        end
        local effectiveRange = baseRange * (Game.player.rangeMultiplier or 1.0) + (Game.player.rangeBonus or 0)
        
        -- 智能目标分配：优先选择未被同类武器瞄准的敌人
        local target = nil
        local weaponTypeKey = weapon.id  -- 用武器ID区分类型
        
        -- 获取射程内所有目标（敌人+残骸，按距离排序）
        -- 复用预分配表，先清空
        local targetCount = 0
        
        -- 添加敌人
        local nearbyEnemies = Enemy.FindNearby(weaponX, weaponY, effectiveRange)
        for _, data in ipairs(nearbyEnemies) do
            targetCount = targetCount + 1
            local entry = _nearbyTargets[targetCount]
            if entry then
                entry.target = data.enemy
                entry.dist = data.dist
            else
                _nearbyTargets[targetCount] = {target = data.enemy, dist = data.dist}
            end
        end
        
        -- 添加残骸（与敌人相同优先级）
        local nearbyDebris = Debris.FindInRange(weaponX, weaponY, effectiveRange)
        for _, data in ipairs(nearbyDebris) do
            targetCount = targetCount + 1
            local entry = _nearbyTargets[targetCount]
            if entry then
                entry.target = data.debris
                entry.dist = data.dist
            else
                _nearbyTargets[targetCount] = {target = data.debris, dist = data.dist}
            end
        end
        
        -- 清除多余条目（本次目标数可能比上次少）
        for i = targetCount + 1, #_nearbyTargets do
            _nearbyTargets[i] = nil
        end
        
        -- 按距离排序
        table.sort(_nearbyTargets, function(a, b) return a.dist < b.dist end)
        
        if targetCount > 0 then
            -- 初始化该武器类型的目标追踪表
            if not frameTargetedEnemies[weaponTypeKey] then
                frameTargetedEnemies[weaponTypeKey] = {}
            end
            local targetedByThisType = frameTargetedEnemies[weaponTypeKey]
            
            -- 优先选择未被同类武器瞄准的目标
            for i = 1, targetCount do
                local targetData = _nearbyTargets[i]
                local t = targetData.target
                if t and t.hp and t.hp > 0 and not targetedByThisType[t] then
                    target = t
                    break
                end
            end
            
            -- 如果所有目标都被瞄准了，选择最近的（允许伤害叠加）
            if not target then
                local first = _nearbyTargets[1]
                if first and first.target and first.target.hp and first.target.hp > 0 then
                    target = first.target
                end
            end
            
            -- 标记该目标被此武器类型瞄准
            if target then
                targetedByThisType[target] = true
            end
        end
        
        -- 更新炮塔朝向（如果最近没有发射导弹）
        -- 导弹发射后有短暂的"保持方向"时间，让炮管指向实际发射方向
        if weapon.aimLockTime then
            weapon.aimLockTime = weapon.aimLockTime - dt
            if weapon.aimLockTime <= 0 then
                weapon.aimLockTime = nil
            end
        end
        
        if target and not weapon.aimLockTime then
            local targetPos = target.node.position
            Player.AimWeaponAt(weapon, targetPos.x, targetPos.y)
        end
        
        -- 冷却
        weapon.cooldown = weapon.cooldown - dt
        
        -- 射击（带轮询控制，同类武器均匀发射）
        if weapon.cooldown <= 0 and target then
            -- 初始化该武器类型的发射队列
            if not weaponFireQueue[weapon.id] then
                weaponFireQueue[weapon.id] = {
                    lastFireTime = nil,   -- nil表示本帧还没有武器发射过
                    frameCount = 0,       -- 当前帧计数
                }
            end
            local queue = weaponFireQueue[weapon.id]
            
            -- 计算同类武器数量和最小发射间隔
            local sameWeaponCount = 0
            for _, w in ipairs(Game.player.weapons) do
                if w.id == weapon.id then
                    sameWeaponCount = sameWeaponCount + 1
                end
            end
            
            -- 最小发射间隔 = CD / 武器数量（确保均匀分布）
            local baseCooldown = weaponDef.cooldown
            if weaponDef.tierCooldown and weaponDef.tierCooldown[weapon.tier] then
                baseCooldown = weaponDef.tierCooldown[weapon.tier]
            end
            local minInterval = baseCooldown / math.max(sameWeaponCount, 1)
            
            -- 检查是否可以发射
            local canFire = false
            
            if queue.lastFireTime == nil then
                -- 本帧还没有同类武器发射过，第一把可以发射
                canFire = true
            else
                -- 检查距离上次发射是否已过最小间隔
                local timeSinceLastFire = weaponSystemTime - queue.lastFireTime
                if timeSinceLastFire >= minInterval then
                    canFire = true
                end
            end
            
            if canFire then
                GameLoop.FireWeapon(scene, weapon, weaponDef, weaponX, weaponY, target)
                queue.lastFireTime = weaponSystemTime
            else
                -- 还没轮到，保持 cooldown 在 0，等待下一帧
                weapon.cooldown = 0
            end
        end
        
        ::continue::
    end
end

-- ============================================================================
-- 武器射击
-- ============================================================================

function GameLoop.FireWeapon(scene, weapon, weaponDef, weaponX, weaponY, target)
    LoadDependencies()
    
    -- 触发炮管闪光
    Player.TriggerWeaponFlash(weapon)
    
    -- fireRate = 1 / cooldown，再乘以有效射速倍率（包含模块效果）
    -- 优先使用tierCooldown（如追踪导弹T4攻速0.52s），否则用基础cooldown
    local baseCooldown = weaponDef.cooldown
    if weaponDef.tierCooldown and weaponDef.tierCooldown[weapon.tier] then
        baseCooldown = weaponDef.tierCooldown[weapon.tier]
    end
    local baseFireRate = 1.0 / baseCooldown
    local effectiveFireRate = Game.GetEffectiveFireRateMultiplier()
    local fireRate = baseFireRate * effectiveFireRate
    weapon.cooldown = 1.0 / fireRate
    
    -- 计算伤害（使用有效伤害乘数，包含所有模块效果）
    local effectiveDamageMult = Game.GetEffectiveDamageMultiplier()
    local baseDamage
    if weaponDef.tierDamage and weaponDef.tierDamage[weapon.tier] then
        baseDamage = weaponDef.tierDamage[weapon.tier] * effectiveDamageMult
    else
        local tierMult = Settings.WeaponTierMultiplier[weapon.tier] or 1.0
        baseDamage = weaponDef.damage * tierMult * effectiveDamageMult
    end
    
    -- 武器类型伤害加成（三大类：近程/弹道/能量，工程类无加成）
    -- 专精伤害是固定值加成，不是百分比
    local weaponType = weaponDef.type
    if weaponType == Weapons.Types.FORCE_FIELD then
        -- 近战强化：力场
        baseDamage = baseDamage + (Game.player.meleeDamageBonus or 0)
    elseif weaponType == Weapons.Types.MACHINEGUN or weaponType == Weapons.Types.MISSILE then
        -- 弹道计算机：机炮+导弹
        baseDamage = baseDamage + (Game.player.ballisticDamageBonus or 0)
    elseif weaponType == Weapons.Types.ARC or weaponType == Weapons.Types.LASER then
        -- 能量增幅：电弧+激光
        baseDamage = baseDamage + (Game.player.energyDamageBonus or 0)
    end
    -- CARRIER (工程类/舰载机) 不受武器类型伤害加成影响
    
    -- 脉冲套装：固定伤害加成（所有武器类型都受益）
    baseDamage = baseDamage + (Game.player.flatDamageBonus or 0)
    
    -- 狂战士加成
    baseDamage = baseDamage * Game.GetBerserkerBonus()
    
    -- 协同武器加成（同类武器越多伤害越高）
    if weaponDef.synergyBonus and weaponDef.synergyBonus > 0 then
        local sameWeaponCount = 0
        for _, w in ipairs(Game.player.weapons) do
            if w.id == weapon.id then
                sameWeaponCount = sameWeaponCount + 1
            end
        end
        -- 第一把武器无加成，每多一把+synergyBonus
        if sameWeaponCount > 1 then
            local synergyMult = 1.0 + weaponDef.synergyBonus * (sameWeaponCount - 1)
            baseDamage = baseDamage * synergyMult
        end
    end
    
    -- 暴击判定
    -- 最终暴击率 = 武器基础暴击率 + 玩家暴击率属性 + 处决者加成
    local finalCritChance = (weaponDef.critChance or 0) + Game.player.critChance
    
    -- 处决者：敌舰护盾<20%时暴击率+30%
    if target and target.hp and target.maxHp then
        local enemyHealthRatio = target.hp / target.maxHp
        finalCritChance = finalCritChance + Game.GetExecutionerCritBonus(enemyHealthRatio)
    end
    
    local isCrit = math.random() < finalCritChance
    local damage = baseDamage
    if isCrit then
        -- 暴击倍率 = 武器基础倍率(默认200%) + 玩家暴击伤害加成(模块等)
        -- 玩家加成 = critDamage - 基础值1.5
        local baseCritMult = weaponDef.critMultiplier or 2.0
        local playerCritBonus = (Game.player.critDamage or 1.5) - 1.5
        local finalCritMult = baseCritMult + playerCritBonus
        damage = damage * finalCritMult
    end
    
    -- 消耗爆发模式（下次攻击+100%伤害一次性效果）
    Game.ConsumeBurstMode()
    
    -- 计算射击方向
    local targetPos = target.node.position
    local aimX, aimY = targetPos.x, targetPos.y
    
    -- 机炮武器添加射击随机性（±0.7米散布）
    if weaponDef.type == Weapons.Types.MACHINEGUN then
        local spread = 0.7
        aimX = aimX + (math.random() * 2 - 1) * spread
        aimY = aimY + (math.random() * 2 - 1) * spread
    end
    
    local angle = Math.AngleTo(weaponX, weaponY, aimX, aimY)
    local dirX = math.cos(angle)
    local dirY = math.sin(angle)
    
    -- 根据武器类型创建不同的攻击效果
    local isForceField = (weaponDef.type == Weapons.Types.FORCE_FIELD or 
                          weaponDef.type == Weapons.Types.ARC)
    
    -- 弹道套装：射程加成（rangeBonus是绝对米数，如0.3表示+0.3米）
    local rangeMultiplier = Game.player.rangeMultiplier or 1.0
    local rangeBonus = Game.player.rangeBonus or 0
    
    -- 计算到目标的距离
    local distToTarget = Math.Distance(weaponX, weaponY, targetPos.x, targetPos.y)
    
    -- 近距离直接命中阈值（当敌人贴脸时，子弹可能飞偏或穿过敌人）
    local directHitThreshold = 1.5  -- 1.5米内直接命中
    
    if isForceField then
        GameLoop.FireForceField(scene, weapon, weaponDef, weaponX, weaponY, targetPos, damage, isCrit)
    elseif weaponDef.instant then
        -- 即时命中武器（激光）：从炮管位置发射
        -- 优先使用tierRange
        local baseRange = weaponDef.range
        if weaponDef.tierRange and weaponDef.tierRange[weapon.tier] then
            baseRange = weaponDef.tierRange[weapon.tier]
        end
        local effectiveRange = baseRange * rangeMultiplier + rangeBonus
        GameLoop.FireLaser(scene, weapon, weaponDef, weaponX, weaponY, dirX, dirY, damage, isCrit, effectiveRange)
    elseif weaponDef.instantChain then
        -- 即时闪电连接武器（离子连锁炮）：第一发也是闪电效果
        GameLoop.FireInstantChain(scene, weapon, weaponDef, weaponX, weaponY, target, damage, isCrit)
    elseif weaponDef.pierceAll then
        -- 穿透全体武器（等离子喷射器）：直线穿透所有敌舰
        GameLoop.FirePierceAll(scene, weapon, weaponDef, weaponX, weaponY, dirX, dirY, damage, isCrit)
    elseif distToTarget < directHitThreshold then
        -- 近距离直接命中：跳过子弹，直接造成伤害
        Audio.PlayShoot(weaponDef.type)
        local actualDamage
        if target.isDebris then
            -- 残骸目标
            actualDamage = Debris.Damage(target, damage, dirX, dirY)
        else
            -- 敌人目标
            actualDamage = Enemy.Damage(target, damage, Game.player.bossDamage, dirX, dirY)
        end
        Game.RecordDamage(actualDamage)  -- 记录实时DPS
        local hitX, hitY = targetPos.x, targetPos.y
        
        -- 命中特效
        Effects.CreateHitSpark(scene, hitX, hitY, weaponDef.color, isCrit)
        Audio.PlayHit(isCrit, weaponDef.type)
        Effects.CreateDamageNumber(hitX, hitY + 0.5, actualDamage, isCrit)
    else
        -- 其他武器：发射子弹（传入玩家穿透属性和爆炸范围加成）
        local playerStats = {
            piercing = Game.player.piercing or 0,
            piercingDamage = Game.player.piercingDamage or 1.0,
            explosionRangeMultiplier = Game.player.explosionRangeMultiplier or 1.0,
            targetDistance = distToTarget,  -- 传入目标距离，用于导弹曲线计算
        }
        local proj = Projectile.Create(scene, weaponX, weaponY, dirX, dirY, 
            weapon.id, weapon.tier, damage, isCrit, nil, playerStats)
        Audio.PlayShoot(weaponDef.type)
        
        -- 追踪导弹：根据实际发射方向更新炮塔朝向（因为导弹有曲线偏移）
        -- 只对 homing=true 的导弹生效，非追踪导弹直线飞行无需调整
        if proj and weaponDef.homing then
            local aimDist = 10  -- 用于计算瞄准点的距离
            local aimTargetX = weaponX + proj.dirX * aimDist
            local aimTargetY = weaponY + proj.dirY * aimDist
            Player.AimWeaponAt(weapon, aimTargetX, aimTargetY)
            -- 锁定炮塔方向一段时间，防止被下一帧的自动瞄准覆盖
            weapon.aimLockTime = 0.15  -- 保持0.15秒
        end
    end
    
    -- 能量吸收
    if math.random() < Game.player.energyAbsorb then
        local heal = math.ceil(damage * 0.1)
        Game.Heal(heal)
    end
end

-- ============================================================================
-- 力场/电弧武器射击
-- ============================================================================

function GameLoop.FireForceField(scene, weapon, weaponDef, weaponX, weaponY, targetPos, damage, isCrit)
    LoadDependencies()
    
    local allEnemies = Enemy.GetList()
    Audio.PlayShoot(weaponDef.type)
    
    local hitWeaponType = weaponDef.type
    local _, hitEnemies = Projectile.CreateForceFieldArc(
        scene, weaponX, weaponY, 
        targetPos.x, targetPos.y, 
        weapon.id, weapon.tier, damage, isCrit,
        allEnemies,
        function(enemy, dmg, crit)
            local enemyPos = enemy.node.position
            local hitDirX, hitDirY = Math.Normalize(enemyPos.x - weaponX, enemyPos.y - weaponY)
            local actualDamage = Enemy.Damage(enemy, dmg, Game.player.bossDamage, hitDirX, hitDirY)
            Game.RecordDamage(actualDamage)  -- 记录实时DPS
            Audio.PlayHit(crit, hitWeaponType)
            
            -- 伤害数字（在敌人位置显示）
            Effects.CreateDamageNumber(enemyPos.x, enemyPos.y + 0.5, actualDamage, crit)
            
            if weaponDef.knockback and weaponDef.knockback > 0 then
                local kbDirX, kbDirY = hitDirX, hitDirY
                local knockbackForce = weaponDef.knockback * 10
                Enemy.ApplyKnockback(enemy, knockbackForce, kbDirX, kbDirY)
            end
        end
    )
end

-- ============================================================================
-- 激光武器射击（即时命中）
-- ============================================================================

function GameLoop.FireLaser(scene, weapon, weaponDef, weaponX, weaponY, dirX, dirY, damage, isCrit, effectiveRange)
    LoadDependencies()
    
    Audio.PlayShoot(weaponDef.type)
    
    -- 射线检测（先检测再画光束，确保光束长度正确）
    local hitCount = 0
    local maxPierce = weaponDef.pierce or 0
    local beamRange = effectiveRange
    
    -- 收集射线路径上的所有敌人（按距离排序）
    local enemiesOnPath = {}
    for _, enemy in ipairs(Enemy.GetList()) do
        local pos = enemy.node.position
        local toEnemyX = pos.x - weaponX
        local toEnemyY = pos.y - weaponY
        local projDist = toEnemyX * dirX + toEnemyY * dirY
        
        if projDist > 0 and projDist <= beamRange then
            local perpX = toEnemyX - projDist * dirX
            local perpY = toEnemyY - projDist * dirY
            local perpDist = math.sqrt(perpX * perpX + perpY * perpY)
            local hitRadius = enemy.hitRadius or (enemy.scale * 1.2)  -- 使用配置的碰撞半径
            
            if perpDist < hitRadius then
                table.insert(enemiesOnPath, {enemy = enemy, dist = projDist})
            end
        end
    end
    
    table.sort(enemiesOnPath, function(a, b) return a.dist < b.dist end)
    
    -- 创建视觉光束（使用完整射程，展示贯穿效果）
    Projectile.CreateLaserBeam(scene, weaponX, weaponY, dirX, dirY,
        weapon.id, weapon.tier, isCrit, effectiveRange)
    
    -- 对路径上的敌人造成伤害
    for _, data in ipairs(enemiesOnPath) do
        local enemy = data.enemy
        local actualDamage = Enemy.Damage(enemy, damage, Game.player.bossDamage, dirX, dirY)
        Game.RecordDamage(actualDamage)  -- 记录实时DPS
        local hitX = enemy.node.position.x
        local hitY = enemy.node.position.y
        
        Effects.CreateHitSpark(scene, hitX, hitY, weaponDef.color, isCrit)
        Audio.PlayHit(isCrit, weaponDef.type)
        Effects.CreateDamageNumber(hitX, hitY + 0.5, actualDamage, isCrit)
        
        hitCount = hitCount + 1
        if maxPierce > 0 and hitCount > maxPierce then
            break
        end
    end
end

-- ============================================================================
-- 碰撞检测
-- ============================================================================

function GameLoop.CheckCollisions(scene)
    LoadDependencies()
    
    -- 子弹命中敌人
    Projectile.CheckCollisions(Enemy.GetList(), function(proj, enemy)
        GameLoop.HandleProjectileHit(scene, proj, enemy)
    end)
    
    -- 子弹命中残骸
    Projectile.CheckCollisions(Debris.GetList(), function(proj, debris)
        GameLoop.HandleProjectileHitDebris(scene, proj, debris)
    end)
    
    -- 敌人碰撞玩家
    if Game.player.invincibleTime <= 0 then
        local playerX, playerY = Player.GetPosition()
        local hitEnemy = Enemy.CheckCollisionWithPlayer(playerX, playerY, Settings.Combat.PlayerHitRadius)
        
        if hitEnemy then
            -- 传递敌人信息用于死亡统计
            local enemyInfo = {id = hitEnemy.id, name = hitEnemy.name}
            local actualDamage, result = Game.TakeDamage(hitEnemy.damage, enemyInfo)
            
            if result == "dodge" then
                Effects.CreateDamageNumber(playerX, playerY + 1, 0, false, "MISS")
            else
                Effects.CreateDamageNumber(playerX, playerY + 1, actualDamage, false, nil, true)
                Effects.TriggerScreenShake(0.3, 0.2)
                Audio.PlayPlayerHit()
            end
        end
        
        -- 敌人子弹命中玩家
        Projectile.CheckEnemyCollisions(playerX, playerY, Settings.Combat.PlayerHitRadius, function(proj, damage)
            -- 传递子弹发射者信息用于死亡统计
            local actualDamage, result = Game.TakeDamage(damage, proj.enemyInfo)
            
            if result == "dodge" then
                Effects.CreateDamageNumber(playerX, playerY + 1, 0, false, "MISS")
            else
                Effects.CreateDamageNumber(playerX, playerY + 1, actualDamage, false, nil, true)
                Effects.TriggerScreenShake(0.2, 0.15)
                Audio.PlayPlayerHit()
            end
        end)
    end
end

-- ============================================================================
-- 子弹命中处理
-- ============================================================================

function GameLoop.HandleProjectileHit(scene, proj, enemy)
    LoadDependencies()
    
    -- 传入子弹方向用于死亡粒子扩散
    local actualDamage = Enemy.Damage(enemy, proj.damage, Game.player.bossDamage, proj.dirX, proj.dirY)
    Game.RecordDamage(actualDamage)  -- 记录实时DPS
    local hitX = enemy.node.position.x
    local hitY = enemy.node.position.y
    
    -- 命中火花特效
    local weaponDef = Weapons.Get(proj.weaponId)
    local sparkColor = weaponDef and weaponDef.color or {r = 1, g = 0.8, b = 0.3}
    Effects.CreateHitSpark(scene, hitX, hitY, sparkColor, proj.isCrit)
    
    -- 播放命中音效
    local weaponType = weaponDef and weaponDef.type or "force_field"
    Audio.PlayHit(proj.isCrit, weaponType)
    
    -- 伤害数字
    Effects.CreateDamageNumber(hitX, hitY + 0.5, actualDamage, proj.isCrit)
    
    -- AOE伤害
    if proj.aoeRadius and proj.aoeRadius > 0 then
        for _, e in ipairs(Enemy.GetList()) do
            if e ~= enemy then
                local dist = Math.Distance(proj.x, proj.y, e.node.position.x, e.node.position.y)
                if dist < proj.aoeRadius then
                    local aoeDamage = proj.damage * 0.7
                    local aoeActualDamage = Enemy.Damage(e, aoeDamage, Game.player.bossDamage, proj.dirX, proj.dirY)
                    Game.RecordDamage(aoeActualDamage)  -- 记录实时DPS
                    Effects.CreateDamageNumber(e.node.position.x, e.node.position.y + 0.5,
                        aoeActualDamage, false)
                end
            end
        end
        
        -- 使用集束炸弹风格的2D圆盘爆炸效果
        -- 视觉半径使用较小值（类似集束炸弹的 clusterRadius = 0.5），伤害范围不变
        local visualRadius = math.min(proj.aoeRadius * 0.3, 1.0)
        Projectile.CreateExplosionEffect(scene, proj.x, proj.y, visualRadius, weaponDef.color)
    end
    
    -- 链式攻击
    if weaponDef and weaponDef.chainCount and weaponDef.chainCount > 0 then
        GameLoop.HandleChainAttack(scene, weaponDef, hitX, hitY, proj.damage, enemy, proj.tier)
    end
    
    -- 燃烧DOT
    if weaponDef and weaponDef.burnDamage and weaponDef.burnDamage > 0 then
        local burnDuration = weaponDef.burnDuration or 3.0
        Enemy.ApplyBurn(enemy, weaponDef.burnDamage, burnDuration)
    end
    
    -- 击退效果（使用子弹飞行方向，更稳定）
    if weaponDef and weaponDef.knockback and weaponDef.knockback > 0 then
        local knockbackForce = weaponDef.knockback * 10
        Enemy.ApplyKnockback(enemy, knockbackForce, proj.dirX, proj.dirY)
    end
end

-- ============================================================================
-- 子弹命中残骸处理
-- ============================================================================

function GameLoop.HandleProjectileHitDebris(scene, proj, debris)
    LoadDependencies()
    
    -- 造成伤害
    local actualDamage = Debris.Damage(debris, proj.damage, proj.dirX, proj.dirY)
    local hitX = debris.x
    local hitY = debris.y
    
    -- 命中火花特效
    local weaponDef = Weapons.Get(proj.weaponId)
    local sparkColor = weaponDef and weaponDef.color or {r = 1, g = 0.8, b = 0.3}
    Effects.CreateHitSpark(scene, hitX, hitY, sparkColor, proj.isCrit)
    
    -- 播放命中音效
    local weaponType = weaponDef and weaponDef.type or "force_field"
    Audio.PlayHit(proj.isCrit, weaponType)
    
    -- 伤害数字
    Effects.CreateDamageNumber(hitX, hitY + 0.5, actualDamage, proj.isCrit)
end

-- ============================================================================
-- 喷射器武器（等离子喷射器专用）
-- ============================================================================

-- ============================================================================
-- 穿透全体武器（等离子喷射器 - 对标 Brotato Flamethrower）
-- 设计：直线穿透所有敌舰，每个命中独立触发能量吸收
-- ============================================================================

function GameLoop.FirePierceAll(scene, weapon, weaponDef, weaponX, weaponY, dirX, dirY, damage, isCrit)
    LoadDependencies()
    
    local range = weaponDef.range or 6
    local beamWidth = 0.5  -- 光束宽度（判定半径）
    
    Audio.PlayShoot(weaponDef.type)
    
    -- 创建等离子光束视觉效果
    local endX = weaponX + dirX * range
    local endY = weaponY + dirY * range
    Effects.CreatePlasmaBeam(scene, weaponX, weaponY, endX, endY, weaponDef.color)
    
    -- 查找直线上的所有敌人（使用点到线段距离判定）
    local allEnemies = Enemy.GetList()
    local hitCount = 0
    
    for _, enemy in ipairs(allEnemies) do
        if enemy and enemy.node then
            local ex = enemy.node.position.x
            local ey = enemy.node.position.y
            
            -- 计算点到线段的距离
            local toEnemyX = ex - weaponX
            local toEnemyY = ey - weaponY
            
            -- 投影到射线方向的距离
            local projDist = toEnemyX * dirX + toEnemyY * dirY
            
            -- 考虑敌人体型：使用统一的边缘距离补偿
            local enemyRadius = Math.GetEntityRadius(enemy)
            local edgeProjDist = projDist - enemyRadius
            
            -- 必须在射程内且在前方（统一使用边缘距离）
            if edgeProjDist > 0.3 and edgeProjDist <= range then
                -- 垂直距离（点到线的距离）
                local perpX = toEnemyX - dirX * projDist
                local perpY = toEnemyY - dirY * projDist
                local perpDist = math.sqrt(perpX * perpX + perpY * perpY)
                
                -- 判定命中（在光束宽度内）
                if perpDist <= beamWidth then
                    -- 命中！无距离衰减，穿透全体
                    local actualDamage = Enemy.Damage(enemy, damage, Game.player.bossDamage, dirX, dirY)
                    Game.RecordDamage(actualDamage)
                    
                    -- 命中特效（等离子火花）
                    Effects.CreateHitSpark(scene, ex, ey, weaponDef.color, isCrit)
                    Effects.CreateDamageNumber(ex, ey + 0.5, actualDamage, isCrit)
                    
                    -- 灼烧DOT（文档：2秒）
                    if weaponDef.burnDamage and weaponDef.burnDamage > 0 then
                        Enemy.ApplyBurn(enemy, weaponDef.burnDamage, weaponDef.burnDuration or 2.0)
                    end
                    
                    hitCount = hitCount + 1
                end
            end
        end
    end
    
    -- 命中音效（只播放一次）
    if hitCount > 0 then
        Audio.PlayHit(isCrit, weaponDef.type)
    end
end

-- ============================================================================
-- 即时闪电连接武器（离子连锁炮专用）
-- ============================================================================

function GameLoop.FireInstantChain(scene, weapon, weaponDef, weaponX, weaponY, target, damage, isCrit)
    LoadDependencies()
    
    if not target or not target.node then return end
    
    local hitX = target.node.position.x
    local hitY = target.node.position.y
    
    -- 射程检查（使用统一的边缘距离补偿）
    local dist = Math.Distance(weaponX, weaponY, hitX, hitY)
    local edgeDist = Math.EdgeDistance(dist, target)
    if edgeDist > weaponDef.range then return end
    
    Audio.PlayShoot(weaponDef.type)
    
    -- 第一发：从武器到敌人的闪电效果
    Effects.CreateChainLightning(scene, weaponX, weaponY, hitX, hitY, weaponDef.color)
    
    -- 造成伤害
    local dirX, dirY = Math.Normalize(hitX - weaponX, hitY - weaponY)
    local actualDamage = Enemy.Damage(target, damage, Game.player.bossDamage, dirX, dirY)
    Game.RecordDamage(actualDamage)
    
    -- 命中特效
    Effects.CreateHitSpark(scene, hitX, hitY, weaponDef.color, isCrit)
    Audio.PlayHit(isCrit, weaponDef.type)
    Effects.CreateDamageNumber(hitX, hitY + 0.5, actualDamage, isCrit)
    
    -- 触发连锁攻击
    if weaponDef.chainCount and weaponDef.chainCount > 0 then
        GameLoop.HandleChainAttack(scene, weaponDef, hitX, hitY, damage, target, weapon.tier)
    end
end

-- ============================================================================
-- 链式攻击处理
-- ============================================================================

function GameLoop.HandleChainAttack(scene, weaponDef, startX, startY, baseDamage, firstEnemy, tier)
    LoadDependencies()
    
    local chainRange = weaponDef.chainRange or 5
    local chainDamageDecay = weaponDef.chainDamageDecay or 0.7
    local chainedEnemies = {firstEnemy}
    local currentX, currentY = startX, startY
    local currentDamage = baseDamage * chainDamageDecay
    
    -- 支持 tierChainCount（T4离子连锁炮可连锁4次）
    local chainCount = weaponDef.chainCount
    if weaponDef.tierChainCount and tier and weaponDef.tierChainCount[tier] then
        chainCount = weaponDef.tierChainCount[tier]
    end
    
    for chain = 1, chainCount do
        local nearby = Enemy.FindNearby(currentX, currentY, chainRange, chainedEnemies)
        if #nearby == 0 then break end
        
        local nextTarget = nearby[1].enemy
        local nextX = nextTarget.node.position.x
        local nextY = nextTarget.node.position.y
        
        -- 链式闪电特效
        Effects.CreateChainLightning(scene, currentX, currentY, nextX, nextY, weaponDef.color)
        
        -- 造成伤害（方向从源点到目标）
        local chainDirX, chainDirY = Math.Normalize(nextX - currentX, nextY - currentY)
        local chainActualDamage = Enemy.Damage(nextTarget, currentDamage, Game.player.bossDamage, chainDirX, chainDirY)
        Game.RecordDamage(chainActualDamage)  -- 记录实时DPS
        Effects.CreateDamageNumber(nextX, nextY + 0.5, chainActualDamage, false)
        
        -- 更新下一次连锁
        table.insert(chainedEnemies, nextTarget)
        currentX, currentY = nextX, nextY
        currentDamage = currentDamage * chainDamageDecay
    end
end

-- ============================================================================
-- 玩家更新
-- ============================================================================

function GameLoop.UpdatePlayer(dt, moveX, moveY)
    LoadDependencies()
    
    if Game.currentState ~= Game.States.PLAYING then return end
    
    -- 更新游戏状态
    Game.Update(dt)
    
    -- 归一化移动输入
    if moveX ~= 0 or moveY ~= 0 then
        local len = math.sqrt(moveX * moveX + moveY * moveY)
        if len > 1 then
            moveX, moveY = moveX / len, moveY / len
        end
    end
    
    -- 应用移动（使用有效移动速度，包含紧急加速等临时效果）
    local effectiveMoveSpeed = Game.GetEffectiveMoveSpeed()
    Player.Move(moveX, moveY, dt, effectiveMoveSpeed)
    
    -- 朝向 (只跟随移动方向)
    if moveX ~= 0 then
        local newFacing = moveX > 0
        if newFacing ~= Game.player.facingRight then
            Game.player.facingRight = newFacing
            Player.SetFacing(newFacing)
        end
    end
    
    -- 更新平滑旋转
    Player.UpdateRotation(dt)
    
    -- 更新引擎火焰（渐变效果）
    Player.UpdateFlame(dt)
    
    -- 更新受击闪白效果
    Player.UpdateHitFlash(dt)
    
    -- 无敌闪烁
    if Game.player.invincibleTime > 0 then
        local flash = math.sin(Game.player.invincibleTime * Settings.Visual.InvincibleFlashSpeed) > 0
        Player.SetVisible(flash)
    else
        Player.SetVisible(true)
    end
end

-- ============================================================================
-- 实体更新
-- ============================================================================

function GameLoop.UpdateEntities(dt, playerX, playerY, scene)
    LoadDependencies()
    
    -- 更新无人机
    Drone.UpdateAll(dt, playerX, playerY, Enemy.GetList(),
        Game.player.damageMultiplier,
        Game.player.critChance,
        Game.player.critDamage)
    
    -- 更新子弹
    Projectile.UpdateAll(dt, Enemy.FindNearest)
    Projectile.UpdateEnemyProjectiles(dt)
    
    -- 更新集束爆炸
    Projectile.UpdateClusterExplosions(dt, scene)
    
    -- 更新敌人
    Enemy.UpdateAll(dt, playerX, playerY)
    
    -- 更新拾取物（传递模块效果）
    local moduleEffects = {
        hasAttractor = Game.player.hasAttractor,
        hasSuperMagnet = Game.player.hasSuperMagnet,
    }
    Pickup.UpdateAll(dt, playerX, playerY, Game.player.pickupRangeMultiplier, moduleEffects)
    
    -- 更新残骸系统
    Debris.UpdateAll(dt)
    
    -- 更新残骸掉落物
    local shieldRegenMult = Game.player.shieldRegen and (1 + Game.player.shieldRegen * 0.1) or 1.0
    DebrisPickup.UpdateAll(dt, playerX, playerY, shieldRegenMult, moduleEffects)
end

-- ============================================================================
-- 视觉效果更新
-- ============================================================================

function GameLoop.UpdateEffects(dt, cameraNode)
    LoadDependencies()
    
    Effects.UpdateHitSparks(dt)
    Effects.UpdateDeathParticles(dt)
    Effects.UpdateSplatterParticles(dt)
    Effects.UpdateExplosions(dt)
    Effects.UpdateChainLightnings(dt)
    Effects.UpdatePlasmaParticles(dt)
    Effects.UpdateDamageNumbers(dt)
    Effects.UpdateWarpWarnings(dt)
    Effects.UpdateScreenShake(dt, cameraNode)
end

return GameLoop
