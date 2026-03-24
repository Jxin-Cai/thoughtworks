# OHS 层 Task 设计文档模板

> 每个 task 文件对应一组 API 资源（按资源/功能分组）。
> 以下代码示例为 Java 参考格式。请根据 CONTEXT 中的 `backend_language` 使用对应语言的惯用写法和 spec 规范中的技术栈。

按以下结构输出，所有占位符 `{...}` 替换为实际内容。没有的章节整节删除，不要留空章节。

---

```markdown
---
task_id: ohs-{nnn}
layer: ohs
order: {N}
status: pending
depends_on: [{上游 task_id 列表，如 application-001}]
description: "{资源名} API"
---

# OHS: {资源名} API

<!-- REQUIRED -->
## 结论

（一句话概括：本 task 要做什么，涉及哪些 API 端点）

<!-- REQUIRED -->
## 依赖契约

> 以下接口和对象定义来自 Application 层和 Domain 层，OHS 层作为消费方使用。
> 来源为已有代码（标注源文件路径）。

### 来自 Application 层

#### ApplicationService 方法（来自已有代码）

| 类名 | 方法签名 | 返回类型 | 本层用途 |
|------|---------|---------|---------|
| {Business}ApplicationService | `{方法签名}` | {返回类型} | {如：Controller 接收请求后委托执行业务逻辑} |

#### Command 类列表（来自已有代码）

| 类名 | 说明 | 本层用途 |
|------|------|---------|
| {Operation}Command | {一句话描述} | {如：由 Request DTO 转换构建后传入 ApplicationService} |

<!-- OPTIONAL: 无 Domain 层直接依赖时可省略 -->
### 来自 Domain 层（可选）

#### 值对象/枚举列表

| 类名 | 说明 | 本层用途 |
|------|------|---------|
| {ValueObject} | {说明} | {DTO 转换时复用} |

## API 端点

### {HTTP_METHOD} /api/{resource}

**用途**：{一句话描述}
**Request**：{Operation}Request（字段由 Worker 根据 Command 推导）
**Response**：{Operation}Response（映射 {ReturnType} 的 {关键字段}）
**设计要点**：
- {映射特殊说明、分页策略、嵌套结构等关键设计决策}

<!-- 对每个 API 端点重复上述结构 -->

<!-- REQUIRED -->
## 设计约束

- {统一响应包装规范}
- {校验规范引用}
- {命名约定}
- {其他约束}

<!-- REQUIRED -->
## 实现清单

| 序号 | output_id | 类名（全路径） | 关键实现点 | 对应章节 |
|------|-----------|---------------|-----------|---------|
| 1 | Output_OHS_{IdeaName}_{nnn}_01 | `{package}.{ClassName}` | {从上方设计中提取的2-5个关键实现要点} | {对应的章节名} |
```
