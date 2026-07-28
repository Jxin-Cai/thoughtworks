---
name: backend-load
description: DDD 后端统一加载器——加载架构原则、角色手册、参考实现和语言约定
argument-hint: "<role> <language> e.g. thinker java, worker python"
---

# DDD 后端统一加载器

加载 DDD 架构原则 + 角色手册 + 参考实现 + 语言约定。

用户传入的参数：`$ARGUMENTS`

## 何时调用

**标准 DDD thinker / worker 链路**：在完成项目扫描后、准备开始产出前调用。

- Thinker：完成需求与上游扫描后、开始写设计方案前
- Worker：完成项目结构扫描后、开始第一处代码写入前

禁止在 agent 启动瞬间提前加载。

**普通后端设计/编码场景**：任务进入后端方案设计或代码实现时，也应在开始产出前调用补充约束。

## 路由规则

### 第一步：识别角色

| 关键词 | 角色 |
|--------|------|
| `thinker`、`design`、`think` | thinker |
| `worker`、`code`、`implement` | worker |

### 第二步：识别语言

| 关键词 | 语言 |
|--------|------|
| `python`、`py`、`fastapi` | python |
| `go`、`golang`、`gin` | go |
| `java`、`spring`、`mybatis`、其他或无关键词 | java（默认） |

### 第三步：加载文件

按以下顺序依次使用 Read 工具加载，每个文件之间用 `---` 分隔：

1. **架构原则**：`../backend-principles/references/architecture.md`
2. **角色手册**：`../backend-principles/references/{role}-playbook.md`
3. **参考实现**：`../backend-principles/references/{lang}/reference-impl.md`
4. **语言约定**：`../backend-principles/references/{lang}/conventions.md`

如果 `$ARGUMENTS` 为空或无法匹配，提示用户可用的参数格式：`/backend-load <role> <language>`。
