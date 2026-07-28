---
name: backend-principles
description: DDD 架构原则、设计手册与实现手册（垂直子域模式）
argument-hint: "<role> <language> — 例：thinker java, worker python"
---

# 后端原则加载器

根据角色和语言加载对应的原则与参考实现文件。

## 路由规则

**输入格式**：`/backend-principles <role> <language>`

### 角色映射

| 关键词 | 角色 |
|--------|------|
| `thinker` / `design` / `设计` | thinker |
| `worker` / `code` / `实现` | worker |

### 语言映射

| 关键词 | 语言 |
|--------|------|
| `java` / `spring` | java |
| `python` / `fastapi` | python |
| `go` / `gin` | go |

未指定语言时默认 `java`。

## 加载顺序

依次用 Read 工具读取以下文件，文件间用 `---` 分隔输出：

1. `{THIS_SKILL}/references/architecture.md` — 架构原则
2. `{THIS_SKILL}/references/{role}-playbook.md` — 角色手册
3. `{THIS_SKILL}/references/{lang}/reference-impl.md` — 参考实现
4. `{THIS_SKILL}/references/{lang}/conventions.md` — 语言约定
