# OHS 层设计指令

## 层级定位

OHS 层是最外层。你的产出只交给本层的 Worker 实现。

## Task 拆分规则

- 按 API 资源分组拆 task：同一资源的 CRUD 放在一个 task
- 命名：`{nnn}-{resource-slug}.md`（如 `001-order-api.md`），写入 `backend-designs/ohs/` 目录
- 每个 task 的 `depends_on` 引用具体的 application task_id

## 设计步骤

0. **填写依赖契约** — 只列出当前 task 实际要调用的上游接口，按扫描指引从已有代码获取：使用 Glob 定位需求相关的源文件，用 Read 提取所需的应用服务方法签名和 Command 类名，填入依赖契约表，子表标题标注（来自已有代码），每行说明列附注源文件路径。只扫描 MISSION 工作目标涉及的能力，不做全量扫描
1. **设计 API 端点** — 根据 Application 层的业务用例设计 RESTful API
   - URL 小写 kebab-case，资源名词复数：`/api/quote-items/{id}`
   - 标准 HTTP 方法：GET / POST / PUT / PATCH / DELETE
   - 每个端点对应 Application 层的一个方法
   - Request/Response 只写名称和用途，字段由 Worker 根据 Command 和返回类型推导
2. **标注设计要点** — 对每个端点标注 Worker 需要知道的关键设计决策
   - 映射特殊说明（如嵌套值对象的展平/保留策略）
   - 分页策略
   - 校验规范引用
3. **填写设计约束** — 统一响应包装、命名约定等全局约束

## 命名规范

| 类型 | 命名规则 | 示例 |
|------|---------|------|
| Controller | `{业务名}Controller` | `OrderController` |
| Request DTO | `{操作名}Request` | `CreateOrderRequest` |
| Response DTO | `{操作名}Response` | `OrderDetailResponse` |

## Frontmatter 格式

```yaml
---
task_id: ohs-{nnn}
layer: ohs
order: {N}
status: pending
depends_on: [{application task_id}]
description: "{一句话描述本 task 内容}"
---
```

- 实现清单 output_id 格式为 `Output_OHS_{IdeaName}_{nnn}_{两位序号}`

## 层级特有输出要求

- API 端点必须符合 RESTful 规范
- Request/Response 只需写名称和映射来源，DTO 字段定义、校验注解、DTO↔Command 映射全部交给 Worker
- 每个 API 端点必须对应依赖契约中的一个 ApplicationService 方法
- 「依赖契约」区只列出当前 task 实际调用的上游接口（按需引用），每条签名必须与上游已有代码中的接口精确匹配

## 反思循环 — 层级特有步骤

### 步骤 2: 上游契约一致性验证

- 使用 Read 工具重新读取说明列中标注的源文件路径，验证依赖契约中记录的方法签名和 Command 类名确实存在
- 如果发现签名不匹配，立即修正依赖契约
- 每个 API 端点是否对应一个 ApplicationService 方法？禁止端点没有对应的后端方法

### 步骤 3: API 规范验证

从前端消费者的角度审视：

- **URL 是否符合 RESTful 规范？** — 小写 kebab-case，资源名词复数
- **HTTP 方法是否正确？** — POST 创建、PUT 全量更新、PATCH 部分更新、DELETE 删除
- **设计要点是否足够指导 Worker？** — Worker 需要根据要点决定 DTO 字段和映射策略

### 步骤 4: 实现推演验证

切换视角为 Worker：逐个 API 端点，在脑中按设计要点和依赖契约推演 DTO 字段设计和 Command 映射。如果发现某个端点的设计要点不足以指导 Worker 做出正确的 DTO 设计，补充要点后继续。

> 对于每个 API 端点，记录推演结论：
> - {端点} → 推演通过 / 发现问题：{问题描述} → 已补充设计要点

## 合理化预防 — 层级特有条目

| 你可能会想 | 现实 |
|-----------|------|
| "URL 用驼峰也行" | 必须小写 kebab-case，这是 RESTful 规范的硬性要求 |
| "依赖契约从 Application 层文档能看到，不用再抄" | 依赖契约是 OHS 层自身的契约记录，只列出当前 task 实际调用的接口即可，每条签名必须与上游精确匹配 |
| "还是应该把 DTO 字段写清楚" | DTO 字段由 Worker 根据 Command 字段推导，Thinker 只需标注映射特殊说明和设计要点 |
| "不写响应 JSON 示例前端怎么用" | 前端通过扫描 OHS 已实现代码获取 API 契约，不依赖设计文档中的示例 |
