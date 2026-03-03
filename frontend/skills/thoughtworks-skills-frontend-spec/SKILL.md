---
name: thoughtworks-skills-frontend-spec
description: Use when working on frontend projects consuming DDD API contracts. Loads tech-stack-specific coding constraints. Invoke with /thoughtworks-skills-frontend-spec [stack] to get targeted rules.
argument-hint: "<stack> e.g. react-ts, all"
disable-model-invocation: true
---

# 前端项目规范加载器

用户传入的参数：`$ARGUMENTS`

## 路由规则

始终读取 [references/common.md](references/common.md) 作为基础规范。

然后根据 `$ARGUMENTS` 中包含的关键词加载对应技术栈规范（可叠加）：

| 关键词匹配 | 加载文件 |
|---|---|
| `react-ts`、`react` | [references/react-ts/components.md](references/react-ts/components.md) + [references/react-ts/api-client.md](references/react-ts/api-client.md) + [references/react-ts/routing.md](references/react-ts/routing.md) + [references/react-ts/state.md](references/react-ts/state.md) |
| `all` | 加载以上全部 references |

如果 `$ARGUMENTS` 为空或无法匹配任何关键词，仅输出 common.md 并提示用户可用的技术栈参数。

## 输出格式

每个 reference 之间用 `---` 分隔。
