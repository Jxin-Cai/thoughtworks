# 前端架构设计文档模板

按以下结构输出，所有占位符 `{...}` 替换为实际内容。没有的章节整节删除，不要留空章节。

---

```markdown
# 前端架构设计

<!-- REQUIRED -->
## 结论

（一句话概括：前端要做什么，涉及哪些页面、Feature 和 API 调用）

<!-- REQUIRED -->
## 依赖契约

> 以下接口和对象定义来自 OHS 层，前端作为消费方使用。
> 来源为已有代码（标注源文件路径）。

<!-- 来源标注规则：
- 子表标题后标注：（来自已有代码），每行「说明」列末尾附注源文件路径
-->

### API 端点（来自已有代码）

| HTTP 方法 | URL | 用途 | Request DTO | Response DTO | 本层用途 |
|-----------|-----|------|-------------|--------------|---------|
| {METHOD} | /api/{resource} | {一句话描述} | {Operation}Request | {Operation}Response | {如：{FeatureName} 场景调用以获取列表数据} |

### Request DTO 定义（来自已有代码）

| DTO 类名 | 字段 | 类型 | 校验规则 | 说明 | 本层用途 |
|----------|------|------|---------|------|---------|
| {Operation}Request | {字段} | {类型} | required / maxLength(N) 等 | {说明} | {如：表单提交时构建请求体} |

### Response DTO 定义（来自已有代码）

| DTO 类名 | 字段 | 类型 | 说明 | 本层用途 |
|----------|------|------|------|---------|
| {Operation}Response | {字段} | {类型} | {说明} | {如：渲染到 {ComponentName} 组件的 {prop} 属性} |

<!-- OPTIONAL — 仅需求含 UI 风格选择时填写，否则删除本章节 -->
## UI 风格

**风格**：{minimalist-luxury / tech-futuristic / classic-elegant / 自定义描述}

**设计 Token 概要**：

| Token | 值 |
|-------|-----|
| 主色 | {色值} |
| 辅色 | {色值} |
| 背景色 | {色值} |
| 圆角 | {sm/md/lg 值} |
| 阴影 | {描述} |
| 字体 | {标题字体 / 正文字体} |

**组件风格要点**：
- 按钮：{视觉特征}
- 卡片：{视觉特征}
- 表格：{视觉特征}
- 导航：{视觉特征}

<!-- REQUIRED -->
## FSD 架构设计

### Entities

| Entity 名称 | Slice 路径 | 核心字段 | UI 组件 | API 接口 |
|-------------|-----------|---------|---------|---------|
| {EntityName} | `src/entities/{entity-name}/` | {字段列表} | {EntityCard, EntityRow 等} | {CRUD 函数名} |

### Features

| Feature 名称 | Slice 路径 | 用户场景 | UI 组件 | 依赖的 Entity |
|-------------|-----------|---------|---------|-------------|
| {FeatureName} | `src/features/{feature-name}/` | {一句话描述用户操作} | {FeatureForm, FeatureFilter 等} | {使用的 Entity 列表} |

### Widgets（可选）

| Widget 名称 | 路径 | 用途 | 组合的 Features/Entities |
|-------------|------|------|------------------------|
| {WidgetName} | `src/widgets/{widget-name}/` | {跨页面共享的 UI 区块} | {使用的 Feature/Entity 列表} |

### 层级依赖关系

```
Pages
  └── {PageName} → uses [{FeatureName}, {WidgetName}]

Widgets
  └── {WidgetName} → uses [{FeatureName}, {EntityName}]

Features
  └── {FeatureName} → uses [{EntityName}]

Entities
  └── {EntityName} → uses [shared]
```

<!-- REQUIRED -->
## 页面与路由

### {PageName}

**路由**：`/{path}`
**用途**：{一句话描述}
**组合的 Features/Widgets**：{列出本页面使用的 Feature 和 Widget}
**关联 API**：`{METHOD} /api/{resource}`

**页面布局**：
```
┌─────────────────────────────────────┐
│ {Header / 导航区域}                  │
├──────────┬──────────────────────────┤
│ {侧边栏}  │ {主内容区}                │
│          │  ┌────────────────────┐  │
│          │  │ {功能区块 1}        │  │
│          │  ├────────────────────┤  │
│          │  │ {功能区块 2}        │  │
│          │  └────────────────────┘  │
├──────────┴──────────────────────────┤
│ {Footer / 操作栏}                    │
└─────────────────────────────────────┘
```
> 使用 ASCII 线框图描述页面布局。标注每个区域对应的 Feature/Widget 组件名称。
> 如果是简单的单栏布局，可以简化线框图。

**响应式策略**：{如：移动端侧边栏折叠为底部导航 / 表格转为卡片列表 / 断点 768px}

**页面交互流程**：
- {用户操作 1} → {界面响应：如弹出表单 Modal / 展开筛选面板 / 跳转到详情页}
- {用户操作 2} → {界面响应}

<!-- REQUIRED -->
## 导出契约

> 以下列表供 Worker 实现和契约校验引用。

### Entity 列表

| Entity 名称 | Slice 路径 | 核心字段 | UI 组件 | API 接口 |
|-------------|-----------|---------|---------|---------|
| {EntityName} | `src/entities/{entity-name}/` | {字段列表} | {EntityCard, EntityRow 等} | {CRUD 函数名} |

### Feature 列表

| Feature 名称 | Slice 路径 | 用户场景 | UI 组件 | 依赖的 Entity |
|-------------|-----------|---------|---------|-------------|
| {FeatureName} | `src/features/{feature-name}/` | {一句话描述用户操作} | {FeatureForm, FeatureFilter 等} | {使用的 Entity 列表} |

### 页面-Feature 映射

| 页面名称 | 路由 | 组合的 Features/Widgets |
|---------|------|----------------------|
| {PageName} | `/{path}` | {Feature 和 Widget 列表} |

### 路由表

| 路由路径 | 页面组件 | 说明 |
|---------|---------|------|
| `/{path}` | `{PageName}` | {一句话描述} |
```
