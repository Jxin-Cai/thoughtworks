# 前端设计文档模板

按以下结构输出，所有占位符 `{...}` 替换为实际内容。没有的章节整节删除，不要留空章节。

---

```markdown
# 前端设计

<!-- REQUIRED -->
## 结论

（一句话概括：前端要做什么，涉及哪些页面、Feature 和 API 调用）

<!-- REQUIRED -->
## 依赖契约

> 以下接口和对象定义来自 OHS 层，前端作为消费方使用。
> 来源为以下之一：① 当前 idea 的 OHS 层设计文档导出契约；② 已有代码（标注源文件路径）。

<!-- 来源标注规则：
- 来自设计文档时，子表标题后标注：（来自 ohs.md 导出契约）
- 来自已有代码时，子表标题后标注：（来自已有代码）并在每行「说明」列末尾附注源文件路径
-->

### API 端点（来自 {ohs.md 导出契约 / 已有代码}）

| HTTP 方法 | URL | 用途 | Request DTO | Response DTO | 本层用途 |
|-----------|-----|------|-------------|--------------|---------|
| {METHOD} | /api/{resource} | {一句话描述} | {Operation}Request | {Operation}Response | {如：{FeatureName} 场景调用以获取列表数据} |

### Request DTO 定义（来自 {ohs.md 导出契约 / 已有代码}）

| DTO 类名 | 字段 | 类型 | 校验规则 | 说明 | 本层用途 |
|----------|------|------|---------|------|---------|
| {Operation}Request | {字段} | {类型} | required / maxLength(N) 等 | {说明} | {如：表单提交时构建请求体} |

### Response DTO 定义（来自 {ohs.md 导出契约 / 已有代码}）

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

**页面结构**：
- {区域/布局描述}
- {主要交互说明}

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

**API 调用映射**：
- {触发时机} → `{apiFunction}()`

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
## 实现清单

| 序号 | output_id | FSD 层 | 文件路径 | 类型 | 说明 |
|------|-----------|--------|---------|------|------|
| 1 | Output_Frontend_{IdeaName}_01 | shared | `src/shared/api/client.ts` | API 客户端 | {说明} |
| 2 | Output_Frontend_{IdeaName}_02 | entity | `src/entities/{entity}/api/{entity}Api.ts` | Entity API | {说明} |
| 3 | Output_Frontend_{IdeaName}_03 | entity | `src/entities/{entity}/model/types.ts` | 类型定义 | {说明} |
| 4 | Output_Frontend_{IdeaName}_04 | entity | `src/entities/{entity}/ui/{Component}.tsx` | Entity 组件 | {说明} |
| 5 | Output_Frontend_{IdeaName}_05 | entity | `src/entities/{entity}/model/use{Entity}.ts` | Entity Hook | {说明} |
| 6 | Output_Frontend_{IdeaName}_06 | entity | `src/entities/{entity}/index.ts` | Public API | Entity slice 导出 |
| 7 | Output_Frontend_{IdeaName}_07 | feature | `src/features/{feature}/api/{api}.ts` | Feature API | {说明} |
| 8 | Output_Frontend_{IdeaName}_08 | feature | `src/features/{feature}/model/types.ts` | 类型定义 | {说明} |
| 9 | Output_Frontend_{IdeaName}_09 | feature | `src/features/{feature}/ui/{Component}.tsx` | Feature 组件 | {说明} |
| 10 | Output_Frontend_{IdeaName}_10 | feature | `src/features/{feature}/model/use{Feature}.ts` | Feature Hook | {说明} |
| 11 | Output_Frontend_{IdeaName}_11 | feature | `src/features/{feature}/index.ts` | Public API | Feature slice 导出 |
| 12 | Output_Frontend_{IdeaName}_12 | page | `src/pages/{PageName}.tsx` | 页面 | {说明} |
| 13 | Output_Frontend_{IdeaName}_13 | app | `src/app/router/index.tsx` | 路由配置 | {说明} |
| 14 | Output_Frontend_{IdeaName}_14 | config | `vite.config.ts` | 构建配置 | 配置层级路径别名（如项目已有则标注为"修改"） |
```
