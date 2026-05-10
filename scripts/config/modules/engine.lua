-- ============================================================================
-- 星河战姬 Starkyries - 引擎模块配置（速度/运势/资源/拾取）
-- ============================================================================

local function register(Modules)
    return {
    -- 引擎模块 - 速度类
    -- ========================================================================
    
    -- 推进器（无代价入门道具）
    {
        id = "thruster",
        name = "推进器",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T1,
        description = "引擎推力+5%",
        price = 15,
        maxStack = 4,
        rarity = 1,
        lore = "基础推进器模块，能够小幅提升战舰的机动性。\n\n「速度决定生死，」飞行教官常说，「慢一秒可能就是最后一秒。」",
        effect = function(p)
            p.moveSpeed = p.moveSpeed * 1.05
        end,
    },
    
    -- 加速踏板
    {
        id = "accelerator",
        name = "加速踏板",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T1,
        description = "引擎推力+8%,装甲-1",
        price = 22,
        maxStack = 3,
        rarity = 1,
        lore = "拆除部分装甲来减轻重量，换取更高的加速度。流浪舰队的拾荒者们最爱这种改装。\n\n「跑得快比打得过更重要，」他们说，「活着才能花钱。」",
        effect = function(p)
            p.moveSpeed = p.moveSpeed * 1.08
            p.armor = p.armor - 1
        end,
    },
    
    -- 涡轮引擎（无代价）
    {
        id = "turbo_engine",
        name = "涡轮引擎",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T2,
        description = "引擎推力+10%",
        price = 40,
        maxStack = 2,
        rarity = 2,
        lore = "帝国赛车联盟的违禁改装件。它能让战舰达到危险的高速。\n\n疾风号的风间美月在黑市上收购了一批：「规则是给慢吞吞的人定的。」",
        effect = function(p)
            p.moveSpeed = p.moveSpeed * 1.10
        end,
    },
    
    -- 离子推进
    {
        id = "ion_propulsion",
        name = "离子推进",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T2,
        description = "引擎推力+8%,规避+3%,最大护盾-5",
        price = 40,
        maxStack = 2,
        rarity = 2,
        lore = "机械叛军的尖端推进技术。它不仅提供速度，还能产生干扰敌方锁定的离子尾迹。\n\n「追不上，也打不中。」——叛军飞行员评价",
        effect = function(p)
            p.moveSpeed = p.moveSpeed * 1.08
            p.dodgeChance = p.dodgeChance + 0.03
            p.maxShield = p.maxShield - 5
        end,
    },
    
    -- 速度狂魔
    {
        id = "speed_demon",
        name = "速度狂魔",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T3,
        description = "每5%速度+2%伤害,最大护盾-8",
        price = 55,
        maxStack = 2,
        rarity = 3,
        lore = "一种将动能转化为武器威力的疯狂技术。你飞得越快，打得越痛。\n\n「我就是我的武器，」疾风号的风间美月说，「速度就是力量。」",
        effect = function(p)
            p.hasSpeedDemon = true
            p.speedDemonDamagePerSpeed = 0.004  -- +2% per 5% speed = 0.4% per 1% speed
            p.maxShield = p.maxShield - 8
        end,
    },
    
    -- ========================================================================
    -- 引擎模块 - 运势类
    -- ========================================================================
    
    -- 幸运芯片（无代价入门道具）
    {
        id = "lucky_chip",
        name = "幸运芯片",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T1,
        description = "战场运势+8",
        price = 25,
        maxStack = 4,
        rarity = 1,
        lore = "一种据说能够影响量子概率的神秘芯片。没人知道它是否真的有效，但每个舰长都想要一个。\n\n「我不迷信，」他们说，「但我不会拒绝好运。」",
        effect = function(p)
            p.luck = (p.luck or 0) + 8
        end,
    },
    
    -- 量子概率核心
    {
        id = "quantum_probability_core",
        name = "量子概率核心",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T2,
        description = "战场运势+20,火力输出-5%",
        price = 48,
        maxStack = 2,
        rarity = 2,
        lore = "创世遗迹中发现的神秘装置，似乎能够扭曲概率本身。但它会消耗部分武器能量来维持运作。\n\n「命运是可以被计算的，」机械叛军的「先知」曾说，「只要你有足够的算力。」",
        effect = function(p)
            p.luck = (p.luck or 0) + 20
            p.damageMultiplier = p.damageMultiplier - 0.05
        end,
    },
    
    -- 幸运算法模块（无代价）
    {
        id = "lucky_algorithm",
        name = "幸运算法模块",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T2,
        description = "战场运势+20",
        price = 45,
        maxStack = 2,
        rarity = 2,
        lore = "机械叛军工程师编写的「概率优化算法」。它不改变物理定律，只是让有利的结果更可能发生。\n\n「我们不相信运气，」他们说，「我们创造运气。」",
        effect = function(p)
            p.luck = (p.luck or 0) + 20
        end,
    },
    
    -- 财运亨通
    {
        id = "fortune",
        name = "财运亨通",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T3,
        description = "战场运势+15,击毁时5%几率+3晶体,最大护盾-5",
        price = 55,
        maxStack = 2,
        rarity = 3,
        lore = "流浪舰队的商人们发誓说这个模块能带来财富。它确实能够从敌舰残骸中提取更多晶体。\n\n黄金号的艾达·财神相信它：「财富是战斗力的一部分。有钱才能买更好的装备。」",
        effect = function(p)
            p.luck = (p.luck or 0) + 15
            p.hasFortune = true
            p.fortuneCrystalChance = 0.05
            p.fortuneCrystalAmount = 3
            p.maxShield = p.maxShield - 5
        end,
    },
    
    -- 欧皇体质（唯一）
    {
        id = "lucky_body",
        name = "欧皇体质",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T3,
        description = "战场运势+30,射击频率-5%",
        price = 70,
        maxStack = 1,
        rarity = 3,
        isUnique = true,
        lore = "传说中的「天选之人」体质。据说拥有它的人会在最关键的时刻遇到最好的运气。\n\n「我不是技术最好的，」幸运儿号的杰克·幸运星说，「但我总能在对的时间出现在对的地方。」",
        effect = function(p)
            p.luck = (p.luck or 0) + 30
            p.fireRateMultiplier = p.fireRateMultiplier - 0.05
        end,
    },
    
    -- ========================================================================
    -- 引擎模块 - 资源类
    -- ========================================================================
    
    -- 资源回收器（无代价入门道具）
    {
        id = "resource_collector",
        name = "资源回收器",
        type = Modules.Types.RESOURCE,
        tier = Modules.Tiers.T1,
        description = "资源回收+8%",
        price = 15,
        maxStack = 5,
        rarity = 1,
        lore = "流浪舰队的生存之道：不放过任何一点资源。\n\n「在星海中漂泊，浪费是最大的罪过。」——舰队补给手册",
        effect = function(p)
            p.crystalMultiplier = p.crystalMultiplier + 0.08
        end,
    },
    
    -- 高效回收
    {
        id = "efficient_harvest",
        name = "高效回收",
        type = Modules.Types.RESOURCE,
        tier = Modules.Tiers.T1,
        description = "资源回收+12,最大护盾-3",
        price = 25,
        maxStack = 3,
        rarity = 1,
        lore = "将部分护盾能量转移到资源回收系统，提高晶体提取效率。\n\n「安全很重要，但吃饭更重要。」——拾荒者格言",
        effect = function(p)
            p.crystalBonus = (p.crystalBonus or 0) + 12
            p.maxShield = p.maxShield - 3
        end,
    },
    
    -- 危险兔子（无代价）
    {
        id = "dangerous_bunny",
        name = "危险兔子",
        type = Modules.Types.RESOURCE,
        tier = Modules.Tiers.T2,
        description = "+1次免费刷新（每波）",
        price = 30,
        maxStack = 3,
        rarity = 2,
        lore = "一个古怪的AI助手，据说是某位疯狂科学家的作品。它能够在补给站免费刷新商品列表。\n\n「别问我是怎么做到的，」它说，「你只需要知道我可以。」",
        effect = function(p)
            p.freeRefreshes = (p.freeRefreshes or 0) + 1
            p.freeRefreshesRemaining = (p.freeRefreshesRemaining or 0) + 1
        end,
    },
    
    -- 磁力牵引
    {
        id = "magnetic_tractor",
        name = "磁力牵引",
        type = Modules.Types.RESOURCE,
        tier = Modules.Tiers.T2,
        description = "资源回收+15,拾取范围+1.0,射击频率-3%",
        price = 40,
        maxStack = 2,
        rarity = 2,
        lore = "强力磁场发生器，能够将更远距离的资源吸引过来。\n\n拾荒者联盟的标准装备：「资源像铁屑一样飞向我们。」",
        effect = function(p)
            p.crystalBonus = (p.crystalBonus or 0) + 15
            p.pickupRange = (p.pickupRange or 0) + 1.0
            p.fireRateMultiplier = p.fireRateMultiplier - 0.03
        end,
    },
    
    -- 过载回收系统
    {
        id = "overload_collector",
        name = "过载回收系统",
        type = Modules.Types.RESOURCE,
        tier = Modules.Tiers.T3,
        description = "资源回收+40,火力输出-8%",
        price = 70,
        maxStack = 2,
        rarity = 3,
        lore = "一种极端的资源回收方式，将大部分能量都用于晶体提取。\n\n黄金号的艾达·财神的座右铭：「钱是赚出来的，不是打出来的。」",
        effect = function(p)
            p.crystalBonus = (p.crystalBonus or 0) + 40
            p.damageMultiplier = p.damageMultiplier - 0.08
        end,
    },
    
    -- 经济学家（唯一）
    {
        id = "economist",
        name = "经济学家",
        type = Modules.Types.RESOURCE,
        tier = Modules.Tiers.T3,
        description = "资源回收+20%,补给站-10%价格,火力输出-5%",
        price = 70,
        maxStack = 1,
        rarity = 3,
        isUnique = true,
        lore = "流浪舰队首席经济顾问的数据模型。它能够优化资源配置，并在补给站获得更好的价格。\n\n「战争的胜负，往往在后勤就已经决定了。」——艾达·财神",
        effect = function(p)
            p.crystalMultiplier = p.crystalMultiplier + 0.20
            p.shopDiscount = (p.shopDiscount or 0) + 0.10
            p.damageMultiplier = p.damageMultiplier - 0.05
        end,
    },
    
    -- ========================================================================
    -- 引擎模块 - 拾取类
    -- ========================================================================
    
    -- 扩展感知器（无代价入门道具）
    {
        id = "extended_sensor",
        name = "扩展感知器",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T1,
        description = "拾取范围+1.0",
        price = 15,
        maxStack = 4,
        rarity = 1,
        lore = "增强型传感器阵列，能够探测更远距离的资源信号。\n\n「眼睛看得远，手就伸得远。」——拾荒者谚语",
        effect = function(p)
            p.pickupRange = (p.pickupRange or 0) + 1.0
        end,
    },
    
    -- 磁力场
    {
        id = "magnetic_field",
        name = "磁力场",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T1,
        description = "拾取范围+2.0,最大护盾-2",
        price = 22,
        maxStack = 3,
        rarity = 1,
        lore = "利用护盾能量产生磁场，吸引周围的金属碎片和晶体。\n\n「舍不得护盾，捡不到晶体。」——流浪舰队俗语",
        effect = function(p)
            p.pickupRange = (p.pickupRange or 0) + 2.0
            p.maxShield = p.maxShield - 2
        end,
    },
    
    -- 扩展牵引臂（无代价）
    {
        id = "extended_tractor_arms",
        name = "扩展牵引臂",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T2,
        description = "拾取范围+3.0",
        price = 35,
        maxStack = 2,
        rarity = 2,
        lore = "机械叛军的回收技术。这些能量构成的「手臂」可以伸展到令人惊讶的距离。\n\n「我们不浪费任何东西，」叛军说，「包括敌人的残骸。」",
        effect = function(p)
            p.pickupRange = (p.pickupRange or 0) + 3.0
        end,
    },
    
    -- 吸引器
    {
        id = "attractor",
        name = "吸引器",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T2,
        description = "掉落物自动飞向战舰,火力输出-3%",
        price = 45,
        maxStack = 1,
        rarity = 2,
        lore = "一种能够扭曲局部重力场的装置。所有掉落物都会像被吸引一样飞向战舰。\n\n「就像整个战场都在向我倾斜。」——使用者描述",
        effect = function(p)
            p.hasAttractor = true
            p.damageMultiplier = p.damageMultiplier - 0.03
        end,
    },
    
    -- 超级磁铁（唯一）
    {
        id = "super_magnet",
        name = "超级磁铁",
        type = Modules.Types.ENGINE,
        tier = Modules.Tiers.T4,
        description = "全屏拾取,火力输出-8%",
        price = 95,
        maxStack = 1,
        rarity = 4,
        isUnique = true,
        lore = "创世遗迹中发现的神器。它产生的引力场覆盖整个战场，让所有资源瞬间飞向使用者。\n\n「这不是磁铁，」研究员说，「这是一个微型黑洞。只是它只吸引晶体。」",
        effect = function(p)
            p.hasSuperMagnet = true
            p.damageMultiplier = p.damageMultiplier - 0.08
        end,
    },
    }
end

return register
