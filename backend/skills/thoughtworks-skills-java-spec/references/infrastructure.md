# 📋 Infrastructure 层（基础设施层）约束

## 路径结构

- `infr/repository/` — 仓储实现、Mapper、PO 对象
- `infr/aop/` — 切面（日志、权限、性能监控）
- `infr/plugin/` — 中间件集成（Redis、MQ、ES 等配置）
- `infr/client/` — 外部系统集成（HTTP/RPC Client）

## 允许

- 实现领域层定义的 Repository 接口
- 领域对象与 PO 的双向转换
- 数据库访问（Mapper、JPA）、所有增删改查操作
- 外部系统集成、中间件配置、缓存管理
- 切面编程

## 禁止

- 包含任何业务逻辑
- 修改聚合根的业务状态（业务状态变更属于领域层）
- 在仓储方法中进行业务规则校验
- 依赖 OHS 层或 Application 层

## 命名

- 仓储实现：`{聚合根名}RepositoryImpl`
- Mapper：`{实体名}Mapper`
- PO：`{实体名}PO`
- Client：`{外部系统名}Client`

## 依赖方向

- 可依赖：Domain 层（实现其接口）、OHS 层(写AOP)、Application 层(写AOP)
