-- ============================================================================
-- 星河战姬 Starkyries - 子弹/投射物系统
-- ============================================================================

local Settings = require("config.settings")
local Weapons = require("config.weapons")
local Materials = require("render.Materials")
local Math = require("utils.Math")

local Projectile = {}

-- 子弹列表
local projectiles = {}

-- 敌人子弹列表
local enemyProjectiles = {}

-- 待处理的集束爆炸列表
local pendingClusterExplosions = {}

-- ============================================================================
-- 对象池系统
-- ============================================================================

local POOL_MAX_SIZE = 100  -- 每种类型池的最大容量

-- 按模型类型分池: { modelPath = {available = {}, count = 0} }
local nodePools = {
    ["Models/Sphere.mdl"] = { available = {}, count = 0 },
    ["Models/Cone.mdl"] = { available = {}, count = 0 },
    ["Models/Cylinder.mdl"] = { available = {}, count = 0 },
}

-- 敌人子弹专用对象池（独立管理，避免与玩家子弹混用材质）
local enemyBulletPool = {
    available = {},
    count = 0,
    maxSize = 100,
}

-- 从池中获取节点
local function AcquireNode(scene, modelPath)
    local pool = nodePools[modelPath]
    if not pool then
        -- 未知模型类型，直接创建
        local node = scene:CreateChild("Bullet")
        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", modelPath))
        local light = node:CreateComponent("Light")
        light.lightType = LIGHT_POINT
        return node, model, light
    end
    
    if #pool.available > 0 then
        -- 从池中取出
        local cached = table.remove(pool.available)
        cached.node:SetEnabled(true)
        return cached.node, cached.model, cached.light
    end
    
    -- 创建新节点
    local node = scene:CreateChild("Bullet")
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", modelPath))
    local light = node:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    pool.count = pool.count + 1
    return node, model, light
end

-- 归还节点到池
local function ReleaseNode(node, model, modelPath)
    local pool = nodePools[modelPath]
    if not pool or #pool.available >= POOL_MAX_SIZE then
        -- 无池或池满，销毁
        node:Remove()
        return
    end
    
    -- 禁用并放入池
    node:SetEnabled(false)
    table.insert(pool.available, {
        node = node,
        model = model,
        light = node:GetComponent("Light"),
    })
end

-- 敌人子弹池：获取节点
local function AcquireEnemyBulletNode(scene)
    if #enemyBulletPool.available > 0 then
        local cached = table.remove(enemyBulletPool.available)
        cached.node:SetEnabled(true)
        return cached.node, cached.model
    end
    
    -- 创建新节点
    local node = scene:CreateChild("EnemyBullet")
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    node:SetScale(0.25)
    enemyBulletPool.count = enemyBulletPool.count + 1
    return node, model
end

-- 敌人子弹池：归还节点
local function ReleaseEnemyBulletNode(node, model)
    if #enemyBulletPool.available >= enemyBulletPool.maxSize then
        node:Remove()
        return
    end
    
    node:SetEnabled(false)
    table.insert(enemyBulletPool.available, {
        node = node,
        model = model,
    })
end

-- 释放敌人子弹（统一接口，处理导弹和普通子弹）
local function ReleaseEnemyProjectile(proj)
    if proj.isMissile then
        -- 导弹直接销毁，不归还池
        proj.node:Remove()
    else
        -- 普通子弹归还池
        ReleaseEnemyBulletNode(proj.node, proj.model)
    end
end

-- 清空所有池
local function ClearPools()
    for _, pool in pairs(nodePools) do
        for _, cached in ipairs(pool.available) do
            cached.node:Remove()
        end
        pool.available = {}
        pool.count = 0
    end
    
    -- 清空敌人子弹池
    for _, cached in ipairs(enemyBulletPool.available) do
        cached.node:Remove()
    end
    enemyBulletPool.available = {}
    enemyBulletPool.count = 0
end

-- 回调
Projectile.onHit = nil  -- function(projectile, enemy)
Projectile.onEnemyHitPlayer = nil  -- function(projectile, damage)

-- ============================================================================
-- 创建子弹
-- ============================================================================

-- 创建扇形力场波（近程武器专用，AOE攻击）
-- 参数：
--   scene: 场景
--   startX, startY: 武器位置（扇形圆心）
--   targetX, targetY: 目标方向（确定扇形中心朝向）
--   weaponId, tier, damage, isCrit: 武器属性
--   enemies: 敌人列表，用于AOE检测
--   onHitCallback: 命中回调 function(enemy, damage, isCrit)
-- 返回：arc对象, 命中的敌人列表
function Projectile.CreateForceFieldArc(scene, startX, startY, targetX, targetY, weaponId, tier, damage, isCrit, enemies, onHitCallback)
    local weaponDef = Weapons.Get(weaponId)
    if not weaponDef then return nil, {} end
    
    -- 扇形参数
    local range = weaponDef.range or 5.0      -- 扇形半径
    local arcAngleDeg = 45                    -- 扇形角度（度）
    local arcAngle = math.rad(arcAngleDeg)    -- 扇形角度（弧度）
    local arcSegments = 5                     -- 弧线上的点数（45度不需要太多）
    
    -- 计算朝向目标的角度
    local dx = targetX - startX
    local dy = targetY - startY
    local centerAngle = math.atan2(dy, dx)
    
    -- 创建父节点
    local arcNode = scene:CreateChild("ForceFieldArc")
    arcNode.position = Vector3(startX, startY, 0)
    
    -- 材质参数
    local intensity = isCrit and 7.0 or 5.0
    local material = Materials.Weapon(weaponDef.color, intensity)
    
    -- 创建弧线（沿扇形边缘的能量球）
    local childNodes = {}
    local startAngleOffset = -arcAngle / 2
    local angleStep = arcAngle / arcSegments
    
    for i = 0, arcSegments do
        local angle = centerAngle + startAngleOffset + angleStep * i
        local x = math.cos(angle) * range
        local y = math.sin(angle) * range
        
        -- 创建能量球
        local sphereNode = arcNode:CreateChild("ArcPoint")
        sphereNode.position = Vector3(x, y, 0)
        
        local model = sphereNode:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        
        -- 中间大，两端小（视觉效果）
        local t = math.abs(i - arcSegments / 2) / (arcSegments / 2)
        local size = (isCrit and 0.35 or 0.25) * (1.0 - t * 0.4)
        sphereNode:SetScale(size)
        model:SetMaterial(material)
        
        table.insert(childNodes, sphereNode)
    end
    
    -- 创建连接弧线的薄片（让弧线更连贯）
    for i = 1, arcSegments do
        local angle1 = centerAngle + startAngleOffset + angleStep * (i - 1)
        local angle2 = centerAngle + startAngleOffset + angleStep * i
        
        local x1 = math.cos(angle1) * range
        local y1 = math.sin(angle1) * range
        local x2 = math.cos(angle2) * range
        local y2 = math.sin(angle2) * range
        
        -- 计算线段中点和长度
        local midX = (x1 + x2) / 2
        local midY = (y1 + y2) / 2
        local segLength = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
        local segAngle = math.atan2(y2 - y1, x2 - x1)
        
        local lineNode = arcNode:CreateChild("ArcLine")
        lineNode.position = Vector3(midX, midY, 0)
        
        local model = lineNode:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        
        local thickness = isCrit and 0.12 or 0.08
        lineNode:SetScale(Vector3(thickness, segLength / 2, thickness))
        lineNode.rotation = Quaternion(0, 0, math.deg(segAngle) - 90)
        model:SetMaterial(material)
        
        table.insert(childNodes, lineNode)
    end
    
    -- AOE伤害检测：检查所有在扇形内的敌人
    local hitEnemies = {}
    if enemies then
        for _, enemy in ipairs(enemies) do
            if enemy and enemy.node then
                local pos = enemy.node.position
                local dist = Math.Distance(startX, startY, pos.x, pos.y)
                
                -- 考虑敌人体型：使用统一的边缘距离补偿
                local edgeDist, enemyRadius = Math.EdgeDistance(dist, enemy)
                
                -- 在射程内（边缘距离）
                if edgeDist <= range then
                    -- 检查是否在扇形角度内
                    local angleToEnemy = math.atan2(pos.y - startY, pos.x - startX)
                    local angleDiff = angleToEnemy - centerAngle
                    
                    -- 标准化角度差到 -π 到 π
                    while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
                    while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
                    
                    if math.abs(angleDiff) <= arcAngle / 2 then
                        table.insert(hitEnemies, enemy)
                        if onHitCallback then
                            onHitCallback(enemy, damage, isCrit)
                        end
                    end
                end
            end
        end
    end
    
    local arc = {
        node = arcNode,
        childNodes = childNodes,
        startX = startX,
        startY = startY,
        centerAngle = centerAngle,
        range = range,
        damage = damage,
        isCrit = isCrit,
        lifetime = 0.2,           -- 持续时间
        maxLifetime = 0.2,
        weaponId = weaponId,
        tier = tier,
        isForceFieldArc = true,
        hitEnemies = hitEnemies,
    }
    
    table.insert(projectiles, arc)
    return arc, hitEnemies
end

-- 保留旧函数名兼容（但推荐使用新的CreateForceFieldArc）
function Projectile.CreateEnergyChain(scene, startX, startY, targetX, targetY, weaponId, tier, damage, isCrit)
    -- 简单模式：无AOE检测，仅视觉效果
    return Projectile.CreateForceFieldArc(scene, startX, startY, targetX, targetY, weaponId, tier, damage, isCrit, nil, nil)
end

-- playerStats: {piercing, piercingDamage, explosionRangeMultiplier} 玩家属性（可选）
function Projectile.Create(scene, x, y, dirX, dirY, weaponId, tier, damage, isCrit, lockedTarget, playerStats)
    local weaponDef = Weapons.Get(weaponId)
    if not weaponDef then return nil end
    
    -- 获取玩家属性（如果传入）
    playerStats = playerStats or {}
    local playerPiercing = playerStats.piercing or 0
    local playerPiercingDamage = playerStats.piercingDamage or 1.0
    local playerExplosionMult = playerStats.explosionRangeMultiplier or 1.0
    
    -- 根据武器类型决定模型和外观
    local projSize = weaponDef.projectileSize or 0.3
    local critMult = isCrit and 1.3 or 1.0
    local modelPath
    
    if weaponDef.homing or weaponDef.type == Weapons.Types.MISSILE then
        modelPath = "Models/Cone.mdl"
    elseif weaponDef.instant or weaponDef.type == Weapons.Types.LASER then
        modelPath = "Models/Cylinder.mdl"
    else
        modelPath = "Models/Sphere.mdl"
    end
    
    -- 从对象池获取节点
    local node, model, light = AcquireNode(scene, modelPath)
    node.position = Vector3(x, y, 0)
    
    -- 设置外观
    local trailNode = nil  -- 尾焰节点
    local trailLength = weaponDef.trailLength or 0
    if weaponDef.homing or weaponDef.type == Weapons.Types.MISSILE then
        -- 导弹外观：圆锥形
        local missileScale = projSize * critMult
        node:SetScale(Vector3(missileScale * 0.4, missileScale, missileScale * 0.4))
        local angle = Math.RadToDeg(math.atan2(dirY, dirX))
        node.rotation = Quaternion(0, 0, angle - 90)
        
        -- 创建尾焰节点（如果配置了 trailLength）
        if trailLength > 0 then
            trailNode = scene:CreateChild("MissileTrail")
            local trailModel = trailNode:CreateComponent("StaticModel")
            trailModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))  -- 锥形
            
            -- 尾焰尺寸：锥形火焰，前宽后窄
            -- 导弹宽度 = missileScale * 0.4，尾焰宽度 = 导弹宽度的一半
            local missileWidth = missileScale * 0.4
            local trailWidth = missileWidth * 0.5   -- 底部宽度 = 导弹宽度的50%
            local trailLen = trailLength * missileScale * 1.5  -- 长度
            trailNode:SetScale(Vector3(trailWidth, trailLen, trailWidth))
            
            -- 尾焰位置：在导弹后方（锥形尖端朝后）
            local offsetDist = missileScale * 0.5 + trailLen * 0.5
            trailNode.position = Vector3(x - dirX * offsetDist, y - dirY * offsetDist, 0.01)
            -- 旋转：锥形默认尖端朝Y+，需要旋转180度让尖端朝后
            trailNode.rotation = Quaternion(0, 0, angle + 90)  -- +90 让尖端朝飞行反方向
            
            -- 尾焰材质：黄色火焰，半透明
            trailModel:SetMaterial(Materials.MissileTrail(1.0, 0.7, 0.1, 0.45, 2.0))
        end
    elseif weaponDef.instant or weaponDef.type == Weapons.Types.LASER then
        -- 激光外观：细长光束
        local beamWidth = (weaponDef.beamWidth or 0.15) * critMult
        local beamLength = (weaponDef.trailLength or 1.0) * 0.5
        node:SetScale(Vector3(beamWidth, beamLength, beamWidth))
        local angle = Math.RadToDeg(math.atan2(dirY, dirX))
        node.rotation = Quaternion(0, 0, angle - 90)
    else
        -- 其他：能量球
        local size = projSize * critMult
        node:SetScale(size)
        node.rotation = Quaternion.IDENTITY
    end
    
    -- 亮度设置（降低自发光强度）
    local baseIntensity = 1.5
    if weaponDef.range and weaponDef.range <= 12 then
        baseIntensity = 2.5  -- 近程稍亮
    end
    local intensity = isCrit and (baseIntensity + 1.0) or baseIntensity
    model:SetMaterial(Materials.Weapon(weaponDef.color, intensity))
    
    -- 设置点光源（降低亮度）
    local col = weaponDef.color or {r = 1, g = 1, b = 1}
    light.color = Color(col.r or col[1], col.g or col[2], col.b or col[3])
    light.brightness = isCrit and 1.0 or 0.5
    light.range = isCrit and 5.0 or 3.0
    
    -- 导弹曲线参数（随机偏移，让轨迹有弧度）
    -- homing=true: 追踪导弹，弧线飞向目标
    -- curvedFlight=true: 非追踪导弹，弧线但不追踪（纯视觉效果）
    local curveOffset = 0
    local curveDecayTime = 0.8  -- 曲线衰减时间（秒）
    local isCurvedFlight = weaponDef.curvedFlight  -- 非追踪弧线飞行标记
    
    if weaponDef.homing then
        -- 追踪导弹：根据目标距离计算曲线强度
        -- 近距离（<8米）减少曲线，避免绕圈；远距离（>15米）完整曲线
        local targetDist = playerStats.targetDistance or 20
        local curveStrength = 1.0
        if targetDist < 8 then
            -- 8米内：曲线强度从0（3米内）到1（8米）线性增加
            curveStrength = math.max(0, (targetDist - 3) / 5)
        end
        
        -- 随机偏移角度：±60度到±120度之间（确保有明显弧度）
        local sign = (math.random() > 0.5) and 1 or -1
        local baseOffset = math.rad(60) + math.random() * math.rad(60)
        curveOffset = sign * baseOffset * curveStrength
        
        -- 缩短近距离导弹的衰减时间
        curveDecayTime = 0.3 + 0.5 * curveStrength  -- 0.3秒（近）到0.8秒（远）
        
        -- 应用初始偏移到发射方向（只有在有曲线时才偏移）
        if curveStrength > 0.1 then
            local currentAngle = math.atan2(dirY, dirX)
            local offsetAngle = currentAngle + curveOffset * 0.5  -- 初始偏移一半
            dirX = math.cos(offsetAngle)
            dirY = math.sin(offsetAngle)
        end
    elseif isCurvedFlight then
        -- 非追踪弧线飞行：较小弧度，纯视觉效果
        local sign = (math.random() > 0.5) and 1 or -1
        -- 弧度范围：±0度到±30度
        local baseOffset = math.random() * math.rad(30)
        curveOffset = sign * baseOffset
        curveDecayTime = 0.5  -- 弧线持续时间
    end
    
    -- 保存原始飞行角度（偏移前，作为目标方向）
    local originalFlightAngle = math.atan2(dirY, dirX)
    
    -- 非追踪弧线：应用初始偏移（从侧面发射，然后弯向目标）
    if isCurvedFlight and curveOffset ~= 0 then
        local offsetAngle = originalFlightAngle + curveOffset
        dirX = math.cos(offsetAngle)
        dirY = math.sin(offsetAngle)
    end
    
    local proj = {
        node = node,
        model = model,
        modelPath = modelPath,  -- 用于对象池归还
        x = x,
        y = y,
        startX = x,           -- 起始位置
        startY = y,
        dirX = dirX,
        dirY = dirY,
        speed = weaponDef.projectileSpeed,
        baseDamage = damage,  -- 基础伤害（穿透前）
        damage = damage,      -- 当前伤害（穿透后可能衰减）
        isCrit = isCrit,
        homing = weaponDef.homing,
        homingStrength = weaponDef.homingStrength or 0,
        aoeRadius = weaponDef.aoeRadius and (weaponDef.aoeRadius * playerExplosionMult) or nil,
        -- 集束爆炸系统
        clusterExplosion = weaponDef.clusterExplosion,
        clusterCount = (weaponDef.tierClusterCount and weaponDef.tierClusterCount[tier]) or weaponDef.clusterCount or 6,
        clusterRadius = weaponDef.clusterRadius and (weaponDef.clusterRadius * playerExplosionMult) or 0.5,
        clusterSpread = (weaponDef.clusterSpread or 1.5) * playerExplosionMult,
        clusterDelay = weaponDef.clusterDelay or 0.05,
        -- 穿透系统
        pierce = (weaponDef.pierce or 0) + playerPiercing,  -- 总穿透次数 = 武器穿透 + 玩家穿透
        pierceCount = 0,                                     -- 已穿透次数
        piercingDamage = playerPiercingDamage,              -- 穿透伤害系数
        hitEnemies = {},                                     -- 已命中的敌人（避免重复命中）
        lifetime = 3.0,
        maxDistance = weaponDef.maxProjectileDistance or (weaponDef.range * 1.5) or 50.0,  -- 优先使用 maxProjectileDistance，否则用 射程 × 1.5
        weaponId = weaponId,
        tier = tier,
        -- 锁定目标追踪（100%命中）
        lockedTarget = lockedTarget,
        instantHit = weaponDef.instantHit,
        -- 曲线追踪参数
        curveOffset = curveOffset,           -- 曲线偏移角度
        curveDecayTime = curveDecayTime,     -- 曲线衰减时间
        flightTime = 0,                      -- 飞行时间
        isCurvedFlight = isCurvedFlight,     -- 非追踪弧线飞行标记
        originalAngle = originalFlightAngle, -- 原始飞行角度（用于弧线计算）
        -- 尾焰系统
        trailNode = trailNode,               -- 尾焰节点
        trailLength = trailLength,           -- 尾焰长度
        missileScale = (weaponDef.homing or weaponDef.type == Weapons.Types.MISSILE) and (projSize * critMult) or nil,
    }
    
    table.insert(projectiles, proj)
    return proj
end

-- ============================================================================
-- 激光束视觉效果（纯视觉，伤害在创建时即时结算）
-- ============================================================================

function Projectile.CreateLaserBeam(scene, x, y, dirX, dirY, weaponId, tier, isCrit, range)
    local weaponDef = Weapons.Get(weaponId)
    if not weaponDef then return nil end
    
    -- 计算光束终点
    local endX = x + dirX * range
    local endY = y + dirY * range
    
    -- 计算光束中点和长度
    local midX = (x + endX) / 2
    local midY = (y + endY) / 2
    local beamLength = range
    
    -- 创建光束节点
    local node = scene:CreateChild("LaserBeam")
    node.position = Vector3(midX, midY, 0)
    
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    
    -- 光束尺寸
    -- Cylinder 默认高度 1.0，缩放 Y 为 beamLength 使其长度正确
    local critMult = isCrit and 1.5 or 1.0
    local beamWidth = (weaponDef.beamWidth or 0.1) * critMult
    node:SetScale(Vector3(beamWidth, beamLength, beamWidth))
    
    -- 旋转光束对准方向
    local angle = Math.RadToDeg(math.atan2(dirY, dirX))
    node.rotation = Quaternion(0, 0, angle - 90)
    
    -- 材质
    local intensity = isCrit and 5.0 or 3.0
    model:SetMaterial(Materials.Weapon(weaponDef.color, intensity))
    
    local beam = {
        node = node,
        lifetime = 0.15,  -- 光束持续时间很短
        maxLifetime = 0.15,
        isLaserBeam = true,
        baseWidth = beamWidth,
    }
    
    table.insert(projectiles, beam)
    return beam
end

-- ============================================================================
-- 敌人子弹
-- ============================================================================

-- @param enemyInfo 可选，发射子弹的敌人信息 {id, name, projectileType}
function Projectile.CreateEnemyProjectile(scene, x, y, dirX, dirY, speed, damage, color, enemyInfo)
    local projectileType = enemyInfo and enemyInfo.projectileType or nil
    local node, model
    local isMissile = (projectileType == "missile")
    
    if isMissile then
        -- 导弹类型：使用圆锥模型，不使用对象池
        node = scene:CreateChild("EnemyMissile")
        model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
        node.position = Vector3(x, y, 0)
        -- 导弹尺寸：较大，便于识别
        node:SetScale(Vector3(0.3, 0.8, 0.3))
        -- 导弹朝向飞行方向
        local angle = Math.RadToDeg(math.atan2(dirY, dirX))
        node.rotation = Quaternion(0, 0, angle - 90)
    else
        -- 普通子弹：从对象池获取球形节点
        node, model = AcquireEnemyBulletNode(scene)
        node.position = Vector3(x, y, 0)
        node:SetScale(0.25)
    end
    
    -- 敌人子弹颜色（默认红色）
    color = color or {r = 1.0, g = 0.3, b = 0.2}
    model:SetMaterial(Materials.CreateEmissive(color.r, color.g, color.b, 3.0))
    
    local proj = {
        node = node,
        model = model,  -- 保存引用用于归还池
        x = x,
        y = y,
        dirX = dirX,
        dirY = dirY,
        speed = speed or 15,
        damage = damage or 5,
        lifetime = 10.0,  -- 10秒生存时间，确保子弹能飞越整个战场
        isEnemy = true,
        isMissile = isMissile,  -- 标记是否为导弹（用于更新朝向和释放）
        enemyInfo = enemyInfo,  -- 记录发射者信息
    }
    
    table.insert(enemyProjectiles, proj)
    return proj
end

-- ============================================================================
-- 更新
-- ============================================================================

-- 释放子弹（归还到池或销毁）
local function ReleaseProjectile(proj)
    -- 销毁尾焰节点（如果有）
    if proj.trailNode then
        proj.trailNode:Remove()
        proj.trailNode = nil
    end
    
    if proj.modelPath then
        -- 可池化的子弹，归还到池
        ReleaseNode(proj.node, proj.model, proj.modelPath)
    else
        -- 特殊类型（力场波、激光束等），直接销毁
        proj.node:Remove()
    end
end

function Projectile.UpdateAll(dt, findNearestEnemy)
    local area = Settings.BattleArea
    
    for i = #projectiles, 1, -1 do
        local proj = projectiles[i]
        proj.lifetime = proj.lifetime - dt
        
        if proj.lifetime <= 0 then
            ReleaseProjectile(proj)
            table.remove(projectiles, i)
            goto continue
        end
        
        -- 扇形力场波：淡出效果
        if proj.isForceFieldArc then
            -- 淡出效果：逐渐缩小
            local alpha = proj.lifetime / proj.maxLifetime
            local scale = 0.8 + alpha * 0.2  -- 从1.0缩小到0.8
            
            if proj.childNodes then
                for _, childNode in ipairs(proj.childNodes) do
                    if childNode then
                        local origScale = childNode.scale
                        -- 保持相对比例缩小
                        childNode:SetScale(origScale * (0.95 + alpha * 0.05))
                    end
                end
            end
            goto continue
        end
        
        -- 激光束：淡出效果
        if proj.isLaserBeam then
            local alpha = proj.lifetime / proj.maxLifetime
            -- 光束逐渐变细消失
            local currentWidth = proj.baseWidth * alpha
            local currentScale = proj.node.scale
            proj.node:SetScale(Vector3(currentWidth, currentScale.y, currentWidth))
            goto continue
        end
        
        -- 爆炸效果：扩散淡出
        if proj.isExplosionEffect then
            local alpha = proj.lifetime / proj.maxLifetime
            local progress = 1 - alpha  -- 0 → 1 随时间增加
            
            -- 多层爆炸动画（带透明度渐变）
            if proj.isMultiLayerExplosion then
                local baseRadius = proj.startScale
                local flatHeight = 0.02
                
                -- 内核：快速消失（前40%时间缩小到0）
                if proj.coreNode then
                    local coreProgress = math.min(1, progress * 2.5)  -- 加速消失
                    local coreScale = baseRadius * 0.45 * (1 - coreProgress * 0.8)  -- 缩小
                    coreScale = math.max(0.001, coreScale)
                    proj.coreNode:SetScale(Vector3(coreScale, flatHeight, coreScale))
                end
                
                -- 中层：正常扩展后缩小
                if proj.middleNode then
                    local middleScale
                    if progress < 0.5 then
                        -- 前半段：扩展
                        middleScale = baseRadius * 0.8 * (1 + progress * 0.6)
                    else
                        -- 后半段：缩小
                        local shrink = (progress - 0.5) * 2  -- 0→1
                        middleScale = baseRadius * 1.04 * (1 - shrink * 0.9)
                    end
                    middleScale = math.max(0.001, middleScale)
                    proj.middleNode:SetScale(Vector3(middleScale, flatHeight, middleScale))
                end
                
                -- 外层：持续扩展，最后缩小
                if proj.outerNode then
                    local outerScale
                    if progress < 0.7 then
                        -- 前70%：扩展
                        outerScale = baseRadius * 1.3 * (1 + progress * 0.8)
                    else
                        -- 后30%：缩小
                        local shrink = (progress - 0.7) / 0.3  -- 0→1
                        outerScale = baseRadius * 1.82 * (1 - shrink * 0.95)
                    end
                    outerScale = math.max(0.001, outerScale)
                    proj.outerNode:SetScale(Vector3(outerScale, flatHeight, outerScale))
                end
                
                -- 光源淡出
                local light = proj.node:GetComponent("Light")
                if light then
                    light.brightness = 3.0 * alpha * alpha
                end
            else
                -- 旧版单层爆炸（兼容）
                local expandScale = proj.startScale * (1.0 + progress * 0.5)
                proj.node:SetScale(Vector3(expandScale, expandScale, expandScale))
                local light = proj.node:GetComponent("Light")
                if light then
                    light.brightness = 2.0 * alpha
                end
            end
            goto continue
        end
        
        -- 旧版能量链兼容
        if proj.isEnergyChain then
            goto continue
        end
        
        -- 更新飞行时间（用于曲线衰减）
        if proj.flightTime then
            proj.flightTime = proj.flightTime + dt
        end
        
        -- 锁定目标追踪（100%命中，instantHit武器）
        if proj.lockedTarget and proj.instantHit then
            local target = proj.lockedTarget
            -- 目标死亡或无效，子弹消失
            if not target or not target.node or not target.hp or target.hp <= 0 then
                ReleaseProjectile(proj)
                table.remove(projectiles, i)
                goto continue
            end
            
            local targetPos = target.node.position
            local targetAngle = Math.AngleTo(proj.x, proj.y, targetPos.x, targetPos.y)
            local distToTarget = Math.Distance(proj.x, proj.y, targetPos.x, targetPos.y)
            
            -- 计算曲线偏移（随时间衰减 + 距离衰减）
            local curveAmount = 0
            if proj.curveOffset and proj.curveDecayTime and proj.flightTime then
                -- 时间衰减
                local decayProgress = math.min(proj.flightTime / proj.curveDecayTime, 1.0)
                local smoothDecay = decayProgress * decayProgress * (3 - 2 * decayProgress)
                
                -- 距离衰减：靠近目标时快速取消曲线（5米内开始衰减，2米内完全取消）
                local distDecay = 1.0
                if distToTarget < 5 then
                    distDecay = math.max(0, (distToTarget - 2) / 3)
                end
                
                curveAmount = proj.curveOffset * (1 - smoothDecay) * distDecay
            end
            
            -- 应用曲线偏移后朝向目标
            local finalAngle = targetAngle + curveAmount
            proj.dirX = math.cos(finalAngle)
            proj.dirY = math.sin(finalAngle)
            
            -- 更新子弹朝向
            local angleDeg = Math.RadToDeg(finalAngle)
            proj.node.rotation = Quaternion(0, 0, angleDeg - 90)
        -- 普通追踪导弹
        elseif proj.homing and findNearestEnemy then
            local target, _ = findNearestEnemy(proj.x, proj.y, 30)
            if target then
                local pos = target.node.position
                local targetAngle = Math.AngleTo(proj.x, proj.y, pos.x, pos.y)
                local currentAngle = math.atan2(proj.dirY, proj.dirX)
                local distToTarget = Math.Distance(proj.x, proj.y, pos.x, pos.y)
                
                -- 计算曲线偏移（随时间衰减 + 距离衰减）
                local curveAmount = 0
                if proj.curveOffset and proj.curveDecayTime and proj.flightTime then
                    -- 时间衰减
                    local decayProgress = math.min(proj.flightTime / proj.curveDecayTime, 1.0)
                    local smoothDecay = decayProgress * decayProgress * (3 - 2 * decayProgress)
                    
                    -- 距离衰减：靠近目标时快速取消曲线（5米内开始衰减，2米内完全取消）
                    local distDecay = 1.0
                    if distToTarget < 5 then
                        distDecay = math.max(0, (distToTarget - 2) / 3)
                    end
                    
                    curveAmount = proj.curveOffset * (1 - smoothDecay) * distDecay
                end
                
                -- 目标角度加上曲线偏移
                local curvedTargetAngle = targetAngle + curveAmount
                
                -- 平滑转向（向曲线偏移后的目标角度转向）
                local angleDiff = Math.AngleDiff(currentAngle, curvedTargetAngle)
                local turnAmount = proj.homingStrength * dt
                
                if math.abs(angleDiff) < turnAmount then
                    currentAngle = curvedTargetAngle
                else
                    currentAngle = currentAngle + (angleDiff > 0 and turnAmount or -turnAmount)
                end
                
                proj.dirX = math.cos(currentAngle)
                proj.dirY = math.sin(currentAngle)
                
                -- 更新导弹朝向
                local angleDeg = Math.RadToDeg(currentAngle)
                proj.node.rotation = Quaternion(0, 0, angleDeg - 90)
            end
        end
        
        -- 非追踪弧线飞行：从偏移方向逐渐回归到原始目标方向
        if proj.isCurvedFlight and proj.curveOffset and proj.curveDecayTime and proj.flightTime then
            -- 计算回归进度：0（刚发射，最大偏移）→ 1（完全回归目标方向）
            local progress = math.min(proj.flightTime / proj.curveDecayTime, 1.0)
            -- 使用平滑的缓动函数
            local smoothProgress = progress * progress * (3 - 2 * progress)
            
            -- 当前偏移量：从 curveOffset 衰减到 0
            local curveAmount = proj.curveOffset * (1 - smoothProgress)
            
            local currentAngle = proj.originalAngle + curveAmount
            proj.dirX = math.cos(currentAngle)
            proj.dirY = math.sin(currentAngle)
            
            -- 更新导弹朝向
            local angleDeg = Math.RadToDeg(currentAngle)
            proj.node.rotation = Quaternion(0, 0, angleDeg - 90)
        end
        
        -- 移动
        proj.x = proj.x + proj.dirX * proj.speed * dt
        proj.y = proj.y + proj.dirY * proj.speed * dt
        proj.node.position = Vector3(proj.x, proj.y, 0)
        
        -- 更新尾焰位置（如果有）
        if proj.trailNode and proj.trailLength and proj.trailLength > 0 then
            local missileScale = proj.missileScale or 0.35
            local trailLen = proj.trailLength * missileScale * 1.5  -- 与创建时一致
            local offsetDist = missileScale * 0.5 + trailLen * 0.5
            proj.trailNode.position = Vector3(
                proj.x - proj.dirX * offsetDist,
                proj.y - proj.dirY * offsetDist,
                0.01
            )
            -- 更新尾焰朝向（锥形尖端朝后）
            local angle = Math.RadToDeg(math.atan2(proj.dirY, proj.dirX))
            proj.trailNode.rotation = Quaternion(0, 0, angle + 90)
        end
        
        -- 超出射程（飞行距离 >= maxDistance）
        -- 锁定追踪弹不受射程限制
        -- 注意：集束爆炸弹道的超距爆炸在 CheckCollisions 中处理（需要 enemies 参数）
        if proj.maxDistance and not proj.instantHit and not proj.clusterExplosion then
            local distTraveled = Math.Distance(proj.x, proj.y, proj.startX, proj.startY)
            if distTraveled >= proj.maxDistance then
                ReleaseProjectile(proj)
                table.remove(projectiles, i)
                goto continue
            end
        end
        
        -- 超出边界
        if proj.x < area.MinX - 5 or proj.x > area.MaxX + 5 or
           proj.y < area.MinY - 5 or proj.y > area.MaxY + 5 then
            ReleaseProjectile(proj)
            table.remove(projectiles, i)
        end
        
        ::continue::
    end
end

-- ============================================================================
-- 集束爆炸系统
-- ============================================================================

-- 调度集束爆炸（命中时调用）
function Projectile.ScheduleClusterExplosion(x, y, proj, enemies, onHit)
    local count = proj.clusterCount or 6
    local spread = proj.clusterSpread or 1.5
    local delay = proj.clusterDelay or 0.05
    local radius = proj.clusterRadius or 0.5
    
    for i = 1, count do
        -- 随机分布在 spread 范围内
        local angle = math.random() * math.pi * 2
        local dist = math.random() * spread
        local explosionX = x + math.cos(angle) * dist
        local explosionY = y + math.sin(angle) * dist
        
        table.insert(pendingClusterExplosions, {
            x = explosionX,
            y = explosionY,
            delay = (i - 1) * delay,  -- 依次爆炸
            radius = radius,
            damage = proj.damage,
            isCrit = proj.isCrit,
            color = proj.color,
            enemies = enemies,
            onHit = onHit,
            weaponId = proj.weaponId,
        })
    end
end

-- 更新集束爆炸（在主循环中调用）
function Projectile.UpdateClusterExplosions(dt, scene)
    for i = #pendingClusterExplosions, 1, -1 do
        local explosion = pendingClusterExplosions[i]
        explosion.delay = explosion.delay - dt
        
        if explosion.delay <= 0 then
            -- 触发爆炸
            Projectile.TriggerClusterExplosion(explosion, scene)
            table.remove(pendingClusterExplosions, i)
        end
    end
end

-- 触发单个集束爆炸
function Projectile.TriggerClusterExplosion(explosion, scene)
    local x, y = explosion.x, explosion.y
    local radius = explosion.radius
    local damage = explosion.damage
    local isCrit = explosion.isCrit
    local enemies = explosion.enemies
    local onHit = explosion.onHit
    
    -- 检测范围内的敌人并造成伤害
    if enemies then
        for _, enemy in ipairs(enemies) do
            if enemy and enemy.node and enemy.hp and enemy.hp > 0 then
                local pos = enemy.node.position
                local dist = Math.Distance(x, y, pos.x, pos.y)
                
                if dist <= radius + (enemy.hitRadius or enemy.scale or 0.5) then
                    -- 创建一个临时 proj 对象用于回调
                    local tempProj = {
                        x = x,
                        y = y,
                        damage = damage,
                        isCrit = isCrit,
                        weaponId = explosion.weaponId,
                        isClusterExplosion = true,
                    }
                    if onHit then
                        onHit(tempProj, enemy)
                    end
                end
            end
        end
    end
    
    -- 创建爆炸视觉效果
    if scene then
        Projectile.CreateExplosionEffect(scene, x, y, radius, explosion.color or {r=1, g=0.6, b=0.3})
    end
end

-- 创建爆炸视觉效果（多层次）
function Projectile.CreateExplosionEffect(scene, x, y, radius, color)
    -- 强制使用黄橙色系（不受导弹颜色影响）
    local explosionColor = {
        core = {r = 1.0, g = 0.95, b = 0.7},    -- 内核：亮黄白
        middle = {r = 1.0, g = 0.7, b = 0.3},   -- 中层：金橙色
        outer = {r = 1.0, g = 0.5, b = 0.15},   -- 外层：橙红光晕
    }
    
    local node = scene:CreateChild("Explosion")
    node.position = Vector3(x, y, 0.1)
    
    -- 2D风格圆形爆炸：使用圆柱体压扁成圆盘
    -- Cylinder 默认 Y 轴方向，绕 X 轴旋转 90 度让圆面朝向 Z 轴
    local discRotation = Quaternion(90, Vector3.RIGHT)
    local flatHeight = 0.02  -- 压扁高度
    
    -- 外层光晕（最大，增强发光效果）
    local outerNode = node:CreateChild("OuterGlow")
    outerNode.rotation = discRotation
    local outerModel = outerNode:CreateComponent("StaticModel")
    outerModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    outerModel:SetMaterial(Materials.ExplosionAlpha(
        explosionColor.outer.r, explosionColor.outer.g, explosionColor.outer.b, 0.7, 3.0
    ))
    -- Cylinder: X和Z控制半径，Y控制高度（压扁）- 外层稍大增强光晕
    outerNode:SetScale(Vector3(radius * 1.3, flatHeight, radius * 1.3))
    
    -- 中层爆炸（主体，明亮）
    local middleNode = node:CreateChild("MiddleExplosion")
    middleNode.position = Vector3(0, 0, 0.02)  -- 稍微靠前
    middleNode.rotation = discRotation
    local middleModel = middleNode:CreateComponent("StaticModel")
    middleModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    middleModel:SetMaterial(Materials.ExplosionAlpha(
        explosionColor.middle.r, explosionColor.middle.g, explosionColor.middle.b, 0.85, 4.0
    ))
    middleNode:SetScale(Vector3(radius * 0.8, flatHeight, radius * 0.8))
    
    -- 内核（最亮，白热）
    local coreNode = node:CreateChild("Core")
    coreNode.position = Vector3(0, 0, 0.04)  -- 最靠前
    coreNode.rotation = discRotation
    local coreModel = coreNode:CreateComponent("StaticModel")
    coreModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    coreModel:SetMaterial(Materials.ExplosionAlpha(
        explosionColor.core.r, explosionColor.core.g, explosionColor.core.b, 0.98, 5.0
    ))
    coreNode:SetScale(Vector3(radius * 0.45, flatHeight, radius * 0.45))
    
    -- 添加点光源（黄橙色，增强亮度和范围）
    local light = node:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    light.color = Color(1.0, 0.75, 0.35)
    light.range = radius * 4.0
    light.brightness = 3.0
    
    -- 存储用于淡出动画（包含多层信息和模型引用）
    table.insert(projectiles, {
        node = node,
        isExplosionEffect = true,
        isMultiLayerExplosion = true,
        outerNode = outerNode,
        middleNode = middleNode,
        coreNode = coreNode,
        lifetime = 0.35,
        maxLifetime = 0.35,
        startScale = radius,
    })
end

-- ============================================================================
-- 碰撞检测
-- ============================================================================

function Projectile.CheckCollisions(enemies, onHit)
    for i = #projectiles, 1, -1 do
        local proj = projectiles[i]
        
        -- 扇形力场/能量链/激光束/爆炸特效：已在创建时处理伤害，跳过碰撞检测
        if proj.isForceFieldArc or proj.isEnergyChain or proj.isLaserBeam or proj.isExplosionEffect then
            -- AOE伤害在创建时通过回调处理
            goto continue
        end
        
        -- 集束爆炸弹道超距检测：超过最大飞行距离时立即爆炸（如轰炸无人机的炸弹）
        if proj.clusterExplosion and proj.maxDistance then
            local distTraveled = Math.Distance(proj.x, proj.y, proj.startX, proj.startY)
            if distTraveled >= proj.maxDistance then
                -- 在当前位置触发集束爆炸
                Projectile.ScheduleClusterExplosion(proj.x, proj.y, proj, enemies, onHit)
                ReleaseProjectile(proj)
                table.remove(projectiles, i)
                goto continue
            end
        end
        
        local hitEnemy = nil
        
        -- instantHit子弹：只检测锁定目标，使用更大命中范围
        if proj.instantHit and proj.lockedTarget then
            local target = proj.lockedTarget
            if target and target.node and target.hp and target.hp > 0 then
                -- 检查是否已经命中过这个敌人
                if not proj.hitEnemies[target] then
                    local pos = target.node.position
                    -- 使用更大的命中距离（确保100%命中）
                    local hitDist = math.max((target.hitRadius or target.scale) * 1.25, 1.0)
                    local dist = Math.Distance(proj.x, proj.y, pos.x, pos.y)
                    
                    if dist < hitDist then
                        hitEnemy = target
                    end
                end
            end
        else
            -- 普通子弹：点碰撞，检测所有敌人（跳过已命中的）
            for _, enemy in ipairs(enemies) do
                -- 跳过已命中的敌人
                if proj.hitEnemies and proj.hitEnemies[enemy] then
                    goto nextEnemy
                end
                
                local pos = enemy.node.position
                -- 命中距离：使用配置的子弹命中补偿系数
                local hitDist = (enemy.hitRadius or enemy.scale) * Settings.Combat.BulletHitCompensation
                
                if Math.Distance(proj.x, proj.y, pos.x, pos.y) < hitDist then
                    hitEnemy = enemy
                    break
                end
                
                ::nextEnemy::
            end
        end
        
        if hitEnemy then
            -- 记录已命中的敌人
            if proj.hitEnemies then
                proj.hitEnemies[hitEnemy] = true
            end
            
            -- 集束爆炸处理：命中后产生连锁爆炸
            if proj.clusterExplosion then
                -- 调度集束爆炸（不直接造成伤害，由爆炸造成）
                Projectile.ScheduleClusterExplosion(proj.x, proj.y, proj, enemies, onHit)
                -- 集束导弹命中后立即销毁，不触发普通命中
                ReleaseProjectile(proj)
                table.remove(projectiles, i)
                goto continue
            end
            
            if onHit then
                onHit(proj, hitEnemy)
            end
            
            -- 穿透处理
            if proj.pierce > 0 and proj.pierceCount < proj.pierce then
                proj.pierceCount = proj.pierceCount + 1
                
                -- 穿透后应用伤害衰减
                -- piercingDamage 是穿透伤害系数（如0.8表示穿透后伤害为基础伤害的80%）
                if proj.piercingDamage and proj.piercingDamage < 1.0 then
                    proj.damage = math.floor(proj.baseDamage * proj.piercingDamage)
                end
            else
                ReleaseProjectile(proj)
                table.remove(projectiles, i)
            end
        end
        
        ::continue::
    end
end

-- ============================================================================
-- 敌人子弹更新
-- ============================================================================

function Projectile.UpdateEnemyProjectiles(dt)
    local area = Settings.BattleArea
    
    for i = #enemyProjectiles, 1, -1 do
        local proj = enemyProjectiles[i]
        proj.lifetime = proj.lifetime - dt
        
        if proj.lifetime <= 0 then
            ReleaseEnemyProjectile(proj)
            table.remove(enemyProjectiles, i)
            goto continue
        end
        
        -- 移动
        proj.x = proj.x + proj.dirX * proj.speed * dt
        proj.y = proj.y + proj.dirY * proj.speed * dt
        proj.node.position = Vector3(proj.x, proj.y, 0)
        
        -- 超出边界
        if proj.x < area.MinX - 5 or proj.x > area.MaxX + 5 or
           proj.y < area.MinY - 5 or proj.y > area.MaxY + 5 then
            ReleaseEnemyProjectile(proj)
            table.remove(enemyProjectiles, i)
        end
        
        ::continue::
    end
end

-- 检测敌人子弹与玩家碰撞
function Projectile.CheckEnemyCollisions(playerX, playerY, playerRadius, onHit)
    playerRadius = playerRadius or 1.0
    
    for i = #enemyProjectiles, 1, -1 do
        local proj = enemyProjectiles[i]
        
        local dist = Math.Distance(proj.x, proj.y, playerX, playerY)
        if dist < playerRadius + 0.3 then
            -- 命中玩家
            if onHit then
                onHit(proj, proj.damage)
            end
            
            ReleaseEnemyProjectile(proj)
            table.remove(enemyProjectiles, i)
        end
    end
end

-- ============================================================================
-- 获取
-- ============================================================================

function Projectile.GetList()
    return projectiles
end

function Projectile.GetCount()
    return #projectiles
end

function Projectile.GetEnemyProjectileCount()
    return #enemyProjectiles
end

function Projectile.GetEnemyProjectiles()
    return enemyProjectiles
end

-- ============================================================================
-- 清理
-- ============================================================================

function Projectile.ClearAll()
    for _, proj in ipairs(projectiles) do
        ReleaseProjectile(proj)
    end
    projectiles = {}
    
    for _, proj in ipairs(enemyProjectiles) do
        ReleaseEnemyProjectile(proj)
    end
    enemyProjectiles = {}
    
    -- 清空待处理的集束爆炸
    pendingClusterExplosions = {}
    
    -- 清空对象池
    ClearPools()
end

-- 只清空敌人子弹（波次结束时调用）
function Projectile.ClearEnemyProjectiles()
    for _, proj in ipairs(enemyProjectiles) do
        ReleaseEnemyProjectile(proj)
    end
    enemyProjectiles = {}
    
    -- 同时清空待处理的集束爆炸（避免带到下一波）
    pendingClusterExplosions = {}
end

-- ============================================================================
-- 跃迁飞离效果
-- ============================================================================

local hyperspaceExit = {
    active = false,
}

function Projectile.StartHyperspaceExit()
    hyperspaceExit.active = true
end

function Projectile.StopHyperspaceExit()
    hyperspaceExit.active = false
end

function Projectile.UpdateHyperspaceExit(speed, stretch)
    if not hyperspaceExit.active then return end
    
    -- 更新玩家子弹
    for _, proj in ipairs(projectiles) do
        if proj.node then
            -- 记录累计位移
            proj.hyperspaceDistance = (proj.hyperspaceDistance or 0) + speed * 0.016
            
            local pos = proj.node.position
            local newZ = pos.z - speed * 0.016
            proj.node.position = Vector3(pos.x, pos.y, newZ)
            
            -- 根据累计位移淡出（飞行超过8单位后开始淡出）
            local dist = proj.hyperspaceDistance
            if dist > 8 then
                local fadeFactor = math.max(0, 1 - (dist - 8) / 12)
                local scale = proj.node.scale
                proj.node:SetScale(scale * (0.9 + fadeFactor * 0.1))
            end
        end
    end
    
    -- 更新敌人子弹
    for _, proj in ipairs(enemyProjectiles) do
        if proj.node then
            proj.hyperspaceDistance = (proj.hyperspaceDistance or 0) + speed * 0.016
            
            local pos = proj.node.position
            local newZ = pos.z - speed * 0.016
            proj.node.position = Vector3(pos.x, pos.y, newZ)
            
            local dist = proj.hyperspaceDistance
            if dist > 8 then
                local fadeFactor = math.max(0, 1 - (dist - 8) / 12)
                local scale = proj.node.scale
                proj.node:SetScale(scale * (0.9 + fadeFactor * 0.1))
            end
        end
    end
end

return Projectile
