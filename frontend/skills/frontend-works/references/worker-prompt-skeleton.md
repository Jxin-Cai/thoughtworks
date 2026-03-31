# Frontend Worker Prompt 骨架

## Prompt 模板

```
Agent(
  subagent_type: "tw-frontend:agent-frontend-worker",
  max_turns: 15,
  description: "Frontend: {task frontmatter description}",
  prompt: "
    # TASK

    根据以下实现清单，逐项创建前端代码文件：

    {task 文件末尾的实现清单表格}

    ---

    # EXECUTION CONTRACT（编排器已确认的执行边界 — 不需要你重新判断）

    task_id: {task_id}
    target_layer: {所属层 layer-id}
    ui_framework: react-ts

    ## Must implement
    {从实现清单提取的文件列表，每行一个}

    ## May infer from code
    - OHS 层 API 端点的具体 URL 和参数（通过扫描已有 OHS 代码确认）
    - 组件内部状态管理细节（按 FSD 规范自主决定）

    ## Must NOT change
    - 设计文档（发现问题上报编排器）
    - 不相关的已有代码
    - 上游层接口

    ## Escalate if
    - OHS 层代码中找不到设计文档引用的 API 端点
    - 设计文档中的组件定义与已有代码冲突
    - 实现清单有项无法落地，但 verify glob 仍会通过

    ---

    # CONTEXT

    ## 本 task 设计
    使用 Read 工具加载本 task 实现清单文档：`{当前 task 文件的绝对路径}`
    重点关注实现清单表格中每个文件的创建路径、关键实现点和对应组件设计。

    ## 上游 task 设计（只读参考）
    {列出 task frontmatter depends_on 中引用的上游 task 文件绝对路径列表：}
    如需参考上游设计（架构设计、组件设计），使用 Read 工具按需加载：
    - `{上游 task 文件绝对路径 1}`
    - `{上游 task 文件绝对路径 2}`

    ## OHS 层已有代码（只读参考）
    如需参考后端 API 接口定义，使用 Glob/Grep 工具扫描已有 OHS 代码：
    - Java: `**/ohs/**/*Controller.java`
    - Python: `**/ohs/**/*_router.py`
    - Go: `**/ohs/**/*_handler.go`

    ## UI/UX 需求上下文

    {UI_UX_CONTEXT}

    ---

    # OUTPUT

    在项目中创建前端代码文件。
    保持代码变更最小化，只实现当前实现清单涉及的文件。

    ---

    # VERIFY & FINALIZE

    编码完成后，你必须执行以下验证和状态更新：

    1. 从 workflow.yaml 读取 frontend-checklist 层 verify 下的 glob 模式列表
    2. 对每个 pattern 用 Glob 验证关键产物已创建
    3. 验证通过 → 执行：
       node {FRONTEND_HELP}/scripts/frontend-workflow-status.mjs {IDEA_DIR} --finish-task {task_id} coded
       并用 Edit 将 task 文件 frontmatter 的 status 更新为 done
    4. 验证失败 → 执行：
       node {FRONTEND_HELP}/scripts/frontend-workflow-status.mjs {IDEA_DIR} --finish-task {task_id} failed
       并报告缺失的产物列表
  "
)
```

## EXECUTION CONTRACT 区块填充规则

主 agent 在组装 prompt 时，需要从 task 设计文档中提取已确认的执行边界，直接注入 EXECUTION CONTRACT 区块：

1. **Must implement** — 从 task 文件末尾实现清单表格提取所有需创建的文件，每行一个
2. **May infer from code** — 前端统一允许：OHS 层 API 端点的具体 URL/参数（扫描确认），组件内部状态管理细节（按 FSD 规范自主决定）
3. **Must NOT change** 和 **Escalate if** — 固定内容，所有层通用

这些字段是编排器的已确认决策，worker 不需要重新判断，直接遵循即可。
