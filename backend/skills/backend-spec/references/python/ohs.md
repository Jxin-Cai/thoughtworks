# 📋 OHS 层（开放主机层）约束

## 路径结构

- `ohs/http/` — HTTP 端点（REST API，FastAPI Router）
- `ohs/rpc/` — RPC 端点（gRPC 等）

## 允许

- Router、DTO（Request/Response BaseModel）、Converter、RPC Service
- 接收请求、参数校验（Pydantic Field 校验 + 自定义 Validator）
- DTO 与 Command 对象的转换
- 调用 ApplicationService
- 异常捕获与协议级转换

## RESTful API 规范

- URL 使用小写 kebab-case，资源名词复数：`/api/quote-items/{id}`
- 标准 HTTP 方法：GET（查询）/ POST（创建）/ PUT（全量更新）/ PATCH（部分更新）/ DELETE（删除）
- 所有接口返回统一包装结构：`{"code": 0, "message": "ok", "data": ...}`
- 分页查询返回：`{"code": 0, "message": "ok", "data": {"list": [...], "total": 100, "page_num": 1, "page_size": 20}}`
- Router 不写 try-except，交由全局异常处理器兜底

## 统一响应包装

- 项目必须有一个公共 `ApiResponse`（或同等语义类），包含 `code`、`message`、`data` 三个字段
- **复用优先**：先用 Glob 搜索 `**/ohs/**/api_response.py` 或 `**/ohs/**/response.py`；已有则直接复用，没有才新建
- 面向 HTTP 的接口统一用 ApiResponse 包装后再返回给调用方
- 同一项目可能存在多端（如 user 端、admin 端），按端在 `ohs/http/` 下分子目录（如 `ohs/http/user/`、`ohs/http/admin/`），公共 ApiResponse 放在 `ohs/http/` 的公共模块中，各端共享

```python
from pydantic import BaseModel, Field
from typing import Generic, TypeVar

T = TypeVar("T")

class ApiResponse(BaseModel, Generic[T]):
    code: int = Field(default=0, description="业务状态码，0 表示成功")
    message: str = Field(default="ok", description="响应消息")
    data: T | None = Field(default=None, description="响应数据")

    @classmethod
    def success(cls, data: T | None = None) -> "ApiResponse[T]":
        return cls(code=0, message="ok", data=data)

    @classmethod
    def fail(cls, code: int, message: str) -> "ApiResponse[None]":
        return cls(code=code, message=message, data=None)
```

## 全局异常处理

- 项目必须有一个全局异常处理器（FastAPI exception_handler），拦截所有异常并统一包装为 ApiResponse 返回
- **复用优先**：先用 Glob 搜索 `**/ohs/**/exception_handler*.py` 或 `**/ohs/**/error_handler*.py`；已有则直接复用，没有才新建
- 内部业务逻辑只需 raise 异常，Router 不写 try-except

## 禁止

- 包含任何业务逻辑或业务规则判断
- 直接调用 Domain Service 或 Repository
- 直接操作数据库
- 直接依赖领域层（必须通过应用层中转）

## 命名

- Router 模块：`{业务名}_router.py`
- Request DTO：`{操作名}Request`
- Response DTO：`{操作名}Response`
- RPC 服务：`{业务名}GrpcService`

## 依赖方向

- 可依赖：Application 层
- 禁止依赖：Domain 层、Infrastructure 层
