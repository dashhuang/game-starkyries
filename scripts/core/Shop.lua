-- ============================================================================
-- 星河战姬 Starkyries - 商店系统（补给站）
-- 完整实现文档设计：Wiki公式、武器保底、匹配池、品质系统、锁定功能
-- ============================================================================

local Settings = require("config.settings")
local Weapons = require("config.weapons")
local Modules = require("config.modules")
local Ships = require("config.ships")
local Math = require("utils.Math")
local Player = require("entities.Player")

local Shop = {}

-- ============================================================================
-- 标签匹配系统
-- 与战舰/已有模块标签匹配的模块有 +5% 出现概率
-- ============================================================================
Shop.TagMatchBonus = Settings.Shop.TagMatchBonus  -- 标签匹配加成

-- ============================================================================
-- 商店状态
-- ============================================================================
Shop.items = {}              -- 当前商品列表
Shop.lockedItems = {}        -- 锁定的商品（跨阶段保留）
Shop.selectedIndex = 1
Shop.refreshCount = 0        -- 当前阶段刷新次数
Shop.currentWave = 1         -- 当前阶段

-- 回调
Shop.getPlayer = nil           -- function() return player
Shop.onPurchaseWeapon = nil    -- function(weaponId, tier) 
Shop.onPurchaseModule = nil    -- function(moduleId)
Shop.onSpendCrystals = nil     -- function(amount) return success

-- ============================================================================
-- 常量配置（对标Brotato Wiki）
-- ============================================================================
Shop.Config = {
    ItemCount = 4,              -- 商店物品数量
    WeaponRatio = 0.35,         -- 武器出现概率 35%
    ModuleRatio = 0.65,         -- 模块出现概率 65%
    
    -- 武器匹配池概率
    SameWeaponPoolChance = 0.20,   -- 同武器池 20%（已装备的相同武器）
    SameTypePoolChance = 0.15,     -- 同类型池 15%（已装备武器的同类型）
    AllWeaponPoolChance = 0.65,    -- 全武器池 65%（随机）
    
    -- 品质参数
    Quality = {
        -- T1 标准型
        T1 = { minWave = 0, baseChance = 1.0, perWaveIncrease = 0, maxChance = 1.0 },
        -- T2 改良型
        T2 = { minWave = 1, baseChance = 0.20, perWaveIncrease = 0.03, maxChance = 1.0 },
        -- T3 精英型
        T3 = { minWave = 3, baseChance = 0.08, perWaveIncrease = 0.02, maxChance = 0.60 },
        -- T4 旗舰型
        T4 = { minWave = 8, baseChance = 0.04, perWaveIncrease = 0.01, maxChance = 0.25 },
    },
    
    -- 前5阶段武器保底
    WeaponGuarantee = {
        [1] = 2,  -- 阶段1：固定2把武器
        [2] = 2,  -- 阶段2：固定2把武器
        [3] = 1,  -- 阶段3：至少1把武器
        [4] = 1,  -- 阶段4：至少1把武器
        [5] = 1,  -- 阶段5：至少1把武器
    },
}

-- ============================================================================
-- 刷新费用公式（Wiki确认版本）
-- 首次刷新费用 = floor(阶段 × 0.75) + floor(阶段 × 0.40)
-- 每次递增 = floor(阶段 × 0.40)，最小值为1
-- ============================================================================

function Shop.CalculateRefreshCost(waveNum, refreshCount)
    -- 公式：首次刷新费用 = floor(阶段 × 0.75) + floor(阶段 × 0.40)
    -- 但低波次（1-2波）时公式结果低于文档表格，需要取 max(waveNum, 公式结果)
    local formulaCost = math.floor(waveNum * 0.75) + math.floor(waveNum * 0.40)
    local baseCost = math.max(waveNum, formulaCost)
    local increment = math.max(1, math.floor(waveNum * 0.40))
    local cost = baseCost + refreshCount * increment
    return math.max(1, cost)  -- 最小1晶体
end

-- ============================================================================
-- 价格通胀公式（Wiki确认版本）
-- 最终价格 = 基础价格 + 阶段 + (基础价格 × 0.1 × 阶段)
-- ============================================================================

function Shop.CalculatePrice(basePrice, waveNum, shopDiscount)
    basePrice = basePrice or 10
    waveNum = waveNum or 1
    shopDiscount = shopDiscount or 0
    local price = basePrice + waveNum + math.floor(basePrice * 0.1 * waveNum)
    -- 应用商店折扣
    price = price * (1 - shopDiscount)
    return math.floor(math.max(1, price))  -- 最小1晶体，确保整数
end

-- ============================================================================
-- 品质生成公式（Wiki确认版本）
-- 品质概率 = ((每阶段增加 × (当前阶段 - 最小阶段 - 1)) + 基础概率) × (100% + 战场运势)
-- ============================================================================

function Shop.CalculateQualityChance(qualityConfig, waveNum, luck)
    if waveNum < qualityConfig.minWave then
        return 0
    end
    
    local waveBonus = qualityConfig.perWaveIncrease * math.max(0, waveNum - qualityConfig.minWave - 1)
    local baseChance = qualityConfig.baseChance + waveBonus
    local finalChance = baseChance * (1 + (luck or 0) / 100)
    
    return math.min(finalChance, qualityConfig.maxChance)
end

function Shop.RollQuality(waveNum, luck)
    local config = Shop.Config.Quality
    
    -- 从高到低判定：T4 → T3 → T2 → T1
    local t4Chance = Shop.CalculateQualityChance(config.T4, waveNum, luck)
    if math.random() < t4Chance then
        return 4, "旗舰型"
    end
    
    local t3Chance = Shop.CalculateQualityChance(config.T3, waveNum, luck)
    if math.random() < t3Chance then
        return 3, "精英型"
    end
    
    local t2Chance = Shop.CalculateQualityChance(config.T2, waveNum, luck)
    if math.random() < t2Chance then
        return 2, "改良型"
    end
    
    return 1, "标准型"
end

-- ============================================================================
-- 初始化
-- ============================================================================

--- 新一局游戏开始时调用，清除跨局残留状态
function Shop.ResetForNewGame()
    Shop.lockedItems = {}
    Shop.items = {}
    Shop.selectedIndex = 1
    Shop.refreshCount = 0
    Shop.currentWave = 1
end

function Shop.Init(waveNum)
    Shop.currentWave = waveNum or 1
    Shop.selectedIndex = 1
    Shop.refreshCount = 0
    
    -- 重置免费刷新次数（危险兔子模块：每波重置）
    local player = Shop.getPlayer and Shop.getPlayer() or {}
    player.freeRefreshesRemaining = player.freeRefreshes or 0
    
    Shop.GenerateItems(waveNum)
end

-- ============================================================================
-- 商品生成（含武器保底和匹配池）
-- ============================================================================

function Shop.GenerateItems(waveNum)
    waveNum = waveNum or 1
    local player = Shop.getPlayer and Shop.getPlayer() or {}
    local luck = player.luck or 0
    
    local itemCount = Shop.Config.ItemCount
    local newItems = {}
    
    -- 计算武器保底数量
    local guaranteedWeapons = Shop.Config.WeaponGuarantee[waveNum] or 0
    local weaponCount = 0
    
    -- 先处理锁定的物品
    local lockedCount = 0
    for i = 1, itemCount do
        if Shop.lockedItems[i] then
            newItems[i] = Shop.lockedItems[i]
            lockedCount = lockedCount + 1
            if newItems[i].type == "weapon" then
                weaponCount = weaponCount + 1
            end
        end
    end
    
    -- 生成新物品填充空位
    for i = 1, itemCount do
        if not newItems[i] then
            local forceWeapon = false
            
            -- 检查是否需要强制武器（保底机制）
            local remainingSlots = 0
            for j = i, itemCount do
                if not newItems[j] then
                    remainingSlots = remainingSlots + 1
                end
            end
            
            local neededWeapons = guaranteedWeapons - weaponCount
            if neededWeapons > 0 and neededWeapons >= remainingSlots then
                forceWeapon = true
            end
            
            local item = Shop.GenerateOneItem(waveNum, player, forceWeapon)
            newItems[i] = item
            
            if item.type == "weapon" then
                weaponCount = weaponCount + 1
            end
        end
    end
    
    Shop.items = newItems
end

function Shop.GenerateOneItem(waveNum, player, forceWeapon)
    local roll = math.random()
    local luck = player.luck or 0
    
    if forceWeapon or roll < Shop.Config.WeaponRatio then
        -- 武器 (35% 或强制)
        return Shop.GenerateWeaponItem(waveNum, player)
    else
        -- 模块 (65%)
        return Shop.GenerateModuleItem(waveNum, player)
    end
end

-- ============================================================================
-- 武器生成（含匹配池系统）
-- ============================================================================

function Shop.GenerateWeaponItem(waveNum, player)
    local weapon = Shop.SelectWeaponFromPool(player)
    
    if not weapon then
        -- 备选：生成模块
        return Shop.GenerateModuleItem(waveNum, player)
    end
    
    local luck = player.luck or 0
    local tier, tierName = Shop.RollQuality(waveNum, luck)
    
    -- 🔴 修复：确保 tier 不低于武器的最低 tier（如激光狙击只有 T3/T4）
    local minTier = weapon.tier or 1
    if tier < minTier then
        tier = minTier
        local tierNames = {[1] = "普通", [2] = "精良", [3] = "稀有", [4] = "传说"}
        tierName = tierNames[tier] or "普通"
    end
    
    -- 计算价格（含通胀和Tier加成）
    local tierMultiplier = {[1] = 1.0, [2] = 1.5, [3] = 2.0, [4] = 2.5}
    local basePrice = weapon.price * (tierMultiplier[tier] or 1.0)
    local shopDiscount = player.shopDiscount or 0
    local finalPrice = Shop.CalculatePrice(basePrice, waveNum, shopDiscount)
    
    -- 检查是否可以合成（武器槽满 + 同ID + 同Tier + Tier<4）
    local canMerge = false
    local weapons = player.weapons or {}
    local maxSlots = player.maxWeaponSlots or 6
    
    -- 只有武器槽满时才显示合成提示
    if #weapons >= maxSlots then
        for _, w in ipairs(weapons) do
            if w.id == weapon.id and w.tier == tier and tier < 4 then
                canMerge = true
                break
            end
        end
    end
    
    return {
        type = "weapon",
        id = weapon.id,
        name = weapon.name,
        description = weapon.description,
        basePrice = weapon.price,
        price = finalPrice,
        lockedPrice = finalPrice,  -- 锁定时记录价格
        tier = tier,
        tierName = tierName,
        canMerge = canMerge,
        weaponData = weapon,
        locked = false,
    }
end

function Shop.SelectWeaponFromPool(player)
    local purchasable = Weapons.GetPurchasable()
    if #purchasable == 0 then
        return nil
    end
    
    local playerWeapons = player.weapons or {}
    local roll = math.random()
    
    -- 20% 同武器池：选择玩家已装备的相同武器
    if roll < Shop.Config.SameWeaponPoolChance and #playerWeapons > 0 then
        local validWeapons = {}
        for _, pw in ipairs(playerWeapons) do
            for _, w in ipairs(purchasable) do
                if w.id == pw.id then
                    table.insert(validWeapons, w)
                    break
                end
            end
        end
        if #validWeapons > 0 then
            return Math.RandomChoice(validWeapons)
        end
    end
    
    -- 15% 同类型池：选择玩家已装备武器的同类型
    if roll < Shop.Config.SameWeaponPoolChance + Shop.Config.SameTypePoolChance and #playerWeapons > 0 then
        local playerTypes = {}
        for _, pw in ipairs(playerWeapons) do
            local weaponData = Weapons.Get(pw.id)
            if weaponData and weaponData.type then
                playerTypes[weaponData.type] = true
            end
        end
        
        local validWeapons = {}
        for _, w in ipairs(purchasable) do
            if playerTypes[w.type] then
                table.insert(validWeapons, w)
            end
        end
        if #validWeapons > 0 then
            return Math.RandomChoice(validWeapons)
        end
    end
    
    -- 65% 全武器池：随机
    return Math.RandomChoice(purchasable)
end

-- ============================================================================
-- 标签匹配辅助函数
-- ============================================================================

--- 收集玩家的所有标签（来自战舰 + 已拥有模块）
--- @param player table 玩家数据
--- @return table 标签集合 {["标签名"] = true, ...}
function Shop.CollectPlayerTags(player)
    local tagSet = {}
    
    -- 1. 收集战舰标签
    local shipId = player.shipId or "Pioneer"
    local ship = Ships.Get(shipId)
    if ship and ship.tags then
        for _, tag in ipairs(ship.tags) do
            tagSet[tag] = true
        end
    end
    
    -- 2. 收集已拥有模块的标签
    local ownedModules = player.modules or {}
    for moduleId, count in pairs(ownedModules) do
        if count > 0 then
            local module = Modules.Get(moduleId)
            if module then
                local moduleTags = Modules.GetTags(module)
                for _, tag in ipairs(moduleTags) do
                    tagSet[tag] = true
                end
            end
        end
    end
    
    return tagSet
end

--- 检查模块是否与玩家标签匹配
--- @param module table 模块数据
--- @param playerTags table 玩家标签集合
--- @return boolean 是否匹配
function Shop.ModuleMatchesTags(module, playerTags)
    local moduleTags = Modules.GetTags(module)
    for _, tag in ipairs(moduleTags) do
        if playerTags[tag] then
            return true
        end
    end
    return false
end

--- 带标签加成的模块选择
--- @param rarityWeights table 稀有度权重 {[1]=60, [2]=30, [3]=10}
--- @param playerTags table 玩家标签集合
--- @return table|nil 选中的模块
function Shop.SelectModuleWithTagBonus(rarityWeights, playerTags)
    local allModules = Modules.GetAllPurchasable()
    if not allModules or #allModules == 0 then
        return nil
    end
    
    -- 构建带权重的候选列表
    local candidates = {}
    local totalWeight = 0
    
    for _, module in ipairs(allModules) do
        local rarity = module.rarity or 1
        local baseWeight = rarityWeights[rarity] or 10
        
        -- 标签匹配加成 +5%
        local weight = baseWeight
        if Shop.ModuleMatchesTags(module, playerTags) then
            weight = baseWeight * (1 + Shop.TagMatchBonus)
        end
        
        if weight > 0 then
            table.insert(candidates, {
                module = module,
                weight = weight,
            })
            totalWeight = totalWeight + weight
        end
    end
    
    if #candidates == 0 or totalWeight <= 0 then
        return nil
    end
    
    -- 加权随机选择
    local roll = math.random() * totalWeight
    local cumulative = 0
    
    for _, candidate in ipairs(candidates) do
        cumulative = cumulative + candidate.weight
        if roll <= cumulative then
            return candidate.module
        end
    end
    
    -- 兜底：返回最后一个
    return candidates[#candidates].module
end

-- ============================================================================
-- 模块生成（含标签匹配加成）
-- ============================================================================

function Shop.GenerateModuleItem(waveNum, player)
    local luck = player.luck or 0
    
    -- 根据阶段和运势调整稀有度权重
    local rarityWeights = {[1] = 60, [2] = 30, [3] = 10}
    
    -- 后期增加稀有模块概率
    if waveNum >= 5 then
        rarityWeights = {[1] = 50, [2] = 35, [3] = 15}
    end
    if waveNum >= 10 then
        rarityWeights = {[1] = 40, [2] = 40, [3] = 20}
    end
    if waveNum >= 15 then
        rarityWeights = {[1] = 30, [2] = 45, [3] = 25}
    end
    
    -- 运势增加稀有概率
    if luck > 0 then
        local bonus = luck * 0.1
        rarityWeights[3] = rarityWeights[3] + bonus
        rarityWeights[2] = rarityWeights[2] + bonus * 0.5
        rarityWeights[1] = rarityWeights[1] - bonus * 1.5
    end
    
    -- 标签匹配加成：收集玩家标签
    local playerTags = Shop.CollectPlayerTags(player)
    
    -- 使用带标签加成的模块选择
    local module = Shop.SelectModuleWithTagBonus(rarityWeights, playerTags)
    if not module then
        -- 备选：返回占位
        return {
            type = "module",
            id = "placeholder",
            name = "空槽位",
            description = "无可用模块",
            price = 0,
            locked = false,
        }
    end
    
    local owned = player.modules and player.modules[module.id] or 0
    local basePrice = module.price
    local shopDiscount = player.shopDiscount or 0
    local finalPrice = Shop.CalculatePrice(basePrice, waveNum, shopDiscount)
    
    -- 已拥有数量增加价格
    finalPrice = finalPrice + owned * 5
    
    return {
        type = "module",
        id = module.id,
        name = module.name,
        description = module.description,
        basePrice = module.price,
        price = finalPrice,
        lockedPrice = finalPrice,  -- 锁定时记录价格
        owned = owned,
        maxStack = module.maxStack,
        moduleData = module,
        locked = false,
    }
end

-- ============================================================================
-- 锁定功能
-- ============================================================================

function Shop.ToggleLock(index)
    local item = Shop.items[index]
    if not item then return false end
    
    item.locked = not item.locked
    
    -- 播放锁定/解锁音效
    local Audio = require("core.Audio")
    if item.locked then
        Shop.lockedItems[index] = item
        Audio.PlayItemLock()
    else
        Shop.lockedItems[index] = nil
        Audio.PlayItemUnlock()
    end
    
    return true
end

function Shop.IsLocked(index)
    local item = Shop.items[index]
    return item and item.locked
end

function Shop.GetLockedCount()
    local count = 0
    for i = 1, Shop.Config.ItemCount do
        if Shop.lockedItems[i] then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- 购买
-- ============================================================================

function Shop.BuyItem(index)
    local item = Shop.items[index]
    if not item then return false, "无效物品" end
    
    local player = Shop.getPlayer and Shop.getPlayer() or {}
    local Audio = require("core.Audio")
    
    -- 使用锁定价格（如果已锁定）
    local price = item.locked and item.lockedPrice or item.price
    
    -- 检查价格
    if (player.crystals or 0) < price then
        Audio.PlayPurchaseFail()
        return false, "晶体不足"
    end
    
    local success, msg
    if item.type == "weapon" then
        success, msg = Shop.BuyWeapon(item, player, price)
    elseif item.type == "module" then
        success, msg = Shop.BuyModule(item, player, price)
    else
        return false, "未知物品类型"
    end
    
    -- 购买成功后标记物品为已售出（不要设为nil，否则ipairs会中断）
    if success then
        item.locked = false
        item.sold = true  -- 标记为已售出，UI会跳过渲染
        Shop.lockedItems[index] = nil
        
        -- 记录统计
        local Game = require("core.Game")
        if Game.battle then
            Game.battle.totalPurchases = (Game.battle.totalPurchases or 0) + 1
            Game.battle.totalCrystalsSpent = (Game.battle.totalCrystalsSpent or 0) + price
            if item.type == "weapon" then
                Game.battle.totalWeaponsBought = (Game.battle.totalWeaponsBought or 0) + 1
            elseif item.type == "module" then
                Game.battle.totalModulesBought = (Game.battle.totalModulesBought or 0) + 1
            end
        end
    end
    
    return success, msg
end

function Shop.BuyWeapon(item, player, price)
    local weapons = player.weapons or {}
    local maxSlots = player.maxWeaponSlots or 6
    local itemTier = item.tier or 1
    
    -- 武器槽未满：直接购买添加
    if #weapons < maxSlots then
        -- 先尝试添加武器（不花费晶体）
        if Shop.onPurchaseWeapon then
            local success, msg = Shop.onPurchaseWeapon(item.id, itemTier)
            if not success then
                return false, msg or "武器添加失败"
            end
            -- 武器添加成功后再扣除晶体
            if Shop.onSpendCrystals then
                Shop.onSpendCrystals(price)
            end
            return true, "购买成功"
        end
        return false, "购买回调未设置"
    end
    
    -- 武器槽已满：检查是否可以合成（同ID + 同Tier + Tier<4）
    local existingWeapon = nil
    for _, w in ipairs(weapons) do
        if w.id == item.id and w.tier == itemTier and itemTier < 4 then
            existingWeapon = w
            break
        end
    end
    
    if not existingWeapon then
        -- 找不到可合成的武器
        if itemTier >= 4 then
            return false, "T4武器无法合成"
        end
        return false, "武器槽已满"
    end
    
    -- 合成升级
    if Shop.onSpendCrystals and Shop.onSpendCrystals(price) then
        existingWeapon.tier = existingWeapon.tier + 1
        -- 更新武器炮塔视觉（品质颜色）
        Player.UpdateWeaponTierVisual(existingWeapon)
        return true, "合成升级至T" .. existingWeapon.tier
    end
    
    return false, "购买失败"
end

function Shop.BuyModule(item, player, price)
    local owned = player.modules and player.modules[item.id] or 0
    
    if item.maxStack and owned >= item.maxStack then
        return false, "已达上限"
    end
    
    if Shop.onSpendCrystals and Shop.onSpendCrystals(price) then
        if Shop.onPurchaseModule then
            Shop.onPurchaseModule(item.id)
        end
        return true, "购买成功"
    end
    
    return false, "购买失败"
end

-- ============================================================================
-- 已装备武器合成
-- ============================================================================

--- 合成两个已装备的武器
--- @param index1 number 第一个武器索引
--- @param index2 number 第二个武器索引
--- @return boolean success 是否成功
--- @return string message 结果消息
function Shop.MergeEquippedWeapons(index1, index2)
    local player = Shop.getPlayer and Shop.getPlayer() or {}
    local weapons = player.weapons
    
    if not weapons then
        return false, "没有武器"
    end
    
    local w1 = weapons[index1]
    local w2 = weapons[index2]
    
    if not w1 or not w2 then
        return false, "武器不存在"
    end
    
    -- 检查合成条件：同ID + 同Tier + Tier<4
    if w1.id ~= w2.id then
        return false, "武器类型不同"
    end
    
    if w1.tier ~= w2.tier then
        return false, "武器等级不同"
    end
    
    if w1.tier >= 4 then
        return false, "T4武器无法合成"
    end
    
    -- 执行合成：升级第一个武器，移除第二个
    -- 确保 w1 有必要的属性（可能从 w2 继承）
    if not w1.slotIndex and w2.slotIndex then
        w1.slotIndex = w2.slotIndex
    end
    if not w1.cooldown then
        w1.cooldown = 0
    end
    
    w1.tier = w1.tier + 1
    
    -- 更新武器炮塔视觉（品质颜色）
    Player.UpdateWeaponTierVisual(w1)
    
    -- 移除第二个武器的炮塔节点（清理场景中的视觉对象）
    if w2.turretNode then
        w2.turretNode:Remove()
        w2.turretNode = nil
    end
    
    -- 从武器数组移除第二个武器
    -- 🔧 统一数据源后，weapons 就是 Player.weapons，无需额外同步
    table.remove(weapons, index2)
    
    return true, "合成成功！升级至T" .. w1.tier
end

-- ============================================================================
-- 刷新
-- ============================================================================

function Shop.Refresh(waveNum)
    waveNum = waveNum or Shop.currentWave
    local player = Shop.getPlayer and Shop.getPlayer() or {}
    local Audio = require("core.Audio")
    
    -- 检查是否有免费刷新次数（危险兔子模块）
    local freeRefreshesRemaining = (player.freeRefreshesRemaining or 0)
    
    if freeRefreshesRemaining > 0 then
        -- 使用免费刷新
        player.freeRefreshesRemaining = freeRefreshesRemaining - 1
        Shop.refreshCount = Shop.refreshCount + 1
        Shop.GenerateItems(waveNum)
        Audio.PlayShopRefresh()
        -- 记录刷新统计
        local Game = require("core.Game")
        if Game.battle then
            Game.battle.totalRefreshes = (Game.battle.totalRefreshes or 0) + 1
        end
        return true, "免费刷新（剩余" .. player.freeRefreshesRemaining .. "次）"
    end
    
    -- 正常付费刷新
    local cost = Shop.CalculateRefreshCost(waveNum, Shop.refreshCount)
    
    if (player.crystals or 0) < cost then
        Audio.PlayPurchaseFail()
        return false, "晶体不足（需要" .. cost .. "）"
    end
    
    if Shop.onSpendCrystals and Shop.onSpendCrystals(cost) then
        Shop.refreshCount = Shop.refreshCount + 1
        Shop.GenerateItems(waveNum)
        Audio.PlayShopRefresh()
        -- 记录刷新统计
        local Game = require("core.Game")
        if Game.battle then
            Game.battle.totalRefreshes = (Game.battle.totalRefreshes or 0) + 1
            Game.battle.totalCrystalsSpent = (Game.battle.totalCrystalsSpent or 0) + cost
        end
        return true, "刷新成功"
    end
    
    return false, "刷新失败"
end

function Shop.GetRefreshCost()
    -- 检查是否有免费刷新次数（危险兔子模块）
    local player = Shop.getPlayer and Shop.getPlayer() or {}
    if (player.freeRefreshesRemaining or 0) > 0 then
        return 0  -- 免费刷新
    end
    return Shop.CalculateRefreshCost(Shop.currentWave, Shop.refreshCount)
end

-- ============================================================================
-- 导航
-- ============================================================================

function Shop.SelectNext()
    Shop.selectedIndex = Shop.selectedIndex + 1
    if Shop.selectedIndex > #Shop.items then
        Shop.selectedIndex = 1
    end
end

function Shop.SelectPrev()
    Shop.selectedIndex = Shop.selectedIndex - 1
    if Shop.selectedIndex < 1 then
        Shop.selectedIndex = #Shop.items
    end
end

function Shop.SelectIndex(index)
    if index >= 1 and index <= #Shop.items then
        Shop.selectedIndex = index
    end
end

-- ============================================================================
-- 获取
-- ============================================================================

function Shop.GetItems()
    return Shop.items
end

function Shop.GetSelectedIndex()
    return Shop.selectedIndex
end

function Shop.GetSelectedItem()
    return Shop.items[Shop.selectedIndex]
end

function Shop.GetCurrentWave()
    return Shop.currentWave
end

-- ============================================================================
-- 调试信息
-- ============================================================================

function Shop.GetDebugInfo()
    local player = Shop.getPlayer and Shop.getPlayer() or {}
    local luck = player.luck or 0
    local waveNum = Shop.currentWave
    
    local config = Shop.Config.Quality
    local t2Chance = Shop.CalculateQualityChance(config.T2, waveNum, luck) * 100
    local t3Chance = Shop.CalculateQualityChance(config.T3, waveNum, luck) * 100
    local t4Chance = Shop.CalculateQualityChance(config.T4, waveNum, luck) * 100
    
    return {
        wave = waveNum,
        refreshCount = Shop.refreshCount,
        refreshCost = Shop.GetRefreshCost(),
        luck = luck,
        t2Chance = string.format("%.1f%%", t2Chance),
        t3Chance = string.format("%.1f%%", t3Chance),
        t4Chance = string.format("%.1f%%", t4Chance),
        lockedCount = Shop.GetLockedCount(),
    }
end

-- ============================================================================
-- 调试面板：获取所有可购买物品及其概率
-- 统一的概率计算，供 ShopUI 调试面板使用
-- ============================================================================

--- 获取所有可购买物品及其出现概率（供调试面板使用）
--- @param waveNum number 当前波次
--- @param player table 玩家数据
--- @return table weaponItems 武器列表（含概率信息）
--- @return table moduleItems 模块列表（含概率信息）
function Shop.GetAllPurchasableItemsWithProbability(waveNum, player)
    waveNum = waveNum or 1
    player = player or {}
    local luck = player.luck or 0
    
    -- ========== 品质概率（复用现有函数）==========
    local config = Shop.Config.Quality
    local t1Chance = 1.0
    local t2Chance = Shop.CalculateQualityChance(config.T2, waveNum, luck)
    local t3Chance = Shop.CalculateQualityChance(config.T3, waveNum, luck)
    local t4Chance = Shop.CalculateQualityChance(config.T4, waveNum, luck)
    t1Chance = math.max(0, 1.0 - t2Chance - t3Chance - t4Chance)
    
    -- ========== 武器列表（复用匹配池配置）==========
    local weaponItems = {}
    local purchasableWeapons = Weapons.GetPurchasable()
    
    -- 收集玩家已有武器的ID和类型
    local playerWeapons = player.weapons or {}
    local ownedWeaponIds = {}
    local ownedWeaponTypes = {}
    for _, pw in ipairs(playerWeapons) do
        ownedWeaponIds[pw.id] = true
        local weaponDef = Weapons.Get(pw.id)
        if weaponDef and weaponDef.type then
            ownedWeaponTypes[weaponDef.type] = true
        end
    end
    
    -- 统计各池武器数量
    local sameWeaponPool = {}  -- 同武器池（玩家已有）
    local sameTypePool = {}    -- 同类型池（同类型但不同武器）
    local allWeaponPool = {}   -- 全武器池（所有武器）
    
    for _, weapon in ipairs(purchasableWeapons) do
        table.insert(allWeaponPool, weapon)
        if ownedWeaponIds[weapon.id] then
            table.insert(sameWeaponPool, weapon)
        elseif ownedWeaponTypes[weapon.type] then
            table.insert(sameTypePool, weapon)
        end
    end
    
    -- 计算每个武器的实际出现概率（复用 Shop.Config 配置）
    local weaponRatio = Shop.Config.WeaponRatio  -- 35%
    local sameWeaponPoolChance = Shop.Config.SameWeaponPoolChance  -- 20%
    local sameTypePoolChance = Shop.Config.SameTypePoolChance      -- 15%
    local allWeaponPoolChance = Shop.Config.AllWeaponPoolChance    -- 65%
    
    for _, weapon in ipairs(purchasableWeapons) do
        local appearChance = 0
        local poolInfo = "全武器池"
        local isOwned = ownedWeaponIds[weapon.id] or false
        local isSameType = (not isOwned) and (ownedWeaponTypes[weapon.type] or false)
        
        -- 全武器池概率（所有武器都有）
        if #allWeaponPool > 0 then
            appearChance = appearChance + (allWeaponPoolChance / #allWeaponPool) * weaponRatio
        end
        
        -- 同武器池额外概率（仅已拥有武器）
        if isOwned and #sameWeaponPool > 0 then
            appearChance = appearChance + (sameWeaponPoolChance / #sameWeaponPool) * weaponRatio
            poolInfo = "已拥有 ⬆"
        -- 同类型池额外概率（仅同类型武器）
        elseif isSameType and #sameTypePool > 0 then
            appearChance = appearChance + (sameTypePoolChance / #sameTypePool) * weaponRatio
            poolInfo = "同类型 ↑"
        end
        
        table.insert(weaponItems, {
            type = "weapon",
            id = weapon.id,
            name = weapon.name,
            description = weapon.description or "",
            price = weapon.price or 25,
            weaponData = weapon,
            -- 品质概率
            t1Chance = t1Chance,
            t2Chance = t2Chance,
            t3Chance = t3Chance,
            t4Chance = t4Chance,
            -- 出现概率（考虑匹配池）
            appearChance = appearChance,
            poolInfo = poolInfo,
            isOwned = isOwned,
            isSameType = isSameType,
        })
    end
    
    -- 按出现概率排序（高概率在前）
    table.sort(weaponItems, function(a, b)
        return a.appearChance > b.appearChance
    end)
    
    -- ========== 模块列表（复用稀有度权重逻辑）==========
    local moduleItems = {}
    local allModules = Modules.GetAllPurchasable()
    
    -- 稀有度权重（与 GenerateModuleItem 完全一致）
    local rarityWeights = {[1] = 60, [2] = 30, [3] = 10}
    if waveNum >= 5 then
        rarityWeights = {[1] = 50, [2] = 35, [3] = 15}
    end
    if waveNum >= 10 then
        rarityWeights = {[1] = 40, [2] = 40, [3] = 20}
    end
    if waveNum >= 15 then
        rarityWeights = {[1] = 30, [2] = 45, [3] = 25}
    end
    
    -- 运势增加稀有概率
    if luck > 0 then
        local bonus = luck * 0.1
        rarityWeights[3] = rarityWeights[3] + bonus
        rarityWeights[2] = rarityWeights[2] + bonus * 0.5
        rarityWeights[1] = rarityWeights[1] - bonus * 1.5
    end
    
    -- 标签匹配加成
    local playerTags = Shop.CollectPlayerTags(player)
    
    -- 计算总权重（含标签加成）
    local moduleWeightList = {}
    local totalWeight = 0
    for _, module in ipairs(allModules) do
        local rarity = module.rarity or 1
        local baseWeight = rarityWeights[rarity] or 10
        local weight = baseWeight
        local hasTagBonus = false
        
        if Shop.ModuleMatchesTags(module, playerTags) then
            weight = baseWeight * (1 + Shop.TagMatchBonus)
            hasTagBonus = true
        end
        
        table.insert(moduleWeightList, {
            module = module,
            weight = weight,
            hasTagBonus = hasTagBonus,
        })
        totalWeight = totalWeight + weight
    end
    
    -- 计算每个模块的出现概率
    local moduleRatio = Shop.Config.ModuleRatio  -- 65%
    for _, entry in ipairs(moduleWeightList) do
        local module = entry.module
        local chance = (entry.weight / math.max(1, totalWeight)) * moduleRatio
        
        table.insert(moduleItems, {
            type = "module",
            id = module.id,
            name = module.name,
            description = module.description or "",
            price = module.price or 20,
            rarity = module.rarity or 1,
            tier = module.tier or 1,
            maxStack = module.maxStack or 1,
            moduleData = module,
            appearChance = chance,
            rarityWeight = entry.weight,
            hasTagBonus = entry.hasTagBonus,
        })
    end
    
    -- 按稀有度/价格排序
    table.sort(moduleItems, function(a, b)
        if a.rarity ~= b.rarity then
            return a.rarity < b.rarity
        end
        return a.price < b.price
    end)
    
    return weaponItems, moduleItems
end

return Shop
