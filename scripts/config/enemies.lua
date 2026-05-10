-- ============================================================================
-- 星河战姬 Starkyries - 敌人配置
-- 垂直切片v1：6种敌人 + 1个Boss
-- ============================================================================

local Enemies = {}

-- ============================================================================
-- 敌人阵营定义
-- ============================================================================
Enemies.Factions = {
    BUG = "Bug",           -- 虫族
    MECH = "Mech",         -- 机械
    PIRATE = "Pirate",     -- 海盗
}

-- ============================================================================
-- 敌人行为模式
-- ============================================================================
Enemies.Behaviors = {
    CHASE = "Chase",       -- 直接追击（突击舰）
    ORBIT = "Orbit",       -- 环绕射击（炮艇）
    TANK = "Tank",         -- 缓慢高血（护盾舰）
    SUPPORT = "Support",   -- 辅助单位（治疗舰）
    BOMBER = "Bomber",     -- 自爆单位（爆破舰）
    ELITE = "Elite",       -- 精英单位（精英舰）
    BOSS = "Boss",         -- Boss单位
}

-- ============================================================================
-- 敌人数据
-- 严格按照垂直切片文档定义
-- 
-- 通用属性说明:
--   hp            - 基础血量
--   hpPerWave     - 每波血量增量（血量 = hp + hpPerWave × (波次-1)）
--   damage        - 基础伤害
--   damagePerWave - 每波伤害增量
--   moveSpeed     - 移动速度（m/s）
--   scale         - 视觉大小（碰撞半径 = scale）
--   armor         - 护甲（减伤点数）
-- 
-- 击退属性:
--   knockbackResist - 击退免疫概率（0~1，1.0=100%免疫）
--   knockbackMult   - 击退效果倍率（0.5=效果减半）
-- ============================================================================

Enemies.List = {
    -- ========================================================================
    -- 1. 孢子虫（虫族）- 基础敌人
    -- 对标Brotato孢子虫：基础杂兵，数量多
    -- ========================================================================
    Spore = {
        id = "Spore",
        name = "孢子虫",
        icon = "🦠",
        faction = Enemies.Factions.BUG,
        hp = 3,               -- 对标孢子虫：基础护盾3
        hpPerWave = 1,        -- +1护盾/波
        damage = 1,           -- 对标孢子虫：基础伤害1
        damagePerWave = 1,    -- +1伤害/波（线性成长）
        moveSpeed = 4.0,      -- 对标孢子虫：4 m/s（中速）
        behavior = Enemies.Behaviors.CHASE,
        
        -- 掉落（对标Brotato：100%掉落，杂兵1晶体）
        dropXp = 1,                    -- 经验值（击杀自动获取）
        dropCrystal = 1,               -- 晶体（固定值，对标Brotato杂兵）
        
        -- 外观
        scale = 1.2,  -- 视觉大小（碰撞半径自动 = scale × 0.5）
        bodyColor = {r = 0.35, g = 0.7, b = 0.2},
        glowColor = {r = 0.5, g = 1.0, b = 0.3},
        
        -- 生成权重
        spawnWeight = 15,
        
        description = "高速冲锋，数量众多",
    },
    
    -- ========================================================================
    -- 2. 海盗炮舰（海盗）- 远程敌人
    -- 对标Brotato海盗炮舰：远程射击，保持距离（8-12米环绕）
    -- ========================================================================
    PirateGun = {
        id = "PirateGun",
        name = "海盗炮舰",
        icon = "🔫",
        faction = Enemies.Factions.PIRATE,
        hp = 8,                   -- 对标文档：基础护盾8
        hpPerWave = 2,            -- +2护盾/波（线性成长）
        damage = 1,               -- 对标文档：基础伤害1
        damagePerWave = 0.6,      -- +0.6伤害/波（线性成长）
        moveSpeed = 2.0,          -- 2 m/s（慢速，便于环绕射击）
        behavior = Enemies.Behaviors.ORBIT,
        
        -- 远程攻击
        canShoot = true,
        attackRange = 10.0,       -- 最佳距离10米，环绕范围8-12米
        projectileSpeed = 5.0,
        attackCooldown = 2.0,     -- 2秒攻击间隔
        
        -- 掉落（对标Brotato：100%掉落，普通敌人1晶体）
        dropXp = 1,                    -- 经验值（击杀自动获取）
        dropCrystal = 1,               -- 晶体（对标文档普通敌人）
        
        -- 外观
        scale = 1.8,  -- 视觉大小（碰撞半径 = scale）
        bodyColor = {r = 0.6, g = 0.4, b = 0.2},
        glowColor = {r = 0.9, g = 0.3, b = 0.2},  -- 棕红色（避免和子弹混淆）
        
        -- 击退抗性
        knockbackMult = 0.5,      -- 击退效果减半
        
        -- 生成权重
        spawnWeight = 10,
        
        description = "保持距离，远程射击",
    },
    
    -- ========================================================================
    -- 3. 甲壳舰（虫族）- 肉盾敌人
    -- 对标Brotato甲壳舰：高护盾坦克，移动缓慢
    -- ========================================================================
    Carapace = {
        id = "Carapace",
        name = "甲壳舰",
        icon = "🛡",
        faction = Enemies.Factions.BUG,  -- 虫族（对标文档）
        hp = 20,
        hpPerWave = 4,            -- +4护盾/波
        damage = 2,               -- 对标文档：伤害2
        damagePerWave = 1,        -- +1伤害/波（线性成长）
        moveSpeed = 3.0,          -- 速度不随波次变化
        behavior = Enemies.Behaviors.TANK,
        
        -- 高护盾特性
        armor = 1,  -- 减伤1点
        knockbackMult = 0.5,      -- 击退效果减半
        
        -- 掉落（对标文档：威胁级2晶体）
        dropXp = 2,                    -- 经验值（威胁敌舰3 XP）
        dropCrystal = 2,               -- 晶体（对标文档威胁级敌人）
        
        -- 外观
        scale = 0.8,  -- 视觉大小（碰撞半径 = scale）
        bodyColor = {r = 0.4, g = 0.45, b = 0.5},
        glowColor = {r = 0.6, g = 0.8, b = 1.0},
        
        -- 生成权重
        spawnWeight = 6,
        
        description = "高护盾，移动缓慢",
    },
    
    -- ========================================================================
    -- 4. 治疗虫（虫族）- 优先目标
    -- 对标Brotato治疗虫/修复机：极速移动，治疗友军，最高优先击杀
    -- 设计：极速移动（9 m/s = 90%玩家速度），必须主动追击
    -- ========================================================================
    HealerBug = {
        id = "HealerBug",
        name = "治疗虫",
        icon = "💚",
        faction = Enemies.Factions.BUG,
        hp = 10,
        hpPerWave = 8,            -- +8护盾/波（线性成长，对标文档）
        damage = 1,
        damagePerWave = 1,        -- +1伤害/波
        moveSpeed = 3.0,          -- 缓慢游荡，专注治疗
        behavior = Enemies.Behaviors.SUPPORT,
        
        -- 治疗能力（对标文档：100+10/波）
        canHeal = true,
        healRange = 8.0,
        healAmount = 100,         -- 基础治疗量（对标文档）
        healAmountPerWave = 10,   -- +10治疗量/波（线性成长）
        healCooldown = 2.0,       -- 治疗间隔
        
        -- 掉落（对标文档：支援级2晶体，4 XP）
        dropXp = 4,                    -- 经验值（支援敌舰4 XP）
        dropCrystal = 2,               -- 晶体（对标文档支援级敌人）
        
        -- 外观
        scale = 0.77,  -- 视觉大小（碰撞半径 = scale）
        bodyColor = {r = 0.3, g = 0.8, b = 0.4},
        glowColor = {r = 0.4, g = 1.0, b = 0.5},
        
        -- 生成权重
        spawnWeight = 4,
        
        -- 优先级标记
        isPriorityTarget = true,
        
        description = "治疗周围友军，优先击杀",
    },
    
    -- ========================================================================
    -- 5. 自爆虫（虫族）- 高威胁
    -- 行为：慢速接近 → 9m处闪红蓄力 → 冲刺到蓄力时玩家位置 → 绿色爆浆
    -- ========================================================================
    SuicideBug = {
        id = "SuicideBug",
        name = "自爆虫",
        icon = "💥",
        faction = Enemies.Factions.BUG,   -- 虫族
        hp = 6,
        hpPerWave = 4,            -- +4护盾/波
        damage = 5,               -- 自爆伤害5
        damagePerWave = 1,        -- +1伤害/波
        behavior = Enemies.Behaviors.BOMBER,
        
        -- 移动速度
        moveSpeed = 10.0,         -- 正常移动速度（10 m/s）
        chargeSpeed = 20.0,       -- 冲刺速度（20 m/s）
        
        -- 自爆特性
        isSuicide = true,
        knockbackResist = 1.0,    -- 100% 免疫击退（防止被打断冲刺）
        explosionRadius = 2.5,
        explosionDamage = 10,
        
        -- 蓄力行为参数
        chargeDistance = 9.0,     -- 距离玩家9m时开始蓄力
        chargeDelay = 1.0,        -- 闪红蓄力时间（1秒，期间不移动）
        
        -- 掉落（死亡才掉，自爆不掉）
        dropXp = 3,
        dropCrystal = 2,
        
        -- 外观（虫族绿色系）
        scale = 0.8,  -- 视觉大小（碰撞半径 = scale）
        bodyColor = {r = 0.3, g = 0.6, b = 0.2},   -- 绿色虫体
        glowColor = {r = 0.4, g = 0.8, b = 0.3},   -- 绿色光晕
        explosionColor = {r = 1.0, g = 0.2, b = 0.1},  -- 红色爆浆
        
        -- 生成权重
        spawnWeight = 5,
        
        -- 警告标记
        showWarning = true,
        
        description = "慢速接近后蓄力冲刺自爆",
    },
    
    -- ========================================================================
    -- 6. 精英舰（机械）- 小Boss
    -- 对标Brotato精英敌人：高属性，固定掉落10晶体
    -- ========================================================================
    Elite = {
        id = "Elite",
        name = "精英舰",
        icon = "⭐",
        faction = Enemies.Factions.MECH,
        hp = 60,
        hpPerWave = 10,           -- +10护盾/波（线性成长，对标Brotato精英）
        damage = 10,              -- 基础伤害10
        damagePerWave = 1,        -- +1伤害/波
        moveSpeed = 2.0,          -- 速度不随波次变化（慢速环绕）
        behavior = Enemies.Behaviors.ORBIT,  -- 环绕射击（与炮舰相同行为）
        
        -- 远程攻击
        canShoot = true,
        attackRange = 15.0,
        projectileSpeed = 12.0,   -- 导弹速度（较慢，便于躲避）
        attackCooldown = 1.0,
        projectileType = "missile",  -- 导弹造型
        
        -- 精英属性
        armor = 2,
        isElite = true,
        knockbackResist = 0.8,    -- 80%概率免疫击退
        knockbackMult = 0.1,      -- 击退效果90%减免
        
        -- 掉落（对标文档：精英敌人固定10晶体，25 XP）
        dropXp = 25,                    -- 经验值（精英敌舰25 XP，对标文档）
        dropCrystal = 10,               -- 晶体（固定值，对标文档精英敌人）
        
        -- 外观
        scale = 2.3,  -- 视觉大小（碰撞半径 = scale），原1.4增加约65%
        bodyColor = {r = 0.3, g = 0.35, b = 0.4},
        glowColor = {r = 1.0, g = 0.5, b = 0.2},
        
        -- 生成权重
        spawnWeight = 2,
        
        description = "强化版机械舰，小Boss级别",
    },
    
    -- ========================================================================
    -- Boss: 虫母舰
    -- 设计：小虫母 - 虫族战役Boss（第10/15波）
    -- 血量随波次线性成长（hpPerWave）
    -- ========================================================================
    BroodMother = {
        id = "BroodMother",
        name = "虫母舰",
        icon = "👾",
        faction = Enemies.Factions.BUG,
        hp = 1000,                -- 基础护盾
        hpPerWave = 50,           -- +50护盾/波
        damage = 30,
        damagePerWave = 0,        -- Boss伤害不随波次成长
        moveSpeed = 2.0,          -- 速度不随波次变化
        behavior = Enemies.Behaviors.BOSS,
        
        -- Boss标记
        isBoss = true,
        knockbackResist = 1.0,    -- 100%免疫击退
        
        -- ====== 弹幕系统配置 ======
        barrage = {
            -- 弹幕类型: "ring"(环形), "spiral"(螺旋), "fan"(扇形), "flower"(花形)
            type = "ring",
            bulletCount = 12,        -- 每次发射子弹数
            bulletSpeed = 8.0,       -- 子弹速度
            bulletDamage = 10,       -- 子弹伤害
            rotationOffset = 15,     -- 每次发射旋转偏移角度（度）
        },
        
        -- 多阶段战斗（弹幕强化）
        phases = {
            -- 阶段1: 100%-50% HP - 环形弹幕
            {
                hpThreshold = 0.5,
                name = "孢子环",
                barrage = {
                    type = "ring",
                    bulletCount = 12,
                    bulletSpeed = 8.0,
                    rotationOffset = 15,
                },
                attackCooldown = 1.5,
            },
            -- 阶段2: 50%-20% HP - 花形弹幕
            {
                hpThreshold = 0.2,
                name = "孢子花",
                barrage = {
                    type = "flower",
                    bulletCount = 16,
                    bulletSpeed = 10.0,
                    rotationOffset = 22.5,
                    petals = 4,           -- 花瓣数量
                },
                attackCooldown = 1.2,
                moveSpeedMultiplier = 1.3,
            },
            -- 阶段3: 20%-0% HP - 螺旋弹幕 + 狂暴
            {
                hpThreshold = 0,
                name = "孢子风暴",
                barrage = {
                    type = "spiral",
                    bulletCount = 3,      -- 每次发射3颗
                    bulletSpeed = 12.0,
                    rotationOffset = 30,
                    arms = 3,             -- 螺旋臂数量
                },
                attackCooldown = 0.15,    -- 快速连射形成螺旋
                moveSpeedMultiplier = 2.0,
                damageMultiplier = 1.5,
            },
        },
        
        -- 远程攻击
        canShoot = true,
        attackRange = 20.0,
        projectileSpeed = 8.0,
        attackCooldown = 1.5,
        
        -- 掉落（对标文档：Boss掉落30-50晶体，100 XP）
        dropXp = 100,                   -- 经验值（阶段5 Boss 100 XP，对标文档）
        dropCrystal = {min = 30, max = 50},  -- 晶体（Boss保持范围值）
        
        -- 外观
        scale = 2.4,  -- 视觉大小（碰撞半径 = scale）
        bodyColor = {r = 0.2, g = 0.5, b = 0.15},
        glowColor = {r = 0.4, g = 0.9, b = 0.3},
        
        -- 特殊显示
        showHealthBar = true,
        bossName = "虫族母舰",
        
        description = "阶段10 Boss，多阶段战斗",
    },
    
    -- ========================================================================
    -- Boss: 大虫母（虫族女王）
    -- 虫族战役最终Boss（第20波）
    -- 体型是小虫母的3倍，更强的弹幕技能
    -- ========================================================================
    BroodQueen = {
        id = "BroodQueen",
        name = "虫族女王",
        icon = "👾",
        faction = Enemies.Factions.BUG,
        hp = 2000,                -- 大虫母护盾（小虫母的4倍）
        hpPerWave = 0,
        damage = 50,              -- 接触伤害
        damagePerWave = 0,
        moveSpeed = 1.5,          -- 移动较慢（体型大）
        behavior = Enemies.Behaviors.BOSS,
        
        -- Boss标记
        isBoss = true,
        knockbackResist = 1.0,    -- 100%免疫击退
        
        -- ====== 弹幕系统配置（更强大的弹幕） ======
        barrage = {
            type = "ring",
            bulletCount = 24,        -- 双倍子弹
            bulletSpeed = 6.0,       -- 稍慢但更密集
            bulletDamage = 15,
            rotationOffset = 7.5,    -- 更小的偏移，更密集
        },
        
        -- 多阶段战斗（4阶段）
        phases = {
            -- 阶段1: 100%-70% HP - 双环弹幕
            {
                hpThreshold = 0.7,
                name = "孢子双环",
                barrage = {
                    type = "ring",
                    bulletCount = 24,
                    bulletSpeed = 6.0,
                    rotationOffset = 7.5,
                },
                attackCooldown = 1.2,
            },
            -- 阶段2: 70%-40% HP - 花形弹幕（8瓣）
            {
                hpThreshold = 0.4,
                name = "死亡之花",
                barrage = {
                    type = "flower",
                    bulletCount = 32,
                    bulletSpeed = 8.0,
                    rotationOffset = 11.25,
                    petals = 8,
                    spreadAngle = 25,
                },
                attackCooldown = 1.0,
                moveSpeedMultiplier = 1.2,
            },
            -- 阶段3: 40%-15% HP - 螺旋风暴（6臂）
            {
                hpThreshold = 0.15,
                name = "毁灭螺旋",
                barrage = {
                    type = "spiral",
                    bulletCount = 6,
                    bulletSpeed = 10.0,
                    rotationOffset = 20,
                    arms = 6,
                },
                attackCooldown = 0.12,
                moveSpeedMultiplier = 1.5,
            },
            -- 阶段4: 15%-0% HP - 狂暴弹幕
            {
                hpThreshold = 0,
                name = "虫族之怒",
                barrage = {
                    type = "spiral",
                    bulletCount = 8,
                    bulletSpeed = 12.0,
                    rotationOffset = 15,
                    arms = 8,
                },
                attackCooldown = 0.08,
                moveSpeedMultiplier = 2.5,
                damageMultiplier = 2.0,
            },
        },
        
        -- 远程攻击
        canShoot = true,
        attackRange = 25.0,
        projectileSpeed = 6.0,
        attackCooldown = 1.2,
        
        -- 掉落（最终Boss奖励）
        dropXp = 300,
        dropCrystal = {min = 100, max = 150},
        
        -- 外观（3倍大小）
        scale = 7.8,  -- 视觉大小（碰撞半径 = scale）
        bodyColor = {r = 0.3, g = 0.1, b = 0.4},   -- 紫色调
        glowColor = {r = 0.8, g = 0.2, b = 0.9},   -- 亮紫色发光
        
        -- 特殊显示
        showHealthBar = true,
        bossName = "虫族女王",
        
        description = "虫族战役最终Boss，体型巨大，弹幕凶猛",
    },
}

-- ============================================================================
-- 工具函数
-- ============================================================================

-- 获取敌人定义
function Enemies.Get(enemyId)
    return Enemies.List[enemyId]
end

-- 获取所有敌人ID
function Enemies.GetAllIds()
    local ids = {}
    for id, _ in pairs(Enemies.List) do
        table.insert(ids, id)
    end
    return ids
end

-- 获取非Boss敌人
function Enemies.GetNonBoss()
    local result = {}
    for id, enemy in pairs(Enemies.List) do
        if not enemy.isBoss then
            result[id] = enemy
        end
    end
    return result
end

-- 获取Boss敌人
function Enemies.GetBosses()
    local result = {}
    for id, enemy in pairs(Enemies.List) do
        if enemy.isBoss then
            result[id] = enemy
        end
    end
    return result
end

-- 根据权重随机选择敌人
function Enemies.GetRandomByWeight(enemyIds)
    local totalWeight = 0
    local validEnemies = {}
    
    for _, id in ipairs(enemyIds) do
        local enemy = Enemies.List[id]
        if enemy and not enemy.isBoss then
            totalWeight = totalWeight + (enemy.spawnWeight or 1)
            table.insert(validEnemies, {id = id, weight = enemy.spawnWeight or 1})
        end
    end
    
    if totalWeight == 0 then return nil end
    
    local roll = math.random() * totalWeight
    local cumWeight = 0
    
    for _, e in ipairs(validEnemies) do
        cumWeight = cumWeight + e.weight
        if roll <= cumWeight then
            return e.id
        end
    end
    
    return validEnemies[1] and validEnemies[1].id or nil
end

-- 获取敌人列表（用于波次配置）
function Enemies.GetBasicTypes()
    return {"Spore", "PirateGun", "Carapace"}
end

function Enemies.GetAdvancedTypes()
    return {"HealerBug", "SuicideBug", "Elite"}
end

function Enemies.GetAllTypes()
    return {"Spore", "PirateGun", "Carapace", "HealerBug", "SuicideBug", "Elite"}
end

return Enemies
