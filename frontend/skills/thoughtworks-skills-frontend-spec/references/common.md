# 通用前端规范

## 目录结构

```
src/
├── pages/          # 页面级组件，按路由组织
├── components/     # 可复用业务组件
├── api/            # API 调用函数，按资源分文件
├── types/          # TypeScript 类型定义
├── hooks/          # 自定义 hooks
├── utils/          # 工具函数
├── router/         # 路由配置
└── assets/         # 静态资源
```

## TypeScript 要求

- 启用 `strict: true`，不允许降级任何 strict 子选项
- 禁止使用 `any` 类型；必要时用 `unknown` 替代并做类型收窄
- 所有函数参数和返回值必须显式标注类型

## 命名约定

| 类别 | 风格 | 示例 |
|---|---|---|
| 组件 | PascalCase | `UserProfile.tsx` |
| hooks | useCamelCase | `useUserList.ts` |
| API 函数 | camelCase | `getUserById` |
| 类型 / 接口 | PascalCase | `UserResponse` |
| 常量 | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| 文件（非组件） | camelCase | `formatDate.ts` |

## API 响应统一类型

```typescript
interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}
```

所有 API 函数返回值必须使用 `Promise<ApiResponse<T>>` 包装。

## 错误处理

- HTTP 错误（4xx/5xx）：由全局响应拦截器统一处理，弹出通用错误提示
- 业务错误（`code !== 0`）：由调用方组件根据业务场景自行处理
- 网络异常：拦截器捕获并提示用户检查网络

## 环境变量

- API base URL 通过环境变量 `VITE_API_BASE_URL`（Vite）或 `REACT_APP_API_BASE_URL`（CRA）配置
- 禁止在代码中硬编码后端地址
- `.env.example` 必须提交到仓库，`.env.local` 加入 `.gitignore`
