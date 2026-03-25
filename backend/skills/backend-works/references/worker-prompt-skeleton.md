# Worker Subagent Prompt 骨架

编排器为每个 task 构建 worker subagent prompt 时使用以下结构。

## Prompt 模板

```
Agent(
  subagent_type: "tw-backend:agent-ddd-worker",
  max_turns: 15,
  description: "{layer}: {task frontmatter description}",
  prompt: "
    # TASK（实现清单）

    根据以下实现清单，逐项创建/修改代码文件：

    {task 文件末尾的实现清单表格}

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
       bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --set-task {task_id} coded
       bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --sync-layer-status
       并用 Edit 将 task 文件 frontmatter 的 status 更新为 done
    4. 验证失败 → 执行：
       bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --set-task {task_id} failed
       并报告缺失的产物列表
  "
)
```
