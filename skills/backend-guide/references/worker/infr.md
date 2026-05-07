# Infrastructure 层编码指令

## 设计文档与自主推导

Infr 层设计文档只提供：数据库设计要点（核心字段、索引策略、特殊约束）和仓储实现策略（关键决策点）。

**以下内容由 Worker 自主推导，设计文档不会给出：**
- 完整 DDL — 从上游 Domain 层聚合根/实体/值对象的字段定义推导表结构（用 Glob/Read 扫描已实现的领域模型代码），结合设计文档中的索引策略和特殊约束
- ORM Model/PO 字段 — 从 DDL 推导，与数据库表一一对应
- Domain ↔ ORM Model 双向转换细节 — 从领域模型和 ORM Model 字段对照推导

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
- `**/domain/**/model/*.{ext}` — 扫描领域模型代码获取字段定义（用于推导 DDL 和 ORM Model）
- `**/domain/**/repository/*.{ext}` — 找到需要实现的 Repository 接口

**关键：** 扫描领域模型代码获取聚合根/实体/值对象的完整字段定义，作为 DDL 和 ORM Model 的推导基础。

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
| "设计文档没给完整 DDL，我不知道建什么表" | 从领域模型代码推导表结构，结合设计文档的索引策略和特殊约束，这是 Infr Worker 的核心职责 |
