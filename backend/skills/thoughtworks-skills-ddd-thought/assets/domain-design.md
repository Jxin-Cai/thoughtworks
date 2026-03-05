# Domain 层设计文档模板

按以下结构输出，所有占位符 `{...}` 替换为实际内容。没有的章节整节删除，不要留空章节。

---

```markdown
# Domain 层设计

<!-- REQUIRED -->
## 结论

（一句话概括：这一层要做什么，涉及哪些聚合根）

<!-- REQUIRED -->
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

<!-- REQUIRED -->
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

## 领域事件

### {AggregateRoot}{Action}Event

| 字段 | 类型 | 说明 |
|------|------|------|
| | | |

**触发时机**：...
**消费方预期**：...

### {AggregateRoot}EventPublisher

```java
public interface {AggregateRoot}EventPublisher {

    /**
     * {事件业务含义}。
     * {触发时机}。
     * {消费方预期行为}。
     */
    void publish{Action}({Event} event);
}
```

## 防腐层接口

### {ExternalDomain}AclService

```java
public interface {ExternalDomain}AclService {

    /**
     * {调用外部什么能力}。
     * {期望行为}。
     * {失败处理策略}。
     */
    {ReturnType} {method}({参数});
}
```

## 领域服务

### {DomainServiceName}

**职责**：（跨聚合编排逻辑描述）

```java
public class {DomainService} {

    /**
     * {编排逻辑描述}。
     */
    {ReturnType} {method}({参数});
}
```

**编排步骤**：
1. ...
2. ...

<!-- REQUIRED -->
## 导出契约

### 聚合根与实体 API

| 类名 | 方法签名 | 返回类型 | 说明 |
|------|---------|---------|------|
| {AggregateRoot} | `{方法签名}` | {返回类型} | {说明} |

<!-- OPTIONAL: 无值对象时可省略 -->
### 值对象定义

| 类名 | 字段 | 类型 | 说明 |
|------|------|------|------|
| {ValueObject} | {字段} | {类型} | {说明} |

### 接口签名

| 接口名 | 方法签名 | 返回类型 | 行为描述 |
|--------|---------|---------|---------|
| {AggregateRoot}Repository | `{方法签名}` | {返回类型} | {行为描述：save 时 insert-or-update 策略及冲突处理、查询时的加载策略及关联抓取范围、删除时的级联策略} |
| {AggregateRoot}EventPublisher | `{方法签名}` | {返回类型} | {行为描述：投递语义（至少一次/恰好一次）、消费方预期行为及幂等要求} |
| {ExternalDomain}AclService | `{方法签名}` | {返回类型} | {行为描述：外部域实际接口及版本、ACL 内部适配与数据映射逻辑、超时/重试/熔断策略} |

<!-- REQUIRED -->
## 实现清单

| 序号 | output_id | 类名（全路径） | 关键实现点 | 对应章节 |
|------|-----------|---------------|-----------|---------|
| 1 | Output_Domain_{IdeaName}_01 | `{package}.{ClassName}` | {从上方设计中提取的2-5个关键实现要点} | {对应的章节名} |
```
