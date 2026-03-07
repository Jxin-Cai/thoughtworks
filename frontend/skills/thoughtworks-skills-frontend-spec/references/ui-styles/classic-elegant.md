# 奢华经典风格指南

## 设计调性

以传统美学和精致工艺为灵感，通过衬线字体、经典边框和温暖色调传递庄重与信赖。

## 色彩系统

| 角色 | 色值 | 说明 |
|------|------|------|
| 主色 | `#5D4037` | 深棕，用于标题、按钮、强调元素 |
| 辅色 | `#8B6914` | 暗金，用于图标高亮、装饰线、badge |
| 背景色 | `#FAF8F5` | 象牙白，主体背景 |
| 卡片背景 | `#FFFFFF` | 纯白，卡片和面板 |
| 正文色 | `#3E2723` | 深棕黑，正文文字 |
| 辅助文字 | `#8D6E63` | 棕灰，次要文字、placeholder |
| 成功色 | `#2E7D32` | 橄榄绿 — 成功 |
| 警告色 | `#E65100` | 琥珀橙 — 警告 |
| 错误色 | `#C62828` | 深红 — 错误 |
| 信息色 | `#1565C0` | 经典蓝 — 提示 |

## 字体方案

| 层级 | 字体栈 | 字号 | 字重 |
|------|--------|------|------|
| H1 | `'Playfair Display', 'Noto Serif SC', serif` | 30px | 700 |
| H2 | `'Playfair Display', 'Noto Serif SC', serif` | 24px | 600 |
| H3 | `'Playfair Display', 'Noto Serif SC', serif` | 20px | 600 |
| 正文 | `'Source Sans Pro', 'Noto Sans SC', sans-serif` | 15px | 400 |
| 辅助文字 | `'Source Sans Pro', 'Noto Sans SC', sans-serif` | 13px | 400 |

## 设计 Token

| Token | 值 | 说明 |
|-------|-----|------|
| `--radius-sm` | `2px` | 小元素圆角（几乎直角） |
| `--radius-md` | `4px` | 中等元素圆角 |
| `--radius-lg` | `6px` | 大元素圆角 |
| `--shadow-sm` | `0 1px 2px rgba(93,64,55,0.08)` | 微阴影 |
| `--shadow-md` | `0 2px 8px rgba(93,64,55,0.12)` | 卡片阴影 |
| `--shadow-lg` | `0 4px 16px rgba(93,64,55,0.16)` | 浮层阴影 |
| `--border-classic` | `1px solid #D7CCC8` | 经典边框 |
| `--border-decorative` | `1px solid #8B6914` | 装饰边框（暗金） |
| `--spacing-unit` | `8px` | 间距基准单位 |
| `--content-max-width` | `1100px` | 内容区最大宽度（偏窄，增强阅读聚焦） |

## 组件风格指引

### 按钮

- 主按钮：`#5D4037` 实心填充，白色文字，hover 时亮度提升 8%，底部 2px `#8B6914` 装饰线
- 次要按钮：白色底 + `--border-classic`，hover 时边框变为主色
- 文字按钮：无背景，主色文字，hover 时添加下划线（衬线风格下划线）
- 高度统一 44px，内边距 `14px 28px`，圆角 `--radius-md`
- 字母间距 `0.5px`

### 卡片

- 白色背景 + `--border-classic` 边框 + `--shadow-sm` 微阴影
- 内边距 `28px`，圆角 `--radius-lg`
- 标题使用衬线字体，下方 `1px solid #D7CCC8` 分隔线
- 可选：顶部 3px `#8B6914` 装饰线

### 表格

- 表头背景 `#EFEBE9`，衬线字体，字重 600，字号 14px
- 行高 56px，行底部 `--border-classic` 分隔
- hover 行背景 `#FFF8E1`（淡金色）
- 表格外层 `--border-classic` 边框包围

### 表单

- 输入框高度 44px，`--border-classic` 边框，圆角 `--radius-md`，背景 `#FFFFFF`
- focus 状态：边框变为主色 `#5D4037`，外发光 `0 0 0 2px rgba(93,64,55,0.1)`
- label 在输入框上方，字号 14px，字重 500，颜色 `#5D4037`，衬线字体
- 必填标记用辅色 `#8B6914` 星号

### 导航

- 顶部导航栏高度 68px，白色背景 + 底部 `--border-classic`
- logo 区域可配合辅色装饰线
- 侧边导航宽度 250px，白色背景 + 右侧 `--border-classic`
- 选中项背景 `#EFEBE9`，左侧 3px 辅色装饰条
- 导航项高度 50px，字号 15px

### 空状态

- 居中排列：经典线条插图（使用辅色描边）+ 衬线字体说明文字 + 经典风格操作按钮
- 整体上下留白充足，传递从容感
