-- ============================================================================
-- 星河战姬 Starkyries - 效果定义
-- 数据驱动的效果配置，所有触发型效果在此定义
-- ============================================================================

local Events = require("config.events")

local Effects = {
    Definitions = {},
    
    -- 效果分类（用于 UI 显示和调试）
    Categories = {
        COMBAT = "combat",       -- 战斗效果
        SURVIVAL = "survival",   -- 生存效果
        RESOURCE = "resource",   -- 资源效果
        UTILITY = "utility",     -- 工具效果
    },
}

-- ============================================================================
-- 击杀触发效果
-- ============================================================================

-- 杀戮快感：击毁敌人回复护盾
Effects.Definitions["heal_on_kill"] = {
    trigger = Events.ENEMY_DEATH,
    category = Effects.Categories.SURVIVAL,
    description = "击毁敌人回复护盾",
    
    condition = function(ctx)
        return ctx.player.killHeal and ctx.player.killHeal > 0
    end,
    
    execute = function(ctx)
        local Game = require("core.Game")
        local healAmount = ctx.player.killHeal
        Game.Heal(healAmount)
        
        -- 可选：触发回血特效
        if ctx.debug then
            print(string.format("[Effect] heal_on_kill: +%d shield", healAmount))
        end
    end,
    
    priority = 0,
}

-- 恶魔契约击杀回血：优先级更高的回血效果
Effects.Definitions["demon_pact_heal"] = {
    trigger = Events.ENEMY_DEATH,
    category = Effects.Categories.SURVIVAL,
    description = "恶魔契约：击毁敌人回复额外护盾",
    
    condition = function(ctx)
        return ctx.player.hasDemonPact and ctx.player.demonPactKillHeal
    end,
    
    execute = function(ctx)
        local Game = require("core.Game")
        local healAmount = ctx.player.demonPactKillHeal
        Game.Heal(healAmount)
        
        if ctx.debug then
            print(string.format("[Effect] demon_pact_heal: +%d shield", healAmount))
        end
    end,
    
    priority = 10,  -- 优先于普通击杀回血
}

-- 死亡连锁：击毁时几率造成连锁伤害
Effects.Definitions["death_chain"] = {
    trigger = Events.ENEMY_DEATH,
    category = Effects.Categories.COMBAT,
    description = "击毁敌人时有几率造成连锁伤害",
    
    condition = function(ctx)
        if not ctx.player.deathChainChance then return false end
        if ctx.player.deathChainChance <= 0 then return false end
        
        -- 随机判定
        local roll = math.random()
        ctx._chainRoll = roll  -- 保存用于调试
        return roll < ctx.player.deathChainChance
    end,
    
    execute = function(ctx)
        local EffectSystem = require("core.EffectSystem")
        local enemy = ctx.event.enemy
        
        if not enemy then return end
        
        -- 连锁伤害 = 原伤害的 50%
        local chainDamage = (ctx.event.damage or 10) * 0.5
        local chainRadius = 80
        
        EffectSystem.TriggerChainDamage(enemy.x, enemy.y, chainDamage, chainRadius)
        
        if ctx.debug then
            print(string.format("[Effect] death_chain: %.1f damage at (%.1f, %.1f)", 
                chainDamage, enemy.x, enemy.y))
        end
    end,
    
    priority = -10,  -- 低优先级，确保其他效果先执行
}

-- 高效回收：击毁额外获得晶体
Effects.Definitions["kill_crystal_bonus"] = {
    trigger = Events.ENEMY_DEATH,
    category = Effects.Categories.RESOURCE,
    description = "击毁敌人额外获得晶体",
    
    condition = function(ctx)
        return ctx.player.killCrystalBonus and ctx.player.killCrystalBonus > 0
    end,
    
    execute = function(ctx)
        local Game = require("core.Game")
        local bonusCrystals = ctx.player.killCrystalBonus
        Game.AddCrystals(bonusCrystals)
        
        if ctx.debug then
            print(string.format("[Effect] kill_crystal_bonus: +%d crystals", bonusCrystals))
        end
    end,
    
    priority = 0,
}

-- ============================================================================
-- 受伤触发效果
-- ============================================================================

-- 紧急加速：受伤时获得速度加成
Effects.Definitions["emergency_boost"] = {
    trigger = Events.PLAYER_DAMAGE,
    category = Effects.Categories.UTILITY,
    description = "受伤时获得短暂速度加成",
    
    condition = function(ctx)
        -- 必须拥有该效果且当前未激活
        if not ctx.player.hasEmergencyBoost then return false end
        if ctx.player.emergencyBoostActive then return false end
        return true
    end,
    
    execute = function(ctx)
        -- 激活紧急加速状态
        ctx.player.emergencyBoostActive = true
        ctx.player.emergencyBoostTimer = ctx.player.emergencyBoostDuration or 2.0
        
        if ctx.debug then
            print(string.format("[Effect] emergency_boost: activated for %.1fs", 
                ctx.player.emergencyBoostTimer))
        end
    end,
    
    priority = 0,
}

-- ============================================================================
-- 周期性效果（需要 GAME_TICK 事件支持）
-- ============================================================================

-- 恶魔契约消耗：每秒扣除护盾
Effects.Definitions["demon_pact_drain"] = {
    trigger = Events.GAME_TICK,  -- 每秒触发
    category = Effects.Categories.SURVIVAL,
    description = "恶魔契约：每秒消耗护盾",
    
    condition = function(ctx)
        return ctx.player.hasDemonPact and ctx.player.demonPactDrain
    end,
    
    execute = function(ctx)
        local Game = require("core.Game")
        local drainAmount = ctx.player.demonPactDrain
        
        -- 直接扣血，忽略无敌时间
        Game.DirectDamage(drainAmount)
        
        if ctx.debug then
            print(string.format("[Effect] demon_pact_drain: -%d shield", drainAmount))
        end
    end,
    
    priority = -100,  -- 最低优先级，最后执行
}

-- ============================================================================
-- 攻击触发效果
-- ============================================================================

-- 等离子灼烧：攻击时几率造成 DOT
Effects.Definitions["plasma_burn"] = {
    trigger = Events.WEAPON_HIT,
    category = Effects.Categories.COMBAT,
    description = "攻击时有几率点燃敌人",
    
    condition = function(ctx)
        if not ctx.player.burnChance then return false end
        if ctx.player.burnChance <= 0 then return false end
        
        local roll = math.random()
        ctx._burnRoll = roll
        return roll < ctx.player.burnChance
    end,
    
    execute = function(ctx)
        local enemy = ctx.event.target
        if not enemy then return end
        
        -- 设置敌人燃烧状态
        enemy.isBurning = true
        enemy.burnDamage = (ctx.event.damage or 10) * 0.3  -- 每秒 30% 原伤害
        enemy.burnDuration = 3.0  -- 持续 3 秒
        enemy.burnTimer = enemy.burnDuration
        
        if ctx.debug then
            print(string.format("[Effect] plasma_burn: enemy burning for %.1f damage/s", 
                enemy.burnDamage))
        end
    end,
    
    priority = 0,
}

-- ============================================================================
-- Boss 相关效果
-- ============================================================================

-- 银弹效果在伤害计算时应用，不在此定义
-- 满盾/低盾伤害加成在伤害计算时应用，不在此定义
-- 这些是"被动计算型"效果，保持在原有系统中

-- ============================================================================
-- 效果注册辅助函数
-- ============================================================================

-- 获取所有效果 ID
function Effects.GetAllIds()
    local ids = {}
    for id in pairs(Effects.Definitions) do
        table.insert(ids, id)
    end
    return ids
end

-- 获取指定类别的效果
function Effects.GetByCategory(category)
    local result = {}
    for id, def in pairs(Effects.Definitions) do
        if def.category == category then
            result[id] = def
        end
    end
    return result
end

-- 获取指定触发事件的效果
function Effects.GetByTrigger(trigger)
    local result = {}
    for id, def in pairs(Effects.Definitions) do
        if def.trigger == trigger then
            result[id] = def
        end
    end
    return result
end

-- 验证效果定义完整性
function Effects.Validate()
    local errors = {}
    
    for id, def in pairs(Effects.Definitions) do
        if not def.trigger then
            table.insert(errors, string.format("Effect '%s' missing trigger", id))
        end
        if not def.execute then
            table.insert(errors, string.format("Effect '%s' missing execute function", id))
        end
        if type(def.execute) ~= "function" then
            table.insert(errors, string.format("Effect '%s' execute is not a function", id))
        end
        if def.condition and type(def.condition) ~= "function" then
            table.insert(errors, string.format("Effect '%s' condition is not a function", id))
        end
    end
    
    return #errors == 0, errors
end

return Effects
