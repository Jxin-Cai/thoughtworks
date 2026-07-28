# DDD 分层架构原则

## 架构全景

```
┌──────────────────┐
│   OHS Layer      │ ← 对外接口（HTTP/RPC），翻译 wire format ↔ 领域概念
└────────┬─────────┘
         ↓ 调用
┌──────────────────┐
│ Application Layer│ ← 编排层，协调领域对象完成用例
└────────┬─────────┘
         ↓ 使用
┌──────────────────┐
│  Domain Layer    │ ← 核心层，承载业务规则，零外部依赖
└────────┬─────────┘
         ↑ 实现接口
┌────────┴─────────┐
│ Infrastructure   │ ← 技术支撑层，实现 Domain 声明的抽象
└──────────────────┘
```

## 依赖矩阵

| 层 | 可依赖 | 禁止依赖 |
|---|---|---|
| OHS | Application | Domain、Infrastructure |
| Application | Domain | OHS、Infrastructure |
| Domain | 无 | 所有其他层 |
| Infrastructure | Domain（实现接口）、OHS+Application（仅限 AOP 切面） | — |

---

## 七条设计原则

### P1: Domain Independence — 领域层零外部依赖

**WHY**：领域层是业务规则的唯一权威表达。零依赖意味着：可以在纯单元测试中秒级验证全部业务逻辑；底层技术栈（数据库、框架、协议）可替换而不触及核心逻辑。

**从此原则可推导**：
- 禁止框架注解（@Component、@Service、@Autowired）
- 禁止 import 任何 `infr.*`、`ohs.*`、`application.*` 包
- 禁止技术细节（数据库访问、HTTP 调用、缓存、消息队列、日志）
- 测试不需要 Spring 容器启动

### P2: Dependency Inversion — 上层依赖 Domain 声明的抽象

**WHY**：领域层定义"我需要什么能力"（Repository、EventPublisher、AclService），基础设施层负责"如何实现"。这让领域层无需知道实现细节，也让实现可以随时切换。

**从此原则可推导**：
- Repository 接口在 Domain 层定义，实现在 Infrastructure 层
- EventPublisher 接口在 Domain 层定义
- Application 层通过 Domain 定义的接口协调，从不直接依赖 Infrastructure
- 仓储接口使用集合语义（save/remove），不暴露数据库语义（insert/delete）

### P3: Rich Domain Model — 业务规则活在领域对象内部

**WHY**：如果实体只有 getter/setter（贫血模型），业务规则必然散落在 Application 或 Service 中，导致相同规则在多处重复，修改时遗漏。信息专家模式——谁拥有数据，谁负责逻辑。

**从此原则可推导**：
- 实体必须包含业务方法
- 禁止 setter——状态变更通过有业务含义的方法（如 `order.cancel(reason)`）
- 使用 private 构造函数 + 静态工厂方法（确保创建时必满足不变量）
- 字段用 final 保护不变性
- 值对象不可变——业务方法返回新对象
- 优先将规则沉到实体/值对象/领域服务，而非上浮到 Application

### P4: Thin Application Layer — 仅编排，不计算

**WHY**：Application 层是胶水——调用领域对象、仓储、事件发布的编排者。如果业务规则上浮到这里，领域层就退化为数据容器，失去 P3 的价值。

**从此原则可推导**：
- 一个公有方法对应一个业务用例
- 方法体只有：获取领域对象 → 调用业务方法 → 持久化 → 发布事件
- 返回领域模型，不返回 DTO（DTO 封装属于 OHS 层职责）
- 不包含 if-else 业务判断——判断属于领域层
- 事务边界在此层管理

### P5: Infrastructure as Servant — 技术支撑实现领域接口

**WHY**：Infrastructure 的存在是为了满足 Domain 声明的需求。它拥有所有技术翻译（Domain Model ↔ PO、领域事件 ↔ MQ 消息），但不参与业务决策。

**从此原则可推导**：
- 实现 Domain 的 Repository 接口
- PO 对象仅用于数据库交互，禁止暴露到领域层
- save 方法内部判断 ID 是否为 null 决定 insert/update
- 查询方法需组装完整聚合根
- 全局异常处理（@RestControllerAdvice）放在此层——AOP 是技术关注点
- 禁止包含任何业务逻辑或业务状态变更

### P6: OHS as Translator — 对外接口只做翻译

**WHY**：OHS（Open Host Service）是外部世界进入系统的翻译层。它只负责：接收请求 → 转换为 Command → 调用 ApplicationService → 将结果转换为 Response。任何业务判断都不应该在这里。

**从此原则可推导**：
- Controller 不写 try-catch（异常由 Infrastructure AOP 兜底）
- 不直接调用 Domain Service 或 Repository（必须通过 Application）
- DTO 与 Command 的转换在此完成
- RESTful 规范（URL kebab-case、资源名词复数、标准 HTTP 方法）
- 统一响应包装 `{ code, message, data }`

### P7: Unidirectional Flow — 单向依赖流

**WHY**：层间形成有向无环图。如果出现环形依赖（如 Application 引用 Infrastructure），修改一层时另一层被迫跟着改，系统逐渐僵化。

**从此原则可推导**：
- OHS → Application → Domain ← Infrastructure
- 禁止反向依赖（Application 不能 import Infrastructure 的类）
- 跨层通信通过事件或接口抽象

---

## 层职责速览

| 层 | 核心职责 | 典型产出 |
|---|---|---|
| Domain | 承载业务规则，定义领域抽象 | Entity、Value Object、Aggregate、Domain Service、Repository Interface、Domain Event、ACL Interface |
| Infrastructure | 实现领域接口，技术翻译 | RepositoryImpl、PO、Mapper、Client、AOP（全局异常处理）、中间件配置 |
| Application | 编排用例，管理事务 | ApplicationService、Command |
| OHS | 翻译外部协议 ↔ 领域概念 | Controller、Request/Response DTO、Converter |

## 路径结构

```
{module}/
├── domain/{子域名}/
│   ├── model/          # Entity, Value Object, Aggregate Root
│   ├── repository/     # Repository Interface（按聚合根划分）
│   ├── event/          # Domain Event + EventPublisher Interface
│   ├── acl/            # Anti-Corruption Layer Interface
│   ├── service/        # Domain Service
│   └── lib/            # 领域内纯函数工具
├── infr/
│   ├── repository/     # RepositoryImpl, Mapper, PO
│   ├── aop/            # 全局异常处理、日志切面
│   ├── plugin/         # 中间件配置（Redis, MQ, ES）
│   └── client/         # 外部系统 Client
├── application/
│   ├── {业务名}/       # ApplicationService, Command
│   └── ...
└── ohs/
    └── http/           # Controller, Request/Response DTO
        ├── {端名}/     # 按端分目录（user, admin）
        └── ...
```

## 命名规范

| 类型 | 命名规则 | 层 |
|------|---------|---|
| 聚合根/实体 | `{业务概念名}` | Domain |
| 值对象 | `{业务概念名}` | Domain |
| 领域服务 | `{业务名}{动作}Service` | Domain |
| 仓储接口 | `{聚合根名}Repository` | Domain |
| 领域事件 | `{聚合根名}{动作过去式}Event` | Domain |
| 事件发布接口 | `{聚合根名}EventPublisher` | Domain |
| 防腐层接口 | `{外部领域名}AclService` | Domain |
| 仓储实现 | `{聚合根名}RepositoryImpl` | Infrastructure |
| Mapper | `{实体名}Mapper` | Infrastructure |
| PO | `{实体名}PO` | Infrastructure |
| Client | `{外部系统名}Client` | Infrastructure |
| 应用服务 | `{业务名}ApplicationService` | Application |
| Command | `{操作名}Command` | Application |
| Controller | `{业务名}Controller` | OHS |
| Request DTO | `{操作名}Request` | OHS |
| Response DTO | `{操作名}Response` | OHS |

## 跨切关注点

### 依赖注入
构造器注入（`@RequiredArgsConstructor`），禁止 `@Autowired` 字段注入。字段 `private final`。

### 异常策略
- 定义 `BusinessException` 基类（携带错误码）
- 业务代码只抛异常，不 catch
- 全局 `@RestControllerAdvice` 统一兜底
- 禁止空 catch 块

### 测试策略
- Domain：纯单元测试（JUnit 5），不需要 Spring 容器
- Application：@MockBean 模拟依赖
- Infrastructure：@MybatisTest / H2 集成测试
- OHS：@WebMvcTest + MockMvc
- 命名：`should_预期行为_when_条件()`

### 日志
SLF4J + `@Slf4j`，占位符格式 `log.info("msg: {}", val)`，禁止字符串拼接和敏感信息。
