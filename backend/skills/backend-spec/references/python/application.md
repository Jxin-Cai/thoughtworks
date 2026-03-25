# 📋 Application 层（应用层）约束

## 允许

- 编排多个 Domain Service / Repository 完成业务用例
- 管理事务边界（SQLAlchemy Session 事务管理）
- 协调多个聚合根之间的交互
- 调用基础设施层（事件发布、缓存、消息等）
- 记录入参出参日志（INFO 级别）

## 禁止

- 包含业务规则（业务规则属于领域层）
- 包含复杂计算逻辑
- 直接操作数据库（必须通过 Repository）
- 依赖 OHS 层
- 定义 DTO 类（返回类型使用领域层模型，DTO 封装由 OHS 层负责）
- 用 try-except 做异常兜底（异常自然上抛，由 Infrastructure 层全局异常处理器统一拦截）

## 核心原则

- 薄薄一层，只做编排不做计算
- 一个公有方法对应一个业务用例

## 事务管理

- 事务管理只在本层处理，使用 SQLAlchemy Session 的上下文管理器或显式 `commit()`/`rollback()`
- 推荐使用上下文管理器模式：`with session.begin():` 或 `async with session.begin():`
- 查询方法使用只读 Session 或 `session.execute()` 直接查询，避免不必要的事务开销
- 事务方法内不做 RPC 调用、消息发送等耗时 I/O（避免大事务）
- 禁止在 Router、领域服务、仓储实现上管理事务

## Command 对象

- 使用 Pydantic `BaseModel` 或 `@dataclass` 定义，字段不可变
- 命名：`{操作名}Command`
- Command 只携带执行用例所需的输入数据，不包含业务逻辑

## 命名

- 应用服务：`{业务名}ApplicationService`
- Command 对象：`{操作名}Command`
- 模块文件名：`snake_case.py`（如 `order_application_service.py`、`create_order_command.py`）

## 依赖方向

- 可依赖：Domain 层
- 禁止依赖：OHS 层、Infrastructure 层
