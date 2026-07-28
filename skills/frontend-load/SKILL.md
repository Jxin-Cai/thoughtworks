---
name: frontend-load
description: 前端统一加载器——加载 FSD 架构原则、角色手册、参考实现和技术栈约定
argument-hint: "<role> <stack> [style] e.g. thinker react-ts, worker react-ts minimalist-luxury"
---

# 前端统一加载器

加载 FSD 架构原则 + 角色手册 + 参考实现 + 技术栈约定 + 可选 UI 风格。

用户传入的参数：`$ARGUMENTS`

## 何时调用

- Thinker：完成需求与项目扫描后、开始写设计方案前
- Worker：完成项目结构扫描后、开始写代码前

禁止在 agent 启动时提前加载。

## 路由规则

### 第一步：识别角色

| 关键词 | 角色 |
|--------|------|
| `thinker`、`design` | thinker |
| `worker`、`code` | worker |

### 第二步：识别技术栈

| 关键词 | 栈 |
|--------|---|
| `react-ts`、`react`、`typescript` | react-ts |

未指定时默认 `react-ts`。

### 第三步：识别 UI 风格（可选）

| 关键词 | 风格文件 |
|--------|---------|
| `minimalist-luxury`、`minimalist` | `../frontend-spec/references/ui-styles/minimalist-luxury.md` |
| `tech-futuristic`、`tech` | `../frontend-spec/references/ui-styles/tech-futuristic.md` |
| `classic-elegant`、`classic` | `../frontend-spec/references/ui-styles/classic-elegant.md` |

### 第四步：加载文件

按以下顺序依次用 Read 工具加载，文件间用 `---` 分隔：

1. **架构原则**：`../frontend-principles/references/architecture.md`
2. **角色手册**：`../frontend-principles/references/{role}-playbook.md`
3. **参考实现**：`../frontend-principles/references/{stack}/reference-impl.md`
4. **技术栈约定**：`../frontend-principles/references/{stack}/conventions.md`
5. （如有 style）**UI 风格规范**：对应的 ui-styles 文件

如果 `$ARGUMENTS` 为空，提示用户格式：`/frontend-load <role> <stack> [style]`。
