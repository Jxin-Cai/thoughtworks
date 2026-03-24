# 📋 Application 层（应用层）约束

## 允许

- 编排多个 Domain Service / Repository 完成业务用例
- 管理事务边界（@Transactional(rollbackFor = Exception.class)）
- 协调多个聚合根之间的交互
- 调用基础设施层（事件发布、缓存、消息等）
- 记录入参出参日志（INFO 级别）

## 禁止

- 包含业务规则（业务规则属于领域层）
- 包含复杂计算逻辑
- 直接操作数据库（必须通过 Repository）
- 依赖 OHS 层
- 定义 DTO 类（返回类型使用领域层模型，DTO 封装由 OHS 层负责）
- 用 try-catch 做异常兜底（异常自然上抛，由 Infrastructure 层全局异常处理 AOP 统一拦截）

## 核心原则

- 薄薄一层，只做编排不做计算
- 一个公有方法对应一个业务用例

## 事务管理

- @Transactional 只加在本层公有方法上
- 必须指定 `rollbackFor = Exception.class`
- 查询方法使用 `@Transactional(readOnly = true)` 优化性能
- 事务方法内不做 RPC 调用、消息发送等耗时 I/O（避免大事务）
- 禁止在 Controller、领域服务、仓储实现上加 @Transactional

## 命名

- 应用服务：`{业务名}ApplicationService`
- Command 对象：`{操作名}Command`（不可变，使用 @Builder）

## 依赖方向

- 可依赖：Domain 层
- 禁止依赖：OHS 层、Infrastructure 层
