# OHS 层设计文档模板

按以下结构输出，所有占位符 `{...}` 替换为实际内容。没有的章节整节删除，不要留空章节。

---

```markdown
# OHS 层设计

<!-- REQUIRED -->
## 结论

（一句话概括：这一层要做什么，涉及哪些 API 端点）

<!-- REQUIRED -->
## 依赖契约

> 以下接口和对象定义来自 Application 层和 Domain 层，OHS 层作为消费方使用。
> 来源为以下之一：① 当前 idea 的设计文档导出契约；② 已有代码（标注源文件路径）。

<!-- 来源标注规则：
- 来自设计文档时，子表标题后标注：（来自 application.md 导出契约）
- 来自已有代码时，子表标题后标注：（来自已有代码）并在每行「说明」列末尾附注源文件路径
-->

### 来自 Application 层

#### ApplicationService 方法（来自 {application.md 导出契约 / 已有代码}）

| 类名 | 方法签名 | 返回类型 | 用例说明 | 本层用途 |
|------|---------|---------|---------|---------|
| {Business}ApplicationService | `{方法签名}` | {返回类型} | {用例说明} | {如：Controller 接收请求后委托执行业务逻辑} |

#### Command 定义（来自 {application.md 导出契约 / 已有代码}）

| 类名 | 字段 | 类型 | 约束 | 本层用途 |
|------|------|------|------|---------|
| {Operation}Command | {字段} | {类型} | {约束} | {如：由 Request DTO 转换构建后传入 ApplicationService} |

#### 返回类型定义（来自 {application.md 导出契约 / 已有代码}）

| 类名 | 字段 | 类型 | 说明 | 本层用途 |
|------|------|------|------|---------|
| {ReturnType} | {字段} | {类型} | {说明} | {如：转换为 Response DTO 返回给调用方} |

<!-- OPTIONAL: 无 Domain 层直接依赖时可省略 -->
### 来自 Domain 层

#### {AggregateName} 聚合

| 类型 | 类名 | 方法/字段 | 用途 |
|------|------|----------|------|
| 值对象 | {ValueObject} | {字段} | {DTO 转换时复用} |

#### {AnotherAggregate} 聚合

（同上结构，按需列出该聚合中 OHS 层需要引用的类型）

<!-- OPTIONAL: 无 Infr 层依赖时可省略 -->
### 来自 Infr 层

| 类型 | 类名 | 方法/字段 | 用途 |
|------|------|----------|------|
| 工具类 | {UtilClass} | `{方法签名}` | {用途} |

## API 端点

### {HTTP_METHOD} /api/{resource}

**用途**：{一句话描述}

**Request DTO** — `{Operation}Request`：

| 字段 | 类型 | 校验注解 | 说明 |
|------|------|---------|------|
| | | @NotBlank / @Size(max=N) 等 | |

**Response DTO** — `{Operation}Response`：

| 字段 | 类型 | 说明 |
|------|------|------|
| | | |

**响应示例**：
```json
{
  "code": 200,
  "message": "success",
  "data": { }
}
```

## Controller

### {Business}Controller

**路径前缀**：`@RequestMapping("/api/{resource}")`
**依赖**：`{Business}ApplicationService`

#### {ResponseType} {methodName}(@Validated @RequestBody {Request} request)

**HTTP 映射**：`@PostMapping` / `@GetMapping("{id}")` 等

**DTO → Command 转换**：
```java
{Operation}Command command = {Operation}Command.builder()
    .xxx(request.getXxx())
    .yyy(request.getYyy())
    .build();
```

**调用**：`applicationService.{method}(command)`

**返回**：`Result.success({response})` 或 `Result.success()`

## RPC 端点

### {Business}GrpcService

**Proto 方法**：
- `rpc {Method}({Request}) returns ({Response})`

**实现映射**：
- 调用 `{Business}ApplicationService.{method}()`

<!-- REQUIRED -->
## 导出契约

### API 端点

| HTTP 方法 | URL | 用途 | Request DTO | Response DTO |
|-----------|-----|------|-------------|--------------|
| {METHOD} | /api/{resource} | {一句话描述} | {Operation}Request | {Operation}Response |

### Request DTO 定义

| DTO 类名 | 字段 | 类型 | 校验注解 | 说明 |
|----------|------|------|---------|------|
| {Operation}Request | {字段} | {类型} | {校验注解} | {说明} |

### Response DTO 定义

| DTO 类名 | 字段 | 类型 | 说明 |
|----------|------|------|------|
| {Operation}Response | {字段} | {类型} | {说明} |

<!-- REQUIRED -->
## 实现清单

| 序号 | output_id | 类名（全路径） | 关键实现点 | 对应章节 |
|------|-----------|---------------|-----------|---------|
| 1 | Output_OHS_{IdeaName}_01 | `{package}.{ClassName}` | {从上方设计中提取的2-5个关键实现要点} | {对应的章节名} |
```
