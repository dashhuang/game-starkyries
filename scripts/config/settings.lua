-- ============================================================================
-- 星河战姬 Starkyries - 游戏设置
-- ============================================================================

local Settings = {}

-- ============================================================================
-- 单位系统说明（米）
-- ============================================================================
-- 游戏世界使用"米"作为长度单位（与 UrhoX 引擎一致）
-- 1 米 ≈ 玩家战舰高度（短边）
-- 
-- 参考尺寸：
--   战舰高度（短边）≈ 1 米
--   战舰长度（长边）≈ 3 米
--   能量晶体 ≈ 0.5 米
--   小型敌舰 ≈ 1 米
--   屏幕宽度 ≈ 40 米
--   屏幕高度 ≈ 22 米
--
-- 距离分类：
--   贴脸: 0-1 米
--   近距离: 1-3 米
--   中距离: 3-8 米
--   远距离: 8-20 米
--   超远: 20+ 米
--
-- 速度单位：米/秒
--   玩家基础速度: 10 米/秒
--   慢速敌舰: 3-5 米/秒
--   普通敌舰: 5-8 米/秒
--   快速敌舰: 8-10 米/秒
-- ============================================================================

-- 游戏标题
Settings.Title = "星河战姬 Starkyries"

-- 战场边界（单位：米）
-- 横向更宽的竞技场，支持横屏和竖屏
Settings.BattleArea = {
    MinX = -37.5, MaxX = 37.5,  -- 宽度 75 米
    MinY = -25, MaxY = 25       -- 高度 50 米
}

-- 可视区域配置（单位：米）
-- 短边保证至少看到 MinSize 米，长边根据屏幕比例扩展
Settings.VisibleArea = {
    MinSize = 28,           -- 短边最小可视尺寸
    MaxSize = 50            -- 长边最大可视尺寸（不超过竞技场）
}

-- 相机配置
Settings.Camera = {
    FOV = 50,               -- 视场角（固定）
    NearClip = 0.5,
    FarClip = 100.0,
    -- 跟随参数
    FollowSmoothing = 5.0,  -- 跟随平滑度（越大越快跟上）
    DeadZone = 1.0          -- 死区半径
}

-- 敌人生成配置（单位：米）
Settings.Spawn = {
    Margin = 2.0,           -- 屏幕外多远生成 (米)
    WarpWarningTime = 1.2,  -- 跃迁预警时间 (秒)
    MinWarpDistance = 8     -- 跃迁最小玩家距离 (米)
}

-- 拾取物配置（单位：米）
Settings.Pickup = {
    CollectRadius = 1.5,    -- 拾取半径 (米)
    MagnetRadius = 5.0,     -- 磁铁吸引半径 (米)
    Lifetime = 30,          -- 存活时间 (秒)
    SuperMagnetRadius = 100,-- 超级磁铁范围 (米，覆盖全战场)
    AttractorSpeed = 12,    -- 吸引器速度 (米/秒)
}

-- 武器等级倍率（伤害、射速等）
Settings.WeaponTierMultiplier = {
    [1] = 1.0,
    [2] = 1.25,
    [3] = 1.5,
    [4] = 1.75
}

-- 初始资源（对标Brotato）
Settings.InitialResources = {
    crystals = 30,          -- 初始晶体（对标Brotato：30材料）
    experience = 0,         -- 初始经验
}

-- 默认玩家属性
Settings.DefaultPlayerStats = {
    shield = 25,            -- 初始护盾（VS文档：25）
    maxShield = 25,         -- 最大护盾（VS文档：25）
    shieldRegen = 0,        -- 护盾再生
    armor = 0,              -- 装甲
    moveSpeed = 12.0,       -- 移动速度 (米/秒)
    damageMultiplier = 1.0, -- 伤害倍率
    fireRateMultiplier = 1.0, -- 射速倍率
    crystalMultiplier = 1.0,  -- 晶体获取倍率
    energyAbsorb = 0,       -- 攻击回盾概率
    dodgeChance = 0,        -- 闪避概率
    critChance = 0.05,      -- 基础5%暴击
    critDamage = 1.5        -- 暴击伤害倍率
}

-- 舰桥升级配置（基于经验值）
-- 对标设计文档 3.1-资源与经济系统.md
-- 公式：升级所需经验 = (等级 + 3)²
-- 
-- 完整升级表（与Brotato Wiki完全一致）:
-- | 等级 | 所需经验 | 累计经验 |
-- |------|----------|----------|
-- | 1    | 16       | 16       |
-- | 2    | 25       | 41       |
-- | 3    | 36       | 77       |
-- | 4    | 49       | 126      |
-- | 5    | 64       | 190      |
-- | 10   | 169      | 805      |
-- | 15   | 324      | 2,095    |
-- | 20   | 529      | 4,310    |
-- | 25   | 784      | 7,700    |
Settings.BridgeUpgrade = {
    -- 使用公式计算，不再使用查表
    -- Formula: XpForLevel(n) = (n + 3)²
}

-- 商店配置
Settings.Shop = {
    ItemCount = 4,          -- 商店物品数量
    BaseRefreshCost = 5,    -- 基础刷新费用
    RefreshCostMultiplier = 2, -- 刷新费用倍率
    TagMatchBonus = 0.05,   -- 标签匹配加成概率 (+5%)
}

-- 视觉效果
Settings.Visual = {
    StarCount = 300,           -- 星空粒子数量
    InvincibleFlashSpeed = 20, -- 无敌闪烁速度
    ScreenShakeDuration = 0.2, -- 屏幕震动时长 (秒)
    FlameFadeSpeed = 3.0,      -- 引擎火焰渐变速度（每秒）
    HitFlashDuration = 0.08,   -- 受击闪白持续时间 (秒)
    HitFlashCooldown = 0.15,   -- 受击闪白冷却时间 (秒)，防止高频攻击时一直白色
    WeaponFlashDuration = 0.08,-- 武器开火闪光持续时间 (秒)
    TiltAngle = -25,           -- 固定俯视角度（3D 倾斜，Player/Enemy 共用）
}

-- 战斗配置
Settings.Combat = {
    MaxEnemies = 100,          -- 场上敌人上限
    InvincibleTime = 0.5,      -- 受伤后无敌时间 (秒)
    DebrisSpawnInterval = 10,  -- 残骸生成间隔 (秒)
    BossDefeatDelay = 1.0,     -- Boss击败后进入商店的延迟 (秒)
    -- ShieldRegenInterval 已废弃，护盾改为持续回复
    -- 公式: HP/s = 0.20 + (shieldRegen - 1) × 0.089
    PlayerHitRadius = 1.0,     -- 玩家碰撞半径 (米)
    
    -- ========================================================================
    -- 碰撞检测补偿系数
    -- ========================================================================
    -- 敌人的 hitRadius 表示视觉边缘位置，但不同场景需要不同的判定宽松度
    -- 补偿系数 = 判定时使用的半径比例（相对于 hitRadius）
    --
    -- 设计原则：
    -- 1. 武器瞄准/射程判定：使用 50% 半径（中心到边缘的中点）
    --    - 确保大型Boss在视觉合理距离可被击中
    --    - 避免小型敌人被提前命中
    -- 2. 子弹命中判定：使用 95% 半径（接近视觉边缘）
    --    - 子弹体积小，需要宽松判定
    --    - 视觉上子弹接触敌人边缘即命中
    -- 3. 玩家接触伤害：使用 90% 半径（略宽松）
    --    - 给玩家一点安全空间
    --    - 避免"明明没碰到却受伤"的体验
    -- ========================================================================
    
    EdgeDistanceCompensation = 0.5,     -- 边缘距离补偿（武器瞄准、射程判定）
    BulletHitCompensation = 0.95,       -- 子弹命中补偿（子弹碰撞敌人）
    PlayerCollisionCompensation = 0.9,  -- 玩家碰撞补偿（敌人接触玩家）
    MaxEnemyRadius = 15,                -- 最大敌人半径（空间哈希搜索扩展）
}

-- 无人机配置
Settings.Drone = {
    CloseRange = 5,            -- 贴身距离阈值 (米，5米以内等概率随机选目标)
}

-- 特效池配置
Settings.Effects = {
    PoolMaxSize = 50,          -- 特效对象池最大容量
}

-- 生成边距配置
Settings.SpawnMargins = {
    ArenaMargin = 5.0,         -- 竞技场边缘外允许生成距离 (米)
    WarpMargin = 2.0,          -- 跃迁点距可视区域边缘距离 (米)
}

-- ============================================================================
-- 测试模式配置
-- ============================================================================

-- 第10波测试加成（模拟正常游戏9波的成长）
Settings.TestMode = {
    Wave10 = {
        bridgeLevel = 9,
        crystals = 500,
        damageMultiplier = 0.30,      -- +30%
        fireRateMultiplier = 0.20,    -- +20%
        maxShield = 30,               -- +30
        armor = 1,                    -- +1
        critChance = 0.05,            -- +5%
        critDamage = 0.20,            -- +20%
    },
    
    -- 第20波测试加成（模拟正常游戏19波的成长）
    Wave20 = {
        bridgeLevel = 19,
        crystals = 1000,
        damageMultiplier = 0.60,      -- +60%
        fireRateMultiplier = 0.40,    -- +40%
        maxShield = 60,               -- +60
        armor = 2,                    -- +2
        critChance = 0.10,            -- +10%
        critDamage = 0.40,            -- +40%
    },
    
    -- 第10波手动测试（需要选船/加点）
    Wave10Manual = {
        bridgeLevel = 0,              -- 让玩家自己选择全部升级
        crystals = 1000,
        pendingUpgrades = 11,         -- 11次升级机会
        damageMultiplier = 0.30,
        fireRateMultiplier = 0.20,
        maxShield = 30,
        armor = 1,
        critChance = 0.05,
        critDamage = 0.20,
    },
}

return Settings
