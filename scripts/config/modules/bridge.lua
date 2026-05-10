-- ============================================================================
-- 星河战姬 Starkyries - 舰桥升级系统
-- ============================================================================

local function register(Modules)
    -- ============================================================================
    -- 舰桥升级选项（免费升级,4选1）
    -- 严格对齐设计文档
    -- ============================================================================

    -- 品质颜色定义
    Modules.TierColors = {
        [1] = {r = 180, g = 180, b = 180, name = "I",   label = "标准"},
        [2] = {r = 80,  g = 200, b = 80,  name = "II",  label = "改良"},
        [3] = {r = 80,  g = 150, b = 255, name = "III", label = "精英"},
        [4] = {r = 200, g = 100, b = 255, name = "IV",  label = "旗舰"},
    }

    -- 舰桥升级属性定义（16种属性,每种4档数值）
    Modules.BridgeUpgradeStats = {
        -- 生存类
        {
            id = "max_shield", name = "护盾容量",
            values = {3, 6, 9, 12},
            descTemplate = "+%d 最大护盾",
            effect = function(p, value) 
                p.maxShield = p.maxShield + value
                p.shield = math.min(p.shield + value, p.maxShield) 
            end
        },
        {
            id = "shield_regen", name = "护盾再生",
            values = {2, 3, 4, 5},
            descTemplate = "+%d 护盾再生值",
            effect = function(p, value) p.shieldRegen = p.shieldRegen + value end
        },
        {
            id = "energy_absorb", name = "能量吸收",
            values = {0.01, 0.02, 0.03, 0.04},
            descTemplate = "+%d%% 攻击回盾",
            isPercent = true,
            effect = function(p, value) p.energyAbsorb = p.energyAbsorb + value end
        },
        {
            id = "armor", name = "装甲强化",
            values = {1, 2, 3, 4},
            descTemplate = "+%d 装甲",
            effect = function(p, value) p.armor = p.armor + value end
        },
        {
            id = "dodge", name = "规避系统",
            values = {0.03, 0.06, 0.09, 0.12},
            descTemplate = "+%d%% 规避",
            isPercent = true,
            effect = function(p, value) p.dodgeChance = p.dodgeChance + value end
        },
        
        -- 通用输出类
        {
            id = "damage", name = "火力输出",
            values = {0.05, 0.08, 0.12, 0.16},
            descTemplate = "+%d%% 火力输出",
            isPercent = true,
            effect = function(p, value) p.damageMultiplier = p.damageMultiplier + value end
        },
        {
            id = "fire_rate", name = "射击频率",
            values = {0.05, 0.10, 0.15, 0.20},
            descTemplate = "+%d%% 攻速",
            isPercent = true,
            effect = function(p, value) p.fireRateMultiplier = p.fireRateMultiplier + value end
        },
        {
            id = "crit", name = "精确打击",
            values = {0.03, 0.05, 0.07, 0.09},
            descTemplate = "+%d%% 暴击率",
            isPercent = true,
            effect = function(p, value) p.critChance = p.critChance + value end
        },
        {
            id = "range", name = "火力范围",
            values = {0.5, 1.0, 1.5, 2.0},
            descTemplate = "+%.1f 火力范围",
            effect = function(p, value) p.attackRange = (p.attackRange or 0) + value end
        },
        
        -- 专精加成类（固定值加成）
        {
            id = "close_range", name = "近程强化",
            values = {1, 2, 3, 4},
            descTemplate = "+%d 近程伤害",
            effect = function(p, value) p.meleeDamageBonus = (p.meleeDamageBonus or 0) + value end
        },
        {
            id = "ballistic", name = "弹道强化",
            values = {1, 2, 3, 4},
            descTemplate = "+%d 弹道伤害",
            effect = function(p, value) p.ballisticDamageBonus = (p.ballisticDamageBonus or 0) + value end
        },
        {
            id = "energy", name = "能量强化",
            values = {1, 2, 3, 4},
            descTemplate = "+%d 能量伤害",
            effect = function(p, value) p.energyDamageBonus = (p.energyDamageBonus or 0) + value end
        },
        {
            id = "engineering", name = "工程",
            values = {2, 3, 4, 5},
            descTemplate = "+%d 工程",
            effect = function(p, value) p.engineering = (p.engineering or 0) + value end
        },
        
        -- 机动与经济类
        {
            id = "speed", name = "引擎推力",
            values = {0.03, 0.06, 0.09, 0.12},
            descTemplate = "+%d%% 速度",
            isPercent = true,
            effect = function(p, value) p.moveSpeed = p.moveSpeed * (1 + value) end
        },
        {
            id = "luck", name = "战场运势",
            values = {5, 10, 15, 20},
            descTemplate = "+%d 运势",
            effect = function(p, value) p.luck = (p.luck or 0) + value end
        },
        {
            id = "crystal", name = "资源回收",
            values = {0.05, 0.08, 0.10, 0.12},
            descTemplate = "+%d%% 晶体掉落",
            isPercent = true,
            effect = function(p, value) p.crystalMultiplier = p.crystalMultiplier + value end
        },
    }

    -- 生成带品质的升级选项
    function Modules.CreateBridgeUpgradeOption(tier, statIndex)
        local stat = Modules.BridgeUpgradeStats[statIndex]
        if not stat then return nil end
        
        tier = math.max(1, math.min(4, tier or 1))
        local value = stat.values[tier]
        local tierInfo = Modules.TierColors[tier]
        
        local displayValue = stat.isPercent and math.floor(value * 100) or value
        local desc = string.format(stat.descTemplate, displayValue)
        
        return {
            id = stat.id,
            name = stat.name,
            desc = desc,
            tier = tier,
            tierName = tierInfo.name,
            tierLabel = tierInfo.label,
            tierColor = tierInfo,
            value = value,
            effect = function(p) stat.effect(p, value) end
        }
    end

    -- 根据等级和运势决定品质
    function Modules.DetermineUpgradeTier(playerLevel, luck)
        luck = luck or 0
        
        if playerLevel >= 25 then
            return 4
        elseif playerLevel == 20 or playerLevel == 15 or playerLevel == 10 then
            return 3
        elseif playerLevel == 5 then
            return 2
        elseif playerLevel <= 4 then
            return 1
        end
        
        local roll = math.random()
        local tier4Base = 0.03 + math.max(0, (playerLevel - 10) * 0.005)
        local tier3Base = 0.10 + math.max(0, (playerLevel - 5) * 0.01)
        local tier2Base = 0.30
        
        local tier4Chance = math.min(0.25, tier4Base * (1 + luck))
        local tier3Chance = math.min(0.60, tier3Base * (1 + luck))
        local tier2Chance = math.min(1.0, tier2Base * (1 + luck))
        
        if playerLevel >= 8 and roll < tier4Chance then
            return 4
        elseif playerLevel >= 3 and roll < tier3Chance then
            return 3
        elseif roll < tier2Chance then
            return 2
        else
            return 1
        end
    end

    -- 获取随机舰桥升级选项
    function Modules.GetRandomBridgeUpgrades(count, playerLevel, luck)
        count = count or 4
        playerLevel = playerLevel or 1
        luck = luck or 0
        
        local indices = {}
        for i = 1, #Modules.BridgeUpgradeStats do
            indices[i] = i
        end
        
        for i = #indices, 2, -1 do
            local j = math.random(i)
            indices[i], indices[j] = indices[j], indices[i]
        end
        
        local result = {}
        for i = 1, math.min(count, #indices) do
            local tier = Modules.DetermineUpgradeTier(playerLevel, luck)
            local option = Modules.CreateBridgeUpgradeOption(tier, indices[i])
            if option then
                table.insert(result, option)
            end
        end
        
        return result
    end
end

return register
