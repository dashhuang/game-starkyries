-- ============================================================================
-- 星河战姬 Starkyries - 玩家死亡动画模块
-- ============================================================================
-- 
-- 职责：管理玩家战舰被击毁后的爆炸和碎片动画
-- 
-- 动画流程：
--   1. 初始爆炸（中心）
--   2. 连锁爆炸（随机位置）
--   3. 碎片飞散（带物理）
--   4. 完成回调
-- 
-- 用法：
--   PlayerDeathAnimation.Start(scene, playerNode, onComplete)
--   PlayerDeathAnimation.Update(dt, playerNode)  -- 每帧调用
--   PlayerDeathAnimation.IsActive()  -- 检查是否播放中
--   PlayerDeathAnimation.Cleanup()  -- 清理资源
-- 
-- ============================================================================

local Materials = require("render.Materials")
local Math = require("utils.Math")

local PlayerDeathAnimation = {}

-- ============================================================================
-- 动画状态
-- ============================================================================
PlayerDeathAnimation.state = {
    active = false,
    timer = 0,
    duration = 1.5,        -- 总动画时长
    phase = 0,             -- 动画阶段
    onComplete = nil,      -- 完成回调
    scene = nil,           -- 场景引用
    explosions = {},       -- 爆炸效果节点
    debris = {},           -- 碎片节点
}

-- ============================================================================
-- 外部依赖（延迟注入）
-- ============================================================================
local playerRef = nil

function PlayerDeathAnimation.SetPlayerRef(player)
    playerRef = player
end

-- ============================================================================
-- 开始死亡动画
-- ============================================================================

function PlayerDeathAnimation.Start(scene, playerNode, onComplete)
    local state = PlayerDeathAnimation.state
    
    if state.active then return end
    
    state.active = true
    state.timer = 0
    state.phase = 0
    state.onComplete = onComplete
    state.scene = scene
    state.explosions = {}
    state.debris = {}
    
    -- 获取玩家位置
    local px, py = 0, 0
    if playerNode then
        px = playerNode.position.x
        py = playerNode.position.y
    end
    
    -- 第一波爆炸（中心）
    PlayerDeathAnimation.CreateExplosion(scene, px, py, 1.2, {r = 1, g = 0.6, b = 0.2})
    
    -- 创建碎片
    PlayerDeathAnimation.CreateDebris(scene, px, py, 15)
end

-- ============================================================================
-- 创建爆炸效果
-- ============================================================================

function PlayerDeathAnimation.CreateExplosion(scene, x, y, size, color)
    local node = scene:CreateChild("DeathExplosion")
    node.position = Vector3(x, y, 0.1)
    
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    node:SetScale(size * 0.3)
    
    -- 高亮发光材质
    local mat = Materials.CreateGlow(color.r, color.g, color.b, 5.0)
    model:SetMaterial(mat)
    
    -- 添加点光源
    local light = node:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    light.color = Color(color.r, color.g, color.b)
    light.brightness = 4.0
    light.range = size * 4
    
    local explosion = {
        node = node,
        model = model,
        light = light,
        timer = 0,
        duration = 0.5,
        maxSize = size,
        color = color,
    }
    
    table.insert(PlayerDeathAnimation.state.explosions, explosion)
end

-- ============================================================================
-- 创建碎片
-- ============================================================================

function PlayerDeathAnimation.CreateDebris(scene, x, y, count)
    local state = PlayerDeathAnimation.state
    
    for i = 1, count do
        local node = scene:CreateChild("DeathDebris")
        node.position = Vector3(x, y, 0)
        
        local model = node:CreateComponent("StaticModel")
        -- 随机形状
        if math.random() > 0.5 then
            model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        else
            model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        end
        
        -- 随机大小
        local size = Math.RandomRange(0.08, 0.25)
        node:SetScale(size)
        
        -- 随机颜色（战舰色调）
        local colorChoice = math.random(3)
        local color
        if colorChoice == 1 then
            color = {r = 0.4, g = 0.5, b = 0.7}  -- 蓝灰色（船体）
        elseif colorChoice == 2 then
            color = {r = 1, g = 0.5, b = 0.2}    -- 橙色（火焰）
        else
            color = {r = 0.8, g = 0.8, b = 0.9}  -- 亮灰色（金属）
        end
        
        local intensity = Math.RandomRange(2.0, 4.0)
        model:SetMaterial(Materials.CreateGlow(color.r, color.g, color.b, intensity))
        
        -- 随机速度（向外飞散）
        local angle = math.random() * math.pi * 2
        local speed = Math.RandomRange(6, 14)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        local vz = Math.RandomRange(-3, 3)  -- 也向前后飞
        
        -- 随机旋转速度
        local rotSpeed = Math.RandomRange(200, 500)
        
        local debris = {
            node = node,
            x = x,
            y = y,
            z = 0,
            vx = vx,
            vy = vy,
            vz = vz,
            rotSpeed = rotSpeed,
            rotation = math.random(360),
            timer = 0,
            lifetime = Math.RandomRange(0.8, 1.4),
            initialSize = size,
        }
        
        table.insert(state.debris, debris)
    end
end

-- ============================================================================
-- 更新动画（每帧调用）
-- ============================================================================

function PlayerDeathAnimation.Update(dt, playerNode)
    local state = PlayerDeathAnimation.state
    
    if not state.active then return end
    
    state.timer = state.timer + dt
    
    local px, py = 0, 0
    if playerNode then
        px = playerNode.position.x
        py = playerNode.position.y
    end
    
    -- 阶段触发
    if state.phase == 0 and state.timer >= 0.15 then
        -- 第二波爆炸（偏移位置）
        PlayerDeathAnimation.CreateExplosion(state.scene, px + 0.3, py + 0.2, 0.8, {r = 1, g = 0.4, b = 0.1})
        state.phase = 1
    end
    
    if state.phase == 1 and state.timer >= 0.3 then
        -- 第三波爆炸
        PlayerDeathAnimation.CreateExplosion(state.scene, px - 0.2, py - 0.1, 1.0, {r = 1, g = 0.7, b = 0.3})
        state.phase = 2
    end
    
    if state.phase == 2 and state.timer >= 0.5 then
        -- 隐藏玩家战舰
        if playerNode then
            playerNode:SetEnabled(false)
        end
        -- 最后大爆炸
        PlayerDeathAnimation.CreateExplosion(state.scene, px, py, 2.0, {r = 1, g = 0.8, b = 0.4})
        state.phase = 3
    end
    
    -- 更新爆炸效果
    PlayerDeathAnimation.UpdateExplosions(dt)
    
    -- 更新碎片
    PlayerDeathAnimation.UpdateDebris(dt)
    
    -- 动画完成检查
    if state.timer >= state.duration then
        PlayerDeathAnimation.Complete()
    end
end

-- ============================================================================
-- 更新爆炸效果
-- ============================================================================

function PlayerDeathAnimation.UpdateExplosions(dt)
    local state = PlayerDeathAnimation.state
    
    for i = #state.explosions, 1, -1 do
        local exp = state.explosions[i]
        exp.timer = exp.timer + dt
        
        local progress = exp.timer / exp.duration
        if progress >= 1 then
            exp.node:Remove()
            table.remove(state.explosions, i)
        else
            -- 扩张
            local scale = exp.maxSize * (0.3 + progress * 0.7)
            exp.node:SetScale(scale)
            
            -- 淡出
            local alpha = 1 - progress
            exp.model:SetMaterial(Materials.CreateGlow(
                exp.color.r, exp.color.g, exp.color.b, 5.0 * alpha
            ))
            
            -- 光源淡出
            if exp.light then
                exp.light.brightness = 4.0 * (1 - progress)
            end
        end
    end
end

-- ============================================================================
-- 更新碎片
-- ============================================================================

function PlayerDeathAnimation.UpdateDebris(dt)
    local state = PlayerDeathAnimation.state
    
    for i = #state.debris, 1, -1 do
        local d = state.debris[i]
        d.timer = d.timer + dt
        
        if d.timer >= d.lifetime then
            d.node:Remove()
            table.remove(state.debris, i)
        else
            -- 移动（带减速和重力）
            local drag = 0.97
            d.vx = d.vx * drag
            d.vy = d.vy * drag
            d.vz = d.vz * drag
            d.vy = d.vy - 8 * dt  -- 轻微重力
            
            d.x = d.x + d.vx * dt
            d.y = d.y + d.vy * dt
            d.z = d.z + d.vz * dt
            d.node.position = Vector3(d.x, d.y, d.z)
            
            -- 旋转
            d.rotation = d.rotation + d.rotSpeed * dt
            d.node.rotation = Quaternion(d.rotation, d.rotation * 0.7, d.rotation * 0.3)
            
            -- 缩小消失
            local progress = d.timer / d.lifetime
            local scale = d.initialSize * (1 - progress * progress)
            d.node:SetScale(math.max(0.01, scale))
        end
    end
end

-- ============================================================================
-- 完成动画
-- ============================================================================

function PlayerDeathAnimation.Complete()
    local state = PlayerDeathAnimation.state
    
    state.active = false
    
    -- 清理残留
    for _, exp in ipairs(state.explosions) do
        if exp.node then exp.node:Remove() end
    end
    for _, d in ipairs(state.debris) do
        if d.node then d.node:Remove() end
    end
    state.explosions = {}
    state.debris = {}
    
    -- 调用完成回调
    if state.onComplete then
        state.onComplete()
    end
end

-- ============================================================================
-- 状态查询
-- ============================================================================

function PlayerDeathAnimation.IsActive()
    return PlayerDeathAnimation.state.active
end

-- ============================================================================
-- 清理
-- ============================================================================

function PlayerDeathAnimation.Cleanup()
    local state = PlayerDeathAnimation.state
    
    if state.active then
        for _, exp in ipairs(state.explosions) do
            if exp.node then exp.node:Remove() end
        end
        for _, d in ipairs(state.debris) do
            if d.node then d.node:Remove() end
        end
        state.explosions = {}
        state.debris = {}
        state.active = false
        state.onComplete = nil
        state.scene = nil
    end
end

return PlayerDeathAnimation
