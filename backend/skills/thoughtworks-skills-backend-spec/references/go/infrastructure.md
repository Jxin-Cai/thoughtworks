# 📋 Infrastructure 层（基础设施层）约束

## 路径结构

- `infr/repository/` — 仓储实现、GORM Model
- `infr/middleware/` — Gin 中间件（日志、认证、错误处理、限流等）
- `infr/client/` — 外部系统集成（HTTP Client、gRPC Client）

## 允许

- 实现领域层定义的 Repository 接口
- 领域对象与 GORM Model 的双向转换
- 数据库访问（GORM）、所有增删改查操作
- 外部系统集成、中间件编写、缓存管理
- Gin 中间件开发

## 全局异常处理（Middleware）

Infrastructure 层必须实现全局错误处理 Gin middleware，拦截 handler 链中产生的错误做兜底处理：

- 使用 Gin middleware 实现全局错误处理器，放在 `infr/middleware/` 目录下
- 使用 `gin.CustomRecovery` 或自定义 Recovery middleware 捕获 panic
- 自定义错误处理中间件从 `c.Errors` 中提取错误，按类型分发：
    - 捕获 `*BusinessError` 返回业务错误码和消息
    - 捕获 `validator.ValidationErrors` 等校验错误，返回参数校验错误信息
    - 捕获未知 error 作为兜底，返回统一的系统错误响应，并记录完整堆栈日志
- **其他层（Application、OHS）禁止用 recover 或错误吞没做异常兜底**，错误自然返回由此 middleware 统一处理

示例：

```go
// ErrorHandlerMiddleware 全局错误处理中间件。
func ErrorHandlerMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Next()

        if len(c.Errors) == 0 {
            return
        }

        err := c.Errors.Last().Err
        var bizErr *BusinessError
        if errors.As(err, &bizErr) {
            c.JSON(http.StatusOK, Response{
                Code:    bizErr.Code,
                Message: bizErr.Message,
                Data:    nil,
            })
            return
        }

        // 未知错误兜底
        logger.Error("unexpected error", zap.Error(err))
        c.JSON(http.StatusInternalServerError, Response{
            Code:    500,
            Message: "internal server error",
            Data:    nil,
        })
    }
}
```

## 禁止

- 包含任何业务逻辑
- 修改聚合根的业务状态（业务状态变更属于领域层）
- 在仓储方法中进行业务规则校验
- 依赖 OHS 层或 Application 层

## 命名

- 仓储实现：`{聚合根名}RepositoryImpl`
- GORM Model：`{实体名}Model`
- Client：`{外部系统名}Client`

## 依赖方向

- 可依赖：Domain 层（实现其接口）、OHS 层（写 middleware）、Application 层（写 middleware）
