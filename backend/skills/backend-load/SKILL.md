---
name: backend-load
description: Unified loader for backend DDD guide + spec (replaces separate backend-guide + backend-spec calls)
argument-hint: "<role> <layer> <language> e.g. thinker domain java, worker infr python"
---

# DDD 后端统一加载器

将 `backend-guide`（设计/编码指令）和 `backend-spec`（编码规范）合并为一次调用。

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

按以下顺序依次使用 Read 工具加载，每个 reference 之间用 `---` 分隔：

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
