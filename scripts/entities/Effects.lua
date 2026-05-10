-- ============================================================================
-- 星河战姬 Starkyries - 特效系统
-- 爆炸、伤害数字、跃迁预警
-- ============================================================================

local Settings = require("config.settings")
local Materials = require("render.Materials")
local Math = require("utils.Math")
local EventBus = require("utils.EventBus")

local Effects = {}

-- 特效列表
local explosions = {}
local damageNumbers = {}
local warpWarnings = {}
local chainLightnings = {}
local plasmaParticles = {}

-- 特效数量上限（防止内存溢出）
local MAX_EXPLOSIONS = 30
local MAX_HIT_SPARKS = 50
local MAX_DEATH_PARTICLES = 150
local MAX_DAMAGE_NUMBERS = 40
local MAX_CHAIN_LIGHTNINGS = 20
local MAX_PLASMA_PARTICLES = 60

-- ============================================================================
-- 对象池系统
-- ============================================================================

local POOL_MAX_SIZE = Settings.Effects.PoolMaxSize

-- 通用球体节点池（用于 hitSpark、deathParticle、explosion 等）
local spherePool = { available = {}, count = 0 }
-- 方块节点池（用于 deathParticle）
local boxPool = { available = {}, count = 0 }

-- 获取球体节点
local function AcquireSphereNode(scene, name)
    if #spherePool.available > 0 then
        local cached = table.remove(spherePool.available)
        cached.node:SetEnabled(true)
        cached.node.name = name or "PooledSphere"
        return cached.node, cached.model
    end
    
    local node = scene:CreateChild(name or "PooledSphere")
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    spherePool.count = spherePool.count + 1
    return node, model
end

-- 归还球体节点
local function ReleaseSphereNode(node, model)
    if #spherePool.available >= POOL_MAX_SIZE then
        node:Remove()
        return
    end
    node:SetEnabled(false)
    table.insert(spherePool.available, { node = node, model = model })
end

-- 获取方块节点
local function AcquireBoxNode(scene, name)
    if #boxPool.available > 0 then
        local cached = table.remove(boxPool.available)
        cached.node:SetEnabled(true)
        cached.node.name = name or "PooledBox"
        return cached.node, cached.model
    end
    
    local node = scene:CreateChild(name or "PooledBox")
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    boxPool.count = boxPool.count + 1
    return node, model
end

-- 归还方块节点
local function ReleaseBoxNode(node, model)
    if #boxPool.available >= POOL_MAX_SIZE then
        node:Remove()
        return
    end
    node:SetEnabled(false)
    table.insert(boxPool.available, { node = node, model = model })
end

-- 清空池
local function ClearPools()
    for _, cached in ipairs(spherePool.available) do
        cached.node:Remove()
    end
    spherePool.available = {}
    spherePool.count = 0
    
    for _, cached in ipairs(boxPool.available) do
        cached.node:Remove()
    end
    boxPool.available = {}
    boxPool.count = 0
end

-- 回调
Effects.onWarpComplete = nil  -- function(x, y, enemyType)

-- ============================================================================
-- 命中火花（子弹击中敌人时的闪光）
-- ============================================================================
local hitSparks = {}

function Effects.CreateHitSpark(scene, x, y, color, isCrit)
    -- 检查数量上限
    if #hitSparks >= MAX_HIT_SPARKS then
        -- 移除最老的一个
        local oldest = hitSparks[1]
        if oldest and oldest.node then oldest.node:Remove() end
        table.remove(hitSparks, 1)
    end
    
    local node = scene:CreateChild("HitSpark")
    node.position = Vector3(x, y, 0)
    
    -- 主闪光
    local flash = node:CreateChild("Flash")
    local flashModel = flash:CreateComponent("StaticModel")
    flashModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    local size = isCrit and 0.6 or 0.35
    flash:SetScale(size)
    
    local intensity = isCrit and 5.0 or 3.0
    local c = color or {r = 1, g = 0.8, b = 0.3}
    flashModel:SetMaterial(Materials.CreateGlow(c.r, c.g, c.b, intensity))
    
    -- 外环（暴击时额外添加）
    local ring = nil
    if isCrit then
        ring = node:CreateChild("Ring")
        local ringModel = ring:CreateComponent("StaticModel")
        ringModel:SetModel(cache:GetResource("Model", "Models/Torus.mdl"))
        ring:SetScale(0.3)
        ring.rotation = Quaternion(math.random(360), math.random(360), math.random(360))
        ringModel:SetMaterial(Materials.CreateGlow(1, 1, 1, 4.0))
    end
    
    local spark = {
        node = node,
        flash = flash,
        ring = ring,
        timer = 0,
        duration = isCrit and 0.2 or 0.12,
        isCrit = isCrit,
    }
    
    table.insert(hitSparks, spark)
    return spark
end

function Effects.UpdateHitSparks(dt)
    for i = #hitSparks, 1, -1 do
        local spark = hitSparks[i]
        spark.timer = spark.timer + dt
        
        local progress = spark.timer / spark.duration
        if progress >= 1 then
            spark.node:Remove()
            table.remove(hitSparks, i)
        else
            -- 快速扩张然后消失
            local scale
            if progress < 0.3 then
                scale = Math.Lerp(0.2, 1.0, progress / 0.3)
            else
                scale = Math.Lerp(1.0, 0.1, (progress - 0.3) / 0.7)
            end
            
            local baseSize = spark.isCrit and 0.6 or 0.35
            spark.flash:SetScale(baseSize * scale)
            
            if spark.ring then
                spark.ring:SetScale(0.3 + progress * 0.8)
                spark.ring.rotation = spark.ring.rotation * Quaternion(0, dt * 720, 0)
            end
        end
    end
end

-- ============================================================================
-- 爆浆特效（自爆虫专属）
-- ============================================================================
local splatterParticles = {}
local MAX_SPLATTER_PARTICLES = 100

function Effects.CreateSplatterEffect(scene, x, y, radius, color)
    local c = color or {r = 0.2, g = 0.9, b = 0.1}  -- 默认绿色
    local count = 8  -- 爆浆液滴数量
    
    -- 检查数量上限
    local availableSlots = MAX_SPLATTER_PARTICLES - #splatterParticles
    if availableSlots <= 0 then
        local toRemove = math.min(count, #splatterParticles)
        for i = 1, toRemove do
            local oldest = splatterParticles[1]
            if oldest and oldest.node then
                ReleaseSphereNode(oldest.node, oldest.model)
            end
            table.remove(splatterParticles, 1)
        end
        availableSlots = count
    end
    count = math.min(count, availableSlots)
    
    -- 创建中心闪光（短暂）
    local flashNode, flashModel = AcquireSphereNode(scene, "SplatterFlash")
    flashNode.position = Vector3(x, y, 0)
    flashNode:SetScale(radius * 0.15)
    flashModel:SetMaterial(Materials.CreateGlow(c.r, c.g, c.b, 5.0))
    table.insert(splatterParticles, {
        node = flashNode,
        model = flashModel,
        x = x, y = y,
        vx = 0, vy = 0,
        timer = 0,
        lifetime = 0.12,
        initialSize = radius * 0.15,
        isFlash = true,
    })
    
    -- 创建爆浆液滴
    for i = 1, count do
        local node, model = AcquireSphereNode(scene, "SplatterDrop")
        node.position = Vector3(x, y, 0)
        
        -- 随机大小（椭圆形液滴）- 缩小尺寸
        local baseSize = radius * Math.RandomRange(0.08, 0.18)
        local scaleX = baseSize * Math.RandomRange(0.8, 1.2)
        local scaleY = baseSize * Math.RandomRange(1.2, 1.8)  -- 拉长的液滴
        local scaleZ = baseSize * Math.RandomRange(0.8, 1.2)
        node:SetScale(Vector3(scaleX, scaleY, scaleZ))
        
        -- 随机颜色变化（绿色系）
        local colorVar = Math.RandomRange(0.7, 1.3)
        local intensity = Math.RandomRange(2.0, 4.0)
        model:SetMaterial(Materials.CreateGlow(
            Math.Clamp(c.r * colorVar, 0, 1),
            Math.Clamp(c.g * colorVar, 0, 1),
            Math.Clamp(c.b * colorVar, 0, 1),
            intensity
        ))
        
        -- 随机速度（向外飞溅，有高度）- 缩小飞散范围
        local angle = math.random() * math.pi * 2
        local speed = Math.RandomRange(3, 7)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed * 0.5 + Math.RandomRange(2, 5)  -- 向上抛
        local vz = Math.RandomRange(-1, 1)  -- Z轴也有一点速度
        
        local particle = {
            node = node,
            model = model,
            x = x,
            y = y,
            z = 0,
            vx = vx,
            vy = vy,
            vz = vz,
            timer = 0,
            lifetime = Math.RandomRange(0.8, 1.2),  -- 增加生命周期
            initialSize = baseSize,
            rotation = math.random(360),
            rotSpeed = Math.RandomRange(200, 500) * (math.random() > 0.5 and 1 or -1),
        }
        
        table.insert(splatterParticles, particle)
    end
    
    -- 屏幕震动
    Effects.TriggerScreenShake(0.2, 0.2)
end

function Effects.UpdateSplatterParticles(dt)
    for i = #splatterParticles, 1, -1 do
        local p = splatterParticles[i]
        p.timer = p.timer + dt
        
        if p.timer >= p.lifetime then
            ReleaseSphereNode(p.node, p.model)
            table.remove(splatterParticles, i)
        else
            local progress = p.timer / p.lifetime
            
            if p.isFlash then
                -- 闪光快速扩张并消失
                local scale = p.initialSize * (1 + progress * 3) * (1 - progress)
                p.node:SetScale(math.max(0.01, scale))
            else
                -- 液滴物理运动（无重力，向四周飞散）
                local drag = 0.96
                p.vx = p.vx * drag
                p.vy = p.vy * drag
                p.vz = p.vz * drag
                
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                p.z = p.z + p.vz * dt
                p.node.position = Vector3(p.x, p.y, p.z)
                
                -- 旋转
                p.rotation = p.rotation + p.rotSpeed * dt
                p.node.rotation = Quaternion(p.rotation, p.rotation * 0.5, 0)
                
                -- 缩小消失（从75%进度开始）
                local shrinkStart = 0.75
                if progress > shrinkStart then
                    local shrinkProgress = (progress - shrinkStart) / (1 - shrinkStart)
                    local scale = p.initialSize * (1 - shrinkProgress * shrinkProgress)
                    p.node:SetScale(math.max(0.01, scale))
                end
            end
        end
    end
end

-- ============================================================================
-- 击毁粒子效果（敌人死亡时的碎片飞散）
-- ============================================================================
local deathParticles = {}

function Effects.CreateDeathParticles(scene, x, y, size, color, count, knockbackResist, hitDirX, hitDirY)
    count = count or 12
    local c = color or {r = 1, g = 0.5, b = 0.2}
    
    -- 检查数量上限，动态减少生成数量
    local availableSlots = MAX_DEATH_PARTICLES - #deathParticles
    if availableSlots <= 0 then
        -- 移除一些最老的粒子
        local toRemove = math.min(count, #deathParticles)
        for i = 1, toRemove do
            local oldest = deathParticles[1]
            if oldest and oldest.node then
                if oldest.isBox then
                    ReleaseBoxNode(oldest.node, oldest.model)
                else
                    ReleaseSphereNode(oldest.node, oldest.model)
                end
            end
            table.remove(deathParticles, 1)
        end
        availableSlots = count
    end
    count = math.min(count, availableSlots)
    
    for i = 1, count do
        -- 随机形状：球体或方块，从对象池获取
        local isBox = math.random() > 0.5
        local node, model
        if isBox then
            node, model = AcquireBoxNode(scene, "DeathParticle")
        else
            node, model = AcquireSphereNode(scene, "DeathParticle")
        end
        node.position = Vector3(x, y, 0)
        
        -- 随机大小
        local particleSize = size * Math.RandomRange(0.08, 0.2)
        node:SetScale(particleSize)
        
        -- 随机颜色变化
        local colorVar = Math.RandomRange(0.7, 1.3)
        local intensity = Math.RandomRange(2.0, 4.0)
        model:SetMaterial(Materials.CreateGlow(
            Math.Clamp(c.r * colorVar, 0, 1),
            Math.Clamp(c.g * colorVar, 0, 1),
            Math.Clamp(c.b * colorVar, 0, 1),
            intensity
        ))
        
        -- 速度计算：基于体积和击退抗性
        -- 扩散范围与体积相关，扩散方向与击退抗性相关
        local baseSpeed = Math.RandomRange(12, 25) * (0.6 + size * 0.6)  -- 体积越大扩散越大
        
        -- 随机方向
        local randomAngle = math.random() * math.pi * 2
        local randomDirX = math.cos(randomAngle)
        local randomDirY = math.sin(randomAngle)
        
        -- 混合击中方向和随机方向（抗性越低越偏向击中方向）
        local resist = knockbackResist or 0
        local hitX = hitDirX or 0
        local hitY = hitDirY or 0
        
        -- 给击中方向加一些随机偏移（±45度）让效果更自然
        local spreadAngle = Math.RandomRange(-0.8, 0.8)
        local cosA, sinA = math.cos(spreadAngle), math.sin(spreadAngle)
        local spreadHitX = hitX * cosA - hitY * sinA
        local spreadHitY = hitX * sinA + hitY * cosA
        
        -- 混合：resist=0 → 70%击中方向+30%随机，resist=1 → 100%随机
        local hitWeight = (1 - resist) * 0.7
        local vx = (spreadHitX * hitWeight + randomDirX * (1 - hitWeight)) * baseSpeed
        local vy = (spreadHitY * hitWeight + randomDirY * (1 - hitWeight)) * baseSpeed
        
        -- 随机旋转速度
        local rotSpeed = Math.RandomRange(200, 600) * (math.random() > 0.5 and 1 or -1)
        
        local particle = {
            node = node,
            model = model,
            isBox = isBox,  -- 记录类型用于归还池
            x = x,
            y = y,
            vx = vx,
            vy = vy,
            rotSpeed = rotSpeed,
            rotation = math.random(360),
            timer = 0,
            lifetime = Math.RandomRange(0.4, 0.8),
            initialSize = particleSize,
            knockbackResist = resist,
        }
        
        table.insert(deathParticles, particle)
    end
end

function Effects.UpdateDeathParticles(dt)
    for i = #deathParticles, 1, -1 do
        local p = deathParticles[i]
        p.timer = p.timer + dt
        
        if p.timer >= p.lifetime then
            if p.isBox then
                ReleaseBoxNode(p.node, p.model)
            else
                ReleaseSphereNode(p.node, p.model)
            end
            table.remove(deathParticles, i)
        else
            -- 移动（方向在创建时已确定，这里只做减速）
            local drag = 0.94
            p.vx = p.vx * drag
            p.vy = p.vy * drag
            
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.node.position = Vector3(p.x, p.y, 0)
            
            -- 旋转
            p.rotation = p.rotation + p.rotSpeed * dt
            p.node.rotation = Quaternion(p.rotation, p.rotation * 0.7, p.rotation * 0.3)
            
            -- 缩小消失
            local progress = p.timer / p.lifetime
            local scale = p.initialSize * (1 - progress * progress)
            p.node:SetScale(math.max(0.01, scale))
        end
    end
end

-- ============================================================================
-- 爆炸效果（闪光球）
-- ============================================================================

function Effects.CreateExplosion(scene, x, y, size, duration, color)
    -- 检查数量上限
    if #explosions >= MAX_EXPLOSIONS then
        local oldest = explosions[1]
        if oldest and oldest.node then oldest.node:Remove() end
        table.remove(explosions, 1)
    end
    
    local node = scene:CreateChild("Explosion")
    node.position = Vector3(x, y, 0)
    
    local col = color or {r = 1, g = 0.6, b = 0.2}
    local r = col.r or col[1] or 1
    local g = col.g or col[2] or 0.6
    local b = col.b or col[3] or 0.2
    
    -- 点光源闪光效果
    local light = node:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    light.color = Color(r, g, b)
    light.brightness = 5.0
    light.range = size * 6
    
    -- 可见的爆炸球体（发光材质）
    -- 注意：爆炸材质需要动态修改颜色，不能使用缓存
    local sphereNode = node:CreateChild("ExplosionSphere")
    local model = sphereNode:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(r * 2, g * 2, b * 2, 1.0)))
    model:SetMaterial(mat)
    
    sphereNode:SetScale(size * 0.5)  -- 初始大小
    
    local explosion = {
        node = node,
        light = light,
        sphereNode = sphereNode,
        sphereMat = mat,
        timer = 0,
        duration = duration,
        maxSize = size,
        color = {r = r, g = g, b = b},
        maxBrightness = 5.0,
    }
    
    table.insert(explosions, explosion)
    return explosion
end

function Effects.UpdateExplosions(dt)
    for i = #explosions, 1, -1 do
        local exp = explosions[i]
        exp.timer = exp.timer + dt
        
        local progress = exp.timer / exp.duration
        if progress >= 1 then
            exp.node:Remove()
            table.remove(explosions, i)
        else
            local easeProgress = 1 - (1 - progress) * (1 - progress)
            
            -- 光源淡出
            if exp.light and exp.maxBrightness then
                exp.light.brightness = exp.maxBrightness * (1 - progress)
                exp.light.range = exp.maxSize * 6 * (1 + easeProgress * 0.5)
            end
            
            -- 球体扩展并淡出
            if exp.sphereNode and exp.sphereMat then
                -- 快速扩展
                local scaleProgress = math.min(1, progress * 2)  -- 前半段快速扩展
                local scale = exp.maxSize * (0.5 + scaleProgress * 1.5)
                exp.sphereNode:SetScale(scale)
                
                -- 颜色淡出
                local alpha = 1 - easeProgress
                local col = exp.color
                exp.sphereMat:SetShaderParameter("MatDiffColor", 
                    Variant(Color(col.r * 2 * alpha, col.g * 2 * alpha, col.b * 2 * alpha, alpha)))
            end
            
            -- 传送特效动画
            if exp.isTeleport then
                -- 光环向外扩展
                if exp.ringNode then
                    local ringScale = 0.5 + easeProgress * 3.0  -- 0.5 → 3.5
                    exp.ringNode:SetScale(Vector3(ringScale, ringScale, 0.1))
                end
                -- 内核收缩消失
                if exp.coreNode then
                    local coreScale = 0.8 * (1 - easeProgress)  -- 0.8 → 0
                    exp.coreNode:SetScale(Vector3(coreScale, coreScale, coreScale))
                end
            end
        end
    end
end

-- ============================================================================
-- 链式闪电特效
-- ============================================================================

function Effects.CreateChainLightning(scene, x1, y1, x2, y2, color)
    -- 检查数量上限
    if #chainLightnings >= MAX_CHAIN_LIGHTNINGS then
        local oldest = chainLightnings[1]
        if oldest and oldest.node then oldest.node:Remove() end
        table.remove(chainLightnings, 1)
    end
    
    color = color or {r = 0.5, g = 0.8, b = 1.0}
    
    local node = scene:CreateChild("ChainLightning")
    
    -- 计算中点和长度
    local midX = (x1 + x2) / 2
    local midY = (y1 + y2) / 2
    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    local angle = math.atan2(dy, dx)
    
    node.position = Vector3(midX, midY, 0)
    node.rotation = Quaternion(0, 0, math.deg(angle))
    
    -- 主线（拉伸的球体模拟闪电）
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    node:SetScale(Vector3(length, 0.08, 0.08))
    model:SetMaterial(Materials.CreateGlow(color.r, color.g, color.b, 3.0))
    
    -- 添加一些分叉效果
    local numBranches = math.random(2, 4)
    for i = 1, numBranches do
        local branch = node:CreateChild("Branch")
        local t = math.random() * 0.6 + 0.2  -- 0.2 to 0.8 along main line
        local branchLen = length * 0.3 * math.random()
        local branchAngle = (math.random() - 0.5) * math.pi * 0.5
        
        branch.position = Vector3((t - 0.5) * length, 0, 0)
        branch.rotation = Quaternion(0, 0, math.deg(branchAngle))
        
        local branchModel = branch:CreateComponent("StaticModel")
        branchModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        branch:SetScale(Vector3(branchLen, 0.04, 0.04))
        branchModel:SetMaterial(Materials.CreateGlow(color.r, color.g, color.b, 2.0))
    end
    
    local chain = {
        node = node,
        timer = 0,
        duration = 0.15,  -- 闪电持续时间很短
    }
    
    table.insert(chainLightnings, chain)
    return chain
end

function Effects.UpdateChainLightnings(dt)
    for i = #chainLightnings, 1, -1 do
        local chain = chainLightnings[i]
        chain.timer = chain.timer + dt
        
        if chain.timer >= chain.duration then
            chain.node:Remove()
            table.remove(chainLightnings, i)
        else
            -- 闪烁效果
            local alpha = 1 - (chain.timer / chain.duration)
            local flicker = 0.7 + math.random() * 0.3
            local scale = chain.node.scale
            chain.node:SetScale(Vector3(scale.x, 0.08 * alpha * flicker, 0.08 * alpha * flicker))
        end
    end
end

-- ============================================================================
-- 等离子喷射特效
-- ============================================================================

-- ============================================================================
-- 等离子喷射（穿透全体武器视觉效果）
-- 对标 Brotato Flamethrower：喷射器风格粒子散射
-- ============================================================================

function Effects.CreatePlasmaBeam(scene, startX, startY, endX, endY, color)
    color = color or {r = 0.4, g = 0.9, b = 1.0}
    
    -- 计算喷射方向
    local dx = endX - startX
    local dy = endY - startY
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.1 then return end
    
    local dirX = dx / length
    local dirY = dy / length
    local baseAngle = math.atan2(dirY, dirX)
    local spreadAngle = math.rad(20)  -- 喷射扩散角度
    
    -- 创建多个粒子模拟喷射效果
    local particleCount = 6
    
    for i = 1, particleCount do
        -- 检查数量上限
        if #plasmaParticles >= MAX_PLASMA_PARTICLES then
            local oldest = plasmaParticles[1]
            if oldest and oldest.node then 
                ReleaseSphereNode(oldest.node, oldest.model)
            end
            table.remove(plasmaParticles, 1)
        end
        
        -- 随机偏移角度（喷射散射）
        local angleOffset = (math.random() - 0.5) * spreadAngle * 2
        local angle = baseAngle + angleOffset
        local pDirX = math.cos(angle)
        local pDirY = math.sin(angle)
        
        -- 随机射程（70%-100%）
        local pRange = length * (0.7 + math.random() * 0.3)
        
        -- 随机大小
        local size = 0.12 + math.random() * 0.1
        
        local node, model = AcquireSphereNode(scene, "PlasmaSpray")
        node.position = Vector3(startX, startY, 0)
        node:SetScale(size)
        
        -- 等离子颜色（青色带随机变化）
        local brightness = 0.8 + math.random() * 0.4
        model:SetMaterial(Materials.CreateGlow(
            color.r * brightness, 
            color.g * brightness, 
            color.b * brightness, 
            3.5
        ))
        
        local particle = {
            node = node,
            model = model,
            x = startX,
            y = startY,
            dirX = pDirX,
            dirY = pDirY,
            speed = 35 + math.random() * 15,  -- 35-50 m/s
            maxDist = pRange,
            traveled = 0,
            size = size,
            timer = 0,
            duration = pRange / 40,
        }
        
        table.insert(plasmaParticles, particle)
    end
end

function Effects.UpdatePlasmaParticles(dt)
    for i = #plasmaParticles, 1, -1 do
        local p = plasmaParticles[i]
        p.timer = p.timer + dt
        
        -- 移动粒子
        local move = p.speed * dt
        p.traveled = p.traveled + move
        p.x = p.x + p.dirX * move
        p.y = p.y + p.dirY * move
        p.node.position = Vector3(p.x, p.y, 0)
        
        -- 逐渐缩小消失
        local progress = p.traveled / p.maxDist
        local scale = p.size * (1 - progress * 0.6)
        p.node:SetScale(math.max(0.03, scale))
        
        -- 到达距离或时间结束
        if p.traveled >= p.maxDist or p.timer >= p.duration then
            ReleaseSphereNode(p.node, p.model)
            table.remove(plasmaParticles, i)
        end
    end
end

-- ============================================================================
-- 伤害数字
-- ============================================================================

function Effects.CreateDamageNumber(x, y, damage, isCrit, text, isPlayerDamage)
    -- 检查数量上限
    if #damageNumbers >= MAX_DAMAGE_NUMBERS then
        table.remove(damageNumbers, 1)
    end
    
    local num = {
        x = x + Math.RandomRange(-0.3, 0.3),
        y = y,
        damage = damage,
        text = text,
        isCrit = isCrit,
        isPlayerDamage = isPlayerDamage,
        timer = 0,
        duration = 1.0,
        velY = 3,
    }
    table.insert(damageNumbers, num)
    return num
end

function Effects.UpdateDamageNumbers(dt)
    for i = #damageNumbers, 1, -1 do
        local num = damageNumbers[i]
        num.timer = num.timer + dt
        num.y = num.y + num.velY * dt
        num.velY = num.velY - dt * 5
        
        if num.timer >= num.duration then
            table.remove(damageNumbers, i)
        end
    end
end

function Effects.GetDamageNumbers()
    return damageNumbers
end

-- ============================================================================
-- 跃迁预警
-- ============================================================================

function Effects.CreateWarpWarning(scene, x, y, enemyType, delay)
    local node = scene:CreateChild("WarpWarning")
    node.position = Vector3(x, y, 0)
    
    -- 漩涡效果
    local vortex = node:CreateChild("Vortex")
    local vortexModel = vortex:CreateComponent("StaticModel")
    vortexModel:SetModel(cache:GetResource("Model", "Models/Torus.mdl"))
    vortex:SetScale(0.1)
    vortexModel:SetMaterial(Materials.WarpVortex())
    
    -- 中心光点
    local center = node:CreateChild("Center")
    local centerModel = center:CreateComponent("StaticModel")
    centerModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    center:SetScale(0.05)
    centerModel:SetMaterial(Materials.CreateGlow(1.0, 1.0, 1.0, 3.0))
    
    local warning = {
        node = node,
        vortex = vortex,
        center = center,
        enemyType = enemyType,
        x = x,
        y = y,
        timer = 0,
        duration = delay or Settings.Spawn.WarpWarningTime,
    }
    
    table.insert(warpWarnings, warning)
    return warning
end

function Effects.UpdateWarpWarnings(dt)
    for i = #warpWarnings, 1, -1 do
        local w = warpWarnings[i]
        w.timer = w.timer + dt
        
        local progress = w.timer / w.duration
        
        -- 漩涡旋转
        w.vortex.rotation = Quaternion(0, w.timer * 360, 0) * Quaternion(90, 0, 0)
        
        if progress < 0.7 then
            -- 阶段1：漩涡扩张
            local scale = Math.Lerp(0.1, 1.5, progress / 0.7)
            w.vortex:SetScale(scale)
            w.center:SetScale(Math.Lerp(0.05, 0.3, progress / 0.7))
        elseif progress < 1.0 then
            -- 阶段2：闪烁
            local flash = math.sin((progress - 0.7) / 0.3 * math.pi * 8)
            local scale = 1.5 + flash * 0.3
            w.vortex:SetScale(scale)
        else
            -- 阶段3：生成敌人
            if Effects.onWarpComplete then
                Effects.onWarpComplete(w.x, w.y, w.enemyType)
            end
            
            -- 发布事件
            EventBus.Emit(EventBus.Events.WARP_COMPLETE, w.x, w.y, w.enemyType)
            
            w.node:Remove()
            table.remove(warpWarnings, i)
        end
    end
end

function Effects.GetWarpWarningCount()
    return #warpWarnings
end

function Effects.ClearAllWarpWarnings()
    for _, w in ipairs(warpWarnings) do
        if w.node then
            w.node:Remove()
        end
    end
    warpWarnings = {}
end

-- ============================================================================
-- 屏幕震动
-- ============================================================================
local screenShake = {intensity = 0, duration = 0}

function Effects.TriggerScreenShake(intensity, duration)
    screenShake.intensity = intensity
    screenShake.duration = duration
end

function Effects.UpdateScreenShake(dt, cameraNode)
    if screenShake.duration > 0 then
        screenShake.duration = screenShake.duration - dt
        local shake = screenShake.intensity * (screenShake.duration / Settings.Visual.ScreenShakeDuration)
        
        local offsetX = Math.RandomRange(-shake, shake)
        local offsetY = Math.RandomRange(-shake, shake)
        
        -- 在当前相机位置基础上添加震动偏移（保持相机跟随位置）
        local currentPos = cameraNode.position
        cameraNode.position = Vector3(currentPos.x + offsetX, currentPos.y + offsetY, currentPos.z)
        return true
    end
    -- 没有震动时不修改相机位置，让相机跟随系统控制
    return false
end

-- ============================================================================
-- 清理
-- ============================================================================

function Effects.ClearAll()
    for _, spark in ipairs(hitSparks) do
        spark.node:Remove()  -- HitSpark 有子节点，不池化
    end
    hitSparks = {}
    
    for _, p in ipairs(deathParticles) do
        if p.isBox then
            ReleaseBoxNode(p.node, p.model)
        else
            ReleaseSphereNode(p.node, p.model)
        end
    end
    deathParticles = {}
    
    for _, p in ipairs(splatterParticles) do
        ReleaseSphereNode(p.node, p.model)
    end
    splatterParticles = {}
    
    for _, exp in ipairs(explosions) do
        exp.node:Remove()  -- Explosion 有 Light 组件，不池化
    end
    explosions = {}
    
    damageNumbers = {}
    
    for _, w in ipairs(warpWarnings) do
        w.node:Remove()  -- WarpWarning 结构复杂，不池化
    end
    warpWarnings = {}
    
    for _, c in ipairs(chainLightnings) do
        c.node:Remove()  -- ChainLightning 有分叉，不池化
    end
    chainLightnings = {}
    
    for _, p in ipairs(plasmaParticles) do
        ReleaseSphereNode(p.node, p.model)
    end
    plasmaParticles = {}
    
    screenShake = {intensity = 0, duration = 0}
    
    -- 清空对象池
    ClearPools()
end

-- ============================================================================
-- 传送特效（传送装置模块触发时）
-- ============================================================================

function Effects.CreateTeleportEffect(scene, x, y)
    if not scene then return end

    -- 创建传送光环
    local node = scene:CreateChild("TeleportEffect")
    node.position = Vector3(x, y, 0.1)
    
    -- 外圈光环
    local ringNode = node:CreateChild("Ring")
    local ringModel = ringNode:CreateComponent("StaticModel")
    ringModel:SetModel(cache:GetResource("Model", "Models/Torus.mdl"))
    local ringMat = Materials.CreateGlow(0.3, 0.8, 1.0, 2.0)  -- 青色
    ringModel:SetMaterial(ringMat)
    ringNode:SetScale(Vector3(0.5, 0.5, 0.1))
    
    -- 内核光球
    local coreNode = node:CreateChild("Core")
    local coreModel = coreNode:CreateComponent("StaticModel")
    coreModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    local coreMat = Materials.CreateGlow(0.5, 0.9, 1.0, 3.0)  -- 亮青色
    coreModel:SetMaterial(coreMat)
    coreNode:SetScale(Vector3(0.8, 0.8, 0.8))
    
    -- 点光源
    local light = node:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    light.color = Color(0.3, 0.8, 1.0)
    light.range = 8
    light.brightness = 3.0
    
    -- 添加到爆炸列表复用淡出逻辑
    table.insert(explosions, {
        node = node,
        light = light,
        ringNode = ringNode,
        coreNode = coreNode,
        timer = 0,
        duration = 0.5,
        maxSize = 3.0,
        isTeleport = true,
        color = {r = 0.3, g = 0.8, b = 1.0},
        maxBrightness = 3.0,
    })
end

return Effects
