# 通用前端规范

## 目录结构（Feature-Sliced Design）

```
src/
├── app/            # 应用层 — 全局配置、Provider、路由挂载、样式入口
│   ├── router/     # 路由配置
│   ├── providers/  # 全局 Provider（QueryClient、Theme 等）
│   └── styles/     # 全局样式
├── pages/          # 页面层 — 路由入口组件，组合 widgets 和 features
├── widgets/        # 组件块层（可选）— 跨页面共享的独立 UI 区块
├── features/       # 特性层 — 用户场景驱动的功能模块
├── entities/       # 实体层 — 业务实体的 CRUD 和 UI 表达
├── shared/         # 共享层 — 基础设施、UI 原子组件、工具函数
│   ├── api/        # API 客户端基础封装
│   ├── ui/         # 通用 UI 组件（Button、Modal、Table 等）
│   ├── lib/        # 工具函数
│   ├── config/     # 全局配置、常量、store
│   └── types/      # 全局共享类型
└── assets/         # 静态资源（图片、字体、图标）
```

## 层级单向依赖规则

```
app → pages → widgets → features → entities → shared
```

- 每层只能导入**同层或下层**的模块，**禁止逆向导入**
- `features/` 不能导入 `pages/` 或 `widgets/`
- `entities/` 不能导入 `features/`、`widgets/` 或 `pages/`
- `shared/` 不能导入任何上层

## Slice 内聚规则

每个 slice（`features/{feature-name}/`、`entities/{entity-name}/`）内部按 segment 组织：

```
features/order-create/
├── ui/           # 组件（页面局部 UI、表单、列表等）
├── model/        # 状态管理（hooks、store、types）
├── api/          # 该 feature 的 API 调用函数
├── lib/          # 该 feature 的工具函数
└── index.ts      # Public API — 唯一对外导出
```

## Public API 规范

- 每个 slice 的 `index.ts` 是唯一对外出口
- 外部模块只能通过 `index.ts` 导入：`import { OrderForm } from '@features/order-create'`
- **禁止穿透导入**：`import { OrderForm } from '@features/order-create/ui/OrderForm'` ← 禁止
- `index.ts` 中显式 re-export 需要暴露的内容，未导出的视为 slice 内部实现

## 路径别名

使用层级别名简化导入路径：

| 别名 | 映射 |
|------|------|
| `@app/` | `src/app/` |
| `@pages/` | `src/pages/` |
| `@widgets/` | `src/widgets/` |
| `@features/` | `src/features/` |
| `@entities/` | `src/entities/` |
| `@shared/` | `src/shared/` |
| `@/` | `src/`（兜底，用于 assets 等） |

- **Vite 项目**必须在 `vite.config.ts` 中配置 `resolve.alias`：

  ```typescript
  import path from 'path';
  export default defineConfig({
    resolve: {
      alias: {
        '@app': path.resolve(__dirname, './src/app'),
        '@pages': path.resolve(__dirname, './src/pages'),
        '@widgets': path.resolve(__dirname, './src/widgets'),
        '@features': path.resolve(__dirname, './src/features'),
        '@entities': path.resolve(__dirname, './src/entities'),
        '@shared': path.resolve(__dirname, './src/shared'),
        '@': path.resolve(__dirname, './src'),
      },
    },
  });
  ```

- **TypeScript** 必须在 `tsconfig.json`（或 `tsconfig.app.json`）中配置 `paths`：

  ```json
  {
    "compilerOptions": {
      "baseUrl": ".",
      "paths": {
        "@app/*": ["src/app/*"],
        "@pages/*": ["src/pages/*"],
        "@widgets/*": ["src/widgets/*"],
        "@features/*": ["src/features/*"],
        "@entities/*": ["src/entities/*"],
        "@shared/*": ["src/shared/*"],
        "@/*": ["src/*"]
      }
    }
  }
  ```

- 禁止使用相对路径跨 3 层以上目录（如 `../../../shared/`），必须使用层级别名
- 同一 slice 内部允许使用相对路径

## 命名约定

| 类别 | 风格 |
|---|---|
| 组件 | PascalCase |
| hooks | useCamelCase |
| API 函数 | camelCase |
| 类型 / 接口 | PascalCase |
| 常量 | UPPER_SNAKE_CASE |
| 文件（非组件） | camelCase |
| slice 目录 | kebab-case |
| segment 目录 | 固定名称 |

## TypeScript 要求

- 启用 `strict: true`，不允许降级任何 strict 子选项
- 禁止使用 `any` 类型；必要时用 `unknown` 替代并做类型收窄
- 所有函数参数和返回值必须显式标注类型

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
