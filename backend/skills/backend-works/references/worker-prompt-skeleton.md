# Worker Subagent Prompt 骨架

编排器为每个 task 构建 worker subagent prompt 时使用以下结构。

## Prompt 模板

```
Agent(
  subagent_type: "tw-backend:agent-ddd-worker",
  max_turns: 15,
  description: "{layer}: {task frontmatter description}",
  prompt: "
    {仅当本次是重试（编排器检测到 task 之前状态为 coding/failed）时注入以下区块，否则省略：}

    # PRIOR ATTEMPT（前次执行残留 — 必须先检查）

    本 task 之前有一次未完成的执行尝试，项目中可能已有部分代码文件。你必须：
    1. 先用 Glob 按 verify 模式扫描本层已有文件：`{verify glob 模式列表}`
    2. 对已存在的文件用 Read 检查内容完整性
    3. 已完整的文件 → 跳过不重写；不完整或有错的文件 → 用 Edit 修复而非重写
    4. 尚不存在的文件 → 正常创建

    前次失败原因：{编排器从暂停机制获取的失败描述，无则填"turn 耗尽，原因未知"}

    ---

    # TASK（实现清单）

    根据以下实现清单，逐项创建/修改代码文件：

    {task 文件末尾的实现清单表格}

    ---

    # EXECUTION CONTRACT（编排器已确认的执行边界 — 不需要你重新判断）

    task_id: {task_id}
    target_layer: {layer}
    backend_language: {BACKEND_LANG}

    ## Must implement
    {从实现清单提取的文件/类列表，每行一个}

    ## May infer from code
    {该层允许自主推导的内容，由编排器根据 layer guide 填充：}
    {domain: 无，严格按设计}
    {infr: DDL 完整字段从领域模型推导、PO 字段从 DDL 推导、Domain↔PO 转换细节}
    {application: 无，严格按设计}
    {ohs: DTO 字段可从 Command/领域模型推导}

    ## Must NOT change
    - 设计文档（发现问题上报编排器）
    - 不相关的已有代码
    - 上游层接口

    ## Escalate if
    - 上游代码与设计文档签名不匹配
    - 设计文档缺少必要签名，无法推导实现
    - 实现清单有项无法落地，但 verify glob 仍会通过

    ---

    # CONTEXT（设计文档 — 读取作为上下文）

    ## 目标层级
    target_layer: {layer}

    ## 后端语言
    backend_language: {BACKEND_LANG}

    ## 本 task 设计
    使用 Read 工具加载本 task 设计文档：`{当前 task 文件的绝对路径}`
    重点关注实现清单表格中每个实现项对应的设计章节、字段定义、方法签名和业务规则。

    ## 上游 task 设计（只读参考）
    {列出 task frontmatter depends_on 中引用的上游 task 文件绝对路径列表，格式如下：}
    如需参考上游设计，使用 Read 工具按需加载：
    - `{上游 task 文件绝对路径 1}`
    - `{上游 task 文件绝对路径 2}`

    ## 上游已实现代码（只读参考）
    如需参考上游层的已实现代码（如 Domain 层的模型类、Repository 接口），使用 Glob/Grep 工具按需扫描。

    ---

    # OUTPUT

    在项目中创建/修改代码文件。

    保持代码变更最小化，只实现当前实现清单涉及的类。

    重要：CONTEXT 是你的参考约束，不要将它们复制到代码注释中。

    ---

    # VERIFY & FINALIZE

    编码完成后，你必须执行以下验证和状态更新：

    1. 从 workflow.yaml 读取本层 verify.{BACKEND_LANG} 下的 glob 模式
    2. 对每个 pattern 用 Glob 验证关键产物已创建
    3. 验证通过 → 执行：
       node {DDD_HELP}/scripts/backend-workflow-status.mjs {IDEA_DIR} --finish-task {task_id} coded
       并用 Edit 将 task 文件 frontmatter 的 status 更新为 done
    4. 验证失败 → 执行：
       node {DDD_HELP}/scripts/backend-workflow-status.mjs {IDEA_DIR} --finish-task {task_id} failed
       并报告缺失的产物列表
  "
)
```

## EXECUTION CONTRACT 区块填充规则

主 agent 在组装 prompt 时，需要从 task 设计文档和 layer guide 中提取已确认的执行边界，直接注入 EXECUTION CONTRACT 区块：

1. **Must implement** — 从 task 文件末尾实现清单表格提取所有需创建的文件/类，每行一个
2. **May infer from code** — 根据 target_layer 填充该层允许自主推导的内容：
   - `domain` → 无，严格按设计
   - `infr` → DDL 完整字段从领域模型推导、PO 字段从 DDL 推导、Domain↔PO 转换细节
   - `application` → 无，严格按设计
   - `ohs` → DTO 字段可从 Command/领域模型推导
3. **Must NOT change** 和 **Escalate if** — 固定内容，所有层通用

这些字段是编排器的已确认决策，worker 不需要重新判断，直接遵循即可。
