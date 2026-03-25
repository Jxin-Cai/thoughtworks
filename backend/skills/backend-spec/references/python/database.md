# 📋 数据库与 SQLAlchemy 约束

## 表设计

- 表名使用 snake_case，与领域模型解耦（通过 ORM Model 转换）
- 主键使用 `id`，类型 BIGINT（或 UUID），自增或雪花算法
- 必须包含 `created_time`、`updated_time` 字段
- 逻辑删除字段 `is_deleted`（INTEGER，0/1）
- 字段禁止使用数据库关键字

## SQL 规范

- 禁止 `SELECT *`，使用 `select(Model.field1, Model.field2)` 明确列出查询字段（全量加载聚合根场景除外）
- 使用 SQLAlchemy 参数绑定，禁止字符串拼接 SQL，防止 SQL 注入
- WHERE 条件必须走索引，禁止全表扫描
- 禁止在 WHERE 中对索引字段使用函数
- UPDATE 必须带 WHERE 条件，禁止全表更新
- DELETE 操作优先使用逻辑删除

## SQLAlchemy ORM 规范

- 使用 SQLAlchemy 2.0 风格（`select()` 语句），禁止 1.x 旧式 `session.query()` 写法
- 批量操作使用 `session.execute(insert(Model).values([...]))` 或 `session.add_all()`，禁止循环单条操作
- 分页使用 `select(...).offset(...).limit(...)` + `select(func.count(...))` 查询总数
- 复杂查询使用 SQLAlchemy Core `select()` 构建，保持可读性

## ORM Model

- 命名：`{实体名}Model`
- 使用 `DeclarativeBase` 或 `MappedAsDataclass` 基类
- 表名通过 `__tablename__` 属性指定（snake_case）
- 字段与数据库列一一对应，使用 `Mapped[T]` + `mapped_column()` 类型注解
- ORM Model 只用于数据库交互，禁止在 ORM Model 中写业务逻辑
- ORM Model 不能暴露到领域层或应用层

## Alembic 迁移规范

- 使用 Alembic 管理数据库迁移，禁止手动执行 DDL
- 每次模型变更生成迁移脚本：`alembic revision --autogenerate -m "描述"`
- 迁移脚本必须包含 `upgrade()` 和 `downgrade()` 函数
- 迁移文件提交到版本控制，与代码变更同步
- 生产环境迁移前在测试环境验证

## 仓储实现中的数据转换

- 仓储方法入参：只能是领域模型或关键字段（如 ID）
- 仓储方法返回值：必须是领域模型（禁止返回 ORM Model）
- 仓储实现负责 Domain Model <-> ORM Model 双向转换
- `save` 方法使用 `session.merge()` 语义（存在则更新，不存在则新增）
- 查询方法需组装完整聚合根（包含聚合内所有实体）
