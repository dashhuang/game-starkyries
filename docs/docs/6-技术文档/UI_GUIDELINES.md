# UI 编码规范

## 1. baseUnit 计算标准 (最重要!)

```lua
local baseUnit = math.min(sw, sh) / 40
```

**所有 UI 文件必须使用相同的 `/40` 除数，禁止使用 `/100` 或其他值。**

## 2. 字体大小参考

### 2.1 旧版乘数表（参考）

| 用途 | 乘数 | 示例 |
|------|------|------|
| 超大标题 | 2.0 ~ 2.5 | 波次公告、游戏结束标题 |
| 大标题 | 1.6 ~ 2.0 | 面板标题、统计数字 |
| 标题 | 1.0 ~ 1.2 | 等级变化、选项名称 |
| 正文 | 0.8 ~ 0.9 | 按钮文字、描述文字 |
| 小字 | 0.6 ~ 0.7 | 标签、提示文字 |

### 2.2 统一字体规范（推荐）

**推荐使用 `UIStyle.GetTypography(sw, sh)` 获取字体大小，自动处理横竖屏适配和最小值限制。**

```lua
local UIStyle = require "ui.UIStyle"
local fonts = UIStyle.GetTypography(sw, sh)

nvgFontSize(nvg, fonts.cardTitle)  -- 自动适配横竖屏
nvgFontSize(nvg, fonts.statLabel)  -- 自动保证最小可读性
```

### 2.3 横竖屏字体乘数

**🔴 重要：横竖屏使用相同乘数！**

原因：
- `baseUnit = math.min(sw, sh) / 40` 已经根据屏幕大小自动缩放
- 横屏 baseUnit 较大，竖屏 baseUnit 较小
- 乘数应该保持一致，通过**最小像素值**保证小屏幕可读性

| 用途 | 乘数（横竖屏相同） |
|------|-------------------|
| 页面标题 pageTitle | 3.0 |
| 页面副标题 pageSubtitle | 1.6 |
| 卡片标题 cardTitle | 1.9 |
| 卡片副标题 cardSubtitle | 1.25 |
| 属性标签 statLabel | 1.5 |
| 属性值 statValue | 1.5 |
| 描述文字 description | 1.2 |
| 按钮文字 buttonText | 1.6 |
| 标签文字 tagText | 1.2 |
| 提示文字 hintText | 1.2 |

### 2.4 最小像素值限制（绝对底线）

**🔴 无论计算结果如何，字体不得小于以下像素值：**

| 用途 | 最小像素值 |
|------|-----------|
| pageTitle | 28px |
| pageSubtitle | 16px |
| cardTitle | 18px |
| cardSubtitle | 14px |
| statLabel | 14px |
| statValue | 14px |
| description | 13px |
| buttonText | 16px |
| tagText | 12px |
| hintText | 13px |

**计算公式**：
```lua
fontSize = math.max(baseUnit * 乘数, 最小像素值)
```

### 2.5 设计原则

1. **横竖屏乘数相同** - baseUnit 已根据屏幕大小缩放
2. **最小像素值保底** - 确保小屏幕上可读
3. **使用 Typography 系统** - `UIStyle.GetTypography(sw, sh)` 自动处理

### 2.6 🔴 强制规范：禁止直接使用 baseUnit * 乘数

**所有字体大小必须通过以下方式之一设置：**

```lua
-- ✅ 方法1（推荐）：使用预定义字体
local fonts = UIStyle.GetTypography(sw, sh)
nvgFontSize(nvg, fonts.statLabel)

-- ✅ 方法2：使用安全字体函数
nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 1.5))

-- ✅ 方法3：指定自定义最小值
nvgFontSize(nvg, UIStyle.FontSize(baseUnit, 0.8, 16))

-- ❌ 禁止：直接乘法（无最小值保护）
nvgFontSize(nvg, baseUnit * 0.8)  -- 可能导致字体太小！
```

**全局最小字体像素值**：`UIStyle.MIN_FONT_SIZE = 14`

### 2.7 代码审查检查项

新增或修改 UI 代码时，必须检查：

- [ ] 所有 `nvgFontSize` 调用是否使用 `UIStyle.FontSize()` 或 `fonts.xxx`
- [ ] 是否有直接的 `baseUnit * 小数` 字体计算
- [ ] 字体在竖屏手机上是否清晰可读（最小 14px）

### 2.8 🔴 关键规则：布局间距必须基于字体大小

**当字体大小改变时，相关布局参数必须同步调整！**

#### 问题示例

```lua
-- ❌ 错误：行高使用固定 baseUnit 倍数
local statFontSize = fonts.statLabel  -- = baseUnit * 2.25 ≈ 60px
local statRowH = baseUnit * 1.8       -- = 48px  ← 行高比字体还小！
-- 结果：文字重叠！

-- ❌ 错误：间距使用固定 baseUnit
nvgText(nvg, x + baseUnit * 1.2, y, text)  -- 间距固定，字体变大后不够用
```

#### 正确做法

```lua
-- ✅ 正确：行高基于字体大小
local statFontSize = fonts.statLabel
local statRowH = statFontSize * 1.5   -- 行高 = 字体 × 1.5（舒适行距）

-- ✅ 正确：间距基于字体大小
nvgText(nvg, x + statFontSize * 1.3, y, text)  -- 间距随字体缩放
```

#### 布局间距系数参考

| 用途 | 系数 | 说明 |
|------|------|------|
| 行高 | 字体 × 1.4~1.6 | 单行文字的行高 |
| 段落间距 | 字体 × 0.8~1.0 | 段落之间的间距 |
| 图标-文字间距 | 字体 × 1.2~1.5 | 图标后的文字起始位置 |
| 内边距 | 字体 × 0.5~1.0 | 容器内边距 |

#### 检查清单

修改字体大小后，必须检查：
- [ ] 行高是否基于字体大小计算
- [ ] 元素间距是否基于字体大小计算
- [ ] 容器高度是否能容纳新的字体大小
- [ ] 滚动区域的可见行数是否正确

## 3. 按钮尺寸参考

| 类型 | 宽度 | 高度 | 字体 |
|------|------|------|------|
| 大按钮 | 8.0 | 2.0 | 0.9 |
| 中按钮 | 6.0 | 1.6 | 0.8 |
| 小按钮 | 4.0 | 1.2 | 0.7 |

## 4. 触摸处理一致性

**渲染函数和触摸处理函数必须使用完全相同的布局计算！**

```lua
-- 渲染函数
function MyUI.Render(nvg, sw, sh, ...)
    local baseUnit = math.min(sw, sh) / 40
    local btnY = panelY + panelH - baseUnit * 3.5  -- 记住这个值
end

-- 触摸处理函数 - 必须一致
function MyUI.HandleTouch(sw, sh, ...)
    local baseUnit = math.min(sw, sh) / 40
    local btnY = panelY + panelH - baseUnit * 3.5  -- 必须相同
end
```

## 5. 常见错误

```lua
-- ❌ 错误: 使用不同的除数
local baseUnit = math.min(sw, sh) / 100

-- ✅ 正确: 统一使用 /40
local baseUnit = math.min(sw, sh) / 40
```

## 6. 选中状态与视觉引导 (重要!)

### 核心原则

**区分两种高亮效果：**

| 类型 | 说明 | 何时显示 | 示例 |
|------|------|----------|------|
| **功能性高亮** | 表示当前状态/推荐选项 | 始终显示 | 当前分类标签、"开始游戏"绿色按钮 |
| **导航性选中框** | 键盘导航指示器 | 仅键盘操作时 | 选中箭头 ▶◀、选中边框 |

### 设计理由

- **鼠标/触摸用户**：不需要选中框，光标位置已足够指示
- **键盘用户**：需要明确的选中指示器来知道当前焦点位置
- **视觉引导**：如"开始游戏"绿色高亮，引导用户注意重要按钮，应始终显示

### 实现方式

```lua
-- 状态变量
MyUI.showKeyboardFocus = false  -- 默认不显示导航选中框

-- 初始化时重置
function MyUI.Init()
    MyUI.showKeyboardFocus = false
end

-- 键盘操作时显示
function MyUI.HandleInput()
    if input:GetKeyPress(KEY_UP) then
        MyUI.showKeyboardFocus = true  -- 开启键盘焦点显示
        -- ... 处理选择逻辑
    end
end

-- 鼠标/触摸操作时隐藏
function MyUI.HandleTouch(sw, sh)
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        MyUI.showKeyboardFocus = false  -- 关闭键盘焦点显示
        -- ... 处理点击逻辑
    end
end

-- 渲染时区分两种效果
function MyUI.Render(nvg, sw, sh)
    for i, btn in ipairs(buttons) do
        -- 功能性高亮：始终根据按钮类型显示
        local variant = "primary"
        if btn.id == "start" then
            variant = "success"  -- 开始按钮始终绿色
        end
        
        -- 导航性选中框：仅键盘模式显示
        local showSelectionIndicator = MyUI.showKeyboardFocus and (i == selectedIndex)
        
        DrawButton(btn, variant)  -- 颜色始终保持
        
        if showSelectionIndicator then
            DrawArrowIndicators()  -- 箭头仅键盘时显示
        end
    end
end
```

### 各 UI 模块应用

| UI 模块 | 功能性高亮 | 导航性选中框 |
|---------|------------|--------------|
| MainMenuUI | "开始游戏"绿色、"继续游戏"特殊色 | 箭头 ▶◀ |
| OptionsUI | 无 | 菜单项选中边框 |
| GalleryUI | 当前分类标签高亮 | 列表项选中边框 |

## 7. 检查清单

- [ ] baseUnit 使用 `/40` 计算
- [ ] 字体大小在推荐范围内
- [ ] 触摸处理与渲染布局一致
- [ ] 功能性高亮始终显示（推荐按钮、当前状态）
- [ ] 导航性选中框仅键盘操作时显示
- [ ] 添加 `showKeyboardFocus` 状态管理
