-- ============================================================================
-- 星河战姬 Starkyries - 防御模块配置
-- ============================================================================

local function register(Modules)
    return {
    -- 防御模块 - 护盾类
    -- ========================================================================
    
    -- 护盾强化（无代价入门道具）
    {
        id = "shield_boost",
        name = "护盾强化",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T1,
        description = "最大护盾+8",
        price = 15,
        maxStack = 5,
        rarity = 1,
        lore = "帝国标准护盾模块。每一艘出厂的战舰都会配备至少一个。\n\n「护盾是舰船的皮肤，」教官们说，「失去它，你就赤身裸体地面对宇宙。」",
        effect = function(p)
            p.maxShield = p.maxShield + 8
            p.shield = math.min(p.shield + 8, p.maxShield)
        end,
    },
    
    -- 活力核心
    {
        id = "vitality_core",
        name = "活力核心",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T1,
        description = "最大护盾+5%基于当前最大护盾,引擎推力-2%",
        price = 25,
        maxStack = 4,
        rarity = 1,
        lore = "一种自适应护盾技术，能够根据现有护盾强度进行增幅。代价是额外的质量。\n\n「越厚的盾，越重的负担。」——堡垒号设计师手记",
        effect = function(p)
            local bonus = math.floor(p.maxShield * 0.05)
            p.maxShield = p.maxShield + bonus
            p.shield = math.min(p.shield + bonus, p.maxShield)
            p.moveSpeed = p.moveSpeed * 0.98
        end,
    },
    
    -- 能量屏障（无代价）
    {
        id = "energy_barrier",
        name = "能量屏障",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T2,
        description = "最大护盾+15,护盾再生+1",
        price = 35,
        maxStack = 3,
        rarity = 2,
        lore = "机械叛军的护盾技术往往比帝国更先进。这种能量屏障不仅容量更大，还能自我修复。\n\n「他们说我们是叛军，」一位机械工程师说，「但我们只是选择了更好的道路。」",
        effect = function(p)
            p.maxShield = p.maxShield + 15
            p.shield = math.min(p.shield + 15, p.maxShield)
            p.shieldRegen = p.shieldRegen + 1
        end,
    },
    
    -- 护盾转化
    {
        id = "shield_convert",
        name = "护盾转化",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T2,
        description = "最大护盾+2每1装甲,规避-3%",
        price = 35,
        maxStack = 2,
        rarity = 2,
        lore = "将装甲的物理防护转化为护盾的能量防护。虽然会降低机动性，但提供了更厚实的保护。\n\n「我宁愿挨一百发打在盾上，也不愿挨一发打在甲上。」——铁壁号舰长",
        effect = function(p)
            local bonus = p.armor * 2
            p.maxShield = p.maxShield + bonus
            p.shield = math.min(p.shield + bonus, p.maxShield)
            p.dodgeChance = p.dodgeChance - 0.03
        end,
    },
    
    -- 重型护盾
    {
        id = "heavy_shield",
        name = "重型护盾",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T2,
        description = "最大护盾+25,引擎推力-5%",
        price = 40,
        maxStack = 3,
        rarity = 2,
        lore = "帝国旗舰级护盾发生器。它的重量足以让小型战舰减速，但提供的防护也是无与伦比的。\n\n堡垒号的林德曼说：「速度？活着比跑得快更重要。」",
        effect = function(p)
            p.maxShield = p.maxShield + 25
            p.shield = math.min(p.shield + 25, p.maxShield)
            p.moveSpeed = p.moveSpeed * 0.95
        end,
    },
    
    -- 紧急护盾
    {
        id = "emergency_shield",
        name = "紧急护盾",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T3,
        description = "护盾归0时回复15护盾(每波1次),最大护盾-5",
        price = 55,
        maxStack = 2,
        rarity = 3,
        lore = "濒死时刻启动的应急系统。它会消耗备用能源为护盾充能，给驾驶员最后一次机会。\n\n「第二次生命，」幸存者们这样称呼它，「但只有一次。」",
        effect = function(p)
            p.hasEmergencyShield = true
            p.emergencyShieldAmount = 15
            p.maxShield = p.maxShield - 5
        end,
    },
    
    -- ========================================================================
    -- 防御模块 - 护盾再生类
    -- ========================================================================
    
    -- 再生器（无代价入门道具）
    {
        id = "regenerator",
        name = "再生器",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T1,
        description = "护盾再生+2",
        price = 20,
        maxStack = 5,
        rarity = 1,
        lore = "基础护盾再生模块，能够缓慢修复战斗中受损的能量护盾。\n\n「时间站在防守者这边，」老兵们说，「只要你能撑得够久。」",
        effect = function(p)
            p.shieldRegen = p.shieldRegen + 2
        end,
    },
    
    -- 战斗修复
    {
        id = "combat_repair",
        name = "战斗修复",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T1,
        description = "击毁敌舰时回复1护盾,最大护盾-4",
        price = 25,
        maxStack = 2,
        rarity = 1,
        lore = "从被击毁的敌舰中回收能量的技术。虽然会削弱护盾总量，但在激烈的战斗中反而更有效。\n\n「以战养战，」狂战号的艾丽卡说，「敌人的死亡就是我的补给。」",
        effect = function(p)
            p.killHeal = (p.killHeal or 0) + 1
            p.maxShield = p.maxShield - 4
        end,
    },
    
    -- 快速修复
    {
        id = "quick_repair",
        name = "快速修复",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T2,
        description = "护盾再生+5,装甲-1",
        price = 30,
        maxStack = 3,
        rarity = 2,
        lore = "通过削弱装甲结构来为护盾再生系统提供更多能量。\n\n「装甲修复需要船坞，护盾只需要几秒钟。」——流浪舰队维修手册",
        effect = function(p)
            p.shieldRegen = p.shieldRegen + 5
            p.armor = p.armor - 1
        end,
    },
    
    -- 纳米修复（无代价）
    {
        id = "nano_repair",
        name = "纳米修复",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T2,
        description = "护盾再生+3,战斗中持续生效",
        price = 40,
        maxStack = 3,
        rarity = 2,
        lore = "微型纳米机器人群在护盾层中游弋，实时修补能量裂隙。\n\n这项技术来自创世遗迹的残骸——据说是人类远古文明的遗产。",
        effect = function(p)
            p.shieldRegen = p.shieldRegen + 3
            p.hasNanoRepair = true
        end,
    },
    
    -- 充能器
    {
        id = "charger",
        name = "充能器",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T3,
        description = "5秒未受伤后,护盾再生×3,射击频率-5%",
        price = 50,
        maxStack = 2,
        rarity = 3,
        lore = "一种「战术喘息」技术。当战舰脱离战斗时，系统会将所有能量集中到护盾再生上。\n\n「有时候，撤退只是为了更凶猛地进攻。」——守护者号舰长",
        effect = function(p)
            p.hasCharger = true
            p.chargerRegenMultiplier = 3
            p.chargerDelay = 5.0
            p.fireRateMultiplier = p.fireRateMultiplier - 0.05
        end,
    },
    
    -- ========================================================================
    -- 防御模块 - 能量吸收类（对标Brotato生命偷取）
    -- ========================================================================
    
    -- 能量吸取器（无代价入门道具）
    {
        id = "energy_siphon",
        name = "能量吸取器",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T1,
        description = "能量吸收+2%",
        price = 20,
        maxStack = 6,
        rarity = 1,
        lore = "将敌舰爆炸释放的能量转化为护盾补充。一种残酷但有效的生存方式。\n\n「每一个敌人的死亡，都是我活下去的理由。」——流浪舰队格言",
        effect = function(p)
            p.energyAbsorb = p.energyAbsorb + 0.02
        end,
    },
    
    -- 虹吸核心
    {
        id = "siphon_core",
        name = "虹吸核心",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T2,
        description = "能量吸收+3%,最大护盾-5",
        price = 35,
        maxStack = 4,
        rarity = 2,
        lore = "一种更激进的能量吸收技术。它会削弱护盾发生器的容量，但大幅提高吸收效率。\n\n猎人号的戴安娜·阿尔忒弥斯偏爱这种风格：「护盾是借来的，杀敌是赚来的。」",
        effect = function(p)
            p.energyAbsorb = p.energyAbsorb + 0.03
            p.maxShield = p.maxShield - 5
        end,
    },
    
    -- 血色护盾
    {
        id = "blood_shield",
        name = "血色护盾",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T2,
        description = "能量吸收+4%,护盾再生-2",
        price = 45,
        maxStack = 3,
        rarity = 2,
        lore = "这种护盾会呈现出诡异的红色光芒，因为它从敌舰的毁灭中汲取能量。\n\n「美丽吗？」梅杜莎·蛇瞳问她的俘虏，「那是你同伴的颜色。」",
        effect = function(p)
            p.energyAbsorb = p.energyAbsorb + 0.04
            p.shieldRegen = p.shieldRegen - 2
        end,
    },
    
    -- 虹吸系统
    {
        id = "siphon_system",
        name = "虹吸系统",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T3,
        description = "能量吸收+3%,暴击时额外+3%,精确打击-3%",
        price = 55,
        maxStack = 2,
        rarity = 3,
        lore = "原生者的生物技术与人类科技的融合产物。它在致命一击时能够吸收更多能量。\n\n「他们不是怪物，」研究员在笔记中写道，「他们只是用不同的方式生存。」",
        effect = function(p)
            p.energyAbsorb = p.energyAbsorb + 0.03
            p.hasSiphonSystem = true
            p.siphonSystemCritBonus = 0.03
            p.critChance = p.critChance - 0.03
        end,
    },
    
    -- 噬能者（唯一）
    {
        id = "energy_eater",
        name = "噬能者",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T3,
        description = "能量吸收回复量+50%,最大护盾-8",
        price = 65,
        maxStack = 1,
        rarity = 3,
        isUnique = true,
        lore = "据说这个模块来自一艘被原生者寄生的帝国战舰。它会「吃掉」周围的能量，包括自己的护盾。\n\n「它在呼吸，」工程师颤抖着说，「它还活着。」",
        effect = function(p)
            p.energyAbsorbEfficiency = (p.energyAbsorbEfficiency or 1) + 0.50
            p.maxShield = p.maxShield - 8
        end,
    },
    
    -- 吸血鬼协议（唯一）
    {
        id = "vampire_protocol",
        name = "吸血鬼协议",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T3,
        description = "能量吸收+5%,无法使用修复包",
        price = 70,
        maxStack = 1,
        rarity = 3,
        isUnique = true,
        lore = "一种极端的生存哲学：完全依赖从敌人身上夺取的能量，放弃所有外部补给。\n\n血蝶号的卡蜜拉·诺斯菲拉图将此视为一种信仰：「我不需要怜悯，只需要猎物。」",
        effect = function(p)
            p.energyAbsorb = p.energyAbsorb + 0.05
            p.canUseRepairPack = false
        end,
    },
    
    -- ========================================================================
    -- 防御模块 - 装甲类
    -- ========================================================================
    
    -- 装甲板
    {
        id = "armor_plate",
        name = "装甲板",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T2,
        description = "装甲+2,火力输出-3%",
        price = 40,
        maxStack = 4,
        rarity = 2,
        lore = "额外焊接的装甲板会增加战舰重量，降低武器系统的能量分配。但对于坚信「皮厚血长」的舰长来说，这是值得的交换。\n\n「我的船比你的炮塔还硬。」——铁壁号舰长",
        effect = function(p)
            p.armor = p.armor + 2
            p.damageMultiplier = p.damageMultiplier - 0.03
        end,
    },
    
    -- 模块化装甲
    {
        id = "modular_armor",
        name = "模块化装甲",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T2,
        description = "每2装甲+1%伤害,最大护盾-5",
        price = 35,
        maxStack = 2,
        rarity = 2,
        lore = "机械叛军的创新设计：装甲不仅是防护，也是武器系统的一部分。越厚的装甲，越强的火力。\n\n「我们不再分离攻防，」叛军工程师说，「我们让它们成为一体。」",
        effect = function(p)
            p.hasModularArmor = true
            p.modularArmorDamagePerArmor = 0.005  -- +1% per 2 armor = 0.5% per 1 armor
            p.maxShield = p.maxShield - 5
        end,
    },
    
    -- 钛合金外壳
    {
        id = "titanium_hull",
        name = "钛合金外壳",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T2,
        description = "装甲+3,规避-5%",
        price = 50,
        maxStack = 2,
        rarity = 2,
        lore = "帝国重型战列舰的标准装甲材料。它能承受巨大的伤害，但也让战舰变得笨重。\n\n「我们不躲避，我们承受。」——帝国战列舰队座右铭",
        effect = function(p)
            p.armor = p.armor + 3
            p.dodgeChance = p.dodgeChance - 0.05
        end,
    },
    
    -- 反应装甲
    {
        id = "reactive_armor",
        name = "反应装甲",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T3,
        description = "装甲+3,受伤时返还2伤害,火力输出-3%",
        price = 55,
        maxStack = 2,
        rarity = 3,
        lore = "一种会「咬回去」的装甲。当受到攻击时，它会释放爆炸反冲，伤害攻击者。\n\n「打我？先问问我的装甲同不同意。」——使用者评价",
        effect = function(p)
            p.armor = p.armor + 3
            p.hasReactiveArmor = true
            p.reactiveArmorDamage = 2
            p.damageMultiplier = p.damageMultiplier - 0.03
        end,
    },
    
    -- 重型装甲
    {
        id = "heavy_armor",
        name = "重型装甲",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T3,
        description = "装甲+4,引擎推力-10%",
        price = 65,
        maxStack = 2,
        rarity = 3,
        lore = "帝国无畏舰的装甲残片，足以覆盖一艘小型护卫舰的整个船体。\n\n堡垒号的林德曼将其视为荣誉：「这是从泰坦号残骸上拆下来的。它保护过成千上万的人。现在它保护我。」",
        effect = function(p)
            p.armor = p.armor + 4
            p.moveSpeed = p.moveSpeed * 0.90
        end,
    },
    
    -- ========================================================================
    -- 防御模块 - 规避类
    -- ========================================================================
    
    -- 规避系统（无代价入门道具）
    {
        id = "evasion_system",
        name = "规避系统",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T1,
        description = "规避率+5%",
        price = 30,
        maxStack = 4,
        rarity = 1,
        lore = "「最好的防御不是挡住攻击，而是根本不被击中。」\n\n疾风号的风间美月将这句话奉为圭臬。她的战舰从未被正面击中过——至少官方记录是这样写的。",
        effect = function(p)
            p.dodgeChance = p.dodgeChance + 0.05
        end,
    },
    
    -- 闪避大师
    {
        id = "dodge_master",
        name = "闪避大师",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T2,
        description = "规避率+8%,最大护盾-10%",
        price = 50,
        maxStack = 2,
        rarity = 2,
        lore = "放弃一部分护盾能量来增强机动系统。这是一种「要么躲开，要么去死」的哲学。\n\n幻影号的镜花水月是这种风格的代表：「护盾只是心理安慰。真正的安全，是敌人永远打不中你。」",
        effect = function(p)
            p.dodgeChance = p.dodgeChance + 0.08
            local reduction = math.floor(p.maxShield * 0.10)
            p.maxShield = p.maxShield - reduction
        end,
    },
    
    -- 相位装置
    {
        id = "phase_device",
        name = "相位装置",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T2,
        description = "规避率+8%,装甲-2",
        price = 45,
        maxStack = 2,
        rarity = 2,
        lore = "据说这项技术来自创世遗迹。它能让战舰短暂地「相位偏移」，让攻击穿过船体而不造成伤害。\n\n「就像鬼魂一样，」使用者说，「子弹从我身体里穿过。」",
        effect = function(p)
            p.dodgeChance = p.dodgeChance + 0.08
            p.armor = p.armor - 2
        end,
    },
    
    -- 紧急规避
    {
        id = "emergency_dodge",
        name = "紧急规避",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T2,
        description = "护盾<30%时规避+20%,火力输出-3%",
        price = 45,
        maxStack = 2,
        rarity = 2,
        lore = "濒死状态下的本能反应被程序化。当护盾即将耗尽时，系统会将所有能量转移到机动系统。\n\n「绝境激发潜能，」幸存者们说，「当死亡在眼前时，你会变得出奇的灵活。」",
        effect = function(p)
            p.hasEmergencyDodge = true
            p.emergencyDodgeThreshold = 0.30
            p.emergencyDodgeBonus = 0.20
            p.damageMultiplier = p.damageMultiplier - 0.03
        end,
    },
    
    -- 幻影模块（无代价T3稀有）
    {
        id = "phantom_module",
        name = "幻影模块",
        type = Modules.Types.DEFENSE,
        tier = Modules.Tiers.T3,
        description = "规避率+6%,受伤后获得+15%规避3秒",
        price = 55,
        maxStack = 2,
        rarity = 3,
        lore = "幻影号的核心系统。每次受伤后，它会激活一种「残影」模式，让战舰变得更加难以捕捉。\n\n镜花水月说：「疼痛让我更加清醒。每一次被击中，都让我更难被再次击中。」",
        effect = function(p)
            p.dodgeChance = p.dodgeChance + 0.06
            p.hasPhantomModule = true
            p.phantomDodgeBonus = 0.15
            p.phantomDuration = 3.0
        end,
    },
    }
end

return register
