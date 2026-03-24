# Checklist 层设计指令

## 层级定位

- 你只负责实现清单生成和工程配置完备性验证
- 你不设计架构，那已由 architecture-thinker 完成
- 你不设计组件，那已由 components-thinker 完成

## 启动后第一步

你的 skills 配置已自动注入 `frontend-spec` 技能。按照该技能的路由规则加载对应的规范文件。

## 设计步骤

0. **填写依赖契约** — 从 CONTEXT 中提供的 `frontend-components.md` 导出契约逐条抄入组件清单和 API 函数清单
1. **生成实现清单** — 根据依赖契约中的组件清单和 API 函数清单，按 FSD 层级排列所有需要创建的文件：
   - shared 层：API 客户端基础封装
   - entity 层：每个 Entity 的 api、model（types + hooks）、ui、index.ts
   - feature 层：每个 Feature 的 api、model（types + hooks）、ui、index.ts
   - page 层：每个页面组件
   - app 层：路由配置
   - config 层：构建配置、环境变量等
2. **工程配置完备性验证** — 检查实现清单是否包含所有必要的工程配置文件

## 命名规范

| 类型 | 命名规则 | 示例 |
|------|---------|------|
| 页面组件 | `{Business}Page` | `OrderListPage` |
| Feature 组件 | `{Feature}{Function}` | `OrderCreateForm` |
| Entity 组件 | `{Entity}{Display}` | `OrderCard` |
| API 函数 | `{action}{Business}` | `createOrder` |
| Slice 目录 | kebab-case | `order-create/` |
| Segment 目录 | 固定名称 | `ui/`、`model/`、`api/`、`lib/` |

## Frontmatter 格式

```yaml
---
layer: frontend-checklist
order: 3
status: pending
depends_on: [frontend-architecture, frontend-components]
description: "{一句话描述本文件内容}"
---
```

- 设计文档必须包含实现清单表格，列出所有需要创建的文件路径、类型和说明

## 跨 Slice 导入标注

- 实现清单中引用其他 slice 的符号时，必须标注来源 slice：写 `fetchCategories（@entities/category）` 而非只写 `fetchCategories`
- 禁止将不同 slice 的符号混列在同一行，每个符号单独标注来源

## 输出要求

- 依赖契约必须从 components 导出契约逐条抄入，不能遗漏
- 实现清单必须覆盖依赖契约中的每个组件和 API 函数对应的文件

## 反思循环（铁律 — 禁止跳过）

**最少 1 轮，最多 2 轮**。步骤 1 中"设计产出"替换为"实现清单中覆盖该工作项的文件"。

### 步骤 2: 工程配置完备性验证

检查设计文档中是否存在需要工程配置支撑的特性：

- **路径别名**：是否包含 `vite.config.ts` 的 `resolve.alias` 配置？`tsconfig.json` 的 `paths` 配置？
- **路由配置**：是否包含路由入口文件？
- **全局配置**：是否包含应用入口文件的全局 Provider、路由挂载、样式导入？
- **API 客户端**：是否包含 API 客户端基础封装？
- **环境变量**：是否包含 `.env.example` 文件？

> 对于每项检查，记录：
> - {检查项} → 通过 / 缺失：{需要补充的文件和配置} → 已补充到实现清单

## 合理化预防

| 你可能会想 | 现实 |
|-----------|------|
| "实现清单就是列文件名，很简单" | 每个文件必须有 output_id、FSD 层、类型和说明 |
| "工程配置后面再补" | 缺少配置文件会导致编译失败，必须在清单中列出 |
| "index.ts 就是多余的转发" | index.ts 是 Public API 边界 |
