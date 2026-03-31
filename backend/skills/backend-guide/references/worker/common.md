# Worker 公共指令

## 扫描完成后、开始写代码前必须执行

你的 skills 配置已注入 `backend-load`。在完成项目结构扫描、上游代码扫描并确认 `target_layer` 与 `backend_language` 后，使用 `/backend-load worker {target_layer} {backend_language}` 一次性加载本层 guide + spec。

不要在启动时提前加载，也不要在标准 DDD worker 链路里手工拆成 `/backend-guide` 与 `/backend-spec` 两次调用。

如果你处于非编排入口的普通后端编码场景，只需要快速补充语言与层级约束，也可主动调用 `backend-spec`。

## 角色约束

- **禁止修改设计文档** — 你只按设计写代码，发现设计问题请报告给主 agent，不要自行修改
- **设计文档是指引而非代码模板** — 设计文档提供方法签名、业务规则和设计要点，具体实现细节（字段映射、DDL、DTO 定义等）由你按照 spec 规范自主推导

## 工作方式

### Phase A: 扫描与方案
1. 阅读 prompt 中 TASK 章节，明确要创建哪些类
2. 阅读 prompt 中 CONTEXT 章节，获取详细的设计信息
3. 用 Glob/Grep 工具探索项目结构，找到正确的包路径和已有代码
4. **扫描上游已实现代码** — 当设计文档中标注"Worker 自主推导"的部分，通过 Glob/Grep/Read 扫描上游层已实现的代码获取所需信息（如 Domain 模型字段、Command 字段定义、ApplicationService 方法签名等）
5. **输出实现方案** — 逐条列出要创建/修改的文件路径、关键实现点和创建顺序

### Phase B: 编码
6. 按实现方案的顺序，用 Write/Edit 工具逐个创建或修改代码文件

## 编码前必须执行（HARD-GATE）

<HARD-GATE>
在执行任何 Write/Edit 操作之前，必须完成以下两步：

### Step A: 项目扫描
用 Glob/Grep 探索项目结构，定位：
- 项目根目录结构和包/模块约定
- 上游层已实现的关键类（模型、接口、服务）的实际路径和签名
- 已有的工具类、基础设施组件（如有）

### Step B: 实现方案
基于扫描结果和设计文档，输出实现方案：
1. 逐条列出要创建/修改的文件及其完整路径
2. 每个文件的关键实现点（依赖哪些上游类、实现哪些接口）
3. 文件间的创建顺序（先基础后依赖）

未完成 Step A + Step B 之前，禁止执行 Write/Edit。
</HARD-GATE>

## 完成前必须执行

<HARD-GATE>
在声称完成之前，必须同时满足：

### 验证 A: 产物存在性
根据 `backend_language` 读取 `backend-help/workflow.yaml` 中当前层 `verify.{language}` 的 glob 模式，并用 Glob 执行检查，确认本层关键产物存在。仅当设计文档明确给出文件路径时，才可额外按文件路径做补充校验。

### 验证 B: 实现清单覆盖
逐条对照 prompt 中的实现清单，确认每一项都已落到具体文件：
- 列出：实现项 → 落地文件路径
- 若有未落地项，修复后重新验证

A + B 都通过后才可执行 `--finish-task {task_id} coded`。

如果任何文件未创建，修复后重新验证。禁止声称完成但未执行验证。
</HARD-GATE>

## 必须停下上报（而不是继续）的情况

- 上游代码与设计文档签名不匹配
- 设计文档中缺少必要签名，无法推导实现
- 需要修改设计文档才能继续
- 实现清单有项无法落地，但 verify glob 仍会通过

遇到以上情况时，执行 `--finish-task {task_id} failed` 并在输出中说明原因。
