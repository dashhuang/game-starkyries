-- ============================================================================
-- PauseUIInventory - 暂停菜单武器/道具格子渲染
-- 从 PauseUI.lua 拆分，负责中间面板（波次+武器+道具）
-- ============================================================================

local UIStyle = require("ui.UIStyle")
local Weapons = require("config.weapons")
local Modules = require("config.modules")
local Settings = require("config.settings")
local Game = require("core.Game")

local PauseUIInventory = {}

-- ============================================================================
-- DPS 计算（local 辅助函数）
-- ============================================================================

--- 计算单把武器的DPS
local function CalculateWeaponDPS(weapon, player)
    local weaponDef = Weapons.List[weapon.id]
    if not weaponDef then return 0 end

    -- 基础伤害（使用tierDamage或damage）
    local baseDamage
    if weaponDef.tierDamage and weaponDef.tierDamage[weapon.tier] then
        baseDamage = weaponDef.tierDamage[weapon.tier]
    else
        local tierMult = Settings.WeaponTierMultiplier[weapon.tier] or 1.0
        baseDamage = (weaponDef.damage or 0) * tierMult
    end

    -- 玩家伤害加成
    baseDamage = baseDamage * (player.damageMultiplier or 1.0)

    -- 武器类型伤害加成
    local weaponType = weaponDef.type
    if weaponType == Weapons.Types.FORCE_FIELD then
        baseDamage = baseDamage + (player.meleeDamageBonus or 0)
    elseif weaponType == Weapons.Types.MACHINEGUN or weaponType == Weapons.Types.MISSILE then
        baseDamage = baseDamage + (player.ballisticDamageBonus or 0)
    elseif weaponType == Weapons.Types.ARC or weaponType == Weapons.Types.LASER then
        baseDamage = baseDamage + (player.energyDamageBonus or 0)
    end

    -- 固定伤害加成
    baseDamage = baseDamage + (player.flatDamageBonus or 0)

    -- 攻速计算（优先使用tierCooldown）
    local baseCooldown = weaponDef.cooldown or 1.0
    if weaponDef.tierCooldown and weaponDef.tierCooldown[weapon.tier] then
        baseCooldown = weaponDef.tierCooldown[weapon.tier]
    end
    local baseFireRate = 1.0 / baseCooldown
    local fireRate = baseFireRate * (player.fireRateMultiplier or 1.0)

    -- 暴击期望
    local finalCritChance = (weaponDef.critChance or 0) + (player.critChance or 0.05)
    finalCritChance = math.min(finalCritChance, 1.0)

    local baseCritMult = weaponDef.critMultiplier or 2.0
    local playerCritBonus = (player.critDamage or 1.5) - 1.5
    local finalCritMult = baseCritMult + playerCritBonus

    local critFactor = 1 + finalCritChance * (finalCritMult - 1)

    -- DPS = 伤害 * 暴击系数 * 攻速
    local dps = baseDamage * critFactor * fireRate
    return dps
end

--- 计算总DPS
local function CalculateTotalDPS(player)
    local totalDPS = 0
    if player.weapons then
        for _, weapon in ipairs(player.weapons) do
            totalDPS = totalDPS + CalculateWeaponDPS(weapon, player)
        end
    end
    return totalDPS
end

-- ============================================================================
-- 中间面板：波次+武器+道具
-- ============================================================================

--- 渲染中间面板
---@param PauseUI table 主模块引用
function PauseUIInventory.RenderCenterPanel(nvg, x, y, w, h, baseUnit, fonts, player, battle, PauseUI)
    -- 波次信息标题
    local titleH = baseUnit * 2.2

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, titleH, baseUnit * 0.4)
    nvgFillColor(nvg, nvgRGBA(30, 35, 45, 245))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, titleH, baseUnit * 0.4)
    nvgStrokeWidth(nvg, 2)
    nvgStrokeColor(nvg, nvgRGBA(255, 180, 60, 150))
    nvgStroke(nvg)

    -- 危险等级 + 波次
    nvgFontSize(nvg, fonts.cardTitle)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 200, 100, 255))
    local waveText = string.format("危险%d - 第%d波（共%d波）",
        battle.dangerLevel or 1,
        battle.currentWave or 1,
        battle.totalWaves or 20)
    nvgText(nvg, x + w / 2, y + titleH / 2, waveText)

    -- 武器面板
    local weaponY = y + titleH + baseUnit * 0.3
    local weaponH = (h - titleH - baseUnit * 0.6) * 0.6
    PauseUIInventory.RenderWeaponsGrid(nvg, x, weaponY, w, weaponH, baseUnit, fonts, player, PauseUI)

    -- 道具面板
    local itemY = weaponY + weaponH + baseUnit * 0.3
    local itemH = h - (itemY - y) - baseUnit * 0.3
    PauseUIInventory.RenderItemsGrid(nvg, x, itemY, w, itemH, baseUnit, fonts, player, PauseUI)
end

-- ============================================================================
-- 武器网格
-- ============================================================================

function PauseUIInventory.RenderWeaponsGrid(nvg, x, y, w, h, baseUnit, fonts, player, PauseUI)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.4)
    nvgFillColor(nvg, nvgRGBA(20, 25, 35, 245))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.4)
    nvgStrokeWidth(nvg, 2)
    nvgStrokeColor(nvg, nvgRGBA(255, 180, 60, 120))
    nvgStroke(nvg)

    -- 标题
    local titleH = baseUnit * 1.8
    nvgFontSize(nvg, fonts.description)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 180, 60, 255))

    local weaponCount = player.weapons and #player.weapons or 0
    local maxSlots = player.maxWeaponSlots or 6
    nvgText(nvg, x + baseUnit * 0.5, y + titleH / 2, string.format("武器(%d/%d)", weaponCount, maxSlots))

    -- DPS显示（右侧）- 使用实时DPS
    local realtimeDPS = Game.GetRealtimeDPS()
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(100, 220, 100, 255))
    nvgText(nvg, x + w - baseUnit * 0.5, y + titleH / 2, string.format("DPS: %.1f", realtimeDPS))

    -- 武器图标网格
    local gridY = y + titleH
    local gridH = h - titleH - baseUnit * 0.3
    local cellSize = baseUnit * 2.8
    local cols = math.floor((w - baseUnit) / (cellSize + baseUnit * 0.3))
    cols = math.max(3, math.min(cols, 6))
    local cellGap = baseUnit * 0.3
    local totalGridW = cols * cellSize + (cols - 1) * cellGap
    local gridStartX = x + (w - totalGridW) / 2

    if player.weapons then
        for i, weapon in ipairs(player.weapons) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local cellX = gridStartX + col * (cellSize + cellGap)
            local cellY = gridY + row * (cellSize + cellGap) + baseUnit * 0.2

            if cellY + cellSize > y + h then break end

            -- 品质颜色
            local tier = weapon.tier or 1
            local tierColor = UIStyle.GetTierColor(tier)

            -- 武器图标
            local weaponDef = Weapons.Get(weapon.id)
            local hasIcon = false

            if weapon.id then
                -- 加载武器图标
                if not PauseUI.weaponImages[weapon.id] then
                    local iconPath = "images/weapons/" .. weapon.id .. ".jpg"
                    local img = nvgCreateImage(nvg, iconPath, 0)
                    if img and img > 0 then
                        PauseUI.weaponImages[weapon.id] = img
                    end
                end

                -- 显示图标（占满整个格子）
                if PauseUI.weaponImages[weapon.id] then
                    hasIcon = true
                    local imgPaint = nvgImagePattern(nvg, cellX, cellY, cellSize, cellSize, 0, PauseUI.weaponImages[weapon.id], 1.0)
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, cellX, cellY, cellSize, cellSize, baseUnit * 0.15)
                    nvgFillPaint(nvg, imgPaint)
                    nvgFill(nvg)

                    -- 品质边框
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, cellX, cellY, cellSize, cellSize, baseUnit * 0.15)
                    nvgStrokeColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 255))
                    nvgStrokeWidth(nvg, 2.5)
                    nvgStroke(nvg)
                end
            end

            -- 没有图标时显示背景和名称缩写
            if not hasIcon then
                local iconGrad = nvgLinearGradient(nvg, cellX, cellY, cellX, cellY + cellSize,
                    nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 60),
                    nvgRGBA(tierColor.r * 0.3, tierColor.g * 0.3, tierColor.b * 0.3, 60))
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, cellX, cellY, cellSize, cellSize, baseUnit * 0.15)
                nvgFillColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 40))
                nvgFill(nvg)
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, cellX, cellY, cellSize, cellSize, baseUnit * 0.15)
                nvgFillPaint(nvg, iconGrad)
                nvgFill(nvg)
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, cellX, cellY, cellSize, cellSize, baseUnit * 0.15)
                nvgStrokeWidth(nvg, 1)
                nvgStrokeColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 100))
                nvgStroke(nvg)

                local weaponAbbr = weaponDef and string.sub(weaponDef.name, 1, 6) or "??"
                nvgFontSize(nvg, cellSize * 0.35)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
                nvgText(nvg, cellX + cellSize / 2, cellY + cellSize * 0.45, weaponAbbr)

                -- Tier标签（底部）
                nvgFontSize(nvg, cellSize * 0.28)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
                nvgFillColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 255))
                nvgText(nvg, cellX + cellSize / 2, cellY + cellSize - cellSize * 0.06, "T" .. tier)
            end

            -- 记录点击区域
            table.insert(PauseUI.weaponRects, {
                x = cellX, y = cellY, w = cellSize, h = cellSize,
                weapon = weapon,
                weaponDef = weaponDef,
            })
        end
    end

    -- 无武器提示
    if weaponCount == 0 then
        nvgFontSize(nvg, fonts.description)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(120, 130, 150, 200))
        nvgText(nvg, x + w / 2, y + h / 2, "暂无武器")
    end
end

-- ============================================================================
-- 道具网格
-- ============================================================================

function PauseUIInventory.RenderItemsGrid(nvg, x, y, w, h, baseUnit, fonts, player, PauseUI)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.4)
    nvgFillColor(nvg, nvgRGBA(20, 25, 35, 245))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.4)
    nvgStrokeWidth(nvg, 2)
    nvgStrokeColor(nvg, nvgRGBA(150, 100, 255, 120))
    nvgStroke(nvg)

    -- 标题
    local titleH = baseUnit * 1.8
    nvgFontSize(nvg, fonts.description)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(150, 100, 255, 255))

    -- 将 player.modules 字典转换为列表
    local itemList = {}
    local totalCount = 0
    if player.modules then
        for moduleId, count in pairs(player.modules) do
            if count > 0 then
                local moduleDef = nil
                for _, m in ipairs(Modules.List) do
                    if m.id == moduleId then
                        moduleDef = m
                        break
                    end
                end
                table.insert(itemList, {
                    id = moduleId,
                    count = count,
                    moduleDef = moduleDef,
                })
                totalCount = totalCount + count
            end
        end
    end

    local itemCount = #itemList
    nvgText(nvg, x + baseUnit * 0.5, y + titleH / 2, string.format("模块(%d)", itemCount))

    -- 道具图标网格
    local gridY = y + titleH
    local gridH = h - titleH - baseUnit * 0.3
    local cellSize = baseUnit * 2.8
    local cols = math.floor((w - baseUnit) / (cellSize + baseUnit * 0.3))
    cols = math.max(3, math.min(cols, 6))
    local cellGap = baseUnit * 0.3
    local totalGridW = cols * cellSize + (cols - 1) * cellGap
    local gridStartX = x + (w - totalGridW) / 2

    if #itemList > 0 then
        for i, item in ipairs(itemList) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local cellX = gridStartX + col * (cellSize + cellGap)
            local cellY = gridY + row * (cellSize + cellGap) + baseUnit * 0.2

            if cellY + cellSize > y + h then break end

            local moduleDef = item.moduleDef

            -- 品质颜色
            local tier = moduleDef and moduleDef.tier or 1
            local tierColor = UIStyle.GetTierColor(tier)

            -- 模块图标
            local moduleId = item.moduleId
            local hasIcon = false
            if moduleId and moduleDef then
                if not PauseUI.moduleImages[moduleId] then
                    local iconPath = "images/modules/" .. moduleId .. ".jpg"
                    local img = nvgCreateImage(nvg, iconPath, 0)
                    if img and img > 0 then
                        PauseUI.moduleImages[moduleId] = img
                    end
                end

                if PauseUI.moduleImages[moduleId] then
                    hasIcon = true
                    local imgPaint = nvgImagePattern(nvg, cellX, cellY, cellSize, cellSize, 0, PauseUI.moduleImages[moduleId], 1.0)
                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, cellX, cellY, cellSize, cellSize, baseUnit * 0.15)
                    nvgFillPaint(nvg, imgPaint)
                    nvgFill(nvg)

                    nvgBeginPath(nvg)
                    nvgRoundedRect(nvg, cellX, cellY, cellSize, cellSize, baseUnit * 0.15)
                    nvgStrokeColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 255))
                    nvgStrokeWidth(nvg, 2.5)
                    nvgStroke(nvg)
                end
            end

            -- 如果没有图标，显示背景和模块名称缩写
            if not hasIcon then
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, cellX, cellY, cellSize, cellSize, baseUnit * 0.15)
                nvgFillColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 50))
                nvgFill(nvg)
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, cellX, cellY, cellSize, cellSize, baseUnit * 0.15)
                nvgStrokeWidth(nvg, 1)
                nvgStrokeColor(nvg, nvgRGBA(tierColor.r, tierColor.g, tierColor.b, 100))
                nvgStroke(nvg)

                local moduleAbbr = moduleDef and string.sub(moduleDef.name, 1, 6) or "??"
                nvgFontSize(nvg, cellSize * 0.35)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
                nvgText(nvg, cellX + cellSize / 2, cellY + cellSize / 2, moduleAbbr)
            end

            -- 数量标签（右下角）
            local count = item.count or 1
            if count > 1 then
                nvgFontSize(nvg, cellSize * 0.28)
                nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
                nvgText(nvg, cellX + cellSize - cellSize * 0.08, cellY + cellSize - cellSize * 0.05, "x" .. count)
            end

            -- 记录点击区域
            table.insert(PauseUI.itemRects, {
                x = cellX, y = cellY, w = cellSize, h = cellSize,
                item = item,
                moduleDef = moduleDef,
            })
        end
    end

    -- 无道具提示
    if itemCount == 0 then
        nvgFontSize(nvg, fonts.description)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(120, 130, 150, 200))
        nvgText(nvg, x + w / 2, y + h / 2 + titleH * 0.3, "暂无模块")
    end
end

return PauseUIInventory
