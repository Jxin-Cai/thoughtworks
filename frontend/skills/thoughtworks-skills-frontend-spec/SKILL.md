---
name: thoughtworks-skills-frontend-spec
description: Frontend coding spec router for tech-stack-specific constraints
argument-hint: "<stack> e.g. react-ts, all | [ui-style] e.g. minimalist-luxury"
---

# 前端项目规范加载器

用户传入的参数：`$ARGUMENTS`

## 路由规则

始终读取 [references/common.md](references/common.md) 作为基础规范。

然后根据 `$ARGUMENTS` 中包含的关键词加载对应规范（可叠加）：

### 技术栈规范

| 关键词匹配 | 加载文件 |
|---|---|
| `react-ts`、`react` | [references/react-ts/components.md](references/react-ts/components.md) + [references/react-ts/api-client.md](references/react-ts/api-client.md) + [references/react-ts/routing.md](references/react-ts/routing.md) + [references/react-ts/state.md](references/react-ts/state.md) |
| `all` | 加载以上全部 references |

### UI 风格规范

| 关键词匹配 | 加载文件 |
|---|---|
| `minimalist-luxury` | [references/ui-styles/minimalist-luxury.md](references/ui-styles/minimalist-luxury.md) |
| `tech-futuristic` | [references/ui-styles/tech-futuristic.md](references/ui-styles/tech-futuristic.md) |
| `classic-elegant` | [references/ui-styles/classic-elegant.md](references/ui-styles/classic-elegant.md) |

如果 `$ARGUMENTS` 为空或无法匹配任何关键词，仅输出 common.md 并提示用户可用的技术栈参数和 UI 风格参数。

## 输出格式

每个 reference 之间用 `---` 分隔。
