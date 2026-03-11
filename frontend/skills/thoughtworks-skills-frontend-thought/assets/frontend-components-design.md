# 前端组件设计文档模板

按以下结构输出，所有占位符 `{...}` 替换为实际内容。没有的章节整节删除，不要留空章节。

---

```markdown
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
## 导出契约

> 以下列表供下游 `frontend-checklist.md` 作为依赖契约引用。

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
