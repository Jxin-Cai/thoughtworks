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
