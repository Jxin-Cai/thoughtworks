# 📋 公共规范

> 适用于基于 DDD 架构的 Python FastAPI 后端项目。

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

## Python FastAPI 公共规范

### Pydantic

- 项目默认使用 Pydantic 做数据验证与序列化
- DTO / Command / Request / Response 等数据类使用 `BaseModel` 定义
- 字段校验使用 `Field(...)` 声明约束（`min_length`、`max_length`、`ge`、`le`、`pattern` 等）
- 使用 `model_validator` 处理跨字段校验
- 领域模型（实体、值对象）禁止使用 Pydantic BaseModel（避免混淆数据传输与领域逻辑），使用 `dataclass` 或 `attrs`

### 依赖注入

- 强制使用 FastAPI `Depends` + 构造函数注入组合依赖
- 禁止使用全局变量传递依赖实例
- 依赖工厂函数定义在独立的 `dependencies.py` 模块中，保持 Router 文件简洁
- 依赖声明使用类型注解，利用 `Annotated[T, Depends(...)]` 语法

### 异常处理

- 定义统一业务异常基类 `BusinessException`，携带错误码（`code`）和消息（`message`）
- 使用 FastAPI `app.exception_handler(BusinessException)` 注册全局异常处理器，统一返回格式
- 禁止吞掉异常（空 `except` 块）；非预期异常必须记录完整堆栈
- 禁止使用裸 `except:` 或 `except Exception`（兜底处理仅在全局异常处理器中）

### 配置管理

- 使用 `pydantic-settings` 的 `BaseSettings` 管理配置
- 支持环境变量 + `.env` 文件加载，按 `model_config = SettingsConfigDict(env_file=".env")` 配置
- 敏感配置禁止明文硬编码，使用环境变量注入
- 配置类按职责拆分（数据库配置、Redis 配置等），通过嵌套 `BaseSettings` 或前缀区分

### 日志规范

- 使用 `logging` 标准库 + `structlog` 结构化日志，禁止 `print()`
- 日志级别：ERROR（系统异常）、WARNING（业务异常）、INFO（关键业务节点）、DEBUG（调试）
- 日志中禁止输出敏感信息；使用结构化参数 `logger.info("user_action", user_id=id, action="login")`，禁止字符串拼接或 f-string 拼日志
- 配置统一日志格式，包含时间戳、级别、模块、请求 ID

### 异步规范

- FastAPI 路由函数默认使用 `async def`，搭配 `await` 处理 I/O 密集操作
- CPU 密集型任务使用 `run_in_executor` 或 `anyio.to_thread.run_sync` 避免阻塞事件循环
- 数据库操作使用 SQLAlchemy async engine + `AsyncSession`，或在同步 Session 场景下使用 `def` 路由
- 禁止在 `async def` 函数中调用同步阻塞 I/O（如同步 HTTP 请求、`time.sleep`）

### 安全规范

- 写操作接口需考虑幂等设计（唯一索引、幂等 Token 机制等）
- 敏感数据返回时脱敏处理
- 使用 FastAPI 安全依赖（`OAuth2PasswordBearer`、`HTTPBearer` 等）管理认证

### 测试规范

- 使用 `pytest` + `pytest-asyncio` 编写测试
- 领域层：纯单元测试，不依赖任何框架或外部服务
- 应用层：使用 `unittest.mock.patch` / `MagicMock` 模拟依赖，验证编排逻辑
- 仓储层：使用 SQLite 内存库或 `testcontainers` 做集成测试
- API 层：使用 `httpx.AsyncClient` + FastAPI `TestClient` 验证参数校验和响应格式
- 命名：`test_{预期行为}_when_{条件}`
- 结构：AAA 模式（Arrange-Act-Assert）
- 每个测试只验证一个行为，禁止在一个测试中断言多个不相关行为

### 代码质量规范

- **重构**：识别并规避《重构（Refactoring）》中描述的代码坏味道，例如：
    - 重复代码（Duplicated Code）
    - 过长方法（Long Method）
    - 过大类（Large Class）
    - 过长参数列表（Long Parameter List）
    - 发散式变化（Divergent Change）
    - 霰弹式修改（Shotgun Surgery）
- **Pythonic 编码**：遵循 Python 社区最佳实践，例如：
    - 使用类型注解（Type Hints）提高代码可读性和 IDE 支持
    - 优先使用枚举（`enum.Enum`）而非字符串常量或魔法数字
    - 最小化可变性，优先使用不可变数据结构（`tuple`、`frozenset`、`frozen dataclass`）
    - 合理使用 `Optional` 类型注解（`T | None`）
    - 优先使用标准异常（`ValueError`、`TypeError`、`KeyError` 等）
    - 遵循 PEP 8 命名规范：模块和变量 `snake_case`，类名 `PascalCase`，常量 `UPPER_SNAKE_CASE`
