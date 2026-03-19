# 📋 OHS 层（开放主机层）约束

## 路径结构

- `ohs/http/` — HTTP 端点（REST API，Gin handler）
- `ohs/rpc/` — RPC 端点（gRPC 等）

## 允许

- Handler 函数、Request/Response struct、Converter 函数、RPC Service
- 接收请求、参数校验（struct binding tag）
- Request struct 与 Command 对象的转换
- 调用 ApplicationService
- 通过 `c.Error(err)` 将错误传递给全局错误处理中间件

## RESTful API 规范

- URL 使用小写 kebab-case，资源名词复数：`/api/quote-items/:id`
- 标准 HTTP 方法：GET（查询）/ POST（创建）/ PUT（全量更新）/ PATCH（部分更新）/ DELETE（删除）
- 所有接口返回统一包装结构：`{"code": 0, "message": "ok", "data": ...}`
- 分页查询返回：`{"code": 0, "message": "ok", "data": {"list": [], "total": 100, "pageNum": 1, "pageSize": 10}}`
- Handler 不写 recover，交由 Infrastructure 层全局错误处理中间件兜底

### 参数校验

- 使用 struct binding tag 做参数校验：`binding:"required"`、`binding:"min=1,max=100"`、`binding:"email"`
- 路径参数通过 `c.Param("id")` 获取并校验
- 校验失败由 `c.ShouldBindJSON()` 返回的 error 传递到全局错误处理中间件

示例：

```go
type CreateOrderRequest struct {
    CustomerID string                   `json:"customerId" binding:"required"`
    Items      []CreateOrderItemRequest `json:"items" binding:"required,min=1,dive"`
}

type CreateOrderItemRequest struct {
    ProductID string `json:"productId" binding:"required"`
    Quantity  int    `json:"quantity" binding:"required,min=1,max=9999"`
}
```

### 统一响应结构

```go
type Response struct {
    Code    int         `json:"code"`
    Message string      `json:"message"`
    Data    interface{} `json:"data"`
}

type PageResponse struct {
    List     interface{} `json:"list"`
    Total    int64       `json:"total"`
    PageNum  int         `json:"pageNum"`
    PageSize int         `json:"pageSize"`
}

func OK(c *gin.Context, data interface{}) {
    c.JSON(http.StatusOK, Response{Code: 0, Message: "ok", Data: data})
}

func OKPage(c *gin.Context, list interface{}, total int64, pageNum, pageSize int) {
    c.JSON(http.StatusOK, Response{
        Code:    0,
        Message: "ok",
        Data: PageResponse{
            List:     list,
            Total:    total,
            PageNum:  pageNum,
            PageSize: pageSize,
        },
    })
}
```

### Handler 示例

```go
func (h *OrderHandler) CreateOrder(c *gin.Context) {
    var req CreateOrderRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        _ = c.Error(err)
        return
    }

    cmd := CreateOrderCommand{
        CustomerID: req.CustomerID,
        Items:      convertToCommandItems(req.Items),
    }

    if err := h.orderAppService.CreateOrder(c.Request.Context(), cmd); err != nil {
        _ = c.Error(err)
        return
    }

    OK(c, nil)
}
```

## 禁止

- 包含任何业务逻辑或业务规则判断
- 直接调用 Domain Service 或 Repository
- 直接操作数据库
- 直接依赖领域层（必须通过应用层中转）

## 命名

- Handler：`{业务名}Handler`
- Request struct：`{操作名}Request`
- Response struct：`{操作名}Response`
- RPC 服务：`{业务名}GrpcService`

## 依赖方向

- 可依赖：Application 层
- 禁止依赖：Domain 层、Infrastructure 层
