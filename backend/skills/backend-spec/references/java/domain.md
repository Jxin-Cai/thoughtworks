# 📋 Domain 层（领域层）约束

## 路径结构

- `domain/{子域名}/model/` — Entity、Value Object、Aggregate Root
- `domain/{子域名}/repository/` — Repository Interface（仓储接口，按聚合根划分）
- `domain/{子域名}/event/` — Domain Event Publishing Interface（事件发布接口，按聚合划分）
- `domain/{子域名}/acl/{外部领域名}/` — Anti-Corruption Layer Interface（防腐层接口，按外部领域划分）
- `domain/{子域名}/service/` — Domain Service
- `domain/{子域名}/lib/` — 领域内通用工具类（如格式化、校验辅助等纯函数工具）

## 允许

- 定义实体、值对象、聚合根，并在其中实现业务规则
- 根据问题边界选择聚合、实体/值对象或领域服务建模；领域可以只有领域服务，不强制必须存在聚合
- 定义领域服务承载不适合放入实体/值对象但明确属于领域层的规则、决策、计算、校验与策略；跨聚合逻辑只是其中一种典型场景
- 定义仓储接口（只定义，不实现）
- 定义领域事件发布接口（只定义，不实现）
- 定义防腐层接口（只定义，不实现）
- 发布领域事件

## 禁止

- 依赖任何其他层（Application、Infrastructure、OHS）
- 使用 Spring 注解（@Component、@Autowired、@Service 等）管理领域对象生命周期
- 包含技术细节（数据库访问、HTTP 调用、缓存操作、消息队列）
- 直接持久化数据
- 记录日志（日志属于应用层职责）
- import 任何 `infr.*`、`ohs.*`、`application.*` 包

## 充血模型与面向对象

- 实体必须包含业务方法，禁止贫血模型（只有 getter/setter）
- 优先将业务规则沉到实体、值对象或领域服务，避免领域层退化成数据封装
- 使用 private 构造函数 + 静态工厂方法
- 使用 final 字段保护不变性，通过业务方法修改状态
- 值对象：所有字段 final，无 setter，业务方法返回新对象，通过值判等（@EqualsAndHashCode）
- 遵循 SOLID 原则
- 识别并规避代码坏味道：重复代码、过长方法、过大类、过长参数列表、发散式变化、霰弹式修改
- 遵循 Effective Java 编码建议：Builder 处理多参数构造、优先枚举而非 int 常量、最小化可变性、合理使用 Optional、优先使用标准异常

## 仓储接口规范（repository/）

一个仓储目录下按聚合根划分，每个聚合根对应一个 Repository 接口。

- 入参：只能是领域模型或关键字段（如 ID）
- 返回值：必须是领域模型或 Optional<领域模型>
- 使用集合语义（save/remove），而非数据库语义（insert/delete）
- 禁止入参或返回值使用 PO、DTO
- 每个方法必须用 Javadoc 描述实现逻辑的预期行为，包括：做什么、关键约束、异常场景

## 事件发布接口规范（event/）

一个事件目录下按聚合划分，每个聚合对应一个 EventPublisher 接口。

- 入参：只能是领域事件对象
- 每个方法必须用 Javadoc 描述事件的业务含义、触发时机、消费方预期行为

## 防腐层接口规范（acl/{外部领域名}/）

按外部领域划分目录，每个外部领域对应一个 ACL 接口，隔离外部领域概念对本领域的侵入。

- 入参和返回值：只能使用本领域的模型或基本类型，禁止引入外部领域的类
- 每个方法必须用 Javadoc 描述：调用外部领域的什么能力、期望的行为、失败时的处理策略

## 命名

- 聚合根/实体：`{业务概念名}`（无后缀）
- 值对象：`{业务概念名}`
- 领域服务：`{业务名}{动作}Service`
- 仓储接口：`{聚合根名}Repository`
- 领域事件：`{聚合根名}{动作过去式}Event`
- 事件发布接口：`{聚合根名}EventPublisher`
- 防腐层接口：`{外部领域名}AclService`

## 依赖方向

- 可依赖：无
- 禁止依赖：所有其他层（Application、Infrastructure、OHS）
