# OHS 层编码指令

## 设计文档与自主推导

OHS 层设计文档只提供：API 端点列表（HTTP 方法、URL、用途、Request/Response 名称、设计要点）和依赖契约（ApplicationService 方法、Command 类）。

**以下内容由 Worker 自主推导，设计文档不会给出：**
- Request DTO 字段定义 — 从上游 Command 类的字段推导（用 Glob/Read 扫描已实现的 Command 代码），按需添加校验注解
- Response DTO 字段定义 — 从 ApplicationService 返回的领域模型中提取需要的字段（用 Glob/Read 扫描已实现的领域模型代码）
- DTO ↔ Command 映射逻辑 — 在 Controller 方法内按字段逐一映射
- 领域模型 → Response DTO 映射逻辑 — 在 Controller 方法内从领域模型提取字段

## 编码要求

### DTO
- Request：按 spec 规范中的校验方式添加校验规则，字段从对应 Command 推导
- Response：从 ApplicationService 返回的领域模型中提取需要的字段，只包含需要返回的字段
- 命名：`{操作名}Request` / `{操作名}Response`

### Controller/Handler
- 按 spec 规范中的路由定义方式（Java: @RestController，Python: FastAPI Router，Go: Gin handler）
- URL 小写 kebab-case，资源名词复数
- 参数校验
- 统一返回结构
- **不写异常捕获** — 交由全局异常处理器兜底

### DTO → Command 转换
- 在 Controller 方法内完成，逐字段映射，使用 Command Builder

### 领域模型 → Response DTO 转换
- 在 Controller 方法内完成，从 ApplicationService 返回的领域模型中提取字段构建 Response DTO

### 通用
- 构造函数注入依赖
- **禁止包含任何业务逻辑**
- 禁止直接调用 Domain Service 或 Repository
- 禁止直接依赖领域层

## 项目结构探索

先用 Glob 搜索（根据 CONTEXT 中的 backend_language 选择匹配模式）：
- `**/ohs/**/*.{ext}` — 找到 ohs 包路径
- Java：`**/application/**/*ApplicationService.java`、`**/application/**/*Command.java`
- Python：`**/application/**/*_application_service.py`、`**/application/**/*_command.py`
- Go：`**/application/**/*_application_service.go`、`**/application/**/*_command.go`

**关键：** 扫描上游已实现的 Command 代码获取字段定义，扫描领域模型代码获取返回类型字段。

## 完成标准

- DTO 和 Controller 都已创建，校验注解完整
- DTO → Command 转换逻辑完整
- 领域模型 → Response DTO 转换逻辑完整
- 代码可编译/运行，符合 backend-spec ohs 规范

## 合理化预防

| 你可能会想 | 现实 |
|-----------|------|
| "加个 try-catch/try-except 更安全" | Controller/Handler 不写异常捕获，交由全局异常处理器 |
| "直接调 Repository 更快" | 禁止直接调用 Repository 或 Domain Service，必须通过 ApplicationService |
| "校验规则后面再加" | 每个 Request 字段必须现在就有校验规则 |
| "用框架字段注入也行" | 必须构造函数注入依赖 |
| "设计文档没给 DTO 字段，我不知道怎么写" | 从 Command 代码推导 Request 字段，从领域模型代码推导 Response 字段，这是 OHS Worker 的核心职责 |
