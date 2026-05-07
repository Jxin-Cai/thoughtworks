---
name: backend-load
description: Unified loader for backend DDD guide + spec (replaces separate backend-guide + backend-spec calls)
argument-hint: "<role> <layer> <language> e.g. thinker domain java, worker infr python"
---

# DDD 后端统一加载器

将 `backend-guide`（设计/编码指令）和 `backend-spec`（编码规范）合并为一次调用。

用户传入的参数：`$ARGUMENTS`

## 何时调用

### 标准 DDD thinker / worker 链路

在完成项目扫描、上游代码扫描并明确 `target_layer` 与 `backend_language` 后调用。
**最佳时机是：准备开始输出设计方案，或准备开始第一处代码写入之前立即调用。**

- Thinker：完成需求与上游上下文扫描后、开始写方案前调用
- Worker：完成项目结构与已有代码扫描、形成实现方案后、开始第一处 `Write` / `Edit` 前调用

禁止在 agent 启动瞬间提前加载，避免规范在后续扫描上下文中被压缩。

### 普通直接后端设计 / 编码场景

如果用户没有走 `/backend`、`/backend-thought`、`/backend-works` 等编排入口，但任务已经进入后端某层的方案设计或代码实现，也应在开始产出前调用本技能补充分层约束。

## 路由规则

### 第一步：识别角色

| 关键词 | 角色 |
|--------|------|
| `thinker`、`design`、`think` | thinker |
| `worker`、`code`、`implement` | worker |

### 第二步：识别层级

| 关键词 | 层级 |
|--------|------|
| `domain` | domain |
| `infr`、`infrastructure`、`repository` | infr |
| `application`、`app` | application |
| `ohs`、`controller`、`handler` | ohs |

### 第三步：识别语言

| 关键词 | 语言 |
|--------|------|
| `python`、`py`、`fastapi`、`sqlalchemy`、`pydantic` | python |
| `go`、`golang`、`gin`、`gorm` | go |
| `java`、`spring`、`mybatis`、其他或无语言关键词 | java（默认） |

### 第四步：加载文件

按以下顺序依次使用 Read 工具加载，每个 reference 之间用 `---` 分隔。
在标准 DDD 链路中，优先使用本技能一次性加载 guide + spec，不要手工拆成 `/backend-guide` + `/backend-spec` 两次调用：

1. **Guide 公共指令**：`../backend-guide/references/{role}/common.md`
2. **Guide 层级指令**：`../backend-guide/references/{role}/{layer}.md`
3. **Spec 语言公共规范**：`../backend-spec/references/{lang}/common.md`
4. **Spec 层级规范**：`../backend-spec/references/{lang}/{layer-mapping}.md`

层级到 spec 文件映射：

| 层级 | Spec 文件 |
|------|----------|
| domain | `{lang}/domain.md` |
| application | `{lang}/application.md` |
| ohs | `{lang}/ohs.md` |
| infr | `{lang}/infrastructure.md` + `{lang}/database.md` |

如果 `$ARGUMENTS` 为空或无法匹配，提示用户可用的参数格式：`/backend-load <role> <layer> <language>`。
