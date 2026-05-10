-- ============================================================================
-- 星河战姬 Starkyries - 初始武器选择界面
-- 安全区设计：横屏16:9 / 竖屏9:16
-- ============================================================================
-- 
-- UI 尺寸标准: baseUnit = safe.baseUnit
-- 
-- 安全区布局:
--   横屏 (16:9): 5卡片横向滚动
--   竖屏 (9:16): 2卡片每行，纵向滚动
-- 
-- ============================================================================

local Weapons = require("config.weapons")
local UIStyle = require("ui.UIStyle")
local UISafeArea = require("ui.UISafeArea")
local UIScreen = require("ui.UIScreen")
local ImageLoader = require("utils.ImageLoader")

local WeaponSelectUI = {}

-- ============================================================================
-- 状态
-- ============================================================================
WeaponSelectUI.visible = false
WeaponSelectUI.selectedIndex = 1
WeaponSelectUI.weapons = {}
WeaponSelectUI.onSelect = nil
WeaponSelectUI.animTime = 0
WeaponSelectUI.selectedShip = nil
WeaponSelectUI.showKeyboardFocus = false  -- 键盘导航模式（预留，当前卡片选中为功能性高亮，始终显示）

-- 滚动相关（支持横向和纵向）
WeaponSelectUI.scrollOffset = 0      -- 当前滚动偏移（像素）
WeaponSelectUI.targetScrollOffset = 0 -- 目标滚动偏移
WeaponSelectUI.isDragging = false
WeaponSelectUI.dragStartX = 0
WeaponSelectUI.dragStartY = 0
WeaponSelectUI.dragStartOffset = 0
WeaponSelectUI.lastDragX = 0
WeaponSelectUI.lastDragY = 0
WeaponSelectUI.dragVelocity = 0

-- 武器图标缓存
WeaponSelectUI.weaponImages = {}

-- VS核心验证武器（12种）
WeaponSelectUI.StarterWeapons = {
    "ParticleMachinegun", -- 资源流：粒子机炮（击毁+1晶体）
    "RapidForceField",   -- 直射：速射力场
    "HomingMissile",     -- 追踪：追踪导弹
    "LaserSniper",       -- 穿透：激光狙击
    "ClusterMissile",    -- AOE：集束导弹
    "IonChain",          -- 连锁：离子连锁炮
    "PlasmaJet",         -- DOT：等离子喷射器
    "ImpulsePulse",      -- 击退：冲击脉冲
    "FighterDrone",      -- 召唤：战斗无人机
    "BomberDrone",       -- 召唤+AOE：轰炸无人机
    "StormForceField",   -- 高射速：风暴力场
    "HeavyTorpedo",      -- 高伤害：主炮弹
}

-- 从武器配置中读取标签（由策划定义）
function WeaponSelectUI.GetEffectLabels(weapon)
    -- 直接返回配置中的 tags 字段
    if weapon.tags and #weapon.tags > 0 then
        return weapon.tags
    end
    -- 如果没有配置标签，返回空数组
    return {}
end

-- 武器类型颜色（用于图标/类型标签）
WeaponSelectUI.TypeColors = {
    [Weapons.Types.FORCE_FIELD] = {r = 60, g = 180, b = 255},
    [Weapons.Types.ARC] = {r = 100, g = 150, b = 255},
    [Weapons.Types.MISSILE] = {r = 255, g = 140, b = 60},
    [Weapons.Types.LASER] = {r = 100, g = 255, b = 150},
    [Weapons.Types.CARRIER] = {r = 180, g = 120, b = 255},
}

-- Tier等级颜色（用于卡片边框/发光）
-- T1白色、T2绿色、T3蓝色、T4紫色
WeaponSelectUI.TierColors = {
    [1] = {r = 200, g = 200, b = 200},  -- T1 白色/灰白
    [2] = {r = 80, g = 220, b = 100},   -- T2 绿色
    [3] = {r = 80, g = 160, b = 255},   -- T3 蓝色
    [4] = {r = 180, g = 80, b = 255},   -- T4 紫色
}

-- 射程分类颜色
WeaponSelectUI.RangeColors = {
    close = {r = 255, g = 120, b = 80},
    medium = {r = 255, g = 220, b = 80},
    long = {r = 80, g = 255, b = 160},
}

-- ============================================================================
-- 响应式布局判断
-- ============================================================================

function WeaponSelectUI.IsPortrait(sw, sh)
    return sh >= sw  -- 宽高比 >= 1 视为竖屏
end

-- ============================================================================
-- 布局配置（响应式）
-- ============================================================================

function WeaponSelectUI.GetLayoutConfig(sw, sh)
    if WeaponSelectUI.IsPortrait(sw, sh) then
        -- 竖屏布局：2列，纵向滚动
        return {
            isPortrait = true,
            columns = 2,                 -- 每行2个卡片
            cardWidthRatio = 0.42,       -- 卡片宽度占屏幕比例
            cardHeightRatio = 0.28,      -- 卡片高度占屏幕比例
            gapXRatio = 0.04,            -- 横向间距
            gapYRatio = 0.02,            -- 纵向间距
            startY = 0.18,               -- 卡片起始Y位置
            contentHeight = 0.62,        -- 内容区域高度比例
        }
    else
        -- 横屏布局：5列，横向滚动
        return {
            isPortrait = false,
            visibleCards = 5,            -- 屏幕上显示的卡片数量
            cardWidthRatio = 0.16,       -- 卡片宽度占屏幕比例
            cardHeightRatio = 0.55,      -- 卡片高度占屏幕比例
            gapRatio = 0.02,             -- 间距占屏幕比例
            startY = 0.20,               -- 卡片起始Y位置
        }
    end
end

-- ============================================================================
-- 初始化
-- ============================================================================

function WeaponSelectUI.Init()
    WeaponSelectUI.weapons = {}
    for _, weaponId in ipairs(WeaponSelectUI.StarterWeapons) do
        local weapon = Weapons.Get(weaponId)
        if weapon then
            -- 复制武器数据，根据 noTier1 调整初始 Tier
            local weaponCopy = {}
            for k, v in pairs(weapon) do
                weaponCopy[k] = v
            end
            
            -- 无T1的武器直接给T2
            if weapon.noTier1 then
                weaponCopy.tier = 2
                -- 更新伤害为T2伤害
                if weapon.tierDamage and weapon.tierDamage[2] then
                    weaponCopy.damage = weapon.tierDamage[2]
                end
                -- 更新射程为T2射程（如果有tierRange）
                if weapon.tierRange and weapon.tierRange[2] then
                    weaponCopy.range = weapon.tierRange[2]
                end
            else
                weaponCopy.tier = 1
            end
            
            table.insert(WeaponSelectUI.weapons, weaponCopy)
        end
    end
    WeaponSelectUI.selectedIndex = 1
    WeaponSelectUI.scrollOffset = 0
    WeaponSelectUI.targetScrollOffset = 0
    WeaponSelectUI.animTime = 0
    WeaponSelectUI.isDragging = false
    WeaponSelectUI.dragVelocity = 0
    WeaponSelectUI.showKeyboardFocus = false
end

function WeaponSelectUI.CollectImagePaths()
    local paths = {}
    for _, weaponId in ipairs(WeaponSelectUI.StarterWeapons) do
        paths[#paths + 1] = "images/weapons/" .. weaponId .. ".jpg"
    end
    return paths
end

function WeaponSelectUI.Show(ship, callback)
    local paths = WeaponSelectUI.CollectImagePaths()
    ImageLoader.PreloadGate(paths, function()
        WeaponSelectUI.visible = true
        WeaponSelectUI.selectedShip = ship
        WeaponSelectUI.onSelect = callback
        WeaponSelectUI.Init()
        
        -- 默认选中战舰推荐的武器（如果在列表中）
        if ship and ship.initialWeapon then
            for i, weapon in ipairs(WeaponSelectUI.weapons) do
                if weapon.id == ship.initialWeapon then
                    WeaponSelectUI.selectedIndex = i
                    break
                end
            end
        end
    end, "正在加载武器数据...")
end

function WeaponSelectUI.Hide()
    WeaponSelectUI.visible = false
    WeaponSelectUI.safeArea = nil
end

-- ============================================================================
-- 计算布局（横屏）
-- ============================================================================

function WeaponSelectUI.GetLayoutParamsLandscape(sw, sh, config)
    local baseUnit = math.min(sw, sh) / 40
    
    local cardW = sw * config.cardWidthRatio
    local cardH = sh * config.cardHeightRatio
    local gap = sw * config.gapRatio
    local totalCardWidth = cardW + gap
    
    -- 计算居中偏移
    local visibleWidth = config.visibleCards * cardW + (config.visibleCards - 1) * gap
    local startX = (sw - visibleWidth) / 2
    
    -- 最大滚动范围
    local totalWeapons = #WeaponSelectUI.weapons
    local maxScroll = math.max(0, (totalWeapons - config.visibleCards) * totalCardWidth)
    
    return {
        isPortrait = false,
        cardW = cardW,
        cardH = cardH,
        gap = gap,
        totalCardWidth = totalCardWidth,
        startX = startX,
        startY = sh * config.startY,
        maxScroll = maxScroll,
        baseUnit = baseUnit,
        sw = sw,
        sh = sh,
        visibleCards = config.visibleCards,
    }
end

-- ============================================================================
-- 计算布局（竖屏）
-- ============================================================================

function WeaponSelectUI.GetLayoutParamsPortrait(sw, sh, config)
    local baseUnit = math.min(sw, sh) / 40
    
    local cardW = sw * config.cardWidthRatio
    local cardH = sh * config.cardHeightRatio
    local gapX = sw * config.gapXRatio
    local gapY = sh * config.gapYRatio
    
    -- 计算行列布局
    local columns = config.columns
    local totalWeapons = #WeaponSelectUI.weapons
    local rows = math.ceil(totalWeapons / columns)
    
    -- 居中计算
    local totalWidth = columns * cardW + (columns - 1) * gapX
    local startX = (sw - totalWidth) / 2
    local startY = sh * config.startY
    
    -- 内容区域高度
    local contentHeight = sh * config.contentHeight
    local totalContentHeight = rows * cardH + (rows - 1) * gapY
    
    -- 最大滚动范围
    local maxScroll = math.max(0, totalContentHeight - contentHeight)
    
    return {
        isPortrait = true,
        cardW = cardW,
        cardH = cardH,
        gapX = gapX,
        gapY = gapY,
        columns = columns,
        rows = rows,
        startX = startX,
        startY = startY,
        contentHeight = contentHeight,
        totalContentHeight = totalContentHeight,
        maxScroll = maxScroll,
        baseUnit = baseUnit,
        sw = sw,
        sh = sh,
    }
end

-- ============================================================================
-- 统一布局计算入口
-- ============================================================================

function WeaponSelectUI.GetLayoutParams(sw, sh)
    local config = WeaponSelectUI.GetLayoutConfig(sw, sh)
    if config.isPortrait then
        return WeaponSelectUI.GetLayoutParamsPortrait(sw, sh, config)
    else
        return WeaponSelectUI.GetLayoutParamsLandscape(sw, sh, config)
    end
end

-- ============================================================================
-- 滚动控制
-- ============================================================================

function WeaponSelectUI.UpdateScroll(dt, params)
    -- 拖动结束后的惯性滚动
    if not WeaponSelectUI.isDragging and math.abs(WeaponSelectUI.dragVelocity) > 1 then
        WeaponSelectUI.scrollOffset = WeaponSelectUI.scrollOffset + WeaponSelectUI.dragVelocity * dt
        WeaponSelectUI.dragVelocity = WeaponSelectUI.dragVelocity * 0.92 -- 摩擦力
        
        -- 边界检查
        if WeaponSelectUI.scrollOffset < 0 then
            WeaponSelectUI.scrollOffset = 0
            WeaponSelectUI.dragVelocity = 0
        elseif WeaponSelectUI.scrollOffset > params.maxScroll then
            WeaponSelectUI.scrollOffset = params.maxScroll
            WeaponSelectUI.dragVelocity = 0
        end
        
        WeaponSelectUI.targetScrollOffset = WeaponSelectUI.scrollOffset
    else
        -- 平滑滚动到目标位置
        local diff = WeaponSelectUI.targetScrollOffset - WeaponSelectUI.scrollOffset
        if math.abs(diff) > 0.5 then
            WeaponSelectUI.scrollOffset = WeaponSelectUI.scrollOffset + diff * 0.15
        else
            WeaponSelectUI.scrollOffset = WeaponSelectUI.targetScrollOffset
        end
    end
end

-- ============================================================================
-- 输入处理
-- ============================================================================

function WeaponSelectUI.HandleInput()
    if not WeaponSelectUI.visible then return false end
    
    if input:GetKeyPress(KEY_LEFT) or input:GetKeyPress(KEY_A) then
        WeaponSelectUI.showKeyboardFocus = true  -- 键盘操作时启用导航模式
        WeaponSelectUI.selectedIndex = WeaponSelectUI.selectedIndex - 1
        if WeaponSelectUI.selectedIndex < 1 then
            WeaponSelectUI.selectedIndex = #WeaponSelectUI.weapons
        end
        return true
    end
    
    if input:GetKeyPress(KEY_RIGHT) or input:GetKeyPress(KEY_D) then
        WeaponSelectUI.showKeyboardFocus = true  -- 键盘操作时启用导航模式
        WeaponSelectUI.selectedIndex = WeaponSelectUI.selectedIndex + 1
        if WeaponSelectUI.selectedIndex > #WeaponSelectUI.weapons then
            WeaponSelectUI.selectedIndex = 1
        end
        return true
    end
    
    if input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_SPACE) then
        local weapon = WeaponSelectUI.weapons[WeaponSelectUI.selectedIndex]
        if weapon and WeaponSelectUI.onSelect then
            WeaponSelectUI.onSelect(weapon)
        end
        WeaponSelectUI.Hide()
        return true
    end
    
    if input:GetKeyPress(KEY_ESCAPE) then
        WeaponSelectUI.Hide()
        return true, "back"
    end
    
    return false
end

-- ============================================================================
-- 触摸处理（横屏）
-- ============================================================================

-- 横屏按下处理
function WeaponSelectUI.HandlePressLandscape(mx, my, uw, uh, params)
    WeaponSelectUI.showKeyboardFocus = false  -- 鼠标操作时关闭键盘导航模式
    
    -- 先检查箭头按钮
    local arrowY = params.startY + params.cardH / 2
    local arrowSize = params.baseUnit * 3
    local pageWidth = params.visibleCards * params.totalCardWidth
    
    -- 左箭头
    if mx < params.startX and 
       my > arrowY - arrowSize and my < arrowY + arrowSize then
        WeaponSelectUI.targetScrollOffset = math.max(0, 
            WeaponSelectUI.scrollOffset - pageWidth)
        WeaponSelectUI.dragVelocity = 0
        return true
    end
    
    -- 右箭头
    local rightArrowX = params.startX + params.visibleCards * params.cardW + 
                       (params.visibleCards - 1) * params.gap
    if mx > rightArrowX and
       my > arrowY - arrowSize and my < arrowY + arrowSize then
        WeaponSelectUI.targetScrollOffset = math.min(params.maxScroll, 
            WeaponSelectUI.scrollOffset + pageWidth)
        WeaponSelectUI.dragVelocity = 0
        return true
    end
    
    -- 检查是否在卡片区域（开始拖动）
    if my >= params.startY and my <= params.startY + params.cardH then
        WeaponSelectUI.isDragging = true
        WeaponSelectUI.dragStartX = mx
        WeaponSelectUI.dragStartOffset = WeaponSelectUI.scrollOffset
        WeaponSelectUI.lastDragX = mx
        WeaponSelectUI.dragVelocity = 0
    end
    
    -- 确认按钮按下
    local btnW = uw * 0.2
    local btnH = uh * 0.06
    local btnX = (uw - btnW) / 2
    local btnY = uh * 0.88
    
    if UIScreen.CheckButtonPress(mx, my, "weapon_confirm", btnX, btnY, btnW, btnH) then
        return true
    end
    
    return false
end

-- 横屏拖动处理
function WeaponSelectUI.HandleDragLandscape(mx, my, uw, uh, params)
    if WeaponSelectUI.isDragging and input:GetMouseButtonDown(MOUSEB_LEFT) then
        local deltaX = mx - WeaponSelectUI.lastDragX
        WeaponSelectUI.dragVelocity = deltaX / 0.016
        WeaponSelectUI.lastDragX = mx
        
        local totalDrag = WeaponSelectUI.dragStartX - mx
        WeaponSelectUI.scrollOffset = WeaponSelectUI.dragStartOffset + totalDrag
        
        local elastic = params.cardW * 0.3
        WeaponSelectUI.scrollOffset = math.max(-elastic, 
            math.min(params.maxScroll + elastic, WeaponSelectUI.scrollOffset))
        WeaponSelectUI.targetScrollOffset = WeaponSelectUI.scrollOffset
    end
    return false
end

-- 横屏释放处理
function WeaponSelectUI.HandleReleaseLandscape(mx, my, uw, uh, params)
    -- 确认按钮释放
    if UIScreen.CheckButtonRelease(mx, my, "weapon_confirm") then
        local weapon = WeaponSelectUI.weapons[WeaponSelectUI.selectedIndex]
        if weapon and WeaponSelectUI.onSelect then
            WeaponSelectUI.onSelect(weapon)
        end
        WeaponSelectUI.Hide()
        return true
    end
    
    -- 拖动结束
    if WeaponSelectUI.isDragging then
        WeaponSelectUI.isDragging = false
        
        if WeaponSelectUI.scrollOffset < 0 then
            WeaponSelectUI.targetScrollOffset = 0
            WeaponSelectUI.dragVelocity = 0
        elseif WeaponSelectUI.scrollOffset > params.maxScroll then
            WeaponSelectUI.targetScrollOffset = params.maxScroll
            WeaponSelectUI.dragVelocity = 0
        else
            WeaponSelectUI.targetScrollOffset = WeaponSelectUI.scrollOffset
        end
        
        -- 如果拖动距离很小，视为点击选择
        local totalDrag = math.abs(WeaponSelectUI.dragStartX - mx)
        if totalDrag < 10 then
            local clickX = mx + WeaponSelectUI.scrollOffset - params.startX
            local clickedIndex = math.floor(clickX / params.totalCardWidth) + 1
            if clickedIndex >= 1 and clickedIndex <= #WeaponSelectUI.weapons then
                WeaponSelectUI.selectedIndex = clickedIndex
            end
        end
    end
    
    return false
end

-- ============================================================================
-- 触摸处理（竖屏）
-- ============================================================================

-- 竖屏按下处理
function WeaponSelectUI.HandlePressPortrait(mx, my, uw, uh, params)
    WeaponSelectUI.showKeyboardFocus = false  -- 触摸操作时关闭键盘导航模式
    
    -- 检查是否在内容区域（开始拖动）
    if my >= params.startY and my <= params.startY + params.contentHeight then
        WeaponSelectUI.isDragging = true
        WeaponSelectUI.dragStartY = my
        WeaponSelectUI.dragStartOffset = WeaponSelectUI.scrollOffset
        WeaponSelectUI.lastDragY = my
        WeaponSelectUI.dragVelocity = 0
    end
    
    -- 确认按钮按下
    local btnW = uw * 0.6
    local btnH = uh * 0.065
    local btnX = (uw - btnW) / 2
    local btnY = uh * 0.87
    
    if UIScreen.CheckButtonPress(mx, my, "weapon_confirm_portrait", btnX, btnY, btnW, btnH) then
        return true
    end
    
    return false
end

-- 竖屏拖动处理
function WeaponSelectUI.HandleDragPortrait(mx, my, uw, uh, params)
    if WeaponSelectUI.isDragging and input:GetMouseButtonDown(MOUSEB_LEFT) then
        local deltaY = my - WeaponSelectUI.lastDragY
        WeaponSelectUI.dragVelocity = -deltaY / 0.016  -- 负号：向上滑动增加offset
        WeaponSelectUI.lastDragY = my
        
        local totalDrag = WeaponSelectUI.dragStartY - my
        WeaponSelectUI.scrollOffset = WeaponSelectUI.dragStartOffset + totalDrag
        
        local elastic = params.cardH * 0.3
        WeaponSelectUI.scrollOffset = math.max(-elastic, 
            math.min(params.maxScroll + elastic, WeaponSelectUI.scrollOffset))
        WeaponSelectUI.targetScrollOffset = WeaponSelectUI.scrollOffset
    end
    return false
end

-- 竖屏释放处理
function WeaponSelectUI.HandleReleasePortrait(mx, my, uw, uh, params)
    -- 确认按钮释放
    if UIScreen.CheckButtonRelease(mx, my, "weapon_confirm_portrait") then
        local weapon = WeaponSelectUI.weapons[WeaponSelectUI.selectedIndex]
        if weapon and WeaponSelectUI.onSelect then
            WeaponSelectUI.onSelect(weapon)
        end
        WeaponSelectUI.Hide()
        return true
    end
    
    -- 拖动结束
    if WeaponSelectUI.isDragging then
        WeaponSelectUI.isDragging = false
        
        if WeaponSelectUI.scrollOffset < 0 then
            WeaponSelectUI.targetScrollOffset = 0
            WeaponSelectUI.dragVelocity = 0
        elseif WeaponSelectUI.scrollOffset > params.maxScroll then
            WeaponSelectUI.targetScrollOffset = params.maxScroll
            WeaponSelectUI.dragVelocity = 0
        else
            WeaponSelectUI.targetScrollOffset = WeaponSelectUI.scrollOffset
        end
        
        -- 如果拖动距离很小，视为点击选择
        local totalDrag = math.abs(WeaponSelectUI.dragStartY - my)
        if totalDrag < 10 then
            -- 计算点击的卡片
            local clickY = my + WeaponSelectUI.scrollOffset - params.startY
            local clickX = mx - params.startX
            
            local col = math.floor(clickX / (params.cardW + params.gapX))
            local row = math.floor(clickY / (params.cardH + params.gapY))
            
            if col >= 0 and col < params.columns then
                local clickedIndex = row * params.columns + col + 1
                if clickedIndex >= 1 and clickedIndex <= #WeaponSelectUI.weapons then
                    WeaponSelectUI.selectedIndex = clickedIndex
                end
            end
        end
    end
    
    return false
end

-- ============================================================================
-- 统一触摸处理入口
-- ============================================================================

function WeaponSelectUI.HandleTouch(sw, sh)
    if not WeaponSelectUI.visible then return false end
    
    -- 区分按下和释放
    if UIScreen.IsMousePressed() then
        return UIScreen.HandleTouch(sw, sh, WeaponSelectUI, WeaponSelectUI.OnPress)
    elseif UIScreen.IsMouseReleased() then
        return UIScreen.HandleTouch(sw, sh, WeaponSelectUI, WeaponSelectUI.OnRelease)
    else
        -- 拖动中也需要处理
        return UIScreen.HandleTouch(sw, sh, WeaponSelectUI, WeaponSelectUI.OnDrag)
    end
end

-- 按下事件处理（设置按钮状态）
function WeaponSelectUI.OnPress(mx, my, uw, uh, safe)
    local baseUnit = safe.baseUnit
    local params = WeaponSelectUI.GetLayoutParams(uw, uh)
    params.safe = safe
    params.baseUnit = baseUnit
    
    -- 返回按钮按下（使用 UIStyle 统一布局）
    local backLayout = UIStyle.GetBackButtonLayout(baseUnit)
    if UIScreen.CheckButtonPress(mx, my, "weapon_back", backLayout.x, backLayout.y - backLayout.h/2, backLayout.w, backLayout.h) then
        return true
    end
    
    if params.isPortrait then
        return WeaponSelectUI.HandlePressPortrait(mx, my, uw, uh, params)
    else
        return WeaponSelectUI.HandlePressLandscape(mx, my, uw, uh, params)
    end
end

-- 释放事件处理（触发回调）
function WeaponSelectUI.OnRelease(mx, my, uw, uh, safe)
    local baseUnit = safe.baseUnit
    local params = WeaponSelectUI.GetLayoutParams(uw, uh)
    params.safe = safe
    params.baseUnit = baseUnit
    
    -- 返回按钮释放
    if UIScreen.CheckButtonRelease(mx, my, "weapon_back") then
        return true, "back"
    end
    
    if params.isPortrait then
        return WeaponSelectUI.HandleReleasePortrait(mx, my, uw, uh, params)
    else
        return WeaponSelectUI.HandleReleaseLandscape(mx, my, uw, uh, params)
    end
end

-- 拖动事件处理
function WeaponSelectUI.OnDrag(mx, my, uw, uh, safe)
    local baseUnit = safe.baseUnit
    local params = WeaponSelectUI.GetLayoutParams(uw, uh)
    params.safe = safe
    params.baseUnit = baseUnit
    
    if params.isPortrait then
        return WeaponSelectUI.HandleDragPortrait(mx, my, uw, uh, params)
    else
        return WeaponSelectUI.HandleDragLandscape(mx, my, uw, uh, params)
    end
end

-- ============================================================================
-- 渲染（横屏）
-- ============================================================================

function WeaponSelectUI.RenderLandscape(nvg, sw, sh, params)
    -- 更新滚动
    WeaponSelectUI.UpdateScroll(0.016, params)
    local fonts = params.fonts
    
    -- 裁剪区域（武器卡片）
    nvgSave(nvg)
    nvgScissor(nvg, params.startX - params.gap, params.startY - params.baseUnit, 
               params.cardW * params.visibleCards + params.gap * (params.visibleCards + 1),
               params.cardH + params.baseUnit * 2)
    
    -- 渲染武器卡片
    for i, weapon in ipairs(WeaponSelectUI.weapons) do
        local cardX = params.startX + (i - 1) * params.totalCardWidth - WeaponSelectUI.scrollOffset
        
        if cardX > -params.cardW and cardX < sw then
            local isSelected = (i == WeaponSelectUI.selectedIndex)
            local isRecommended = WeaponSelectUI.selectedShip and 
                                  weapon.id == WeaponSelectUI.selectedShip.initialWeapon
            
            local scale = isSelected and 1.0 or 0.92
            local scaledW = params.cardW * scale
            local scaledH = params.cardH * scale
            local offsetX = (params.cardW - scaledW) / 2
            local offsetY = (params.cardH - scaledH) / 2
            
            WeaponSelectUI.RenderWeaponCard(nvg, 
                cardX + offsetX, params.startY + offsetY, 
                scaledW, scaledH, 
                weapon, isSelected, isRecommended, params.baseUnit, i, false, fonts)
        end
    end
    
    nvgRestore(nvg)
    
    -- 左右箭头
    WeaponSelectUI.DrawScrollArrowsLandscape(nvg, sw, sh, params)
    
    -- 滚动指示器（点点）
    WeaponSelectUI.DrawScrollIndicatorLandscape(nvg, sw, sh, params)
    
    -- 确认按钮
    local btnW = sw * 0.2
    local btnH = sh * 0.06
    local btnX = (sw - btnW) / 2
    local btnY = sh * 0.88
    
    -- 检查按钮是否被按下
    local mx, my = UIScreen.GetLocalMouse(WeaponSelectUI, sw, sh)
    local confirmPressed = mx and my and UIScreen.ShouldShowPressed(mx, my, "weapon_confirm")
    
    UIStyle.DrawSciFiButton(nvg, btnX, btnY, btnW, btnH, "确认选择", {
        baseUnit = params.baseUnit,
        animTime = WeaponSelectUI.animTime,
        variant = "success",
        fontSize = fonts.buttonText,
        pressed = confirmPressed,
    })
end

-- ============================================================================
-- 渲染（竖屏）
-- ============================================================================

function WeaponSelectUI.RenderPortrait(nvg, sw, sh, params)
    -- 更新滚动
    WeaponSelectUI.UpdateScroll(0.016, params)
    local fonts = params.fonts
    
    -- 裁剪区域
    nvgSave(nvg)
    nvgScissor(nvg, 0, params.startY, sw, params.contentHeight)
    
    -- 渲染武器卡片（网格布局）
    for i, weapon in ipairs(WeaponSelectUI.weapons) do
        local col = (i - 1) % params.columns
        local row = math.floor((i - 1) / params.columns)
        
        local cardX = params.startX + col * (params.cardW + params.gapX)
        local cardY = params.startY + row * (params.cardH + params.gapY) - WeaponSelectUI.scrollOffset
        
        -- 只渲染可见的卡片
        if cardY + params.cardH > params.startY - params.cardH and 
           cardY < params.startY + params.contentHeight + params.cardH then
            local isSelected = (i == WeaponSelectUI.selectedIndex)
            local isRecommended = WeaponSelectUI.selectedShip and 
                                  weapon.id == WeaponSelectUI.selectedShip.initialWeapon
            
            WeaponSelectUI.RenderWeaponCard(nvg, 
                cardX, cardY, 
                params.cardW, params.cardH, 
                weapon, isSelected, isRecommended, params.baseUnit, i, true, fonts)
        end
    end
    
    nvgRestore(nvg)
    
    -- 滚动条（竖屏）
    WeaponSelectUI.DrawScrollBarPortrait(nvg, sw, sh, params)
    
    -- 确认按钮（竖屏更宽）
    local btnW = sw * 0.6
    local btnH = sh * 0.065
    local btnX = (sw - btnW) / 2
    local btnY = sh * 0.87
    
    -- 检查按钮是否被按下
    local mx, my = UIScreen.GetLocalMouse(WeaponSelectUI, sw, sh)
    local confirmPressed = mx and my and UIScreen.ShouldShowPressed(mx, my, "weapon_confirm_portrait")
    
    UIStyle.DrawSciFiButton(nvg, btnX, btnY, btnW, btnH, "确认选择", {
        baseUnit = params.baseUnit,
        animTime = WeaponSelectUI.animTime,
        variant = "success",
        fontSize = fonts.buttonText,
        pressed = confirmPressed,
    })
end

-- ============================================================================
-- 主渲染函数
-- ============================================================================

-- 缓存安全区信息（用于输入处理）
WeaponSelectUI.safeArea = nil

function WeaponSelectUI.Render(nvg, sw, sh)
    if not WeaponSelectUI.visible then return end
    
    -- 更新动画时间
    WeaponSelectUI.animTime = WeaponSelectUI.animTime + 0.016
    
    -- 使用 UIScreen 标准渲染流程
    UIScreen.Render(nvg, sw, sh, WeaponSelectUI, {
        drawBackground = WeaponSelectUI.DrawFullscreenBackground,
        drawContent = WeaponSelectUI.DrawContent,
        useMask = false,  -- 武器选择背景全屏显示，不绘制遮罩
    })
end

--- 全屏背景绘制
function WeaponSelectUI.DrawFullscreenBackground(nvg, sw, sh, baseUnit)
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(10, 16, 28, 250))
    nvgFill(nvg)
end

--- 安全区内容绘制
function WeaponSelectUI.DrawContent(nvg, uw, uh, baseUnit, fonts, safe)
    local params = WeaponSelectUI.GetLayoutParams(uw, uh)
    params.fonts = fonts  -- 传递给子渲染函数
    
    -- 获取鼠标位置检测按下状态
    local mx, my = UIScreen.GetLocalMouse(WeaponSelectUI, uw, uh)
    local backPressed = mx and my and UIScreen.ShouldShowPressed(mx, my, "weapon_back")
    
    -- 返回按钮（使用统一组件）
    UIStyle.DrawBackButton(nvg, baseUnit, fonts.buttonText * 0.9, backPressed)
    
    -- 装饰电路
    WeaponSelectUI.DrawCircuitDecor(nvg, uw, uh, params.baseUnit)
    
    -- 标题（使用统一字体规范）
    nvgFontSize(nvg, fonts.pageTitle)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    
    -- 根据是否有初始武器显示不同标题
    local hasInitialWeapon = WeaponSelectUI.selectedShip and WeaponSelectUI.selectedShip.initialWeapon
    local title = hasInitialWeapon and "选择额外武器" or "选择武器"
    nvgText(nvg, uw / 2, uh * 0.03, title)
    
    -- 武器数量指示器
    nvgFontSize(nvg, fonts.cardTitle)
    nvgFillColor(nvg, nvgRGBA(255, 200, 60, 255))
    nvgText(nvg, uw / 2, uh * (params.isPortrait and 0.11 or 0.14), 
            WeaponSelectUI.selectedIndex .. " / " .. #WeaponSelectUI.weapons)
    
    -- 根据屏幕方向渲染
    if params.isPortrait then
        WeaponSelectUI.RenderPortrait(nvg, uw, uh, params)
    else
        WeaponSelectUI.RenderLandscape(nvg, uw, uh, params)
    end
end

-- ============================================================================
-- 滚动箭头（横屏）
-- ============================================================================

function WeaponSelectUI.DrawScrollArrowsLandscape(nvg, sw, sh, params)
    local arrowY = params.startY + params.cardH / 2
    local arrowSize = params.baseUnit * 2
    
    -- 左箭头
    if WeaponSelectUI.scrollOffset > 5 then
        local leftX = params.startX - arrowSize * 2
        
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, leftX + arrowSize, arrowY - arrowSize)
        nvgLineTo(nvg, leftX, arrowY)
        nvgLineTo(nvg, leftX + arrowSize, arrowY + arrowSize)
        nvgStrokeColor(nvg, nvgRGBA(100, 180, 255, 200))
        nvgStrokeWidth(nvg, 3)
        nvgStroke(nvg)
    end
    
    -- 右箭头
    if WeaponSelectUI.scrollOffset < params.maxScroll - 5 then
        local rightX = params.startX + params.visibleCards * params.cardW + 
                      (params.visibleCards - 1) * params.gap + arrowSize
        
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, rightX, arrowY - arrowSize)
        nvgLineTo(nvg, rightX + arrowSize, arrowY)
        nvgLineTo(nvg, rightX, arrowY + arrowSize)
        nvgStrokeColor(nvg, nvgRGBA(100, 180, 255, 200))
        nvgStrokeWidth(nvg, 3)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- 滚动指示器（横屏 - 点点）
-- ============================================================================

function WeaponSelectUI.DrawScrollIndicatorLandscape(nvg, sw, sh, params)
    local dotY = params.startY + params.cardH + params.baseUnit * 1.5
    local dotRadius = params.baseUnit * 0.3
    local dotGap = params.baseUnit * 1.2
    local totalDots = #WeaponSelectUI.weapons
    local totalWidth = (totalDots - 1) * dotGap
    local startDotX = (sw - totalWidth) / 2
    
    for i = 1, totalDots do
        local dotX = startDotX + (i - 1) * dotGap
        local isActive = (i == WeaponSelectUI.selectedIndex)
        
        nvgBeginPath(nvg)
        nvgCircle(nvg, dotX, dotY, isActive and dotRadius * 1.5 or dotRadius)
        
        if isActive then
            nvgFillColor(nvg, nvgRGBA(100, 200, 255, 255))
        else
            nvgFillColor(nvg, nvgRGBA(60, 80, 100, 180))
        end
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 滚动条（竖屏）
-- ============================================================================

function WeaponSelectUI.DrawScrollBarPortrait(nvg, sw, sh, params)
    if params.maxScroll <= 0 then return end
    
    local barX = sw - params.baseUnit * 0.8
    local barY = params.startY
    local barH = params.contentHeight
    local barW = params.baseUnit * 0.3
    
    -- 背景轨道
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX, barY, barW, barH, barW / 2)
    nvgFillColor(nvg, nvgRGBA(40, 50, 60, 100))
    nvgFill(nvg)
    
    -- 滑块
    local thumbRatio = params.contentHeight / params.totalContentHeight
    local thumbH = math.max(barH * thumbRatio, params.baseUnit * 2)
    local scrollRatio = WeaponSelectUI.scrollOffset / params.maxScroll
    local thumbY = barY + (barH - thumbH) * scrollRatio
    
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX, thumbY, barW, thumbH, barW / 2)
    nvgFillColor(nvg, nvgRGBA(100, 180, 255, 180))
    nvgFill(nvg)
end

-- ============================================================================
-- 装饰电路
-- ============================================================================

function WeaponSelectUI.DrawCircuitDecor(nvg, sw, sh, baseUnit)
    local lineColor = nvgRGBA(40, 70, 100, 80)
    local nodeColor = nvgRGBA(60, 120, 180, 100)
    
    nvgStrokeColor(nvg, lineColor)
    nvgStrokeWidth(nvg, 1)
    
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sw * 0.05, sh * 0.15)
    nvgLineTo(nvg, sw * 0.95, sh * 0.15)
    nvgStroke(nvg)
    
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, sw * 0.05, sh * 0.84)
    nvgLineTo(nvg, sw * 0.95, sh * 0.84)
    nvgStroke(nvg)
    
    local corners = {
        {sw * 0.05, sh * 0.15},
        {sw * 0.95, sh * 0.15},
        {sw * 0.05, sh * 0.84},
        {sw * 0.95, sh * 0.84},
    }
    
    for _, c in ipairs(corners) do
        nvgBeginPath(nvg)
        nvgCircle(nvg, c[1], c[2], 3)
        nvgFillColor(nvg, nodeColor)
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 武器卡片渲染
-- ============================================================================

function WeaponSelectUI.RenderWeaponCard(nvg, x, y, w, h, weapon, isSelected, isRecommended, baseUnit, index, isPortrait, fonts)
    local typeColor = WeaponSelectUI.TypeColors[weapon.type] or {r = 100, g = 150, b = 200}
    local tier = weapon.tier or 1
    local tierColor = WeaponSelectUI.TierColors[tier] or WeaponSelectUI.TierColors[1]
    
    -- 使用统一字体规范，但缩小以适应卡片
    fonts = fonts or UIStyle.GetTypography(w * 2, isPortrait and w * 3 or h * 2)
    local scaleFactor = 0.85  -- 全局字体缩小系数
    
    -- 选中时的外发光
    if isSelected then
        local glowAlpha = 0.3 + 0.15 * math.sin(WeaponSelectUI.animTime * 3)
        for i = 3, 1, -1 do
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, x - i * 2, y - i * 2, w + i * 4, h + i * 4, baseUnit * 0.4 + i)
            nvgFillColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, glowAlpha * 255 / i))
            nvgFill(nvg)
        end
    end
    
    -- 卡片背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.4)
    nvgFillColor(nvg, nvgRGBA(18, 25, 40, isSelected and 255 or 220))
    nvgFill(nvg)
    
    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.4)
    nvgStrokeColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, isSelected and 255 or 120))
    nvgStrokeWidth(nvg, isSelected and 2 or 1.5)
    nvgStroke(nvg)
    
    -- 效果类型标签（顶部，紧凑布局）
    local effectLabels = WeaponSelectUI.GetEffectLabels(weapon)
    if #effectLabels > 0 then
        local tagFontSize = fonts.tagText * 0.72 * scaleFactor
        local tagH = tagFontSize * 1.2
        local tagGap = baseUnit * 0.12
        local tagY = y + baseUnit * 0.2
        local startX = x + baseUnit * 0.2
        local maxX = x + w - baseUnit * 0.2
        local currentX = startX
        
        for i, label in ipairs(effectLabels) do
            local charCount = #label / 3
            local tagW = tagFontSize * (charCount + 0.8)
            
            if currentX + tagW > maxX then break end
            
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, currentX, tagY, tagW, tagH, baseUnit * 0.1)
            nvgFillColor(nvg, nvgRGBA(typeColor.r, typeColor.g, typeColor.b, 50))
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(typeColor.r, typeColor.g, typeColor.b, 150))
            nvgStrokeWidth(nvg, 1)
            nvgStroke(nvg)
            
            nvgFontSize(nvg, tagFontSize * 0.9)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(typeColor.r, typeColor.g, typeColor.b, 255))
            nvgText(nvg, currentX + tagW / 2, tagY + tagH / 2, label)
            
            currentX = currentX + tagW + tagGap
        end
    end
    
    -- 内容起始位置
    local py = y + baseUnit * 1.6
    local cx = x + w / 2
    
    -- 武器图标（放大50%后再放大50%）
    local iconSize = baseUnit * 4.5
    local iconX = cx - iconSize / 2
    local iconY = py
    
    -- 尝试加载武器图标
    local hasIcon = false
    local iconPath = "images/weapons/" .. weapon.id .. ".jpg"
    
    local img = ImageLoader.GetImage(nvg, iconPath, WeaponSelectUI.weaponImages, weapon.id)
    if img and img > 0 then
        hasIcon = true
        -- 绘制图标背景（轻微透明）
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.25)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 80))
        nvgFill(nvg)
        
        -- 绘制武器图标
        local imgPaint = nvgImagePattern(nvg, iconX, iconY, iconSize, iconSize, 0, img, 1.0)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, iconX, iconY, iconSize, iconSize, baseUnit * 0.25)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)
    end
    
    -- 没有图标时显示骨架屏占位
    if not hasIcon then
        ImageLoader.RenderPlaceholder(nvg, iconX, iconY, iconSize, iconSize, WeaponSelectUI.animTime, baseUnit * 0.25)
    end
    py = py + iconSize + baseUnit * 0.5
    
    -- 武器名称
    nvgFontSize(nvg, fonts.cardTitle * scaleFactor)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, isSelected and 255 or 200))
    nvgText(nvg, cx, py, weapon.name)
    py = py + fonts.cardTitle * scaleFactor * 1.1
    
    -- 武器类型 + Tier
    local tierNames = {"T1", "T2", "T3", "T4"}
    local tierName = tierNames[tier] or "T1"
    local typeName = WeaponSelectUI.GetTypeName(weapon.type)
    local typeAndTier = typeName .. " · " .. tierName
    
    nvgFontSize(nvg, fonts.cardSubtitle * scaleFactor * 0.9)
    nvgFillColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 220))
    nvgText(nvg, cx, py, typeAndTier)
    py = py + fonts.cardSubtitle * scaleFactor * 1.1
    
    -- 属性（更紧凑）
    local statFontSize = fonts.statValue * scaleFactor * 0.9
    nvgFontSize(nvg, statFontSize)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local statLineHeight = statFontSize * 1.25
    
    -- 伤害
    nvgFillColor(nvg, nvgRGBA(255, 100, 100, 255))
    nvgText(nvg, x + baseUnit * 0.4, py, "伤害: " .. weapon.damage)
    py = py + statLineHeight
    
    -- 攻速
    local attackSpeed = string.format("%.1f", 1.0 / weapon.cooldown)
    nvgFillColor(nvg, nvgRGBA(100, 200, 255, 255))
    nvgText(nvg, x + baseUnit * 0.4, py, "攻速: " .. attackSpeed .. "/s")
    py = py + statLineHeight
    
    -- 射程
    local rangeCategory, rangeLabel = WeaponSelectUI.GetRangeCategory(weapon.range)
    local rangeColor = WeaponSelectUI.RangeColors[rangeCategory]
    nvgFillColor(nvg, nvgRGBA(rangeColor.r, rangeColor.g, rangeColor.b, 255))
    nvgText(nvg, x + baseUnit * 0.4, py, "射程: " .. rangeLabel)
    py = py + statLineHeight
    
    -- 描述（底部，居中，最多2行）
    local descFontSize = fonts.description * scaleFactor * 0.75
    nvgFontSize(nvg, descFontSize)
    nvgFillColor(nvg, nvgRGBA(150, 160, 180, 200))
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    
    local desc = weapon.description or ""
    -- 中文字符宽度约等于字体大小
    local maxCharsPerLine = math.floor((w - baseUnit * 1.0) / descFontSize)
    local lines = WeaponSelectUI.WrapText(desc, maxCharsPerLine, 2)
    local descLineH = descFontSize * 1.25
    
    for lineIdx, line in ipairs(lines) do
        nvgText(nvg, cx, py + (lineIdx - 1) * descLineH, line)
    end
end

-- 文本换行辅助函数（按UTF-8字符数分行）
function WeaponSelectUI.WrapText(text, maxCharsPerLine, maxLines)
    local lines = {}
    local currentLine = ""
    local currentCount = 0
    local i = 1
    
    while i <= #text do
        local byte = string.byte(text, i)
        local charLen = 1
        if byte >= 0xF0 then charLen = 4
        elseif byte >= 0xE0 then charLen = 3
        elseif byte >= 0xC0 then charLen = 2 end
        
        local char = string.sub(text, i, i + charLen - 1)
        
        if currentCount >= maxCharsPerLine then
            -- 当前行满了，换行
            table.insert(lines, currentLine)
            currentLine = char
            currentCount = 1
            
            if #lines >= maxLines then
                -- 达到最大行数，截断最后一行
                if i + charLen <= #text then
                    lines[#lines] = string.sub(lines[#lines], 1, -4) .. "…"
                end
                return lines
            end
        else
            currentLine = currentLine .. char
            currentCount = currentCount + 1
        end
        
        i = i + charLen
    end
    
    -- 添加最后一行
    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end
    
    return lines
end

function WeaponSelectUI.GetTypeName(weaponType)
    -- 委托给 Weapons 模块的统一函数（避免重复定义映射）
    return Weapons.GetTypeName(weaponType)
end

function WeaponSelectUI.GetRangeCategory(range)
    -- 使用 Weapons 模块的统一阈值
    local thresholds = Weapons.RangeThresholds
    if range <= thresholds.close then
        return "close", "近程"
    elseif range <= thresholds.medium then
        return "medium", "中程"
    else
        return "long", "远程"
    end
end

return WeaponSelectUI
