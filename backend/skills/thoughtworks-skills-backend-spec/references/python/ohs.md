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

示例：

```python
from fastapi import APIRouter, Depends

router = APIRouter(prefix="/api/orders", tags=["订单"])

@router.post("", summary="创建订单")
async def create_order(
    request: CreateOrderRequest,
    service: Annotated[OrderApplicationService, Depends(get_order_service)],
) -> ApiResponse[CreateOrderResponse]:
    command = CreateOrderCommand(
        product_id=request.product_id,
        quantity=request.quantity,
        price=request.price,
    )
    order = service.create_order(command)
    return ApiResponse.success(CreateOrderResponse.from_domain(order))

@router.get("/{order_id}", summary="查询订单")
async def get_order(
    order_id: str,
    service: Annotated[OrderApplicationService, Depends(get_order_service)],
) -> ApiResponse[OrderDetailResponse]:
    order = service.get_order(order_id)
    return ApiResponse.success(OrderDetailResponse.from_domain(order))
```

## 统一响应包装

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
