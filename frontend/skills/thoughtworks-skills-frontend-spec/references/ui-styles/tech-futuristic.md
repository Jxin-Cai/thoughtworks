# 科技未来风格指南

## 设计调性

以深色主题为基底，通过霓虹光效和透明质感营造科技前沿氛围。

## 色彩系统

| 角色 | 色值 | 说明 |
|------|------|------|
| 主色 | `#7C3AED` | 电光紫，用于主按钮、强调元素 |
| 辅色 | `#06B6D4` | 赛博蓝，用于链接、图标高亮、进度条 |
| 背景色 | `#0F172A` | 深蓝黑，主体背景 |
| 卡片背景 | `rgba(30, 41, 59, 0.8)` | 半透明深蓝灰，玻璃态卡片 |
| 正文色 | `#E2E8F0` | 浅灰白，正文文字 |
| 辅助文字 | `#94A3B8` | 中灰蓝，次要文字、placeholder |
| 成功色 | `#10B981` | 翡翠绿 — 成功 |
| 警告色 | `#F59E0B` | 琥珀黄 — 警告 |
| 错误色 | `#EF4444` | 霓虹红 — 错误 |
| 信息色 | `#3B82F6` | 亮蓝 — 提示 |

## 字体方案

| 层级 | 字体栈 | 字号 | 字重 |
|------|--------|------|------|
| H1 | `'JetBrains Mono', 'Inter', 'Noto Sans SC', monospace` | 28px | 700 |
| H2 | `'Inter', 'Noto Sans SC', sans-serif` | 22px | 600 |
| H3 | `'Inter', 'Noto Sans SC', sans-serif` | 18px | 600 |
| 正文 | `'Inter', 'Noto Sans SC', sans-serif` | 14px | 400 |
| 辅助文字 | `'Inter', 'Noto Sans SC', sans-serif` | 12px | 400 |

## 设计 Token

| Token | 值 | 说明 |
|-------|-----|------|
| `--radius-sm` | `6px` | 小元素圆角 |
| `--radius-md` | `10px` | 中等元素圆角 |
| `--radius-lg` | `16px` | 大元素圆角 |
| `--shadow-glow-primary` | `0 0 12px rgba(124,58,237,0.3)` | 主色微发光 |
| `--shadow-glow-secondary` | `0 0 12px rgba(6,182,212,0.3)` | 辅色微发光 |
| `--shadow-md` | `0 4px 16px rgba(0,0,0,0.4)` | 卡片阴影 |
| `--shadow-lg` | `0 8px 32px rgba(0,0,0,0.5)` | 浮层阴影 |
| `--glass-bg` | `rgba(30, 41, 59, 0.6)` | 玻璃态背景 |
| `--glass-border` | `1px solid rgba(148,163,184,0.15)` | 玻璃态边框 |
| `--glass-blur` | `backdrop-filter: blur(12px)` | 玻璃态模糊 |
| `--spacing-unit` | `8px` | 间距基准单位 |
| `--content-max-width` | `1400px` | 内容区最大宽度 |

## 组件风格指引

### 按钮

- 主按钮：渐变填充 `linear-gradient(135deg, #7C3AED, #06B6D4)`，白色文字，hover 时增加 `--shadow-glow-primary`
- 次要按钮：透明底 + `rgba(124,58,237,0.5)` 边框 1px，hover 时边框变实色
- 文字按钮：无背景，辅色文字，hover 时增加微发光
- 高度统一 42px，内边距 `16px 28px`，圆角 `--radius-md`

### 卡片

- 玻璃态：`--glass-bg` 背景 + `--glass-border` 边框 + `--glass-blur` 模糊
- 内边距 `24px`，圆角 `--radius-lg`
- hover 时边框亮度提升，增加微弱的 `--shadow-glow-secondary`

### 表格

- 表头背景 `rgba(30, 41, 59, 0.9)`，字重 600，字号 13px，辅色文字
- 行高 52px，行底部 `1px solid rgba(148,163,184,0.1)` 分隔
- hover 行背景 `rgba(124,58,237,0.08)`
- 选中行左侧 2px 主色发光条

### 表单

- 输入框高度 42px，背景 `rgba(15,23,42,0.6)`，边框 `--glass-border`，圆角 `--radius-md`
- focus 状态：边框变为主色，外发光 `--shadow-glow-primary`
- label 在输入框上方，字号 13px，字重 500，辅色文字
- 必填标记用主色星号

### 导航

- 侧边栏：玻璃态背景，宽度 260px，左侧固定
- 选中项背景 `rgba(124,58,237,0.15)`，左侧 3px 主色发光条
- 导航项高度 48px，图标使用辅色
- 顶部 logo 区域带微弱发光效果

### 空状态

- 居中排列：渐变描边的几何图形 + 辅色说明文字 + 带发光效果的操作按钮
- 图形使用主色到辅色的渐变描边，线条风格
