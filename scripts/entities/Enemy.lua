-- ============================================================================
-- 星河战姬 Starkyries - 敌人实体管理
-- ============================================================================

local Settings = require("config.settings")
local Enemies = require("config.enemies")
local Materials = require("render.Materials")
local Math = require("utils.Math")
local EnemyModels = require("entities.EnemyModels.index")
local SpatialHash = require("utils.SpatialHash")
local EventBus = require("utils.EventBus")
local EnemyBehavior = require("entities.enemy.EnemyBehavior")
local EnemyVisualEffects = require("entities.enemy.EnemyVisualEffects")

local Enemy = {}

-- 敌人列表
Enemy.list = {}

-- 空间哈希（用于优化范围查询）
Enemy.spatialHash = SpatialHash.New(10.0)  -- 10米单元格

-- 回调
Enemy.onDeath = nil        -- function(enemy) 死亡时立即触发
Enemy.onDeathFinish = nil  -- function(enemy) 死亡动画结束时触发（击退完成后）

-- ============================================================================
-- 8方向系统（与玩家一致）
-- ============================================================================
Enemy.TILT_ANGLE = Settings.Visual.TiltAngle  -- 固定俯视角度

Enemy.DIRECTIONS = {
    RIGHT      = 0,
    RIGHT_UP   = -45,
    UP         = -90,
    LEFT_UP    = -135,
    LEFT       = 180,
    LEFT_DOWN  = 135,
    DOWN       = 90,
    RIGHT_DOWN = 45,
}

-- 计算8方向旋转
function Enemy.ComputeRotation(yaw)
    local tiltRot = Quaternion(Enemy.TILT_ANGLE, Vector3.RIGHT)
    local directionRot = Quaternion(yaw, Vector3.UP)
    return tiltRot * directionRot
end

-- 根据移动方向计算目标Yaw角度
function Enemy.GetYawFromDirection(dx, dy)
    if math.abs(dx) < 0.01 and math.abs(dy) < 0.01 then
        return nil  -- 没有移动
    end
    
    local angle = math.atan(dy, dx)
    local degrees = math.deg(angle)
    
    -- 映射到8方向
    if degrees >= -22.5 and degrees < 22.5 then
        return Enemy.DIRECTIONS.RIGHT
    elseif degrees >= 22.5 and degrees < 67.5 then
        return Enemy.DIRECTIONS.RIGHT_UP
    elseif degrees >= 67.5 and degrees < 112.5 then
        return Enemy.DIRECTIONS.UP
    elseif degrees >= 112.5 and degrees < 157.5 then
        return Enemy.DIRECTIONS.LEFT_UP
    elseif degrees >= 157.5 or degrees < -157.5 then
        return Enemy.DIRECTIONS.LEFT
    elseif degrees >= -157.5 and degrees < -112.5 then
        return Enemy.DIRECTIONS.LEFT_DOWN
    elseif degrees >= -112.5 and degrees < -67.5 then
        return Enemy.DIRECTIONS.DOWN
    else
        return Enemy.DIRECTIONS.RIGHT_DOWN
    end
end

-- ============================================================================
-- 创建敌人
-- ============================================================================

function Enemy.Create(scene, enemyType, x, y, scaledStats)
    local def = Enemies.Get(enemyType)
    if not def then return nil end
    
    local node = scene:CreateChild("Enemy")
    node.position = Vector3(x, y, 0)
    
    local bc = def.bodyColor
    local gc = def.glowColor
    local s = def.scale
    
    -- 创建船体容器（用于旋转）
    local hull = node:CreateChild("Hull")
    
    -- 使用工厂模式创建敌人模型
    local materials = EnemyModels.CreateMaterials(def)
    local flameNodes = EnemyModels.Create(hull, enemyType, def, materials)
    
    -- 初始旋转（面向左，朝向玩家方向）
    local initialYaw = x > 0 and Enemy.DIRECTIONS.LEFT or Enemy.DIRECTIONS.RIGHT
    hull.rotation = Enemy.ComputeRotation(initialYaw)
    
    -- 应用缩放后的属性
    local hp = scaledStats and scaledStats.hp or def.hp
    local damage = scaledStats and scaledStats.damage or def.damage
    local speed = scaledStats and scaledStats.moveSpeed or def.moveSpeed
    
    local enemy = {
        node = node,
        hull = hull,  -- 船体节点（用于旋转）
        type = enemyType,
        id = def.id or enemyType,      -- 敌人ID（用于死亡统计）
        name = def.name or enemyType,  -- 敌人名称（用于死亡统计显示）
        hp = hp,
        maxHp = hp,
        damage = damage,
        moveSpeed = speed,
        behavior = def.behavior,
        attackRange = def.attackRange or 0,
        dropCrystal = def.dropCrystal,
        dropXp = def.dropXp or 1,  -- 经验值（对标文档：普通敌舰1XP）
        scale = def.scale,
        hitRadius = def.scale,  -- 碰撞半径 = 视觉大小（100% 一致）
        glowColor = def.glowColor,
        armor = def.armor or 0,
        facingRight = x < 0,
        attackCooldown = 0,
        -- 8方向系统
        currentYaw = initialYaw,
        targetYaw = initialYaw,
        rotationSpeed = 360,  -- 度/秒
        -- 引擎火焰
        flameNodes = flameNodes,
        flameIntensity = 0,
        isMoving = false,
        -- 行为相关
        orbitAngle = math.random() * math.pi * 2,
        orbitDir = math.random() > 0.5 and 1 or -1,
        fromWarp = false,
        spawnTime = 0,
        -- 特殊能力
        canShoot = def.canShoot,
        projectileSpeed = def.projectileSpeed,
        projectileType = def.projectileType,  -- 子弹类型（nil=普通, "missile"=导弹）
        isBoss = def.isBoss,
        isSuicide = def.isSuicide,
        knockbackResist = def.knockbackResist or 0,  -- 击退抗性（0-1）
        explosionRadius = def.explosionRadius,
        -- 自爆虫蓄力冲刺状态
        chargeState = "approach",  -- "approach" | "charging" | "dash"
        chargeTimer = 0,
        chargeTargetX = nil,
        chargeTargetY = nil,
        chargeDistance = def.chargeDistance or 9.0,
        chargeDelay = def.chargeDelay or 0.5,
        chargeSpeed = def.chargeSpeed or 15.0,
        explosionColor = def.explosionColor,
        -- 治疗能力
        canHeal = def.canHeal,
        healRange = def.healRange,
        healAmount = def.healAmount,
        healCooldown = def.healCooldown,
        healTimer = 0,
        -- Boss阶段
        bossPhases = def.phases,
        currentPhase = 1,
        phaseSpawnTimer = 0,
        baseAttackCooldownTime = def.attackCooldown or 1.0,
        baseMoveSpeed = speed,
        baseDamage = damage,
        -- 弹幕配置
        barrage = def.barrage,
        barrageAngle = 0,
    }
    
    table.insert(Enemy.list, enemy)
    Enemy.spatialHash:Insert(enemy, x, y)
    return enemy
end

-- Boss召唤回调
Enemy.onBossSpawn = nil  -- function(bossEnemy, spawnType, count)
Enemy.onBossPhaseChange = nil  -- function(bossEnemy, newPhase, phaseName)

-- 爆破舰自爆回调
Enemy.onExplode = nil  -- function(x, y, radius, damage, enemyInfo)

-- 治疗舰治疗回调
Enemy.onHeal = nil  -- function(healerX, healerY, targetX, targetY, amount)

-- 敌人射击回调
Enemy.onShoot = nil  -- function(enemy, targetX, targetY)

-- ============================================================================
-- 击退效果（必须在 UpdateOne 之前定义）
-- ============================================================================

-- 更新击退效果（在UpdateOne中调用）
local function UpdateKnockback(enemy, dt)
    if not enemy.knockbackVelX and not enemy.knockbackVelY then return end
    
    local velX = enemy.knockbackVelX or 0
    local velY = enemy.knockbackVelY or 0
    
    -- 如果速度很小，清除击退状态
    local speed = math.sqrt(velX * velX + velY * velY)
    if speed < 0.1 then
        enemy.knockbackVelX = nil
        enemy.knockbackVelY = nil
        enemy.knockbackDecay = nil
        return
    end
    
    -- 应用击退位移
    local pos = enemy.node.position
    pos.x = pos.x + velX * dt
    pos.y = pos.y + velY * dt
    
    -- 边界限制
    local area = Settings.BattleArea
    pos.x = Math.Clamp(pos.x, area.MinX - 3, area.MaxX + 3)
    pos.y = Math.Clamp(pos.y, area.MinY - 3, area.MaxY + 3)
    
    enemy.node.position = pos
    
    -- 衰减击退速度
    local decay = enemy.knockbackDecay or 0.3
    local decayRate = 1.0 / decay  -- 每秒衰减率
    local factor = math.max(0, 1.0 - decayRate * dt)
    
    enemy.knockbackVelX = velX * factor
    enemy.knockbackVelY = velY * factor
end

-- 应用击退效果
-- @param enemy 敌人对象
-- @param force 击退力度（米）
-- @param dirX, dirY 击退方向（归一化）
function Enemy.ApplyKnockback(enemy, force, dirX, dirY)
    if not enemy or not enemy.node then return end
    
    -- 击退抗性检查（按概率免疫）
    -- knockbackResist: 0 = 总是被击退, 1.0 = 100%免疫（从配置读取）
    local resist = enemy.knockbackResist or 0
    
    -- 按概率判断是否免疫本次击退
    if resist > 0 and math.random() < resist then
        return  -- 免疫本次击退
    end
    
    -- 击退效果倍率（从配置读取，默认1.0）
    local knockbackMult = enemy.knockbackMult or 1.0
    
    -- 计算实际击退力度
    local actualForce = force * knockbackMult
    
    -- 累加击退速度
    enemy.knockbackVelX = (enemy.knockbackVelX or 0) + dirX * actualForce
    enemy.knockbackVelY = (enemy.knockbackVelY or 0) + dirY * actualForce
    
    -- 限制最大击退速度（不超过武器自身的击退力度）
    local currentSpeed = math.sqrt(enemy.knockbackVelX * enemy.knockbackVelX + enemy.knockbackVelY * enemy.knockbackVelY)
    if currentSpeed > actualForce then
        local scale = actualForce / currentSpeed
        enemy.knockbackVelX = enemy.knockbackVelX * scale
        enemy.knockbackVelY = enemy.knockbackVelY * scale
    end
    
    -- 设置击退衰减时间
    enemy.knockbackDecay = 0.3  -- 0.3秒内衰减完毕
end

-- ============================================================================
-- Boss多阶段更新
-- ============================================================================

function Enemy.UpdateBossPhase(enemy, dt)
    if not enemy.bossPhases then return end
    
    local hpPercent = enemy.hp / enemy.maxHp
    local phases = enemy.bossPhases
    
    -- 检查是否进入下一阶段
    local targetPhase = 1
    for i, phase in ipairs(phases) do
        if hpPercent > phase.hpThreshold then
            targetPhase = i
            break
        else
            targetPhase = i + 1
        end
    end
    targetPhase = math.min(targetPhase, #phases)
    
    -- 阶段变化
    if targetPhase ~= enemy.currentPhase then
        local oldPhase = enemy.currentPhase
        enemy.currentPhase = targetPhase
        local phase = phases[targetPhase]
        
        -- 应用阶段修改器
        if phase.moveSpeedMultiplier then
            enemy.moveSpeed = enemy.baseMoveSpeed * phase.moveSpeedMultiplier
        end
        if phase.damageMultiplier then
            enemy.damage = enemy.baseDamage * phase.damageMultiplier
        end
        if phase.attackCooldown then
            enemy.baseAttackCooldownTime = phase.attackCooldown
        end
        if phase.canShoot ~= nil then
            enemy.canShoot = phase.canShoot
        end
        
        -- 阶段变化回调
        if Enemy.onBossPhaseChange then
            Enemy.onBossPhaseChange(enemy, targetPhase, phase.name)
        end
        
        -- 重置召唤计时器
        enemy.phaseSpawnTimer = 0
    end
    
    -- 当前阶段召唤逻辑
    local phase = phases[enemy.currentPhase]
    if phase and phase.spawnType and phase.spawnInterval then
        enemy.phaseSpawnTimer = enemy.phaseSpawnTimer + dt
        
        if enemy.phaseSpawnTimer >= phase.spawnInterval then
            enemy.phaseSpawnTimer = 0
            
            -- 触发召唤回调
            if Enemy.onBossSpawn then
                Enemy.onBossSpawn(enemy, phase.spawnType, phase.spawnCount or 1)
            end
        end
    end
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

-- 真正移除敌人（死亡动画结束后调用）
local function RemoveEnemy(enemy)
    if enemy.node then
        enemy.node:Remove()
    end
    
    -- 从列表移除
    for i, e in ipairs(Enemy.list) do
        if e == enemy then
            table.remove(Enemy.list, i)
            break
        end
    end
end

-- ============================================================================
-- 更新
-- ============================================================================

function Enemy.UpdateAll(dt, playerX, playerY)
    -- 收集需要自爆的敌人和需要移除的死亡敌人
    local explodingEnemies = {}
    local toRemove = {}
    
    for i = #Enemy.list, 1, -1 do
        local enemy = Enemy.list[i]
        
        -- 处理死亡动画
        if enemy.isDying then
            -- 死亡期间继续处理击退效果（先击退再爆炸）
            UpdateKnockback(enemy, dt)
            
            -- 死亡期间继续更新闪白效果（避免一直白着）
            if enemy.hitFlashTimer and enemy.hitFlashTimer > 0 then
                enemy.hitFlashTimer = enemy.hitFlashTimer - dt
                if enemy.hitFlashTimer <= 0 then
                    Enemy.RestoreOriginalMaterials(enemy)
                end
            end
            
            enemy.deathTimer = enemy.deathTimer - dt
            if enemy.deathTimer <= 0 then
                -- 死亡动画结束，在最终位置触发粒子效果
                if Enemy.onDeathFinish then
                    Enemy.onDeathFinish(enemy)
                end
                table.insert(toRemove, enemy)
            end
            goto continue
        end
        
        Enemy.UpdateOne(enemy, dt, playerX, playerY)
        
        -- 检查是否需要自爆
        if enemy.shouldExplode then
            table.insert(explodingEnemies, enemy)
        end
        
        ::continue::
    end
    
    -- 移除死亡动画完成的敌人
    for _, enemy in ipairs(toRemove) do
        RemoveEnemy(enemy)
    end
    
    -- 处理自爆（在更新循环外处理，避免修改迭代中的列表）
    for _, enemy in ipairs(explodingEnemies) do
        local radius = enemy.explosionRadius or 3.0
        local damage = enemy.damage * 2  -- 自爆伤害为基础伤害的2倍
        
        -- 触发自爆回调（用于对玩家造成伤害和显示特效）
        local enemyInfo = {
            id = enemy.id, 
            name = enemy.name or "爆破舰",
            explosionColor = enemy.explosionColor  -- 自定义爆炸颜色（如绿色爆浆）
        }
        if Enemy.onExplode then
            Enemy.onExplode(enemy.explodeX, enemy.explodeY, radius, damage, enemyInfo)
        end
        
        -- 发布事件
        EventBus.Emit(EventBus.Events.ENEMY_EXPLODE, enemy.explodeX, enemy.explodeY, radius, damage, enemyInfo)
        
        -- 自爆后死亡（不触发普通死亡回调，因为不掉落晶体）
        enemy.node:Remove()
        Enemy.spatialHash:Remove(enemy)
        for i, e in ipairs(Enemy.list) do
            if e == enemy then
                table.remove(Enemy.list, i)
                break
            end
        end
    end
end

function Enemy.UpdateOne(enemy, dt, playerX, playerY)
    -- 更新击退效果（优先处理）
    UpdateKnockback(enemy, dt)
    
    -- 更新受击闪白
    if enemy.hitFlashTimer and enemy.hitFlashTimer > 0 then
        enemy.hitFlashTimer = enemy.hitFlashTimer - dt
        if enemy.hitFlashTimer <= 0 then
            Enemy.RestoreOriginalMaterials(enemy)
        end
    end
    
    -- 更新闪白冷却时间
    if enemy.hitFlashCooldown and enemy.hitFlashCooldown > 0 then
        enemy.hitFlashCooldown = enemy.hitFlashCooldown - dt
    end
    
    -- 更新燃烧DOT
    if enemy.burnDamage and enemy.burnDamage > 0 then
        enemy.burnTimer = (enemy.burnTimer or 0) + dt
        enemy.burnDuration = (enemy.burnDuration or 0) - dt
        
        -- 每0.5秒造成一次伤害
        if enemy.burnTimer >= 0.5 then
            enemy.burnTimer = 0
            local actualDamage = math.max(1, enemy.burnDamage - enemy.armor)
            enemy.hp = enemy.hp - actualDamage
            
            -- 燃烧伤害数字回调
            if Enemy.onBurnDamage then
                Enemy.onBurnDamage(enemy, actualDamage)
            end
            
            if enemy.hp <= 0 then
                Enemy.Kill(enemy)
                return  -- 已死亡，跳过后续更新
            end
        end
        
        -- 燃烧结束
        if enemy.burnDuration <= 0 then
            enemy.burnDamage = 0
            enemy.burnTimer = 0
        end
    end
    
    local pos = enemy.node.position
    local def = Enemies.Get(enemy.type)
    
    -- Boss多阶段更新
    if enemy.isBoss and enemy.bossPhases then
        Enemy.UpdateBossPhase(enemy, dt)
    end
    
    -- 行为AI（委托给 EnemyBehavior 模块）
    local behaviorContext = {
        healCallback = Enemy.onHeal,
        enemyList = Enemy.list,
    }
    local moveX, moveY, speed = EnemyBehavior.Calculate(enemy, dt, playerX, playerY, behaviorContext)
    
    -- 应用移动
    pos.x = pos.x + moveX * speed * dt
    pos.y = pos.y + moveY * speed * dt
    
    -- 边界限制
    local area = Settings.BattleArea
    pos.x = Math.Clamp(pos.x, area.MinX - 3, area.MaxX + 3)
    pos.y = Math.Clamp(pos.y, area.MinY - 3, area.MaxY + 3)
    
    enemy.node.position = pos
    
    -- 更新移动状态和方向
    enemy.isMoving = math.abs(moveX) > 0.01 or math.abs(moveY) > 0.01
    
    -- 根据移动方向更新目标朝向（8方向）
    if enemy.isMoving then
        local newYaw = Enemy.GetYawFromDirection(moveX, moveY)
        if newYaw then
            enemy.targetYaw = newYaw
        end
    end
    
    -- 平滑旋转
    if enemy.hull and enemy.currentYaw ~= enemy.targetYaw then
        local diff = enemy.targetYaw - enemy.currentYaw
        -- 处理角度环绕
        while diff > 180 do diff = diff - 360 end
        while diff < -180 do diff = diff + 360 end
        
        local maxRotation = enemy.rotationSpeed * dt
        if math.abs(diff) <= maxRotation then
            enemy.currentYaw = enemy.targetYaw
        else
            enemy.currentYaw = enemy.currentYaw + (diff > 0 and maxRotation or -maxRotation)
        end
        
        -- 应用旋转
        enemy.hull.rotation = Enemy.ComputeRotation(enemy.currentYaw)
    end
    
    -- 更新引擎火焰
    Enemy.UpdateFlame(enemy, dt)
    
    -- 更新蓄力闪红效果（自爆虫）
    Enemy.UpdateChargeFlash(enemy, dt)
    
    -- 朝向玩家（用于其他逻辑）
    enemy.facingRight = playerX > pos.x
    
    -- 远程射击逻辑
    if enemy.canShoot then
        enemy.attackCooldown = (enemy.attackCooldown or 0) - dt
        
        if enemy.attackCooldown <= 0 then
            -- 检查射程
            local dist = Math.Distance(pos.x, pos.y, playerX, playerY)
            local attackRange = enemy.attackRange or 12.0
            
            if dist <= attackRange then
                -- 重置冷却
                enemy.attackCooldown = enemy.baseAttackCooldownTime or 1.5
                
                -- 触发射击回调
                if Enemy.onShoot then
                    Enemy.onShoot(enemy, playerX, playerY)
                end
            end
        end
    end
    
    -- 更新空间哈希位置
    local finalPos = enemy.node.position
    Enemy.spatialHash:Update(enemy, finalPos.x, finalPos.y)
end

-- 更新敌人引擎火焰（委托给 EnemyVisualEffects）
function Enemy.UpdateFlame(enemy, dt)
    EnemyVisualEffects.UpdateFlame(enemy, dt)
end

-- ============================================================================
-- 视觉特效（委托给 EnemyVisualEffects）
-- ============================================================================

-- 更新蓄力闪红效果（自爆虫专用）
function Enemy.UpdateChargeFlash(enemy, dt)
    EnemyVisualEffects.UpdateChargeFlash(enemy, dt)
end

-- ============================================================================
-- 伤害
-- ============================================================================

function Enemy.Damage(enemy, damage, bossDamageBonus, hitDirX, hitDirY)
    -- Boss伤害加成
    if enemy.isBoss and bossDamageBonus and bossDamageBonus > 0 then
        damage = damage * (1 + bossDamageBonus)
    end
    
    -- 记录最后击中方向（用于死亡粒子扩散）
    if hitDirX and hitDirY then
        enemy.lastHitDirX = hitDirX
        enemy.lastHitDirY = hitDirY
    end
    
    -- 装甲减伤
    local armor = enemy.armor or 0
    local actualDamage = math.max(1, damage - armor)
    enemy.hp = enemy.hp - actualDamage
    
    -- 触发闪白效果
    Enemy.TriggerHitFlash(enemy)
    
    if enemy.hp <= 0 then
        Enemy.Kill(enemy)
    end
    
    return actualDamage
end

-- 触发受击闪白（委托给 EnemyVisualEffects）
function Enemy.TriggerHitFlash(enemy)
    EnemyVisualEffects.TriggerHitFlash(enemy)
end

-- 恢复原始材质（委托给 EnemyVisualEffects）
function Enemy.RestoreOriginalMaterials(enemy)
    EnemyVisualEffects.RestoreOriginalMaterials(enemy)
end

function Enemy.Kill(enemy)
    -- 防止重复击杀
    if enemy.isDying then return end
    enemy.isDying = true
    
    -- 回调（保持向后兼容）
    if Enemy.onDeath then
        Enemy.onDeath(enemy)
    end
    
    -- 发布事件（新方式）
    EventBus.Emit(EventBus.Events.ENEMY_DEATH, enemy)
    
    -- 从空间哈希移除（不再参与碰撞）
    Enemy.spatialHash:Remove(enemy)
    
    -- 死亡延迟：只有在有击退效果时才延迟（让敌人滑行后再爆炸）
    -- 没有击退的武器直接死亡，手感更好
    local hasKnockback = (enemy.knockbackVelX and math.abs(enemy.knockbackVelX) > 0.1) or
                         (enemy.knockbackVelY and math.abs(enemy.knockbackVelY) > 0.1)
    enemy.deathTimer = hasKnockback and 0.2 or 0
end

-- ============================================================================
-- 碰撞检测
-- ============================================================================

function Enemy.CheckCollisionWithPlayer(playerX, playerY, playerRadius)
    playerRadius = playerRadius or 1.0
    
    for _, enemy in ipairs(Enemy.list) do
        local pos = enemy.node.position
        -- 使用配置的玩家碰撞补偿系数
        local hitDist = (enemy.hitRadius or enemy.scale) * Settings.Combat.PlayerCollisionCompensation + playerRadius
        
        if Math.Distance(pos.x, pos.y, playerX, playerY) < hitDist then
            return enemy
        end
    end
    return nil
end

-- 查找最近敌人（使用空间哈希优化）
function Enemy.FindNearest(x, y, maxRange)
    maxRange = maxRange or 999
    return Enemy.spatialHash:QueryNearest(x, y, maxRange)
end

-- 查找范围内的敌人（排除指定敌人，使用空间哈希优化）
function Enemy.FindNearby(x, y, range, excludeList)
    local results = Enemy.spatialHash:QueryRange(x, y, range, excludeList)
    -- 按距离排序
    table.sort(results, function(a, b) return a.dist < b.dist end)
    return results
end

-- 应用燃烧效果
function Enemy.ApplyBurn(enemy, damage, duration)
    -- 如果已有燃烧，取最大伤害和刷新时间
    if enemy.burnDamage and enemy.burnDamage > damage then
        -- 保持更高伤害，只刷新时间
        enemy.burnDuration = math.max(enemy.burnDuration or 0, duration)
    else
        enemy.burnDamage = damage
        enemy.burnDuration = duration
        enemy.burnTimer = 0
    end
end

-- ============================================================================
-- 获取
-- ============================================================================

function Enemy.GetList()
    return Enemy.list
end

function Enemy.GetCount()
    return #Enemy.list
end

-- ============================================================================
-- 清理
-- ============================================================================

function Enemy.ClearAll()
    for _, enemy in ipairs(Enemy.list) do
        enemy.hp = 0  -- 标记为死亡，防止其他模块（如无人机）继续引用
        enemy.node:Remove()
        enemy.node = nil  -- 清除节点引用
    end
    Enemy.list = {}
    Enemy.spatialHash:Clear()
end

-- ============================================================================
-- 触发所有敌人自爆（Boss击败时调用）
-- ============================================================================

function Enemy.TriggerAllSelfDestruct()
    for _, enemy in ipairs(Enemy.list) do
        -- 跳过已经在死亡状态的敌人
        if not enemy.isDying then
            -- 标记为自爆状态
            enemy.shouldExplode = true
            enemy.explodeX = enemy.node.position.x
            enemy.explodeY = enemy.node.position.y
        end
    end
end

-- ============================================================================
-- 强制移除（用于超出上限时，不掉落材料）
-- ============================================================================

-- 强制移除敌人（不触发 onDeath 回调，不掉落材料）
function Enemy.ForceRemove(enemy)
    -- 移除节点
    enemy.node:Remove()
    
    -- 从空间哈希移除
    Enemy.spatialHash:Remove(enemy)
    
    -- 从列表移除
    for i, e in ipairs(Enemy.list) do
        if e == enemy then
            table.remove(Enemy.list, i)
            break
        end
    end
end

-- 随机移除一只非精英/非Boss敌舰（超出上限时调用）
-- 返回 true 如果成功移除，false 如果没有可移除的敌舰
function Enemy.ForceRemoveRandomNonElite()
    -- 收集所有非精英/非Boss敌舰
    local candidates = {}
    for i, enemy in ipairs(Enemy.list) do
        if not enemy.isElite and not enemy.isBoss then
            table.insert(candidates, {index = i, enemy = enemy})
        end
    end
    
    -- 没有可移除的敌舰
    if #candidates == 0 then
        return false
    end
    
    -- 随机选择一只移除
    local choice = candidates[math.random(#candidates)]
    Enemy.ForceRemove(choice.enemy)
    
    return true
end

-- ============================================================================
-- 超空间跃迁飞离效果
-- ============================================================================

-- 跃迁飞离状态
local hyperspaceExit = {
    active = false,
    speed = 0,
    stretch = 1,
}

-- 开始跃迁飞离
function Enemy.StartHyperspaceExit()
    hyperspaceExit.active = true
    hyperspaceExit.speed = 0
    hyperspaceExit.stretch = 1
    
    -- 保存每个敌人的原始位置和缩放
    for _, enemy in ipairs(Enemy.list) do
        enemy.hyperspaceOriginalZ = enemy.z or 0
        enemy.hyperspaceOriginalScale = enemy.node.scale.x
    end
end

-- 停止跃迁飞离
function Enemy.StopHyperspaceExit()
    hyperspaceExit.active = false
    hyperspaceExit.speed = 0
    hyperspaceExit.stretch = 1
end

-- 是否正在跃迁飞离
function Enemy.IsHyperspaceExitActive()
    return hyperspaceExit.active
end

-- 更新跃迁飞离效果（每帧调用）
-- speed: 当前跃迁速度 (0-200)
-- stretch: 当前拉伸倍数 (1-15)
function Enemy.UpdateHyperspaceExit(speed, stretch)
    if not hyperspaceExit.active then return end
    
    hyperspaceExit.speed = speed
    hyperspaceExit.stretch = stretch
    
    local maxSpeed = 200
    local speedRatio = speed / maxSpeed
    
    for _, enemy in ipairs(Enemy.list) do
        -- 记录累计位移（用于淡出计算）
        enemy.hyperspaceDistance = (enemy.hyperspaceDistance or 0) + speed * 0.016
        
        -- 敌人向镜头飞来（Z 减小）
        local pos = enemy.node.position
        local newZ = pos.z - speed * 0.016
        enemy.node.position = Vector3(pos.x, pos.y, newZ)
        
        -- 拉伸效果（沿 Z 轴拉长）
        local baseScale = enemy.hyperspaceOriginalScale or 1
        local actualStretch = 1 + (stretch - 1) * 0.5  -- 敌人拉伸程度较小
        
        -- 根据累计位移计算淡出（飞行超过10单位后开始淡出）
        local fadeStartDist = 10
        local fadeEndDist = 25
        local dist = enemy.hyperspaceDistance
        
        if dist < fadeStartDist then
            -- 还没开始淡出，只应用拉伸
            if actualStretch > 1.1 then
                enemy.node:SetScale(Vector3(baseScale, baseScale, baseScale * actualStretch))
            end
        else
            -- 开始淡出
            local fadeFactor = math.max(0, 1 - (dist - fadeStartDist) / (fadeEndDist - fadeStartDist))
            enemy.node:SetScale(Vector3(
                baseScale * fadeFactor,
                baseScale * fadeFactor,
                baseScale * actualStretch * fadeFactor
            ))
        end
    end
end

return Enemy
