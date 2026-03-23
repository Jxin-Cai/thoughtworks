# Infrastructure 层 Task 设计文档模板

> 每个 task 文件对应一个聚合的基础设施实现。
> 以下代码示例为 Java 参考格式。请根据 CONTEXT 中的 `backend_language` 使用对应语言的惯用写法和 spec 规范中的技术栈。

按以下结构输出，所有占位符 `{...}` 替换为实际内容。没有的章节整节删除，不要留空章节。

---

```markdown
---
task_id: infr-{nnn}
layer: infr
order: {N}
status: pending
depends_on: [{上游 task_id 列表，如 domain-001}]
description: "{AggregateName} 基础设施实现"
---

# Infrastructure: {AggregateName} 基础设施实现

<!-- REQUIRED -->
## 结论

（一句话概括：本 task 要做什么，涉及哪些表和仓储实现）

<!-- REQUIRED -->
## 依赖契约

> 以下接口定义来自 Domain 层，Infr 层负责提供实现。
> 来源为已有代码（标注源文件路径）。

### 来自 {AggregateName} 聚合

#### 仓储实现契约（来自已有代码）

| 接口名 | 方法签名 | 返回类型 | 行为描述 | 实现方案 |
|--------|---------|---------|---------|---------|
| {AggregateRoot}Repository | `{方法签名}` | {返回类型} | {行为描述} | {MyBatis-Plus / 自定义 SQL / 组合查询} |

<!-- OPTIONAL -->
#### 事件发布实现契约（来自已有代码）

| 接口名 | 方法签名 | 返回类型 | 行为描述 | 实现方案 |
|--------|---------|---------|---------|---------|
| {AggregateRoot}EventPublisher | `{方法签名}` | {返回类型} | {行为描述} | {RocketMQ / Kafka / Spring Event} |

<!-- OPTIONAL -->
#### 防腐层实现契约（来自已有代码）

| 接口名 | 方法签名 | 返回类型 | 行为描述 | 实现方案 |
|--------|---------|---------|---------|---------|
| {ExternalDomain}AclService | `{方法签名}` | {返回类型} | {行为描述} | {HTTP/Feign / gRPC} |

## 数据库设计要点

### {table_name}

**对应聚合根/实体**：{AggregateRoot}
**核心业务字段**：{字段1}, {字段2}, ...（Worker 根据领域模型推导完整 DDL）
**索引策略**：{需要索引的查询场景}
**特殊约束**：{逻辑删除、乐观锁、JSON 字段等}

<!-- 如有关联表，继续添加 ### {another_table_name} -->

## 仓储实现策略

### {AggregateRoot}RepositoryImpl

**关键实现要点**：
- save: {insert/update 判断策略，如：ID 为 null 则 insert}
- findById: {关联加载策略，如：主表+明细表 join 或分次查询}
- {其他方法}: {关键实现思路}

**值对象映射要点**：
- {ValueObject} → {映射方式：嵌入字段 / JSON 序列化 / 关联表}

<!-- OPTIONAL -->
## 外部集成

### {ExternalSystem}Client

**实现方案**：{Feign / RestTemplate / gRPC}
**关键配置**：超时 {N}ms / 重试 {N}次 / 熔断 {策略}

<!-- REQUIRED -->
## 设计约束

- {ORM 框架约定}
- {命名约定}
- {其他约束}

<!-- REQUIRED -->
## 实现清单

| 序号 | output_id | 类名（全路径） | 关键实现点 | 对应章节 |
|------|-----------|---------------|-----------|---------|
| 1 | Output_Infr_{IdeaName}_{nnn}_01 | `{package}.{ClassName}` | {从上方设计中提取的2-5个关键实现要点} | {对应的章节名} |
```
