# Infrastructure 层编码指令

## 编码要求

### 数据库
- DDL 中表名 snake_case
- 必须包含 `id`, `created_time`, `updated_time`, `is_deleted`
- SQL/Migration 文件写入项目的 migration 目录（Java: `resources/db/migration/`，Python: `alembic/versions/`，Go: `migrations/`）

### ORM Model
- 与数据库表一一对应，字段映射关系清晰
- ORM Model 只用于数据库交互，禁止写业务逻辑

### 仓储实现
- 实现 Domain 层的 Repository 接口
- Domain ↔ ORM Model 双向转换完整
- save：按 spec 规范中的语言惯用方式判断 insert/update
- 查询：组装完整聚合根，返回领域模型（禁止返回 ORM Model）

### 通用
- 构造函数注入依赖，禁止框架字段注入
- 禁止包含业务逻辑
- 禁止依赖 OHS 层或 Application 层

## Spec 加载补充

使用 `{language} infr` 和 `{language} database` 关键词匹配加载对应的规范文件。

## 项目结构探索

先用 Glob 搜索（根据 CONTEXT 中的 backend_language 选择扩展名）：
- `**/infr/**/*.{ext}` — 找到 infr 包路径
- `**/domain/**/repository/*.{ext}` — 找到需要实现的 Repository 接口

## 完成标准

- DDL/Migration、ORM Model、RepositoryImpl 都已创建
- Domain ↔ ORM Model 转换逻辑完整
- 代码可编译/运行，符合 backend-spec infr/repository 规范

## 合理化预防

| 你可能会想 | 现实 |
|-----------|------|
| "PO 和领域模型字段一样，直接复用" | ORM Model 和领域模型必须独立，双向转换逻辑必须完整 |
| "返回 ORM Model 让上层自己转" | 仓储方法返回值必须是领域模型，禁止返回 ORM Model |
| "SELECT * 更方便" | 禁止 SELECT *，必须明确列出查询字段（或使用 ORM 的字段选择） |
| "业务校验放这里更安全" | 禁止在仓储中做业务规则校验，那是 Domain 层的职责 |
