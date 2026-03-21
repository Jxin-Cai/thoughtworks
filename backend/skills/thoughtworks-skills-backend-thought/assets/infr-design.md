# Infrastructure 层设计文档模板

> 以下代码示例为 Java 参考格式。请根据 CONTEXT 中的 `backend_language` 使用对应语言的惯用写法和 spec 规范中的技术栈。

按以下结构输出，所有占位符 `{...}` 替换为实际内容。没有的章节整节删除，不要留空章节。

---

```markdown
# Infrastructure 层设计

<!-- REQUIRED -->
## 结论

（一句话概括：这一层要做什么，涉及哪些表和仓储实现）

<!-- REQUIRED -->
## 依赖契约

> 以下接口定义来自 Domain 层，Infr 层负责提供实现。
> 来源为已有代码（标注源文件路径），按聚合分组，每个聚合列出其需要实现的接口。

<!-- 来源标注规则：
- 子表标题后标注：（来自已有代码），每行「说明」列末尾附注源文件路径
-->

### 来自 {AggregateName} 聚合

#### 仓储实现契约（来自已有代码）

| 接口名 | 方法签名 | 返回类型 | 行为描述 | 实现方案 | 本层用途 |
|--------|---------|---------|---------|---------|---------|
| {AggregateRoot}Repository | `{方法签名}` | {返回类型} | {行为描述} | {MyBatis-Plus / 自定义 SQL / 组合查询} | {如：实现 save() 时调用 MyBatis-Plus insertOrUpdate} |

#### 事件发布实现契约（来自已有代码）

| 接口名 | 方法签名 | 返回类型 | 行为描述 | 实现方案 | 本层用途 |
|--------|---------|---------|---------|---------|---------|
| {AggregateRoot}EventPublisher | `{方法签名}` | {返回类型} | {行为描述} | {RocketMQ / Kafka / Spring Event / 数据库事件表} | {如：实现事件投递到 RocketMQ} |

#### 防腐层实现契约（来自已有代码）

| 接口名 | 方法签名 | 返回类型 | 行为描述 | 实现方案 | 本层用途 |
|--------|---------|---------|---------|---------|---------|
| {ExternalDomain}AclService | `{方法签名}` | {返回类型} | {行为描述} | {HTTP/Feign / gRPC / SDK / 消息队列} | {如：通过 Feign 调用外部服务实现 ACL 适配} |

### 来自 {AnotherAggregate} 聚合

（同上结构，按需列出该聚合的仓储/事件/防腐层实现契约）

## 数据库表设计

### {table_name}

```sql
CREATE TABLE {table_name} (
    id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '{注释}',
    -- 业务字段（逐个列出）
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    is_deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除'
) COMMENT='{表注释}';

-- 索引
CREATE INDEX idx_{table_name}_{field} ON {table_name}({field});
```

## PO 对象

### {Entity}PO

| PO 字段 | Java 类型 | 数据库列 | 对应领域模型字段 | 转换说明 |
|---------|----------|---------|-----------------|---------|
| id | Long | id | {AggregateRoot}.id | 直接映射 |

## Mapper

### {Entity}Mapper

**继承**：`BaseMapper<{Entity}PO>`

**自定义方法**：

```java
@Mapper
public interface {Entity}Mapper extends BaseMapper<{Entity}PO> {

    /**
     * {查询描述}。
     */
    @Param("{param}") {ReturnType} {method}({参数});
}
```

## 仓储实现

### {AggregateRoot}RepositoryImpl

**实现接口**：`{AggregateRoot}Repository`
**注入依赖**：`{Entity}Mapper`

#### save({AggregateRoot})
- ID 为 null → insert，否则 → update
- Domain → PO 转换：{逐字段描述}
- 聚合内实体处理：{描述}

#### findById({IdType})
- 查询主表 PO
- 查询关联表 PO（如有）
- PO → Domain 转换：{逐字段描述}
- 组装完整聚合

#### remove({IdType})
- 逻辑删除：`UPDATE SET is_deleted = 1`
- 级联处理：{描述}

## 外部集成

### {ExternalSystem}Client

**接口**：
```java
public interface {ExternalSystem}Client {
    {ReturnType} {method}({参数});
}
```

**配置**：
- 超时：{N}ms
- 重试：{策略}
- 熔断：{策略}

<!-- REQUIRED -->
## 实现清单

| 序号 | output_id | 类名（全路径） | 关键实现点 | 对应章节 |
|------|-----------|---------------|-----------|---------|
| 1 | Output_Infr_{IdeaName}_01 | `{package}.{ClassName}` | {从上方设计中提取的2-5个关键实现要点} | {对应的章节名} |
```
