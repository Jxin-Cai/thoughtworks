# Domain 层 Task 设计文档模板

> 每个 task 文件对应一个聚合的完整设计。
> 以下代码示例为 Java 参考格式。请根据 CONTEXT 中的 `backend_language` 使用对应语言的惯用写法和 spec 规范中的技术栈。

按以下结构输出，所有占位符 `{...}` 替换为实际内容。没有的章节整节删除，不要留空章节。

---

```markdown
---
task_id: domain-{nnn}
layer: domain
order: {N}
status: pending
depends_on: [{上游 task_id 列表，通常为空}]
description: "{AggregateName} 聚合设计"
---

# Domain: {AggregateName} 聚合

<!-- REQUIRED -->
## 结论

（一句话概括：本聚合的核心职责和关键业务规则）

## 聚合根与实体

### {AggregateRootName}

**职责**：（一句话）

**字段**：

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | {IdType} | 必填，唯一 | 聚合根标识 |

**静态工厂方法**：

```java
public static {AggregateRoot} create({参数列表}) {
    // 构造逻辑描述
}
```

**业务方法**：

| 方法签名 | 行为描述 | 业务规则 |
|----------|----------|----------|
| `void doSomething({参数})` | 行为描述 | 违反时抛出 {Exception} |

**不变量**：
- 规则描述 → 违反时行为

<!-- OPTIONAL -->
### {Entity}（聚合内实体，如有）

（同上格式，省略不变量）

## 值对象

### {ValueObjectName}

| 字段 | 类型 | 说明 |
|------|------|------|
| （所有字段 final） | | |

**验证规则**：
- 创建时校验：...

**业务方法**（如有）：
- `{ValueObject} withXxx({参数})` — 返回新对象，描述

## 仓储接口

### {AggregateRoot}Repository

```java
public interface {AggregateRoot}Repository {

    /**
     * {做什么}。
     * {关键约束}。
     * {异常场景}。
     */
    void save({AggregateRoot} entity);

    /**
     * {做什么}。
     * {加载策略}。
     * {不存在时行为}。
     */
    Optional<{AggregateRoot}> findById({IdType} id);
}
```

<!-- OPTIONAL -->
## 领域事件

### {AggregateRoot}{Action}Event

| 字段 | 类型 | 说明 |
|------|------|------|

**触发时机**：...
**消费方预期**：...

### {AggregateRoot}EventPublisher

```java
public interface {AggregateRoot}EventPublisher {
    void publish{Action}({Event} event);
}
```

<!-- OPTIONAL -->
## 防腐层接口

### {ExternalDomain}AclService

```java
public interface {ExternalDomain}AclService {
    {ReturnType} {method}({参数});
}
```

<!-- OPTIONAL -->
## 领域服务

### {DomainServiceName}

**职责**：（跨聚合编排逻辑描述）
**编排步骤**：
1. ...
2. ...

## 导出契约

### 聚合根与实体 API

| 类名 | 方法签名 | 返回类型 | 说明 |
|------|---------|---------|------|
| {AggregateRoot} | `{方法签名}` | {返回类型} | {说明} |

<!-- OPTIONAL -->
### 值对象定义

| 类名 | 字段 | 类型 | 说明 |
|------|------|------|------|
| {ValueObject} | {字段} | {类型} | {说明} |

### 接口签名

| 接口名 | 方法签名 | 返回类型 | 行为描述 |
|--------|---------|---------|---------|
| {AggregateRoot}Repository | `{方法签名}` | {返回类型} | {行为描述} |

<!-- REQUIRED -->
## 实现清单

| 序号 | output_id | 类名（全路径） | 关键实现点 | 对应章节 |
|------|-----------|---------------|-----------|---------|
| 1 | Output_Domain_{IdeaName}_{nnn}_01 | `{package}.{ClassName}` | {从上方设计中提取的2-5个关键实现要点} | {对应的章节名} |
```
