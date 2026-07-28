---
name: frontend-principles
description: FSD 架构原则、设计手册与实现手册（垂直 Feature 模式）
argument-hint: "<role> <stack> [style] — 例：thinker react-ts, worker react-ts minimalist-luxury"
---

# 前端原则加载器

根据角色和技术栈加载对应的原则与参考实现文件。

## 路由规则

**输入格式**：`/frontend-principles <role> <stack> [style]`

### 角色映射

| 关键词 | 角色 |
|--------|------|
| `thinker` / `design` | thinker |
| `worker` / `code` | worker |

### 技术栈映射

| 关键词 | 栈 |
|--------|---|
| `react-ts` / `react` / `typescript` | react-ts |

### UI 风格（可选）

| 关键词 | 风格 |
|--------|------|
| `minimalist-luxury` / `minimalist` | minimalist-luxury |
| `tech-futuristic` / `tech` | tech-futuristic |
| `classic-elegant` / `classic` | classic-elegant |

## 加载顺序

依次用 Read 工具读取，文件间用 `---` 分隔：

1. `{THIS_SKILL}/references/architecture.md` — FSD 架构原则
2. `{THIS_SKILL}/references/{role}-playbook.md` — 角色手册
3. `{THIS_SKILL}/references/{stack}/reference-impl.md` — 参考实现
4. `{THIS_SKILL}/references/{stack}/conventions.md` — 技术栈约定
5. （如有 style）`../frontend-spec/references/ui-styles/{style}.md` — UI 风格规范
