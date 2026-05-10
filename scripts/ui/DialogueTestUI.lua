-- ============================================================================
-- 星河战姬 Starkyries - 对话模式测试UI
-- 自动列出所有对话，点击进入测试
-- ============================================================================

local UIStyle = require("ui.UIStyle")
local DialogueUI = require("ui.DialogueUI")
local DialogueData = require("data.DialogueData")
local TouchInput = require("utils.TouchInput")

local DialogueTestUI = {}

-- ============================================================================
-- 状态
-- ============================================================================
DialogueTestUI.visible = false
DialogueTestUI.animTime = 0
DialogueTestUI.onClose = nil
DialogueTestUI.showingDialogue = false
DialogueTestUI.selectedIndex = 1
DialogueTestUI.scrollOffset = 0
DialogueTestUI.dialogueList = {}  -- 对话列表缓存
DialogueTestUI.scene = nil        -- 游戏场景（用于语音播放）

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function DialogueTestUI.Show(onClose, scene)
    DialogueTestUI.visible = true
    DialogueTestUI.animTime = 0
    DialogueTestUI.onClose = onClose
    DialogueTestUI.showingDialogue = false
    DialogueTestUI.selectedIndex = 1
    DialogueTestUI.scrollOffset = 0
    DialogueTestUI.scene = scene  -- 保存场景引用
    
    -- 加载所有对话ID
    DialogueTestUI.RefreshDialogueList()
end

function DialogueTestUI.Hide()
    DialogueTestUI.visible = false
    DialogueTestUI.showingDialogue = false
    DialogueUI.Stop()
    if DialogueTestUI.onClose then
        DialogueTestUI.onClose()
    end
end

function DialogueTestUI.IsVisible()
    return DialogueTestUI.visible
end

-- ============================================================================
-- 对话列表管理
-- ============================================================================

function DialogueTestUI.RefreshDialogueList()
    DialogueTestUI.dialogueList = {}
    local ids = DialogueData.GetAllIds()
    
    for _, id in ipairs(ids) do
        local dialogue = DialogueData.Get(id)
        if dialogue then
            -- 获取对话信息
            local firstLine = dialogue[1]
            local speaker = firstLine and firstLine.speaker or "未知"
            local lineCount = #dialogue
            local summary = dialogue.summary or "无简介"
            
            table.insert(DialogueTestUI.dialogueList, {
                id = id,
                speaker = speaker,
                lineCount = lineCount,
                summary = summary,
            })
        end
    end
    
    print("[DialogueTestUI] 加载了 " .. #DialogueTestUI.dialogueList .. " 个对话")
end

-- ============================================================================
-- 对话控制
-- ============================================================================

function DialogueTestUI.StartDialogue(dialogueId)
    local dialogue = DialogueData.Get(dialogueId)
    if not dialogue then
        print("[DialogueTestUI] 未找到对话: " .. dialogueId)
        return
    end
    
    DialogueTestUI.showingDialogue = true
    
    -- 传递 dialogueId 和 scene 以启用语音播放
    DialogueUI.Play(dialogue, function()
        -- 对话结束，返回列表
        DialogueTestUI.showingDialogue = false
    end, { dialogueId = dialogueId, scene = DialogueTestUI.scene })
end

-- ============================================================================
-- 更新
-- ============================================================================

function DialogueTestUI.Update(dt)
    if not DialogueTestUI.visible then return end
    
    DialogueTestUI.animTime = DialogueTestUI.animTime + dt
    
    if DialogueTestUI.showingDialogue then
        DialogueUI.Update(dt)
    end
end

-- ============================================================================
-- 输入处理
-- ============================================================================

function DialogueTestUI.HandleInput()
    if not DialogueTestUI.visible then return false end
    
    -- 如果正在显示对话，交给DialogueUI处理
    if DialogueTestUI.showingDialogue then
        return DialogueUI.HandleInput()
    end
    
    local listCount = #DialogueTestUI.dialogueList
    if listCount == 0 then
        if input:GetKeyPress(KEY_ESCAPE) then
            DialogueTestUI.Hide()
            return true
        end
        return false
    end
    
    -- 上下选择
    if input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) then
        DialogueTestUI.selectedIndex = DialogueTestUI.selectedIndex - 1
        if DialogueTestUI.selectedIndex < 1 then
            DialogueTestUI.selectedIndex = listCount
        end
        return true
    end
    
    if input:GetKeyPress(KEY_DOWN) or input:GetKeyPress(KEY_S) then
        DialogueTestUI.selectedIndex = DialogueTestUI.selectedIndex + 1
        if DialogueTestUI.selectedIndex > listCount then
            DialogueTestUI.selectedIndex = 1
        end
        return true
    end
    
    -- 确认选择
    if input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_SPACE) then
        local item = DialogueTestUI.dialogueList[DialogueTestUI.selectedIndex]
        if item then
            DialogueTestUI.StartDialogue(item.id)
        end
        return true
    end
    
    -- ESC：返回
    if input:GetKeyPress(KEY_ESCAPE) then
        DialogueTestUI.Hide()
        return true
    end
    
    return false
end

function DialogueTestUI.HandleTouch(sw, sh)
    if not DialogueTestUI.visible then return false end
    
    -- 如果正在显示对话，交给DialogueUI处理
    if DialogueTestUI.showingDialogue then
        return DialogueUI.HandleTouch(sw, sh)
    end
    
    local mx = TouchInput.x
    local my = TouchInput.y
    
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        local baseUnit = math.min(sw, sh) / 40
        
        -- 列表区域
        local listX = baseUnit * 2
        local listY = baseUnit * 5
        local listW = sw - baseUnit * 4
        local itemH = baseUnit * 4
        local itemSpacing = baseUnit * 0.5
        local maxVisible = math.floor((sh - baseUnit * 8) / (itemH + itemSpacing))
        
        -- 检查列表项点击
        for i = 1, math.min(maxVisible, #DialogueTestUI.dialogueList) do
            local actualIndex = i + DialogueTestUI.scrollOffset
            if actualIndex <= #DialogueTestUI.dialogueList then
                local itemY = listY + (i - 1) * (itemH + itemSpacing)
                
                if mx >= listX and mx <= listX + listW and
                   my >= itemY and my <= itemY + itemH then
                    DialogueTestUI.selectedIndex = actualIndex
                    local item = DialogueTestUI.dialogueList[actualIndex]
                    if item then
                        DialogueTestUI.StartDialogue(item.id)
                    end
                    return true
                end
            end
        end
        
        -- 返回按钮
        local backX = sw - baseUnit * 4
        local backY = baseUnit * 0.5
        if mx >= backX and mx <= backX + baseUnit * 3 and
           my >= backY and my <= backY + baseUnit * 2 then
            DialogueTestUI.Hide()
            return true
        end
    end
    
    -- 滚轮滚动
    local wheel = input.mouseMove and input.mouseMove.z or 0
    if wheel ~= 0 then
        local maxVisible = math.floor((sh - math.min(sw, sh) / 40 * 8) / (math.min(sw, sh) / 40 * 4.5))
        local maxScroll = math.max(0, #DialogueTestUI.dialogueList - maxVisible)
        
        DialogueTestUI.scrollOffset = DialogueTestUI.scrollOffset - wheel
        DialogueTestUI.scrollOffset = math.max(0, math.min(maxScroll, DialogueTestUI.scrollOffset))
        return true
    end
    
    return false
end

-- ============================================================================
-- 渲染
-- ============================================================================

function DialogueTestUI.Render(nvg, sw, sh)
    if not DialogueTestUI.visible then return end
    
    local baseUnit = math.min(sw, sh) / 40
    local fonts = UIStyle.GetTypography(sw, sh)
    
    -- 如果正在显示对话，只渲染DialogueUI
    if DialogueTestUI.showingDialogue then
        DialogueUI.Render(nvg, sw, sh)
        return
    end
    
    -- 背景
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, sw, sh)
    nvgFillColor(nvg, nvgRGBA(10, 15, 25, 255))
    nvgFill(nvg)
    
    -- 标题
    nvgFontSize(nvg, fonts.pageTitle)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 200, 100, 255))
    nvgText(nvg, sw / 2, baseUnit * 1.5, "剧情测试")
    
    -- 对话数量
    nvgFontSize(nvg, fonts.bodyText)
    nvgFillColor(nvg, nvgRGBA(150, 150, 170, 200))
    nvgText(nvg, sw / 2, baseUnit * 3.5, "共 " .. #DialogueTestUI.dialogueList .. " 个对话")
    
    -- 返回按钮
    nvgFontSize(nvg, fonts.cardTitle)
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 100, 100, 200))
    nvgText(nvg, sw - baseUnit * 1.5, baseUnit * 1, "返回")
    
    -- 对话列表
    local listX = baseUnit * 2
    local listY = baseUnit * 5
    local listW = sw - baseUnit * 4
    local itemH = baseUnit * 4
    local itemSpacing = baseUnit * 0.5
    local maxVisible = math.floor((sh - baseUnit * 8) / (itemH + itemSpacing))
    
    if #DialogueTestUI.dialogueList == 0 then
        -- 无对话提示
        nvgFontSize(nvg, fonts.cardTitle)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(150, 150, 150, 150))
        nvgText(nvg, sw / 2, sh / 2, "暂无对话数据")
    else
        -- 渲染列表项
        for i = 1, math.min(maxVisible, #DialogueTestUI.dialogueList) do
            local actualIndex = i + DialogueTestUI.scrollOffset
            if actualIndex <= #DialogueTestUI.dialogueList then
                local item = DialogueTestUI.dialogueList[actualIndex]
                local itemY = listY + (i - 1) * (itemH + itemSpacing)
                local isSelected = (actualIndex == DialogueTestUI.selectedIndex)
                
                -- 项背景
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, listX, itemY, listW, itemH, baseUnit * 0.3)
                
                if isSelected then
                    local pulse = 0.7 + 0.3 * math.sin(DialogueTestUI.animTime * 3)
                    nvgFillColor(nvg, nvgRGBA(60, 100, 180, math.floor(120 * pulse)))
                    nvgFill(nvg)
                    nvgStrokeColor(nvg, nvgRGBA(100, 180, 255, 255))
                    nvgStrokeWidth(nvg, 2)
                    nvgStroke(nvg)
                else
                    nvgFillColor(nvg, nvgRGBA(30, 40, 60, 200))
                    nvgFill(nvg)
                    nvgStrokeColor(nvg, nvgRGBA(60, 80, 120, 100))
                    nvgStrokeWidth(nvg, 1)
                    nvgStroke(nvg)
                end
                
                -- 对话ID
                nvgFontSize(nvg, fonts.cardTitle)
                nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(nvg, isSelected and nvgRGBA(255, 255, 255, 255) or nvgRGBA(220, 220, 230, 255))
                nvgText(nvg, listX + baseUnit * 0.8, itemY + baseUnit * 0.5, item.id)
                
                -- 说话人和行数
                nvgFontSize(nvg, fonts.description)
                nvgFillColor(nvg, nvgRGBA(150, 180, 220, 200))
                local info = "首位说话人: " .. item.speaker .. " | " .. item.lineCount .. " 条对话"
                nvgText(nvg, listX + baseUnit * 0.8, itemY + baseUnit * 2, info)
                
                -- 简介（截断显示）
                nvgFillColor(nvg, nvgRGBA(120, 130, 150, 180))
                local summaryText = item.summary
                if #summaryText > 40 then
                    summaryText = string.sub(summaryText, 1, 40) .. "..."
                end
                nvgText(nvg, listX + baseUnit * 0.8, itemY + baseUnit * 3, summaryText)
            end
        end
        
        -- 滚动指示器（如果需要）
        if #DialogueTestUI.dialogueList > maxVisible then
            local scrollBarH = sh - baseUnit * 10
            local scrollThumbH = scrollBarH * (maxVisible / #DialogueTestUI.dialogueList)
            local scrollThumbY = listY + (DialogueTestUI.scrollOffset / (#DialogueTestUI.dialogueList - maxVisible)) * (scrollBarH - scrollThumbH)
            
            -- 滚动条背景
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, sw - baseUnit * 1.2, listY, baseUnit * 0.4, scrollBarH, baseUnit * 0.2)
            nvgFillColor(nvg, nvgRGBA(50, 60, 80, 100))
            nvgFill(nvg)
            
            -- 滚动条滑块
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, sw - baseUnit * 1.2, scrollThumbY, baseUnit * 0.4, scrollThumbH, baseUnit * 0.2)
            nvgFillColor(nvg, nvgRGBA(100, 150, 220, 200))
            nvgFill(nvg)
        end
    end
    
    -- 底部操作提示
    nvgFontSize(nvg, fonts.description)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(nvg, nvgRGBA(100, 120, 150, 150))
    nvgText(nvg, sw / 2, sh - baseUnit * 0.5, "↑↓ 选择 | Enter 确认 | ESC 返回")
end

return DialogueTestUI
