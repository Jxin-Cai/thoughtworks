# Java/Spring Boot 约定

本文件仅包含 Java 和 Spring Boot 框架特有的技术约定。架构原则和 DDD 层规则见 `architecture.md`。

## Lombok 使用

| 场景 | 注解 |
|------|------|
| Domain Entity/Value Object | `@Getter` + `@EqualsAndHashCode`，手写业务方法，**禁止 @Data** |
| Command | `@Getter` + `@Builder` |
| DTO (Request/Response) | `@Data` 或 `@Builder` |
| PO | `@Data` + `@TableName` |
| Service/Repository | `@RequiredArgsConstructor`（构造器注入） |

Spring Boot 3.x 须在构建配置中显式声明 Lombok annotation processor。

## 依赖注入

```java
@RequiredArgsConstructor
public class OrderApplicationService {
    private final OrderRepository orderRepository;  // private final 保证不可变
}
```

禁止 `@Autowired` 字段注入。

## 事务管理

```java
@Transactional(rollbackFor = Exception.class)          // 写操作
@Transactional(readOnly = true)                        // 查询操作
```

- 只加在 Application 层公有方法上
- 禁止在 Controller、Domain Service、RepositoryImpl 上加
- 事务方法内不做 RPC/消息发送等耗时 I/O

## MyBatis / MyBatis Plus

- PO 注解：`@TableName("t_xxx")`、`@TableId(type = IdType.AUTO)`
- Mapper 继承 `BaseMapper<PO>`，自定义方法用 `@Param`
- 批量操作用 `foreach`，禁止循环单条
- 分页用 PageHelper 或 MyBatis Plus 分页插件
- 复杂查询写 XML，动态 SQL 用 `<if>`/`<choose>`

## 数据库表设计

- 表名 `snake_case`，字段名 `snake_case`
- 必备字段：`id`(BIGINT 自增/雪花)、`created_time`、`updated_time`、`is_deleted`(TINYINT 0/1)
- 使用 `#{}` 防 SQL 注入，禁止 `${}`
- 禁止 `SELECT *`，明确列出字段
- WHERE 条件走索引

## 异常体系

```java
public class BusinessException extends RuntimeException {
    private final String code;
    private final String message;
}
```

- `@RestControllerAdvice` 全局处理器放在 `infr/aop/`
- 捕获 `BusinessException` → 业务错误码
- 捕获 `MethodArgumentNotValidException` → 校验错误
- 兜底 `Exception` → 系统错误 + 记录堆栈

## 统一响应结构

```java
public class Response<T> {
    private int code;
    private String message;
    private T data;

    public static <T> Response<T> success(T data) { ... }
    public static Response<?> error(String code, String message) { ... }
}
```

分页：`data: { list, total, pageNum, pageSize }`

## RESTful API

- URL：小写 `kebab-case`，资源名词复数：`/api/order-items/{id}`
- HTTP 方法：GET 查询 / POST 创建 / PUT 全量更新 / PATCH 部分更新 / DELETE 删除
- Controller 不写 try-catch

## 配置管理

- 按环境：`application-{profile}.yml`
- 自定义配置绑定到 `@ConfigurationProperties` POJO
- 敏感配置用环境变量，禁止明文

## 日志

- `@Slf4j` + 占位符：`log.info("orderId: {}", id)`
- 禁止 `System.out`、字符串拼接、输出敏感信息
- 级别：ERROR（系统异常）、WARN（业务异常）、INFO（关键节点）、DEBUG（调试）

## 异步

- 禁止 `new Thread()`，使用 `@Async` + 自定义线程池 `@Bean`
- 异步方法异常必须有处理机制

## 测试

| 层 | 策略 | 注解 |
|---|---|---|
| Domain | 纯 JUnit 5 + Mockito | 无需 Spring |
| Application | @MockBean 模拟 | @SpringBootTest 或切片 |
| Infrastructure | H2 集成测试 | @MybatisTest |
| OHS | MockMvc | @WebMvcTest |

命名：`should_预期行为_when_条件()`，结构：Given-When-Then。

## 安全

- 写操作考虑幂等（唯一索引、Token 机制）
- 敏感数据返回时脱敏
