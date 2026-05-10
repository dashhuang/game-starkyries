-- ============================================================================
-- 星河战姬 Starkyries - 敌人行为AI模块
-- ============================================================================
-- 
-- 职责：计算敌人的移动方向和速度
-- 
-- 支持的行为类型：
--   - CHASE/TANK: 直接追击玩家
--   - SWARM: 快速追击，带随机摆动
--   - ORBIT/SNIPER: 环绕保持距离
--   - BOMBER: 自爆虫（接近→蓄力→冲刺→爆炸）
--   - SUPPORT: 治疗虫（随机游荡，治疗友军）
--   - BOSS: Boss行为（阶段性变化）
-- 
-- 用法：
--   local moveX, moveY, speed = EnemyBehavior.Calculate(enemy, dt, playerX, playerY, context)
-- 
-- ============================================================================

local Settings = nil
local Enemies = nil
local Math = nil

--- 延迟加载依赖（避免循环引用）
local function LoadDependencies()
    if not Settings then
        Settings = require("config.settings")
        Enemies = require("config.enemies")
        Math = require("utils.Math")
    end
end

local EnemyBehavior = {}

-- ============================================================================
-- 行为AI - 计算移动方向和速度
-- ============================================================================

-- 执行 CHASE / TANK 行为
local function ExecuteChase(enemy, pos, playerX, playerY)
    local moveX, moveY = Math.Normalize(playerX - pos.x, playerY - pos.y)
    return moveX, moveY, enemy.moveSpeed
end

-- 执行 SWARM 行为（快速追击，略带随机摆动）
local function ExecuteSwarm(enemy, pos, playerX, playerY)
    local dx, dy = Math.Normalize(playerX - pos.x, playerY - pos.y)
    local wobble = math.sin(os.clock() * 5 + enemy.orbitAngle) * 0.3
    local moveX = dx + wobble * dy
    local moveY = dy - wobble * dx
    moveX, moveY = Math.Normalize(moveX, moveY)
    return moveX, moveY, enemy.moveSpeed
end

-- 执行 ORBIT / SNIPER 行为（环绕保持距离）
local function ExecuteOrbit(enemy, pos, playerX, playerY)
    local dist = Math.Distance(pos.x, pos.y, playerX, playerY)
    local attackRange = enemy.attackRange or 10
    local optimalDist = attackRange - 2  -- 比攻击范围近2米，确保能射击
    
    -- 计算当前相对玩家的角度
    local dx = pos.x - playerX
    local dy = pos.y - playerY
    local currentAngle = math.atan2(dy, dx)
    
    local moveX, moveY
    if dist > optimalDist + 2 then
        -- 太远：向玩家靠近，同时略微环绕
        local approachAngle = currentAngle + enemy.orbitDir * 0.3
        moveX = -math.cos(approachAngle)
        moveY = -math.sin(approachAngle)
    elseif dist < optimalDist - 2 then
        -- 太近：远离玩家，同时略微环绕
        local retreatAngle = currentAngle + enemy.orbitDir * 0.3
        moveX = math.cos(retreatAngle)
        moveY = math.sin(retreatAngle)
    else
        -- 最佳距离：纯环绕（切线方向）
        local tangentAngle = currentAngle + enemy.orbitDir * math.pi / 2
        moveX = math.cos(tangentAngle)
        moveY = math.sin(tangentAngle)
    end
    
    return moveX, moveY, enemy.moveSpeed
end

-- 执行 BOMBER 行为（自爆虫：接近 → 蓄力 → 冲刺 → 自爆）
local function ExecuteBomber(enemy, pos, playerX, playerY, dt)
    local moveX, moveY = 0, 0
    local speed = enemy.moveSpeed
    
    if enemy.isSuicide then
        local dist = Math.Distance(pos.x, pos.y, playerX, playerY)
        
        if enemy.chargeState == "approach" then
            -- 阶段1：慢速接近玩家
            moveX, moveY = Math.Normalize(playerX - pos.x, playerY - pos.y)
            speed = enemy.moveSpeed  -- 使用慢速（3.0）
            
            -- 到达蓄力距离时开始蓄力
            if dist <= enemy.chargeDistance then
                enemy.chargeState = "charging"
                enemy.chargeTimer = 0
                -- 记录蓄力开始时玩家位置作为冲刺目标
                enemy.chargeTargetX = playerX
                enemy.chargeTargetY = playerY
            end
            
        elseif enemy.chargeState == "charging" then
            -- 阶段2：原地闪红蓄力（不移动）
            moveX, moveY = 0, 0
            speed = 0
            enemy.chargeTimer = enemy.chargeTimer + dt
            
            -- 闪红效果：通过修改材质发光强度实现
            enemy.isCharging = true
            enemy.chargeProgress = enemy.chargeTimer / enemy.chargeDelay
            
            -- 蓄力完成，开始冲刺
            if enemy.chargeTimer >= enemy.chargeDelay then
                enemy.chargeState = "dash"
                enemy.isCharging = false
            end
            
        elseif enemy.chargeState == "dash" then
            -- 阶段3：快速冲向蓄力时记录的目标位置
            local targetX = enemy.chargeTargetX or playerX
            local targetY = enemy.chargeTargetY or playerY
            local distToTarget = Math.Distance(pos.x, pos.y, targetX, targetY)
            
            moveX, moveY = Math.Normalize(targetX - pos.x, targetY - pos.y)
            speed = enemy.chargeSpeed  -- 使用冲刺速度（15.0）
            
            -- 到达目标位置或接近玩家时自爆
            local detonateRange = 1.5
            if distToTarget < detonateRange or dist < detonateRange then
                enemy.shouldExplode = true
                enemy.explodeX = pos.x
                enemy.explodeY = pos.y
            end
        end
    else
        -- 非自爆单位的BOMBER行为：直接冲向玩家
        moveX, moveY = Math.Normalize(playerX - pos.x, playerY - pos.y)
    end
    
    return moveX, moveY, speed
end

-- 执行 SUPPORT 行为（治疗虫：随机游荡 + 治疗友军）
-- @param healCallback function(healerPos, targetPos, amount) 治疗回调
-- @param enemyList table 敌人列表（用于查找受伤友军）
local function ExecuteSupport(enemy, pos, playerX, playerY, dt, healCallback, enemyList)
    LoadDependencies()
    
    local moveX, moveY = 0, 0
    
    -- 初始化随机游荡目标
    if not enemy.wanderTargetX or not enemy.wanderTimer then
        enemy.wanderTimer = 0
    end
    
    -- 定期更换游荡目标
    enemy.wanderTimer = enemy.wanderTimer - dt
    if enemy.wanderTimer <= 0 then
        -- 在当前位置附近随机选择一个目标点（5-10米范围）
        local angle = math.random() * math.pi * 2
        local dist = 5 + math.random() * 5
        enemy.wanderTargetX = pos.x + math.cos(angle) * dist
        enemy.wanderTargetY = pos.y + math.sin(angle) * dist
        
        -- 限制在战场范围内
        local area = Settings.BattleArea
        enemy.wanderTargetX = Math.Clamp(enemy.wanderTargetX, area.MinX + 2, area.MaxX - 2)
        enemy.wanderTargetY = Math.Clamp(enemy.wanderTargetY, area.MinY + 2, area.MaxY - 2)
        
        -- 下次换目标的时间（2-4秒）
        enemy.wanderTimer = 2 + math.random() * 2
    end
    
    -- 朝游荡目标移动
    local distToTarget = Math.Distance(pos.x, pos.y, enemy.wanderTargetX, enemy.wanderTargetY)
    if distToTarget > 1.0 then
        moveX, moveY = Math.Normalize(enemy.wanderTargetX - pos.x, enemy.wanderTargetY - pos.y)
    end
    
    -- 治疗逻辑
    if enemy.canHeal then
        enemy.healTimer = (enemy.healTimer or 0) + dt
        local healCooldown = enemy.healCooldown or 2.0
        
        if enemy.healTimer >= healCooldown then
            enemy.healTimer = 0
            
            -- 查找范围内受伤的友军
            local healRange = enemy.healRange or 8.0
            local healAmount = enemy.healAmount or 2
            
            for _, ally in ipairs(enemyList) do
                if ally ~= enemy and ally.hp < ally.maxHp then
                    local allyPos = ally.node.position
                    local allyDist = Math.Distance(pos.x, pos.y, allyPos.x, allyPos.y)
                    
                    if allyDist <= healRange then
                        -- 治疗友军
                        ally.hp = math.min(ally.maxHp, ally.hp + healAmount)
                        
                        -- 触发治疗回调（用于特效）
                        if healCallback then
                            healCallback(pos.x, pos.y, allyPos.x, allyPos.y, healAmount)
                        end
                    end
                end
            end
        end
    end
    
    return moveX, moveY, enemy.moveSpeed
end

-- 执行 BOSS 行为（根据阶段变化）
local function ExecuteBoss(enemy, pos, playerX, playerY, dt)
    local dist = Math.Distance(pos.x, pos.y, playerX, playerY)
    local optimalDist = 8  -- Boss保持距离
    
    local moveX, moveY
    
    -- 第三阶段（狂暴冲锋）直接追击
    if enemy.currentPhase and enemy.currentPhase >= 3 then
        moveX, moveY = Math.Normalize(playerX - pos.x, playerY - pos.y)
    else
        -- 保持距离，缓慢逼近
        if dist > optimalDist + 3 then
            moveX, moveY = Math.Normalize(playerX - pos.x, playerY - pos.y)
        elseif dist < optimalDist - 2 then
            moveX, moveY = Math.Normalize(pos.x - playerX, pos.y - playerY)
        else
            -- 缓慢环绕
            enemy.orbitAngle = enemy.orbitAngle + enemy.orbitDir * dt * 0.3
            moveX = -math.sin(enemy.orbitAngle) * 0.5
            moveY = math.cos(enemy.orbitAngle) * 0.5
        end
    end
    
    return moveX, moveY, enemy.moveSpeed
end

-- ============================================================================
-- 主入口：根据行为类型计算移动
-- ============================================================================

---@param enemy table 敌人对象
---@param dt number 时间增量
---@param playerX number 玩家X坐标
---@param playerY number 玩家Y坐标
---@param context table 上下文 {healCallback, enemyList}
---@return number moveX 移动方向X
---@return number moveY 移动方向Y
---@return number speed 移动速度
function EnemyBehavior.Calculate(enemy, dt, playerX, playerY, context)
    LoadDependencies()
    
    local pos = enemy.node.position
    local behavior = enemy.behavior
    
    if behavior == Enemies.Behaviors.CHASE or 
       behavior == Enemies.Behaviors.TANK then
        return ExecuteChase(enemy, pos, playerX, playerY)
        
    elseif behavior == Enemies.Behaviors.SWARM then
        return ExecuteSwarm(enemy, pos, playerX, playerY)
        
    elseif behavior == Enemies.Behaviors.ORBIT or
           behavior == Enemies.Behaviors.SNIPER then
        return ExecuteOrbit(enemy, pos, playerX, playerY)
        
    elseif behavior == Enemies.Behaviors.BOMBER then
        return ExecuteBomber(enemy, pos, playerX, playerY, dt)
        
    elseif behavior == Enemies.Behaviors.SUPPORT then
        local healCallback = context and context.healCallback
        local enemyList = context and context.enemyList or {}
        return ExecuteSupport(enemy, pos, playerX, playerY, dt, healCallback, enemyList)
        
    elseif behavior == Enemies.Behaviors.BOSS then
        return ExecuteBoss(enemy, pos, playerX, playerY, dt)
        
    else
        -- 默认行为：追击
        return ExecuteChase(enemy, pos, playerX, playerY)
    end
end

return EnemyBehavior
