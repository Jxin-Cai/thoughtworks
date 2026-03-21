# OHS 层设计指令

## 层级定位

OHS 层是最外层。你的产出只交给本层的 Worker 实现。

## 设计步骤

0. **填写依赖契约** — 只列出当前需求实际要调用的上游接口，按扫描指引从已有代码获取：使用 Glob 定位需求相关的源文件，用 Read 提取所需的应用服务方法签名、Command 字段和返回类型，填入依赖契约表，子表标题标注（来自已有代码），每行说明列附注源文件路径。只扫描 MISSION 工作目标涉及的能力，不做全量扫描
1. **设计 API 端点** — 根据 Application 层的业务用例设计 RESTful API
   - URL 小写 kebab-case，资源名词复数：`/api/quote-items/{id}`
   - 标准 HTTP 方法：GET / POST / PUT / PATCH / DELETE
   - 每个端点对应 Application 层的一个方法
2. **设计 Request DTO** — 对应 Application 层的 Command 对象
   - 字段与 Command 对应，但可以有不同的命名（面向 API 消费者）
   - 参数校验规则：按 spec 规范中的校验方式（如 Java 用 @Validated + JSR 380，Python 用 Pydantic Field，Go 用 binding tag）
3. **设计 Response DTO** — 面向 API 消费者的返回结构
   - 字段来源于 Application 层返回的**领域模型**（聚合根、实体、值对象），OHS 层负责领域模型到 Response DTO 的转换
   - 统一包装：`{ code, message, data }`
   - 分页查询：`{ code, message, data: { list, total, pageNum, pageSize } }`
4. **设计 Controller** — 按资源分组
   - 方法签名
   - DTO → Command 转换映射（逐字段）
   - 调用哪个 ApplicationService 的哪个方法
   - Controller 不写 try-catch，交由全局异常处理器

## 命名规范

| 类型 | 命名规则 | 示例 |
|------|---------|------|
| Controller | `{业务名}Controller` | `OrderController` |
| Request DTO | `{操作名}Request` | `CreateOrderRequest` |
| Response DTO | `{操作名}Response` | `OrderDetailResponse` |
| RPC 服务 | `{业务名}GrpcService` | `OrderGrpcService` |

## Frontmatter 格式

```yaml
---
spec_id: Spec_OHS
layer: ohs
order: 1
status: pending
depends_on: []
description: "{一句话描述本文件内容}"
---
```

- 实现清单 output_id 格式为 `Output_OHS_{IdeaName}_{两位序号}`
- 默认产出单文件 `ohs.md`，当预估内容超过约 3000 字时按功能独立性拆分为 `ohs-{order}-{topic}.md`，有关联的内容不拆，拆分后通过 depends_on 声明同层内依赖

## 层级特有输出要求

- API 端点必须符合 RESTful 规范
- Request DTO 的校验规则必须逐字段标注
- DTO → Command 的字段映射必须逐字段列出
- 「依赖契约」区只列出当前需求 Controller 实际调用的上游接口（按需引用，非全量抄入），每条签名必须与上游已有代码中的接口精确匹配；Controller 中调用的每个 ApplicationService 方法和 Command 必须能在依赖契约中找到对应条目
- 每个 API 端点必须对应依赖契约中的一个 ApplicationService 方法
- DTO → Command 映射表中的目标字段必须与 Command 定义表完全匹配
- Response DTO 字段必须能追溯到返回类型定义（领域模型）或值对象定义，禁止凭空发明字段

## 反思循环 — 层级特有步骤

### 步骤 2: 上游契约一致性验证

- 使用 Read 工具重新读取说明列中标注的源文件路径，验证依赖契约中记录的方法签名和 Command 字段确实存在
- 如果发现签名不匹配，立即修正依赖契约
- DTO → Command 映射是否逐字段匹配？映射目标字段必须与源代码中的 Command 定义完全一致
- 每个 API 端点是否对应一个 ApplicationService 方法？禁止端点没有对应的后端方法
- Response DTO 字段是否都能追溯到返回类型定义？禁止凭空发明字段

### 步骤 3: API 规范验证

从前端消费者的角度审视：

- **URL 是否符合 RESTful 规范？** — 小写 kebab-case，资源名词复数
- **每个 Request 字段是否都有校验规则？** — Worker 需要直接按此编码
- **每个端点是否都有响应 JSON 示例？** — 前端开发依赖它
- **HTTP 方法是否正确？** — POST 创建、PUT 全量更新、PATCH 部分更新、DELETE 删除

### 步骤 4: 实现推演验证

切换视角为 Worker：逐个 Controller/Handler 方法，在脑中按方案的描述写出完整实现代码。用 spec 规范中对应语言的技术栈推演每一行，包括 Request 校验、DTO→Command 转换、Response 组装和序列化。如果推演到某一步时，发现在特定数据状态下会导致运行时异常或产生错误结果，说明方案本身有缺陷 — 补充处理策略后再继续。

> 对于每个 Controller 方法/DTO 转换，记录推演结论：
> - {方法名} → 推演通过 / 发现问题：{问题描述} → 已补充处理策略

## 合理化预防 — 层级特有条目

| 你可能会想 | 现实 |
|-----------|------|
| "校验规则后面再加" | 每个 Request 字段必须现在就标注校验注解，这是 API 契约的一部分 |
| "DTO 和 Command 字段一样，不用写映射" | 必须逐字段列出映射关系，OHS 层和 Application 层是独立的 |
| "响应示例太啰嗦" | 每个端点必须有响应 JSON 示例，前端开发依赖它 |
| "URL 用驼峰也行" | 必须小写 kebab-case，这是 RESTful 规范的硬性要求 |
| "依赖契约从 Application 层文档能看到，不用再抄" | 依赖契约是 OHS 层自身的契约记录，只列出当前需求实际调用的接口即可，不要求全量抄入，但每条签名必须与上游精确匹配 |
