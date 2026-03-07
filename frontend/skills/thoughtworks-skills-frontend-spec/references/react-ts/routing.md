# 路由规范

## 技术选型

- 使用 React Router v6+
- 路由定义集中在 `src/app/router/` 目录下

## 路由定义

```typescript
// src/app/router/index.tsx
import { createBrowserRouter } from 'react-router-dom';

const router = createBrowserRouter([
  {
    path: '/',
    element: <RootLayout />,
    children: [
      { index: true, element: <HomePage /> },
      { path: 'user-management', element: <UserListPage /> },
      { path: 'user-management/:id', element: <UserDetailPage /> },
    ],
  },
]);
```

## 懒加载

- 所有页面组件使用 `React.lazy()` 动态导入
- 外层包裹 `<Suspense fallback={<Loading />}>` 提供加载态
- 懒加载导入路径使用 `@pages/` 层级别名

```typescript
const UserListPage = lazy(() => import('@pages/user-management/UserListPage'));
```

## 路径命名

- 路由路径使用小写 kebab-case：`/user-management`、`/order-detail`
- 动态参数使用 camelCase：`:userId`、`:orderId`
- 禁止在路径中使用大写字母或下划线

## 嵌套路由

- 父路由使用 `<Outlet />` 渲染子路由
- 布局组件（如侧边栏、顶栏）放在父路由的 `element` 中
- 避免超过 3 层嵌套

## 路由守卫

- 需要鉴权的路由通过高阶组件或 wrapper 组件实现守卫
- 守卫逻辑统一放在 `src/app/router/guards/` 下
- 未登录用户重定向到 `/login`，登录后回跳原地址

## 约束

- 禁止在组件内使用硬编码路径跳转，路径常量集中定义
- 404 页面必须配置兜底路由 `path: '*'`
- 路由参数通过 `useParams` 获取，查询参数通过 `useSearchParams` 获取
