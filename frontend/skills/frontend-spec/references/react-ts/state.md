# 状态管理规范

## 状态分类

| 类型 | 方案 | 适用场景 |
|---|---|---|
| 组件局部状态 | `useState` / `useReducer` | 仅当前组件使用的 UI 状态 |
| 服务端状态 | TanStack Query（React Query） | API 数据的缓存、同步、分页 |
| 全局客户端状态 | zustand | 跨页面共享的客户端状态（如用户信息、主题） |
| 简单共享状态 | React Context | 少量低频更新的共享数据（如 locale） |

## 服务端状态（TanStack Query）

- 所有 API 数据获取必须通过 `useQuery` / `useMutation` 管理
- 查询 hook 按 FSD 层级放置：
  - Entity CRUD hook 放在 `src/entities/{entity}/model/`（如 `useUserList`、`useUserDetail`）
  - Feature 场景 hook 放在 `src/features/{feature}/model/`（如 `useCreateOrder`、`useFilterOrders`）

```typescript
// src/entities/user/model/useUserList.ts
function useUserList(params: UserQueryParams) {
  return useQuery({
    queryKey: ['users', params],
    queryFn: () => getUserList(params),
  });
}
```

- `queryKey` 必须包含所有影响查询结果的参数
- 写操作使用 `useMutation`，成功后通过 `invalidateQueries` 刷新相关缓存

## 全局客户端状态（zustand）

```typescript
interface AuthStore {
  token: string | null;
  setToken: (token: string) => void;
  clearToken: () => void;
}

const useAuthStore = create<AuthStore>((set) => ({
  token: null,
  setToken: (token) => set({ token }),
  clearToken: () => set({ token: null }),
}));
```

- 全局 store 放在 `src/shared/config/stores/`（如 `useAuthStore`、`useThemeStore`）
- Feature 专属 store 放在 `src/features/{feature}/model/`（如 `useCartStore`）
- store 保持扁平结构，避免深层嵌套

## 约束

- 禁止 prop drilling 超过 2 层；超出时提升到 Context 或 zustand
- 禁止将服务端数据复制到全局 store；服务端数据由 React Query 管理
- `useReducer` 仅用于单组件内复杂状态逻辑（3 个以上关联状态字段）
- 状态更新必须保持不可变性，禁止直接修改 state 对象
