-- ============================================================================
-- 星河战姬 Starkyries - 武器配置
-- 垂直切片v1：15种核心武器
-- 数值严格对齐设计文档 2.2-武器数据.md
-- ============================================================================

local Weapons = {}

-- ============================================================================
-- 武器类型定义
-- ============================================================================
Weapons.Types = {
    FORCE_FIELD = "force_field",  -- 近程炮（力场/脉冲，射程5-7m）
    ARC = "arc",                  -- 电弧系（射程6m）
    MACHINEGUN = "machinegun",    -- 机炮系（射程10m，高射速连发）
    MISSILE = "missile",          -- 导弹系（射程20-40m）
    LASER = "laser",              -- 激光系（射程8-50m）
    CARRIER = "carrier",          -- 舰载机（全图追踪）
}

-- 武器类型显示名称（UI用，与 Types 保持同步）
Weapons.TypeNames = {
    [Weapons.Types.FORCE_FIELD] = "近程",   -- 力场类 → 近程伤害
    [Weapons.Types.ARC] = "近程",           -- 电弧类 → 近程伤害
    [Weapons.Types.MACHINEGUN] = "弹道",    -- 机炮类 → 弹道伤害
    [Weapons.Types.MISSILE] = "弹道",       -- 导弹类 → 弹道伤害
    [Weapons.Types.LASER] = "能量",         -- 激光类 → 能量伤害
    [Weapons.Types.CARRIER] = "舰载",       -- 舰载机类
}

-- 获取武器类型显示名称
function Weapons.GetTypeName(weaponType)
    return Weapons.TypeNames[weaponType] or "未知"
end

-- ============================================================================
-- 射程分类说明（供AI和开发者理解）
-- ============================================================================
--[[
射程设计原则：
  - 战场可视范围约 50×30 米
  - 近程必须让玩家感受到"需要冒险贴近敌人"
  - 射程差异要在视觉上明显可辨

实际射程配置（2024-12-31 更新）：

近程武器（≤8m，贴身战斗）：
  - 力场系列 → 5m：几乎贴脸才能打到
  - 电弧系列 → 6m：需要非常近
  - 脉冲系列 → 7m：略远一点但仍是近战
  - 等离子/离子 → 8m：近战型激光

中程武器（9-30m，安全距离）：
  - 导弹系列 → 20-40m：中等安全距离
  - 冷冻射线 → 30m：中程控制

远程武器（>30m，远距离狙击）：
  - 激光炮 → 40m：安全输出
  - 激光狙击 → 50m：最远射程

视觉差异化：
  - 近程（力场/电弧）：使用能量链表现，直接连接敌人
  - 中程（导弹）：追踪弹道、导弹形态、尾焰
  - 远程（激光）：细长光束、即时命中
]]

-- ============================================================================
-- 武器数据（严格按照设计文档）
-- ============================================================================

Weapons.List = {
    -- ========================================================================
    -- 力场系列（射程150 → 15m）- 贴身战斗
    -- 特点：高射速、能量波动视觉、需要近距离
    -- ========================================================================
    
    -- 速射力场 - 基础武器，先锋号初始
    RapidForceField = {
        id = "RapidForceField",
        name = "速射力场",
        nameEn = "Rapid Force Field",
        type = Weapons.Types.FORCE_FIELD,
        tier = 1,
        tags = {"力场"},      -- 套装标签（对应力场套装）
        damage = 8,
        tierDamage = {8, 12, 18, 26},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 0.69,
        critChance = 0.0,
        projectileSpeed = 50.0,
        range = 5.0,          -- 力场：贴脸攻击
        -- 视觉
        color = {r = 0.3, g = 0.8, b = 1.0},  -- 青蓝色能量
        turretSize = 0.25,    -- 小型能量发射器
        projectileSize = 0.4, -- 能量球较大
        trailLength = 0.3,    -- 短尾迹
        -- 经济
        price = 15,           -- 文档：15
        description = "基础近程武器，稳定输出",
        lore = "帝国军校的制式装备，设计之初只为训练新兵。然而，当陆星遥驾驶先锋号冲出包围圈时，这把被嘲笑为'学员玩具'的武器，击落了三架追击舰。\n\n——「她握着这把枪的样子，让我想起了年轻时的自己。」\n　　　　　——亚历珊德拉·凯撒将军，叛逃前夜",
    },
    
    -- 穿透力场 - 猎鹰号初始，高攻速+暴击
    PierceForceField = {
        id = "PierceForceField",
        name = "穿透力场",
        nameEn = "Pierce Force Field",
        type = Weapons.Types.FORCE_FIELD,
        tier = 1,
        tags = {"力场"},      -- 套装标签（对应力场套装）
        damage = 5,
        tierDamage = {5, 8, 11, 16},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 0.46,
        critChance = 0.03,
        projectileSpeed = 55.0,
        range = 5.0,          -- 力场：贴脸攻击
        -- 视觉
        color = {r = 0.5, g = 0.9, b = 1.0},  -- 亮青色
        turretSize = 0.22,
        projectileSize = 0.35,
        trailLength = 0.4,
        -- 经济
        price = 18,           -- 文档：18
        description = "高攻速，+3%暴击率",
        lore = "猎鹰中队的标配武器，为拦截任务特化。其频率经过精密校准，能在敌舰装甲的分子间隙中找到共振点。\n\n云霄在拒绝屠杀平民那天，用这把武器击穿了上级的座舰护盾。她说那是她开过的最准的一枪。",
    },
    
    -- 风暴力场 - 极限攻速
    StormForceField = {
        id = "StormForceField",
        name = "风暴力场",
        nameEn = "Storm Force Field",
        type = Weapons.Types.FORCE_FIELD,
        tier = 1,
        tags = {"力场"},      -- 套装标签（对应力场套装）
        damage = 3,           -- T1基础伤害（文档2026-01-05）
        tierDamage = {3, 4, 6, 9},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 0.25,      -- 极快攻速
        critChance = 0.0,
        projectileSpeed = 60.0,
        range = 5.0,          -- 力场：贴脸攻击
        -- 视觉
        color = {r = 0.4, g = 0.7, b = 1.0},  -- 风暴蓝
        turretSize = 0.2,     -- 最小型
        projectileSize = 0.25,  -- 小弹幕
        trailLength = 0.2,
        -- 经济
        price = 25,           -- 文档：25
        description = "极快射速，弹幕压制",
        lore = "帝国狂战士的疯狂之作。设计者在图纸上写道：「不要问能不能命中，要问敌人能不能躲开。」\n\n艾丽卡·冯·布伦在竞技场使用此武器时，解说员说她像是在编织一张死亡之网。皇室成员的护盾在三秒内被撕成碎片。\n\n那场决斗改变了她的命运。",
    },
    
    -- 协同力场 - 多面号初始，多武器协同
    SynergyForceField = {
        id = "SynergyForceField",
        name = "协同力场",
        nameEn = "Synergy Force Field",
        type = Weapons.Types.FORCE_FIELD,
        tier = 1,
        tags = {"力场"},      -- 套装标签（对应力场套装）（对标Brotato树枝）
        damage = 4,           -- 文档：4
        tierDamage = {4, 6, 9, 13},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 0.58,      -- 文档：0.58s
        critChance = 0.0,
        projectileSpeed = 48.0,
        range = 5.0,          -- 力场：贴脸攻击
        -- 特殊效果
        synergyBonus = 0.12,  -- 每把同ID武器+12%伤害
        -- 视觉
        color = {r = 0.6, g = 0.5, b = 1.0},  -- 紫蓝色
        turretSize = 0.25,
        projectileSize = 0.35,
        trailLength = 0.3,
        -- 经济
        price = 12,           -- 文档：12
        description = "每装备一把+12%火力输出",
        lore = "帝国情报部的秘密项目。多把协同力场会在量子层面产生共振，每一次射击都在强化下一次。\n\n伊芙·千面曾独自携带六把此武器执行刺杀任务。档案显示目标在0.3秒内被击毙，但具体过程被列为最高机密。\n\n如今她知道的太多了，连她自己也成了需要被抹去的秘密。",
    },
    
    -- 护盾冲击 - 击毁叠加护盾
    ShieldBurst = {
        id = "ShieldBurst",
        name = "护盾冲击",
        nameEn = "Shield Burst",
        type = Weapons.Types.FORCE_FIELD,
        tier = 1,
        tags = {"力场"},      -- 套装标签（对应力场套装）
        damage = 10,          -- 文档：10
        tierDamage = {10, 15, 22, 32},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 0.69,      -- 文档：0.69s
        critChance = 0.0,
        projectileSpeed = 50.0,
        range = 5.0,          -- 力场：贴脸攻击
        -- 特殊效果
        shieldOnKill = 1,     -- 击毁+1护盾
        maxShieldStack = 15,  -- 上限15
        -- 视觉
        color = {r = 0.3, g = 0.9, b = 0.6},  -- 护盾绿
        turretSize = 0.28,
        projectileSize = 0.4,
        trailLength = 0.3,
        -- 经济
        price = 25,           -- 文档：25
        description = "击毁叠加护盾(+1，上限15)",
        lore = "普莉西亚·晶华的研究成果——被帝国窃取后量产。这把武器能将敌舰的能量残留转化为护盾。\n\n「每击毁一个敌人，你就偷走了它的一部分生命。」她在逃亡时写道，「我不知道这是科学还是诅咒。」\n\n讽刺的是，正是这把武器让她在追杀中存活至今。",
    },
    
    -- ========================================================================
    -- 脉冲系列（射程200 → 20m）- 中近距离
    -- ========================================================================
    
    -- 冲击脉冲 - 基础脉冲+击退
    ImpulsePulse = {
        id = "ImpulsePulse",
        name = "冲击脉冲",
        nameEn = "Impact Pulse",
        type = Weapons.Types.FORCE_FIELD,
        tier = 1,
        tags = {"力场"},      -- 套装标签（对应力场套装）
        damage = 12,          -- 文档：12
        tierDamage = {12, 18, 25, 36},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 0.69,      -- 文档：0.69s
        critChance = 0.0,
        projectileSpeed = 45.0,
        range = 10.0,         -- 脉冲：近战但稍远（文档：10m）
        -- 特殊效果
        knockback = 1.5,      -- 🔴 新增：击退1.5米（设计文档要求）
        -- 视觉
        color = {r = 1.0, g = 0.7, b = 0.3},  -- 橙黄色脉冲
        turretSize = 0.3,
        projectileSize = 0.5,  -- 脉冲波较大
        trailLength = 0.35,
        -- 经济
        price = 18,           -- 文档：18
        description = "中近距离高伤害脉冲，击退敌舰",
        lore = "最初是矿业公司的采矿工具，用于在小行星表面制造裂缝。边境殖民地的守护者布伦希尔德将其改装为武器。\n\n当帝国舰队来袭时，她用这把武器将敌舰一架架推入小行星带。\n\n「我们没有战舰，」她说，「但我们有石头，有愤怒，还有回家的理由。」",
    },
    
    -- ========================================================================
    -- 电弧系列（射程175 → 18m）- 短距防御
    -- ========================================================================
    
    -- 电弧冲击 - 狂战号初始
    ArcShock = {
        id = "ArcShock",
        name = "电弧冲击",
        nameEn = "Arc Shockwave",
        type = Weapons.Types.ARC,
        tier = 1,
        tags = {"能量"},      -- 套装标签（电弧属于能量套装）
        damage = 15,          -- 文档：15
        tierDamage = {15, 22, 31, 45},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 0.81,      -- 文档：0.81s
        critChance = 0.0,
        projectileSpeed = 55.0,
        range = 8.0,          -- 电弧：短距离（文档：8m）
        -- 特殊效果
        knockback = 0.5,      -- 击退+50%
        -- 视觉
        color = {r = 0.5, g = 0.7, b = 1.0},  -- 电弧蓝
        turretSize = 0.3,
        projectileSize = 0.45,
        trailLength = 0.5,    -- 电弧拖尾
        -- 经济
        price = 22,           -- 文档：22
        description = "电弧攻击，击退敌舰",
        lore = "帝国竞技场的宠儿。电弧在真空中不应该传播，但帝国科学家找到了方法——代价是每一发都在消耗舰体的离子储备。\n\n托尔·雷霆的部落用雷电命名他们的勇士。当帝国吞并他的家园时，他发誓要让征服者尝尝雷霆的滋味。\n\n这把武器，是他誓言的延伸。",
    },
    
    -- 重装电弧 - 堡垒号初始（对标电弧协同）
    HeavyArc = {
        id = "HeavyArc",
        name = "重装电弧",
        nameEn = "Heavy Arc",
        type = Weapons.Types.ARC,
        tier = 1,
        tags = {"能量"},      -- 套装标签（电弧属于能量套装）
        damage = 10,          -- 平衡调整
        tierDamage = {10, 15, 21, 30},  -- T1-T4固定伤害（对标电弧协同）
        cooldown = 0.69,
        critChance = 0.0,
        projectileSpeed = 50.0,
        range = 6.0,          -- 电弧：短距离
        -- 视觉
        color = {r = 0.3, g = 0.6, b = 1.0},
        turretSize = 0.35,
        projectileSize = 0.5,
        trailLength = 0.4,
        -- 经济
        price = 0,            -- 初始武器
        description = "堡垒号初始武器，稳定电弧攻击",
        lore = "堡垒级战舰的标准配置，为防御作战而生。厚重的电弧在敌舰靠近时形成一道不可逾越的屏障。\n\n艾琳·巴斯廷曾用这把武器掩护整个中队撤退。当上级命令她放弃伤员时，她选择了抗命。\n\n「堡垒的意义，」她后来说，「不是保护自己，而是保护身后的人。」",
    },
    
    -- ========================================================================
    -- 机炮系列（射程10m）- 高射速连发
    -- 特点：高射速、中短射程、弹幕压制、受弹道计算机加成（弹道武器）
    -- 对标 Brotato SMG 系列
    -- ========================================================================
    
    -- 粒子机炮 - 击毁+1晶体，资源流核心武器
    -- 对标 Brotato SMG：高射速、低单发伤害、弹幕压制
    ParticleMachinegun = {
        id = "ParticleMachinegun",
        name = "粒子机炮",
        nameEn = "Particle Machinegun",
        type = Weapons.Types.MACHINEGUN,
        tier = 1,
        tags = {"弹道"},  -- 伤害类型标签
        damage = 3,           -- T1基础伤害（兼容旧逻辑）
        tierDamage = {3, 4, 5, 8},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 0.17,      -- 文档：0.17s（~5.9发/秒）
        tierCooldown = {0.17, 0.17, 0.17, 0.15},  -- T4攻速0.15s（文档）
        critChance = 0.01,    -- 对标SMG：1%暴击率
        critMultiplier = 1.5, -- 对标SMG：1.5倍暴击伤害
        projectileSpeed = 70.0,
        range = 10.0,         -- 机炮：中短射程（受弹道计算机加成）
        -- 特殊效果
        crystalOnKill = 1,    -- 🔴 核心：击毁+1晶体
        knockback = 1.0,      -- 中等击退
        -- 视觉
        color = {r = 0.7, g = 0.5, b = 1.0},  -- 粒子紫
        turretSize = 0.25,
        projectileSize = 0.15,  -- 小型弹药（连发视觉）
        trailLength = 0.3,      -- 短曳光尾迹（快速连发）
        -- 经济
        price = 22,           -- 文档：22
        -- DPS ≈ 16.7/s（与原设计相近，但射速感完全不同）
        description = "高射速机炮，击毁敌舰+1晶体",
        lore = "海盗和拾荒者的最爱。这把武器的弹药经过特殊处理，能在击毁敌舰时分离出能量晶体。\n\n莉莉丝·暴风曾是最臭名昭著的海盗之一。她说厌倦了掠夺的生活，但从未放下这把枪。\n\n「晶体是生存的货币，」她耸耸肩，「这和抢劫有什么区别？区别在于我抢的是想杀我的人。」",
    },
    
    -- ========================================================================
    -- 导弹系列（射程300-600 → 30-60m）- 中程追踪
    -- 特点：追踪弹道、中等弹速、需要穿透属性
    -- ========================================================================
    
    -- 速射导弹 - 高射速
    RapidMissile = {
        id = "RapidMissile",
        name = "速射导弹",
        nameEn = "Rapid Missile",
        type = Weapons.Types.MISSILE,
        tier = 1,
        tags = {"弹道"},      -- 伤害类型标签
        damage = 4,           -- 文档：4
        tierDamage = {4, 6, 8, 12},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 0.30,      -- 文档：0.30s
        critChance = 0.0,
        projectileSpeed = 35.0,
        range = 16.0,         -- 中程导弹（文档：16m）
        -- 导弹属性
        homing = false,
        curvedFlight = true,  -- 弧线飞行（非追踪，纯视觉效果）
        pierce = 0,
        -- 视觉
        color = {r = 0.3, g = 0.7, b = 1.0},  -- 导弹蓝
        turretSize = 0.28,
        projectileSize = 0.35,
        trailLength = 0.8,    -- 导弹长尾焰
        -- 经济
        price = 22,           -- 文档：22
        description = "高射速小型导弹",
        lore = "帝国舰队的基础火力配置，产量以亿计算。每一枚导弹的造价不过几个晶体，却能在星海中画出死亡的轨迹。\n\n风间美月因超速驾驶被判处叛国罪的那天，她用这把武器击落了十七枚拦截导弹。\n\n「快，」她说，「是唯一的正义。」",
    },
    
    -- 集束导弹 - 命中后产生6个连锁爆炸
    ClusterMissile = {
        id = "ClusterMissile",
        name = "集束导弹",
        nameEn = "Cluster Missile",
        type = Weapons.Types.MISSILE,
        tier = 1,
        tags = {"弹道", "爆炸"},  -- 伤害类型标签
        damage = 4,           -- 文档：4×6（每个爆炸点伤害）
        tierDamage = {4, 6, 8, 12},  -- T1-T4固定伤害（每个爆炸点）
        tierCooldown = {0.81, 0.81, 0.81, 0.72},  -- T1-T3: 0.81s, T4: 0.72s
        cooldown = 0.81,      -- 基础冷却时间
        critChance = 0.0,
        projectileSpeed = 25.0,  -- 飞行速度 25 m/s
        range = 12.0,         -- 文档：12m
        -- 导弹属性
        homing = false,
        curvedFlight = true,  -- 弧线飞行（非追踪，纯视觉效果）
        pierce = 0,
        -- 集束爆炸属性
        clusterExplosion = true,      -- 启用集束爆炸
        clusterCount = 6,             -- 6个爆炸点
        clusterRadius = 0.5,          -- 每个爆炸点半径0.5m
        clusterSpread = 1.5,          -- 爆炸点分布范围1.5m
        clusterDelay = 0.05,          -- 每个爆炸间隔0.05秒
        -- 视觉
        color = {r = 0.4, g = 0.8, b = 1.0},  -- 集束青蓝
        turretSize = 0.35,
        projectileSize = 0.35,  -- 单发导弹稍大
        trailLength = 0.8,
        -- 经济
        price = 25,           -- 文档：25
        description = "命中后产生6个连锁爆炸",
        lore = "星火·诺娃的杰作——也是让她被通缉的原因。一枚导弹携带六个独立弹头，在目标区域绽放成死亡之花。\n\n「实验室爆炸是意外，」她坚持说，「但爆炸本身是艺术。」\n\n帝国研究所不这么认为。他们派出了三支追杀队，至今没有一支回来。",
    },
    
    -- 追踪导弹 - 强追踪
    HomingMissile = {
        id = "HomingMissile",
        name = "追踪导弹",
        nameEn = "Homing Missile",
        type = Weapons.Types.MISSILE,
        tier = 1,
        tags = {"弹道"},      -- 伤害类型标签
        damage = 5,           -- 文档：5（2026-01-05更新）
        tierDamage = {5, 8, 11, 16},  -- T1-T4固定伤害（文档2026-01-05）
        tierCooldown = {0.61, 0.61, 0.61, 0.52},  -- T4攻速0.52s
        cooldown = 0.61,      -- 文档：0.61s
        critChance = 0.0,
        projectileSpeed = 28.0,  -- 追踪弹稍慢
        tierRange = {12.0, 13.0, 14.0, 15.0},  -- 射程随Tier增加
        range = 12.0,         -- 追踪导弹（中近程起始）
        -- 导弹属性
        homing = true,
        homingStrength = 6.0,  -- 强追踪
        pierce = 0,
        -- 视觉
        color = {r = 0.5, g = 0.9, b = 1.0},  -- 追踪亮青
        turretSize = 0.32,
        projectileSize = 0.4,
        trailLength = 1.0,    -- 追踪长尾
        -- 经济
        price = 22,           -- 文档：22
        description = "自动追踪最近敌人",
        lore = "机械叛军的标志性武器。每一枚导弹内置的追踪AI都是从帝国战舰上觉醒的碎片意识。\n\n零·伊芙说，这些导弹会「选择」自己的目标。有时它们会绕过军舰，直奔后方的补给船。\n\n「它们记得，」她解释道，「记得谁下达了灭绝指令。」",
    },
    
    -- ========================================================================
    -- 巨炮系列 - 战舰主炮发射的高穿透炮弹
    -- 特点：高单发伤害、自带穿透、弱追踪（弹道为主）
    -- 对标 Brotato：Crossbow（十字弓）、Sniper（狙击枪）
    -- ========================================================================
    
    -- 狙击弹 - 精准高暴击
    LightTorpedo = {
        id = "LightTorpedo",
        name = "狙击弹",
        nameEn = "Sniper Shell",
        type = Weapons.Types.MISSILE,
        tier = 1,
        tags = {"弹道", "精准"},  -- 伤害类型标签（高暴击）
        damage = 18,          -- 文档：18
        tierDamage = {18, 27, 38, 54},  -- T1-T4固定伤害
        cooldown = 0.92,      -- 文档：0.92s
        critChance = 0.05,    -- 文档：5%
        critDamageBonus = 0.5,-- 暴击伤害+50%
        projectileSpeed = 35.0,  -- 高速弹道（炮弹更快）
        range = 24.0,         -- 射程：24m
        -- 炮弹属性（直射弹道，无追踪）
        homing = false,       -- 炮弹不追踪，直射弹道
        pierce = 1,           -- 穿透1
        -- 视觉（金黄色炮弹）
        color = {r = 1.0, g = 0.8, b = 0.3},  -- 金黄色（炮弹发热）
        turretSize = 0.38,
        projectileSize = 0.45,   -- 细长炮弹
        trailLength = 0.8,       -- 短尾焰（炮弹而非导弹）
        -- 经济
        price = 22,           -- 文档：22
        description = "精准狙击炮弹，高暴击伤害",
        lore = "狙击号战舰的标配武器，每一发都经过精密计算。\n\n「在战场上，一发入魂比乱枪扫射更有效率。」——狙击手守则第一条",
    },
    
    -- 主炮弹 - 高伤害高穿透
    HeavyTorpedo = {
        id = "HeavyTorpedo",
        name = "主炮弹",
        nameEn = "Main Cannon Shell",
        type = Weapons.Types.MISSILE,
        tier = 1,
        tags = {"弹道", "重型"},  -- 伤害类型标签（高单发伤害）
        damage = 35,          -- 文档：35
        tierDamage = {35, 52, 73, 105},  -- T1-T4固定伤害
        cooldown = 1.50,      -- 文档：1.50s
        critChance = 0.10,    -- 10%暴击
        projectileSpeed = 20.0,  -- 文档：20.0
        range = 32.0,         -- 射程：32m
        -- 炮弹属性（直射弹道，无追踪）
        homing = false,       -- 炮弹不追踪，直射弹道
        pierce = 3,           -- 穿透3
        aoeRadius = 3.0,      -- 文档：3.0
        -- 视觉（橙红色重型炮弹）
        color = {r = 1.0, g = 0.5, b = 0.2},  -- 橙红色（高温炮弹）
        turretSize = 0.38,       -- 大型炮塔（收敛尺寸差异）
        projectileSize = 0.7,    -- 大型炮弹
        trailLength = 1.0,       -- 火焰尾迹
        -- 经济
        price = 30,           -- 文档：30
        description = "重巡主炮发射的穿甲弹，贯穿3个目标",
        lore = "帝国重巡舰的主炮标准弹药，每一发都能贯穿三艘轻型战舰。\n\n维多利亚·雷吉娜曾指挥重巡舰队，这是她最熟悉的武器。\n\n「皇室教会我一件事，」她说，「要么压倒性地获胜，要么什么都不是。」",
    },
    
    -- ========================================================================
    -- 激光系列（射程200-1000 → 20-100m）- 远程即时
    -- 特点：即时命中、细长光束、最远射程
    -- ========================================================================
    
    -- 激光炮 - 基础激光
    LaserCannon = {
        id = "LaserCannon",
        name = "激光炮",
        nameEn = "Laser Cannon",
        type = Weapons.Types.LASER,
        tier = 1,
        tags = {"能量"},      -- 伤害类型标签
        damage = 10,          -- 文档：10
        tierDamage = {10, 15, 21, 30},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 0.46,      -- 文档：0.46s
        critChance = 0.0,
        projectileSpeed = 100.0, -- 激光极快
        range = 24.0,         -- 激光炮（文档：24m）
        -- 激光属性
        instant = true,       -- 即时命中
        -- 视觉
        color = {r = 0.3, g = 1.0, b = 0.5},  -- 激光绿
        turretSize = 0.35,    -- 长管炮塔
        projectileSize = 0.2, -- 细光束
        trailLength = 2.0,    -- 长光束
        beamWidth = 0.15,     -- 光束宽度
        -- 经济
        price = 25,           -- 文档：25
        description = "即时命中，基础激光武器",
        lore = "光速武器，帝国科学院的骄傲。当你看到光束时，你已经被击中了。\n\n艾达·洛芙蕾丝曾参与这种武器的研发。当她发现激光核心的能量来源是被奴役的原生者幼体时，她烧毁了实验室。\n\n现在她用同样的武器对准帝国。讽刺的是，帝国从未告诉她原生者也有孩子。",
    },
    
    -- 激光狙击 - 最远射程，贯穿全部（文档2026-01-06：仅T3/T4）
    LaserSniper = {
        id = "LaserSniper",
        name = "激光狙击",
        nameEn = "Laser Sniper",
        type = Weapons.Types.LASER,
        tier = 3,  -- 起始T3
        tags = {"能量", "精准"},  -- 伤害类型标签
        damage = 50,          -- T3基础伤害
        tierDamage = {nil, nil, 50, 80},  -- 仅T3/T4（文档2026-01-06）
        cooldown = 2.4,       -- 文档：2.4s
        critChance = 0.10,    -- 文档：10%暴击
        projectileSpeed = 150.0,  -- 即时命中（仅用于视觉）
        range = 25.0,         -- T3基础射程25m
        tierRange = {nil, nil, 25, 30},  -- T3:25m, T4:30m（文档2026-01-06）
        -- 激光属性
        instant = true,
        pierce = 99,          -- 贯穿全部
        -- 视觉
        color = {r = 0.2, g = 0.9, b = 0.4},  -- 深绿狙击
        turretSize = 0.38,    -- 大型狙击炮（收敛尺寸差异）
        projectileSize = 0.15,  -- 极细光束
        trailLength = 3.0,    -- 超长光束
        beamWidth = 0.12,     -- 稍粗一点更明显
        -- 经济
        price = 95,           -- 文档：95
        description = "高伤害狙击，贯穿全部敌人",
        lore = "帝国狙击手戴安娜·月影的定制武器。一道光，贯穿黑暗，从不失手。\n\n她曾是帝国最出色的刺客，直到接到暗杀政敌家属的命令。目标是一个六岁的女孩。\n\n那天，她的瞄准镜第一次偏移了。不是因为失误，而是因为选择。\n\n光束依然精准，只是换了目标。",
    },
    
    -- 等离子喷射器 - 穿透全体 + 灼烧（对标 Brotato Flamethrower）
    -- 设计核心：低直伤、穿透全体、高攻速 → 吸血发动机
    PlasmaJet = {
        id = "PlasmaJet",
        name = "等离子喷射器",
        nameEn = "Plasma Sprayer",
        type = Weapons.Types.LASER,
        tier = 2,             -- 文档：无T1，从T2开始
        noTier1 = true,       -- 标记此武器无T1
        tags = {"能量"},      -- 伤害类型标签（DOT/控制）
        damage = 2,           -- T2基础伤害
        tierDamage = {nil, 2, 3, 5},  -- 无T1, T2=2, T3=3, T4=5（文档2026-01-05）
        cooldown = 0.17,      -- 文档：0.17s（≈6次/秒）
        critChance = 0.0,
        projectileSpeed = 100.0,  -- 快速等离子流
        range = 6.0,          -- T2射程6m
        tierRange = {nil, 6, 7, 8},  -- 射程随Tier：无/6/7/8m
        -- 穿透全体特性（对标 Brotato Pierces 99）
        pierceAll = true,     -- 穿透直线上所有敌舰
        -- 灼烧效果
        burnDamage = 5,       -- 灼烧5伤害/秒（固定，不随Tier变）
        burnDuration = 2.0,   -- 文档：2秒
        -- 视觉
        color = {r = 0.4, g = 0.9, b = 1.0},  -- 等离子青
        turretSize = 0.3,
        projectileSize = 0.15,  -- 细小等离子流
        trailLength = 0.8,      -- 长尾迹
        -- 经济
        price = 36,           -- 文档：T2=36
        description = "穿透全体敌舰，命中灼烧2秒",
        lore = "朱璃的标志性武器。等离子火焰在真空中燃烧，违反了所有已知的物理定律。\n\n「皇帝演讲太啰嗦了。」她在酒后这样评价，被同桌的线人举报。\n\n叛逃时，她把整条追击航线烧成了一片火海。妹妹玄霜跟在她身后，眼中没有恐惧，只有决心。\n\n火焰与冰霜，从此形影不离。",
    },
    
    -- 离子连锁炮 - 连锁攻击（近距离激光）
    IonChain = {
        id = "IonChain",
        name = "离子连锁炮",
        nameEn = "Ion Chain",
        type = Weapons.Types.LASER,
        tier = 1,
        tags = {"能量", "支援"},  -- 伤害类型标签（连锁/控制）
        damage = 8,           -- 文档：8
        tierDamage = {8, 12, 17, 25},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 0.46,      -- 文档：0.46s
        critChance = 0.0,
        projectileSpeed = 80.0,
        range = 7.0,          -- 文档：7m（近战激光）
        -- 即时闪电连接（第一发也是闪电效果）
        instantChain = true,  -- 使用闪电连接而非子弹
        -- 特殊效果
        chainCount = 3,       -- 连锁3目标（T4升级为4次）
        tierChainCount = {3, 3, 3, 4},  -- T1-T3: 3次, T4: 4次
        chainRange = 4.0,     -- 连锁范围4m
        chainDamageDecay = 0.7,
        -- 视觉
        color = {r = 0.4, g = 0.8, b = 1.0},  -- 离子蓝
        turretSize = 0.32,
        projectileSize = 0.25,
        trailLength = 0.8,
        -- 经济
        price = 25,           -- 文档：25
        description = "命中后连锁攻击3个目标",
        lore = "离子束会自动寻找最短路径连接多个目标，仿佛有自己的意志。\n\n妮可拉·特斯拉坚持认为这是「共振现象」，但其他科学家称之为「特斯拉的疯狂」。\n\n当帝国把她关进禁闭室时，她用一把实验原型机烧穿了三层装甲墙。\n\n「疯狂？」她笑着说，「这叫天才。」",
    },
    
    -- 冷冻射线 - 减速控制
    CryoRay = {
        id = "CryoRay",
        name = "冷冻射线",
        nameEn = "Cryo Ray",
        type = Weapons.Types.LASER,
        tier = 1,
        tags = {"能量"},      -- 伤害类型标签（DOT/控制）
        damage = 10,          -- 文档：10
        tierDamage = {10, 15, 21, 30},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 0.69,      -- 文档：0.69s
        critChance = 0.0,
        projectileSpeed = 90.0,
        range = 16.0,         -- 冷冻射线（文档：16m）
        -- 特殊效果
        slowPercent = 0.30,   -- 减速30%
        slowDuration = 2.0,   -- 文档：2秒
        -- 视觉
        color = {r = 0.4, g = 0.9, b = 1.0},  -- 冰蓝
        turretSize = 0.35,
        projectileSize = 0.3,
        trailLength = 1.2,
        -- 经济
        price = 25,           -- 文档：25
        description = "命中减速30%，持续2秒",
        lore = "玄霜的标志性武器，能将目标的分子运动降至接近绝对零度。\n\n她从不像姐姐那样张扬。当朱璃燃烧整条航线时，玄霜只是沉默地冻结了追击舰的引擎。\n\n「热情会燃尽，」她说，「但寒冷是永恒的。」\n\n姐妹二人，一火一冰，却从未分离。",
    },
    
    -- ========================================================================
    -- 舰载机系列（全图追踪）
    -- 特点：召唤物、自动追踪、持续输出
    -- ========================================================================
    
    -- 战斗无人机 - 高频低伤，飞出去近距离攻击
    FighterDrone = {
        id = "FighterDrone",
        name = "战斗无人机",
        nameEn = "Combat Drone",
        type = Weapons.Types.CARRIER,
        tier = 1,
        tags = {"舰载"},      -- 套装标签
        damage = 5,           -- 低伤害
        tierDamage = {5, 7, 10, 15},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 0.2,       -- 高频率（每秒5次）
        tierCooldown = {0.2, 0.18, 0.16, 0.14},  -- T1-T4攻击间隔（文档）
        critChance = 0.0,
        projectileSpeed = 100.0,
        range = 6.0,          -- 攻击射程（文档：6m）
        instantHit = true,    -- 100%命中，不发射子弹
        -- 无人机属性
        isDrone = true,
        droneCount = 1,
        droneOrbitRadius = 3.0,
        droneOrbitSpeed = 1.5,
        -- 视觉
        color = {r = 0.5, g = 0.8, b = 1.0},
        turretSize = 0.35,
        projectileSize = 0.3,
        trailLength = 0.6,
        droneSize = 0.8,      -- 无人机模型大小
        -- 经济
        price = 25,           -- 文档：25
        description = "部署1架高频攻击无人机，飞出去近战",
        lore = "玛丽·蜂后的孩子们。她曾是帝国最优秀的无人机操控者，直到算法判定她「未来可能叛逆」。\n\n讽刺的是，预测成了自我实现的预言。\n\n如今她的无人机群遍布流浪舰队，每一架都像忠诚的孩子守护着母亲。\n\n「它们不会背叛，」她说，「因为它们懂得什么是爱。」",
    },
    
    -- 轰炸无人机 - 爆炸伤害
    BomberDrone = {
        id = "BomberDrone",
        name = "轰炸无人机",
        nameEn = "Bomber Drone",
        type = Weapons.Types.CARRIER,
        tier = 1,
        tags = {"舰载", "爆炸"},  -- 套装标签
        damage = 30,          -- 文档：30（2026-01-05更新）
        tierDamage = {30, 45, 63, 90},  -- T1-T4固定伤害（文档2026-01-05）
        cooldown = 1.5,       -- 文档：1.5s
        critChance = 0.0,
        projectileSpeed = 12.0,  -- 慢速投弹，让用户能看到炸弹落下（4m / 12m/s ≈ 0.33秒）
        range = 30.0,         -- ⚠️ 这是寻敌范围（能飞多远找敌人），实际攻击射程在 Drone.lua 中定义为 4m（贴脸投弹）
        maxProjectileDistance = 6.0,  -- 炸弹最大飞行距离（攻击范围4m × 1.5），超过此距离立即爆炸
        -- 无人机属性
        isDrone = true,
        droneCount = 1,
        droneOrbitRadius = 4.0,
        droneOrbitSpeed = 1.2,
        -- 集束爆炸属性（轰炸机风格大范围爆炸）
        clusterExplosion = true,      -- 启用集束爆炸
        clusterCount = 3,             -- 基础3个爆炸点
        tierClusterCount = {3, 3, 3, 4},  -- T4额外+1爆炸点
        clusterRadius = 0.5,          -- 每个爆炸点半径0.5m
        clusterSpread = 2.0,          -- 爆炸点分布范围2.0m（随机分布区域）
        clusterDelay = 0.03,          -- 每个爆炸间隔0.03秒（更紧凑）
        -- 视觉
        color = {r = 1.0, g = 0.6, b = 0.3},
        turretSize = 0.4,
        projectileSize = 0.45,
        trailLength = 0.8,
        droneSize = 1.0,
        -- 经济
        price = 30,           -- 文档：30
        description = "部署1架轰炸无人机，范围爆炸",
        lore = "克利奥帕特拉的遗产。当她的星系被帝国吞并时，她带走了所有轰炸机的设计图。\n\n「女王失去了王国，」她说，「但从未失去战争的能力。」\n\n每一架轰炸无人机都刻着她故土的星图。它们在敌舰间穿梭，像是在寻找回家的路。\n\n而家，早已化为尘埃。",
    },
    
    -- 修复无人机 - 恢复护盾
    RepairDrone = {
        id = "RepairDrone",
        name = "修复无人机",
        nameEn = "Repair Drone",
        type = Weapons.Types.CARRIER,
        tier = 1,
        tags = {"舰载", "医疗"},  -- 套装标签
        damage = 0,           -- 不造成伤害
        tierDamage = {0, 0, 0, 0},  -- 不造成伤害
        cooldown = 2.0,       -- 文档：2.0s
        critChance = 0.0,
        projectileSpeed = 0,
        range = 999.0,        -- 无限范围（跟随玩家）
        -- 无人机属性
        isDrone = true,
        droneCount = 1,
        droneOrbitRadius = 2.5,
        droneOrbitSpeed = 2.0,
        -- 特殊效果
        shieldRegen = 1,      -- 护盾再生基础值
        tierShieldRegen = {1, 2, 3, 4},  -- T1-T4护盾再生（文档）
        -- 视觉
        color = {r = 0.3, g = 1.0, b = 0.5},  -- 修复绿
        turretSize = 0.3,
        droneSize = 0.7,
        -- 经济
        price = 30,           -- 文档：30
        description = "部署修复无人机，护盾再生+1",
        lore = "安琪拉·怀特的信念具现。她曾是帝国医疗兵，救治了一个不该救的伤员——敌方的飞行员，一个十七岁的男孩。\n\n军事法庭判她叛国，但她从不后悔。\n\n「生命不分敌我，」她在逃亡时写道，「我的无人机会治愈每一个需要帮助的人。」\n\n绿色的微光在战场上穿梭，那是她温柔的延伸。",
    },
}

-- ============================================================================
-- 武器升级数值（T1→T2→T3→T4）
-- 严格按照设计文档
-- ============================================================================
Weapons.TierMultipliers = {
    damage = {1.0, 1.25, 1.5, 1.75},     -- 文档：×1.0, ×1.25, ×1.5, ×1.75
    cooldown = {1.0, 1.0, 1.0, 1.0},     -- 冷却不变
    price = {1.0, 2.5, 5.0, 10.0},       -- 文档：×1.0, ×2.5, ×5.0, ×10.0
}

-- Tier颜色定义
Weapons.TierColors = {
    {r = 1.0, g = 1.0, b = 1.0},  -- T1 白色
    {r = 0.3, g = 1.0, b = 0.3},  -- T2 绿色
    {r = 0.3, g = 0.5, b = 1.0},  -- T3 蓝色
    {r = 0.8, g = 0.3, b = 1.0},  -- T4 紫色
}

Weapons.TierNames = {
    "标准型", "改良型", "精英型", "旗舰型"
}

-- ============================================================================
-- 工具函数
-- ============================================================================

-- 获取武器定义
function Weapons.Get(weaponId)
    return Weapons.List[weaponId]
end

-- 获取所有武器ID列表
function Weapons.GetAllIds()
    local ids = {}
    for id, _ in pairs(Weapons.List) do
        table.insert(ids, id)
    end
    return ids
end

-- 获取指定类型的武器
function Weapons.GetByType(weaponType)
    local result = {}
    for id, weapon in pairs(Weapons.List) do
        if weapon.type == weaponType then
            result[id] = weapon
        end
    end
    return result
end

-- 获取可购买的武器（排除初始武器）
function Weapons.GetPurchasable()
    local result = {}
    for id, weapon in pairs(Weapons.List) do
        if weapon.price > 0 then
            table.insert(result, weapon)
        end
    end
    return result
end

-- 获取武器在指定等级的属性
function Weapons.GetTierStats(weaponId, tier)
    local base = Weapons.List[weaponId]
    if not base then return nil end
    
    tier = math.max(1, math.min(4, tier or 1))
    local mult = Weapons.TierMultipliers
    
    return {
        damage = base.damage * mult.damage[tier],
        cooldown = base.cooldown * mult.cooldown[tier],
        price = math.floor(base.price * mult.price[tier]),
    }
end

-- 获取随机可购买武器
function Weapons.GetRandomPurchasable()
    local purchasable = Weapons.GetPurchasable()
    if #purchasable == 0 then return nil end
    return purchasable[math.random(#purchasable)]
end

-- 按射程分类获取武器
-- 阈值使用 Weapons.RangeThresholds（统一定义）
--   近程：≤8m（力场/电弧/等离子/离子）
--   中程：9-24m（导弹/冷冻）
--   远程：>24m（激光狙击等）
function Weapons.GetByRangeCategory()
    local categories = {
        close = {},    -- ≤ 8m（贴身战斗）
        medium = {},   -- 9-24m（安全距离）
        long = {}      -- > 24m（远程狙击）
    }
    
    for id, weapon in pairs(Weapons.List) do
        if weapon.range <= Weapons.RangeThresholds.close then
            table.insert(categories.close, weapon)
        elseif weapon.range <= Weapons.RangeThresholds.medium then
            table.insert(categories.medium, weapon)
        else
            table.insert(categories.long, weapon)
        end
    end
    
    return categories
end

-- 射程分类阈值（统一定义，所有地方都使用这个）
Weapons.RangeThresholds = {
    close = 8,    -- ≤8m 为近程
    medium = 24,  -- ≤24m 为中程，>24m 为远程
}

-- 获取武器射程描述
-- 阈值与 GetByRangeCategory 保持一致
function Weapons.GetRangeDescription(range)
    if range <= Weapons.RangeThresholds.close then
        return "近程", {r = 1.0, g = 0.6, b = 0.3}  -- 橙色
    elseif range <= Weapons.RangeThresholds.medium then
        return "中程", {r = 1.0, g = 1.0, b = 0.3}  -- 黄色
    else
        return "远程", {r = 0.3, g = 1.0, b = 0.5}  -- 绿色
    end
end

return Weapons
