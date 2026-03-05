# 前端设计文档模板

按以下结构输出，所有占位符 `{...}` 替换为实际内容。没有的章节整节删除，不要留空章节。

---

```markdown
# 前端设计

<!-- REQUIRED -->
## 结论

（一句话概括：前端要做什么，涉及哪些页面和 API 调用）

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
| {METHOD} | /api/{resource} | {一句话描述} | {Operation}Request | {Operation}Response | {如：{PageName} 页面加载时调用以获取列表数据} |

### Request DTO 定义（来自 {ohs.md 导出契约 / 已有代码}）

| DTO 类名 | 字段 | 类型 | 校验规则 | 说明 | 本层用途 |
|----------|------|------|---------|------|---------|
| {Operation}Request | {字段} | {类型} | required / maxLength(N) 等 | {说明} | {如：表单提交时构建请求体} |

### Response DTO 定义（来自 {ohs.md 导出契约 / 已有代码}）

| DTO 类名 | 字段 | 类型 | 说明 | 本层用途 |
|----------|------|------|------|---------|
| {Operation}Response | {字段} | {类型} | {说明} | {如：渲染到 {ComponentName} 组件的 {prop} 属性} |

<!-- REQUIRED -->
## 页面与路由

### {PageName}

**路由**：`/{path}`
**用途**：{一句话描述}
**关联 API**：`{METHOD} /api/{resource}`

**页面结构**：
- {区域/布局描述}
- {主要交互说明}

<!-- REQUIRED -->
## 组件设计

### {ComponentName}

**类型**：容器组件 / 展示组件

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

### {apiFunction}

**端点**：`{METHOD} /api/{resource}`
**参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| {param} | {类型} | {说明} |

**返回**：`{ResponseType}`

<!-- REQUIRED -->
## 实现清单

| 序号 | output_id | 文件路径 | 类型 | 说明 |
|------|-----------|---------|------|------|
| 1 | Output_Frontend_{IdeaName}_01 | `src/pages/{PageName}.tsx` | 页面 | {说明} |
| 2 | Output_Frontend_{IdeaName}_02 | `src/components/{ComponentName}.tsx` | 组件 | {说明} |
| 3 | Output_Frontend_{IdeaName}_03 | `src/api/{resource}.ts` | API 调用 | {说明} |
```
