---
name: thoughtworks-skills-backend-guide
description: Backend DDD layer-specific design and coding instructions router
argument-hint: "<role> <layer> e.g. thinker domain, worker infr"
disable-model-invocation: true
---

# DDD 层级指令加载器

用户传入的参数：`$ARGUMENTS`

## 路由规则

### 第一步：识别角色

从 `$ARGUMENTS` 中识别角色关键词：

| 关键词 | 角色 |
|--------|------|
| `thinker`、`design`、`think` | thinker |
| `worker`、`code`、`implement` | worker |

### 第二步：识别层级

从 `$ARGUMENTS` 中识别层级关键词：

| 关键词 | 层级 |
|--------|------|
| `domain` | domain |
| `infr`、`infrastructure`、`repository` | infr |
| `application`、`app` | application |
| `ohs`、`controller`、`handler` | ohs |

### 第三步：加载指令

根据角色和层级，读取对应的 reference 文件：

1. 始终加载公共指令：[references/{role}/common.md](references/{role}/common.md)
2. 追加加载层级指令：[references/{role}/{layer}.md](references/{role}/{layer}.md)

#### Thinker 路由

| 参数匹配 | 加载文件 |
|---|---|
| `thinker domain` | [references/thinker/common.md](references/thinker/common.md) + [references/thinker/domain.md](references/thinker/domain.md) |
| `thinker infr` | [references/thinker/common.md](references/thinker/common.md) + [references/thinker/infr.md](references/thinker/infr.md) |
| `thinker application` | [references/thinker/common.md](references/thinker/common.md) + [references/thinker/application.md](references/thinker/application.md) |
| `thinker ohs` | [references/thinker/common.md](references/thinker/common.md) + [references/thinker/ohs.md](references/thinker/ohs.md) |

#### Worker 路由

| 参数匹配 | 加载文件 |
|---|---|
| `worker domain` | [references/worker/common.md](references/worker/common.md) + [references/worker/domain.md](references/worker/domain.md) |
| `worker infr` | [references/worker/common.md](references/worker/common.md) + [references/worker/infr.md](references/worker/infr.md) |
| `worker application` | [references/worker/common.md](references/worker/common.md) + [references/worker/application.md](references/worker/application.md) |
| `worker ohs` | [references/worker/common.md](references/worker/common.md) + [references/worker/ohs.md](references/worker/ohs.md) |

如果 `$ARGUMENTS` 为空或无法匹配，提示用户可用的参数格式。

## 输出格式

每个 reference 之间用 `---` 分隔。
