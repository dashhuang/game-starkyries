-- ============================================================================
-- 星河战姬 Starkyries - 武器标签套装效果
-- 完全对标 Brotato 的 Weapon Class 系统
-- 激活门槛：2把起效，逐级递增至6把满效果
-- ============================================================================

local TagSetBonuses = {}

-- ============================================================================
-- 套装效果定义（2/3/4/5/6把，线性递增）
-- 数值来源：Brotato Wiki，2把和6把完全复刻，中间等级线性插值
-- ============================================================================

TagSetBonuses.Sets = {
    -- 力场套装 (Blade) - 近程伤害 + 能量吸收
    -- 标签名改为"力场"以匹配文档
    ["力场"] = {
        name = "力场",
        icon = "⚔",
        color = {r = 255, g = 100, b = 100},
        bonuses = {
            [2] = { meleeDamageBonus = 1, energyAbsorb = 0.01, desc = "+1近程伤害, +1%能量吸收" },
            [3] = { meleeDamageBonus = 2, energyAbsorb = 0.02, desc = "+2近程伤害, +2%能量吸收" },
            [4] = { meleeDamageBonus = 3, energyAbsorb = 0.03, desc = "+3近程伤害, +3%能量吸收" },
            [5] = { meleeDamageBonus = 4, energyAbsorb = 0.04, desc = "+4近程伤害, +4%能量吸收" },
            [6] = { meleeDamageBonus = 5, energyAbsorb = 0.05, desc = "+5近程伤害, +5%能量吸收" },
        }
    },
    
    -- 虚灵套装 (Ethereal) - 规避率（有负面效果：-装甲）
    ["虚灵"] = {
        name = "虚灵",
        icon = "👻",
        color = {r = 180, g = 100, b = 255},
        bonuses = {
            [2] = { evasion = 0.06, armor = -1, desc = "+6%规避率, -1装甲" },
            [3] = { evasion = 0.12, armor = -2, desc = "+12%规避率, -2装甲" },
            [4] = { evasion = 0.18, armor = -3, desc = "+18%规避率, -3装甲" },
            [5] = { evasion = 0.24, armor = -4, desc = "+24%规避率, -4装甲" },
            [6] = { evasion = 0.30, armor = -5, desc = "+30%规避率, -5装甲" },
        }
    },
    
    -- 原始套装 (Primitive) - 最大护盾
    ["原始"] = {
        name = "原始",
        icon = "🛡",
        color = {r = 150, g = 200, b = 100},
        bonuses = {
            [2] = { maxShield = 3, desc = "+3最大护盾" },
            [3] = { maxShield = 6, desc = "+6最大护盾" },
            [4] = { maxShield = 9, desc = "+9最大护盾" },
            [5] = { maxShield = 12, desc = "+12最大护盾" },
            [6] = { maxShield = 15, desc = "+15最大护盾" },
        }
    },
    
    -- 弹道套装 (Gun) - 射程百分比加成
    ["弹道"] = {
        name = "弹道",
        icon = "🎯",
        color = {r = 100, g = 180, b = 255},
        bonuses = {
            [2] = { rangeBonus = 0.3, desc = "+0.3 射程" },
            [3] = { rangeBonus = 0.6, desc = "+0.6 射程" },
            [4] = { rangeBonus = 0.9, desc = "+0.9 射程" },
            [5] = { rangeBonus = 1.2, desc = "+1.2 射程" },
            [6] = { rangeBonus = 1.5, desc = "+1.5 射程" },
        }
    },
    
    -- 爆炸套装 (Explosive) - 爆炸范围%
    ["爆炸"] = {
        name = "爆炸",
        icon = "💥",
        color = {r = 255, g = 150, b = 50},
        bonuses = {
            [2] = { explosionRange = 0.05, desc = "+5%爆炸范围" },
            [3] = { explosionRange = 0.10, desc = "+10%爆炸范围" },
            [4] = { explosionRange = 0.15, desc = "+15%爆炸范围" },
            [5] = { explosionRange = 0.20, desc = "+20%爆炸范围" },
            [6] = { explosionRange = 0.25, desc = "+25%爆炸范围" },
        }
    },
    
    -- 能量套装 (Elemental) - 能量伤害
    ["能量"] = {
        name = "能量",
        icon = "⚡",
        color = {r = 100, g = 255, b = 200},
        bonuses = {
            [2] = { energyDamageBonus = 1, desc = "+1能量伤害" },
            [3] = { energyDamageBonus = 2, desc = "+2能量伤害" },
            [4] = { energyDamageBonus = 3, desc = "+3能量伤害" },
            [5] = { energyDamageBonus = 4, desc = "+4能量伤害" },
            [6] = { energyDamageBonus = 5, desc = "+5能量伤害" },
        }
    },
    
    -- 舰载套装 (Tool) - 工程
    ["舰载"] = {
        name = "舰载",
        icon = "🛠",
        color = {r = 200, g = 200, b = 100},
        bonuses = {
            [2] = { engineering = 1, desc = "+1工程" },
            [3] = { engineering = 2, desc = "+2工程" },
            [4] = { engineering = 3, desc = "+3工程" },
            [5] = { engineering = 4, desc = "+4工程" },
            [6] = { engineering = 5, desc = "+5工程" },
        }
    },
    
    -- 医疗套装 (Medical) - 护盾再生
    ["医疗"] = {
        name = "医疗",
        icon = "💚",
        color = {r = 100, g = 255, b = 150},
        bonuses = {
            [2] = { shieldRegen = 1, desc = "+1护盾再生" },
            [3] = { shieldRegen = 2, desc = "+2护盾再生" },
            [4] = { shieldRegen = 3, desc = "+3护盾再生" },
            [5] = { shieldRegen = 4, desc = "+4护盾再生" },
            [6] = { shieldRegen = 5, desc = "+5护盾再生" },
        }
    },
    
    -- 精准套装 (Precise) - 暴击率
    ["精准"] = {
        name = "精准",
        icon = "🎯",
        color = {r = 255, g = 220, b = 100},
        bonuses = {
            [2] = { critChance = 0.03, desc = "+3%暴击率" },
            [3] = { critChance = 0.06, desc = "+6%暴击率" },
            [4] = { critChance = 0.09, desc = "+9%暴击率" },
            [5] = { critChance = 0.12, desc = "+12%暴击率" },
            [6] = { critChance = 0.15, desc = "+15%暴击率" },
        }
    },
    
    -- 支援套装 (Support) - 资源回收
    ["支援"] = {
        name = "支援",
        icon = "📦",
        color = {r = 150, g = 200, b = 255},
        bonuses = {
            [2] = { harvesting = 5, desc = "+5资源回收" },
            [3] = { harvesting = 10, desc = "+10资源回收" },
            [4] = { harvesting = 15, desc = "+15资源回收" },
            [5] = { harvesting = 20, desc = "+20资源回收" },
            [6] = { harvesting = 25, desc = "+25资源回收" },
        }
    },
    
    -- 重型套装 (Heavy) - 火力输出%
    ["重型"] = {
        name = "重型",
        icon = "💪",
        color = {r = 200, g = 100, b = 100},
        bonuses = {
            [2] = { damageMultiplier = 0.05, desc = "+5%火力输出" },
            [3] = { damageMultiplier = 0.10, desc = "+10%火力输出" },
            [4] = { damageMultiplier = 0.15, desc = "+15%火力输出" },
            [5] = { damageMultiplier = 0.20, desc = "+20%火力输出" },
            [6] = { damageMultiplier = 0.25, desc = "+25%火力输出" },
        }
    },
}

-- ============================================================================
-- 计算玩家武器的标签统计
-- ============================================================================

function TagSetBonuses.CountWeaponTags(weapons)
    local tagCounts = {}
    
    if not weapons then return tagCounts end
    
    for _, weapon in ipairs(weapons) do
        local weaponDef = weapon
        -- 如果是武器实例，获取定义
        if weapon.id then
            local Weapons = require "config.weapons"
            weaponDef = Weapons.Get(weapon.id) or weapon
        end
        
        local tags = weaponDef.tags
        if tags then
            for _, tag in ipairs(tags) do
                tagCounts[tag] = (tagCounts[tag] or 0) + 1
            end
        end
    end
    
    return tagCounts
end

-- ============================================================================
-- 获取激活的套装效果
-- 返回: { tagName = { count, level, bonus } }
-- level: 0=未激活, 2-6=激活等级
-- ============================================================================

function TagSetBonuses.GetActiveSetBonuses(weapons)
    local tagCounts = TagSetBonuses.CountWeaponTags(weapons)
    local activeBonuses = {}
    
    for tag, count in pairs(tagCounts) do
        local setDef = TagSetBonuses.Sets[tag]
        if setDef then
            -- 新的5级系统：2/3/4/5/6
            local level = 0
            if count >= 6 then
                level = 6
            elseif count >= 5 then
                level = 5
            elseif count >= 4 then
                level = 4
            elseif count >= 3 then
                level = 3
            elseif count >= 2 then
                level = 2
            end
            
            activeBonuses[tag] = {
                count = count,
                level = level,
                setDef = setDef,
                bonus = level > 0 and setDef.bonuses[level] or nil,
            }
        end
    end
    
    return activeBonuses
end

-- ============================================================================
-- 计算所有套装的总加成
-- 返回合并后的属性加成表
-- ============================================================================

function TagSetBonuses.CalculateTotalBonuses(weapons)
    local activeBonuses = TagSetBonuses.GetActiveSetBonuses(weapons)
    local total = {
        meleeDamageBonus = 0,
        energyAbsorb = 0,
        evasion = 0,
        armor = 0,
        maxShield = 0,
        rangeBonus = 0,
        explosionRange = 0,
        energyDamageBonus = 0,
        engineering = 0,
        shieldRegen = 0,
        critChance = 0,
        harvesting = 0,
        damageMultiplier = 0,
    }
    
    for _, data in pairs(activeBonuses) do
        if data.bonus then
            for stat, value in pairs(data.bonus) do
                if stat ~= "desc" and total[stat] ~= nil then
                    total[stat] = total[stat] + value
                end
            end
        end
    end
    
    return total
end

-- ============================================================================
-- 获取武器的标签信息（用于UI显示）
-- ============================================================================

function TagSetBonuses.GetWeaponTagInfo(weaponId, allWeapons)
    local Weapons = require "config.weapons"
    local weaponDef = Weapons.Get(weaponId)
    if not weaponDef or not weaponDef.tags then
        return {}
    end
    
    local tagCounts = TagSetBonuses.CountWeaponTags(allWeapons)
    local tagInfo = {}
    
    for _, tag in ipairs(weaponDef.tags) do
        local setDef = TagSetBonuses.Sets[tag]
        if setDef then
            local count = tagCounts[tag] or 0
            -- 新的5级系统
            local level = 0
            if count >= 6 then level = 6
            elseif count >= 5 then level = 5
            elseif count >= 4 then level = 4
            elseif count >= 3 then level = 3
            elseif count >= 2 then level = 2
            end
            
            -- 下一级：2→3→4→5→6→nil
            local nextLevel = nil
            if level == 0 then nextLevel = 2
            elseif level < 6 then nextLevel = level + 1
            end
            
            table.insert(tagInfo, {
                tag = tag,
                setDef = setDef,
                count = count,
                level = level,
                bonus = level > 0 and setDef.bonuses[level] or nil,
                nextLevel = nextLevel,
                nextBonus = nextLevel and setDef.bonuses[nextLevel] or nil,
            })
        end
    end
    
    return tagInfo
end

return TagSetBonuses
