---
name: frontend-load
description: Unified loader for frontend guide + spec (replaces separate frontend-guide + frontend-spec calls)
argument-hint: "<role> <layer> [stack] [style] e.g. thinker architecture react-ts, worker common react-ts"
---

# 前端统一加载器

将 `frontend-guide`（设计/编码指令）和 `frontend-spec`（编码规范）合并为一次调用。

用户传入的参数：`$ARGUMENTS`

## 路由规则

### 第一步：识别角色

| 关键词 | 角色 |
|--------|------|
| `thinker`、`design`、`think` | thinker |
| `worker`、`code`、`implement` | worker |

### 第二步：识别层级

| 关键词 | 层级 |
|--------|------|
| `architecture`、`arch` | architecture |
| `components`、`component`、`comp` | components |
| `checklist`、`check` | checklist |
| `frontend`、`common` | common（Worker 通用） |

### 第三步：识别技术栈

| 关键词 | 技术栈 |
|--------|--------|
| `react-ts`、`react` | react-ts |
| 无匹配 | react-ts（默认） |

### 第四步：识别 UI 风格（可选）

| 关键词 | 风格 |
|--------|------|
| `minimalist-luxury` | minimalist-luxury |
| `tech-futuristic` | tech-futuristic |
| `classic-elegant` | classic-elegant |

### 第五步：加载文件

按以下顺序依次使用 Read 工具加载，每个 reference 之间用 `---` 分隔：

#### Thinker 模式

1. **Guide 公共指令**：`../frontend-guide/references/thinker/common.md`
2. **Guide 层级指令**：`../frontend-guide/references/thinker/{layer}.md`
3. **Spec 公共规范**：`../frontend-spec/references/common.md`
4. **Spec 技术栈规范**（全部）：
   - `../frontend-spec/references/{stack}/components.md`
   - `../frontend-spec/references/{stack}/api-client.md`
   - `../frontend-spec/references/{stack}/routing.md`
   - `../frontend-spec/references/{stack}/state.md`
5. **UI 风格规范**（如指定）：`../frontend-spec/references/ui-styles/{style}.md`

#### Worker 模式

1. **Guide Worker 公共指令**：`../frontend-guide/references/worker/common.md`
2. **Spec 公共规范**：`../frontend-spec/references/common.md`
3. **Spec 技术栈规范**（全部）：
   - `../frontend-spec/references/{stack}/components.md`
   - `../frontend-spec/references/{stack}/api-client.md`
   - `../frontend-spec/references/{stack}/routing.md`
   - `../frontend-spec/references/{stack}/state.md`
4. **UI 风格规范**（如指定）：`../frontend-spec/references/ui-styles/{style}.md`

如果 `$ARGUMENTS` 为空或无法匹配，提示用户可用的参数格式：`/frontend-load <role> <layer> [stack] [style]`。
