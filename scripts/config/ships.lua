-- ============================================================================
-- 星河战姬 Starkyries - 战舰配置
-- 垂直切片v1：2艘战舰（按VS文档要求）
-- ============================================================================

local Ships = {}

-- ============================================================================
-- 单位说明
-- ============================================================================
-- 长度单位：米（与 UrhoX 引擎一致）
-- 速度单位：米/秒
-- 参考：屏幕宽度 ≈ 40 米，屏幕高度 ≈ 22 米

-- ============================================================================
-- 资源规范
-- ============================================================================
-- 角色图片目录结构：image/{角色名}/
--   - 头像.jpg      舰长头像（用于战舰选择界面）
--   - 其他表情.jpg  对话系统用的表情立绘
-- 
-- 图片格式规范：
--   - 角色相关图片统一使用 JPG 格式（节省空间）
--   - UI 元素、图标等需要透明通道的使用 PNG 格式
--
-- 分辨率规范：
--   - 头像：512×512（正方形）
--   - 立绘：2048×2048（正方形）
--   - 场景背景：1920×1080
--
-- 详见：assets/README.md

-- ============================================================================
-- 战舰基础数值（来自VS文档）
-- ============================================================================
Ships.BaseStats = {
    maxShield = 25,           -- 基础最大护盾
    shieldRegen = 0,          -- 基础护盾再生值（HP/s = 0.20 + (值-1) × 0.089）
    energyAbsorb = 0,         -- 基础能量吸收（上限10护盾/秒）
    weaponSlots = 6,          -- 基础武器槽位
    moveSpeed = 10.0,         -- 基础移动速度 10 米/秒（100%）
    armor = 0,                -- 基础装甲
    dodge = 0,                -- 基础闪避
}

-- ============================================================================
-- 战舰数据
-- VS版本：2艘战舰
-- - SSA-01 先锋号：通用型，无负面，专注验证武器效果
-- - SSA-10 多面号：多武器型，验证6武器同时射击的视觉表现
-- ============================================================================

Ships.List = {
    -- ========== SSA-01 先锋号（新手入门/默认）==========
    -- VS用途：测试所有武器类型
    Pioneer = {
        id = "Pioneer",
        code = "SSA-01",
        name = "先锋号",
        captain = "星遥",
        captainPortrait = "image/星遥/头像.jpg",  -- 舰长头像
        tier = 1,
        role = "新手友好",
        tags = {"通用", "资源"},  -- 标签匹配系统用
        
        -- 基础属性
        shield = 30,              -- 基础25 + 5
        shieldRegen = 0,
        energyAbsorb = 0,
        armor = 0,
        dodge = 0,
        moveSpeed = 10.5,         -- 基础10.0 × 1.05 = +5% (米/秒)
        weaponSlots = 6,
        
        -- 加成说明
        bonuses = {
            {desc = "引擎推力+5%"},
            {desc = "最大护盾+5"},
            {desc = "资源回收+5%"},
        },
        penalties = {},  -- 无惩罚
        
        -- 特殊效果
        special = {
            crystalBonus = 0.05,  -- +5%晶体
        },
        
        -- 外观颜色
        hullColor = {r = 0.2, g = 0.35, b = 0.6},
        accentColor = {r = 0.4, g = 0.7, b = 1.0},
        engineColor = {r = 0.3, g = 0.6, b = 1.0},
        
        -- 武器槽位（6个，位置单位：米）
        -- 坐标系：x=船长方向(+前-后), y=高度(+上), z=船宽方向(+右-左)
        -- 先锋号主体尺寸约 3.0×0.5×0.7 米
        weaponSlots = {
            {x = 0.6, y = 0.45, z = 0.30},   -- 槽位1: 前右侧
            {x = 0.6, y = 0.45, z = -0.30},  -- 槽位2: 前左侧
            {x = -0.2, y = 0.50, z = 0.32},  -- 槽位3: 中右侧（舰桥旁）
            {x = -0.2, y = 0.50, z = -0.32}, -- 槽位4: 中左侧（舰桥旁）
            {x = -0.8, y = 0.40, z = 0.25},  -- 槽位5: 后右侧（引擎前）
            {x = -0.8, y = 0.40, z = -0.25}, -- 槽位6: 后左侧（引擎前）
        },
        
        description = "均衡型战舰，无惩罚，适合学习游戏基础",
        unlockCondition = "default",
    },
    
    -- ========== SSA-10 多面号（多武器流）==========
    -- 对标Brotato多面手(Multitasker)：12武器槽，+20%伤害，每武器-5%伤害
    Polyhedron = {
        id = "Polyhedron",
        code = "SSA-10",
        name = "多面号",
        captain = "伊芙",
        captainPortrait = "image/伊芙/头像.jpg",  -- 舰长头像
        tier = 2,
        role = "多武器",
        tags = {"火力", "通用"},  -- 标签匹配系统用
        
        -- 基础属性
        shield = 25,
        shieldRegen = 0,
        energyAbsorb = 0,
        armor = 0,
        dodge = 0,
        moveSpeed = 10.0,         -- 基础速度 10 米/秒
        maxWeaponSlots = 12,      -- 12武器槽位（Brotato多面手核心）
        
        -- 无初始武器（需要在商店购买）
        initialWeapon = nil,
        initialWeaponCount = 0,
        
        -- 加成说明（对标Brotato）
        bonuses = {
            {stat = "damagePercent", value = 20, desc = "火力输出+20%"},
            {stat = "weaponSlots", value = 6, desc = "武器槽位+6（共12个）"},
        },
        penalties = {
            {stat = "damagePerWeapon", value = -5, desc = "每装备一把武器：火力输出-5%"},
        },
        
        -- 特殊效果（对标Brotato多面手）
        special = {
            damageBonus = 0.20,              -- +20%火力
            damagePerWeaponPenalty = -0.05,  -- 每把武器-5%火力
        },
        
        -- 外观颜色
        hullColor = {r = 0.4, g = 0.3, b = 0.5},
        accentColor = {r = 0.7, g = 0.5, b = 0.9},
        engineColor = {r = 0.6, g = 0.4, b = 0.8},
        
        -- 武器槽位（12个，位置单位：米）
        -- 坐标系：x=船长方向(+前-后), y=高度(+上), z=船宽方向(+右-左)
        -- 与 ShipModels.lua 中的 mountPositions 视觉位置对齐
        weaponSlots = {
            -- 前排2个
            {x = 1.0, y = 0.40, z = 0.4},
            {x = 1.0, y = 0.40, z = -0.4},
            -- 中前排2个
            {x = 0.5, y = 0.42, z = 0.55},
            {x = 0.5, y = 0.42, z = -0.55},
            -- 中排2个
            {x = 0, y = 0.45, z = 0.5},
            {x = 0, y = 0.45, z = -0.5},
            -- 中后排2个
            {x = -0.5, y = 0.42, z = 0.45},
            {x = -0.5, y = 0.42, z = -0.45},
            -- 后排2个
            {x = -1.0, y = 0.40, z = 0.35},
            {x = -1.0, y = 0.40, z = -0.35},
            -- 侧翼2个
            {x = 0.2, y = 0.42, z = 0.65},
            {x = 0.2, y = 0.42, z = -0.65},
        },
        
        description = "12武器槽位，+20%火力，但每装备一把武器-5%火力（满配净-40%）",
        unlockCondition = "collect_5000_crystals",  -- 对标Brotato：5000材料
        difficulty = 4,  -- ★★★★☆
    },
}

-- ============================================================================
-- 工具函数
-- ============================================================================

-- 获取战舰定义
function Ships.Get(shipId)
    return Ships.List[shipId]
end

-- 获取所有战舰ID
function Ships.GetAllIds()
    local ids = {}
    for id, _ in pairs(Ships.List) do
        table.insert(ids, id)
    end
    return ids
end

-- 获取所有战舰（列表形式）
function Ships.GetAll()
    local list = {}
    for id, ship in pairs(Ships.List) do
        table.insert(list, ship)
    end
    -- 按tier排序
    table.sort(list, function(a, b)
        return a.tier < b.tier
    end)
    return list
end

-- 获取默认战舰（游戏开始时使用）
function Ships.GetDefault()
    return Ships.List.Pioneer
end

-- 获取战舰数量
function Ships.GetCount()
    local count = 0
    for _ in pairs(Ships.List) do
        count = count + 1
    end
    return count
end

-- 计算战舰的武器伤害修正（VS简化版无惩罚）
function Ships.GetWeaponDamageMultiplier(ship, weaponCount)
    if ship.special and ship.special.weaponDamagePenaltyPerSlot then
        return 1.0 + ship.special.weaponDamagePenaltyPerSlot * weaponCount
    end
    return 1.0
end

-- 计算狂战士射速加成（VS版本未使用）
function Ships.GetBerserkerFireRateBonus(ship, shieldPercent)
    if ship.special and ship.special.berserkerMode then
        local shieldLoss = 1.0 - shieldPercent
        return shieldLoss * 100 * ship.special.fireRatePerShieldLoss
    end
    return 0
end

return Ships
