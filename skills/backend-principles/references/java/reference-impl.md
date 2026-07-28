# Java 垂直切片参考实现

以下是一个"订单"子域从 Domain 到 OHS 的完整实现示例。以此为模式参考。

---

## Domain 层

### Entity — `domain/order/model/Order.java`

```java
package com.example.domain.order.model;

import lombok.EqualsAndHashCode;
import lombok.Getter;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

@Getter
@EqualsAndHashCode(of = "id")
public class Order {
    private Long id;
    private final String orderNumber;
    private final Long customerId;
    private OrderStatus status;
    private final List<OrderItem> items;
    private final LocalDateTime createdTime;

    private Order(String orderNumber, Long customerId, List<OrderItem> items) {
        this.orderNumber = orderNumber;
        this.customerId = customerId;
        this.status = OrderStatus.CREATED;
        this.items = new ArrayList<>(items);
        this.createdTime = LocalDateTime.now();
    }

    public static Order create(String orderNumber, Long customerId, List<OrderItem> items) {
        if (items == null || items.isEmpty()) {
            throw new IllegalArgumentException("Order must have at least one item");
        }
        return new Order(orderNumber, customerId, items);
    }

    public void confirm() {
        if (this.status != OrderStatus.CREATED) {
            throw new IllegalStateException("Only CREATED order can be confirmed");
        }
        this.status = OrderStatus.CONFIRMED;
    }

    public void cancel(String reason) {
        if (this.status == OrderStatus.COMPLETED) {
            throw new IllegalStateException("Completed order cannot be cancelled");
        }
        this.status = OrderStatus.CANCELLED;
    }

    public BigDecimal totalAmount() {
        return items.stream()
                .map(OrderItem::subtotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    public List<OrderItem> getItems() {
        return Collections.unmodifiableList(items);
    }
}
```

### Value Object — `domain/order/model/OrderItem.java`

```java
package com.example.domain.order.model;

import lombok.EqualsAndHashCode;
import lombok.Getter;
import java.math.BigDecimal;

@Getter
@EqualsAndHashCode
public class OrderItem {
    private final Long productId;
    private final String productName;
    private final int quantity;
    private final BigDecimal unitPrice;

    private OrderItem(Long productId, String productName, int quantity, BigDecimal unitPrice) {
        this.productId = productId;
        this.productName = productName;
        this.quantity = quantity;
        this.unitPrice = unitPrice;
    }

    public static OrderItem of(Long productId, String productName, int quantity, BigDecimal unitPrice) {
        if (quantity <= 0) {
            throw new IllegalArgumentException("Quantity must be positive");
        }
        if (unitPrice.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Unit price must be positive");
        }
        return new OrderItem(productId, productName, quantity, unitPrice);
    }

    public BigDecimal subtotal() {
        return unitPrice.multiply(BigDecimal.valueOf(quantity));
    }
}
```

### Enum — `domain/order/model/OrderStatus.java`

```java
package com.example.domain.order.model;

public enum OrderStatus {
    CREATED, CONFIRMED, COMPLETED, CANCELLED
}
```

### Repository Interface — `domain/order/repository/OrderRepository.java`

```java
package com.example.domain.order.repository;

import com.example.domain.order.model.Order;
import java.util.Optional;

public interface OrderRepository {
    /**
     * 持久化订单。ID 为 null 时新建，非 null 时更新。
     * 同时级联持久化聚合内的 OrderItem。
     */
    void save(Order order);

    /**
     * 按 ID 加载完整订单聚合（含全部 OrderItem）。
     * 不存在时返回 empty。
     */
    Optional<Order> findById(Long id);

    /**
     * 按订单号查找。订单号具有唯一性约束。
     */
    Optional<Order> findByOrderNumber(String orderNumber);

    /**
     * 移除订单（逻辑删除）。
     */
    void remove(Order order);
}
```

### Domain Event — `domain/order/event/OrderConfirmedEvent.java`

```java
package com.example.domain.order.event;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public class OrderConfirmedEvent {
    private final Long orderId;
    private final String orderNumber;
    private final Long customerId;
}
```

---

## Infrastructure 层

### PO — `infr/repository/order/OrderPO.java`

```java
package com.example.infr.repository.order;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("t_order")
public class OrderPO {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String orderNumber;
    private Long customerId;
    private String status;
    private BigDecimal totalAmount;
    private LocalDateTime createdTime;
    private LocalDateTime updatedTime;
    private Integer isDeleted;
}
```

### Mapper — `infr/repository/order/OrderMapper.java`

```java
package com.example.infr.repository.order;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface OrderMapper extends BaseMapper<OrderPO> {
}
```

### RepositoryImpl — `infr/repository/order/OrderRepositoryImpl.java`

```java
package com.example.infr.repository.order;

import com.example.domain.order.model.Order;
import com.example.domain.order.model.OrderItem;
import com.example.domain.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class OrderRepositoryImpl implements OrderRepository {
    private final OrderMapper orderMapper;
    private final OrderItemMapper orderItemMapper;

    @Override
    public void save(Order order) {
        OrderPO po = toPO(order);
        if (order.getId() == null) {
            orderMapper.insert(po);
            // 回写 ID 到领域对象（通过反射或专门的内部方法）
        } else {
            po.setId(order.getId());
            orderMapper.updateById(po);
        }
        saveItems(order.getId(), order.getItems());
    }

    @Override
    public Optional<Order> findById(Long id) {
        OrderPO po = orderMapper.selectById(id);
        if (po == null || po.getIsDeleted() == 1) {
            return Optional.empty();
        }
        List<OrderItemPO> itemPOs = orderItemMapper.selectByOrderId(id);
        return Optional.of(toDomain(po, itemPOs));
    }

    @Override
    public Optional<Order> findByOrderNumber(String orderNumber) {
        // 按唯一索引查询
        OrderPO po = orderMapper.selectOne(
            new LambdaQueryWrapper<OrderPO>().eq(OrderPO::getOrderNumber, orderNumber)
        );
        if (po == null || po.getIsDeleted() == 1) {
            return Optional.empty();
        }
        List<OrderItemPO> itemPOs = orderItemMapper.selectByOrderId(po.getId());
        return Optional.of(toDomain(po, itemPOs));
    }

    @Override
    public void remove(Order order) {
        OrderPO po = new OrderPO();
        po.setId(order.getId());
        po.setIsDeleted(1);
        orderMapper.updateById(po);
    }

    private OrderPO toPO(Order order) {
        OrderPO po = new OrderPO();
        po.setOrderNumber(order.getOrderNumber());
        po.setCustomerId(order.getCustomerId());
        po.setStatus(order.getStatus().name());
        po.setTotalAmount(order.totalAmount());
        return po;
    }

    private Order toDomain(OrderPO po, List<OrderItemPO> itemPOs) {
        List<OrderItem> items = itemPOs.stream()
                .map(ip -> OrderItem.of(ip.getProductId(), ip.getProductName(),
                        ip.getQuantity(), ip.getUnitPrice()))
                .toList();
        // 通过反射或专门的重建方法还原领域对象
        return Order.reconstruct(po.getId(), po.getOrderNumber(), po.getCustomerId(),
                OrderStatus.valueOf(po.getStatus()), items, po.getCreatedTime());
    }

    private void saveItems(Long orderId, List<OrderItem> items) {
        orderItemMapper.deleteByOrderId(orderId);
        items.forEach(item -> {
            OrderItemPO itemPO = toItemPO(orderId, item);
            orderItemMapper.insert(itemPO);
        });
    }
}
```

---

## Application 层

### Command — `application/order/CreateOrderCommand.java`

```java
package com.example.application.order;

import lombok.Builder;
import lombok.Getter;
import java.math.BigDecimal;
import java.util.List;

@Getter
@Builder
public class CreateOrderCommand {
    private final Long customerId;
    private final List<OrderItemInput> items;

    @Getter
    @Builder
    public static class OrderItemInput {
        private final Long productId;
        private final String productName;
        private final int quantity;
        private final BigDecimal unitPrice;
    }
}
```

### ApplicationService — `application/order/OrderApplicationService.java`

```java
package com.example.application.order;

import com.example.domain.order.model.Order;
import com.example.domain.order.model.OrderItem;
import com.example.domain.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class OrderApplicationService {
    private final OrderRepository orderRepository;
    private final OrderNumberGenerator orderNumberGenerator;

    @Transactional(rollbackFor = Exception.class)
    public Order createOrder(CreateOrderCommand command) {
        log.info("Creating order for customer: {}", command.getCustomerId());

        List<OrderItem> items = command.getItems().stream()
                .map(i -> OrderItem.of(i.getProductId(), i.getProductName(),
                        i.getQuantity(), i.getUnitPrice()))
                .toList();

        String orderNumber = orderNumberGenerator.generate();
        Order order = Order.create(orderNumber, command.getCustomerId(), items);
        orderRepository.save(order);

        log.info("Order created: {}", order.getOrderNumber());
        return order;
    }

    @Transactional(rollbackFor = Exception.class)
    public Order confirmOrder(Long orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new BusinessException("ORDER_NOT_FOUND", "Order not found"));
        order.confirm();
        orderRepository.save(order);
        return order;
    }

    @Transactional(readOnly = true)
    public Order getOrder(Long orderId) {
        return orderRepository.findById(orderId)
                .orElseThrow(() -> new BusinessException("ORDER_NOT_FOUND", "Order not found"));
    }
}
```

---

## OHS 层

### Request DTO — `ohs/http/order/CreateOrderRequest.java`

```java
package com.example.ohs.http.order;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.math.BigDecimal;
import java.util.List;

@Data
public class CreateOrderRequest {
    @NotNull
    private Long customerId;

    @NotEmpty
    @Valid
    private List<OrderItemRequest> items;

    @Data
    public static class OrderItemRequest {
        @NotNull
        private Long productId;
        @NotNull
        private String productName;
        @NotNull
        private Integer quantity;
        @NotNull
        private BigDecimal unitPrice;
    }
}
```

### Response DTO — `ohs/http/order/OrderResponse.java`

```java
package com.example.ohs.http.order;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class OrderResponse {
    private Long id;
    private String orderNumber;
    private Long customerId;
    private String status;
    private BigDecimal totalAmount;
    private List<OrderItemResponse> items;
    private LocalDateTime createdTime;

    @Data
    @Builder
    public static class OrderItemResponse {
        private Long productId;
        private String productName;
        private int quantity;
        private BigDecimal unitPrice;
        private BigDecimal subtotal;
    }
}
```

### Controller — `ohs/http/order/OrderController.java`

```java
package com.example.ohs.http.order;

import com.example.application.order.CreateOrderCommand;
import com.example.application.order.OrderApplicationService;
import com.example.domain.order.model.Order;
import com.example.ohs.http.common.Response;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {
    private final OrderApplicationService orderApplicationService;

    @PostMapping
    public Response<OrderResponse> createOrder(@Valid @RequestBody CreateOrderRequest request) {
        CreateOrderCommand command = toCommand(request);
        Order order = orderApplicationService.createOrder(command);
        return Response.success(toResponse(order));
    }

    @PostMapping("/{id}/confirm")
    public Response<OrderResponse> confirmOrder(@PathVariable Long id) {
        Order order = orderApplicationService.confirmOrder(id);
        return Response.success(toResponse(order));
    }

    @GetMapping("/{id}")
    public Response<OrderResponse> getOrder(@PathVariable Long id) {
        Order order = orderApplicationService.getOrder(id);
        return Response.success(toResponse(order));
    }

    private CreateOrderCommand toCommand(CreateOrderRequest request) {
        return CreateOrderCommand.builder()
                .customerId(request.getCustomerId())
                .items(request.getItems().stream()
                        .map(i -> CreateOrderCommand.OrderItemInput.builder()
                                .productId(i.getProductId())
                                .productName(i.getProductName())
                                .quantity(i.getQuantity())
                                .unitPrice(i.getUnitPrice())
                                .build())
                        .toList())
                .build();
    }

    private OrderResponse toResponse(Order order) {
        return OrderResponse.builder()
                .id(order.getId())
                .orderNumber(order.getOrderNumber())
                .customerId(order.getCustomerId())
                .status(order.getStatus().name())
                .totalAmount(order.totalAmount())
                .items(order.getItems().stream()
                        .map(i -> OrderResponse.OrderItemResponse.builder()
                                .productId(i.getProductId())
                                .productName(i.getProductName())
                                .quantity(i.getQuantity())
                                .unitPrice(i.getUnitPrice())
                                .subtotal(i.subtotal())
                                .build())
                        .toList())
                .createdTime(order.getCreatedTime())
                .build();
    }
}
```

---

## 模式要点总结

| 模式 | 示例体现 |
|------|---------|
| Private 构造 + 静态工厂 | `Order.create(...)`, `OrderItem.of(...)` |
| 不变量保护 | 工厂方法中校验 items 非空、quantity > 0 |
| 业务方法修改状态 | `order.confirm()`, `order.cancel(reason)` |
| 状态前置检查 | confirm 检查 status == CREATED |
| 集合语义仓储 | `save` (非 insert/update), `remove` (非 delete) |
| Javadoc 描述行为预期 | Repository 每个方法有完整注释 |
| PO 隔离 | PO 只在 RepositoryImpl 内部使用 |
| 薄 Application 层 | 只有获取→调用→持久化，无 if-else 业务判断 |
| Command 不可变 | @Builder + @Getter，无 setter |
| Controller 无 try-catch | 异常交由 @RestControllerAdvice 处理 |
| 单向依赖 | Controller→AppService→Domain←RepositoryImpl |
