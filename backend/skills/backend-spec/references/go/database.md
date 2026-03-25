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

## 数据库迁移

- 使用 golang-migrate 管理数据库版本迁移
- 迁移文件按版本号顺序命名：`000001_create_order_table.up.sql` / `000001_create_order_table.down.sql`
- 每次变更必须同时提供 up 和 down 脚本
- 禁止使用 GORM AutoMigrate 管理生产环境表结构
- 迁移 SQL 中建表必须包含 `id`、`created_time`、`updated_time`、`is_deleted` 字段

## GORM 查询规范

- 使用 GORM 链式调用构建查询，禁止拼接 Raw SQL（除非 GORM 无法表达的复杂查询）
- 注意 `Find` 与 `First` 的语义差异：
    - `Find`：查询多条记录，无结果返回空切片（不返回 error）
    - `First`：查询单条记录，无结果返回 `gorm.ErrRecordNotFound`
- 批量操作使用 `CreateInBatches`，禁止循环单条插入
- 分页查询使用 `Offset` + `Limit`，配合 `Count` 获取总数

## 仓储实现中的数据转换

- 仓储方法入参：只能是领域模型或关键字段（如 ID）
- 仓储方法返回值：必须是领域模型（禁止返回 GORM Model）
- 仓储实现负责 Domain Model <-> GORM Model 双向转换
- Save 方法使用 GORM 的 `Save`（upsert 语义：有主键则更新，无主键则插入）
- 查询方法需组装完整聚合根（包含聚合内所有实体）
