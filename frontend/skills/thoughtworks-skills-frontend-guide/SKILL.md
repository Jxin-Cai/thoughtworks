---
name: thoughtworks-skills-frontend-guide
description: Frontend layer-specific design and coding instructions router
argument-hint: "<role> <layer> e.g. thinker architecture, thinker components, worker frontend"
disable-model-invocation: true
---

# 前端层级指令加载器

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
| `architecture`、`arch` | architecture |
| `components`、`component`、`comp` | components |
| `checklist`、`check` | checklist |
| `frontend`、`common` | common（Worker 通用） |

### 第三步：加载指令

#### Thinker 路由

| 参数匹配 | 加载文件 |
|---|---|
| `thinker architecture` | [references/thinker/architecture.md](references/thinker/architecture.md) |
| `thinker components` | [references/thinker/components.md](references/thinker/components.md) |
| `thinker checklist` | [references/thinker/checklist.md](references/thinker/checklist.md) |

#### Worker 路由

| 参数匹配 | 加载文件 |
|---|---|
| `worker frontend` | [references/worker/common.md](references/worker/common.md) |
| `worker common` | [references/worker/common.md](references/worker/common.md) |

如果 `$ARGUMENTS` 为空或无法匹配，提示用户可用的参数格式。

## 输出格式

每个 reference 之间用 `---` 分隔。
