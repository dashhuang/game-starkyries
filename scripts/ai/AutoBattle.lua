-- ============================================================================
-- 星河战姬 Starkyries - 自动战斗 AI 模块 v4.0
-- 按 T 键开启/关闭自动战斗
-- 核心理念：预判躲避（子弹+碰撞）> 主动进攻 > 尽量吃晶体
-- ============================================================================

local Math = require("utils.Math")

-- ============================================================================
-- 状态定义
-- ============================================================================

local States = {
    AGGRESSIVE = "aggressive",   -- 主动进攻
    EVASIVE = "evasive",         -- 闪避模式（有威胁时）
    HARVEST = "harvest",         -- 收割模式（无敌人）
}

local AutoBattle = {
    enabled = false,
    currentState = States.AGGRESSIVE,
    stateTimer = 0,
    
    -- 配置参数
    config = {
        -- 进攻设置
        attackRange = 15.0,         -- 主动进攻搜索范围
        optimalRange = 7.0,         -- 最优战斗距离
        
        -- 碰撞躲避设置
        collisionPredictTime = 0.8, -- 碰撞预判时间（秒）
        collisionDangerRadius = 3.5,-- 碰撞危险半径
        collisionUrgentRadius = 2.0,-- 紧急躲避半径
        
        -- 子弹躲避设置
        bulletPredictTime = 0.6,    -- 子弹预判时间
        bulletDangerRadius = 3.0,   -- 子弹危险半径
        
        -- 特殊敌人额外距离
        suicideBotExtraRadius = 3.0,-- 自爆机额外安全距离
        fastEnemyExtraRadius = 1.5, -- 高速敌人额外距离（速度>7）
        
        -- 边界设置
        edgeMargin = 2.5,
        mapHalfWidth = 20.0,
        mapHalfHeight = 15.0,
        
        -- 拾取设置
        pickupSearchRadius = 12.0,  -- 拾取搜索范围
        pickupSafetyWeight = 0.6,   -- 安全权重（0-1，越高越保守）
        pickupValueWeight = 0.4,    -- 价值权重
        
        -- 目标优先级
        targetPriority = {
            HealerBug = 100,
            SuicideBug = 90,
            Elite = 80,
            PirateGun = 60,
            Carapace = 40,
            Spore = 30,
            default = 50,
        },
        
        -- 威胁权重（用于躲避计算）
        threatWeight = {
            SuicideBug = 3.0,   -- 自爆虫最危险
            HealerBug = 1.5,    -- 治疗虫速度快
            Spore = 1.2,        -- 孢子虫数量多
            Carapace = 1.0,     -- 甲壳舰慢
            Elite = 1.3,        -- 精英舰
            PirateGun = 0.8,    -- 炮舰主要靠子弹
            default = 1.0,
        },
    },
    
    -- 当前目标
    currentTarget = nil,
    targetSwitchCooldown = 0,
    
    -- 缓存的威胁数据
    threats = {
        bullets = {},       -- 威胁子弹列表
        enemies = {},       -- 威胁敌人列表
        totalDanger = 0,    -- 总威胁值
    },
    
    -- 调试信息
    debug = {
        state = States.AGGRESSIVE,
        targetEnemy = nil,
        threatLevel = 0,
        bulletThreats = 0,
        enemyThreats = 0,
        bestPickup = nil,
        vectors = {},
    },
}

-- 延迟加载
local Enemy, Projectile, Pickup, Game
local function LoadDependencies()
    if not Enemy then
        Enemy = require("entities.Enemy")
        Projectile = require("entities.Projectile")
        Pickup = require("entities.Pickup")
        Game = require("core.Game")
    end
end

-- ============================================================================
-- 公共接口
-- ============================================================================

function AutoBattle.Toggle()
    AutoBattle.enabled = not AutoBattle.enabled
    if AutoBattle.enabled then
        AutoBattle.currentState = States.AGGRESSIVE
        AutoBattle.currentTarget = nil
    end
    return AutoBattle.enabled
end

function AutoBattle.IsEnabled()
    return AutoBattle.enabled
end

function AutoBattle.SetEnabled(enabled)
    AutoBattle.enabled = enabled
end

function AutoBattle.GetState()
    return AutoBattle.currentState
end

-- ============================================================================
-- 核心更新
-- ============================================================================

function AutoBattle.Update(dt, playerX, playerY)
    if not AutoBattle.enabled then
        return 0, 0
    end
    
    LoadDependencies()
    
    local config = AutoBattle.config
    local debug = AutoBattle.debug
    
    -- 更新冷却
    if AutoBattle.targetSwitchCooldown > 0 then
        AutoBattle.targetSwitchCooldown = AutoBattle.targetSwitchCooldown - dt
    end
    AutoBattle.stateTimer = AutoBattle.stateTimer + dt
    
    -- ========================================
    -- 第一步：收集所有威胁信息
    -- ========================================
    local enemies = AutoBattle.CollectEnemies(playerX, playerY)
    local bulletThreats = AutoBattle.AnalyzeBulletThreats(playerX, playerY)
    local enemyThreats = AutoBattle.AnalyzeEnemyThreats(playerX, playerY, enemies)
    
    local totalThreat = #bulletThreats + #enemyThreats
    debug.bulletThreats = #bulletThreats
    debug.enemyThreats = #enemyThreats
    debug.threatLevel = totalThreat
    
    -- ========================================
    -- 第二步：更新状态
    -- ========================================
    if #enemies == 0 then
        AutoBattle.currentState = States.HARVEST
    elseif totalThreat > 0 then
        AutoBattle.currentState = States.EVASIVE
    else
        AutoBattle.currentState = States.AGGRESSIVE
    end
    debug.state = AutoBattle.currentState
    
    -- ========================================
    -- 第三步：选择攻击目标
    -- ========================================
    AutoBattle.SelectTarget(playerX, playerY, enemies)
    
    -- ========================================
    -- 第四步：计算各方向向量
    -- ========================================
    
    -- 1. 统一躲避向量（子弹 + 敌人碰撞）
    local evadeX, evadeY, evadeStrength = AutoBattle.CalculateEvadeVector(
        playerX, playerY, bulletThreats, enemyThreats
    )
    debug.vectors.evade = {x = evadeX, y = evadeY, strength = evadeStrength}
    
    -- 2. 进攻向量
    local attackX, attackY = AutoBattle.CalculateAttackVector(playerX, playerY)
    debug.vectors.attack = {x = attackX, y = attackY}
    
    -- 3. 边界向量
    local edgeX, edgeY = AutoBattle.CalculateEdgeVector(playerX, playerY)
    debug.vectors.edge = {x = edgeX, y = edgeY}
    
    -- 4. 拾取向量（基于当前移动意图计算最优拾取）
    local baseX = evadeX * evadeStrength + attackX * (1 - evadeStrength * 0.5)
    local baseY = evadeY * evadeStrength + attackY * (1 - evadeStrength * 0.5)
    local pickupX, pickupY = AutoBattle.CalculateSmartPickup(
        playerX, playerY, baseX, baseY, enemyThreats, bulletThreats
    )
    debug.vectors.pickup = {x = pickupX, y = pickupY}
    
    -- ========================================
    -- 第五步：混合最终向量
    -- ========================================
    local finalX, finalY = 0, 0
    
    if AutoBattle.currentState == States.HARVEST then
        -- 无敌人：全力拾取
        finalX = pickupX * 2.0 + edgeX * 0.5
        finalY = pickupY * 2.0 + edgeY * 0.5
    elseif AutoBattle.currentState == States.EVASIVE then
        -- 有威胁：躲避优先，但仍然进攻和拾取
        -- 躲避强度越高，进攻权重越低
        local attackWeight = math.max(0.3, 1.0 - evadeStrength)
        local pickupWeight = math.max(0.2, 0.8 - evadeStrength * 0.5)
        
        finalX = evadeX * 2.5 + attackX * attackWeight + pickupX * pickupWeight + edgeX * 1.0
        finalY = evadeY * 2.5 + attackY * attackWeight + pickupY * pickupWeight + edgeY * 1.0
    else
        -- 安全：进攻为主，积极拾取
        finalX = attackX * 2.0 + pickupX * 1.5 + edgeX * 0.5
        finalY = attackY * 2.0 + pickupY * 1.5 + edgeY * 0.5
    end
    
    -- 归一化
    local len = math.sqrt(finalX * finalX + finalY * finalY)
    if len > 0.01 then
        finalX = finalX / len
        finalY = finalY / len
    else
        finalX, finalY = 0, 0
    end
    
    debug.vectors.final = {x = finalX, y = finalY}
    
    return finalX, finalY
end

-- ============================================================================
-- 威胁分析
-- ============================================================================

-- 收集活着的敌人
function AutoBattle.CollectEnemies(playerX, playerY)
    local enemies = Enemy.GetList()
    local alive = {}
    
    for _, enemy in ipairs(enemies) do
        if enemy.node and enemy.hp and enemy.hp > 0 then
            local pos = enemy.node.position
            enemy._dist = Math.Distance(playerX, playerY, pos.x, pos.y)
            enemy._pos = pos
            table.insert(alive, enemy)
        end
    end
    
    return alive
end

-- 分析子弹威胁
function AutoBattle.AnalyzeBulletThreats(playerX, playerY)
    local config = AutoBattle.config
    local projectiles = Projectile.GetEnemyProjectiles()
    local threats = {}
    
    for _, proj in ipairs(projectiles) do
        if proj.x and proj.y and proj.dirX and proj.dirY and proj.speed then
            -- 预测子弹未来位置
            local futureX = proj.x + proj.dirX * proj.speed * config.bulletPredictTime
            local futureY = proj.y + proj.dirY * proj.speed * config.bulletPredictTime
            
            -- 计算最近距离
            local closestDist = AutoBattle.PointToSegmentDistance(
                playerX, playerY, proj.x, proj.y, futureX, futureY
            )
            
            -- 检查是否朝向玩家
            local toPlayerX = playerX - proj.x
            local toPlayerY = playerY - proj.y
            local dot = toPlayerX * proj.dirX + toPlayerY * proj.dirY
            
            if closestDist < config.bulletDangerRadius and dot > 0 then
                -- 计算撞击时间
                local dist = Math.Distance(playerX, playerY, proj.x, proj.y)
                local timeToImpact = dist / proj.speed
                
                table.insert(threats, {
                    type = "bullet",
                    x = proj.x,
                    y = proj.y,
                    dirX = proj.dirX,
                    dirY = proj.dirY,
                    speed = proj.speed,
                    distance = closestDist,
                    timeToImpact = timeToImpact,
                    danger = (1 - closestDist / config.bulletDangerRadius) * 
                             (1 / math.max(0.1, timeToImpact)),
                })
            end
        end
    end
    
    return threats
end

-- 分析敌人碰撞威胁
function AutoBattle.AnalyzeEnemyThreats(playerX, playerY, enemies)
    local config = AutoBattle.config
    local threats = {}
    
    for _, enemy in ipairs(enemies) do
        local pos = enemy._pos
        local dist = enemy._dist
        
        -- 计算敌人移动方向（朝向玩家）
        local toPlayerX = playerX - pos.x
        local toPlayerY = playerY - pos.y
        local toPlayerLen = math.sqrt(toPlayerX * toPlayerX + toPlayerY * toPlayerY)
        
        if toPlayerLen > 0.1 then
            toPlayerX = toPlayerX / toPlayerLen
            toPlayerY = toPlayerY / toPlayerLen
        end
        
        -- 获取敌人速度
        local speed = enemy.moveSpeed or 4.0
        
        -- 计算危险半径（基于敌人类型）
        local dangerRadius = config.collisionDangerRadius
        local threatWeight = config.threatWeight[enemy.id] or config.threatWeight.default
        
        -- 自爆机额外距离
        if enemy.isSuicide or enemy.id == "SuicideBug" then
            dangerRadius = dangerRadius + config.suicideBotExtraRadius
        end
        
        -- 高速敌人额外距离
        if speed > 7.0 then
            dangerRadius = dangerRadius + config.fastEnemyExtraRadius
        end
        
        -- 预测碰撞时间
        local timeToCollision = dist / speed
        
        -- 只考虑会在预判时间内到达的敌人
        if timeToCollision < config.collisionPredictTime or dist < dangerRadius then
            -- 预测敌人未来位置
            local predictTime = math.min(config.collisionPredictTime, timeToCollision)
            local futureX = pos.x + toPlayerX * speed * predictTime
            local futureY = pos.y + toPlayerY * speed * predictTime
            local futureDist = Math.Distance(playerX, playerY, futureX, futureY)
            
            if futureDist < dangerRadius or dist < dangerRadius then
                -- 计算危险值
                local danger = threatWeight * (1 - math.min(dist, futureDist) / dangerRadius)
                danger = danger * (1 / math.max(0.2, timeToCollision))
                
                -- 自爆机危险加倍
                if enemy.isSuicide or enemy.id == "SuicideBug" then
                    danger = danger * 2.0
                end
                
                table.insert(threats, {
                    type = "enemy",
                    enemy = enemy,
                    x = pos.x,
                    y = pos.y,
                    futureX = futureX,
                    futureY = futureY,
                    dirX = toPlayerX,
                    dirY = toPlayerY,
                    speed = speed,
                    distance = dist,
                    futureDist = futureDist,
                    timeToCollision = timeToCollision,
                    danger = danger,
                    dangerRadius = dangerRadius,
                })
            end
        end
    end
    
    return threats
end

-- ============================================================================
-- 躲避向量计算
-- ============================================================================

function AutoBattle.CalculateEvadeVector(playerX, playerY, bulletThreats, enemyThreats)
    local evadeX, evadeY = 0, 0
    local totalDanger = 0
    
    -- 躲避子弹
    for _, threat in ipairs(bulletThreats) do
        -- 计算垂直于子弹方向的躲避向量
        local perpX = -threat.dirY
        local perpY = threat.dirX
        
        -- 选择更好的躲避方向
        local testX = playerX + perpX
        local testY = playerY + perpY
        local testDist = AutoBattle.PointToSegmentDistance(
            testX, testY,
            threat.x, threat.y,
            threat.x + threat.dirX * threat.speed * 0.5,
            threat.y + threat.dirY * threat.speed * 0.5
        )
        if testDist < threat.distance then
            perpX, perpY = -perpX, -perpY
        end
        
        evadeX = evadeX + perpX * threat.danger
        evadeY = evadeY + perpY * threat.danger
        totalDanger = totalDanger + threat.danger
    end
    
    -- 躲避敌人碰撞
    for _, threat in ipairs(enemyThreats) do
        -- 远离敌人（和预测位置）
        local awayX = playerX - (threat.x + threat.futureX) / 2
        local awayY = playerY - (threat.y + threat.futureY) / 2
        
        local len = math.sqrt(awayX * awayX + awayY * awayY)
        if len > 0.01 then
            awayX = awayX / len
            awayY = awayY / len
        end
        
        -- 添加侧向分量（不要直线后退，容易被追上）
        local sideX = -awayY
        local sideY = awayX
        local sideWeight = 0.3
        
        -- 根据时间选择侧向
        local sideSign = math.sin(AutoBattle.stateTimer * 2 + threat.x) > 0 and 1 or -1
        
        evadeX = evadeX + (awayX + sideX * sideWeight * sideSign) * threat.danger
        evadeY = evadeY + (awayY + sideY * sideWeight * sideSign) * threat.danger
        totalDanger = totalDanger + threat.danger
    end
    
    -- 计算躲避强度（0-1）
    local evadeStrength = math.min(1.0, totalDanger / 3.0)
    
    -- 归一化
    local len = math.sqrt(evadeX * evadeX + evadeY * evadeY)
    if len > 0.01 then
        evadeX = evadeX / len
        evadeY = evadeY / len
    else
        evadeX, evadeY = 0, 0
    end
    
    return evadeX, evadeY, evadeStrength
end

-- ============================================================================
-- 进攻向量
-- ============================================================================

function AutoBattle.SelectTarget(playerX, playerY, enemies)
    local config = AutoBattle.config
    local debug = AutoBattle.debug
    
    -- 保持当前目标（如果还活着且在冷却中）
    if AutoBattle.currentTarget and AutoBattle.targetSwitchCooldown > 0 then
        local t = AutoBattle.currentTarget
        if t.hp and t.hp > 0 and t.node then
            debug.targetEnemy = t
            return
        end
    end
    
    -- 选择新目标
    local bestTarget = nil
    local bestScore = -9999
    
    for _, enemy in ipairs(enemies) do
        local dist = enemy._dist or 999
        
        if dist < config.attackRange then
            local priority = config.targetPriority[enemy.id] or config.targetPriority.default
            local score = priority - dist * 1.5
            
            -- 低血量加分
            if enemy.hp and enemy.maxHp and enemy.hp < enemy.maxHp * 0.3 then
                score = score + 25
            end
            
            if score > bestScore then
                bestScore = score
                bestTarget = enemy
            end
        end
    end
    
    -- 没有范围内目标，选最近的
    if not bestTarget and #enemies > 0 then
        local minDist = 999
        for _, enemy in ipairs(enemies) do
            if enemy._dist < minDist then
                minDist = enemy._dist
                bestTarget = enemy
            end
        end
    end
    
    AutoBattle.currentTarget = bestTarget
    AutoBattle.targetSwitchCooldown = 0.5
    debug.targetEnemy = bestTarget
end

function AutoBattle.CalculateAttackVector(playerX, playerY)
    local target = AutoBattle.currentTarget
    if not target or not target.node then
        return 0, 0
    end
    
    local config = AutoBattle.config
    local pos = target._pos or target.node.position
    local dist = target._dist or Math.Distance(playerX, playerY, pos.x, pos.y)
    
    local toX = pos.x - playerX
    local toY = pos.y - playerY
    
    local len = math.sqrt(toX * toX + toY * toY)
    if len < 0.01 then return 0, 0 end
    
    toX = toX / len
    toY = toY / len
    
    -- 根据距离调整
    if dist > config.optimalRange then
        -- 太远：靠近
        return toX, toY
    else
        -- 最优距离：绕圈
        local circleX = -toY * 0.4
        local circleY = toX * 0.4
        return toX * 0.3 + circleX, toY * 0.3 + circleY
    end
end

-- ============================================================================
-- 智能拾取（综合考虑安全性和价值）
-- ============================================================================

function AutoBattle.CalculateSmartPickup(playerX, playerY, moveX, moveY, enemyThreats, bulletThreats)
    local config = AutoBattle.config
    local pickups = Pickup.GetList()
    local debug = AutoBattle.debug
    
    local bestPickup = nil
    local bestScore = -9999
    
    -- 归一化移动方向
    local moveLen = math.sqrt(moveX * moveX + moveY * moveY)
    local moveDirX, moveDirY = 0, 0
    if moveLen > 0.01 then
        moveDirX = moveX / moveLen
        moveDirY = moveY / moveLen
    end
    
    for _, pickup in ipairs(pickups) do
        if pickup.node then
            local pos = pickup.node.position
            local dist = Math.Distance(playerX, playerY, pos.x, pos.y)
            
            if dist < config.pickupSearchRadius and dist > 0.5 then
                -- 计算方向
                local toX = (pos.x - playerX) / dist
                local toY = (pos.y - playerY) / dist
                
                -- ========================================
                -- 1. 方向得分（沿途优先）
                -- ========================================
                local dirScore = 0
                if moveLen > 0.01 then
                    local dot = moveDirX * toX + moveDirY * toY
                    dirScore = dot  -- -1 到 1
                else
                    dirScore = 0.5  -- 没有移动方向时，中性
                end
                
                -- ========================================
                -- 2. 安全得分（远离威胁）
                -- ========================================
                local safetyScore = 1.0
                
                -- 检查敌人威胁
                for _, threat in ipairs(enemyThreats) do
                    local threatDist = Math.Distance(pos.x, pos.y, threat.futureX, threat.futureY)
                    if threatDist < threat.dangerRadius then
                        safetyScore = safetyScore - (1 - threatDist / threat.dangerRadius) * 0.5
                    end
                end
                
                -- 检查子弹威胁
                for _, threat in ipairs(bulletThreats) do
                    local bulletFutureX = threat.x + threat.dirX * threat.speed * 0.5
                    local bulletFutureY = threat.y + threat.dirY * threat.speed * 0.5
                    local pathDist = AutoBattle.PointToSegmentDistance(
                        pos.x, pos.y, threat.x, threat.y, bulletFutureX, bulletFutureY
                    )
                    if pathDist < 2.0 then
                        safetyScore = safetyScore - (1 - pathDist / 2.0) * 0.3
                    end
                end
                
                safetyScore = math.max(0, safetyScore)
                
                -- ========================================
                -- 3. 价值得分
                -- ========================================
                local value = pickup.amount or 1
                local valueScore = math.log(value + 1) / math.log(10)  -- 对数缩放
                
                -- ========================================
                -- 4. 距离惩罚
                -- ========================================
                local distPenalty = dist / config.pickupSearchRadius
                
                -- ========================================
                -- 综合得分
                -- ========================================
                local score = dirScore * 1.5                         -- 方向权重
                            + safetyScore * config.pickupSafetyWeight * 3  -- 安全权重
                            + valueScore * config.pickupValueWeight * 2    -- 价值权重
                            - distPenalty * 1.0                       -- 距离惩罚
                
                -- 如果在移动方向上（dot > 0.5），额外加分
                if dirScore > 0.5 then
                    score = score + 1.0
                end
                
                -- 如果非常安全（safetyScore > 0.8），额外加分
                if safetyScore > 0.8 then
                    score = score + 0.5
                end
                
                if score > bestScore then
                    bestScore = score
                    bestPickup = pickup
                end
            end
        end
    end
    
    debug.bestPickup = bestPickup
    
    if bestPickup and bestScore > -1 then
        local pos = bestPickup.node.position
        local toX = pos.x - playerX
        local toY = pos.y - playerY
        
        local len = math.sqrt(toX * toX + toY * toY)
        if len > 0.01 then
            return toX / len, toY / len
        end
    end
    
    return 0, 0
end

-- ============================================================================
-- 边界向量
-- ============================================================================

function AutoBattle.CalculateEdgeVector(playerX, playerY)
    local config = AutoBattle.config
    local edgeX, edgeY = 0, 0
    
    local margin = config.edgeMargin
    local halfW = config.mapHalfWidth
    local halfH = config.mapHalfHeight
    
    if playerX < -halfW + margin then
        local u = 1.0 - (playerX + halfW) / margin
        edgeX = edgeX + u * u
    end
    if playerX > halfW - margin then
        local u = 1.0 - (halfW - playerX) / margin
        edgeX = edgeX - u * u
    end
    if playerY < -halfH + margin then
        local u = 1.0 - (playerY + halfH) / margin
        edgeY = edgeY + u * u
    end
    if playerY > halfH - margin then
        local u = 1.0 - (halfH - playerY) / margin
        edgeY = edgeY - u * u
    end
    
    local len = math.sqrt(edgeX * edgeX + edgeY * edgeY)
    if len > 0.01 then
        return edgeX / len, edgeY / len
    end
    return 0, 0
end

-- ============================================================================
-- 工具函数
-- ============================================================================

-- 点到线段的距离
function AutoBattle.PointToSegmentDistance(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local lenSq = dx * dx + dy * dy
    
    if lenSq < 0.0001 then
        return Math.Distance(px, py, x1, y1)
    end
    
    local t = ((px - x1) * dx + (py - y1) * dy) / lenSq
    t = math.max(0, math.min(1, t))
    
    return Math.Distance(px, py, x1 + t * dx, y1 + t * dy)
end

-- ============================================================================
-- 调试接口
-- ============================================================================

function AutoBattle.GetDebugInfo()
    return AutoBattle.debug
end

function AutoBattle.GetConfig()
    return AutoBattle.config
end

function AutoBattle.GetCurrentTarget()
    return AutoBattle.currentTarget
end

return AutoBattle
