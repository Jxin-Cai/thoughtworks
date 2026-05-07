# 前端组件设计文档模板

按以下结构输出，所有占位符 `{...}` 替换为实际内容。没有的章节整节删除，不要留空章节。

---

```markdown
---
task_id: comp-{nnn}
layer: frontend-components
order: {N}
status: pending
depends_on: [{上游 task_id 列表}]
description: "{一句话描述}"
---
# 前端组件设计

<!-- REQUIRED -->
## 结论

（一句话概括：本文件设计了哪些组件和 API 调用函数）

<!-- REQUIRED -->
## 依赖契约

> 以下列表来自 `frontend-architecture.md` 导出契约，作为本文件的设计输入。

### Entity 列表（来自 frontend-architecture.md 导出契约）

| Entity 名称 | Slice 路径 | 核心字段 | UI 组件 | API 接口 |
|-------------|-----------|---------|---------|---------|
| {EntityName} | `src/entities/{entity-name}/` | {字段列表} | {EntityCard, EntityRow 等} | {CRUD 函数名} |

### Feature 列表（来自 frontend-architecture.md 导出契约）

| Feature 名称 | Slice 路径 | 用户场景 | UI 组件 | 依赖的 Entity |
|-------------|-----------|---------|---------|-------------|
| {FeatureName} | `src/features/{feature-name}/` | {一句话描述用户操作} | {FeatureForm, FeatureFilter 等} | {使用的 Entity 列表} |

<!-- REQUIRED -->
## 组件设计

### Entity 组件

#### {EntityName} — {ComponentName}

**所属 Slice**：`src/entities/{entity-name}/ui/`
**类型**：展示组件

**Props**：

| 属性 | 类型 | 必填 | 说明 |
|------|------|------|------|
| {prop} | {类型} | 是/否 | {说明} |

**状态**：

| 状态 | 类型 | 初始值 | 说明 |
|------|------|--------|------|
| {state} | {类型} | {初始值} | {说明} |

**视觉规格**：
- 布局：{如：水平排列，左侧头像 40px + 右侧信息区 flex-1}
- 尺寸：{如：卡片高度 auto，最小高度 80px，宽度 100%}
- 间距：{如：内边距 16px，元素间距 12px}
- 边框/圆角：{如：1px solid border-color，圆角 8px}
- 背景：{如：白色卡片背景，hover 时 bg-gray-50}

**交互行为**：
- hover：{如：边框变为主色、显示阴影 / 无}
- 点击：{如：跳转到详情页 / 展开详情面板 / 无}
- 加载态：{如：骨架屏 / shimmer 动画 / 无}
- 空状态：{如：显示占位图 + 提示文案 / 不适用}

### Feature 组件

#### {FeatureName} — {ComponentName}

**所属 Slice**：`src/features/{feature-name}/ui/`
**类型**：功能组件

**Props**：

| 属性 | 类型 | 必填 | 说明 |
|------|------|------|------|
| {prop} | {类型} | 是/否 | {说明} |

**状态**：

| 状态 | 类型 | 初始值 | 说明 |
|------|------|--------|------|
| {state} | {类型} | {初始值} | {说明} |

**视觉规格**：
- 布局：{如：垂直表单布局，label 在上 input 在下 / 网格布局 3 列}
- 尺寸：{如：表单宽度 480px 居中 / 筛选栏高度 56px 全宽}
- 间距：{如：表单项间距 24px，按钮组间距 12px}
- 视觉重点：{如：提交按钮为 Primary 样式，取消按钮为 Ghost 样式}

**交互行为**：
- 提交/操作：{如：点击提交 → 按钮显示 loading spinner → 成功后 Toast 提示 + 关闭 Modal / 跳转}
- 校验反馈：{如：失败字段下方显示红色错误文案，输入框边框变红}
- 加载态：{如：首次加载显示骨架屏 / 操作中按钮 disabled + spinner}
- 空状态：{如：列表为空时显示空态插图 + 「暂无数据」 + 操作引导按钮}
- 错误态：{如：API 失败时显示 inline 错误提示 + 重试按钮}

**API 调用映射**：
- {触发时机} → `{apiFunction}()` → 成功：{界面变化} / 失败：{错误处理}

<!-- REQUIRED -->
## API 调用层

### Entity API — {EntityName}

#### {apiFunction}

**所属 Slice**：`src/entities/{entity-name}/api/`
**端点**：`{METHOD} /api/{resource}`
**参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| {param} | {类型} | {说明} |

**返回**：`{ResponseType}`

### Feature API — {FeatureName}

#### {apiFunction}

**所属 Slice**：`src/features/{feature-name}/api/`
**端点**：`{METHOD} /api/{resource}`
**参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| {param} | {类型} | {说明} |

**返回**：`{ResponseType}`

<!-- REQUIRED -->
## 导出契约

> 以下列表供 Worker 实现和契约校验引用。

### 组件清单

| 组件名称 | 所属 Slice | 类型 | 文件路径 |
|---------|-----------|------|---------|
| {ComponentName} | `src/entities/{entity-name}/ui/` | Entity 组件 | `{ComponentName}.tsx` |
| {ComponentName} | `src/features/{feature-name}/ui/` | Feature 组件 | `{ComponentName}.tsx` |

### API 函数清单

| 函数名称 | 所属 Slice | 端点 | 文件路径 |
|---------|-----------|------|---------|
| {apiFunction} | `src/entities/{entity-name}/api/` | `{METHOD} /api/{resource}` | `{entity}Api.ts` |
| {apiFunction} | `src/features/{feature-name}/api/` | `{METHOD} /api/{resource}` | `{feature}Api.ts` |
```
