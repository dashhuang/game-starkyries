-- ============================================================================
-- 星河战姬 Starkyries - 对话数据统一入口
-- 合并所有对话模块，提供统一访问接口
-- ============================================================================
--[[
================================================================================
                            对话系统设计规范
================================================================================

【核心规则 #1】指挥官不说话
--------------------------------------------------------------------------------
玩家扮演的"指挥官"是沉默型主角，在对话中不发言。
- 错误: { speaker = "指挥官", text = "我明白了" }
- 正确: 角色对指挥官说话，指挥官通过选项或沉默回应
- 正确: { speaker = "星遥", text = "指挥官，你觉得呢？......嗯，我懂了！" }


【核心规则 #2】图片场景一致性
--------------------------------------------------------------------------------
所有角色图片都自带背景场景，同一段对话中不能随意切换场景图片。
- 每段对话开始时确定场景（如"战败后的舰桥"）
- 该场景内的所有图片使用相同背景
- 切换场景 = 切换对话段落


【核心规则 #3】图片命名规范
--------------------------------------------------------------------------------
路径格式: image/[角色名]/[场景_情绪].jpg

示例：
  image/星遥/战败_沮丧.jpg    -- 战败场景 + 沮丧情绪
  image/星遥/战败_开心.jpg    -- 战败场景 + 开心情绪
  image/零/冷静.jpg           -- 默认舰桥 + 冷静情绪


【核心规则 #4】图片占位符系统
--------------------------------------------------------------------------------
使用 imageDesc 字段描述所需图片内容，便于美术制作：
{
    speaker = "星遥",
    text = "对话内容",
    image = "image/星遥/战败_沮丧.jpg",
    imageDesc = "星遥半身像，表情沮丧低落，先锋号舰桥背景",
}


================================================================================
                            对话数据字段说明
================================================================================

【对话序列字段】
- summary   (string, 可选)  剧情简介，玩家跳过对话时显示

【对话条目字段】
- speaker   (string, 必填)  说话者名称
- text      (string, 必填)  对话文本
- image     (string, 可选)  角色图片路径
- imageDesc (string, 可选)  图片描述，用于占位符显示
- cropTop   (number, 可选)  图片顶部裁剪比例，默认0.15
- effect    (string, 可选)  触发效果，支持: "shake"


================================================================================
                            目录结构
================================================================================

data/dialogue/
├── index.lua          # 本文件 - 统一入口
├── tutorial/          # 新手引导
│   ├── Opening.lua    # 游戏开场
│   └── FirstDefeat.lua
├── main/              # 主线剧情
│   └── (待添加)
├── daily/             # 日常对话
│   └── Zero_Xingyao.lua
└── event/             # 活动剧情
    └── (待添加)

]]

local DialogueData = {}

-- ============================================================================
-- 加载所有对话模块
-- ============================================================================

local modules = {
    -- 新手引导
    require("data.dialogue.tutorial.Opening"),
    require("data.dialogue.tutorial.FirstDefeat"),
    
    -- 日常对话
    require("data.dialogue.daily.BridgeChat"),
    
    -- 主线剧情（待添加）
    -- require("data.dialogue.main.Chapter1"),
    
    -- 活动剧情
    require("data.dialogue.event.Eclipse_BossBattle"),
    require("data.dialogue.event.CoreCrew_Greeting"),
}

-- 合并所有模块到 DialogueData
for _, mod in ipairs(modules) do
    for key, value in pairs(mod) do
        if DialogueData[key] then
            print("[DialogueData] 警告：对话ID重复: " .. key)
        end
        DialogueData[key] = value
    end
end

-- ============================================================================
-- 工具函数
-- ============================================================================

---获取对话数据
---@param dialogueId string 对话ID
---@return table|nil
function DialogueData.Get(dialogueId)
    return DialogueData[dialogueId]
end

---获取所有对话ID列表
---@return table
function DialogueData.GetAllIds()
    local ids = {}
    for k, v in pairs(DialogueData) do
        if type(v) == "table" and type(k) == "string" 
           and k ~= "Get" and k ~= "GetAllIds" then
            table.insert(ids, k)
        end
    end
    table.sort(ids)
    return ids
end

return DialogueData
