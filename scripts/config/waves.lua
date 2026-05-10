-- ============================================================================
-- 星河战姬 Starkyries - 波次配置
-- 虫族战役：20波，虫族主题
-- ============================================================================

local Waves = {}

-- ============================================================================
-- 虫族战役敌人类型（来自 enemies.lua）
-- 
-- 普通虫族:
--   Spore      - 孢子虫（高速冲锋）
--   PirateGun  - 炮艇虫（远程射击）
--   Carapace   - 甲壳虫（高血肉盾）
--   HealerBug  - 治疗虫（治疗友军）
--   SuicideBug - 自爆虫（自爆高伤害）
--   Elite      - 精英虫（强化版）
-- 
-- Boss:
--   BroodMother - 小虫母（第10、15波Boss，弹幕攻击）
--   BroodQueen  - 大虫母/虫族女王（第20波最终Boss，3倍体型）
-- ============================================================================

-- ============================================================================
-- 波次时长配置（对标Brotato）
-- 1-9波递增（20→60秒），10-19波固定60秒（Boss波90秒），20波180秒
-- ============================================================================
Waves.Durations = {
    [1] = 20, [2] = 25, [3] = 30, [4] = 35, [5] = 40,
    [6] = 45, [7] = 50, [8] = 55, [9] = 60, [10] = 90,
    [11] = 60, [12] = 60, [13] = 60, [14] = 60, [15] = 90,
    [16] = 60, [17] = 60, [18] = 60, [19] = 60, [20] = 180,
}

-- ============================================================================
-- 势力配置 - 虫族战役
-- ============================================================================
Waves.Factions = {
    { name = "虫巢前哨", waves = {1, 5}, theme = "bug" },     -- 前哨虫群
    { name = "虫族主力", waves = {6, 10}, theme = "bug" },    -- 主力部队+小虫母
    { name = "虫巢精锐", waves = {11, 15}, theme = "bug" },   -- 精锐部队+小虫母
    { name = "虫族核心", waves = {16, 20}, theme = "bug" },   -- 核心部队+大虫母
}

-- ============================================================================
-- 分组刷怪配置
-- 每个波次包含多个敌舰组，每组有独立的刷新参数
-- 
-- 参数说明:
--   spawn_timing: 首次刷新时机（秒）
--   repeating_interval: 刷新间隔（秒），nil表示只刷一次
--   min_number: 每次最少数量
--   max_number: 每次最多数量
--   enemies: 该组可刷新的敌舰类型列表
--   spawnChance: 刷新概率（可选，默认1.0）
-- ============================================================================

Waves.List = {
    -- ========================================================================
    -- 波次1（20秒）- 入门：只有突击舰
    -- ========================================================================
    {
        wave = 1,
        name = "虫族先遣",
        faction = "虫族舰队",
        duration = 20,
        groups = {
            { -- 基础组：突击舰（数量翻倍）
                spawn_timing = 0.5,
                repeating_interval = 4,
                min_number = 4, max_number = 6,  -- 原：2-3，翻倍后：4-6
                enemies = {"Spore"},
            },
        },
        warpChance = 0.1,
        expectedKills = 34,      -- 原17，翻倍后34
        expectedCrystals = 52,   -- 原26，翻倍后52
    },
    
    -- ========================================================================
    -- 波次2（25秒）- 引入炮艇
    -- ========================================================================
    {
        wave = 2,
        name = "海盗出没",
        faction = "虫族舰队",
        duration = 25,
        groups = {
            { -- 基础组
                spawn_timing = 0.5,
                repeating_interval = 3.5,
                min_number = 2, max_number = 4,
                enemies = {"Spore"},
            },
            { -- 炮艇组
                spawn_timing = 8,
                repeating_interval = 5,
                min_number = 1, max_number = 2,
                enemies = {"PirateGun"},
            },
        },
        warpChance = 0.15,
        expectedKills = 21,
        expectedCrystals = 32,
    },
    
    -- ========================================================================
    -- 波次3（30秒）- 增加压力
    -- ========================================================================
    {
        wave = 3,
        name = "蜂拥而至",
        faction = "虫族舰队",
        duration = 30,
        groups = {
            { -- 基础组
                spawn_timing = 0.5,
                repeating_interval = 3,
                min_number = 3, max_number = 5,
                enemies = {"Spore"},
            },
            { -- 炮艇组
                spawn_timing = 5,
                repeating_interval = 5,
                min_number = 2, max_number = 3,
                enemies = {"PirateGun"},
            },
        },
        warpChance = 0.2,
        expectedKills = 25,
        expectedCrystals = 38,
    },
    
    -- ========================================================================
    -- 波次4（35秒）- 引入护盾舰
    -- ========================================================================
    {
        wave = 4,
        name = "机械防线",
        faction = "虫族舰队",
        duration = 35,
        groups = {
            { -- 基础组
                spawn_timing = 0.5,
                repeating_interval = 2.5,
                min_number = 4, max_number = 6,
                enemies = {"Spore"},
            },
            { -- 炮艇组
                spawn_timing = 3,
                repeating_interval = 5,
                min_number = 2, max_number = 3,
                enemies = {"PirateGun"},
            },
            { -- 护盾组
                spawn_timing = 12,
                repeating_interval = 8,
                min_number = 1, max_number = 2,
                enemies = {"Carapace"},
            },
        },
        warpChance = 0.2,
        expectedKills = 30,
        expectedCrystals = 45,
    },
    
    -- ========================================================================
    -- 波次5（40秒）- 小Boss测试：引入精英舰
    -- ========================================================================
    {
        wave = 5,
        name = "精英登场",
        faction = "虫族舰队",
        duration = 40,
        groups = {
            { -- 基础组
                spawn_timing = 0.5,
                repeating_interval = 2,
                min_number = 5, max_number = 7,
                enemies = {"Spore"},
            },
            { -- 炮艇组
                spawn_timing = 3,
                repeating_interval = 4,
                min_number = 2, max_number = 4,
                enemies = {"PirateGun"},
            },
            { -- 护盾组
                spawn_timing = 10,
                repeating_interval = 8,
                min_number = 1, max_number = 2,
                enemies = {"Carapace"},
            },
            { -- 精英组
                spawn_timing = 20,
                repeating_interval = 15,
                min_number = 1, max_number = 1,
                enemies = {"Elite"},
            },
        },
        warpChance = 0.15,
        isEliteWave = true,
        expectedKills = 34,
        expectedCrystals = 51,
    },
    
    -- ========================================================================
    -- 波次6（45秒）- 引入治疗虫
    -- 目标：孢子虫130, 海盗炮舰25, 甲壳舰12, 治疗虫4 = 171
    -- ========================================================================
    {
        wave = 6,
        name = "虫潮涌动",
        faction = "虫族主力",
        duration = 45,
        groups = {
            { -- 孢子虫：130个
                spawn_timing = 0.5,
                repeating_interval = 1.7,
                min_number = 5, max_number = 5,
                enemies = {"Spore"},
            },
            { -- 海盗炮舰：25个
                spawn_timing = 3,
                repeating_interval = 3.5,
                min_number = 2, max_number = 2,
                enemies = {"PirateGun"},
            },
            { -- 甲壳舰：12个
                spawn_timing = 8,
                repeating_interval = 5,
                min_number = 1, max_number = 2,
                enemies = {"Carapace"},
            },
            { -- 治疗虫：4个
                spawn_timing = 15,
                repeating_interval = 10,
                min_number = 1, max_number = 1,
                enemies = {"HealerBug"},
            },
        },
        warpChance = 0.25,
        expectedKills = 171,
        expectedCrystals = 200,
    },
    
    -- ========================================================================
    -- 波次7（50秒）- 引入自爆虫
    -- 目标：孢子虫150, 海盗炮舰27, 甲壳舰16, 治疗虫5, 自爆虫6 = 204
    -- ========================================================================
    {
        wave = 7,
        name = "生化前锋",
        faction = "虫族主力",
        duration = 50,
        groups = {
            { -- 孢子虫：150个
                spawn_timing = 0.5,
                repeating_interval = 1.65,
                min_number = 5, max_number = 5,
                enemies = {"Spore"},
            },
            { -- 海盗炮舰：27个
                spawn_timing = 3,
                repeating_interval = 3.5,
                min_number = 2, max_number = 2,
                enemies = {"PirateGun"},
            },
            { -- 甲壳舰：16个
                spawn_timing = 8,
                repeating_interval = 4.5,
                min_number = 1, max_number = 2,
                enemies = {"Carapace"},
            },
            { -- 自爆虫：6个
                spawn_timing = 15,
                repeating_interval = 6,
                min_number = 1, max_number = 1,
                enemies = {"SuicideBug"},
            },
            { -- 治疗虫：5个
                spawn_timing = 18,
                repeating_interval = 8,
                min_number = 1, max_number = 1,
                enemies = {"HealerBug"},
            },
        },
        warpChance = 0.3,
        expectedKills = 204,
        expectedCrystals = 240,
    },
    
    -- ========================================================================
    -- 波次8（55秒）- 引入精英舰
    -- 目标：孢子虫180, 海盗炮舰30, 甲壳舰20, 治疗虫6, 自爆虫10, 精英舰3 = 249
    -- ========================================================================
    {
        wave = 8,
        name = "特种渗透",
        faction = "虫族主力",
        duration = 55,
        groups = {
            { -- 孢子虫：180个
                spawn_timing = 0.5,
                repeating_interval = 1.5,
                min_number = 5, max_number = 5,
                enemies = {"Spore"},
            },
            { -- 海盗炮舰：30个
                spawn_timing = 2,
                repeating_interval = 3.5,
                min_number = 2, max_number = 2,
                enemies = {"PirateGun"},
            },
            { -- 甲壳舰：20个
                spawn_timing = 6,
                repeating_interval = 4,
                min_number = 1, max_number = 2,
                enemies = {"Carapace"},
            },
            { -- 自爆虫：10个
                spawn_timing = 10,
                repeating_interval = 4.5,
                min_number = 1, max_number = 1,
                enemies = {"SuicideBug"},
            },
            { -- 治疗虫：6个
                spawn_timing = 15,
                repeating_interval = 7,
                min_number = 1, max_number = 1,
                enemies = {"HealerBug"},
            },
            { -- 精英舰：3个
                spawn_timing = 25,
                repeating_interval = 12,
                min_number = 1, max_number = 1,
                enemies = {"Elite"},
            },
        },
        warpChance = 0.25,
        isEliteWave = true,
        expectedKills = 249,
        expectedCrystals = 300,
    },
    
    -- ========================================================================
    -- 波次9（60秒）- Boss前最后一波
    -- 目标：孢子虫210, 海盗炮舰32, 甲壳舰25, 治疗虫8, 自爆虫15, 精英舰5 = 295
    -- ========================================================================
    {
        wave = 9,
        name = "精英围攻",
        faction = "虫族主力",
        duration = 60,
        groups = {
            { -- 孢子虫：210个
                spawn_timing = 0.5,
                repeating_interval = 1.4,
                min_number = 5, max_number = 5,
                enemies = {"Spore"},
            },
            { -- 海盗炮舰：32个
                spawn_timing = 2,
                repeating_interval = 3.5,
                min_number = 2, max_number = 2,
                enemies = {"PirateGun"},
            },
            { -- 甲壳舰：25个
                spawn_timing = 5,
                repeating_interval = 3.5,
                min_number = 1, max_number = 2,
                enemies = {"Carapace"},
            },
            { -- 自爆虫：15个
                spawn_timing = 10,
                repeating_interval = 3.5,
                min_number = 1, max_number = 1,
                enemies = {"SuicideBug"},
            },
            { -- 治疗虫：8个
                spawn_timing = 12,
                repeating_interval = 6,
                min_number = 1, max_number = 1,
                enemies = {"HealerBug"},
            },
            { -- 精英舰：3个
                spawn_timing = 20,
                repeating_interval = 16,
                min_number = 1, max_number = 1,
                enemies = {"Elite"},
            },
        },
        warpChance = 0.35,
        expectedKills = 295,
        expectedCrystals = 350,
    },
    
    -- ========================================================================
    -- 波次10（90秒）- 虫母舰Boss战 I
    -- 目标：孢子虫150, 海盗炮舰25, 甲壳舰15 = 190 + 虫母舰Boss
    -- ========================================================================
    {
        wave = 10,
        name = "虫巢觉醒",
        faction = "虫族主力",
        duration = 90,
        isBossWave = true,
        bossType = "BroodMother",
        bossSpawnTime = 5,
        groups = {
            { -- 孢子虫：200个 (interval=1.5, 40次×5)
                spawn_timing = 0.5,
                repeating_interval = 1.5,
                min_number = 5, max_number = 5,
                enemies = {"Spore"},
            },
            { -- 海盗炮舰：32个 (interval=3.5, 17次×2)
                spawn_timing = 2,
                repeating_interval = 3.5,
                min_number = 2, max_number = 2,
                enemies = {"PirateGun"},
            },
            { -- 甲壳舰：20个 (interval=4, 14次×1.5)
                spawn_timing = 5,
                repeating_interval = 4,
                min_number = 1, max_number = 2,
                enemies = {"Carapace"},
            },
            { -- 自爆虫：12个 (interval=4.5, 12次×1)
                spawn_timing = 8,
                repeating_interval = 4.5,
                min_number = 1, max_number = 1,
                enemies = {"SuicideBug"},
            },
            { -- 治疗虫：6个 (interval=8, 7次×1)
                spawn_timing = 10,
                repeating_interval = 8,
                min_number = 1, max_number = 1,
                enemies = {"HealerBug"},
            },
        },
        warpChance = 0.2,
        expectedKills = 270,
        expectedCrystals = 320,
        bossCrystals = 35,
    },
    
    -- ========================================================================
    -- 波次11（60秒）
    -- 目标：孢子虫230, 海盗炮舰33, 甲壳舰28, 治疗虫10, 自爆虫18, 精英舰6 = 325
    -- ========================================================================
    [11] = {
        wave = 11,
        name = "反击浪潮",
        faction = "虫巢精锐",
        duration = 60,
        groups = {
            { -- 孢子虫：230个
                spawn_timing = 0.5, repeating_interval = 1.3, min_number = 5, max_number = 5, enemies = {"Spore"} },
            { -- 海盗炮舰：33个
                spawn_timing = 2, repeating_interval = 3.5, min_number = 2, max_number = 2, enemies = {"PirateGun"} },
            { -- 甲壳舰：28个
                spawn_timing = 5, repeating_interval = 3.2, min_number = 1, max_number = 2, enemies = {"Carapace"} },
            { -- 自爆虫：18个
                spawn_timing = 10, repeating_interval = 3, min_number = 1, max_number = 1, enemies = {"SuicideBug"} },
            { -- 治疗虫：10个
                spawn_timing = 12, repeating_interval = 5, min_number = 1, max_number = 1, enemies = {"HealerBug"} },
            { -- 精英舰：3个
                spawn_timing = 20, repeating_interval = 16, min_number = 1, max_number = 1, enemies = {"Elite"} },
        },
        warpChance = 0.3,
        expectedKills = 325,
        expectedCrystals = 400,
    },
    
    -- ========================================================================
    -- 波次12（60秒）
    -- 目标：孢子虫250, 海盗炮舰35, 甲壳舰32, 治疗虫12, 自爆虫22, 精英舰8 = 359
    -- ========================================================================
    [12] = {
        wave = 12,
        name = "甲壳围城",
        faction = "虫巢精锐",
        duration = 60,
        groups = {
            { -- 孢子虫：250个
                spawn_timing = 0.5, repeating_interval = 1.2, min_number = 5, max_number = 5, enemies = {"Spore"} },
            { -- 海盗炮舰：35个
                spawn_timing = 2, repeating_interval = 3.3, min_number = 2, max_number = 2, enemies = {"PirateGun"} },
            { -- 甲壳舰：32个
                spawn_timing = 5, repeating_interval = 2.8, min_number = 1, max_number = 2, enemies = {"Carapace"} },
            { -- 自爆虫：22个
                spawn_timing = 10, repeating_interval = 2.5, min_number = 1, max_number = 1, enemies = {"SuicideBug"} },
            { -- 治疗虫：12个
                spawn_timing = 12, repeating_interval = 4, min_number = 1, max_number = 1, enemies = {"HealerBug"} },
            { -- 精英舰：4个
                spawn_timing = 18, repeating_interval = 11, min_number = 1, max_number = 1, enemies = {"Elite"} },
        },
        warpChance = 0.3,
        isEliteWave = true,
        expectedKills = 359,
        expectedCrystals = 440,
    },
    
    -- ========================================================================
    -- 波次13（60秒）
    -- 目标：孢子虫270, 海盗炮舰36, 甲壳舰35, 治疗虫14, 自爆虫25, 精英舰10 = 390
    -- ========================================================================
    [13] = {
        wave = 13,
        name = "虫巢联军",
        faction = "虫巢精锐",
        duration = 60,
        groups = {
            { -- 孢子虫：270个
                spawn_timing = 0.5, repeating_interval = 1.1, min_number = 5, max_number = 5, enemies = {"Spore"} },
            { -- 海盗炮舰：36个
                spawn_timing = 2, repeating_interval = 3.2, min_number = 2, max_number = 2, enemies = {"PirateGun"} },
            { -- 甲壳舰：35个
                spawn_timing = 5, repeating_interval = 2.6, min_number = 1, max_number = 2, enemies = {"Carapace"} },
            { -- 自爆虫：25个
                spawn_timing = 10, repeating_interval = 2.2, min_number = 1, max_number = 1, enemies = {"SuicideBug"} },
            { -- 治疗虫：14个
                spawn_timing = 12, repeating_interval = 3.5, min_number = 1, max_number = 1, enemies = {"HealerBug"} },
            { -- 精英舰：5个
                spawn_timing = 18, repeating_interval = 9, min_number = 1, max_number = 1, enemies = {"Elite"} },
        },
        warpChance = 0.35,
        expectedKills = 390,
        expectedCrystals = 480,
    },
    
    -- ========================================================================
    -- 波次14（60秒）
    -- 目标：孢子虫290, 海盗炮舰38, 甲壳舰38, 治疗虫16, 自爆虫28, 精英舰12 = 422
    -- ========================================================================
    [14] = {
        wave = 14,
        name = "孢子狂潮",
        faction = "虫巢精锐",
        duration = 60,
        groups = {
            { -- 孢子虫：290个
                spawn_timing = 0.5, repeating_interval = 1.0, min_number = 5, max_number = 5, enemies = {"Spore"} },
            { -- 海盗炮舰：38个
                spawn_timing = 2, repeating_interval = 3.0, min_number = 2, max_number = 2, enemies = {"PirateGun"} },
            { -- 甲壳舰：38个
                spawn_timing = 5, repeating_interval = 2.4, min_number = 1, max_number = 2, enemies = {"Carapace"} },
            { -- 自爆虫：28个
                spawn_timing = 10, repeating_interval = 2.0, min_number = 1, max_number = 1, enemies = {"SuicideBug"} },
            { -- 治疗虫：16个
                spawn_timing = 12, repeating_interval = 3, min_number = 1, max_number = 1, enemies = {"HealerBug"} },
            { -- 精英舰：6个
                spawn_timing = 15, repeating_interval = 8, min_number = 1, max_number = 1, enemies = {"Elite"} },
        },
        warpChance = 0.35,
        isEliteWave = true,
        expectedKills = 422,
        expectedCrystals = 520,
    },
    
    -- ========================================================================
    -- 波次15（90秒）- 虫母舰Boss战 II（增强版）
    -- 目标：孢子虫220, 海盗炮舰30, 甲壳舰25, 治疗虫10, 自爆虫15, 精英舰5 = 305 + 虫母舰Boss
    -- ========================================================================
    [15] = {
        wave = 15,
        name = "虫母再临",
        faction = "虫巢精锐",
        duration = 90,
        isBossWave = true,
        bossType = "BroodMother",
        bossSpawnTime = 5,
        bossEnhanced = true,  -- 标记为增强版
        groups = {
            { -- 孢子虫：220个
                spawn_timing = 0.5, 
                repeating_interval = 1.35, 
                min_number = 5, max_number = 5, 
                enemies = {"Spore"} 
            },
            { -- 海盗炮舰：30个
                spawn_timing = 3, 
                repeating_interval = 3.8, 
                min_number = 2, max_number = 2, 
                enemies = {"PirateGun"} 
            },
            { -- 甲壳舰：25个
                spawn_timing = 8, 
                repeating_interval = 3.5, 
                min_number = 1, max_number = 2, 
                enemies = {"Carapace"} 
            },
            { -- 自爆虫：15个
                spawn_timing = 12, 
                repeating_interval = 3.5, 
                min_number = 1, max_number = 1, 
                enemies = {"SuicideBug"} 
            },
            { -- 治疗虫：10个
                spawn_timing = 15, 
                repeating_interval = 5, 
                min_number = 1, max_number = 1, 
                enemies = {"HealerBug"} 
            },
            { -- 精英舰：3个
                spawn_timing = 25,
                repeating_interval = 14,
                min_number = 1, max_number = 1,
                enemies = {"Elite"}
            },
        },
        warpChance = 0.25,
        expectedKills = 305,
        expectedCrystals = 380,
        bossCrystals = 40,
    },
    
    -- ========================================================================
    -- 波次16（60秒）
    -- 目标：孢子虫320, 海盗炮舰38, 甲壳舰42, 治疗虫18, 自爆虫32, 精英舰14 = 464
    -- ========================================================================
    [16] = {
        wave = 16,
        name = "核心守卫",
        faction = "虫族核心",
        duration = 60,
        groups = {
            { -- 孢子虫：320个
                spawn_timing = 0.5, repeating_interval = 0.93, min_number = 5, max_number = 5, enemies = {"Spore"} },
            { -- 海盗炮舰：38个
                spawn_timing = 2, repeating_interval = 3.0, min_number = 2, max_number = 2, enemies = {"PirateGun"} },
            { -- 甲壳舰：42个
                spawn_timing = 5, repeating_interval = 2.2, min_number = 1, max_number = 2, enemies = {"Carapace"} },
            { -- 自爆虫：32个
                spawn_timing = 10, repeating_interval = 1.7, min_number = 1, max_number = 1, enemies = {"SuicideBug"} },
            { -- 治疗虫：18个
                spawn_timing = 12, repeating_interval = 2.8, min_number = 1, max_number = 1, enemies = {"HealerBug"} },
            { -- 精英舰：7个
                spawn_timing = 15, repeating_interval = 7, min_number = 1, max_number = 1, enemies = {"Elite"} },
        },
        warpChance = 0.35,
        expectedKills = 464,
        expectedCrystals = 570,
    },
    
    -- ========================================================================
    -- 波次17（60秒）
    -- 目标：孢子虫350, 海盗炮舰39, 甲壳舰45, 治疗虫20, 自爆虫35, 精英舰16 = 505
    -- ========================================================================
    [17] = {
        wave = 17,
        name = "虫群压制",
        faction = "虫族核心",
        duration = 60,
        groups = {
            { -- 孢子虫：350个
                spawn_timing = 0.5, repeating_interval = 0.85, min_number = 5, max_number = 5, enemies = {"Spore"} },
            { -- 海盗炮舰：39个
                spawn_timing = 2, repeating_interval = 2.95, min_number = 2, max_number = 2, enemies = {"PirateGun"} },
            { -- 甲壳舰：45个
                spawn_timing = 5, repeating_interval = 2.0, min_number = 1, max_number = 2, enemies = {"Carapace"} },
            { -- 自爆虫：35个
                spawn_timing = 10, repeating_interval = 1.5, min_number = 1, max_number = 1, enemies = {"SuicideBug"} },
            { -- 治疗虫：20个
                spawn_timing = 12, repeating_interval = 2.5, min_number = 1, max_number = 1, enemies = {"HealerBug"} },
            { -- 精英舰：8个
                spawn_timing = 15, repeating_interval = 6, min_number = 1, max_number = 1, enemies = {"Elite"} },
        },
        warpChance = 0.35,
        isEliteWave = true,
        expectedKills = 505,
        expectedCrystals = 620,
    },
    
    -- ========================================================================
    -- 波次18（60秒）
    -- 目标：孢子虫380, 海盗炮舰40, 甲壳舰48, 治疗虫22, 自爆虫38, 精英舰18 = 546
    -- ========================================================================
    [18] = {
        wave = 18,
        name = "虫族疯狂",
        faction = "虫族核心",
        duration = 60,
        groups = {
            { -- 孢子虫：380个
                spawn_timing = 0.5, repeating_interval = 0.78, min_number = 5, max_number = 5, enemies = {"Spore"} },
            { -- 海盗炮舰：40个
                spawn_timing = 2, repeating_interval = 2.9, min_number = 2, max_number = 2, enemies = {"PirateGun"} },
            { -- 甲壳舰：48个
                spawn_timing = 5, repeating_interval = 1.85, min_number = 1, max_number = 2, enemies = {"Carapace"} },
            { -- 自爆虫：38个
                spawn_timing = 10, repeating_interval = 1.35, min_number = 1, max_number = 1, enemies = {"SuicideBug"} },
            { -- 治疗虫：22个
                spawn_timing = 12, repeating_interval = 2.2, min_number = 1, max_number = 1, enemies = {"HealerBug"} },
            { -- 精英舰：9个
                spawn_timing = 15, repeating_interval = 5.2, min_number = 1, max_number = 1, enemies = {"Elite"} },
        },
        warpChance = 0.4,
        expectedKills = 546,
        expectedCrystals = 670,
    },
    
    -- ========================================================================
    -- 波次19（60秒）
    -- 目标：孢子虫410, 海盗炮舰40, 甲壳舰50, 治疗虫24, 自爆虫40, 精英舰20 = 584
    -- ========================================================================
    [19] = {
        wave = 19,
        name = "最后防线",
        faction = "虫族核心",
        duration = 60,
        groups = {
            { -- 孢子虫：410个
                spawn_timing = 0.5, repeating_interval = 0.72, min_number = 5, max_number = 5, enemies = {"Spore"} },
            { -- 海盗炮舰：40个
                spawn_timing = 2, repeating_interval = 2.9, min_number = 2, max_number = 2, enemies = {"PirateGun"} },
            { -- 甲壳舰：50个
                spawn_timing = 5, repeating_interval = 1.75, min_number = 1, max_number = 2, enemies = {"Carapace"} },
            { -- 自爆虫：40个
                spawn_timing = 10, repeating_interval = 1.3, min_number = 1, max_number = 1, enemies = {"SuicideBug"} },
            { -- 治疗虫：24个
                spawn_timing = 12, repeating_interval = 2.0, min_number = 1, max_number = 1, enemies = {"HealerBug"} },
            { -- 精英舰：10个
                spawn_timing = 15, repeating_interval = 5, min_number = 1, max_number = 1, enemies = {"Elite"} },
        },
        warpChance = 0.4,
        isEliteWave = true,
        expectedKills = 584,
        expectedCrystals = 720,
    },
    
    -- ========================================================================
    -- 波次20（180秒）- 虫族女王最终Boss战
    -- 目标：孢子虫350, 海盗炮舰35, 甲壳舰40, 治疗虫20, 自爆虫30, 精英舰15 = 490
    --       + 虫族女王 + 2虫母舰
    -- ========================================================================
    [20] = {
        wave = 20,
        name = "虫族女王",
        faction = "虫族核心",
        duration = 180,
        isBossWave = true,
        isFinal = true,
        bossType = "BroodQueen",        -- 虫族女王作为主Boss
        additionalBosses = {            -- 额外Boss：1只虫母舰护卫（作为普通敌人）
            "BroodMother",
        },
        silentAdditionalBosses = true,  -- 小Boss不显示攻击形态变化提示
        bossSpawnTime = 5,
        groups = {
            { -- 孢子虫：350个（90秒）
                spawn_timing = 0.5, 
                repeating_interval = 1.28, 
                min_number = 5, max_number = 5, 
                enemies = {"Spore"} 
            },
            { -- 海盗炮舰：35个
                spawn_timing = 3, 
                repeating_interval = 5, 
                min_number = 2, max_number = 2, 
                enemies = {"PirateGun"} 
            },
            { -- 甲壳舰：40个
                spawn_timing = 8, 
                repeating_interval = 3.5, 
                min_number = 1, max_number = 2, 
                enemies = {"Carapace"} 
            },
            { -- 自爆虫：30个
                spawn_timing = 15, 
                repeating_interval = 2.7, 
                min_number = 1, max_number = 1, 
                enemies = {"SuicideBug"} 
            },
            { -- 治疗虫：20个
                spawn_timing = 20, 
                repeating_interval = 3.7, 
                min_number = 1, max_number = 1, 
                enemies = {"HealerBug"} 
            },
            { -- 精英舰：7个
                spawn_timing = 25, 
                repeating_interval = 10, 
                min_number = 1, max_number = 1, 
                enemies = {"Elite"} 
            },
        },
        warpChance = 0.3,
        expectedKills = 490,
        expectedCrystals = 600,
        bossCrystals = 100,  -- 最终Boss奖励
    },
}

-- ============================================================================
-- 难度缩放配置（纯线性，完全对标Brotato）
-- ============================================================================
-- 新公式（2026-01-05更新）：
--   敌舰护盾 = 基础护盾 + (每波护盾增量 × (当前波次 - 1))
--   敌舰伤害 = 基础伤害 + (每波伤害增量 × (当前波次 - 1))
--   敌舰速度 = 基础速度（不随波次变化）
-- 每个敌人的 hpPerWave 和 damagePerWave 定义在 enemies.lua 中
--
-- 旧指数公式已废弃，以下配置仅保留用于兼容性
Waves.Scaling = {
    -- [已废弃] 旧指数公式参数，现已改用纯线性
    hpExponent = 1.35,
    hpMultiplier = 0.12,
    damageExponent = 1.25,
    damageMultiplier = 0.10,
    countExponent = 1.15,
    countMultiplier = 0.08,
    
    -- Boss血量倍率（已废弃，Boss现使用 hpPerWave 线性成长）
    bossHpMultiplier = 1.0,
}

-- ============================================================================
-- 工具函数
-- ============================================================================

-- 获取波次配置
function Waves.Get(waveNum)
    return Waves.List[waveNum]
end

-- 获取总波数
function Waves.GetTotalWaves()
    return 20
end

-- 获取波次时长
function Waves.GetDuration(waveNum)
    local wave = Waves.List[waveNum]
    if wave and wave.duration then
        return wave.duration
    end
    return Waves.Durations[waveNum] or 60
end

-- 计算敌人属性缩放（旧接口，保留兼容性）
-- 注意：实际属性计算已改为纯线性公式，见 Battle.ScaleEnemyStats
function Waves.GetScaling(waveNum)
    local s = Waves.Scaling
    return {
        -- 以下乘数已废弃，实际使用敌人配置中的 hpPerWave/damagePerWave
        hpMult = 1.0 + math.pow(waveNum, s.hpExponent) * s.hpMultiplier,
        damageMult = 1.0 + math.pow(waveNum, s.damageExponent) * s.damageMultiplier,
        countMult = 1.0 + math.pow(waveNum, s.countExponent) * s.countMultiplier,
        speedMult = 1.0,  -- 速度不再成长（Brotato原版设计）
    }
end

-- 检查是否是BOSS波
function Waves.IsBossWave(waveNum)
    local wave = Waves.List[waveNum]
    return wave and wave.isBossWave == true
end

-- 检查是否是精英波
function Waves.IsEliteWave(waveNum)
    local wave = Waves.List[waveNum]
    return wave and wave.isEliteWave == true
end

-- 获取Boss类型
function Waves.GetBossType(waveNum)
    local wave = Waves.List[waveNum]
    return wave and wave.bossType
end

-- 获取Boss晶体奖励
function Waves.GetBossCrystals(waveNum)
    local wave = Waves.List[waveNum]
    return wave and wave.bossCrystals or 30
end

-- 获取BOSS波列表
function Waves.GetBossWaves()
    return {10, 15, 20}
end

-- 获取势力信息
function Waves.GetFaction(waveNum)
    for _, faction in ipairs(Waves.Factions) do
        if waveNum >= faction.waves[1] and waveNum <= faction.waves[2] then
            return faction
        end
    end
    return nil
end

-- 获取势力名称
function Waves.GetFactionName(waveNum)
    local faction = Waves.GetFaction(waveNum)
    return faction and faction.name or "未知势力"
end

-- 获取波次的所有刷怪组
function Waves.GetSpawnGroups(waveNum)
    local wave = Waves.List[waveNum]
    return wave and wave.groups or {}
end

-- 从敌人列表中随机选择一个
function Waves.RandomEnemy(enemies)
    if not enemies or #enemies == 0 then
        return nil
    end
    return enemies[math.random(1, #enemies)]
end

-- 获取波次的预期击杀数
function Waves.GetExpectedKills(waveNum)
    local wave = Waves.List[waveNum]
    return wave and wave.expectedKills or 30
end

-- 获取波次的预期晶体收入
function Waves.GetExpectedCrystals(waveNum)
    local wave = Waves.List[waveNum]
    return wave and wave.expectedCrystals or 45
end

-- ============================================================================
-- 向后兼容函数
-- ============================================================================

-- 计算波次的生成间隔（向后兼容，新系统不再使用）
function Waves.CalculateSpawnRate(waveNum)
    local baseInterval = 1.5
    return baseInterval / (1 + waveNum * 0.1)
end

-- 获取单次刷新的敌人数量范围（向后兼容，新系统不再使用）
function Waves.GetBatchSpawnCount(waveNum)
    local min, max
    if waveNum <= 3 then
        min, max = 3, 5
    elseif waveNum <= 5 then
        min, max = 5, 8
    elseif waveNum <= 10 then
        min, max = 8, 12
    elseif waveNum <= 15 then
        min, max = 12, 18
    else
        min, max = 18, 25
    end
    return math.random(min, max)
end

-- 获取敌人池（向后兼容）
function Waves.GetEnemyPool(waveNum)
    local groups = Waves.GetSpawnGroups(waveNum)
    local pool = {}
    for _, group in ipairs(groups) do
        for _, enemy in ipairs(group.enemies) do
            table.insert(pool, enemy)
        end
    end
    return pool
end

return Waves
