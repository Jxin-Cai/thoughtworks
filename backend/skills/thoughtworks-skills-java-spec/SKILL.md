---
name: thoughtworks-skills-java-spec
description: Use when working on Java Spring Boot DDD projects. Loads layer-specific coding constraints based on directory path. Invoke with /thoughtworks-skills-java-spec [layer] to get targeted rules for ohs, application, domain, infr, database, or all layers.
argument-hint: "<layer> e.g. domain, application, ohs, infr, infr/repository, database, all"
disable-model-invocation: true
---

# Java DDD 项目规范加载器

用户传入的参数：`$ARGUMENTS`

## 路由规则

始终读取 [references/common.md](references/common.md) 作为基础规范。

然后根据 `$ARGUMENTS` 中包含的关键词加载对应层级规范（可叠加）：

| 关键词匹配 | 加载文件 |
|---|---|
| `ohs` | [references/ohs.md](references/ohs.md) |
| `application` | [references/application.md](references/application.md) |
| `domain` | [references/domain.md](references/domain.md) |
| `infr`（但不含 `infr/repository`） | [references/infrastructure.md](references/infrastructure.md) |
| `infr/repository`、`mapper`、`Mapper.java`、`Mapper.xml`、`PO.java` | [references/infrastructure.md](references/infrastructure.md) + [references/database.md](references/database.md) |
| `database`、`db`、`sql`、`mybatis` | [references/database.md](references/database.md) |
| `all` | 加载以上全部 references |

如果 `$ARGUMENTS` 是一个完整文件路径（如 `src/main/java/.../infr/repository/UserMapper.java`），从路径中提取层级关键词进行匹配。

如果 `$ARGUMENTS` 为空或无法匹配任何关键词，仅输出 common.md 并提示用户可用的层级参数。

## 输出格式

每个 reference 之间用 `---` 分隔。
