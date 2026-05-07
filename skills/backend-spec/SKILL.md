---
name: backend-spec
description: Backend layer-specific design and coding constraints. In direct backend planning/coding scenarios, proactively load before writing solutions or code when the task touches domain/application/infr/ohs.
argument-hint: "<language> <layer> e.g. java domain, python application, go ohs, java all"
---

# DDD 后端项目规范加载器

用户传入的参数：`$ARGUMENTS`

## 何时应主动调用

### 普通直接后端设计 / 编码场景

当用户没有走 `/backend`、`/backend-thought`、`/backend-works` 等标准编排入口，但当前任务已经进入后端某层的方案设计、代码实现、重构、补接口、补仓储、改 controller / handler 等场景时，应主动调用本技能补充约束。

### 最佳调用时机

先完成代码仓扫描、文件路径识别和目标层判断，再在**开始输出方案或开始修改代码之前**立即调用。
不要太早加载，避免规范被后续扫描上下文压缩。

### 典型触发信号

- **层级关键词**：domain、aggregate、entity、value object、domain service、application、command、repository、controller、handler、dto、request、response
- **文件路径信号**：`domain/`、`application/`、`infr/`、`repository/`、`controller/`、`handler/`
- **任务动作信号**：设计 application service、实现 repository、补 handler、设计领域模型、补 DTO / persistence model

### 与 backend-load 的关系

标准 DDD thinker / worker 流程优先通过 `backend-load` 一次性加载 guide + spec；本技能不替代该统一入口。
当你处于普通直接后端设计 / 编码场景，且需要快速补充语言与层级约束时，应主动调用本技能。

## 路由规则

### 第一步：识别语言

从 `$ARGUMENTS` 中识别语言关键词：

| 关键词 | 语言 |
|--------|------|
| `python`、`py`、`fastapi`、`sqlalchemy`、`pydantic` | python |
| `go`、`golang`、`gin`、`gorm` | go |
| `java`、`spring`、`mybatis`、其他或无语言关键词 | java（默认） |

### 第二步：加载公共规范

根据识别出的语言，始终读取对应的公共规范：

- Java → [references/java/common.md](references/java/common.md)
- Python → [references/python/common.md](references/python/common.md)
- Go → [references/go/common.md](references/go/common.md)

### 第三步：加载层级规范

根据 `$ARGUMENTS` 中包含的层级关键词，再追加读取对应层级规范（可叠加）：

#### Java 路由

| 关键词匹配 | 加载文件 |
|---|---|
| `ohs` | [references/java/ohs.md](references/java/ohs.md) |
| `application` | [references/java/application.md](references/java/application.md) |
| `domain` | [references/java/domain.md](references/java/domain.md) |
| `infr`（但不含 `infr/repository`） | [references/java/infrastructure.md](references/java/infrastructure.md) |
| `infr/repository`、`mapper`、`Mapper`、`PO` | [references/java/infrastructure.md](references/java/infrastructure.md) + [references/java/database.md](references/java/database.md) |
| `database`、`db`、`sql`、`mybatis` | [references/java/database.md](references/java/database.md) |
| `all` | 加载 Java 下全部 references |

#### Python 路由

| 关键词匹配 | 加载文件 |
|---|---|
| `ohs` | [references/python/ohs.md](references/python/ohs.md) |
| `application` | [references/python/application.md](references/python/application.md) |
| `domain` | [references/python/domain.md](references/python/domain.md) |
| `infr`（但不含 `infr/repository`） | [references/python/infrastructure.md](references/python/infrastructure.md) |
| `infr/repository`、`model`、`sqlalchemy`、`repository_impl` | [references/python/infrastructure.md](references/python/infrastructure.md) + [references/python/database.md](references/python/database.md) |
| `database`、`db`、`sql`、`sqlalchemy`、`alembic` | [references/python/database.md](references/python/database.md) |
| `all` | 加载 Python 下全部 references |

#### Go 路由

| 关键词匹配 | 加载文件 |
|---|---|
| `ohs` | [references/go/ohs.md](references/go/ohs.md) |
| `application` | [references/go/application.md](references/go/application.md) |
| `domain` | [references/go/domain.md](references/go/domain.md) |
| `infr`（但不含 `infr/repository`） | [references/go/infrastructure.md](references/go/infrastructure.md) |
| `infr/repository`、`model`、`gorm`、`repository_impl` | [references/go/infrastructure.md](references/go/infrastructure.md) + [references/go/database.md](references/go/database.md) |
| `database`、`db`、`sql`、`gorm`、`migrate` | [references/go/database.md](references/go/database.md) |
| `all` | 加载 Go 下全部 references |

如果 `$ARGUMENTS` 是一个完整文件路径（如 `src/main/java/.../infr/repository/UserMapper.java`、`app/infr/order_repository_impl.py`、`internal/infr/repository/order_repository_impl.go`），从路径中提取语言和层级关键词进行匹配。

如果 `$ARGUMENTS` 为空或无法匹配任何关键词，仅输出对应语言的 common.md，并提示用户可用的语言和层级参数。

## 输出格式

每个 reference 之间用 `---` 分隔。
