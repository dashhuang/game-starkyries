-- ============================================================================
-- 星河战姬 Starkyries - 火控模块配置
-- ============================================================================

local function register(Modules)
    return {
    -- ========================================================================
    -- 火控模块 - 伤害类
    -- ========================================================================
    
    -- 火力强化（无代价入门道具）
    {
        id = "damage_boost",
        name = "火力强化",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "火力输出+6%",
        price = 20,
        maxStack = 5,
        rarity = 1,
        lore = "帝国军校的标准教材。每一个毕业生都会领到一枚，刻着校训：「更强的火力，更短的战争。」\n\n但战争从未变短。",
        effect = function(p)
            p.damageMultiplier = p.damageMultiplier + 0.06
        end,
    },
    
    -- 激进战术
    {
        id = "aggressive_tactics",
        name = "激进战术",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "火力输出+6%,装甲-1",
        price = 25,
        maxStack = 5,
        rarity = 1,
        lore = "艾丽卡·冯·布伦的战斗哲学：进攻就是最好的防御。\n\n「装甲是给懦夫准备的，」她说，「真正的战士在敌人开枪之前就已经赢了。」",
        effect = function(p)
            p.damageMultiplier = p.damageMultiplier + 0.06
            p.armor = p.armor - 1
        end,
    },
    
    -- 武器过载器
    {
        id = "weapon_overload",
        name = "武器过载器",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T3,
        description = "火力输出+25%,每波受到15伤害",
        price = 70,
        maxStack = 2,
        rarity = 3,
        lore = "这枚芯片会强制武器系统超出安全阈值运行，代价是持续灼伤舰体。\n\n设计者在笔记中写道：「疼痛是力量的货币。」\n\n他死于过载测试。讽刺的是，测试被判定为「成功」。",
        effect = function(p)
            p.damageMultiplier = p.damageMultiplier + 0.25
            p.waveStartDamage = (p.waveStartDamage or 0) + 15
        end,
    },
    
    -- 高能核心（无代价）
    {
        id = "power_core",
        name = "高能核心",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T2,
        description = "火力输出+12%",
        price = 40,
        maxStack = 3,
        rarity = 2,
        lore = "从帝国旗舰「永恒意志号」残骸中打捞的技术。\n\n那艘船在与机械叛军的战斗中被击沉，但它的核心技术流入了黑市，成为每个拾荒者梦寐以求的宝藏。",
        effect = function(p)
            p.damageMultiplier = p.damageMultiplier + 0.12
        end,
    },
    
    -- 杀戮本能
    {
        id = "killing_instinct",
        name = "杀戮本能",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T2,
        description = "火力输出+3%每层,击毁叠加(上限10层),引擎推力-3%",
        price = 40,
        maxStack = 2,
        rarity = 2,
        lore = "夜凛的神经接口会记录每一次击杀，并将其转化为战斗效率的提升。\n\n「杀得越多，杀得越快，」她曾经这样描述，「这是诅咒还是祝福，取决于你站在哪一边。」",
        effect = function(p)
            p.hasKillingInstinct = true
            p.killingInstinctMaxStacks = 10
            p.killingInstinctDamagePerStack = 0.03
            p.moveSpeed = p.moveSpeed * 0.97
        end,
    },
    
    -- 愤怒芯片
    {
        id = "rage_chip",
        name = "愤怒芯片",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "火力输出+1%每损失1%护盾,护盾再生-1",
        price = 25,
        maxStack = 2,
        rarity = 1,
        lore = "将痛苦转化为愤怒，将愤怒转化为力量。\n\n帝国审讯官罗莎·荆棘深谙此道——她在审讯室中学会了这一点，只是角色与她想象的不同。",
        effect = function(p)
            p.hasRageChip = true
            p.rageDamagePerMissingShieldPercent = 0.01
            p.shieldRegen = p.shieldRegen - 1
        end,
    },
    
    -- ========================================================================
    -- 火控模块 - 攻速类
    -- ========================================================================
    
    -- 射击控制器（无代价入门道具）
    {
        id = "fire_controller",
        name = "射击控制器",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "射击频率+8%",
        price = 20,
        maxStack = 5,
        rarity = 1,
        lore = "精密的节拍器，让武器以最优频率开火。\n\n格蕾丝·霍珀曾为帝国校准过数千枚这样的芯片。当她发现这些武器用于屠杀平民时，她亲手砸碎了最后一批。",
        effect = function(p)
            p.fireRateMultiplier = p.fireRateMultiplier + 0.08
        end,
    },
    
    -- 连射模块
    {
        id = "rapid_fire",
        name = "连射模块",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "射击频率+10%,火力输出-4%",
        price = 20,
        maxStack = 5,
        rarity = 1,
        lore = "牺牲单发威力换取更密集的弹幕。\n\n竞技场角斗士雅典娜·斯巴达偏爱这种风格：「让敌人数清你的子弹？别开玩笑了。」",
        effect = function(p)
            p.fireRateMultiplier = p.fireRateMultiplier + 0.10
            p.damageMultiplier = p.damageMultiplier - 0.04
        end,
    },
    
    -- 涡轮发射器（无代价）
    {
        id = "turbo_launcher",
        name = "涡轮发射器",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "射击频率+10%",
        price = 25,
        maxStack = 3,
        rarity = 1,
        lore = "通过压缩能量释放周期来提升射速。简单，粗暴，有效。\n\n疾风号的风间美月说这是她最喜欢的模块：「快，还要更快。」",
        effect = function(p)
            p.fireRateMultiplier = p.fireRateMultiplier + 0.10
        end,
    },
    
    -- 战斗兴奋剂
    {
        id = "combat_stimulant",
        name = "战斗兴奋剂",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T2,
        description = "击毁敌舰触发+15%射速3秒,最大护盾-3",
        price = 35,
        maxStack = 2,
        rarity = 2,
        lore = "帝国暗部的违禁品，通过神经刺激让舰长进入亢奋状态。副作用包括护盾系统不稳定。\n\n梅杜莎·蛇瞳曾大量使用这种药剂。「毒蛇不需要休息，」她说，「只需要下一个猎物。」",
        effect = function(p)
            p.hasCombatStimulant = true
            p.combatStimulantFireRateBonus = 0.15
            p.combatStimulantDuration = 3.0
            p.maxShield = p.maxShield - 3
        end,
    },
    
    -- 狂热模式
    {
        id = "frenzy_mode",
        name = "狂热模式",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T3,
        description = "射击频率+2%每层,击毁叠加(上限15层),装甲-1",
        price = 55,
        maxStack = 2,
        rarity = 3,
        lore = "原本是治疗创伤后应激障碍的神经模块，却被改造成了战斗增强器。\n\n狂战号的艾丽卡发现了它的另一种用途：让愤怒成为武器。每一次击杀都在喂养内心的野兽。",
        effect = function(p)
            p.hasFrenzyMode = true
            p.frenzyMaxStacks = 15
            p.frenzyFireRatePerStack = 0.02
            p.armor = p.armor - 1
        end,
    },
    
    -- ========================================================================
    -- 火控模块 - 暴击类
    -- ========================================================================
    
    -- 精准瞄具（无代价入门道具）
    {
        id = "precision_scope",
        name = "精准瞄具",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "精确打击+5%",
        price = 20,
        maxStack = 4,
        rarity = 1,
        lore = "狙击手伊莎贝拉·猎隼的入门课：「瞄准反应堆，不是驾驶舱。机师可以换，引擎不能。」\n\n她从不解释为什么要饶过那些驾驶员。",
        effect = function(p)
            p.critChance = p.critChance + 0.05
        end,
    },
    
    -- 致命一击（无代价）
    {
        id = "critical_strike",
        name = "致命一击",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T2,
        description = "致命伤害+25%",
        price = 30,
        maxStack = 3,
        rarity = 2,
        lore = "帝国死刑执行官的标准配置，设计用于一击毙命。\n\n「慈悲，」马库斯·铁腕曾说，「是让目标没有时间感到恐惧。」他在叛逃前处决了三百人。他记得每一个名字。",
        effect = function(p)
            p.critDamage = p.critDamage + 0.25
        end,
    },
    
    -- 暗杀协议
    {
        id = "assassination_protocol",
        name = "暗杀协议",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T2,
        description = "精确打击+10%,装甲-1",
        price = 50,
        maxStack = 2,
        rarity = 2,
        lore = "帝国暗杀部队「沉默者」的标准程序。牺牲防护换取致命精准。\n\n暗影号的夜凛曾是这支部队的王牌。她现在仍用这套协议——只是目标变了。",
        effect = function(p)
            p.critChance = p.critChance + 0.10
            p.armor = p.armor - 1
        end,
    },
    
    -- 致命校准
    {
        id = "lethal_calibration",
        name = "致命校准",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T2,
        description = "精确打击+8%,致命伤害+15%,最大护盾-5",
        price = 55,
        maxStack = 3,
        rarity = 2,
        lore = "这套校准程序会将护盾能量转移到武器系统，换取更精准的杀伤。\n\n「每一分防护都是对进攻的浪费，」赛博战士「零」如此评价，「在敌人反应过来之前结束战斗。」",
        effect = function(p)
            p.critChance = p.critChance + 0.08
            p.critDamage = p.critDamage + 0.15
            p.maxShield = p.maxShield - 5
        end,
    },
    
    -- 处决者
    {
        id = "executioner",
        name = "处决者",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T3,
        description = "敌舰护盾<20%时精确打击+30%,火力输出-5%",
        price = 60,
        maxStack = 2,
        rarity = 3,
        lore = "帝国行刑官的座右铭：「猎物最虚弱的时刻，就是下手的时刻。」\n\n这段代码从帝国司法系统流出，据说出自审判官罗莎·荆棘之手。她用它处决了无数「叛国者」——直到有一天，她发现自己也在名单上。",
        effect = function(p)
            p.hasExecutioner = true
            p.executionerThreshold = 0.20
            p.executionerCritBonus = 0.30
            p.damageMultiplier = p.damageMultiplier - 0.05
        end,
    },
    
    -- ========================================================================
    -- 火控模块 - 穿透类
    -- ========================================================================
    
    -- 穿甲弹头（限购1）
    {
        id = "armor_piercing",
        name = "穿甲弹头",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "穿透+1,后续目标伤害-20%,火力输出-5%",
        price = 25,
        maxStack = 1,
        rarity = 1,
        isUnique = true,
        lore = "机械叛军「穿刺者」的标准弹药。它的设计理念很简单：一发子弹，解决多个问题。\n\n「帝国的阵型太密集了，」叛军工程师说，「这是他们自己的错。」",
        effect = function(p)
            p.piercing = (p.piercing or 0) + 1
            p.piercingDamage = (p.piercingDamage or 1) - 0.20
            p.damageMultiplier = p.damageMultiplier - 0.05
        end,
    },
    
    -- 穿透增幅（不增加穿透次数,只增加穿透后伤害）
    {
        id = "piercing_damage",
        name = "穿透增幅",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T2,
        description = "后续目标伤害+15%,火力输出-2%",
        price = 40,
        maxStack = 3,
        rarity = 2,
        lore = "改良型穿甲弹芯，使用衰变金属制造，穿透后释放能量。\n\n「贯穿三艘巡洋舰后仍有杀伤力，」测试报告如是写道，「测试员申请心理辅导。」",
        effect = function(p)
            p.piercingDamage = (p.piercingDamage or 1) + 0.15
            p.damageMultiplier = p.damageMultiplier - 0.02
        end,
    },
    
    -- 战术头带
    {
        id = "tactical_headband",
        name = "战术头带",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T3,
        description = "穿透+1,火力输出-10%",
        price = 75,
        maxStack = 3,
        rarity = 3,
        lore = "机械叛军领袖「先知」的遗物。这条看似普通的头带实际上是一个神经接口，能够预测弹道轨迹。\n\n「它让我看到了战场的脉络，」装备过它的人说，「敌人排成一条线，等待被串起来。」",
        effect = function(p)
            p.piercing = (p.piercing or 0) + 1
            p.damageMultiplier = p.damageMultiplier - 0.10
        end,
    },
    
    -- ========================================================================
    -- 火控模块 - 类型加成
    -- ========================================================================
    
    -- 近战强化（无代价入门道具）
    {
        id = "melee_boost",
        name = "近战强化",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "近程伤害+2",
        price = 20,
        maxStack = 3,
        rarity = 1,
        lore = "「距离是懦夫的借口。」\n\n烈焰号的艾丽卡·冯·布伦将这句话刻在她的力场发生器上。她相信真正的战士应该直面敌人，而不是躲在远程武器后面。",
        effect = function(p)
            p.meleeDamageBonus = (p.meleeDamageBonus or 0) + 2
        end,
    },
    
    -- 近战大师
    {
        id = "melee_master",
        name = "近战大师",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T2,
        description = "近程伤害+6,弹炮伤害-3",
        price = 55,
        maxStack = 2,
        rarity = 2,
        lore = "竞技场传奇雅典娜·斯巴达的战斗哲学：抵近，再抵近，直到能看清敌人眼中的恐惧。\n\n「导弹？太无聊了。我要听到金属撕裂的声音。」",
        effect = function(p)
            p.meleeDamageBonus = (p.meleeDamageBonus or 0) + 6
            p.ballisticDamageBonus = (p.ballisticDamageBonus or 0) - 3
        end,
    },
    
    -- 弹道计算机（无代价入门道具）
    {
        id = "ballistic_computer",
        name = "弹道计算机",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "弹炮伤害+2",
        price = 20,
        maxStack = 3,
        rarity = 1,
        lore = "每一个帝国炮手都会被灌输一个观念：「子弹比思想更快。」\n\n这台计算机会自动修正重力、风阻和目标移动轨迹。有人说它比人类更懂射击。",
        effect = function(p)
            p.ballisticDamageBonus = (p.ballisticDamageBonus or 0) + 2
        end,
    },
    
    -- 弹道大师
    {
        id = "ballistic_master",
        name = "弹道大师",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T2,
        description = "弹炮伤害+6,近程伤害-3",
        price = 55,
        maxStack = 2,
        rarity = 2,
        lore = "帝国射击冠军维克多·千里眼的秘密：三公里外一枪击中敌舰指挥塔的观察窗。\n\n「子弹是我延伸的手臂，」他说，「只是这条手臂比任何人都长。」",
        effect = function(p)
            p.ballisticDamageBonus = (p.ballisticDamageBonus or 0) + 6
            p.meleeDamageBonus = (p.meleeDamageBonus or 0) - 3
        end,
    },
    
    -- 能量增幅（无代价入门道具）
    {
        id = "energy_amplifier",
        name = "能量增幅",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "能量伤害+2",
        price = 20,
        maxStack = 3,
        rarity = 1,
        lore = "能量武器代表着帝国科技的巅峰。这个小小的增幅器能让光束变得更加炽热。\n\n「原始人用火焰，我们用恒星。」——帝国科学院铭文",
        effect = function(p)
            p.energyDamageBonus = (p.energyDamageBonus or 0) + 2
        end,
    },
    
    -- 能量大师
    {
        id = "energy_master",
        name = "能量大师",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T2,
        description = "能量伤害+6,弹炮伤害-3",
        price = 55,
        maxStack = 2,
        rarity = 2,
        lore = "「光比金属更纯粹。」\n\n圣光号的圣女贞德将能量武器视为神圣的馈赠。她的激光炮在战场上划出炽白的轨迹，像是裁决的光芒。",
        effect = function(p)
            p.energyDamageBonus = (p.energyDamageBonus or 0) + 6
            p.ballisticDamageBonus = (p.ballisticDamageBonus or 0) - 3
        end,
    },
    
    -- 工程专家（无代价入门道具）
    {
        id = "engineering_expert",
        name = "工程专家",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "工程+3",
        price = 20,
        maxStack = 3,
        rarity = 1,
        lore = "机械叛军的核心理念：机器是生命的延伸，而非工具。\n\n这套工程协议来自叛军的开源数据库，任何人都可以学习它——帝国却禁止传播。",
        effect = function(p)
            p.engineering = (p.engineering or 0) + 3
        end,
    },
    
    -- 工程大师
    {
        id = "engineering_master",
        name = "工程大师",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T2,
        description = "工程+6,近程伤害-3",
        price = 55,
        maxStack = 2,
        rarity = 2,
        lore = "蜂巢号的蜂后将无人机视为自己的孩子。她说它们比任何武器都更可靠。\n\n「子弹会偏离，导弹会被拦截，但我的孩子们永远不会背叛我。」",
        effect = function(p)
            p.engineering = (p.engineering or 0) + 6
            p.meleeDamageBonus = (p.meleeDamageBonus or 0) - 3
        end,
    },
    
    -- ========================================================================
    -- 火控模块 - 范围类
    -- ========================================================================
    
    -- 远程瞄具（无代价入门道具）
    {
        id = "long_range_scope",
        name = "远程瞄具",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "火力范围+0.5",
        price = 15,
        maxStack = 4,
        rarity = 1,
        lore = "「如果你能看到敌人，敌人也能看到你。所以，看得更远一点。」\n\n——帝国狙击手训练手册第一章",
        effect = function(p)
            p.attackRange = (p.attackRange or 0) + 0.5
        end,
    },
    
    -- 扩展感知
    {
        id = "extended_sensors",
        name = "扩展感知",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T1,
        description = "火力范围+1,拾取范围+0.5,最大护盾-3",
        price = 25,
        maxStack = 3,
        rarity = 1,
        lore = "这套感知系统会将部分护盾能量重定向到传感器阵列，换取更广阔的战场视野。\n\n「看得更多，意味着暴露更多。」——幽灵号舰长语录",
        effect = function(p)
            p.attackRange = (p.attackRange or 0) + 1.0
            p.pickupRange = (p.pickupRange or 0) + 0.5
            p.maxShield = p.maxShield - 3
        end,
    },
    
    -- 超远距离
    {
        id = "ultra_range",
        name = "超远距离",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T2,
        description = "火力范围+1.5,射击频率-5%",
        price = 40,
        maxStack = 2,
        rarity = 2,
        lore = "帝国边境巡逻队的标准配置，用于在敌人进入有效射程前开火。\n\n「先手优势，」巡逻队长常说，「是唯一能弥补数量劣势的东西。」",
        effect = function(p)
            p.attackRange = (p.attackRange or 0) + 1.5
            p.fireRateMultiplier = p.fireRateMultiplier - 0.05
        end,
    },
    
    -- 鹰眼系统
    {
        id = "eagle_eye",
        name = "鹰眼系统",
        type = Modules.Types.FIRE_CONTROL,
        tier = Modules.Tiers.T3,
        description = "每10火力范围+1%伤害,引擎推力-5%",
        price = 55,
        maxStack = 2,
        rarity = 3,
        lore = "传说中的「千里眼」维克多的神经植入物。它让使用者能够感知极远距离的目标，并将这种感知转化为杀伤力。\n\n「在我眼中，星星不过是更远的靶子。」——维克多·千里眼",
        effect = function(p)
            p.hasEagleEye = true
            p.eagleEyeDamagePerRange = 0.001  -- +1% per 10 range = 0.001 per 1 range
            p.moveSpeed = p.moveSpeed * 0.95
        end,
    },
    }
end

return register
