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

## 组件分层

| 类型 | 目录 | 职责 |
|---|---|---|
| 页面组件 | `src/pages/` | 数据获取、布局编排、路由参数处理 |
| 业务组件 | `src/components/` | UI 渲染、用户交互、事件回调 |

- 页面组件通过 hooks 获取数据，将数据作为 props 传递给业务组件
- 业务组件不直接调用 API，保持纯展示 + 回调模式

## 数据获取

- 禁止在组件内直接调用 `axios` / `fetch`
- 所有数据获取封装到 `src/hooks/` 下的自定义 hook 中
- hook 内部使用 React Query 管理请求状态

## 表单处理

- 使用受控组件模式
- 表单验证逻辑集中在提交时或 `onBlur` 时执行
- 复杂表单推荐使用 `react-hook-form`
- 验证规则与错误提示就近定义，不分散到多个文件

## 其他约束

- 单个组件文件不超过 200 行；超出则拆分子组件
- 每个组件文件只导出一个组件
- 事件处理函数命名：`handle{Event}`（如 `handleSubmit`、`handleClick`）
