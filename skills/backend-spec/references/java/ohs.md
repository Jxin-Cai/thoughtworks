# 📋 OHS 层（开放主机层）约束

## 路径结构

- `ohs/http/` — HTTP 端点（REST API）
- `ohs/rpc/` — RPC 端点（gRPC、Dubbo 等）

## 允许

- Controller、DTO（Request/Response）、Converter、RpcService
- 接收请求、参数校验（@Validated + JSR 380 注解）
- DTO 与 Command 对象的转换
- 调用 ApplicationService
- 异常捕获与协议级转换

## RESTful API 规范

- URL 使用小写 kebab-case，资源名词复数：`/api/quote-items/{id}`
- 标准 HTTP 方法：GET（查询）/ POST（创建）/ PUT（全量更新）/ PATCH（部分更新）/ DELETE（删除）
- 所有接口返回统一包装结构：`{ code, message, data }`
- 分页查询返回：`{ code, message, data: { list, total, pageNum, pageSize } }`
- Controller 层不写 try-catch，交由 @RestControllerAdvice 全局处理器兜底

## 统一响应包装

- 项目必须有一个公共 `Response`（或同等语义类），包含 `code`、`message`、`data` 三个字段
- **复用优先**：先用 Glob 搜索 `**/ohs/**/Response.java` 或 `**/ohs/**/ApiResponse.java`；已有则直接复用，没有才新建
- 面向 HTTP 的接口统一用 Response 包装后再返回给调用方
- 同一项目可能存在多端（如 user 端、admin 端），按端在 `ohs/http/` 下分子目录（如 `ohs/http/user/`、`ohs/http/admin/`），公共 Response 类放在 `ohs/http/` 的公共包中，各端共享

## 全局异常处理

- 项目必须有一个 `@RestControllerAdvice` 全局异常处理器，拦截所有异常并统一包装为 Response 返回
- **复用优先**：先用 Glob 搜索 `**/ohs/**/*Advice.java` 或 `**/ohs/**/*ExceptionHandler.java`；已有则直接复用，没有才新建
- 内部业务逻辑只需抛出异常，Controller 不写 try-catch

## 禁止

- 包含任何业务逻辑或业务规则判断
- 直接调用 Domain Service 或 Repository
- 直接操作数据库
- 直接依赖领域层（必须通过应用层中转）

## 命名

- Controller：`{业务名}Controller`
- Request DTO：`{操作名}Request`
- Response DTO：`{操作名}Response`
- RPC 服务：`{业务名}GrpcService`

## 依赖方向

- 可依赖：Application 层
- 禁止依赖：Domain 层、Infrastructure 层
