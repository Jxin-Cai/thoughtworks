# Go 垂直切片参考实现

以下是一个"订单"子域从 Domain 到 OHS 的完整实现示例（Gin + GORM）。

---

## Domain 层

### Entity — `domain/order/model/order.go`

```go
package model

import (
	"errors"
	"time"
)

type OrderStatus string

const (
	OrderStatusCreated   OrderStatus = "CREATED"
	OrderStatusConfirmed OrderStatus = "CONFIRMED"
	OrderStatusCompleted OrderStatus = "COMPLETED"
	OrderStatusCancelled OrderStatus = "CANCELLED"
)

type Order struct {
	id          int64
	orderNumber string
	customerID  int64
	status      OrderStatus
	items       []OrderItem
	createdTime time.Time
}

func NewOrder(orderNumber string, customerID int64, items []OrderItem) (*Order, error) {
	if len(items) == 0 {
		return nil, errors.New("order must have at least one item")
	}
	return &Order{
		orderNumber: orderNumber,
		customerID:  customerID,
		status:      OrderStatusCreated,
		items:       items,
		createdTime: time.Now(),
	}, nil
}

// Reconstitute 从持久化数据重建领域对象（仅供 Repository 使用）
func Reconstitute(id int64, orderNumber string, customerID int64,
	status OrderStatus, items []OrderItem, createdTime time.Time) *Order {
	return &Order{
		id:          id,
		orderNumber: orderNumber,
		customerID:  customerID,
		status:      status,
		items:       items,
		createdTime: createdTime,
	}
}

func (o *Order) Confirm() error {
	if o.status != OrderStatusCreated {
		return errors.New("only CREATED order can be confirmed")
	}
	o.status = OrderStatusConfirmed
	return nil
}

func (o *Order) Cancel(reason string) error {
	if o.status == OrderStatusCompleted {
		return errors.New("completed order cannot be cancelled")
	}
	o.status = OrderStatusCancelled
	return nil
}

func (o *Order) TotalAmount() int64 {
	var total int64
	for _, item := range o.items {
		total += item.Subtotal()
	}
	return total
}

func (o *Order) ID() int64            { return o.id }
func (o *Order) OrderNumber() string   { return o.orderNumber }
func (o *Order) CustomerID() int64     { return o.customerID }
func (o *Order) Status() OrderStatus   { return o.status }
func (o *Order) Items() []OrderItem    { return o.items }
func (o *Order) CreatedTime() time.Time { return o.createdTime }
func (o *Order) SetID(id int64)        { o.id = id }
```

### Value Object — `domain/order/model/order_item.go`

```go
package model

import "errors"

type OrderItem struct {
	productID   int64
	productName string
	quantity    int
	unitPrice   int64 // 分为单位
}

func NewOrderItem(productID int64, productName string, quantity int, unitPrice int64) (*OrderItem, error) {
	if quantity <= 0 {
		return nil, errors.New("quantity must be positive")
	}
	if unitPrice <= 0 {
		return nil, errors.New("unit price must be positive")
	}
	return &OrderItem{
		productID:   productID,
		productName: productName,
		quantity:    quantity,
		unitPrice:   unitPrice,
	}, nil
}

func (i *OrderItem) Subtotal() int64 {
	return i.unitPrice * int64(i.quantity)
}

func (i *OrderItem) ProductID() int64    { return i.productID }
func (i *OrderItem) ProductName() string { return i.productName }
func (i *OrderItem) Quantity() int       { return i.quantity }
func (i *OrderItem) UnitPrice() int64    { return i.unitPrice }
```

### Repository Interface — `domain/order/repository/order_repository.go`

```go
package repository

import (
	"context"
	"example.com/domain/order/model"
)

// OrderRepository 订单聚合根仓储接口
type OrderRepository interface {
	// Save 持久化订单。ID 为 0 时新建，非 0 时更新。级联持久化 OrderItem。
	Save(ctx context.Context, order *model.Order) error

	// FindByID 按 ID 加载完整订单聚合（含全部 OrderItem）。不存在时返回 nil, nil。
	FindByID(ctx context.Context, id int64) (*model.Order, error)

	// FindByOrderNumber 按订单号查找。订单号具有唯一性约束。
	FindByOrderNumber(ctx context.Context, orderNumber string) (*model.Order, error)

	// Remove 移除订单（逻辑删除）。
	Remove(ctx context.Context, order *model.Order) error
}
```

---

## Infrastructure 层

### GORM Model — `infr/repository/order/order_model.go`

```go
package order

import "time"

type OrderModel struct {
	ID          int64     `gorm:"column:id;primaryKey;autoIncrement"`
	OrderNumber string    `gorm:"column:order_number;uniqueIndex;not null"`
	CustomerID  int64     `gorm:"column:customer_id;not null"`
	Status      string    `gorm:"column:status;not null"`
	TotalAmount int64     `gorm:"column:total_amount;not null"`
	CreatedTime time.Time `gorm:"column:created_time;autoCreateTime"`
	UpdatedTime time.Time `gorm:"column:updated_time;autoUpdateTime"`
	IsDeleted   int       `gorm:"column:is_deleted;default:0"`
}

func (OrderModel) TableName() string { return "t_order" }
```

### RepositoryImpl — `infr/repository/order/order_repository_impl.go`

```go
package order

import (
	"context"
	"example.com/domain/order/model"
	"gorm.io/gorm"
)

type OrderRepositoryImpl struct {
	db *gorm.DB
}

func NewOrderRepositoryImpl(db *gorm.DB) *OrderRepositoryImpl {
	if db == nil {
		panic("db must not be nil")
	}
	return &OrderRepositoryImpl{db: db}
}

func (r *OrderRepositoryImpl) Save(ctx context.Context, order *model.Order) error {
	po := r.toModel(order)
	if order.ID() == 0 {
		if err := r.db.WithContext(ctx).Create(po).Error; err != nil {
			return err
		}
		order.SetID(po.ID)
	} else {
		po.ID = order.ID()
		if err := r.db.WithContext(ctx).Save(po).Error; err != nil {
			return err
		}
	}
	return r.saveItems(ctx, order.ID(), order.Items())
}

func (r *OrderRepositoryImpl) FindByID(ctx context.Context, id int64) (*model.Order, error) {
	var po OrderModel
	err := r.db.WithContext(ctx).Where("id = ? AND is_deleted = 0", id).First(&po).Error
	if err == gorm.ErrRecordNotFound {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var itemPOs []OrderItemModel
	if err := r.db.WithContext(ctx).Where("order_id = ?", id).Find(&itemPOs).Error; err != nil {
		return nil, err
	}
	return r.toDomain(&po, itemPOs), nil
}

func (r *OrderRepositoryImpl) FindByOrderNumber(ctx context.Context, orderNumber string) (*model.Order, error) {
	var po OrderModel
	err := r.db.WithContext(ctx).Where("order_number = ? AND is_deleted = 0", orderNumber).First(&po).Error
	if err == gorm.ErrRecordNotFound {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var itemPOs []OrderItemModel
	if err := r.db.WithContext(ctx).Where("order_id = ?", po.ID).Find(&itemPOs).Error; err != nil {
		return nil, err
	}
	return r.toDomain(&po, itemPOs), nil
}

func (r *OrderRepositoryImpl) Remove(ctx context.Context, order *model.Order) error {
	return r.db.WithContext(ctx).Model(&OrderModel{}).
		Where("id = ?", order.ID()).
		Update("is_deleted", 1).Error
}

func (r *OrderRepositoryImpl) toModel(order *model.Order) *OrderModel {
	return &OrderModel{
		OrderNumber: order.OrderNumber(),
		CustomerID:  order.CustomerID(),
		Status:      string(order.Status()),
		TotalAmount: order.TotalAmount(),
	}
}

func (r *OrderRepositoryImpl) toDomain(po *OrderModel, itemPOs []OrderItemModel) *model.Order {
	items := make([]model.OrderItem, 0, len(itemPOs))
	for _, ip := range itemPOs {
		item, _ := model.NewOrderItem(ip.ProductID, ip.ProductName, ip.Quantity, ip.UnitPrice)
		items = append(items, *item)
	}
	return model.Reconstitute(po.ID, po.OrderNumber, po.CustomerID,
		model.OrderStatus(po.Status), items, po.CreatedTime)
}

func (r *OrderRepositoryImpl) saveItems(ctx context.Context, orderID int64, items []model.OrderItem) error {
	r.db.WithContext(ctx).Where("order_id = ?", orderID).Delete(&OrderItemModel{})
	for _, item := range items {
		itemPO := &OrderItemModel{
			OrderID:     orderID,
			ProductID:   item.ProductID(),
			ProductName: item.ProductName(),
			Quantity:    item.Quantity(),
			UnitPrice:   item.UnitPrice(),
		}
		if err := r.db.WithContext(ctx).Create(itemPO).Error; err != nil {
			return err
		}
	}
	return nil
}
```

---

## Application 层

### Command — `application/order/command.go`

```go
package order

type CreateOrderCommand struct {
	CustomerID int64
	Items      []OrderItemInput
}

type OrderItemInput struct {
	ProductID   int64
	ProductName string
	Quantity    int
	UnitPrice   int64
}
```

### ApplicationService — `application/order/order_application_service.go`

```go
package order

import (
	"context"
	"example.com/domain/order/model"
	"example.com/domain/order/repository"
	"go.uber.org/zap"
)

type OrderApplicationService struct {
	orderRepo    repository.OrderRepository
	numberGen    OrderNumberGenerator
	logger       *zap.Logger
}

func NewOrderApplicationService(
	orderRepo repository.OrderRepository,
	numberGen OrderNumberGenerator,
	logger *zap.Logger,
) *OrderApplicationService {
	if orderRepo == nil {
		panic("orderRepo must not be nil")
	}
	return &OrderApplicationService{
		orderRepo: orderRepo,
		numberGen: numberGen,
		logger:    logger,
	}
}

func (s *OrderApplicationService) CreateOrder(ctx context.Context, cmd CreateOrderCommand) (*model.Order, error) {
	s.logger.Info("Creating order", zap.Int64("customerID", cmd.CustomerID))

	items := make([]model.OrderItem, 0, len(cmd.Items))
	for _, i := range cmd.Items {
		item, err := model.NewOrderItem(i.ProductID, i.ProductName, i.Quantity, i.UnitPrice)
		if err != nil {
			return nil, err
		}
		items = append(items, *item)
	}

	orderNumber := s.numberGen.Generate()
	order, err := model.NewOrder(orderNumber, cmd.CustomerID, items)
	if err != nil {
		return nil, err
	}

	if err := s.orderRepo.Save(ctx, order); err != nil {
		return nil, err
	}

	s.logger.Info("Order created", zap.String("orderNumber", order.OrderNumber()))
	return order, nil
}

func (s *OrderApplicationService) ConfirmOrder(ctx context.Context, orderID int64) (*model.Order, error) {
	order, err := s.orderRepo.FindByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if order == nil {
		return nil, NewBusinessError("ORDER_NOT_FOUND", "order not found")
	}
	if err := order.Confirm(); err != nil {
		return nil, err
	}
	if err := s.orderRepo.Save(ctx, order); err != nil {
		return nil, err
	}
	return order, nil
}

func (s *OrderApplicationService) GetOrder(ctx context.Context, orderID int64) (*model.Order, error) {
	order, err := s.orderRepo.FindByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if order == nil {
		return nil, NewBusinessError("ORDER_NOT_FOUND", "order not found")
	}
	return order, nil
}
```

---

## OHS 层

### Request/Response DTO — `ohs/http/order/dto.go`

```go
package order

type CreateOrderRequest struct {
	CustomerID int64              `json:"customer_id" binding:"required"`
	Items      []OrderItemRequest `json:"items" binding:"required,min=1,dive"`
}

type OrderItemRequest struct {
	ProductID   int64  `json:"product_id" binding:"required"`
	ProductName string `json:"product_name" binding:"required"`
	Quantity    int    `json:"quantity" binding:"required,min=1"`
	UnitPrice   int64  `json:"unit_price" binding:"required,min=1"`
}

type OrderResponse struct {
	ID          int64               `json:"id"`
	OrderNumber string              `json:"order_number"`
	CustomerID  int64               `json:"customer_id"`
	Status      string              `json:"status"`
	TotalAmount int64               `json:"total_amount"`
	Items       []OrderItemResponse `json:"items"`
	CreatedTime string              `json:"created_time"`
}

type OrderItemResponse struct {
	ProductID   int64  `json:"product_id"`
	ProductName string `json:"product_name"`
	Quantity    int    `json:"quantity"`
	UnitPrice   int64  `json:"unit_price"`
	Subtotal    int64  `json:"subtotal"`
}
```

### Controller — `ohs/http/order/order_handler.go`

```go
package order

import (
	"net/http"
	"strconv"

	appOrder "example.com/application/order"
	"example.com/ohs/http/common"
	"github.com/gin-gonic/gin"
)

type OrderHandler struct {
	orderService *appOrder.OrderApplicationService
}

func NewOrderHandler(orderService *appOrder.OrderApplicationService) *OrderHandler {
	return &OrderHandler{orderService: orderService}
}

func (h *OrderHandler) RegisterRoutes(r *gin.RouterGroup) {
	orders := r.Group("/orders")
	orders.POST("", h.CreateOrder)
	orders.POST("/:id/confirm", h.ConfirmOrder)
	orders.GET("/:id", h.GetOrder)
}

func (h *OrderHandler) CreateOrder(c *gin.Context) {
	var req CreateOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		common.ErrorResponse(c, http.StatusBadRequest, "INVALID_PARAMS", err.Error())
		return
	}

	cmd := appOrder.CreateOrderCommand{
		CustomerID: req.CustomerID,
		Items: func() []appOrder.OrderItemInput {
			items := make([]appOrder.OrderItemInput, len(req.Items))
			for i, item := range req.Items {
				items[i] = appOrder.OrderItemInput{
					ProductID:   item.ProductID,
					ProductName: item.ProductName,
					Quantity:    item.Quantity,
					UnitPrice:   item.UnitPrice,
				}
			}
			return items
		}(),
	}

	order, err := h.orderService.CreateOrder(c.Request.Context(), cmd)
	if err != nil {
		common.HandleError(c, err)
		return
	}
	common.SuccessResponse(c, toResponse(order))
}

func (h *OrderHandler) ConfirmOrder(c *gin.Context) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	order, err := h.orderService.ConfirmOrder(c.Request.Context(), id)
	if err != nil {
		common.HandleError(c, err)
		return
	}
	common.SuccessResponse(c, toResponse(order))
}

func (h *OrderHandler) GetOrder(c *gin.Context) {
	id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
	order, err := h.orderService.GetOrder(c.Request.Context(), id)
	if err != nil {
		common.HandleError(c, err)
		return
	}
	common.SuccessResponse(c, toResponse(order))
}

func toResponse(order *model.Order) OrderResponse {
	items := make([]OrderItemResponse, len(order.Items()))
	for i, item := range order.Items() {
		items[i] = OrderItemResponse{
			ProductID:   item.ProductID(),
			ProductName: item.ProductName(),
			Quantity:    item.Quantity(),
			UnitPrice:   item.UnitPrice(),
			Subtotal:    item.Subtotal(),
		}
	}
	return OrderResponse{
		ID:          order.ID(),
		OrderNumber: order.OrderNumber(),
		CustomerID:  order.CustomerID(),
		Status:      string(order.Status()),
		TotalAmount: order.TotalAmount(),
		Items:       items,
		CreatedTime: order.CreatedTime().Format("2006-01-02T15:04:05Z07:00"),
	}
}
```

---

## 模式要点总结

| 模式 | Go 体现 |
|------|---------|
| Unexported struct + 构造函数 | `type Order struct` (unexported fields) + `NewOrder()` |
| 不变量保护 | 构造函数中校验，返回 error |
| 值对象不可变 | unexported 字段，只有 Getter，无 Setter |
| 集合语义仓储 | `Save`/`Remove`，interface 定义 |
| Context 贯穿 | 所有 Repository 和 Service 方法第一参数 `context.Context` |
| 显式错误处理 | 返回 `(*T, error)` 元组 |
| 构造函数 nil check | `if db == nil { panic(...) }` |
| GORM Model 隔离 | Model 仅在 RepositoryImpl 内部 |
| Handler 注册路由 | `RegisterRoutes(r *gin.RouterGroup)` |
| 统一错误处理 | `common.HandleError(c, err)` 分派到 middleware |
