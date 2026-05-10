-- ============================================================================
-- 星河战姬 Starkyries - 玩家实体
-- 战舰创建、移动、武器管理
-- ============================================================================

local Settings = require("config.settings")
local Ships = require("config.ships")
local Weapons = require("config.weapons")
local Materials = require("render.Materials")
local ShipModels = require("render.ShipModels")
local Math = require("utils.Math")
local PlayerDeathAnimation = require("entities.player.PlayerDeathAnimation")

local Player = {}

-- Game 延迟加载（避免循环依赖）
local Game = nil
local function GetGame()
    if not Game then
        Game = require("core.Game")
    end
    return Game
end

-- ============================================================================
-- 玩家状态
-- ============================================================================
Player.node = nil
Player.hullNode = nil  -- Hull节点引用，用于旋转
Player.weapons = {}  -- 武器实例列表 {id, tier, slotIndex, cooldown, turretNode, barrelNode}
                     -- 🔧 注意：Game.player.weapons 直接引用此数组，不要用 = {} 重新赋值！

-- 原地清空武器数组（保持引用不变，供 Game.player.weapons 同步）
local function ClearWeaponsInPlace()
    -- 先清理所有武器的 turretNode
    for _, weapon in ipairs(Player.weapons) do
        if weapon.turretNode then
            weapon.turretNode:Remove()
            weapon.turretNode = nil
        end
    end
    -- 原地清空数组（保持表引用不变）
    for i = #Player.weapons, 1, -1 do
        Player.weapons[i] = nil
    end
end
Player.flameNodes = {}  -- 引擎火焰节点引用 {node, baseScale}
Player.isMoving = false  -- 是否正在移动
Player.flameIntensity = 0  -- 火焰强度 (0-1)
Player.flameFadeSpeed = nil  -- 从 Settings.Visual.FlameFadeSpeed 获取

-- 8方向朝向系统（等距俯视风格）
-- 固定俯视角度 + 水平面内转向（四元数组合）
Player.TILT_ANGLE = Settings.Visual.TiltAngle  -- 固定俯视角度

-- 8个方向的水平朝向角度（绕Y轴，船头指向）
Player.DIRECTIONS = {
    RIGHT      = 0,      -- → 右
    RIGHT_UP   = -45,    -- ↗ 右上
    UP         = -90,    -- ↑ 上
    LEFT_UP    = -135,   -- ↖ 左上
    LEFT       = 180,    -- ← 左
    LEFT_DOWN  = 135,    -- ↙ 左下
    DOWN       = 90,     -- ↓ 下
    RIGHT_DOWN = 45,     -- ↘ 右下
}

Player.currentDirection = "UP"  -- 当前朝向（默认朝上，跃迁姿态）
Player.targetYaw = 0               -- 目标水平朝向（绕Y轴）
Player.currentYaw = 0              -- 当前水平朝向（绕Y轴）
Player.rotationSpeed = 300         -- 旋转速度（度/秒）

-- 计算最终旋转：等距俯视风格
-- 先应用俯视倾斜，再绕倾斜后的Y轴旋转方向
-- 这样船看起来在一个倾斜平面上旋转
function Player.ComputeRotation(yaw)
    local tiltRot = Quaternion(Player.TILT_ANGLE, Vector3.RIGHT)  -- 俯视角（绕X轴）
    local directionRot = Quaternion(yaw, Vector3.UP)  -- 水平朝向（绕Y轴）
    return tiltRot * directionRot  -- 先倾斜视角，再转方向
end

-- ============================================================================
-- 创建战舰
-- ============================================================================

function Player.Create(scene, shipConfig)
    shipConfig = shipConfig or Ships.GetDefault()
    
    Player.node = scene:CreateChild("PlayerShip")
    Player.node.position = Vector3(0, 0, 0)
    -- 🔧 原地清空武器数组，保持 Game.player.weapons 引用有效
    ClearWeaponsInPlace()
    Player.currentShipId = shipConfig.id  -- 保存当前战舰ID
    
    -- 使用 ShipModels 系统创建战舰模型
    local hullNode, flameNodes, engineLight = ShipModels.Create(
        shipConfig.id,
        Player.node,
        shipConfig
    )
    
    -- 保存引用
    Player.hullNode = hullNode
    Player.flameNodes = flameNodes or {}
    Player.engineLight = engineLight
    
    -- 初始朝向（上）：跃迁姿态
    Player.currentYaw = Player.DIRECTIONS.UP
    Player.targetYaw = Player.currentYaw
    if Player.hullNode then
        Player.hullNode.rotation = Player.ComputeRotation(Player.currentYaw)
    end
    
    -- 初始状态：火焰强度为0
    Player.flameIntensity = 0
    Player.UpdateFlameVisual()
    
    return Player.node
end

-- ============================================================================
-- 武器系统
-- ============================================================================

-- 添加武器
function Player.AddWeapon(weaponId, slotIndex, tier, shipConfig)
    tier = tier or 1
    local weaponDef = Weapons.Get(weaponId)
    if not weaponDef then return nil end
    
    -- 使用传入的战舰配置，或从 Game 获取，或使用默认
    shipConfig = shipConfig or (GetGame() and GetGame().player and GetGame().player.shipConfig) or Ships.GetDefault()
    
    local slots = shipConfig.weaponSlots
    if not slots then return nil end
    
    local slot = slots[slotIndex]
    if not slot then return nil end
    
    -- 创建炮塔节点（挂载到 hullNode，随船体旋转）
    local parentNode = Player.hullNode or Player.node
    local turretNode = parentNode:CreateChild("Turret_" .. slotIndex)
    -- 支持3D槽位坐标：x=长度方向, y=高度, z=宽度方向
    local slotZ = slot.z or 0
    turretNode.position = Vector3(slot.x, slot.y, slotZ)
    
    -- 炮塔底座（按品质着色）
    local base = turretNode:CreateChild("Base")
    local baseModel = base:CreateComponent("StaticModel")
    baseModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    base:SetScale(Vector3(weaponDef.turretSize, 0.1, weaponDef.turretSize))
    baseModel:SetMaterial(Materials.TurretBaseByTier(tier))
    
    -- 炮管（可旋转瞄准）
    local barrel = turretNode:CreateChild("Barrel")
    local barrelModel = barrel:CreateComponent("StaticModel")
    barrelModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    barrel:SetScale(Vector3(0.08, weaponDef.turretSize * 1.5, 0.08))
    barrel.rotation = Quaternion(0, 0, -90)  -- 初始朝右
    barrel.position = Vector3(weaponDef.turretSize * 0.5, 0, 0)
    
    -- 🔧 默认使用不发光的材质，射击时才闪亮
    barrelModel:SetMaterial(Materials.WeaponBarrel())
    
    local weapon = {
        id = weaponId,
        tier = tier,
        slotIndex = slotIndex,
        cooldown = 0,
        turretNode = turretNode,
        barrelNode = barrel,
        weaponColor = weaponDef.color,  -- 保存武器颜色用于射击闪光
        flashTimer = 0,  -- 闪光计时器
    }
    
    table.insert(Player.weapons, weapon)
    return weapon
end

-- 重新分配同类武器的冷却时间（均匀错开，避免同时发射）
function Player.RedistributeWeaponCooldowns(weaponId)
    local weaponDef = Weapons.Get(weaponId)
    if not weaponDef then return end
    
    -- 收集同类武器
    local sameWeapons = {}
    for _, w in ipairs(Player.weapons) do
        if w.id == weaponId then
            table.insert(sameWeapons, w)
        end
    end
    
    local count = #sameWeapons
    if count <= 1 then return end  -- 单把武器无需错开
    
    -- 计算基础冷却时间
    local baseCooldown = weaponDef.cooldown
    -- 使用第一把武器的tier来计算（假设同类武器tier相同或接近）
    local tier = sameWeapons[1].tier or 1
    if weaponDef.tierCooldown and weaponDef.tierCooldown[tier] then
        baseCooldown = weaponDef.tierCooldown[tier]
    end
    
    -- 均匀分配冷却时间：0, CD/n, 2*CD/n, 3*CD/n, ...
    for i, w in ipairs(sameWeapons) do
        w.cooldown = baseCooldown * ((i - 1) / count)
    end
end

-- 重新分配所有武器类型的冷却时间（游戏加载后调用）
function Player.RedistributeAllWeaponCooldowns()
    -- 收集所有不同的武器ID
    local weaponIds = {}
    for _, w in ipairs(Player.weapons) do
        weaponIds[w.id] = true
    end
    
    -- 为每种武器类型重新分配冷却
    for weaponId, _ in pairs(weaponIds) do
        Player.RedistributeWeaponCooldowns(weaponId)
    end
end

-- 移除武器
function Player.RemoveWeapon(slotIndex)
    for i, weapon in ipairs(Player.weapons) do
        if weapon.slotIndex == slotIndex then
            if weapon.turretNode then
                weapon.turretNode:Remove()
            end
            table.remove(Player.weapons, i)
            return true
        end
    end
    return false
end

-- 更新武器品质视觉（合成升级后调用）
function Player.UpdateWeaponTierVisual(weapon)
    if not weapon or not weapon.turretNode then return end
    
    local tier = weapon.tier or 1
    local baseNode = weapon.turretNode:GetChild("Base")
    if baseNode then
        local baseModel = baseNode:GetComponent("StaticModel")
        if baseModel then
            baseModel:SetMaterial(Materials.TurretBaseByTier(tier))
        end
    end
end

-- 射击闪光持续时间（秒）
local WEAPON_FLASH_DURATION = Settings.Visual.WeaponFlashDuration

-- 触发武器射击闪光
function Player.TriggerWeaponFlash(weapon)
    if not weapon or not weapon.barrelNode or not weapon.weaponColor then return end
    
    local barrelModel = weapon.barrelNode:GetComponent("StaticModel")
    if barrelModel then
        -- 切换到发光材质
        barrelModel:SetMaterial(Materials.WeaponBarrelGlow(weapon.weaponColor))
        weapon.flashTimer = WEAPON_FLASH_DURATION
    end
end

-- 更新所有武器的闪光状态（每帧调用）
function Player.UpdateWeaponFlash(dt)
    for _, weapon in ipairs(Player.weapons) do
        if weapon.flashTimer and weapon.flashTimer > 0 then
            weapon.flashTimer = weapon.flashTimer - dt
            if weapon.flashTimer <= 0 then
                -- 恢复不发光材质
                if weapon.barrelNode then
                    local barrelModel = weapon.barrelNode:GetComponent("StaticModel")
                    if barrelModel then
                        barrelModel:SetMaterial(Materials.WeaponBarrel())
                    end
                end
                weapon.flashTimer = 0
            end
        end
    end
end

-- 获取空闲槽位
function Player.GetFreeSlot(maxSlots)
    local usedSlots = {}
    
    -- 检查 Game.player.weapons（商店购买的武器在这里）
    local game = GetGame()
    local gameWeapons = game and game.player and game.player.weapons or {}
    for _, w in ipairs(gameWeapons) do
        if w.slotIndex then
            usedSlots[w.slotIndex] = true
        end
    end
    
    -- 也检查 Player.weapons（兼容性）
    for _, w in ipairs(Player.weapons) do
        if w.slotIndex then
            usedSlots[w.slotIndex] = true
        end
    end
    
    for i = 1, maxSlots do
        if not usedSlots[i] then
            return i
        end
    end
    return nil
end

-- 更新武器炮塔位置（使用Y轴旋转后，子节点自动跟随，此函数保留兼容性）
function Player.UpdateWeaponPositions(facingRight, shipConfig)
    -- 使用Y轴旋转后，武器作为子节点会自动跟随旋转
    -- 不再需要手动翻转X坐标
    -- 保留此函数以保持API兼容性
end

-- 更新炮塔朝向（完整3D旋转）
function Player.AimWeaponAt(weapon, targetX, targetY)
    local weaponDef = Weapons.Get(weapon.id)
    if not weaponDef or not weapon.turretNode then return end
    
    -- 获取炮塔世界位置和旋转
    local turretWorldPos = weapon.turretNode.worldPosition
    local turretWorldRot = weapon.turretNode.worldRotation
    
    -- 计算世界空间中指向目标的方向
    local targetWorldPos = Vector3(targetX, targetY, 0)
    local worldDir = targetWorldPos - turretWorldPos
    if worldDir:Length() < 0.001 then return end
    worldDir = worldDir:Normalized()
    
    -- 将世界方向转换到炮塔的本地空间
    local invRot = turretWorldRot:Inverse()
    local localDir = invRot * worldDir
    localDir = localDir:Normalized()
    
    if weapon.barrelNode then
        -- Cylinder模型默认沿Y轴（Vector3.UP）
        -- 使用 FromRotationTo 计算从Y轴到目标方向的3D旋转
        local fromDir = Vector3.UP
        local toDir = localDir
        
        local rotation = Quaternion()
        rotation:FromRotationTo(fromDir, toDir)
        weapon.barrelNode.rotation = rotation
        
        -- 炮管位置偏移（沿本地方向）
        local offset = weaponDef.turretSize * 0.5
        weapon.barrelNode.position = Vector3(
            localDir.x * offset,
            localDir.y * offset,
            localDir.z * offset
        )
    end
end

-- ============================================================================
-- 移动
-- ============================================================================

function Player.Move(dx, dy, dt, moveSpeed)
    if not Player.node then return end
    
    local pos = Player.node.position
    pos.x = pos.x + dx * moveSpeed * dt
    pos.y = pos.y + dy * moveSpeed * dt
    
    -- 边界限制
    local area = Settings.BattleArea
    pos.x = Math.Clamp(pos.x, area.MinX, area.MaxX)
    pos.y = Math.Clamp(pos.y, area.MinY, area.MaxY)
    
    Player.node.position = pos
    
    -- 检测是否正在移动
    Player.isMoving = math.abs(dx) > 0.01 or math.abs(dy) > 0.01
    
    -- 根据移动方向更新8方向朝向
    if Player.isMoving then
        Player.UpdateDirectionFromMovement(dx, dy)
    end
end

-- 根据移动方向计算8方向朝向
function Player.UpdateDirectionFromMovement(dx, dy)
    local newDir = nil
    
    -- 使用角度来判断8个方向
    -- 每个方向占 45 度范围
    local angle = math.atan(dy, dx)  -- 返回弧度 (-π, π]
    local degrees = math.deg(angle)   -- 转换为角度 (-180, 180]
    
    -- 将角度映射到8个方向
    -- 右: -22.5 ~ 22.5
    -- 右上: 22.5 ~ 67.5
    -- 上: 67.5 ~ 112.5
    -- 左上: 112.5 ~ 157.5
    -- 左: 157.5 ~ 180 或 -180 ~ -157.5
    -- 左下: -157.5 ~ -112.5
    -- 下: -112.5 ~ -67.5
    -- 右下: -67.5 ~ -22.5
    
    if degrees >= -22.5 and degrees < 22.5 then
        newDir = "RIGHT"
    elseif degrees >= 22.5 and degrees < 67.5 then
        newDir = "RIGHT_UP"
    elseif degrees >= 67.5 and degrees < 112.5 then
        newDir = "UP"
    elseif degrees >= 112.5 and degrees < 157.5 then
        newDir = "LEFT_UP"
    elseif degrees >= 157.5 or degrees < -157.5 then
        newDir = "LEFT"
    elseif degrees >= -157.5 and degrees < -112.5 then
        newDir = "LEFT_DOWN"
    elseif degrees >= -112.5 and degrees < -67.5 then
        newDir = "DOWN"
    elseif degrees >= -67.5 and degrees < -22.5 then
        newDir = "RIGHT_DOWN"
    end
    
    if newDir and newDir ~= Player.currentDirection then
        Player.SetDirection(newDir)
    end
end

-- 设置目标朝向（8方向）
function Player.SetDirection(dirName)
    local yaw = Player.DIRECTIONS[dirName]
    if yaw then
        Player.currentDirection = dirName
        Player.targetYaw = yaw
    end
end

-- 设置目标朝向 (兼容旧接口)
function Player.SetFacing(facingRight)
    Player.SetDirection(facingRight and "RIGHT" or "LEFT")
end

-- 立即设置朝向 (无动画，用于初始化)
function Player.SetFacingImmediate(facingRight)
    local dirName = facingRight and "RIGHT" or "LEFT"
    local yaw = Player.DIRECTIONS[dirName]
    Player.currentDirection = dirName
    Player.targetYaw = yaw
    Player.currentYaw = yaw
    if Player.hullNode then
        Player.hullNode.rotation = Player.ComputeRotation(yaw)
    end
end

-- 立即设置任意朝向 (无动画)
function Player.SetDirectionImmediate(dirName)
    local yaw = Player.DIRECTIONS[dirName]
    if yaw then
        Player.currentDirection = dirName
        Player.targetYaw = yaw
        Player.currentYaw = yaw
        if Player.hullNode then
            Player.hullNode.rotation = Player.ComputeRotation(yaw)
        end
    end
end

-- 平滑插值单个角度（处理环绕）
local function lerpAngle(current, target, step)
    local diff = target - current
    -- 处理角度环绕（选择最短路径）
    if diff > 180 then diff = diff - 360
    elseif diff < -180 then diff = diff + 360
    end
    
    if math.abs(diff) < 0.5 then
        return target
    elseif diff > 0 then
        return current + math.min(step, diff)
    else
        return current - math.min(step, -diff)
    end
end

-- 更新朝向旋转 (每帧调用)
function Player.UpdateRotation(dt)
    if not Player.hullNode then return end
    
    local step = Player.rotationSpeed * dt
    
    -- 只插值水平朝向（yaw），俯视角度固定
    Player.currentYaw = lerpAngle(Player.currentYaw, Player.targetYaw, step)
    
    -- 使用四元数组合计算最终旋转
    Player.hullNode.rotation = Player.ComputeRotation(Player.currentYaw)
end

-- 快速转向更新（用于跃迁准备阶段，0.1秒内完成任意角度）
function Player.UpdateRotationFast(dt)
    if not Player.hullNode then return end
    
    -- 1800度/秒，0.1秒可转180度
    local fastSpeed = 1800
    local step = fastSpeed * dt
    
    Player.currentYaw = lerpAngle(Player.currentYaw, Player.targetYaw, step)
    Player.hullNode.rotation = Player.ComputeRotation(Player.currentYaw)
end

-- 获取当前是否朝右
function Player.IsFacingRight()
    return Player.currentDirection == "RIGHT" or 
           Player.currentDirection == "RIGHT_UP" or 
           Player.currentDirection == "RIGHT_DOWN"
end

-- 设置可见性（无敌闪烁）
function Player.SetVisible(visible)
    if Player.node then
        Player.node:SetEnabled(visible)
    end
end

-- ============================================================================
-- 受击闪白
-- ============================================================================

Player.hitFlashTimer = 0
Player.originalMaterials = nil

-- 受击闪白材质（玩家战舰较大，使用较低强度避免过亮）
local hitFlashMaterial = nil
local function GetHitFlashMaterial()
    if not hitFlashMaterial then
        hitFlashMaterial = Materials.CreateGlow(1.0, 1.0, 1.0, 0.8)
    end
    return hitFlashMaterial
end

-- 递归收集节点下所有 StaticModel（排除引擎火焰节点）
local function CollectModels(node, models)
    models = models or {}
    local nodeName = node.name or ""
    
    -- 排除引擎火焰相关节点（Flame*, Glow*）
    if nodeName:find("^Flame") or nodeName:find("^Glow") then
        return models
    end
    
    local model = node:GetComponent("StaticModel")
    if model then
        table.insert(models, {node = node, model = model})
    end
    local numChildren = node:GetNumChildren(false)
    for i = 0, numChildren - 1 do
        CollectModels(node:GetChild(i), models)
    end
    return models
end

-- 触发受击闪白
function Player.TriggerHitFlash()
    if not Player.node then return end
    
    Player.hitFlashTimer = Settings.Visual.HitFlashDuration
    
    local targetNode = Player.hullNode or Player.node
    
    -- 如果还没保存原始材质，先保存
    if not Player.originalMaterials then
        Player.originalMaterials = {}
        local models = CollectModels(targetNode)
        for _, item in ipairs(models) do
            Player.originalMaterials[item.node.name] = item.model:GetMaterial(0)
        end
    end
    
    -- 应用闪白材质
    local flashMat = GetHitFlashMaterial()
    local models = CollectModels(targetNode)
    for _, item in ipairs(models) do
        item.model:SetMaterial(flashMat)
    end
end

-- 恢复原始材质
function Player.RestoreOriginalMaterials()
    if not Player.originalMaterials or not Player.node then return end
    
    local targetNode = Player.hullNode or Player.node
    local models = CollectModels(targetNode)
    for _, item in ipairs(models) do
        local originalMat = Player.originalMaterials[item.node.name]
        if originalMat then
            item.model:SetMaterial(originalMat)
        end
    end
end

-- 更新受击闪白（每帧调用）
function Player.UpdateHitFlash(dt)
    if Player.hitFlashTimer > 0 then
        Player.hitFlashTimer = Player.hitFlashTimer - dt
        if Player.hitFlashTimer <= 0 then
            Player.RestoreOriginalMaterials()
        end
    end
end

-- 更新引擎火焰（每帧调用，处理渐变效果）
function Player.UpdateFlame(dt)
    local targetIntensity = Player.isMoving and 1.0 or 0.0
    local fadeSpeed = Settings.Visual.FlameFadeSpeed
    
    if Player.flameIntensity ~= targetIntensity then
        if targetIntensity > Player.flameIntensity then
            -- 点火：快速达到满强度
            Player.flameIntensity = math.min(1.0, Player.flameIntensity + fadeSpeed * 2 * dt)
        else
            -- 熄灭：渐渐消失
            Player.flameIntensity = math.max(0.0, Player.flameIntensity - fadeSpeed * dt)
        end
        Player.UpdateFlameVisual()
    end
end

-- 根据火焰强度更新视觉效果
function Player.UpdateFlameVisual()
    local intensity = Player.flameIntensity
    local visible = intensity > 0.01
    
    for _, flameData in ipairs(Player.flameNodes) do
        if flameData.node then
            flameData.node:SetEnabled(visible)
            if visible then
                -- 根据强度缩放火焰大小
                local baseScale = flameData.baseScale
                local scale = Vector3(
                    baseScale.x * intensity,
                    baseScale.y * intensity,
                    baseScale.z * intensity
                )
                flameData.node:SetScale(scale)
            end
        end
    end
    
    -- 更新引擎点光源亮度
    if Player.engineLight then
        Player.engineLight.brightness = intensity * 2.0  -- 最大亮度 2.0
    end
end

-- ============================================================================
-- 获取
-- ============================================================================

function Player.GetPosition()
    if Player.node then
        local pos = Player.node.position
        return pos.x, pos.y
    end
    return 0, 0
end

-- 设置玩家位置
function Player.SetPosition(x, y)
    if Player.node then
        Player.node.position = Vector3(x, y, 0)
    end
end

-- 重置玩家到地图中心
function Player.ResetToCenter()
    Player.SetPosition(0, 0)
end

function Player.GetNode()
    return Player.node
end

function Player.GetWeapons()
    return Player.weapons
end

-- ============================================================================
-- 死亡动画（委托给 PlayerDeathAnimation 模块）
-- ============================================================================

-- 开始死亡动画
function Player.StartDeathAnimation(scene, onComplete)
    -- 关闭引擎火焰
    Player.isMoving = false
    Player.flameIntensity = 0
    Player.UpdateFlameVisual()
    
    -- 委托给 PlayerDeathAnimation 模块
    PlayerDeathAnimation.Start(scene, Player.node, onComplete)
end

-- 更新死亡动画（每帧调用）
function Player.UpdateDeathAnimation(dt)
    PlayerDeathAnimation.Update(dt, Player.node)
end

-- 检查死亡动画是否正在播放
function Player.IsDeathAnimationActive()
    return PlayerDeathAnimation.IsActive()
end

-- ============================================================================
-- 清理
-- ============================================================================

function Player.Destroy()
    -- 清理死亡动画残留节点
    PlayerDeathAnimation.Cleanup()
    
    if Player.node then
        Player.node:Remove()
        Player.node = nil
    end
    Player.hullNode = nil
    -- 🔧 原地清空武器数组，保持 Game.player.weapons 引用有效
    ClearWeaponsInPlace()
    Player.flameNodes = {}
    Player.engineLight = nil
    
    -- 🔧 修复内存泄漏：清理受击闪白相关资源
    Player.originalMaterials = nil
    Player.hitFlashTimer = 0
    
    -- 重置朝向状态（朝上，跃迁姿态）
    Player.currentDirection = "UP"
    Player.targetYaw = Player.DIRECTIONS.UP
    Player.currentYaw = Player.DIRECTIONS.UP
    
    -- 重置移动和火焰状态
    Player.isMoving = false
    Player.flameIntensity = 0
end

return Player
