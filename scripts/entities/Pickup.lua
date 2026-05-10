-- ============================================================================
-- 星河战姬 Starkyries - 拾取物系统
-- ============================================================================

local Settings = require("config.settings")
local Materials = require("render.Materials")
local Math = require("utils.Math")
local EventBus = require("utils.EventBus")

local Pickup = {}

-- 拾取物列表
local pickups = {}

-- 回调（保持向后兼容）
Pickup.onCollect = nil  -- function(pickup)

-- ============================================================================
-- 创建拾取物
-- ============================================================================

function Pickup.Create(scene, x, y, pickupType, amount)
    local node = scene:CreateChild("Pickup")
    node.position = Vector3(x, y, 0)
    
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    
    -- 根据数量调整尺寸和材质（对标Brotato视觉反馈）
    local baseScale = 0.3
    local material
    
    if pickupType == "crystal" then
        node.rotation = Quaternion(45, 45, 0)
        
        -- 根据晶体数量调整尺寸
        local scaleMultiplier = 1.0
        if amount >= 10 then
            scaleMultiplier = 1.8  -- 精英掉落：最大
        elseif amount >= 5 then
            scaleMultiplier = 1.5  -- 特殊高价值
        elseif amount >= 2 then
            scaleMultiplier = 1.2  -- 威胁/支援级
        end
        
        baseScale = baseScale * scaleMultiplier
        material = Materials.CrystalByAmount(amount)
    else
        material = Materials.Pickup(pickupType)
    end
    
    node:SetScale(baseScale)
    model:SetMaterial(material)
    
    local pickup = {
        node = node,
        type = pickupType,
        amount = amount,
        x = x,
        y = y,
        bobPhase = math.random() * math.pi * 2,
        lifetime = Settings.Pickup.Lifetime,
        originalScale = baseScale,  -- 保存原始尺寸，用于跨波次重置
    }
    
    table.insert(pickups, pickup)
    return pickup
end

-- 创建晶体
function Pickup.CreateCrystal(scene, x, y, amount)
    return Pickup.Create(scene, x, y, "crystal", amount)
end

-- 创建治疗包
function Pickup.CreateHealth(scene, x, y, amount)
    return Pickup.Create(scene, x, y, "health", amount)
end

-- ============================================================================
-- 更新
-- ============================================================================

function Pickup.UpdateAll(dt, playerX, playerY, pickupRangeMultiplier, moduleEffects)
    pickupRangeMultiplier = pickupRangeMultiplier or 1.0
    moduleEffects = moduleEffects or {}
    
    -- 超级磁铁：全屏拾取
    local collectRadius = Settings.Pickup.CollectRadius * pickupRangeMultiplier
    local magnetRadius = Settings.Pickup.MagnetRadius * pickupRangeMultiplier
    
    if moduleEffects.hasSuperMagnet then
        -- 全屏磁吸和拾取
        magnetRadius = Settings.Pickup.SuperMagnetRadius  -- 覆盖全战场
        collectRadius = collectRadius * 2  -- 拾取范围也增大
    end
    
    -- 吸引器：掉落物自动飞向战舰
    local hasAttractor = moduleEffects.hasAttractor
    local attractorSpeed = Settings.Pickup.AttractorSpeed  -- 吸引速度
    
    for i = #pickups, 1, -1 do
        local p = pickups[i]
        p.lifetime = p.lifetime - dt
        
        if p.lifetime <= 0 then
            p.node:Remove()
            table.remove(pickups, i)
            goto continue
        end
        
        -- 弹出动画（新波次晶体出现时）
        if p.spawnAnim then
            local anim = p.spawnAnim
            anim.time = anim.time + dt
            
            -- 等待延迟
            if anim.time < anim.delay then
                goto continue
            end
            
            local t = (anim.time - anim.delay) / anim.duration
            if t >= 1 then
                -- 动画结束
                t = 1
                p.node:SetScale(p.originalScale)
                p.node.position = Vector3(p.x, p.y, 0)
                p.spawnAnim = nil
            else
                -- 缓动函数：弹性效果 (easeOutBack)
                local c1 = 1.70158
                local c3 = c1 + 1
                local easeT = 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
                
                -- 缩放动画
                local scale = p.originalScale * easeT
                p.node:SetScale(scale)
                
                -- Y 位置动画（从下方弹出）
                local animY = anim.startY + (p.y - anim.startY) * easeT
                p.node.position = Vector3(p.x, animY, 0)
            end
            
            p.node.rotation = p.node.rotation * Quaternion(0, dt * 180, 0)  -- 快速旋转
            goto continue
        end
        
        -- 浮动动画
        p.bobPhase = p.bobPhase + dt * 3
        local bobY = math.sin(p.bobPhase) * 0.15
        
        -- 计算距离
        local dist = Math.Distance(p.x, p.y, playerX, playerY)
        
        -- 吸引器效果：无视距离，始终飞向玩家
        if hasAttractor then
            local dx, dy = Math.Normalize(playerX - p.x, playerY - p.y)
            p.x = p.x + dx * attractorSpeed * dt
            p.y = p.y + dy * attractorSpeed * dt
        -- 标准磁吸效果
        elseif dist < magnetRadius then
            local pullStrength = (magnetRadius - dist) / magnetRadius * 8
            local dx, dy = Math.Normalize(playerX - p.x, playerY - p.y)
            p.x = p.x + dx * pullStrength * dt
            p.y = p.y + dy * pullStrength * dt
        end
        
        p.node.position = Vector3(p.x, p.y + bobY, 0)
        p.node.rotation = p.node.rotation * Quaternion(0, dt * 90, 0)
        
        -- 收集
        if dist < collectRadius then
            if Pickup.onCollect then
                Pickup.onCollect(p)
            end
            
            -- 发布事件
            EventBus.Emit(EventBus.Events.PICKUP_COLLECT, p)
            if p.type == "crystal" then
                EventBus.Emit(EventBus.Events.CRYSTAL_COLLECT, p.amount)
            end
            
            p.node:Remove()
            table.remove(pickups, i)
        end
        
        ::continue::
    end
end

-- ============================================================================
-- 获取
-- ============================================================================

function Pickup.GetList()
    return pickups
end

function Pickup.GetCount()
    return #pickups
end

-- ============================================================================
-- 清理
-- ============================================================================

function Pickup.ClearAll()
    for _, p in ipairs(pickups) do
        p.node:Remove()
    end
    pickups = {}
end

-- 重置位置（新波次开始时调用，将上一波遗留晶体重置到原位置附近）
function Pickup.ResetPositions()
    local count = #pickups
    if count == 0 then return end
    
    for i, p in ipairs(pickups) do
        if p.node then
            -- 重新启用节点（之前被 HideAll 隐藏）
            p.node:SetEnabled(true)
            
            -- 在原位置附近添加少量随机偏移（避免完全重叠）
            local offsetX = (math.random() - 0.5) * 1.0
            local offsetY = (math.random() - 0.5) * 1.0
            local newX = p.x + offsetX
            local newY = p.y + offsetY
            
            -- 重置位置（z 归零，超空间飞离时 z 会变化）
            p.node.position = Vector3(newX, newY, 0)
            p.x = newX
            p.y = newY
            
            -- 清除超空间相关状态
            p.hyperspaceDistance = nil
            
            -- 重置生命周期（给玩家足够时间收集）
            p.lifetime = Settings.Pickup.Lifetime
            
            -- 设置弹出动画状态（从小变大 + 向上弹起）
            p.spawnAnim = {
                time = 0,
                duration = 0.4,
                delay = i * 0.05,  -- 错开出现时间，形成波浪效果
                startY = newY - 0.5,  -- 从下方弹出
            }
            
            -- 初始状态：缩放为0（动画开始时才显示）
            p.node:SetScale(0)
        end
    end
    
    print(string.format("[Pickup] 重置 %d 个遗留拾取物位置（原位置附近）", count))
end

-- 获取当前拾取物数量
function Pickup.GetCount()
    return #pickups
end

-- 隐藏所有拾取物（超空间跳跃时调用）
function Pickup.HideAll()
    for _, p in ipairs(pickups) do
        if p.node then
            p.node:SetEnabled(false)
        end
    end
end

-- 显示所有拾取物
function Pickup.ShowAll()
    for _, p in ipairs(pickups) do
        if p.node then
            p.node:SetEnabled(true)
        end
    end
end

-- ============================================================================
-- 晶体合并（波次结束时调用）
-- 规则：同等级 + 附近的晶体才合并，最多提升2级，合并后留在原位置附近
-- ============================================================================

-- 获取晶体等级（根据数量）
local function GetCrystalTier(amount)
    if amount >= 10 then
        return 4  -- 金色（最高）
    elseif amount >= 5 then
        return 3  -- 青蓝色
    elseif amount >= 2 then
        return 2  -- 亮蓝色
    else
        return 1  -- 标准蓝色
    end
end

-- 获取等级对应的最小数量
local function GetTierMinAmount(tier)
    if tier >= 4 then return 10
    elseif tier == 3 then return 5
    elseif tier == 2 then return 2
    else return 1
    end
end

-- 合并场上的晶体
-- mergeRadius: 合并范围（默认5米）
-- maxTierIncrease: 最大提升等级数（默认2）
function Pickup.MergeCrystals(scene, maxTierIncrease, mergeRadius)
    maxTierIncrease = maxTierIncrease or 2
    mergeRadius = mergeRadius or 5  -- 5米内的晶体才合并
    
    -- 收集所有晶体
    local crystals = {}
    for i, p in ipairs(pickups) do
        if p.type == "crystal" then
            table.insert(crystals, {
                index = i,
                pickup = p,
                tier = GetCrystalTier(p.amount),
                merged = false  -- 标记是否已被合并
            })
        end
    end
    
    local toRemove = {}  -- 需要移除的晶体索引
    local toCreate = {}  -- 需要创建的新晶体 {x, y, amount}
    
    -- 遍历每个晶体，找附近同等级的进行合并
    for i, crystal in ipairs(crystals) do
        if not crystal.merged and crystal.tier <= 3 then  -- 等级4不合并
            -- 找附近同等级的晶体
            local cluster = {crystal}
            crystal.merged = true
            
            for j, other in ipairs(crystals) do
                if i ~= j and not other.merged and other.tier == crystal.tier then
                    -- 检查是否在合并范围内
                    local dx = other.pickup.x - crystal.pickup.x
                    local dy = other.pickup.y - crystal.pickup.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    
                    if dist <= mergeRadius then
                        table.insert(cluster, other)
                        other.merged = true
                    end
                end
            end
            
            -- 如果找到了附近的同等级晶体，进行合并
            if #cluster >= 2 then
                -- 计算总价值和中心位置
                local totalAmount = 0
                local sumX, sumY = 0, 0
                
                for _, c in ipairs(cluster) do
                    totalAmount = totalAmount + c.pickup.amount
                    sumX = sumX + c.pickup.x
                    sumY = sumY + c.pickup.y
                    table.insert(toRemove, c.index)
                end
                
                local centerX = sumX / #cluster
                local centerY = sumY / #cluster
                
                -- 计算目标等级（最多提升maxTierIncrease级，但不超过4）
                local targetTier = math.min(crystal.tier + maxTierIncrease, 4)
                local targetMinAmount = GetTierMinAmount(targetTier)
                
                -- 计算合并后的晶体数量
                local numNewCrystals = math.max(1, math.floor(totalAmount / targetMinAmount))
                local amountPerCrystal = math.floor(totalAmount / numNewCrystals)
                local extraAmount = totalAmount - amountPerCrystal * numNewCrystals
                
                -- 创建新晶体（围绕中心位置分布）
                for k = 1, numNewCrystals do
                    local amount = amountPerCrystal
                    if k == 1 then
                        amount = amount + extraAmount  -- 余数加到第一个
                    end
                    
                    -- 位置略微随机偏移（避免完全重叠，但保持在原区域附近）
                    local offsetX = (math.random() - 0.5) * 1.0
                    local offsetY = (math.random() - 0.5) * 1.0
                    
                    table.insert(toCreate, {
                        x = centerX + offsetX,
                        y = centerY + offsetY,
                        amount = amount
                    })
                end
            end
        end
    end
    
    -- 移除旧晶体（从后往前移除，避免索引错乱）
    table.sort(toRemove, function(a, b) return a > b end)
    for _, idx in ipairs(toRemove) do
        local p = pickups[idx]
        if p and p.node then
            p.node:Remove()
        end
        table.remove(pickups, idx)
    end
    
    -- 创建新晶体
    for _, data in ipairs(toCreate) do
        Pickup.CreateCrystal(scene, data.x, data.y, data.amount)
    end
    
    -- 返回合并统计
    return {
        merged = #toRemove,
        created = #toCreate
    }
end

-- ============================================================================
-- 跃迁飞离效果
-- ============================================================================

local hyperspaceExit = {
    active = false,
}

function Pickup.StartHyperspaceExit()
    hyperspaceExit.active = true
end

function Pickup.StopHyperspaceExit()
    hyperspaceExit.active = false
end

function Pickup.UpdateHyperspaceExit(speed, stretch)
    if not hyperspaceExit.active then return end
    
    for _, pickup in ipairs(pickups) do
        if pickup.node then
            -- 记录累计位移
            pickup.hyperspaceDistance = (pickup.hyperspaceDistance or 0) + speed * 0.016
            
            local pos = pickup.node.position
            local newZ = pos.z - speed * 0.016
            pickup.node.position = Vector3(pos.x, pos.y, newZ)
            
            -- 根据累计位移淡出（飞行超过8单位后开始淡出）
            local dist = pickup.hyperspaceDistance
            if dist > 8 then
                local fadeFactor = math.max(0, 1 - (dist - 8) / 12)
                local scale = pickup.node.scale
                pickup.node:SetScale(scale * (0.9 + fadeFactor * 0.1))
            end
        end
    end
end

return Pickup
