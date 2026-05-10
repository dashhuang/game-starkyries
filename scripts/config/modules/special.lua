-- ============================================================================
-- 星河战姬 Starkyries - 特殊模块配置
-- ============================================================================

local function register(Modules)
    return {
    -- ========================================================================
    -- 特殊模块
    -- ========================================================================

    -- 传送装置（唯一）
    {
        id = "teleporter",
        name = "传送装置",
        type = Modules.Types.SPECIAL,
        tier = Modules.Tiers.T3,
        description = "受到致命伤害时传送到安全位置(每波1次),最大护盾-10",
        price = 60,
        maxStack = 1,
        rarity = 3,
        isUnique = true,
        lore = "创世遗迹中发现的空间折叠技术。当死亡逼近时，它会将使用者传送到安全地点。\n\n「我见过死亡的脸，」幸存者说，「然后我出现在了别处。那一秒像是永恒。」",
        effect = function(p)
            p.hasTeleporter = true
            p.maxShield = p.maxShield - 10
        end,
    },

    -- 完美防御（唯一）
    {
        id = "perfect_defense",
        name = "完美防御",
        type = Modules.Types.SPECIAL,
        tier = Modules.Tiers.T4,
        description = "每10秒免疫所有伤害1秒,火力输出-8%",
        price = 95,
        maxStack = 1,
        rarity = 4,
        isUnique = true,
        lore = "来自创世遗迹最深处的防御科技。它能够创造一个绝对无敌的力场——但只能维持一瞬间。\n\n「一秒钟，」铁壁号舰长林德曼说，「在战场上，一秒钟就是生与死的距离。」",
        effect = function(p)
            p.hasPerfectDefense = true
            p.perfectDefenseInterval = 10.0
            p.perfectDefenseDuration = 1.0
            p.damageMultiplier = p.damageMultiplier - 0.08
        end,
    },

    -- 量子锚定（唯一）
    {
        id = "quantum_anchor",
        name = "量子锚定",
        type = Modules.Types.SPECIAL,
        tier = Modules.Tiers.T4,
        description = "每波开始时记录状态,死亡时恢复(每局1次),火力输出-10%",
        price = 110,
        maxStack = 1,
        rarity = 4,
        isUnique = true,
        lore = "时间锚定技术——在量子层面记录你的存在状态，在死亡时将你「拉回」到记录点。\n\n「这不是复活，」研究员解释道，「这是让死亡从未发生。代价是……你会记得那种感觉。」\n\n没有人愿意描述那种感觉。",
        effect = function(p)
            p.hasQuantumAnchor = true
            p.damageMultiplier = p.damageMultiplier - 0.10
        end,
    },
    }
end

return register
