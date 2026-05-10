-- ============================================================================
-- 星河战姬 Starkyries - 对话数据入口
-- ============================================================================
--[[
此文件已重构为模块化结构，实际数据存储在 data/dialogue/ 目录下。

目录结构：
  data/dialogue/
  ├── index.lua              -- 统一入口（合并所有模块）
  ├── tutorial/              -- 新手引导对话
  │   └── FirstDefeat.lua    -- 首次战败
  ├── daily/                 -- 角色日常对话
  │   └── Zero_Xingyao.lua   -- 零与星遥
  ├── main/                  -- 主线剧情（待添加）
  └── event/                 -- 活动剧情（待添加）

如需查看对话系统设计规范，请参阅 data/dialogue/index.lua 顶部注释。

使用方式（保持不变）：
  local DialogueData = require "data.DialogueData"
  local dialogue = DialogueData.Get("Tutorial_FirstDefeat")
  local allIds = DialogueData.GetAllIds()
]]

-- 直接返回模块化入口，保持向后兼容
return require "data.dialogue.index"
