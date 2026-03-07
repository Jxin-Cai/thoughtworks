# 📋 公共规范

> 适用于基于 DDD 架构的 Java Spring Boot 后端项目。

## DDD 分层架构

核心原则：按职责分层，依赖倒置，领域层是核心。

```
┌──────────────────┐
│   OHS Layer      │ ← 对外接口（HTTP/RPC）
└────────┬─────────┘
         ↓
┌──────────────────┐
│ Application Layer│ ← 编排层
└────────┬─────────┘
         ↓
┌──────────────────┐
│  Domain Layer    │ ← 核心层（不依赖任何层）
└────────┬─────────┘
         ↑ 实现接口
┌────────┴─────────┐
│ Infrastructure   │ ← 技术支撑层
└──────────────────┘
```

### 依赖规则

| 层 | 可依赖 | 禁止依赖 |
|---|---|---|
| OHS | Application、Infrastructure（仅工具类） | Domain（不能直接调用） |
| Application | Domain、Infrastructure | OHS |
| Domain | 无 | 所有其他层 |
| Infrastructure | Domain（实现接口） | OHS、Application |

## Spring Boot 公共规范

### 依赖注入

- 强制使用构造器注入（@RequiredArgsConstructor），禁止 @Autowired 字段注入
- 依赖字段声明为 `private final`

### 异常处理

- 定义统一业务异常基类 `BusinessException`，携带错误码和消息
- 使用 `@RestControllerAdvice` 全局异常处理器，统一返回格式
- 禁止吞掉异常（空 catch 块）；非预期异常必须记录完整堆栈

### 配置管理

- 按环境拆分 `application-{profile}.yml`
- 敏感配置禁止明文，使用环境变量或配置中心
- 自定义配置使用 `@ConfigurationProperties` 绑定到 POJO，禁止散落的 @Value

### 日志规范

- 使用 SLF4J + Lombok @Slf4j，禁止 System.out/err
- 日志级别：ERROR（系统异常）、WARN（业务异常）、INFO（关键业务节点）、DEBUG（调试）
- 日志中禁止输出敏感信息；使用占位符 `log.info("userId: {}", id)`，禁止字符串拼接

### 线程与异步

- 禁止手动 new Thread，使用 Spring @Async + 自定义线程池（@Bean 显式配置）
- 异步方法异常必须有处理机制

### 安全规范

- 写操作接口需考虑幂等设计（唯一索引、Token 机制等）
- 敏感数据返回时脱敏处理

### 测试规范

- 领域层：纯单元测试（JUnit 5 + Mockito），不依赖 Spring 容器
- 应用层：@MockBean 模拟依赖，验证编排逻辑
- 仓储层：@MybatisTest 或 H2 内存库集成测试
- Controller 层：@WebMvcTest + MockMvc 验证参数校验和响应格式
- 命名：`should_预期行为_when_条件()`，结构：Given-When-Then

#### 代码质量规范

- **重构**：识别并规避《重构（Refactoring）》中描述的代码坏味道，例如：
    - 重复代码（Duplicated Code）
    - 过长方法（Long Method）
    - 过大类（Large Class）
    - 过长参数列表（Long Parameter List）
    - 发散式变化（Divergent Change）
    - 霰弹式修改（Shotgun Surgery）
- **Effective Java**：遵循《Effective Java》编码建议，例如：
    - 使用构建器（Builder）处理多参数构造
    - 优先使用枚举而非 int 常量
    - 最小化可变性
    - 合理使用 Optional
    - 优先使用标准异常