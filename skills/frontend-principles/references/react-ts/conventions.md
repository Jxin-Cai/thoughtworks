# React + TypeScript 约定

本文件仅包含 React 和 TypeScript 特有的技术约定。FSD 架构规则见 `architecture.md`。

## TypeScript

- `strict: true`，不降级任何 strict 子选项
- 禁止 `any`，必要时用 `unknown` + 类型收窄
- 所有函数参数和返回值显式标注类型

## 组件声明

```typescript
// 推荐：函数声明
function UserProfile({ name, age }: UserProfileProps) {
  return <div>{name}</div>;
}

// 不推荐：React.FC
```

## Props 定义

```typescript
interface UserProfileProps {
  /** 用户名称 */
  name: string;
  /** 年龄，可选 */
  age?: number;
}
```

- 使用 `interface`，命名 `{ComponentName}Props`
- 每个 prop 添加 JSDoc 注释
- 可选 prop 用解构默认值

## 状态管理

| 类型 | 方案 | 场景 |
|---|---|---|
| 组件局部 | `useState` / `useReducer` | 仅当前组件的 UI 状态 |
| 服务端 | TanStack Query | API 数据缓存、同步、分页 |
| 全局客户端 | zustand | 跨页面共享（用户信息、主题） |
| 简单共享 | React Context | 少量低频更新数据（locale） |

### React Query 约定

```typescript
function useOrderList(params: OrderQueryParams) {
  return useQuery({
    queryKey: ['orders', params],
    queryFn: () => getOrderList(params),
  });
}
```

- `queryKey` 必须包含所有影响结果的参数
- 写操作用 `useMutation`，成功后 `invalidateQueries`
- 禁止将 API 数据复制到全局 store

### Zustand 约定

```typescript
const useAuthStore = create<AuthStore>((set) => ({
  token: null,
  setToken: (token) => set({ token }),
}));
```

- 全局 store 放 `src/shared/config/stores/`
- Feature 专属 store 放 `src/features/{feature}/model/`
- 保持扁平结构

## 数据获取

- 禁止在组件内直接调用 axios/fetch
- Entity CRUD hook → `entities/{entity}/model/`
- Feature 场景 hook → `features/{feature}/model/`

## 路由（React Router v6）

```typescript
import { lazy } from 'react';
const Page = lazy(() => import('@pages/xxx/XxxPage'));
```

- 页面级 lazy loading
- URL 使用 kebab-case
- 路由守卫用 `loader` 或包装组件
- 路由配置集中在 `src/app/router/`

## API 客户端

- 基础封装放 `src/shared/api/client.ts`
- 统一拦截器处理 HTTP 错误和网络异常
- 每个 slice 的 API 函数放 `{slice}/api/` 目录
- 返回类型使用 `ApiResponse<T>`

## 表单

- 使用受控组件模式
- 复杂表单用 `react-hook-form`
- 验证逻辑集中在提交或 onBlur
- 禁止混用框架校验和手动校验

## 组件约束

- 单文件 ≤200 行，超出拆分子组件
- 每文件只导出一个组件
- 事件处理命名：`handle{Event}`（handleSubmit、handleClick）
- 禁止 prop drilling 超过 2 层

## 环境变量

- `VITE_API_BASE_URL` 配置 API 地址
- 禁止硬编码后端地址
- `.env.example` 提交仓库，`.env.local` 加入 .gitignore

## 错误处理

- HTTP 错误：全局拦截器统一处理
- 业务错误（code !== 0）：调用方组件自行处理
- 网络异常：拦截器提示用户

## 统一响应类型

```typescript
interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}
```

## Vite 路径别名配置

必须同时配置 `vite.config.ts`（resolve.alias）和 `tsconfig.json`（paths）。
