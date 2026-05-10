-- ============================================================================
-- 星河战姬 Starkyries - 舰桥升级系统
-- 负责升级状态管理、选项生成、刷新逻辑
-- ============================================================================

local Settings = require("config.settings")
local Modules = require("config.modules")

local BridgeUpgrade = {}

-- ============================================================================
-- 状态
-- ============================================================================
BridgeUpgrade.state = {
    active = false,
    options = {},
    selectedIndex = 1,
    refreshCount = 0,
}

-- 当前波次（用于跟踪波次变化以重置刷新计数）
BridgeUpgrade.lastWaveForUpgrade = 0

-- 回调
BridgeUpgrade.onComplete = nil      -- function(hasMore) 升级完成回调
BridgeUpgrade.onRefresh = nil       -- function() 刷新完成回调
BridgeUpgrade.getPlayer = nil       -- function() return player
BridgeUpgrade.getCurrentWave = nil  -- function() return waveNum
BridgeUpgrade.spendCrystals = nil   -- function(amount) return success
BridgeUpgrade.playUpgradeSound = nil    -- function()
BridgeUpgrade.playClickSound = nil      -- function()

-- ============================================================================
-- 初始化
-- ============================================================================

function BridgeUpgrade.Init()
    BridgeUpgrade.state = {
        active = false,
        options = {},
        selectedIndex = 1,
        refreshCount = 0,
    }
    BridgeUpgrade.lastWaveForUpgrade = 0
end

-- ============================================================================
-- 升级刷新费用计算
-- 公式与商店相同：首次 = floor(阶段×0.75) + floor(阶段×0.40)
-- 每次递增 = floor(阶段×0.40)
-- ============================================================================

function BridgeUpgrade.CalculateRefreshCost(waveNum, refreshCount)
    local baseCost = math.floor(waveNum * 0.75) + math.floor(waveNum * 0.40)
    local increment = math.max(1, math.floor(waveNum * 0.40))
    local cost = baseCost + refreshCount * increment
    return math.max(1, cost)
end

function BridgeUpgrade.GetRefreshCost()
    local waveNum = 1
    if BridgeUpgrade.getCurrentWave then
        waveNum = BridgeUpgrade.getCurrentWave()
    end
    return BridgeUpgrade.CalculateRefreshCost(waveNum, BridgeUpgrade.state.refreshCount)
end

-- ============================================================================
-- 开始升级UI
-- ============================================================================

function BridgeUpgrade.Start(Game)
    Game.StartBridgeUpgrade()
    
    BridgeUpgrade.state.active = true
    BridgeUpgrade.state.selectedIndex = 1
    
    -- 检查波次变化，重置刷新计数（同波次多次升级共享计数）
    local currentWave = 1
    if BridgeUpgrade.getCurrentWave then
        currentWave = BridgeUpgrade.getCurrentWave()
    end
    
    if currentWave ~= BridgeUpgrade.lastWaveForUpgrade then
        BridgeUpgrade.state.refreshCount = 0
        BridgeUpgrade.lastWaveForUpgrade = currentWave
    end
    
    -- 使用品质系统生成升级选项
    local player = nil
    if BridgeUpgrade.getPlayer then
        player = BridgeUpgrade.getPlayer()
    end
    
    local playerLevel = (player and player.bridgeLevel or 0) + 1
    local luck = player and player.luck or 0
    
    BridgeUpgrade.state.options = Modules.GetRandomBridgeUpgrades(4, playerLevel, luck)
end

-- ============================================================================
-- 选择升级选项
-- ============================================================================

function BridgeUpgrade.Select(index, Game)
    local option = BridgeUpgrade.state.options[index]
    if not option then return false end
    
    local player = nil
    if BridgeUpgrade.getPlayer then
        player = BridgeUpgrade.getPlayer()
    end
    
    if option.effect and player then
        option.effect(player)
        -- 播放升级音效
        if BridgeUpgrade.playUpgradeSound then
            BridgeUpgrade.playUpgradeSound()
        end
    end
    
    -- 完成这次升级，检查是否还有更多
    local hasMore = Game.CompleteBridgeUpgrade()
    
    if hasMore then
        -- 还有更多升级，刷新选项
        BridgeUpgrade.Start(Game)
        return true
    else
        -- 所有升级完成
        BridgeUpgrade.state.active = false
        BridgeUpgrade.state.options = {}
        
        if BridgeUpgrade.onComplete then
            BridgeUpgrade.onComplete(false)
        end
        return false
    end
end

-- ============================================================================
-- 刷新升级选项
-- ============================================================================

function BridgeUpgrade.Refresh()
    if not BridgeUpgrade.state.active then 
        return false, "未在升级状态" 
    end
    
    local cost = BridgeUpgrade.GetRefreshCost()
    
    local player = nil
    if BridgeUpgrade.getPlayer then
        player = BridgeUpgrade.getPlayer()
    end
    
    if not player or player.crystals < cost then
        return false, "晶体不足（需要" .. cost .. "）"
    end
    
    -- 扣除晶体
    if BridgeUpgrade.spendCrystals and BridgeUpgrade.spendCrystals(cost) then
        BridgeUpgrade.state.refreshCount = BridgeUpgrade.state.refreshCount + 1
        
        -- 重新生成选项
        local playerLevel = player.bridgeLevel + 1
        local luck = player.luck or 0
        BridgeUpgrade.state.options = Modules.GetRandomBridgeUpgrades(4, playerLevel, luck)
        
        -- 播放刷新音效
        if BridgeUpgrade.playClickSound then
            BridgeUpgrade.playClickSound()
        end
        
        if BridgeUpgrade.onRefresh then
            BridgeUpgrade.onRefresh()
        end
        
        return true, "刷新成功"
    end
    
    return false, "刷新失败"
end

-- ============================================================================
-- 状态获取
-- ============================================================================

function BridgeUpgrade.GetState()
    return BridgeUpgrade.state
end

function BridgeUpgrade.IsActive()
    return BridgeUpgrade.state.active
end

function BridgeUpgrade.GetOptions()
    return BridgeUpgrade.state.options
end

function BridgeUpgrade.GetSelectedIndex()
    return BridgeUpgrade.state.selectedIndex
end

function BridgeUpgrade.SetSelectedIndex(index)
    if index >= 1 and index <= #BridgeUpgrade.state.options then
        BridgeUpgrade.state.selectedIndex = index
    end
end

-- ============================================================================
-- 导航
-- ============================================================================

function BridgeUpgrade.SelectNext()
    local state = BridgeUpgrade.state
    state.selectedIndex = state.selectedIndex + 1
    if state.selectedIndex > #state.options then
        state.selectedIndex = 1
    end
end

function BridgeUpgrade.SelectPrev()
    local state = BridgeUpgrade.state
    state.selectedIndex = state.selectedIndex - 1
    if state.selectedIndex < 1 then
        state.selectedIndex = #state.options
    end
end

return BridgeUpgrade
