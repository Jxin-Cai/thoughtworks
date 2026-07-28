# Python/FastAPI 约定

本文件仅包含 Python 和 FastAPI 框架特有的技术约定。架构原则和 DDD 层规则见 `architecture.md`。

## 领域模型定义

| 场景 | 方式 |
|------|------|
| Entity | `@dataclass` + `@classmethod` 工厂方法 |
| Value Object | `@dataclass(frozen=True)` |
| Domain Event | `@dataclass(frozen=True)` |
| Repository Interface | `abc.ABC` + `@abstractmethod` |

禁止在 Domain 层使用 Pydantic BaseModel（避免混淆数据传输与领域逻辑）。

## Pydantic 使用

| 场景 | 方式 |
|------|------|
| Command | `BaseModel` 或 `@dataclass(frozen=True)` |
| Request/Response DTO | `BaseModel` + `Field(...)` 校验 |
| 配置 | `pydantic-settings` 的 `BaseSettings` |

字段校验用 `Field(min_length=, ge=, pattern=)` + `model_validator` 处理跨字段校验。

## 依赖注入

```python
from fastapi import Depends
from typing import Annotated

OrderService = Annotated[OrderApplicationService, Depends(get_order_application_service)]
```

- 依赖工厂函数定义在 `infr/dependencies.py`
- 禁止全局变量传递依赖实例

## SQLAlchemy

- 使用 SQLAlchemy 2.0 风格：`select()` 语句，禁止 `session.query()`
- ORM Model 用 `DeclarativeBase` + `Mapped[T]` + `mapped_column()`
- 表名通过 `__tablename__` 指定（snake_case）
- 批量操作用 `session.add_all()` 或 `insert().values([...])`，禁止循环单条
- 分页：`select().offset().limit()` + `select(func.count())`

## 事务管理

```python
async with session.begin():
    # 事务操作
```

- 只在 Application 层管理事务
- 查询方法使用只读 Session
- 事务内不做 RPC/消息发送

## Alembic 迁移

- 每次模型变更：`alembic revision --autogenerate -m "描述"`
- 必须包含 `upgrade()` 和 `downgrade()`
- 迁移文件提交版本控制

## 数据库表设计

- 表名 `snake_case`，字段名 `snake_case`
- 必备字段：`id`(BIGINT)、`created_time`、`updated_time`、`is_deleted`(INTEGER 0/1)
- 使用参数绑定防 SQL 注入
- 禁止 `SELECT *`（全量加载聚合根除外）
- WHERE 条件走索引
- DELETE 优先逻辑删除

## 异常体系

```python
class BusinessException(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message
```

- `app.exception_handler(BusinessException)` 注册全局处理
- 捕获 `RequestValidationError` → 参数错误
- 兜底 `Exception` → 系统错误 + 记录堆栈

## 统一响应

```python
class ApiResponse(BaseModel, Generic[T]):
    code: int = 0
    message: str = "ok"
    data: T | None = None
```

分页：`data: {"list": [...], "total": N, "page_num": 1, "page_size": 20}`

## RESTful API

- URL：小写 `kebab-case`，资源名词复数
- HTTP 方法：GET/POST/PUT/PATCH/DELETE
- Router 不写 try-except

## 异步

- FastAPI 路由默认 `async def`
- CPU 密集任务用 `run_in_executor`
- 禁止在 `async def` 中调用同步阻塞 I/O

## 日志

- `logging` + `structlog`，禁止 `print()`
- 结构化参数：`logger.info("event", key=value)`

## 配置

- `pydantic-settings` 的 `BaseSettings`
- 支持 `.env` 文件 + 环境变量
- 敏感配置禁止明文

## 测试

| 层 | 策略 |
|---|---|
| Domain | 纯 pytest，无外部依赖 |
| Application | `unittest.mock.patch` / `MagicMock` |
| Infrastructure | SQLite 内存库 / testcontainers |
| OHS | `httpx.AsyncClient` + TestClient |

命名：`test_{预期行为}_when_{条件}`，结构：Arrange-Act-Assert。

## 命名规范

- 模块/变量：`snake_case`
- 类名：`PascalCase`
- 常量：`UPPER_SNAKE_CASE`
- 文件名：`snake_case.py`

## 安全

- 写操作考虑幂等（唯一索引、Token 机制）
- 敏感数据脱敏
- FastAPI 安全依赖（`OAuth2PasswordBearer`、`HTTPBearer`）
