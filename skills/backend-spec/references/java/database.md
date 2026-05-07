# 📋 数据库与 MyBatis 约束

## 表设计

- 表名使用 snake_case，与领域模型解耦（通过 PO 转换）
- 主键使用 `id`，类型 BIGINT，自增或雪花算法
- 必须包含 `created_time`、`updated_time` 字段
- 逻辑删除字段 `is_deleted`（TINYINT，0/1）
- 字段禁止使用数据库关键字

## SQL 规范

- 禁止 `SELECT *`，明确列出查询字段
- 使用 `#{}` 而非 `${}`，防止 SQL 注入
- WHERE 条件必须走索引，禁止全表扫描
- 禁止在 WHERE 中对索引字段使用函数
- UPDATE 必须带 WHERE 条件，禁止全表更新
- DELETE 操作优先使用逻辑删除

## MyBatis 规范

- 批量操作使用 foreach 批量插入/更新，禁止循环单条操作
- 分页使用 PageHelper 或 MyBatis Plus 分页插件，禁止内存分页
- 复杂查询写 XML 而非注解
- 动态 SQL 使用 `<if>`、`<choose>` 标签，避免拼接

## PO 对象

- 命名：`{实体名}PO`
- 使用 @TableName 映射表名
- 字段与数据库列一一对应
- PO 只用于数据库交互，禁止在 PO 中写业务逻辑
- PO 不能暴露到领域层或应用层

## Mapper 规范

- 命名：`{实体名}Mapper`
- 继承 BaseMapper<PO>（MyBatis Plus）
- 自定义方法入参使用 @Param 注解
- 返回值为 PO 或基本类型，由仓储实现层转换为领域模型

## 仓储实现中的数据转换

- 仓储方法入参：只能是领域模型或关键字段（如 ID）
- 仓储方法返回值：必须是领域模型（禁止返回 PO）
- 仓储实现负责 Domain Model ↔ PO 双向转换
- save 方法内部判断 ID 是否为 null 决定 insert/update
- 查询方法需组装完整聚合根（包含聚合内所有实体）
