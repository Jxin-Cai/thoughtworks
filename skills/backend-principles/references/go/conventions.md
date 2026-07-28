# Go/Gin 约定

本文件仅包含 Go 和 Gin 框架特有的技术约定。架构原则和 DDD 层规则见 `architecture.md`。

## 领域模型定义

| 场景 | 方式 |
|------|------|
| Entity | unexported struct + `New{Name}()` 构造函数 + Getter 方法 |
| Value Object | unexported struct，无 Setter，业务方法返回新对象 |
| Domain Event | exported struct（纯数据） |
| Repository Interface | exported interface（消费方定义，小接口） |

接口由消费方定义（Go 隐式实现），保持 1-3 个方法。

## 结构体与方法

- 导出字段 `PascalCase`，私有字段 `camelCase`
- 优先组合（embedding）而非继承
- 禁止 package 级全局可变变量
- 零值可用设计（struct 零值应有合理默认行为）

## 依赖注入

```go
func NewOrderApplicationService(repo repository.OrderRepository, logger *zap.Logger) *OrderApplicationService {
    if repo == nil {
        panic("repo must not be nil")
    }
    return &OrderApplicationService{repo: repo, logger: logger}
}
```

- 通过构造函数注入，依赖作为 unexported 字段
- 依赖声明为接口类型
- 禁止 `init()` 中做复杂初始化
- 必要依赖做 nil check

## 错误处理

```go
type BusinessError struct {
    Code    string
    Message string
}

func (e *BusinessError) Error() string { return e.Message }
```

- 返回 `(T, error)` 元组，显式处理
- `fmt.Errorf("xxx: %w", err)` 包装错误链
- 禁止吞掉错误 `_ = someFunc()`
- Gin middleware 统一捕获 `BusinessError` 和未知错误

## GORM

- Model 用 `gorm` tag 映射列名
- `TableName()` 方法指定表名
- 链式调用构建查询，禁止拼接 Raw SQL
- `Find` 返回空切片不报错；`First` 无结果返回 `gorm.ErrRecordNotFound`
- 批量用 `CreateInBatches`，禁止循环单条
- 分页：`Offset` + `Limit` + `Count`
- 参数化查询防 SQL 注入

## 数据库迁移

- 使用 `golang-migrate`
- 文件命名：`000001_create_xxx.up.sql` / `000001_create_xxx.down.sql`
- 必须包含 up 和 down
- 禁止 GORM AutoMigrate 管理生产环境
- 建表必含：`id`、`created_time`、`updated_time`、`is_deleted`

## 数据库表设计

- 表名 `snake_case`
- 主键 `id` BIGINT 自增/雪花
- 必备：`created_time`、`updated_time`、`is_deleted`(TINYINT 0/1)
- 禁止数据库关键字做字段名
- WHERE 走索引
- DELETE 优先逻辑删除

## 统一响应

```go
type Response struct {
    Code    int         `json:"code"`
    Message string      `json:"message"`
    Data    interface{} `json:"data,omitempty"`
}

func SuccessResponse(c *gin.Context, data interface{}) {
    c.JSON(http.StatusOK, Response{Code: 0, Message: "ok", Data: data})
}
```

分页：`data: {"list": [...], "total": N, "page_num": 1, "page_size": 20}`

## RESTful API

- URL：小写 kebab-case，资源名词复数
- HTTP 方法：GET/POST/PUT/PATCH/DELETE
- Handler 注册路由：`RegisterRoutes(r *gin.RouterGroup)`
- 错误交由 middleware 统一处理

## 配置

- viper 读取 YAML + 环境变量
- 配置绑定到 struct（`AppConfig`、`DatabaseConfig`）
- 按环境拆分：`config-dev.yaml`、`config-prod.yaml`
- 敏感配置用环境变量

## 日志

- zap 或 zerolog，禁止 `fmt.Println`/`log.Println`
- 结构化字段：`zap.String("key", val)`
- requestId 通过 context 传递贯穿链路

## 并发

- 禁止裸 `go func()` 不处理 panic
- 用 `errgroup` 管理并发任务组
- channel 做 goroutine 间通信
- context 贯穿异步调用

## 测试

| 层 | 策略 |
|---|---|
| Domain | testing + testify/assert |
| Application | testify/mock 或 gomock |
| Infrastructure | SQLite 内存库 / testcontainers |
| OHS | httptest + gin.TestMode |

命名：`Test{功能}_When{条件}_Should{预期}`，表驱动测试覆盖多场景。

## 安全

- 写操作考虑幂等（唯一索引、Token）
- 敏感数据脱敏
- 参数化查询防注入
