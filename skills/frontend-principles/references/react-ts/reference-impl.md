# React + TypeScript 垂直 Feature 参考实现

以下是"订单创建"Feature 的完整 FSD 实现示例。

---

## Shared 层

### API 客户端 — `src/shared/api/client.ts`

```typescript
import axios from 'axios';

const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  timeout: 10000,
});

apiClient.interceptors.response.use(
  (response) => response.data,
  (error) => {
    if (!error.response) {
      console.error('Network error');
    }
    return Promise.reject(error);
  }
);

export { apiClient };
```

### 统一响应类型 — `src/shared/types/api.ts`

```typescript
export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

export interface PaginatedData<T> {
  list: T[];
  total: number;
  pageNum: number;
  pageSize: number;
}
```

---

## Entity 层 — `src/entities/order/`

### 类型 — `src/entities/order/model/types.ts`

```typescript
export interface Order {
  id: number;
  orderNumber: string;
  customerId: number;
  status: OrderStatus;
  totalAmount: number;
  items: OrderItem[];
  createdTime: string;
}

export interface OrderItem {
  productId: number;
  productName: string;
  quantity: number;
  unitPrice: number;
  subtotal: number;
}

export type OrderStatus = 'CREATED' | 'CONFIRMED' | 'COMPLETED' | 'CANCELLED';
```

### 查询 Hook — `src/entities/order/model/useOrderDetail.ts`

```typescript
import { useQuery } from '@tanstack/react-query';
import { getOrderDetail } from '../api/getOrderDetail';

export function useOrderDetail(orderId: number) {
  return useQuery({
    queryKey: ['order', orderId],
    queryFn: () => getOrderDetail(orderId),
    enabled: orderId > 0,
  });
}
```

### API 函数 — `src/entities/order/api/getOrderDetail.ts`

```typescript
import { apiClient } from '@shared/api/client';
import type { ApiResponse } from '@shared/types/api';
import type { Order } from '../model/types';

export async function getOrderDetail(orderId: number): Promise<Order> {
  const res = await apiClient.get<never, ApiResponse<Order>>(`/api/orders/${orderId}`);
  return res.data;
}
```

### Public API — `src/entities/order/index.ts`

```typescript
export type { Order, OrderItem, OrderStatus } from './model/types';
export { useOrderDetail } from './model/useOrderDetail';
```

---

## Feature 层 — `src/features/order-create/`

### 类型 — `src/features/order-create/model/types.ts`

```typescript
export interface CreateOrderFormValues {
  customerId: number;
  items: OrderItemInput[];
}

export interface OrderItemInput {
  productId: number;
  productName: string;
  quantity: number;
  unitPrice: number;
}
```

### Mutation Hook — `src/features/order-create/model/useCreateOrder.ts`

```typescript
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { createOrder } from '../api/createOrder';
import type { CreateOrderFormValues } from './types';

export function useCreateOrder() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (values: CreateOrderFormValues) => createOrder(values),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['orders'] });
    },
  });
}
```

### API 函数 — `src/features/order-create/api/createOrder.ts`

```typescript
import { apiClient } from '@shared/api/client';
import type { ApiResponse } from '@shared/types/api';
import type { Order } from '@entities/order';
import type { CreateOrderFormValues } from '../model/types';

export async function createOrder(data: CreateOrderFormValues): Promise<Order> {
  const res = await apiClient.post<never, ApiResponse<Order>>('/api/orders', data);
  return res.data;
}
```

### 表单组件 — `src/features/order-create/ui/OrderCreateForm.tsx`

```typescript
import { useState } from 'react';
import { useCreateOrder } from '../model/useCreateOrder';
import type { CreateOrderFormValues, OrderItemInput } from '../model/types';

interface OrderCreateFormProps {
  /** 提交成功后的回调 */
  onSuccess?: () => void;
}

function OrderCreateForm({ onSuccess }: OrderCreateFormProps) {
  const [formValues, setFormValues] = useState<CreateOrderFormValues>({
    customerId: 0,
    items: [],
  });
  const { mutate, isPending } = useCreateOrder();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    mutate(formValues, { onSuccess });
  }

  function handleAddItem(item: OrderItemInput) {
    setFormValues((prev) => ({
      ...prev,
      items: [...prev.items, item],
    }));
  }

  return (
    <form onSubmit={handleSubmit}>
      {/* Customer selection */}
      {/* Items list with add/remove */}
      <button type="submit" disabled={isPending}>
        {isPending ? '提交中...' : '创建订单'}
      </button>
    </form>
  );
}

export { OrderCreateForm };
```

### Public API — `src/features/order-create/index.ts`

```typescript
export { OrderCreateForm } from './ui/OrderCreateForm';
export { useCreateOrder } from './model/useCreateOrder';
```

---

## Pages 层 — `src/pages/order-create/`

### 页面组件 — `src/pages/order-create/OrderCreatePage.tsx`

```typescript
import { useNavigate } from 'react-router-dom';
import { OrderCreateForm } from '@features/order-create';

function OrderCreatePage() {
  const navigate = useNavigate();

  function handleSuccess() {
    navigate('/orders');
  }

  return (
    <div>
      <h1>创建订单</h1>
      <OrderCreateForm onSuccess={handleSuccess} />
    </div>
  );
}

export default OrderCreatePage;
```

---

## App 层 — 路由配置

### `src/app/router/routes.tsx`

```typescript
import { lazy } from 'react';
import type { RouteObject } from 'react-router-dom';

const OrderCreatePage = lazy(() => import('@pages/order-create/OrderCreatePage'));
const OrderDetailPage = lazy(() => import('@pages/order-detail/OrderDetailPage'));

export const routes: RouteObject[] = [
  { path: '/orders/create', element: <OrderCreatePage /> },
  { path: '/orders/:id', element: <OrderDetailPage /> },
];
```

---

## 模式要点总结

| 模式 | 示例体现 |
|------|---------|
| Feature as Vertical Slice | order-create 包含 ui/ + model/ + api/ + index.ts |
| Public API Boundary | 只通过 index.ts 导出 |
| Entity 复用 | Order 类型在 entities/ 定义，Feature 和 Page 都引用 |
| Server State Ownership | useQuery/useMutation 管理，无全局 store 复制 |
| Page as Composition Root | OrderCreatePage 只组合 + 导航，无业务逻辑 |
| Lazy Loading | 路由用 React.lazy() |
| 层级别名导入 | `@features/`, `@entities/`, `@shared/` |
