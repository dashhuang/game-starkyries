-- ============================================================================
-- 星河战姬 Starkyries - 实验模块配置
-- ============================================================================

local function register(Modules)
    return {
    -- ========================================================================
    -- 实验模块 - 不稳定系列
    -- ========================================================================

    -- 不稳定反应堆
    {
        id = "unstable_reactor",
        name = "不稳定反应堆",
        type = Modules.Types.EXPERIMENTAL,
        tier = Modules.Tiers.T2,
        description = "火力输出+20%,每波受到15伤害",
        price = 35,
        maxStack = 2,
        rarity = 2,
        lore = "一种危险的能源系统，通过可控的核泄漏来提供额外能量。\n\n「它每秒都在杀死我一点点，」使用者说，「但它让我的敌人死得更快。」",
        effect = function(p)
            p.damageMultiplier = p.damageMultiplier + 0.20
            p.waveStartDamage = (p.waveStartDamage or 0) + 15
        end,
    },

    -- 玻璃大炮
    {
        id = "glass_cannon",
        name = "玻璃大炮",
        type = Modules.Types.EXPERIMENTAL,
        tier = Modules.Tiers.T3,
        description = "火力输出+25%,装甲-3",
        price = 75,
        maxStack = 1,
        rarity = 3,
        lore = "移除所有非必要装甲，将省下的重量全部用于武器系统。\n\n「我的船是一把刀，」烈焰号的艾丽卡说，「刀不需要护甲，刀只需要锋利。」",
        effect = function(p)
            p.damageMultiplier = p.damageMultiplier + 0.25
            p.armor = p.armor - 3
        end,
    },

    -- ========================================================================
    -- 实验模块 - 诅咒系列
    -- ========================================================================

    -- 恶魔契约
    {
        id = "demon_contract",
        name = "恶魔契约",
        type = Modules.Types.EXPERIMENTAL,
        tier = Modules.Tiers.T2,
        description = "击毁敌舰+1护盾,每秒损失1护盾（不给无敌帧）",
        price = 40,
        maxStack = 1,
        rarity = 2,
        lore = "一种寄生式能源系统。它不断吸取你的生命力，但会在你杀敌时返还一部分。\n\n「与恶魔做交易，」血蝶号的卡蜜拉说，「代价是永恒的饥饿。」",
        effect = function(p)
            p.hasDemonContract = true
            p.demonContractKillHeal = 1
            p.demonContractDrain = 1
        end,
    },

    -- ========================================================================
    -- 实验模块 - 疯狂系列
    -- ========================================================================

    -- 赌徒心态
    {
        id = "gamblers_mind",
        name = "赌徒心态",
        type = Modules.Types.EXPERIMENTAL,
        tier = Modules.Tiers.T2,
        description = "暴击伤害+50%,非暴击伤害-15%",
        price = 45,
        maxStack = 2,
        rarity = 2,
        lore = "要么大赢，要么输惨。这种神经改造让你的攻击变得极端——暴击时毁天灭地，普通攻击却软弱无力。\n\n幸运儿号的杰克说：「人生就是一场豪赌。我只下大注。」",
        effect = function(p)
            p.critDamage = p.critDamage + 0.50
            p.nonCritDamageMultiplier = (p.nonCritDamageMultiplier or 1) - 0.15
        end,
    },

    -- 狂战士之血
    {
        id = "berserker_blood",
        name = "狂战士之血",
        type = Modules.Types.EXPERIMENTAL,
        tier = Modules.Tiers.T3,
        description = "护盾越低伤害越高(最高+50%),护盾再生-5",
        price = 55,
        maxStack = 1,
        rarity = 3,
        lore = "古老的战士基因被激活。越是濒死，越是强大。但这种力量会吞噬你的恢复能力。\n\n狂战号的艾丽卡·冯·布伦是这种战斗方式的代言人：「流血让我清醒，伤痛让我愤怒。」",
        effect = function(p)
            p.hasBerserkerBlood = true
            p.berserkerMaxDamageBonus = 0.50
            p.shieldRegen = (p.shieldRegen or 0) - 5
        end,
    },

    -- 孤注一掷（唯一）
    {
        id = "all_in",
        name = "孤注一掷",
        type = Modules.Types.EXPERIMENTAL,
        tier = Modules.Tiers.T3,
        description = "单武器时伤害+30%,只能装备1武器",
        price = 70,
        maxStack = 1,
        rarity = 3,
        isUnique = true,
        lore = "抛弃所有备用武器，将全部能量集中在一件武器上。\n\n「一把剑，一个人，一条路。」\n\n剑圣号的宫本武藏将此视为武道的最高境界：「分散注意力是弱者的表现。」",
        effect = function(p)
            p.hasAllIn = true
            p.allInDamageBonus = 0.30
            p.maxWeapons = 1
        end,
    },
    }
end

return register
