-- ============================================================================
-- 星河战姬 Starkyries - 无人机实体管理
-- 无人机行为：飞出去近距离攻击敌人，然后返回玩家身边
-- ============================================================================

local Settings = require("config.settings")
local Weapons = require("config.weapons")
local Materials = require("render.Materials")
local Math = require("utils.Math")
local EventBus = require("utils.EventBus")

local Drone = {}

-- 懒加载 Game 模块（避免循环依赖）
local Game = nil
local function GetGame()
    if not Game then
        Game = require("core.Game")
    end
    return Game
end

-- 无人机列表
Drone.list = {}

-- 场景引用（由 main.lua 设置）
Drone.scene = nil

-- 回调
Drone.onFire = nil  -- function(drone, targetX, targetY, damage, isCrit, aoeRadius)

-- 无人机状态
Drone.State = {
    IDLE = "idle",           -- 环绕玩家待机
    ATTACKING = "attacking", -- 飞向目标
    RETURNING = "returning", -- 返回玩家身边
}

-- ============================================================================
-- 无人机配置
-- ⚠️ 重要概念区分（避免混淆）：
--   - seekRange：寻敌范围，无人机能飞多远去找敌人
--   - attackRange：攻击射程，无人机离敌人多近才开始攻击
--   - weapons.lua 中的 range：对应 seekRange（寻敌范围）
-- 
-- 例如轰炸无人机：seekRange=30m 表示能飞30米找敌人，
--                attackRange=4m 表示要飞到敌人4米内才投弹（贴脸攻击）
-- ============================================================================
Drone.Config = {
    FighterDrone = {
        attackRange = 6.0,    -- 攻击射程（文档：6m）
        seekRange = 20.0,     -- 寻敌范围 20米
        flySpeed = 15.0,      -- 飞行速度
        returnSpeed = 12.0,   -- 返回速度
    },
    BomberDrone = {
        attackRange = 4.0,    -- 攻击射程（贴脸投弹，需要飞到敌人附近）
        seekRange = 30.0,     -- 寻敌范围 30米（能飞多远找敌人）
        flySpeed = 12.0,      -- 飞行速度（轰炸机稍慢）
        returnSpeed = 10.0,   -- 返回速度
    },
    RepairDrone = {
        attackRange = 0,      -- 不攻击
        seekRange = 0,        -- 不寻敌
        flySpeed = 0,
        returnSpeed = 0,
    },
}

-- ============================================================================
-- 创建无人机
-- ============================================================================

function Drone.Create(scene, weaponId, tier, playerX, playerY, orbitIndex)
    local def = Weapons.Get(weaponId)
    if not def or not def.isDrone then return nil end
    
    Drone.scene = scene
    
    local node = scene:CreateChild("Drone")
    
    -- 初始位置（环绕玩家）
    local orbitRadius = def.droneOrbitRadius or 3.0
    local angle = (orbitIndex or 0) * (math.pi * 2 / 6)  -- 最多6个无人机均匀分布
    local x = playerX + math.cos(angle) * orbitRadius
    local y = playerY + math.sin(angle) * orbitRadius
    node.position = Vector3(x, y, 0)
    
    -- 外观
    local color = def.color or {r = 0.5, g = 0.8, b = 1.0}
    local scale = 0.5
    
    -- 主体
    local body = node:CreateChild("Body")
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    body:SetScale(Vector3(scale * 1.2, scale * 0.5, scale * 0.4))
    bodyModel:SetMaterial(Materials.CreatePBR(color.r, color.g, color.b, 0.8, 0.3))
    
    -- 引擎光效
    local engine = node:CreateChild("Engine")
    engine.position = Vector3(-scale * 0.5, 0, 0)
    local engineModel = engine:CreateComponent("StaticModel")
    engineModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    engine:SetScale(scale * 0.3)
    engineModel:SetMaterial(Materials.CreateGlow(color.r, color.g, color.b, 2.0))
    
    -- 计算伤害
    local tierMult = Settings.WeaponTierMultiplier[tier] or 1.0
    local baseDamage = def.damage * tierMult
    
    -- 获取无人机配置
    local droneConfig = Drone.Config[weaponId] or Drone.Config.FighterDrone
    
    -- 🔴 每架无人机的攻击角度偏移（防止多架无人机重叠）
    -- 基于 orbitIndex 分配不同角度，加上随机扰动
    local attackAngleOffset = (orbitIndex or 0) * (math.pi * 2 / 6) + math.random() * 0.5
    
    -- 获取 tier-based cooldown（战斗无人机等有分层冷却）
    local cooldown = def.cooldown or 1.0
    if def.tierCooldown and def.tierCooldown[tier] then
        cooldown = def.tierCooldown[tier]
    end
    
    -- 获取 tier-based shieldRegen（修复无人机）
    local shieldRegen = def.shieldRegen or 0
    if def.tierShieldRegen and def.tierShieldRegen[tier] then
        shieldRegen = def.tierShieldRegen[tier]
    end
    
    local drone = {
        node = node,
        weaponId = weaponId,
        tier = tier,
        damage = baseDamage,
        cooldown = cooldown,
        shieldRegen = shieldRegen,
        currentCooldown = 0,
        aoeRadius = def.aoeRadius,
        orbitRadius = orbitRadius,
        orbitAngle = angle,
        orbitSpeed = 1.5,
        orbitIndex = orbitIndex or 0,
        
        -- 状态机
        state = Drone.State.IDLE,
        target = nil,
        
        -- 🔴 攻击位置偏移（每架无人机围绕目标的不同角度攻击）
        attackAngleOffset = attackAngleOffset,
        attackOrbitRadius = droneConfig.attackRange * 0.7,  -- 围绕目标的距离
        
        -- 配置
        attackRange = droneConfig.attackRange,
        seekRange = droneConfig.seekRange,
        flySpeed = droneConfig.flySpeed,
        returnSpeed = droneConfig.returnSpeed,
        
        -- 颜色（用于特效）
        color = color,
    }
    
    table.insert(Drone.list, drone)
    return drone
end

-- ============================================================================
-- 更新所有无人机
-- ============================================================================

function Drone.UpdateAll(dt, playerX, playerY, enemies, damageMultiplier, critChance, critDamage)
    for _, drone in ipairs(Drone.list) do
        Drone.UpdateOne(drone, dt, playerX, playerY, enemies, damageMultiplier, critChance, critDamage)
    end
end

function Drone.UpdateOne(drone, dt, playerX, playerY, enemies, damageMultiplier, critChance, critDamage)
    local pos = drone.node.position
    
    -- 安全检查：如果位置异常（NaN 或超出战斗区域），强制重置到玩家身边
    local maxDist = 50  -- 最大允许离玩家距离（战斗区域约 75×50 米）
    local distToPlayer = Math.Distance(pos.x, pos.y, playerX, playerY)
    local posInvalid = distToPlayer ~= distToPlayer or  -- NaN check
                       distToPlayer > maxDist or
                       math.abs(pos.x) > 50 or  -- 超出战斗区域
                       math.abs(pos.y) > 35
    
    if posInvalid then
        -- 位置异常，强制重置到玩家身边
        pos.x = playerX + math.cos(drone.orbitAngle) * drone.orbitRadius
        pos.y = playerY + math.sin(drone.orbitAngle) * drone.orbitRadius
        drone.node.position = pos
        drone.target = nil
        drone.state = Drone.State.IDLE
        return  -- 跳过本帧更新
    end
    
    -- 更新攻击冷却
    drone.currentCooldown = drone.currentCooldown - dt
    
    -- 🔴 关键：始终更新环绕角度，防止多架无人机重叠
    -- 即使在攻击/返回状态，也要保持角度差异，确保返回后不会重叠
    drone.orbitAngle = drone.orbitAngle + drone.orbitSpeed * dt
    
    -- 状态机
    if drone.state == Drone.State.IDLE then
        -- 待机状态：环绕玩家
        local targetX = playerX + math.cos(drone.orbitAngle) * drone.orbitRadius
        local targetY = playerY + math.sin(drone.orbitAngle) * drone.orbitRadius
        
        -- 平滑移动到环绕位置
        local moveSpeed = 8.0
        pos.x = pos.x + (targetX - pos.x) * moveSpeed * dt
        pos.y = pos.y + (targetY - pos.y) * moveSpeed * dt
        drone.node.position = pos
        
        -- 朝向前进方向
        local faceAngle = drone.orbitAngle + math.pi / 2
        drone.node.rotation = Quaternion(0, 0, math.deg(faceAngle))
        
        -- 冷却完成后寻找目标
        if drone.currentCooldown <= 0 and drone.seekRange > 0 then
            -- 🔴 轰炸无人机特殊逻辑：如果有lastTarget，优先攻击它
            if drone.weaponId == "BomberDrone" and drone.lastTarget then
                local lastTarget = drone.lastTarget
                -- 检查lastTarget是否仍然有效
                if lastTarget.hp > 0 and lastTarget.node then
                    drone.target = lastTarget
                    drone.lastTarget = nil  -- 清除，避免重复使用
                    drone.state = Drone.State.ATTACKING
                else
                    -- lastTarget已死亡，清除并正常寻敌
                    drone.lastTarget = nil
                    local target = Drone.FindTargetInRange(drone, enemies, playerX, playerY, drone.seekRange)
                    if target then
                        drone.target = target
                        drone.state = Drone.State.ATTACKING
                    end
                end
            else
                local target = Drone.FindTargetInRange(drone, enemies, playerX, playerY, drone.seekRange)
                if target then
                    drone.target = target
                    drone.state = Drone.State.ATTACKING
                end
            end
        end
        
    elseif drone.state == Drone.State.ATTACKING then
        -- 攻击状态：飞向目标并持续攻击直到目标死亡
        if not drone.target or not drone.target.node or drone.target.hp <= 0 then
            -- 目标死亡或无效，直接寻找离玩家最近的敌人继续攻击
            drone.target = nil
            local newTarget = Drone.FindNearestEnemy(enemies, playerX, playerY)
            if newTarget then
                -- 找到新目标，继续攻击（不返回）
                drone.target = newTarget
                -- 保持 ATTACKING 状态
            else
                -- 没有目标了，返回玩家身边
                drone.state = Drone.State.RETURNING
            end
        end
        
        -- 有目标时执行攻击逻辑
        if drone.target and drone.target.node and drone.target.hp > 0 then
            local targetPos = drone.target.node.position
            
            -- 🔴 安全检查：验证目标位置是否合理（防止节点销毁后返回异常值）
            local targetValid = targetPos and 
                targetPos.x == targetPos.x and  -- NaN check
                targetPos.y == targetPos.y and
                math.abs(targetPos.x) < 100 and 
                math.abs(targetPos.y) < 100
            
            if not targetValid then
                -- 目标位置异常，放弃目标返回
                drone.target = nil
                drone.state = Drone.State.RETURNING
                return
            end
            
            -- 🔴 关键：计算围绕目标的攻击位置（每架无人机位置不同）
            -- 无人机不直接飞向目标中心，而是飞向目标周围的某个位置
            local orbitDist = drone.attackOrbitRadius or (drone.attackRange * 0.7)
            local attackPosX = targetPos.x + math.cos(drone.attackAngleOffset) * orbitDist
            local attackPosY = targetPos.y + math.sin(drone.attackAngleOffset) * orbitDist
            
            local distToAttackPos = Math.Distance(pos.x, pos.y, attackPosX, attackPosY)
            local distToTarget = Math.Distance(pos.x, pos.y, targetPos.x, targetPos.y)
            
            -- 朝向目标（不是攻击位置）
            local angle = Math.AngleTo(pos.x, pos.y, targetPos.x, targetPos.y)
            drone.node.rotation = Quaternion(0, 0, math.deg(angle))
            
            if distToTarget <= drone.attackRange then
                -- 在攻击范围内，持续攻击（根据冷却）
                if drone.currentCooldown <= 0 then
                    -- 舰载套装：工程加成（engineering是固定值加成）
                    local g = GetGame()
                    local engineeringBonus = g and g.player and g.player.engineering or 0
                    local damage = (drone.damage + engineeringBonus) * (damageMultiplier or 1.0)
                    local isCrit = math.random() < (critChance or 0.05)
                    if isCrit then
                        damage = damage * (critDamage or 1.5)
                    end
                    
                    -- 触发攻击回调（保持向后兼容）
                    if Drone.onFire then
                        Drone.onFire(drone, targetPos.x, targetPos.y, damage, isCrit, drone.aoeRadius)
                    end
                    
                    -- 发布事件
                    EventBus.Emit(EventBus.Events.DRONE_FIRE, drone, targetPos.x, targetPos.y, damage, isCrit, drone.aoeRadius)
                    
                    -- 重置冷却
                    drone.currentCooldown = drone.cooldown
                    
                    -- 🔴 轰炸无人机特殊逻辑：每次攻击后轮换目标
                    if drone.weaponId == "BomberDrone" then
                        local currentTarget = drone.target
                        -- 寻找除当前目标外的其他敌人
                        local newTarget = Drone.FindTargetExcluding(enemies, playerX, playerY, drone.seekRange, currentTarget)
                        if newTarget then
                            -- 找到其他目标，切换
                            drone.target = newTarget
                        else
                            -- 没有其他目标，记住当前目标，先返回再攻击
                            drone.lastTarget = currentTarget
                            drone.target = nil
                            drone.state = Drone.State.RETURNING
                        end
                    end
                end
                
                -- 🔴 飞向各自的攻击位置（围绕目标），而不是目标中心
                if distToAttackPos > 0.5 then
                    local dirX, dirY = Math.Normalize(attackPosX - pos.x, attackPosY - pos.y)
                    pos.x = pos.x + dirX * drone.flySpeed * 0.5 * dt
                    pos.y = pos.y + dirY * drone.flySpeed * 0.5 * dt
                    drone.node.position = pos
                end
            else
                -- 🔴 飞向各自的攻击位置（围绕目标）
                local dirX, dirY = Math.Normalize(attackPosX - pos.x, attackPosY - pos.y)
                pos.x = pos.x + dirX * drone.flySpeed * dt
                pos.y = pos.y + dirY * drone.flySpeed * dt
                drone.node.position = pos
            end
        end
        
    elseif drone.state == Drone.State.RETURNING then
        -- 返回状态：飞回玩家身边
        local returnX = playerX + math.cos(drone.orbitAngle) * drone.orbitRadius
        local returnY = playerY + math.sin(drone.orbitAngle) * drone.orbitRadius
        local dist = Math.Distance(pos.x, pos.y, returnX, returnY)
        
        -- 朝向返回方向
        local angle = Math.AngleTo(pos.x, pos.y, returnX, returnY)
        drone.node.rotation = Quaternion(0, 0, math.deg(angle))
        
        if dist <= 1.0 then
            -- 到达，切换到待机
            drone.state = Drone.State.IDLE
        else
            -- 飞回去
            local dirX, dirY = Math.Normalize(returnX - pos.x, returnY - pos.y)
            pos.x = pos.x + dirX * drone.returnSpeed * dt
            pos.y = pos.y + dirY * drone.returnSpeed * dt
            drone.node.position = pos
        end
    end
end

-- ============================================================================
-- 加权随机选择敌人（距离越近权重越高，但保持随机性）
-- ============================================================================

-- 贴身距离阈值（5米以内算贴身，等概率随机）
local CLOSE_RANGE = Settings.Drone.CloseRange

function Drone.FindRandomTargetInRange(drone, enemies, playerX, playerY, maxRange)
    -- 收集范围内的敌人及其权重
    local candidates = {}
    local totalWeight = 0
    
    for _, enemy in ipairs(enemies) do
        if enemy.hp > 0 and enemy.node then
            local enemyPos = enemy.node.position
            local dist = Math.Distance(playerX, playerY, enemyPos.x, enemyPos.y)
            
            if dist < maxRange then
                local weight
                if dist <= CLOSE_RANGE then
                    -- 贴身范围（5米以内）：等概率随机
                    weight = 1.0
                else
                    -- 远距离：距离越远权重越低
                    local normalizedDist = (dist - CLOSE_RANGE) / (maxRange - CLOSE_RANGE)  -- 0-1
                    weight = (1 - normalizedDist) * (1 - normalizedDist)  -- 平方衰减
                    weight = math.max(weight, 0.1)  -- 最低权重 0.1
                end
                
                table.insert(candidates, {enemy = enemy, weight = weight})
                totalWeight = totalWeight + weight
            end
        end
    end
    
    -- 没有候选者
    if #candidates == 0 then return nil end
    
    -- 加权随机选择
    local roll = math.random() * totalWeight
    local accumulated = 0
    
    for _, c in ipairs(candidates) do
        accumulated = accumulated + c.weight
        if roll <= accumulated then
            return c.enemy
        end
    end
    
    -- 兜底：返回最后一个
    return candidates[#candidates].enemy
end

-- ============================================================================
-- 在指定范围内查找目标（使用加权随机）
-- ============================================================================

function Drone.FindTargetInRange(drone, enemies, playerX, playerY, maxRange)
    return Drone.FindRandomTargetInRange(drone, enemies, playerX, playerY, maxRange)
end

-- ============================================================================
-- 查找除指定目标外的其他敌人（用于轰炸无人机轮换攻击）
-- ============================================================================

function Drone.FindTargetExcluding(enemies, playerX, playerY, maxRange, excludeTarget)
    local candidates = {}
    local totalWeight = 0
    
    for _, enemy in ipairs(enemies) do
        -- 跳过被排除的目标
        if enemy == excludeTarget then goto continue end
        
        if enemy.hp > 0 and enemy.node then
            local enemyPos = enemy.node.position
            local dist = Math.Distance(playerX, playerY, enemyPos.x, enemyPos.y)
            
            if dist < maxRange then
                local weight
                if dist <= CLOSE_RANGE then
                    weight = 1.0
                else
                    local normalizedDist = (dist - CLOSE_RANGE) / (maxRange - CLOSE_RANGE)
                    weight = (1 - normalizedDist) * (1 - normalizedDist)
                    weight = math.max(weight, 0.1)
                end
                
                table.insert(candidates, {enemy = enemy, weight = weight})
                totalWeight = totalWeight + weight
            end
        end
        
        ::continue::
    end
    
    if #candidates == 0 then return nil end
    
    -- 加权随机选择
    local roll = math.random() * totalWeight
    local accumulated = 0
    
    for _, c in ipairs(candidates) do
        accumulated = accumulated + c.weight
        if roll <= accumulated then
            return c.enemy
        end
    end
    
    return candidates[#candidates].enemy
end

-- ============================================================================
-- 寻找下一个攻击目标（使用加权随机，范围更大）
-- ============================================================================

function Drone.FindNearestEnemy(enemies, playerX, playerY)
    -- 使用较大的搜索范围进行加权随机选择
    local maxRange = 30  -- 搜索范围 30 米
    
    local candidates = {}
    local totalWeight = 0
    
    for _, enemy in ipairs(enemies) do
        if enemy.hp > 0 and enemy.node then
            local enemyPos = enemy.node.position
            local dist = Math.Distance(playerX, playerY, enemyPos.x, enemyPos.y)
            
            if dist < maxRange then
                local weight
                if dist <= CLOSE_RANGE then
                    -- 贴身范围（5米以内）：等概率随机
                    weight = 1.0
                else
                    -- 远距离：距离越远权重越低
                    local normalizedDist = (dist - CLOSE_RANGE) / (maxRange - CLOSE_RANGE)  -- 0-1
                    weight = (1 - normalizedDist) * (1 - normalizedDist)  -- 平方衰减
                    weight = math.max(weight, 0.1)  -- 最低权重 0.1
                end
                
                table.insert(candidates, {enemy = enemy, weight = weight})
                totalWeight = totalWeight + weight
            end
        end
    end
    
    -- 没有候选者
    if #candidates == 0 then return nil end
    
    -- 加权随机选择
    local roll = math.random() * totalWeight
    local accumulated = 0
    
    for _, c in ipairs(candidates) do
        accumulated = accumulated + c.weight
        if roll <= accumulated then
            return c.enemy
        end
    end
    
    -- 兜底：返回最后一个
    return candidates[#candidates].enemy
end

-- ============================================================================
-- 获取无人机数量（按武器ID）
-- ============================================================================

function Drone.GetCountByWeapon(weaponId)
    local count = 0
    for _, drone in ipairs(Drone.list) do
        if drone.weaponId == weaponId then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- 移除武器的无人机
-- ============================================================================

function Drone.RemoveByWeapon(weaponId)
    for i = #Drone.list, 1, -1 do
        local drone = Drone.list[i]
        if drone.weaponId == weaponId then
            drone.node:Remove()
            table.remove(Drone.list, i)
        end
    end
end

-- ============================================================================
-- 获取
-- ============================================================================

function Drone.GetList()
    return Drone.list
end

function Drone.GetCount()
    return #Drone.list
end

-- ============================================================================
-- 重置所有无人机状态（波次开始时调用）
-- ============================================================================

function Drone.ResetAllStates(playerX, playerY)
    for _, drone in ipairs(Drone.list) do
        -- 清除目标引用
        drone.target = nil
        -- 重置状态为待机
        drone.state = Drone.State.IDLE
        -- 重置冷却
        drone.currentCooldown = 0
        -- 重置位置到玩家身边
        local x = playerX + math.cos(drone.orbitAngle) * drone.orbitRadius
        local y = playerY + math.sin(drone.orbitAngle) * drone.orbitRadius
        drone.node.position = Vector3(x, y, 0)
    end
end

-- ============================================================================
-- 清理
-- ============================================================================

function Drone.ClearAll()
    for _, drone in ipairs(Drone.list) do
        drone.node:Remove()
    end
    Drone.list = {}
end

return Drone
