# 📋 数据库与 GORM 约束

## 表设计

- 表名使用 snake_case，与领域模型解耦（通过 GORM Model 转换）
- 主键使用 `id`，类型 BIGINT，自增或雪花算法
- 必须包含 `created_time`、`updated_time` 字段
- 逻辑删除字段 `is_deleted`（TINYINT，0/1）
- 字段禁止使用数据库关键字

## SQL 规范

- 禁止 `SELECT *`，使用 GORM 的 `Select()` 明确列出查询字段或通过 Model struct 字段隐式限定
- 使用 GORM 参数化查询，禁止字符串拼接 SQL，防止 SQL 注入
- WHERE 条件必须走索引，禁止全表扫描
- 禁止在 WHERE 中对索引字段使用函数
- UPDATE 必须带 WHERE 条件，禁止全表更新
- DELETE 操作优先使用逻辑删除

## GORM Model

- 命名：`{实体名}Model`
- 使用 `TableName()` 方法显式指定表名
- 字段使用 `gorm` tag 映射数据库列名
- Model 只用于数据库交互，禁止在 Model 中写业务逻辑
- Model 不能暴露到领域层或应用层

示例：

```go
type OrderModel struct {
    ID          int64     `gorm:"column:id;primaryKey;autoIncrement"`
    CustomerID  string    `gorm:"column:customer_id;not null"`
    Status      string    `gorm:"column:status;not null"`
    CreatedTime time.Time `gorm:"column:created_time;autoCreateTime"`
    UpdatedTime time.Time `gorm:"column:updated_time;autoUpdateTime"`
    IsDeleted   int       `gorm:"column:is_deleted;default:0"`
}

func (OrderModel) TableName() string {
    return "t_order"
}

type OrderItemModel struct {
    ID          int64     `gorm:"column:id;primaryKey;autoIncrement"`
    OrderID     int64     `gorm:"column:order_id;not null;index"`
    ProductID   string    `gorm:"column:product_id;not null"`
    Quantity    int       `gorm:"column:quantity;not null"`
    CreatedTime time.Time `gorm:"column:created_time;autoCreateTime"`
    UpdatedTime time.Time `gorm:"column:updated_time;autoUpdateTime"`
    IsDeleted   int       `gorm:"column:is_deleted;default:0"`
}

func (OrderItemModel) TableName() string {
    return "t_order_item"
}
```

## 数据库迁移

- 使用 golang-migrate 管理数据库版本迁移
- 迁移文件按版本号顺序命名：`000001_create_order_table.up.sql` / `000001_create_order_table.down.sql`
- 每次变更必须同时提供 up 和 down 脚本
- 禁止使用 GORM AutoMigrate 管理生产环境表结构
- 迁移 SQL 中建表必须包含 `id`、`created_time`、`updated_time`、`is_deleted` 字段

示例：

```sql
-- 000001_create_order_table.up.sql
CREATE TABLE t_order (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(64)  NOT NULL,
    status      VARCHAR(32)  NOT NULL,
    created_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_time DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_deleted  TINYINT      NOT NULL DEFAULT 0
);

CREATE INDEX idx_order_customer_id ON t_order(customer_id);
```

## GORM 查询规范

- 使用 GORM 链式调用构建查询，禁止拼接 Raw SQL（除非 GORM 无法表达的复杂查询）
- 注意 `Find` 与 `First` 的语义差异：
    - `Find`：查询多条记录，无结果返回空切片（不返回 error）
    - `First`：查询单条记录，无结果返回 `gorm.ErrRecordNotFound`
- 批量操作使用 `CreateInBatches`，禁止循环单条插入
- 分页查询使用 `Offset` + `Limit`，配合 `Count` 获取总数

示例：

```go
// 查询单条 — 使用 First
var model OrderModel
result := db.Where("id = ? AND is_deleted = 0", id).First(&model)
if errors.Is(result.Error, gorm.ErrRecordNotFound) {
    return nil, nil // 不存在返回 nil
}
if result.Error != nil {
    return nil, result.Error
}

// 查询多条 — 使用 Find
var models []OrderItemModel
if err := db.Where("order_id = ? AND is_deleted = 0", orderID).Find(&models).Error; err != nil {
    return nil, err
}

// 分页查询
var total int64
db.Model(&OrderModel{}).Where("is_deleted = 0").Count(&total)

var models []OrderModel
db.Where("is_deleted = 0").Offset(offset).Limit(pageSize).Find(&models)
```

## 仓储实现中的数据转换

- 仓储方法入参：只能是领域模型或关键字段（如 ID）
- 仓储方法返回值：必须是领域模型（禁止返回 GORM Model）
- 仓储实现负责 Domain Model <-> GORM Model 双向转换
- Save 方法使用 GORM 的 `Save`（upsert 语义：有主键则更新，无主键则插入）
- 查询方法需组装完整聚合根（包含聚合内所有实体）

示例：

```go
type OrderRepositoryImpl struct {
    db *gorm.DB
}

func NewOrderRepositoryImpl(db *gorm.DB) *OrderRepositoryImpl {
    return &OrderRepositoryImpl{db: db}
}

func (r *OrderRepositoryImpl) Save(ctx context.Context, order *order) error {
    model := toOrderModel(order)
    if err := r.db.WithContext(ctx).Save(&model).Error; err != nil {
        return err
    }

    // 保存订单项：先删后插保证聚合一致性
    if err := r.db.WithContext(ctx).
        Where("order_id = ?", model.ID).
        Delete(&OrderItemModel{}).Error; err != nil {
        return err
    }

    itemModels := toOrderItemModels(order.Items(), model.ID)
    if len(itemModels) > 0 {
        if err := r.db.WithContext(ctx).CreateInBatches(&itemModels, 100).Error; err != nil {
            return err
        }
    }

    return nil
}

func (r *OrderRepositoryImpl) FindByID(ctx context.Context, id OrderID) (*order, error) {
    var model OrderModel
    result := r.db.WithContext(ctx).
        Where("id = ? AND is_deleted = 0", id.Value()).
        First(&model)
    if errors.Is(result.Error, gorm.ErrRecordNotFound) {
        return nil, nil
    }
    if result.Error != nil {
        return nil, result.Error
    }

    var itemModels []OrderItemModel
    if err := r.db.WithContext(ctx).
        Where("order_id = ? AND is_deleted = 0", model.ID).
        Find(&itemModels).Error; err != nil {
        return nil, err
    }

    return toDomainOrder(model, itemModels), nil
}
```
