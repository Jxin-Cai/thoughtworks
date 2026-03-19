# Application 层设计文档模板

> 以下代码示例为 Java 参考格式。请根据 CONTEXT 中的 `backend_language` 使用对应语言的惯用写法和 spec 规范中的技术栈。

按以下结构输出，所有占位符 `{...}` 替换为实际内容。没有的章节整节删除，不要留空章节。

---

```markdown
# Application 层设计

<!-- REQUIRED -->
## 结论

（一句话概括：这一层要做什么，涉及哪些业务用例）

<!-- REQUIRED -->
## 依赖契约

> 以下接口和对象定义来自 Domain 层，Application 层作为消费方使用。
> 来源为以下之一：① 当前 idea 的 Domain 层设计文档导出契约；② 已有代码（标注源文件路径）。
> 按聚合分组，每个聚合列出本层需要消费的接口。

<!-- 来源标注规则：
- 来自设计文档时，子表标题后标注：（来自 domain.md 导出契约）
- 来自已有代码时，子表标题后标注：（来自已有代码）并在每行「说明」列末尾附注源文件路径
-->

### 来自 Domain 层

#### {AggregateName} 聚合

##### 聚合根 API（来自 {domain.md 导出契约 / 已有代码}）

| 类名 | 方法签名 | 返回类型 | 说明（来自 Domain 层） | 本层用途 |
|------|---------|---------|----------------------|---------|
| {AggregateRoot} | `{方法签名}` | {返回类型} | {说明} | {如：在 {methodName} 用例中调用以执行业务逻辑} |

##### Repository 接口（来自 {domain.md 导出契约 / 已有代码}）

| 接口名 | 方法签名 | 返回类型 | 本层用途 |
|--------|---------|---------|---------|
| {AggregateRoot}Repository | `{方法签名}` | {返回类型} | {如：加载聚合根供业务方法调用 / 持久化聚合根状态变更} |

#### {AnotherAggregate} 聚合

（同上结构，按需列出该聚合的聚合根 API 和 Repository 接口）

## Command 对象

### {Operation}Command

**对应用例**：{业务用例名称}

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| | | @NotNull / @NotBlank 等 | |

**构建方式**：`@Builder`，所有字段 final

## 应用服务

### {Business}ApplicationService

**依赖**：

| 字段 | 类型 | 用途 |
|------|------|------|
| {name}Repository | {AggregateRoot}Repository | 聚合持久化 |

#### {returnType} {methodName}({Command} command)

**用例**：{一句话描述}
**事务**：`@Transactional(rollbackFor = Exception.class)` 或 `@Transactional(readOnly = true)`

**编排步骤**：
1. `{repository}.findById(command.getId())` — 加载聚合根
2. `{aggregateRoot}.{businessMethod}(command.getXxx())` — 调用业务方法
3. `{repository}.save({aggregateRoot})` — 持久化
4. `{eventPublisher}.publish{Action}(new {Event}(...))` — 发布事件（如需要）

**异常处理**：
- 聚合根不存在 → 抛出 `BusinessException("{message}")`
- {其他场景} → {处理方式}

<!-- REQUIRED -->
## 导出契约

### 应用服务 API

| 类名 | 方法签名 | 返回类型 | 说明 |
|------|---------|---------|------|
| {Business}ApplicationService | `{方法签名}` | {返回类型} | {说明} |

### Command 定义

| 类名 | 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|------|
| {Operation}Command | {字段} | {类型} | {约束} | {说明} |

### 返回类型定义

<!-- 返回类型必须是领域层模型（聚合根、实体、值对象或其组合），禁止在 Application 层定义 DTO。DTO 封装由 OHS 层负责。 -->

| 类名 | 字段 | 类型 | 说明 |
|------|------|------|------|
| {ReturnType} | {字段} | {类型} | {说明} |

<!-- REQUIRED -->
## 实现清单

| 序号 | output_id | 类名（全路径） | 关键实现点 | 对应章节 |
|------|-----------|---------------|-----------|---------|
| 1 | Output_Application_{IdeaName}_01 | `{package}.{ClassName}` | {从上方设计中提取的2-5个关键实现要点} | {对应的章节名} |
```
