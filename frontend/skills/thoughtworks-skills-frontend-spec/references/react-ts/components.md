# React + TypeScript 组件规范

## 组件声明

- 使用函数声明，不推荐 `React.FC`：

```typescript
// 推荐
function UserProfile({ name, age }: UserProfileProps) {
  return <div>{name}</div>;
}

// 不推荐
const UserProfile: React.FC<UserProfileProps> = ({ name, age }) => { ... };
```

## Props 定义

- 使用 `interface` 定义 Props，命名为 `{ComponentName}Props`
- 必须为每个 prop 添加 JSDoc 注释
- 可选 prop 使用 `?` 标注，提供默认值用解构赋值

```typescript
interface UserProfileProps {
  /** 用户名称 */
  name: string;
  /** 年龄，默认不显示 */
  age?: number;
}
```

## 组件分层（FSD）

| FSD 层 | 目录 | 职责 | 示例 |
|--------|------|------|------|
| Pages | `src/pages/` | 路由入口，组合 Features 和 Widgets，处理路由参数 | `OrderListPage` |
| Widgets | `src/widgets/` | 跨页面共享的独立 UI 区块（可选层） | `HeaderNavigation`、`SidebarMenu` |
| Features | `src/features/{feature}/ui/` | 用户场景驱动的功能组件（含交互逻辑） | `OrderCreateForm`、`OrderFilter` |
| Entities | `src/entities/{entity}/ui/` | 业务实体的 UI 表达（纯展示为主） | `OrderCard`、`UserAvatar` |
| Shared | `src/shared/ui/` | 通用原子组件（与业务无关） | `Button`、`Modal`、`Table` |

### 层级职责边界

- **Pages** — 只做组合和路由参数处理，不包含业务逻辑，将 Feature 和 Widget 组件拼装为完整页面
- **Widgets** — 可跨页面复用的 UI 区块，可组合多个 Feature 和 Entity 组件
- **Features** — 一个 Feature 对应一个用户场景（如"创建订单"），包含该场景的组件、状态、API 调用
- **Entities** — 一个 Entity 对应一个业务实体（如"订单"），包含该实体的展示组件、CRUD hooks、类型定义
- **Shared** — 与业务完全无关的基础组件和工具

### Feature 组件结构示例

```
src/features/order-create/
├── ui/
│   ├── OrderCreateForm.tsx     # 表单组件
│   └── OrderCreateDialog.tsx   # 弹窗容器（可选）
├── model/
│   ├── useCreateOrder.ts       # 创建订单的 mutation hook
│   └── types.ts                # 该 feature 专属类型
├── api/
│   └── createOrder.ts          # API 调用函数
└── index.ts                    # 导出：OrderCreateForm, useCreateOrder
```

## 数据获取

- 禁止在组件内直接调用 `axios` / `fetch`
- Entity 层的数据获取 hook 放在 `entities/{entity}/model/`（如 `useUserList`、`useOrderDetail`）
- Feature 层的数据获取 hook 放在 `features/{feature}/model/`（如 `useCreateOrder`、`useOrderFilter`）
- hook 内部使用 React Query 管理请求状态

## 表单处理

- 使用受控组件模式
- 表单验证逻辑集中在提交时或 `onBlur` 时执行
- 复杂表单推荐使用 `react-hook-form`
- 验证规则与错误提示就近定义，不分散到多个文件
- **表单事件与校验策略必须一致**：若使用 UI 框架内置校验回调（如 Ant Design `@finish`、Element Plus `@submit`），则表单项必须完整配置 `model`/`name`/`rules`；若使用手动校验，则使用原生 `@submit.prevent` / `onSubmit`。禁止混用两种模式

## 其他约束

- 单个组件文件不超过 200 行；超出则拆分子组件
- 每个组件文件只导出一个组件
- 事件处理函数命名：`handle{Event}`（如 `handleSubmit`、`handleClick`）
