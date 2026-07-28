# Python 垂直切片参考实现

以下是一个"订单"子域从 Domain 到 OHS 的完整实现示例（FastAPI + SQLAlchemy）。

---

## Domain 层

### Entity — `domain/order/model/order.py`

```python
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from typing import List

from domain.order.model.order_item import OrderItem
from domain.order.model.order_status import OrderStatus


@dataclass
class Order:
    order_number: str
    customer_id: int
    status: OrderStatus = field(default=OrderStatus.CREATED, init=False)
    items: List[OrderItem] = field(default_factory=list)
    created_time: datetime = field(default_factory=datetime.now)
    id: int | None = field(default=None)

    def __post_init__(self):
        if not self.items:
            raise ValueError("Order must have at least one item")

    @classmethod
    def create(cls, order_number: str, customer_id: int, items: List[OrderItem]) -> Order:
        return cls(order_number=order_number, customer_id=customer_id, items=list(items))

    @classmethod
    def reconstitute(cls, id: int, order_number: str, customer_id: int,
                     status: OrderStatus, items: List[OrderItem],
                     created_time: datetime) -> Order:
        """从持久化数据重建领域对象（仅供 Repository 使用）"""
        obj = object.__new__(cls)
        obj.id = id
        obj.order_number = order_number
        obj.customer_id = customer_id
        obj.status = status
        obj.items = items
        obj.created_time = created_time
        return obj

    def confirm(self) -> None:
        if self.status != OrderStatus.CREATED:
            raise ValueError("Only CREATED order can be confirmed")
        self.status = OrderStatus.CONFIRMED

    def cancel(self, reason: str) -> None:
        if self.status == OrderStatus.COMPLETED:
            raise ValueError("Completed order cannot be cancelled")
        self.status = OrderStatus.CANCELLED

    def total_amount(self) -> Decimal:
        return sum((item.subtotal() for item in self.items), Decimal("0"))
```

### Value Object — `domain/order/model/order_item.py`

```python
from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class OrderItem:
    product_id: int
    product_name: str
    quantity: int
    unit_price: Decimal

    def __post_init__(self):
        if self.quantity <= 0:
            raise ValueError("Quantity must be positive")
        if self.unit_price <= 0:
            raise ValueError("Unit price must be positive")

    @classmethod
    def of(cls, product_id: int, product_name: str, quantity: int, unit_price: Decimal) -> "OrderItem":
        return cls(product_id=product_id, product_name=product_name,
                   quantity=quantity, unit_price=unit_price)

    def subtotal(self) -> Decimal:
        return self.unit_price * self.quantity
```

### Enum — `domain/order/model/order_status.py`

```python
from enum import Enum

class OrderStatus(Enum):
    CREATED = "CREATED"
    CONFIRMED = "CONFIRMED"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"
```

### Repository Interface — `domain/order/repository/order_repository.py`

```python
from abc import ABC, abstractmethod
from typing import Optional
from domain.order.model.order import Order


class OrderRepository(ABC):
    @abstractmethod
    def save(self, order: Order) -> None:
        """持久化订单。ID 为 None 时新建，非 None 时更新。级联持久化 OrderItem。"""
        ...

    @abstractmethod
    def find_by_id(self, id: int) -> Optional[Order]:
        """按 ID 加载完整订单聚合（含全部 OrderItem）。不存在时返回 None。"""
        ...

    @abstractmethod
    def find_by_order_number(self, order_number: str) -> Optional[Order]:
        """按订单号查找。订单号具有唯一性约束。"""
        ...

    @abstractmethod
    def remove(self, order: Order) -> None:
        """移除订单（逻辑删除）。"""
        ...
```

---

## Infrastructure 层

### ORM Model — `infr/repository/order/order_model.py`

```python
from datetime import datetime
from decimal import Decimal
from sqlalchemy import BigInteger, DateTime, Integer, Numeric, String, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class OrderModel(Base):
    __tablename__ = "t_order"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    order_number: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    customer_id: Mapped[int] = mapped_column(BigInteger, nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False)
    total_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    created_time: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_time: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())
    is_deleted: Mapped[int] = mapped_column(Integer, default=0)
```

### RepositoryImpl — `infr/repository/order/order_repository_impl.py`

```python
from typing import Optional
from sqlalchemy import select
from sqlalchemy.orm import Session

from domain.order.model.order import Order
from domain.order.model.order_item import OrderItem
from domain.order.model.order_status import OrderStatus
from domain.order.repository.order_repository import OrderRepository
from infr.repository.order.order_model import OrderModel
from infr.repository.order.order_item_model import OrderItemModel


class OrderRepositoryImpl(OrderRepository):
    def __init__(self, session: Session):
        self._session = session

    def save(self, order: Order) -> None:
        model = self._to_model(order)
        if order.id is None:
            self._session.add(model)
            self._session.flush()
            order.id = model.id
        else:
            model.id = order.id
            self._session.merge(model)
        self._save_items(order.id, order.items)

    def find_by_id(self, id: int) -> Optional[Order]:
        model = self._session.get(OrderModel, id)
        if model is None or model.is_deleted == 1:
            return None
        item_models = self._session.scalars(
            select(OrderItemModel).where(OrderItemModel.order_id == id)
        ).all()
        return self._to_domain(model, item_models)

    def find_by_order_number(self, order_number: str) -> Optional[Order]:
        model = self._session.scalars(
            select(OrderModel).where(
                OrderModel.order_number == order_number,
                OrderModel.is_deleted == 0
            )
        ).first()
        if model is None:
            return None
        item_models = self._session.scalars(
            select(OrderItemModel).where(OrderItemModel.order_id == model.id)
        ).all()
        return self._to_domain(model, item_models)

    def remove(self, order: Order) -> None:
        model = self._session.get(OrderModel, order.id)
        if model:
            model.is_deleted = 1

    def _to_model(self, order: Order) -> OrderModel:
        model = OrderModel()
        model.order_number = order.order_number
        model.customer_id = order.customer_id
        model.status = order.status.value
        model.total_amount = order.total_amount()
        return model

    def _to_domain(self, model: OrderModel, item_models: list[OrderItemModel]) -> Order:
        items = [
            OrderItem.of(im.product_id, im.product_name, im.quantity, im.unit_price)
            for im in item_models
        ]
        return Order.reconstitute(
            id=model.id, order_number=model.order_number,
            customer_id=model.customer_id,
            status=OrderStatus(model.status), items=items,
            created_time=model.created_time
        )

    def _save_items(self, order_id: int, items: list[OrderItem]) -> None:
        self._session.execute(
            OrderItemModel.__table__.delete().where(OrderItemModel.order_id == order_id)
        )
        for item in items:
            item_model = OrderItemModel(
                order_id=order_id, product_id=item.product_id,
                product_name=item.product_name, quantity=item.quantity,
                unit_price=item.unit_price
            )
            self._session.add(item_model)
```

---

## Application 层

### Command — `application/order/create_order_command.py`

```python
from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class OrderItemInput:
    product_id: int
    product_name: str
    quantity: int
    unit_price: Decimal


@dataclass(frozen=True)
class CreateOrderCommand:
    customer_id: int
    items: tuple[OrderItemInput, ...]
```

### ApplicationService — `application/order/order_application_service.py`

```python
import logging
from domain.order.model.order import Order
from domain.order.model.order_item import OrderItem
from domain.order.repository.order_repository import OrderRepository
from application.order.create_order_command import CreateOrderCommand

logger = logging.getLogger(__name__)


class OrderApplicationService:
    def __init__(self, order_repository: OrderRepository, order_number_generator):
        self._order_repository = order_repository
        self._order_number_generator = order_number_generator

    def create_order(self, command: CreateOrderCommand) -> Order:
        logger.info("Creating order for customer: %s", command.customer_id)

        items = [
            OrderItem.of(i.product_id, i.product_name, i.quantity, i.unit_price)
            for i in command.items
        ]

        order_number = self._order_number_generator.generate()
        order = Order.create(order_number, command.customer_id, items)
        self._order_repository.save(order)

        logger.info("Order created: %s", order.order_number)
        return order

    def confirm_order(self, order_id: int) -> Order:
        order = self._order_repository.find_by_id(order_id)
        if order is None:
            raise BusinessException("ORDER_NOT_FOUND", "Order not found")
        order.confirm()
        self._order_repository.save(order)
        return order

    def get_order(self, order_id: int) -> Order:
        order = self._order_repository.find_by_id(order_id)
        if order is None:
            raise BusinessException("ORDER_NOT_FOUND", "Order not found")
        return order
```

---

## OHS 层

### Request DTO — `ohs/http/order/schemas.py`

```python
from decimal import Decimal
from pydantic import BaseModel, Field


class OrderItemRequest(BaseModel):
    product_id: int
    product_name: str = Field(min_length=1)
    quantity: int = Field(ge=1)
    unit_price: Decimal = Field(gt=0)


class CreateOrderRequest(BaseModel):
    customer_id: int
    items: list[OrderItemRequest] = Field(min_length=1)


class OrderItemResponse(BaseModel):
    product_id: int
    product_name: str
    quantity: int
    unit_price: Decimal
    subtotal: Decimal


class OrderResponse(BaseModel):
    id: int
    order_number: str
    customer_id: int
    status: str
    total_amount: Decimal
    items: list[OrderItemResponse]
    created_time: str
```

### Router — `ohs/http/order/order_router.py`

```python
from fastapi import APIRouter, Depends
from typing import Annotated

from application.order.create_order_command import CreateOrderCommand, OrderItemInput
from application.order.order_application_service import OrderApplicationService
from ohs.http.common.api_response import ApiResponse
from ohs.http.order.schemas import CreateOrderRequest, OrderResponse
from infr.dependencies import get_order_application_service

router = APIRouter(prefix="/api/orders", tags=["orders"])

OrderService = Annotated[OrderApplicationService, Depends(get_order_application_service)]


@router.post("", response_model=ApiResponse[OrderResponse])
async def create_order(request: CreateOrderRequest, service: OrderService):
    command = CreateOrderCommand(
        customer_id=request.customer_id,
        items=tuple(
            OrderItemInput(product_id=i.product_id, product_name=i.product_name,
                          quantity=i.quantity, unit_price=i.unit_price)
            for i in request.items
        )
    )
    order = service.create_order(command)
    return ApiResponse.success(data=_to_response(order))


@router.post("/{order_id}/confirm", response_model=ApiResponse[OrderResponse])
async def confirm_order(order_id: int, service: OrderService):
    order = service.confirm_order(order_id)
    return ApiResponse.success(data=_to_response(order))


@router.get("/{order_id}", response_model=ApiResponse[OrderResponse])
async def get_order(order_id: int, service: OrderService):
    order = service.get_order(order_id)
    return ApiResponse.success(data=_to_response(order))


def _to_response(order) -> OrderResponse:
    return OrderResponse(
        id=order.id, order_number=order.order_number,
        customer_id=order.customer_id, status=order.status.value,
        total_amount=order.total_amount(),
        items=[
            OrderItemResponse(product_id=i.product_id, product_name=i.product_name,
                              quantity=i.quantity, unit_price=i.unit_price,
                              subtotal=i.subtotal())
            for i in order.items
        ],
        created_time=order.created_time.isoformat()
    )
```

---

## 模式要点总结

| 模式 | Python 体现 |
|------|------------|
| Private 构造 + 工厂方法 | `@classmethod create()`, `reconstitute()` |
| 不变量保护 | `__post_init__` 校验 |
| 值对象不可变 | `@dataclass(frozen=True)` |
| 集合语义仓储 | `save`/`remove`，ABC 接口 |
| PO 隔离 | ORM Model 仅在 RepositoryImpl 内部 |
| 薄 Application 层 | 获取→调用→持久化，无 if-else |
| Command 不可变 | `@dataclass(frozen=True)` |
| Router 无 try-except | 异常交由 exception_handler |
| DI 通过 Depends | `Annotated[T, Depends(factory)]` |
