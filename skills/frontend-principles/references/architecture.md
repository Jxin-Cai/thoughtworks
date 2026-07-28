# FSD (Feature-Sliced Design) 架构原则

## 架构全景

```
src/
├── app/          ← 应用层：全局配置、Provider、路由挂载
├── pages/        ← 页面层：路由入口，组合 widgets/features
├── widgets/      ← 组件块层（可选）：跨页面共享的独立 UI 区块
├── features/     ← 特性层：用户场景驱动的功能模块
├── entities/     ← 实体层：业务实体的 CRUD 和 UI 表达
├── shared/       ← 共享层：基础设施、原子组件、工具
└── assets/       ← 静态资源
```

## 单向依赖流

```
app → pages → widgets → features → entities → shared
```

**每层只能导入同层或下层，禁止逆向导入。**

---

## 五条设计原则

### P1: Feature as Vertical Slice — 一个 Feature 对应一个完整用户场景

**WHY**：Feature 不是组件库的抽屉——它是一个用户可感知的能力单元（如"创建订单"）。将 UI、状态、API 调用封装在一个 slice 内，修改时只触及一个目录。

**从此原则可推导**：
- Feature slice 包含 ui/、model/、api/、index.ts
- Feature 之间不互相导入——共同依赖下沉到 entities 或 shared
- 一个 Feature 修改不应该影响其他 Feature

### P2: Public API Boundary — 每个 slice 的 index.ts 是唯一对外出口

**WHY**：如果外部可以直接 import slice 内部文件，重构时任何内部移动都是 breaking change。index.ts 作为契约边界，内部结构可以自由重组。

**从此原则可推导**：
- 禁止穿透导入（`@features/xxx/ui/Component` ← 禁止）
- 未从 index.ts 导出的内容视为 slice 私有实现
- 使用层级别名（`@features/`、`@entities/`）简化导入

### P3: Entity as Business Concept — Entity 是业务实体的 UI 表达

**WHY**：Entity（如"订单"、"用户"）跨多个 Feature 共享。将实体的类型定义、CRUD hooks、展示组件集中在 entities/ 下，多个 Feature 复用而非各自重复。

**从此原则可推导**：
- Entity 包含类型定义、列表/详情查询 hooks、展示组件
- Feature 依赖 Entity（如 order-create feature 使用 order entity 的类型）
- Entity 不依赖任何 Feature

### P4: Server State Ownership — 服务端数据由 React Query 独占管理

**WHY**：将服务端数据复制到全局 store 会导致缓存不一致。React Query 负责请求去重、缓存失效、乐观更新，是服务端状态的唯一真相源。

**从此原则可推导**：
- 禁止将 API 数据复制到 zustand/Redux
- 所有数据获取通过 useQuery/useMutation
- 全局 store 仅管理纯客户端状态（用户信息、主题、locale）

### P5: Page as Composition Root — Page 只做组合，不做逻辑

**WHY**：Page 是路由入口的"画布"——它将 Feature 和 Widget 组件组合为完整页面，处理路由参数传递。如果 Page 里塞业务逻辑，同一个 Feature 就无法被另一个 Page 复用。

**从此原则可推导**：
- Page 组件不包含业务逻辑和 API 调用
- Page 只从路由提取参数，传递给 Feature/Widget 组件
- 复杂布局拆分为 Widget

---

## Slice 内部结构

```
features/order-create/
├── ui/           # 组件
├── model/        # 状态管理（hooks、store、types）
├── api/          # API 调用函数
├── lib/          # 工具函数
└── index.ts      # Public API
```

entities/ 结构相同。shared/ 按 segment 组织（api/、ui/、lib/、config/、types/）。

## 命名约定

| 类别 | 风格 |
|---|---|
| 组件 | PascalCase |
| hooks | useCamelCase |
| API 函数 | camelCase |
| 类型/接口 | PascalCase |
| 常量 | UPPER_SNAKE_CASE |
| 文件（非组件） | camelCase |
| slice 目录 | kebab-case |

## 路径别名

| 别名 | 映射 |
|------|------|
| `@app/` | `src/app/` |
| `@pages/` | `src/pages/` |
| `@widgets/` | `src/widgets/` |
| `@features/` | `src/features/` |
| `@entities/` | `src/entities/` |
| `@shared/` | `src/shared/` |

禁止使用相对路径跨 3 层以上，必须使用别名。同一 slice 内允许相对路径。
