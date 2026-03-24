# 📋 Application 层（应用层）约束

## 允许

- 编排多个 Domain Service / Repository 完成业务用例
- 管理事务边界（`db.Transaction(func(tx *gorm.DB) error { ... })`）
- 协调多个聚合根之间的交互
- 调用基础设施层（事件发布、缓存、消息等）
- 记录入参出参日志（Info 级别）

## 禁止

- 包含业务规则（业务规则属于领域层）
- 包含复杂计算逻辑
- 直接操作数据库（必须通过 Repository）
- 依赖 OHS 层
- 定义 DTO 类型（返回类型使用领域层模型，DTO 封装由 OHS 层负责）
- 用 recover 做错误兜底（错误自然返回，由 Infrastructure 层全局错误处理 middleware 统一拦截）

## 核心原则

- 薄薄一层，只做编排不做计算
- 一个公有方法对应一个业务用例

## 事务管理

- 通过 `db.Transaction(func(tx *gorm.DB) error { ... })` 管理事务边界
- 事务仅在应用层使用，禁止在 handler、领域服务、仓储实现中开启事务
- 查询方法无需事务包装
- 事务方法内不做 RPC 调用、消息发送等耗时 I/O（避免大事务）
- Repository 接口可接受 `context.Context` 传递事务上下文，或通过构造函数注入 `*gorm.DB` 在事务中替换

示例：

```go
func (s *OrderApplicationService) CreateOrder(ctx context.Context, cmd CreateOrderCommand) error {
    return s.db.Transaction(func(tx *gorm.DB) error {
        // 使用事务内的 repository
        orderRepo := s.orderRepoFactory(tx)

        order, err := domain.NewOrder(domain.NewOrderID(), cmd.CustomerID)
        if err != nil {
            return err
        }

        for _, item := range cmd.Items {
            if err := order.AddItem(item.ProductID, item.Quantity); err != nil {
                return err
            }
        }

        return orderRepo.Save(ctx, order)
    })
}
```

## Command 对象

- Command 是纯数据结构（struct），承载业务用例的输入参数
- 禁止在 Command 中包含业务逻辑
- Command 创建后不可变（所有字段 exported，不提供修改方法）

示例：

```go
type CreateOrderCommand struct {
    CustomerID string
    Items      []CreateOrderItemCommand
}

type CreateOrderItemCommand struct {
    ProductID string
    Quantity  int
}
```

## 命名

- 应用服务：`{业务名}ApplicationService`
- Command 对象：`{操作名}Command`

## 依赖方向

- 可依赖：Domain 层
- 禁止依赖：OHS 层、Infrastructure 层
