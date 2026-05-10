-- ============================================================================
-- 星河战姬 Starkyries - 战术模块配置
-- ============================================================================

local function register(Modules)
    return {
    -- ========================================================================
    -- 战术模块 - 击毁触发
    -- ========================================================================

    -- 晶体强化（无代价）
    {
        id = "crystal_boost",
        name = "晶体强化",
        type = Modules.Types.TACTICAL,
        tier = Modules.Tiers.T1,
        description = "击毁敌舰时额外获得+10%能量晶体",
        price = 22,
        maxStack = 3,
        rarity = 1,
        lore = "优化晶体提取协议，从敌舰残骸中榨取更多能量。\n\n「每一艘敌舰都是一座移动的矿藏，」拾荒者说，「你只需要知道怎么开采。」",
        effect = function(p)
            p.killCrystalBonus = (p.killCrystalBonus or 0) + 0.10
        end,
    },

    -- 杀戮快感
    {
        id = "kill_thrill",
        name = "杀戮快感",
        type = Modules.Types.TACTICAL,
        tier = Modules.Tiers.T1,
        description = "击毁敌舰回复1护盾,射击频率-5%",
        price = 25,
        maxStack = 2,
        rarity = 1,
        lore = "一种神经反馈系统，将击杀的满足感转化为护盾能量。\n\n梅杜莎·蛇瞳的战斗日志：「每一次击杀都让我变得更强。这是诅咒还是祝福？」",
        effect = function(p)
            p.killHeal = (p.killHeal or 0) + 1
            p.fireRateMultiplier = p.fireRateMultiplier - 0.05
        end,
    },

    -- 连杀奖励（无代价）
    {
        id = "multi_kill_bonus",
        name = "连杀奖励",
        type = Modules.Types.TACTICAL,
        tier = Modules.Tiers.T2,
        description = "1秒内多杀+5晶体",
        price = 40,
        maxStack = 2,
        rarity = 2,
        lore = "帝国竞技场的奖金机制被改造成了战斗系统。连续击杀能够触发额外的资源奖励。\n\n「观众喜欢看连杀，」角斗士们说，「赞助商更喜欢。」",
        effect = function(p)
            p.hasMultiKillBonus = true
            p.multiKillCrystalBonus = 5
        end,
    },

    -- 爆发模式
    {
        id = "burst_mode",
        name = "爆发模式",
        type = Modules.Types.TACTICAL,
        tier = Modules.Tiers.T3,
        description = "击毁10敌舰后下次攻击+100%伤害,护盾再生-2",
        price = 50,
        maxStack = 2,
        rarity = 3,
        lore = "积蓄愤怒，然后释放。这套系统会记录击杀数，在达到阈值时释放毁灭性的一击。\n\n狂战号的艾丽卡·冯·布伦称之为「复仇蓄力」：「十条命换一声怒吼。」",
        effect = function(p)
            p.hasBurstMode = true
            p.burstModeKillRequirement = 10
            p.burstModeDamageBonus = 1.00
            p.shieldRegen = p.shieldRegen - 2
        end,
    },

    -- ========================================================================
    -- 战术模块 - 受伤触发
    -- ========================================================================

    -- 紧急加速（无代价入门道具）
    {
        id = "emergency_boost",
        name = "紧急加速",
        type = Modules.Types.TACTICAL,
        tier = Modules.Tiers.T1,
        description = "受伤时+30%速度持续2秒",
        price = 22,
        maxStack = 2,
        rarity = 1,
        lore = "疼痛触发的肾上腺素反应被程序化。受伤的瞬间，引擎会自动进入超载模式。\n\n「被打痛了就跑得更快，」疾风号的风间美月说，「这不是懦弱，是本能。」",
        effect = function(p)
            p.hasEmergencyBoost = true
            p.emergencyBoostAmount = 0.30
            p.emergencyBoostDuration = 2.0
        end,
    },

    -- 愤怒激活
    {
        id = "rage_activate",
        name = "愤怒激活",
        type = Modules.Types.TACTICAL,
        tier = Modules.Tiers.T1,
        description = "受伤时+10%伤害持续3秒,最大护盾-3",
        price = 25,
        maxStack = 2,
        rarity = 1,
        lore = "将疼痛转化为愤怒，将愤怒转化为破坏力。\n\n狂战号的艾丽卡说：「打我？好，现在你惹怒我了。」",
        effect = function(p)
            p.hasRageActivate = true
            p.rageActivateDamageBonus = 0.10
            p.rageActivateDuration = 3.0
            p.maxShield = p.maxShield - 3
        end,
    },

    -- 反击协议
    {
        id = "counter_protocol",
        name = "反击协议",
        type = Modules.Types.TACTICAL,
        tier = Modules.Tiers.T2,
        description = "受伤时返还5伤害,护盾再生-1",
        price = 35,
        maxStack = 3,
        rarity = 2,
        lore = "「以牙还牙」的战术哲学被编码成了自动反击系统。\n\n铁壁号舰长林德曼的格言：「打我一拳，我还你两拳。这叫利息。」",
        effect = function(p)
            p.hasCounterProtocol = true
            p.counterProtocolDamage = 5
            p.shieldRegen = p.shieldRegen - 1
        end,
    },

    -- 护盾爆发
    {
        id = "shield_burst",
        name = "护盾爆发",
        type = Modules.Types.TACTICAL,
        tier = Modules.Tiers.T2,
        description = "护盾归0时对周围敌舰造成25伤害,最大护盾-5",
        price = 40,
        maxStack = 2,
        rarity = 2,
        lore = "当护盾崩溃时，释放所有剩余能量造成爆炸伤害。一种「同归于尽」的战术。\n\n「如果我的盾要碎，那我要让所有人都知道。」——使用者遗言",
        effect = function(p)
            p.hasShieldBurst = true
            p.shieldBurstDamage = 25
            p.maxShield = p.maxShield - 5
        end,
    },

    -- ========================================================================
    -- 战术模块 - 条件触发
    -- ========================================================================

    -- 满血奖励
    {
        id = "full_shield_bonus",
        name = "满血奖励",
        type = Modules.Types.TACTICAL,
        tier = Modules.Tiers.T2,
        description = "护盾满时+25%伤害,护盾再生-2",
        price = 35,
        maxStack = 2,
        rarity = 2,
        lore = "完美状态下的战斗优势。当护盾完整时，系统会将多余能量导入武器系统。\n\n守护者号舰长的哲学：「保护好自己，才能更好地伤害敌人。」",
        effect = function(p)
            p.fullShieldDamageBonus = (p.fullShieldDamageBonus or 0) + 0.25
            p.shieldRegen = p.shieldRegen - 2
        end,
    },

    -- 低血爆发
    {
        id = "low_shield_burst",
        name = "低血爆发",
        type = Modules.Types.TACTICAL,
        tier = Modules.Tiers.T2,
        description = "护盾<30%时+50%伤害,护盾再生-3",
        price = 45,
        maxStack = 2,
        rarity = 2,
        lore = "濒死状态下的爆发力。当护盾即将耗尽时，系统会超载武器以求最后一搏。\n\n「置之死地而后生，」狂战号的艾丽卡说，「我在悬崖边上最危险。」",
        effect = function(p)
            p.lowShieldDamageBonus = (p.lowShieldDamageBonus or 0) + 0.50
            p.lowShieldThreshold = 0.30
            p.shieldRegen = p.shieldRegen - 3
        end,
    },

    -- ========================================================================
    -- 战术模块 - 连锁触发
    -- ========================================================================

    -- 死亡连锁
    {
        id = "death_chain",
        name = "死亡连锁",
        type = Modules.Types.TACTICAL,
        tier = Modules.Tiers.T3,
        description = "击毁敌舰10%几率对附近敌舰造成5伤害(+25%运势加成),最大护盾-5",
        price = 50,
        maxStack = 2,
        rarity = 3,
        lore = "死亡会传染。这套系统能够让一艘敌舰的毁灭波及周围的同伴。\n\n「多米诺骨牌，」暗影号的夜凛轻声说，「推倒第一块，剩下的自己会倒。」",
        effect = function(p)
            p.deathChainChance = (p.deathChainChance or 0) + 0.10
            p.deathChainDamage = 5
            p.deathChainLuckScale = 0.25
            p.maxShield = p.maxShield - 5
        end,
    },

    -- 能量爆发（无代价）
    {
        id = "energy_explosion",
        name = "能量爆发",
        type = Modules.Types.TACTICAL,
        tier = Modules.Tiers.T2,
        description = "击毁敌舰时25%几率产生小范围爆炸",
        price = 45,
        maxStack = 2,
        rarity = 2,
        lore = "引爆敌舰反应堆的技术。有时候，敌人的死亡本身就是一种武器。\n\n「让他们的船变成炸弹，」机械叛军工程师说，「这就是诗意。」",
        effect = function(p)
            p.energyExplosionChance = (p.energyExplosionChance or 0) + 0.25
            p.energyExplosionRadius = 1.5
            p.energyExplosionDamage = 3
        end,
    },

    -- ========================================================================
    -- 战术模块 - DOT/燃烧类
    -- ========================================================================

    -- 等离子灼烧（无代价）
    {
        id = "plasma_burn",
        name = "等离子灼烧",
        type = Modules.Types.TACTICAL,
        tier = Modules.Tiers.T2,
        description = "攻击20%几率施加等离子灼烧(3秒内造成基础伤害×50%)",
        price = 45,
        maxStack = 2,
        rarity = 2,
        lore = "等离子附着在装甲上持续燃烧，即使躲过了直接攻击也难逃后续伤害。\n\n烈焰号的武器专家说：「火焰不会放过任何人。它会一直烧，直到没有东西可烧。」",
        effect = function(p)
            p.burnChance = (p.burnChance or 0) + 0.20
            p.burnDuration = 3.0
            p.burnDamagePercent = 0.50
        end,
    },
    }
end

return register
