# 📋 Domain 层（领域层）约束

## 路径结构

- `domain/{子域名}/model/` — Entity、Value Object、Aggregate Root
- `domain/{子域名}/repository/` — Repository Interface（仓储接口，按聚合根划分）
- `domain/{子域名}/event/` — Domain Event Publishing Interface（事件发布接口，按聚合划分）
- `domain/{子域名}/acl/{外部领域名}/` — Anti-Corruption Layer Interface（防腐层接口，按外部领域划分）
- `domain/{子域名}/service/` — Domain Service
- `domain/{子域名}/lib/` — 领域内通用工具函数（如格式化、校验辅助等纯函数工具）

## 允许

- 定义实体、值对象、聚合根，并在其中实现业务规则
- 定义领域服务处理跨聚合的业务逻辑
- 定义仓储接口（只定义，不实现）
- 定义领域事件发布接口（只定义，不实现）
- 定义防腐层接口（只定义，不实现）
- 发布领域事件

## 禁止

- 依赖任何其他层（Application、Infrastructure、OHS）
- 使用框架注解或注册机制管理领域对象生命周期
- 包含技术细节（数据库访问、HTTP 调用、缓存操作、消息队列）
- 直接持久化数据
- 记录日志（日志属于应用层职责）
- import 任何 `infr`、`ohs`、`application` 包

## 充血模型与面向对象

- 实体必须包含业务方法，禁止贫血模型（只有导出字段、无行为）
- 使用 unexported struct + exported 构造函数 `New{Name}()` 控制创建入口
- 使用 unexported 字段保护不变性，通过业务方法修改状态，提供必要的 Getter 方法
- 值对象：所有字段 unexported，无 setter 方法，业务方法返回新对象，创建后不可变
- 遵循 SOLID 原则（Go 的接口隐式实现天然支持依赖倒置和接口隔离）
- 识别并规避代码坏味道：重复代码、过长函数、过大结构体、过长参数列表、发散式变化、霰弹式修改
- 遵循 Go 惯用实践：小接口、显式错误处理、组合优于继承、零值可用

示例：

```go
// order.go — 聚合根
type order struct {
    id         OrderID
    customerID CustomerID
    status     OrderStatus
    items      []OrderItem
    createdAt  time.Time
}

// NewOrder 创建订单聚合根，校验必要参数。
func NewOrder(id OrderID, customerID CustomerID) (*order, error) {
    if id.IsEmpty() {
        return nil, NewBusinessError(400, "order id must not be empty")
    }
    return &order{
        id:         id,
        customerID: customerID,
        status:     OrderStatusCreated,
        items:      make([]OrderItem, 0),
        createdAt:  time.Now(),
    }, nil
}

func (o *order) ID() OrderID           { return o.id }
func (o *order) Status() OrderStatus   { return o.status }
func (o *order) Items() []OrderItem    { return append([]OrderItem{}, o.items...) }

// AddItem 添加订单项，执行库存充足性校验。
func (o *order) AddItem(productID ProductID, quantity int) error {
    if quantity <= 0 {
        return NewBusinessError(400, "quantity must be positive")
    }
    o.items = append(o.items, NewOrderItem(productID, quantity))
    return nil
}

// Cancel 取消订单，仅允许从已创建状态取消。
func (o *order) Cancel() error {
    if o.status != OrderStatusCreated {
        return NewBusinessError(400, "only created order can be cancelled")
    }
    o.status = OrderStatusCancelled
    return nil
}
```

## 仓储接口规范（repository/）

一个仓储目录下按聚合根划分，每个聚合根对应一个 Repository 接口。

- 入参：只能是领域模型或关键字段（如 ID）
- 返回值：必须是领域模型或 `(领域模型, error)`，不存在时返回 `nil, nil`（约定语义）或自定义 NotFoundError
- 使用集合语义（Save/Remove），而非数据库语义（Insert/Delete）
- 禁止入参或返回值使用 GORM Model、DTO
- 所有方法第一个参数为 `context.Context`
- 每个方法必须用注释描述实现逻辑的预期行为，包括：做什么、关键约束、异常场景

示例：

```go
// OrderRepository 订单聚合根仓储接口。
type OrderRepository interface {

    // Save 保存订单聚合根。
    // 若订单不存在则新增，若已存在则更新全部字段及其关联的订单项。
    // 保存时需同步持久化订单项集合，保证聚合一致性。
    Save(ctx context.Context, order *order) error

    // FindByID 根据订单ID查询订单聚合根。
    // 需同时加载订单项集合，返回完整的聚合。
    // 若订单不存在返回 nil, nil。
    FindByID(ctx context.Context, id OrderID) (*order, error)

    // Remove 移除订单聚合根。
    // 需级联移除关联的订单项。
    // 若订单不存在则静默忽略。
    Remove(ctx context.Context, id OrderID) error
}
```

## 事件发布接口规范（event/）

一个事件目录下按聚合划分，每个聚合对应一个 EventPublisher 接口。

- 入参：只能是领域事件对象
- 所有方法第一个参数为 `context.Context`
- 每个方法必须用注释描述事件的业务含义、触发时机、消费方预期行为

示例：

```go
// OrderEventPublisher 订单聚合事件发布接口。
type OrderEventPublisher interface {

    // PublishOrderCreated 发布订单已创建事件。
    // 在订单聚合根完成创建并持久化后调用。
    // 消费方预期：库存服务扣减库存，通知服务发送下单确认。
    PublishOrderCreated(ctx context.Context, event OrderCreatedEvent) error

    // PublishOrderCancelled 发布订单已取消事件。
    // 在订单状态变更为已取消并持久化后调用。
    // 消费方预期：库存服务释放库存，支付服务发起退款。
    PublishOrderCancelled(ctx context.Context, event OrderCancelledEvent) error
}
```

## 防腐层接口规范（acl/{外部领域名}/）

按外部领域划分目录，每个外部领域对应一个 ACL 接口，隔离外部领域概念对本领域的侵入。

- 入参和返回值：只能使用本领域的模型或基本类型，禁止引入外部领域的类型
- 所有方法第一个参数为 `context.Context`
- 每个方法必须用注释描述：调用外部领域的什么能力、期望的行为、失败时的处理策略

示例：

```go
// InventoryAclService 库存领域防腐层。
// 隔离库存领域的概念，将其转换为订单领域可理解的接口。
type InventoryAclService interface {

    // CheckStock 检查商品是否有足够库存。
    // 调用库存领域查询指定商品的可用库存数量，与请求数量比较。
    // 若库存服务不可用，应返回 error 而非默认返回 true。
    CheckStock(ctx context.Context, productID ProductID, quantity int) (bool, error)

    // ReserveStock 预扣库存。
    // 调用库存领域对指定商品执行预扣操作，返回预扣凭证。
    // 预扣失败（库存不足或服务异常）应返回 error。
    ReserveStock(ctx context.Context, productID ProductID, quantity int) (string, error)
}
```

## 命名

- 聚合根/实体：`{业务概念名}`（无后缀，PascalCase 导出构造函数，unexported struct）
- 值对象：`{业务概念名}`（无后缀）
- 领域服务：`{业务名}{动作}Service`
- 仓储接口：`{聚合根名}Repository`
- 领域事件：`{聚合根名}{动作过去式}Event`
- 事件发布接口：`{聚合根名}EventPublisher`
- 防腐层接口：`{外部领域名}AclService`

## 依赖方向

- 可依赖：无
- 禁止依赖：所有其他层（Application、Infrastructure、OHS）
