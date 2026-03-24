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
- 定义领域服务处理跨聚合的业务逻辑
- 定义仓储接口（只定义，不实现）
- 定义领域事件发布接口（只定义，不实现）
- 定义防腐层接口（只定义，不实现）
- 发布领域事件

## 禁止

- 依赖任何其他层（Application、Infrastructure、OHS）
- 使用框架注解或装饰器管理领域对象生命周期（如 FastAPI `Depends`、SQLAlchemy 映射等）
- 包含技术细节（数据库访问、HTTP 调用、缓存操作、消息队列）
- 直接持久化数据
- 记录日志（日志属于应用层职责）
- import 任何 `infr.*`、`ohs.*`、`application.*` 模块

## 充血模型与面向对象

- 实体必须包含业务方法，禁止贫血模型（只有属性存取）
- 使用 `@dataclass` 或 `attrs` 定义实体，配合 `_` 前缀属性 + `@property` 保护封装性
- 使用 `@classmethod` 工厂方法替代 `__init__` 直接暴露，工厂方法名体现创建语义（如 `create`、`reconstitute`）
- 通过业务方法修改状态，禁止直接赋值修改属性
- 值对象：使用 `@dataclass(frozen=True)` 或 `attrs.frozen`，所有字段不可变，无 setter，业务方法返回新对象，通过值判等（`__eq__` 自动生成）
- 遵循 SOLID 原则
- 识别并规避代码坏味道：重复代码、过长方法、过大类、过长参数列表、发散式变化、霰弹式修改
- 遵循 Pythonic 编码建议：类型注解、优先枚举而非字符串常量、最小化可变性、合理使用 `Optional`、优先使用标准异常

## 仓储接口规范（repository/）

一个仓储目录下按聚合根划分，每个聚合根对应一个 Repository 接口。

- 使用 `ABC`（`abc.ABC` + `@abstractmethod`）定义接口
- 入参：只能是领域模型或关键字段（如 ID）
- 返回值：必须是领域模型或 `Optional[领域模型]`（即 `T | None`）
- 使用集合语义（`save`/`remove`），而非数据库语义（`insert`/`delete`）
- 禁止入参或返回值使用 ORM Model、DTO
- 每个方法必须用 docstring 描述实现逻辑的预期行为，包括：做什么、关键约束、异常场景

示例：

```python
from abc import ABC, abstractmethod

class OrderRepository(ABC):

    @abstractmethod
    def save(self, order: Order) -> None:
        """保存订单聚合根。

        若订单不存在则新增，若已存在则更新全部字段及其关联的订单项。
        保存时需同步持久化订单项集合，保证聚合一致性。
        """
        ...

    @abstractmethod
    def find_by_id(self, order_id: OrderId) -> Order | None:
        """根据订单ID查询订单聚合根。

        需同时加载订单项集合，返回完整的聚合。
        若订单不存在返回 None。
        """
        ...

    @abstractmethod
    def remove(self, order_id: OrderId) -> None:
        """移除订单聚合根。

        需级联移除关联的订单项。
        若订单不存在则静默忽略。
        """
        ...
```

## 事件发布接口规范（event/）

一个事件目录下按聚合划分，每个聚合对应一个 EventPublisher 接口。

- 使用 `ABC` 定义接口
- 入参：只能是领域事件对象
- 每个方法必须用 docstring 描述事件的业务含义、触发时机、消费方预期行为

示例：

```python
from abc import ABC, abstractmethod

class OrderEventPublisher(ABC):

    @abstractmethod
    def publish_order_created(self, event: OrderCreatedEvent) -> None:
        """发布订单已创建事件。

        在订单聚合根完成创建并持久化后调用。
        消费方预期：库存服务扣减库存，通知服务发送下单确认。
        """
        ...

    @abstractmethod
    def publish_order_cancelled(self, event: OrderCancelledEvent) -> None:
        """发布订单已取消事件。

        在订单状态变更为已取消并持久化后调用。
        消费方预期：库存服务释放库存，支付服务发起退款。
        """
        ...
```

## 防腐层接口规范（acl/{外部领域名}/）

按外部领域划分目录，每个外部领域对应一个 ACL 接口，隔离外部领域概念对本领域的侵入。

- 使用 `ABC` 定义接口
- 入参和返回值：只能使用本领域的模型或基本类型，禁止引入外部领域的类
- 每个方法必须用 docstring 描述：调用外部领域的什么能力、期望的行为、失败时的处理策略

示例：

```python
from abc import ABC, abstractmethod

class InventoryAclService(ABC):
    """库存领域防腐层。

    隔离库存领域的概念，将其转换为订单领域可理解的接口。
    """

    @abstractmethod
    def check_stock(self, product_id: ProductId, quantity: int) -> bool:
        """检查商品是否有足够库存。

        调用库存领域查询指定商品的可用库存数量，与请求数量比较。
        若库存服务不可用，应抛出异常而非默认返回 True。
        """
        ...

    @abstractmethod
    def reserve_stock(self, product_id: ProductId, quantity: int) -> str:
        """预扣库存。

        调用库存领域对指定商品执行预扣操作，返回预扣凭证。
        预扣失败（库存不足或服务异常）应抛出业务异常。
        """
        ...
```

## 命名

- 聚合根/实体：`{业务概念名}`（无后缀）
- 值对象：`{业务概念名}`
- 领域服务：`{业务名}{动作}Service`
- 仓储接口：`{聚合根名}Repository`
- 领域事件：`{聚合根名}{动作过去式}Event`
- 事件发布接口：`{聚合根名}EventPublisher`
- 防腐层接口：`{外部领域名}AclService`
- 模块文件名：`snake_case.py`（如 `order_repository.py`、`order_created_event.py`）

## 依赖方向

- 可依赖：无
- 禁止依赖：所有其他层（Application、Infrastructure、OHS）
