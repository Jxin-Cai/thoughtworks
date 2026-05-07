# 📋 公共规范

> 适用于基于 DDD 架构的 Go Gin 后端项目。

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
| OHS | Application | Domain、Infrastructure |
| Application | Domain | OHS、Infrastructure |
| Domain | 无 | 所有其他层 |
| Infrastructure | Domain（实现接口） | OHS、Application |

## Go Gin 公共规范

### 结构体设计

- 使用 struct + 方法接收器承载行为，禁止在 package 级别定义全局可变变量
- 导出字段使用 PascalCase，私有字段使用 camelCase
- 优先组合（embedding）而非继承式设计

### 依赖注入

- 通过构造函数 `New{Name}()` 注入依赖，依赖作为 struct 的 unexported 字段保存
- 禁止在 `init()` 中执行依赖注入或复杂初始化逻辑
- 依赖声明为接口类型，便于测试替换
- 构造函数中对必要依赖做 nil 检查，不满足时 panic 明确报错

### 异常处理

- 定义统一业务错误类型 `BusinessError`，实现 `error` 接口，携带错误码（Code）和消息（Message）
- 在 Gin middleware 中统一捕获 `BusinessError` 和未知错误，转换为标准响应格式
- 禁止吞掉错误（`_ = someFunc()`）；非预期错误必须记录完整堆栈
- 使用 `fmt.Errorf("xxx: %w", err)` 包装错误链，保留原始错误上下文

### 配置管理

- 使用 viper 读取 YAML 配置文件和环境变量
- 配置绑定到专用 struct（如 `AppConfig`、`DatabaseConfig`），禁止散落的 `viper.GetString()` 调用
- 敏感配置（密码、密钥）禁止明文写入配置文件，使用环境变量注入
- 按环境拆分配置文件：`config-dev.yaml`、`config-prod.yaml`

### 日志规范

- 使用 zap 或 zerolog 结构化日志库，禁止 `fmt.Println`、`log.Println`
- 日志级别：Error（系统异常）、Warn（业务异常）、Info（关键业务节点）、Debug（调试）
- 日志中禁止输出敏感信息；使用结构化字段 `zap.String("userId", id)`，禁止字符串拼接
- 请求链路使用 requestId 贯穿，通过 context 传递

### 并发规范

- 禁止裸 `go func()` 不处理 panic，必须在 goroutine 内 defer recover 或使用 errgroup
- 优先使用 `golang.org/x/sync/errgroup` 管理并发任务组
- 使用 channel 做 goroutine 间通信，避免共享内存；必须共享时使用 `sync.Mutex`
- context 贯穿所有异步调用，支持超时和取消

### 安全规范

- 写操作接口需考虑幂等设计（唯一索引、Token 机制等）
- 敏感数据返回时脱敏处理
- SQL 查询使用 GORM 参数化查询，禁止字符串拼接 SQL

### 测试规范

- 领域层：纯单元测试（testing + testify/assert），不依赖任何外部服务
- 应用层：mock 接口依赖（testify/mock 或 gomock），验证编排逻辑
- 仓储层：SQLite 内存数据库或 testcontainers 集成测试
- API 层：httptest + gin.TestMode 验证参数校验和响应格式
- 命名：`Test{功能}_When{条件}_Should{预期}`
- 结构：Arrange-Act-Assert（对应 Given-When-Then）
- 优先使用表驱动测试（Table-Driven Tests）覆盖多种输入场景

### 代码质量规范

- **重构**：识别并规避《重构（Refactoring）》中描述的代码坏味道，例如：
    - 重复代码（Duplicated Code）
    - 过长函数（Long Function）
    - 过大结构体（Large Struct）
    - 过长参数列表（Long Parameter List）
    - 发散式变化（Divergent Change）
    - 霰弹式修改（Shotgun Surgery）
- **Go 惯用实践**：遵循 Go 社区编码惯例，例如：
    - 接口由消费方定义，保持小接口（1-3 个方法）
    - error 作为返回值显式处理，不使用 panic 做流程控制
    - 使用 `context.Context` 作为函数第一个参数传递请求范围数据
    - 命名返回值仅用于文档目的，避免裸 return
    - 优先使用组合而非继承
    - 零值可用设计（struct 零值应有合理默认行为）
