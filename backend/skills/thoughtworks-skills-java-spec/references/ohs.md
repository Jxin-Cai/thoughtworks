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

- 可依赖：Application 层、Infrastructure 层（仅工具类）
- 禁止依赖：Domain 层
