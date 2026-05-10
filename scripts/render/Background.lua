-- ============================================================================
-- 星河战姬 Starkyries - 背景星空
-- 支持超空间跳跃动画（星际大战风格）
-- ============================================================================

local Settings = require("config.settings")
local Materials = require("render.Materials")
local Math = require("utils.Math")

local Background = {}

-- 背景星星列表
local stars = {}

-- ============================================================================
-- 超空间跳跃状态
-- ============================================================================
local hyperspace = {
    active = false,
    phase = "idle",  -- "idle", "accelerate", "warp", "decelerate", "complete"
    mode = "enter",  -- "enter" = 进入战斗, "exit" = 离开战斗
    timer = 0,
    
    -- 进入动画参数
    warpDuration = 1.0,         -- 跃迁阶段（最高速，直接开始）
    decelerateDuration = 0.7,   -- 减速阶段
    
    -- 离开动画参数
    exitAccelerateDuration = 0.5,  -- 加速阶段
    exitWarpDuration = 0.6,        -- 跃迁阶段（然后直接结束）
    
    -- 当前速度和拉伸
    currentSpeed = 0,
    maxSpeed = 200,             -- 最高跃迁速度
    currentStretch = 1,
    maxStretch = 15,            -- 最大拉伸倍数
    
    -- 回调
    onComplete = nil,
}

-- ============================================================================
-- 创建背景
-- ============================================================================

function Background.Create(scene)
    stars = {}
    
    local starCount = Settings.Visual.StarCount
    
    for i = 1, starCount do
        local star = Background.CreateStar(scene, i)
        table.insert(stars, star)
    end
    
    -- 重置超空间状态
    hyperspace.active = false
    hyperspace.phase = "idle"
    hyperspace.timer = 0
    hyperspace.currentSpeed = 0
    hyperspace.currentStretch = 1
    
    return stars
end

-- 创建单个星星
function Background.CreateStar(scene, index)
    -- 分层：1-4层，越远越淡
    local layer = math.random(1, 4)
    local depth = 20 + layer * 10  -- 20-60 深度
    
    local node = scene:CreateChild("Star")
    node.position = Vector3(
        Math.RandomRange(-50, 50),
        Math.RandomRange(-30, 30),
        depth
    )
    
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    
    -- 大小基于层级
    local size = Math.RandomRange(0.02, 0.06) * (5 - layer)
    node:SetScale(size)
    
    -- 亮度基于层级
    local brightness = Math.RandomRange(0.4, 1.0) * (5 - layer) / 4
    
    -- 颜色变化
    local tint = math.random()
    local r, g, b
    if tint < 0.4 then
        -- 白色
        r, g, b = brightness, brightness, brightness
    elseif tint < 0.7 then
        -- 蓝白
        r, g, b = brightness * 0.8, brightness * 0.9, brightness
    else
        -- 暖白
        r, g, b = brightness, brightness * 0.95, brightness * 0.8
    end
    
    model:SetMaterial(Materials.Star(r, g, b, 1.0))
    
    return {
        node = node,
        model = model,
        layer = layer,
        twinkleSpeed = Math.RandomRange(2, 6),
        twinklePhase = Math.RandomRange(0, 6.28),
        baseScale = size,
        baseBrightness = brightness,
        r = r, g = g, b = b,
        -- 保存原始位置（用于跃迁重置）
        originalX = node.position.x,
        originalY = node.position.y,
        originalZ = depth,
    }
end

-- ============================================================================
-- 超空间跳跃动画
-- ============================================================================

-- 开始超空间跳跃（进入战斗）
-- @param onComplete 动画完成回调
-- @param onStartFadeOut 开始渐隐回调（减速阶段开始时触发）
function Background.StartHyperspace(onComplete, onStartFadeOut)
    if hyperspace.active then return end
    
    hyperspace.active = true
    hyperspace.mode = "enter"
    hyperspace.phase = "warp"  -- 直接进入跃迁阶段
    hyperspace.timer = 0
    hyperspace.currentSpeed = hyperspace.maxSpeed      -- 直接最高速
    hyperspace.currentStretch = hyperspace.maxStretch  -- 直接最大拉伸
    hyperspace.onComplete = onComplete
    hyperspace.onStartFadeOut = onStartFadeOut
    
    -- 保存所有星星的当前位置
    for _, star in ipairs(stars) do
        star.originalX = star.node.position.x
        star.originalY = star.node.position.y
        star.originalZ = star.node.position.z
    end
    
    print("[Background] 超空间跳跃开始（进入）")
end

-- 开始超空间跳跃（离开战斗）
function Background.StartHyperspaceExit(onComplete, onStartFadeOut)
    if hyperspace.active then return end
    
    hyperspace.active = true
    hyperspace.mode = "exit"
    hyperspace.phase = "accelerate"  -- 从加速开始
    hyperspace.timer = 0
    hyperspace.currentSpeed = 0
    hyperspace.currentStretch = 1
    hyperspace.onComplete = onComplete
    hyperspace.onStartFadeOut = onStartFadeOut
    
    -- 保存所有星星的当前位置
    for _, star in ipairs(stars) do
        star.originalX = star.node.position.x
        star.originalY = star.node.position.y
        star.originalZ = star.node.position.z
    end
    
    print("[Background] 超空间跳跃开始（离开）")
end

-- 是否正在跃迁中
function Background.IsInHyperspace()
    return hyperspace.active
end

-- 获取当前跃迁模式
function Background.GetHyperspaceMode()
    return hyperspace.mode
end

-- 获取当前跃迁速度和拉伸（用于同步敌人飞离效果）
function Background.GetHyperspaceState()
    return {
        speed = hyperspace.currentSpeed,
        stretch = hyperspace.currentStretch,
        active = hyperspace.active,
        mode = hyperspace.mode,
    }
end

-- 跳过跃迁动画（立即完成）
function Background.SkipHyperspace()
    if not hyperspace.active then return end
    
    hyperspace.phase = "complete"
    Background.FinalizeHyperspace()
end

-- 完成跃迁（重置状态）
local function FinalizeHyperspace()
    hyperspace.active = false
    hyperspace.phase = "idle"
    hyperspace.currentSpeed = 0
    hyperspace.currentStretch = 1
    
    -- 恢复所有星星到正常状态（保持当前位置，只恢复视觉属性）
    for _, star in ipairs(stars) do
        -- 恢复均匀缩放
        star.node:SetScale(star.baseScale)
        
        -- 恢复原始材质颜色
        star.model:SetMaterial(Materials.Star(star.r, star.g, star.b, 1.0))
        
        -- 更新原始位置记录
        local pos = star.node.position
        star.originalX = pos.x
        star.originalY = pos.y
        star.originalZ = pos.z
    end
    
    print("[Background] 超空间跳跃完成")
    
    if hyperspace.onComplete then
        hyperspace.onComplete()
        hyperspace.onComplete = nil
    end
end

-- 更新超空间动画
local function UpdateHyperspace(dt)
    if not hyperspace.active then return end
    
    hyperspace.timer = hyperspace.timer + dt
    
    local progress = 0
    
    if hyperspace.mode == "enter" then
        -- ========== 进入模式 ==========
        if hyperspace.phase == "warp" then
            -- 跃迁阶段：保持最高速度
            hyperspace.currentSpeed = hyperspace.maxSpeed
            hyperspace.currentStretch = hyperspace.maxStretch
            
            if hyperspace.timer >= hyperspace.warpDuration then
                hyperspace.phase = "decelerate"
                hyperspace.timer = 0
                -- 减速阶段开始时触发渐隐回调
                if hyperspace.onStartFadeOut then
                    hyperspace.onStartFadeOut()
                end
            end
            
        elseif hyperspace.phase == "decelerate" then
            -- 减速阶段：速度和拉伸逐渐归零
            progress = math.min(hyperspace.timer / hyperspace.decelerateDuration, 1)
            local eased = 1 - (1 - progress) * (1 - progress) * (1 - progress)
            hyperspace.currentSpeed = hyperspace.maxSpeed * (1 - eased)
            hyperspace.currentStretch = 1 + (hyperspace.maxStretch - 1) * (1 - eased)
            
            if progress >= 1 then
                hyperspace.currentSpeed = 0
                hyperspace.currentStretch = 1
                hyperspace.phase = "complete"
                FinalizeHyperspace()
            end
        end
    else
        -- ========== 离开模式 ==========
        if hyperspace.phase == "accelerate" then
            -- 加速阶段：速度和拉伸从 0 增加到最大
            progress = math.min(hyperspace.timer / hyperspace.exitAccelerateDuration, 1)
            local eased = progress * progress  -- ease-in
            hyperspace.currentSpeed = hyperspace.maxSpeed * eased
            hyperspace.currentStretch = 1 + (hyperspace.maxStretch - 1) * eased
            
            if progress >= 1 then
                hyperspace.phase = "warp"
                hyperspace.timer = 0
                -- 跃迁阶段开始时触发渐隐回调
                if hyperspace.onStartFadeOut then
                    hyperspace.onStartFadeOut()
                end
            end
            
        elseif hyperspace.phase == "warp" then
            -- 跃迁阶段：保持最高速度
            hyperspace.currentSpeed = hyperspace.maxSpeed
            hyperspace.currentStretch = hyperspace.maxStretch
            
            if hyperspace.timer >= hyperspace.exitWarpDuration then
                hyperspace.phase = "complete"
                FinalizeHyperspace()
            end
        end
    end
    
    -- 更新星星位置和拉伸
    -- 优化：每10帧更新一次材质，减少材质创建
    hyperspace.frameCounter = (hyperspace.frameCounter or 0) + 1
    local shouldUpdateMaterial = (hyperspace.frameCounter % 6 == 0)  -- 每6帧更新材质
    
    for _, star in ipairs(stars) do
        local pos = star.node.position
        local newZ
        
        if hyperspace.mode == "enter" then
            -- 进入模式：星星向镜头飞来（Z 减小）
            newZ = pos.z - hyperspace.currentSpeed * dt
            
            -- 当星星飞过镜头后，重新从远处生成
            -- 使用与初始化相同的深度范围（20-60），避免动画结束时跳帧
            if newZ < 5 then
                newZ = 20 + star.layer * 10 + math.random() * 10  -- 基于layer的深度 + 随机偏移
                star.node.position = Vector3(
                    Math.RandomRange(-50, 50),
                    Math.RandomRange(-30, 30),
                    newZ
                )
            else
                star.node.position = Vector3(pos.x, pos.y, newZ)
            end
        else
            -- 离开模式：星星也向镜头飞来（Z 减小），和入场一样
            newZ = pos.z - hyperspace.currentSpeed * dt
            
            -- 当星星飞过镜头后，重新从远处生成
            -- 使用与初始化相同的深度范围（20-60），避免动画结束时跳帧
            if newZ < 5 then
                newZ = 20 + star.layer * 10 + math.random() * 10  -- 基于layer的深度 + 随机偏移
                star.node.position = Vector3(
                    Math.RandomRange(-50, 50),
                    Math.RandomRange(-30, 30),
                    newZ
                )
            else
                star.node.position = Vector3(pos.x, pos.y, newZ)
            end
        end
        
        -- 拉伸效果：沿 Z 轴拉长星星
        local stretch = hyperspace.currentStretch
        local baseScale = star.baseScale
        
        -- 根据距离调整拉伸
        local distFactor = (60 - math.min(newZ, 60)) / 40
        local actualStretch = 1 + (stretch - 1) * math.max(distFactor, 0.3)
        
        -- 设置缩放（当拉伸接近1时使用均匀缩放，避免跳帧）
        if actualStretch < 1.01 then
            star.node:SetScale(baseScale)
        else
            star.node:SetScale(Vector3(baseScale, baseScale, baseScale * actualStretch))
        end
        
        -- 亮度随速度增加（优化：降低材质更新频率）
        if shouldUpdateMaterial then
            local speedRatio = hyperspace.currentSpeed / hyperspace.maxSpeed
            local brightnessMult = 1 + speedRatio * 2
            local r = math.min(star.r * brightnessMult, 1.0)
            local g = math.min(star.g * brightnessMult, 1.0)
            local b = math.min(star.b * brightnessMult, 1.0)
            
            -- 高速时偏蓝白色
            if speedRatio > 0.5 then
                local blueTint = (speedRatio - 0.5) * 2
                r = r * (1 - blueTint * 0.3)
                b = math.min(b * (1 + blueTint * 0.5), 1.0)
            end
            
            star.model:SetMaterial(Materials.Star(r, g, b, 1.0))
        end
    end
end

-- ============================================================================
-- 更新背景（闪烁效果）
-- ============================================================================

function Background.Update(dt)
    -- 优先处理超空间跳跃
    if hyperspace.active then
        UpdateHyperspace(dt)
        return
    end
    
    -- 正常闪烁效果
    local time = os.clock()
    
    for _, star in ipairs(stars) do
        -- 闪烁效果
        local twinkle = 0.7 + 0.3 * math.sin(time * star.twinkleSpeed + star.twinklePhase)
        local newScale = star.baseScale * twinkle
        star.node:SetScale(newScale)
    end
end

-- ============================================================================
-- 清理
-- ============================================================================

function Background.Clear()
    for _, star in ipairs(stars) do
        if star.node then
            star.node:Remove()
        end
    end
    stars = {}
    
    -- 重置超空间状态
    hyperspace.active = false
    hyperspace.phase = "idle"
end

-- ============================================================================
-- 获取星星列表
-- ============================================================================

function Background.GetStars()
    return stars
end

return Background
