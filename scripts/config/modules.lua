-- ============================================================================
-- 星河战姬 Starkyries - 模块配置（聚合器）
-- 严格对齐设计文档 2.3-模块数据.md
-- ============================================================================

local Modules = {}

-- ============================================================================
-- 模块类型定义
-- ============================================================================
Modules.Types = {
    FIRE_CONTROL = "fire_control",   -- 火控模块
    DEFENSE = "defense",             -- 防御模块
    ENGINE = "engine",               -- 引擎模块
    RESOURCE = "resource",           -- 资源模块
    TACTICAL = "tactical",           -- 战术模块
    EXPERIMENTAL = "experimental",   -- 实验模块
    SPECIAL = "special",             -- 特殊模块
}

-- ============================================================================
-- 标签系统（用于商店标签匹配）
-- ============================================================================
Modules.TypeToTags = {
    [Modules.Types.FIRE_CONTROL] = {"火力"},
    [Modules.Types.DEFENSE] = {"防御"},
    [Modules.Types.ENGINE] = {"速度"},
    [Modules.Types.RESOURCE] = {"资源"},
    [Modules.Types.TACTICAL] = {"战术"},
    [Modules.Types.EXPERIMENTAL] = {"实验"},
    [Modules.Types.SPECIAL] = {"特殊"},
}

--- 获取模块的标签列表
--- @param module table 模块数据
--- @return table 标签列表
function Modules.GetTags(module)
    if not module then return {} end
    -- 优先使用模块自定义标签
    if module.tags then
        return module.tags
    end
    -- 否则使用类型默认标签
    return Modules.TypeToTags[module.type] or {}
end

-- ============================================================================
-- 品质定义（对标Brotato）
-- T1: 8-30g  基础效果
-- T2: 30-60g 进阶效果
-- T3: 50-90g 强力效果
-- T4: 90-130g 改变机制
-- ============================================================================
Modules.Tiers = {
    T1 = 1,
    T2 = 2,
    T3 = 3,
    T4 = 4,
}

-- ============================================================================
-- 从子模块加载模块数据
-- ============================================================================
local moduleCategories = {
    "config.modules.fire_control",
    "config.modules.defense",
    "config.modules.engine",
    "config.modules.tactical",
    "config.modules.experimental",
    "config.modules.special",
}

Modules.List = {}

for _, modPath in ipairs(moduleCategories) do
    local register = require(modPath)
    local items = register(Modules)
    for _, item in ipairs(items) do
        table.insert(Modules.List, item)
    end
end

-- ============================================================================
-- 舰桥升级系统（直接注入到 Modules 上）
-- ============================================================================
local registerBridge = require("config.modules.bridge")
registerBridge(Modules)

-- ============================================================================
-- 🚧 未实现模块列表（共40个）
-- 以下模块在设计文档 2.3-模块数据.md 中已定义,但尚未在代码中实现
-- ============================================================================

--[[
================================================================================
引擎模块 - 修复包类（3个）
================================================================================
-- TODO: 急救包 (first_aid)
--       T1, 15g, 修复包效果+25%, 火力输出-1%

-- TODO: 自动医疗 (auto_medic)
--       T2, 35g, 护盾<30%自动使用修复包, 最大护盾-5

-- TODO: 医疗系统 (medical_system)
--       T2, 45g, 修复包效果+50%+每波额外1修复包, 火力输出-3%

================================================================================
战术模块 - 击毁触发（1个缺失）
================================================================================
-- TODO: 残骸分析 (wreckage_analysis)
--       T3, 55g, 击毁敌舰时5%几率获得属性提升, 火力输出-5%

================================================================================
战术模块 - 受伤触发（1个缺失）
================================================================================
-- TODO: 牺牲 (sacrifice)
--       T3, 55g, 受到致命伤害时消耗50晶体存活, 资源回收-10

================================================================================
战术模块 - 周期触发（4个,全部缺失）
================================================================================
-- TODO: 自动修复 (auto_repair)
--       T2, 30g, 每5秒回复3护盾, 火力输出-3%

-- TODO: 能量脉冲 (energy_pulse)
--       T2, 35g, 每5秒获得+20%攻速持续2秒, 最大护盾-5

-- TODO: 持续增益 (continuous_buff)
--       T2, 45g, 每10秒随机获得一个属性+5%, 引擎推力-3%

-- TODO: 时间炸弹 (time_bomb)
--       T3, 50g, 每10秒对周围敌舰造成50伤害, 护盾再生-2

================================================================================
战术模块 - 条件触发（4个缺失）
================================================================================
-- TODO: 速战速决 (quick_battle)
--       T1, 22g, 波次前20秒+30%伤害, 护盾再生-1

-- TODO: 单打独斗 (solo_fighter)
--       T2, 30g, 场上<5敌舰时+30%伤害, 最大护盾-5

-- TODO: 持久战 (endurance)
--       T2, 30g, 波次60秒后+50%伤害, 火力输出-5%（前60秒）

-- TODO: 重围之中 (surrounded)
--       T2, 35g, 周围>10敌舰时+20%攻速+10%护盾再生, 规避-5%

================================================================================
战术模块 - 拾取触发（3个,全部缺失）
================================================================================
-- TODO: 能量共振 (energy_resonance)
--       T1, 22g, 拾取晶体时回复1护盾, 火力输出-2%

-- TODO: 磁力爆发 (magnetic_burst)
--       T2, 35g, 拾取晶体15%几率对随机敌舰造成3伤害(+10%运势加成), 最大护盾-5

-- TODO: 晶体过载 (crystal_overload)
--       T2, 45g, 连续拾取5个晶体后下次攻击+50%伤害, 射击频率-3%

================================================================================
战术模块 - 连锁触发（2个缺失）
================================================================================
-- TODO: 能量爆发 (energy_explosion)
--       T2, 45g, 击毁敌舰时25%几率产生小范围爆炸, 火力输出-3%

-- TODO: 毁灭共鸣 (destruction_resonance)
--       T3, 55g, 每击毁5敌舰下一击毁必定触发连锁, 护盾再生-2

================================================================================
战术模块 - DOT/燃烧类（2个缺失）
================================================================================
-- TODO: 腐蚀扩散 (corrosion_spread)
--       T3, 50g, 等离子灼烧扩散到附近1个敌舰, 火力输出-5%

-- TODO: 离子过载 (ion_overload)
--       T3, 55g, 被灼烧敌舰死亡时爆炸对周围敌舰造成5伤害, 最大护盾-8

================================================================================
实验模块 - 不稳定系列（3个缺失）
================================================================================
-- TODO: 过载核心 (overload_core)
--       T2, 45g, 射击频率+40%, 攻击时5%几率自伤5

-- TODO: 不稳定弹药 (unstable_ammo)
--       T2, 45g, 暴击时爆炸伤害+100, 暴击时自伤10

-- TODO: 危险实验 (dangerous_experiment)
--       T3, 50g, 所有属性+10%, 敌舰伤害+25%

================================================================================
实验模块 - 诅咒系列（4个缺失）
================================================================================
-- TODO: 命运赌局 (fate_gamble)
--       T2, 30g, 每波随机+50%属性, 每波随机-25%属性

-- TODO: 力量代价 (power_price)
--       T2, 45g, 近程强化+50%, 每次攻击-1护盾

-- TODO: 血之饥渴 (blood_thirst)
--       T3, 50g, 能量吸收+20%, 无法使用修复包+护盾再生-100

-- TODO: 死神之手 (deaths_hand)
--       T3, 50g, 击毁敌舰+5晶体, 被击毁时损失所有晶体

================================================================================
实验模块 - 疯狂系列（2个缺失）
================================================================================
-- TODO: 禁忌之力 (forbidden_power)
--       T3, 55g, 所有类型伤害+30%, 敌舰+30%速度

-- TODO: 疯狂科学家 (mad_scientist)
--       T3, 65g, 工程+60%, 非召唤物伤害-50%

================================================================================
实验模块 - 经济代价系列（4个,全部缺失）
================================================================================
-- TODO: 节俭存储 (frugal_storage) [唯一]
--       T2, 45g, 每波开始+15%晶体, 所有价格+30%

-- TODO: 献血协议 (blood_donation)
--       T3, 50g, 资源回收+40, 每秒损失1护盾

-- TODO: 物资专家 (material_expert)
--       T3, 50g, 每持有25晶体火力+1%(500晶体=+20%), 武器/模块价格+50%

-- TODO: 拖拉机芯片 (tractor_chip)
--       T3, 70g, 资源回收+40, 火力输出-8%

================================================================================
特殊模块（7个缺失）
================================================================================
-- TODO: 护盾转换 (shield_convert_special)
--       T3, 50g, 将装甲转换为护盾(×5), 装甲归零

-- TODO: 经济转换 (economy_convert)
--       T3, 55g, 伤害的5%转化为晶体, 火力输出-5%

-- TODO: 吸收护盾 (absorb_shield)
--       T3, 60g, 吸收导弹攻击转化为护盾, 规避-5%

-- TODO: 时间减速 (time_slow)
--       T3, 65g, 敌舰移动速度-20%, 射击频率-5%

-- TODO: 武器融合 (weapon_fusion)
--       T3, 70g, 相同武器合并为更强版本, 火力输出-3%

-- TODO: 隐身装置 (stealth_device) [唯一]
--       T4, 90g, 静止3秒后获得隐身敌舰不会攻击你, 引擎推力-10%

-- TODO: 敌人转化 (enemy_convert) [唯一]
--       T4, 100g, 击毁敌舰5%几率转化为友军, 资源回收-15

================================================================================
总计: 40个模块待实现
- 引擎-修复包类: 3个
- 战术模块: 17个
- 实验模块: 13个
- 特殊模块: 7个
================================================================================
]]

-- ============================================================================
-- 工具函数
-- ============================================================================

function Modules.GetById(moduleId)
    for _, module in ipairs(Modules.List) do
        if module.id == moduleId then
            return module
        end
    end
    return nil
end

-- 别名，兼容旧代码
Modules.Get = Modules.GetById

function Modules.GetByType(moduleType)
    local result = {}
    for _, module in ipairs(Modules.List) do
        if module.type == moduleType then
            table.insert(result, module)
        end
    end
    return result
end

function Modules.GetByRarity(rarity)
    local result = {}
    for _, module in ipairs(Modules.List) do
        if module.rarity == rarity then
            table.insert(result, module)
        end
    end
    return result
end

function Modules.GetByTier(tier)
    local result = {}
    for _, module in ipairs(Modules.List) do
        if module.tier == tier then
            table.insert(result, module)
        end
    end
    return result
end

function Modules.GetRandom(rarityWeights)
    rarityWeights = rarityWeights or {[1] = 60, [2] = 30, [3] = 10}
    
    local totalWeight = 0
    local availableByRarity = {}
    
    for rarity, weight in pairs(rarityWeights) do
        local modules = Modules.GetByRarity(rarity)
        if #modules > 0 then
            availableByRarity[rarity] = modules
            totalWeight = totalWeight + weight
        end
    end
    
    local roll = math.random() * totalWeight
    local cumWeight = 0
    local selectedRarity = 1
    
    for rarity, weight in pairs(rarityWeights) do
        cumWeight = cumWeight + weight
        if roll <= cumWeight and availableByRarity[rarity] then
            selectedRarity = rarity
            break
        end
    end
    
    local pool = availableByRarity[selectedRarity] or Modules.List
    return pool[math.random(#pool)]
end

function Modules.GetCount()
    return #Modules.List
end

-- 获取唯一模块列表
function Modules.GetUniqueModules()
    local result = {}
    for _, module in ipairs(Modules.List) do
        if module.isUnique then
            table.insert(result, module)
        end
    end
    return result
end

--- 获取所有可购买模块（商店用）
--- @return table 模块列表
function Modules.GetAllPurchasable()
    local result = {}
    for _, module in ipairs(Modules.List) do
        -- 排除不可购买的模块（如果有 purchasable = false 字段）
        if module.purchasable ~= false then
            table.insert(result, module)
        end
    end
    return result
end

return Modules
