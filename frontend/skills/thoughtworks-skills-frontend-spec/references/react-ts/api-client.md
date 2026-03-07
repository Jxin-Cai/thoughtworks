# API 调用层规范

## 封装基础

- 基于 `axios` 创建统一实例，配置 `baseURL`、`timeout`、默认 headers
- 如项目不引入 axios，可基于 `fetch` 封装等效的 `request` 函数
- API 客户端基础封装位于 `src/shared/api/`

```typescript
// src/shared/api/client.ts
const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  timeout: 10000,
});
```

## 文件组织（FSD 三层）

| FSD 层 | 位置 | 职责 | 示例 |
|--------|------|------|------|
| Shared | `src/shared/api/` | API 客户端实例、拦截器、通用请求封装 | `client.ts`、`interceptors.ts` |
| Entity | `src/entities/{entity}/api/` | 实体 CRUD 接口 | `entities/user/api/userApi.ts` |
| Feature | `src/features/{feature}/api/` | 场景专属接口（组合多个实体操作） | `features/order-create/api/createOrder.ts` |

- 类型定义放在各 slice 内 `model/types.ts`，不再集中到 `src/types/`
- 拦截器文件位于 `src/shared/api/interceptors.ts`

## 拦截器

请求拦截器：
- 从存储中读取 token，注入 `Authorization` header
- 设置 `Content-Type: application/json`

响应拦截器：
- 2xx 响应：直接返回 `response.data`（即 `ApiResponse<T>`）
- 401：清除本地 token，跳转登录页
- 其他错误：抛出统一格式的错误对象，由上层处理

## API 函数签名

每个端点对应一个导出函数，签名严格标注请求和响应类型：

```typescript
// src/entities/user/api/userApi.ts
export async function createUser(
  params: CreateUserRequest
): Promise<ApiResponse<UserResponse>> {
  return apiClient.post('/users', params);
}

export async function getUserById(
  id: string
): Promise<ApiResponse<UserResponse>> {
  return apiClient.get(`/users/${id}`);
}
```

## 约束

- 禁止在 API 函数中处理 UI 逻辑（如 toast、redirect）
- 禁止在 API 层做数据转换；数据映射放在 hook 或 service 层
- 分页接口统一使用 `PageRequest` / `PageResponse<T>` 类型
- DELETE 请求如无响应体，返回类型为 `Promise<ApiResponse<void>>`
