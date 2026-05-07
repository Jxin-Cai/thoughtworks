# 📋 Infrastructure 层（基础设施层）约束

## 路径结构

- `infr/repository/` — 仓储实现、SQLAlchemy ORM Model
- `infr/middleware/` — 中间件（全局异常处理、日志、CORS、请求 ID 注入等）
- `infr/client/` — 外部系统集成（HTTP Client、RPC Client）
- `infr/plugin/` — 中间件集成（Redis、MQ、ES 等配置）

## 允许

- 实现领域层定义的 Repository 接口
- 领域对象与 ORM Model 的双向转换
- 数据库访问（SQLAlchemy Session）、所有增删改查操作
- 外部系统集成、中间件配置、缓存管理
- 全局异常处理

## 全局异常处理（Middleware）

Infrastructure 层必须实现全局异常处理，拦截 OHS 层（Router）抛出的异常做兜底处理：

- 使用 FastAPI `app.exception_handler` 注册异常处理函数，放在 `infr/middleware/` 目录下
- 捕获 `BusinessException` 返回业务错误码和消息
- 捕获 Pydantic `ValidationError` 和 FastAPI `RequestValidationError`，返回参数校验错误信息
- 捕获 `Exception` 作为兜底，返回统一的系统错误响应，并记录完整堆栈日志
- **其他层（Application、OHS）禁止用 try-except 做异常兜底**，异常自然上抛由此全局处理器统一处理

## 禁止

- 包含任何业务逻辑
- 修改聚合根的业务状态（业务状态变更属于领域层）
- 在仓储方法中进行业务规则校验
- 依赖 OHS 层或 Application 层

## 命名

- 仓储实现：`{聚合根名}RepositoryImpl`
- ORM Model：`{实体名}Model`
- Client：`{外部系统名}Client`
- 模块文件名：`snake_case.py`（如 `order_repository_impl.py`、`order_model.py`）

## 依赖方向

- 可依赖：Domain 层（实现其接口）
- 禁止依赖：OHS 层、Application 层
