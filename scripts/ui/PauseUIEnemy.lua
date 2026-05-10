-- ============================================================================
-- PauseUIEnemy - 暂停菜单敌人面板与按钮渲染
-- 从 PauseUI.lua 拆分，负责右侧面板（敌人+按钮）
-- ============================================================================

local UIScreen = require("ui.UIScreen")
local UISafeArea = require("ui.UISafeArea")
local Waves = require("config.waves")
local EnemiesConfig = require("config.enemies")
local TouchInput = require("utils.TouchInput")

local PauseUIEnemy = {}

-- ============================================================================
-- 右侧面板：敌人+按钮
-- ============================================================================

function PauseUIEnemy.RenderRightPanel(nvg, x, y, w, h, baseUnit, fonts, enemies, battle, PauseUI)
    -- 敌人信息
    local enemyH = h * 0.35
    PauseUIEnemy.RenderEnemyPanel(nvg, x, y, w, enemyH, baseUnit, fonts, enemies, battle)

    -- 按钮列表
    local btnY = y + enemyH + baseUnit * 0.4
    local btnH = h - enemyH - baseUnit * 0.4
    PauseUIEnemy.RenderButtons(nvg, x, btnY, w, btnH, baseUnit, fonts, PauseUI)
end

-- ============================================================================
-- 敌人面板（显示本波配置的敌人类型）
-- ============================================================================

function PauseUIEnemy.RenderEnemyPanel(nvg, x, y, w, h, baseUnit, fonts, enemies, battle)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.4)
    nvgFillColor(nvg, nvgRGBA(20, 25, 35, 245))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, w, h, baseUnit * 0.4)
    nvgStrokeWidth(nvg, 2)
    nvgStrokeColor(nvg, nvgRGBA(255, 100, 100, 120))
    nvgStroke(nvg)

    -- 标题
    local titleH = baseUnit * 1.8
    nvgFontSize(nvg, fonts.description)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 100, 100, 255))
    nvgText(nvg, x + baseUnit * 0.5, y + titleH / 2, "本波敌人")

    -- 获取本波敌人类型（去重）
    local waveNum = battle and battle.currentWave or 1
    local enemyPool = Waves.GetEnemyPool(waveNum)
    local uniqueTypes = {}
    local seenTypes = {}

    for _, enemyId in ipairs(enemyPool) do
        if not seenTypes[enemyId] then
            seenTypes[enemyId] = true
            table.insert(uniqueTypes, enemyId)
        end
    end

    -- 敌人图标网格
    local gridY = y + titleH + baseUnit * 0.3
    local gridH = h - titleH - baseUnit * 0.5
    local cellSize = baseUnit * 2.2
    local cellGap = baseUnit * 0.25
    local cols = math.floor((w - baseUnit * 0.6) / (cellSize + cellGap))
    cols = math.max(2, math.min(cols, 4))
    local totalGridW = cols * cellSize + (cols - 1) * cellGap
    local gridStartX = x + (w - totalGridW) / 2

    for i, enemyId in ipairs(uniqueTypes) do
        local enemyDef = EnemiesConfig.List[enemyId]
        if enemyDef then
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local cellX = gridStartX + col * (cellSize + cellGap)
            local cellY = gridY + row * (cellSize + cellGap)

            if cellY + cellSize > y + h then break end

            -- 敌人格子背景
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, cellX, cellY, cellSize, cellSize, baseUnit * 0.2)

            -- 根据阵营设置背景色
            local bgColor = nvgRGBA(50, 40, 40, 200)
            if enemyDef.faction == "Bug" then
                bgColor = nvgRGBA(40, 55, 35, 200)
            elseif enemyDef.faction == "Mech" then
                bgColor = nvgRGBA(40, 45, 55, 200)
            elseif enemyDef.faction == "Pirate" then
                bgColor = nvgRGBA(55, 45, 35, 200)
            end
            nvgFillColor(nvg, bgColor)
            nvgFill(nvg)

            -- 敌人图标
            if enemyDef.icon then
                nvgFontSize(nvg, cellSize * 0.55)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
                nvgText(nvg, cellX + cellSize / 2, cellY + cellSize * 0.45, enemyDef.icon)
            end

            -- 敌人名称（缩写）
            nvgFontSize(nvg, fonts.hintText * 0.85)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(nvg, nvgRGBA(180, 180, 180, 255))
            local shortName = string.sub(enemyDef.name, 1, 6)
            nvgText(nvg, cellX + cellSize / 2, cellY + cellSize - baseUnit * 0.1, shortName)
        end
    end

    -- 无敌人提示
    if #uniqueTypes == 0 then
        nvgFontSize(nvg, fonts.description)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(120, 130, 150, 200))
        nvgText(nvg, x + w / 2, y + h / 2, "无敌人")
    end
end

-- ============================================================================
-- 按钮列表
-- ============================================================================

function PauseUIEnemy.RenderButtons(nvg, x, y, w, h, baseUnit, fonts, PauseUI)
    local btnH = baseUnit * 2.0
    local btnGap = baseUnit * 0.35
    local btnCount = #PauseUI.buttons
    local totalBtnH = btnCount * btnH + (btnCount - 1) * btnGap
    local startY = y + (h - totalBtnH) / 2

    -- 获取鼠标位置用于按下状态检测
    local safe = PauseUI.safeArea
    local mx, my = nil, nil
    if safe then
        local screenX = TouchInput.x
        local screenY = TouchInput.y
        if UISafeArea.Contains(safe, screenX, screenY) then
            mx, my = UISafeArea.ToLocal(safe, screenX, screenY)
        end
    end

    for i, btn in ipairs(PauseUI.buttons) do
        local btnY = startY + (i - 1) * (btnH + btnGap)
        local buttonId = "pause_" .. btn.id
        local isPressed = mx and my and UIScreen.ShouldShowPressed(mx, my, buttonId)

        -- 按下时的偏移
        local offsetY = isPressed and 2 or 0
        local actualY = btnY + offsetY

        -- 按钮背景颜色（按下时变暗）
        local bgColor, borderColor
        if btn.variant == "primary" then
            if isPressed then
                bgColor = nvgRGBA(40, 70, 130, 250)
                borderColor = nvgRGBA(120, 170, 255, 255)
            else
                bgColor = nvgRGBA(60, 100, 180, 240)
                borderColor = nvgRGBA(100, 150, 255, 200)
            end
        elseif btn.variant == "danger" then
            if isPressed then
                bgColor = nvgRGBA(110, 35, 35, 250)
                borderColor = nvgRGBA(255, 120, 120, 255)
            else
                bgColor = nvgRGBA(150, 50, 50, 240)
                borderColor = nvgRGBA(255, 100, 100, 200)
            end
        else
            if isPressed then
                bgColor = nvgRGBA(35, 42, 56, 250)
                borderColor = nvgRGBA(100, 120, 160, 255)
            else
                bgColor = nvgRGBA(50, 60, 80, 240)
                borderColor = nvgRGBA(80, 100, 140, 200)
            end
        end

        -- 背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, actualY, w, btnH, baseUnit * 0.25)
        nvgFillColor(nvg, bgColor)
        nvgFill(nvg)

        -- 边框
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x, actualY, w, btnH, baseUnit * 0.25)
        nvgStrokeWidth(nvg, isPressed and 2 or 1.5)
        nvgStrokeColor(nvg, borderColor)
        nvgStroke(nvg)

        -- 文字
        nvgFontSize(nvg, fonts.buttonText)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        nvgText(nvg, x + w / 2, actualY + btnH / 2, btn.text)

        -- 记录点击区域（使用原始位置）
        table.insert(PauseUI.buttonRects, {x = x, y = btnY, w = w, h = btnH, id = btn.id})
    end
end

return PauseUIEnemy
