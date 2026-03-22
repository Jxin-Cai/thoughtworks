---
name: thoughtworks-skills-frontend-works
description: Frontend coding phase orchestrating worker from frontend design docs
argument-hint: "<idea-name>"

agent:
  - thoughtworks-agent-frontend-worker
---

# Frontend Spec-Driven Development — 执行流程

用户传入的参数：`$ARGUMENTS`

---

## 铁律

1. **checklist 驱动编码** — Worker 从 `frontend-checklist.md` 提取实现清单作为主执行清单，其他设计文件作为上下文参考
2. **禁止修改实现清单** — 实现清单由 thought skill 产出，执行阶段不能修改
3. **禁止未验证就标记 done** — agent 完成后必须验证文件已创建
4. **工作流数据源唯一性** — 前端层定义、verify 模式必须从 `{FRONTEND_HELP}/workflow.yaml` 实际读取获得。禁止凭 SKILL.md 文本、记忆或推断确定这些信息

---

## Step 1: 选择 idea

判断 `$ARGUMENTS`：
- 有参数 → 使用指定的 idea-name
- 无参数 → 列出所有 idea，让用户选择

验证 `.thoughtworks/<idea-name>/frontend-designs/` 目录存在且包含设计文件。

设置变量：
- `IDEA_DIR` = `.thoughtworks/<idea-name>`
- `FRONTEND_HELP` = `../thoughtworks-skills-frontend-help/`
- `DESIGNS_DIR` = `{IDEA_DIR}/frontend-designs`

---

## Step 2: 读取工作流定义、状态与设计文件

<HARD-GATE>
必须用 Read 工具实际读取 `{FRONTEND_HELP}/workflow.yaml` 并解析前端层定义后，才能进入 Step 3。
</HARD-GATE>

读取 `{FRONTEND_HELP}/workflow.yaml`，解析出前端层定义（id、phase、requires、verify、worker-ref）。

查询状态：

```bash
bash {FRONTEND_HELP}/scripts/frontend-status.sh {IDEA_DIR}
```

- `all_done` → 提示已完成
- `blocked` → 列出 failed 文件
- 其他 → 继续执行

读取 `{DESIGNS_DIR}/` 下的所有设计文件（文件列表来自 workflow.yaml 中定义的层 id）。

从 workflow.yaml 中 `worker-ref` 不为 null 的层对应的设计文件提取实现清单表格作为 Worker 的执行清单。其他设计文件作为上下文参考。

---

## Step 2.5: UI/UX 需求提取

从 `{IDEA_DIR}/frontend-requirement.md` 中提取 UI/UX 相关信息（产品类型、风格关键词等），存为 `UI_UX_CONTEXT`。如无明确风格信息则留空。

此信息将在 Step 3 注入 prompt，供 Worker agent 内置的 `ui-ux-pro-max` 技能使用（若该技能已安装）。

---

## Step 3: 执行

**subagent 启动前准备**：在开始执行前，运行：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-checklist coding
cat > {IDEA_DIR}/.current-task-frontend-checklist.json << 'TASK_EOF'
{"role":"worker","layer":"frontend-checklist","idea_dir":"{IDEA_DIR}","stack":"frontend"}
TASK_EOF
```

读取 `{DESIGNS_DIR}/frontend-checklist.md` 的 frontmatter，将 status 更新为 `in_progress`。

启动 worker agent：

```
Agent(
  subagent_type: "thoughtworks-frontend:thoughtworks-agent-frontend-worker",
  max_turns: 15,
  description: "Frontend: {frontend-checklist.md 的 description}",
  prompt: "
    # TASK

    根据以下实现清单，逐项创建前端代码文件：

    {frontend-checklist.md 中的实现清单表格}

    ---

    # CONTEXT

    ## 前端实现清单
    使用 Read 工具加载完整的实现清单文档：`{frontend-checklist.md 的绝对路径}`
    重点关注实现清单表格中每个文件的创建路径、关键实现点和对应组件设计。

    ## 上游设计（只读参考）
    如需参考架构设计和组件设计，使用 Read 工具按需加载：
    - 前端架构设计：`{frontend-architecture.md 的绝对路径}`
    - 前端组件设计：`{frontend-components.md 的绝对路径}`

    ## OHS 层设计（只读参考）
    如需参考 OHS 层设计，使用 Read 工具加载：`{ohs.md 的绝对路径}`

    ## UI/UX 需求上下文

    {UI_UX_CONTEXT}

    ---

    # OUTPUT

    在项目中创建前端代码文件。
    保持代码变更最小化，只实现当前实现清单涉及的文件。
  "
)
```

验证产出：用 Glob 搜索确认文件已创建。如果有文件未创建，重新启动 worker agent，在 prompt 开头追加：

```
---

# PREVIOUS ATTEMPT FAILURE

上次实现验证发现以下文件未创建：
{未创建的文件路径列表}

请确保本次执行后这些文件存在。

---
```

**最多重试 2 次**，超过后暂停并用 AskUserQuestion 询问用户。

验证通过后，将 `frontend-checklist.md` 的 frontmatter status 更新为 `done`。

> SubagentStop hook 已自动将 `coding` → `coded`。编排器无需手动设置 `coded` 状态。

如果 Worker 失败，编排器需要覆盖设置为 `failed`：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-checklist failed
```

---

## Step 4: 完成汇总

```bash
bash {FRONTEND_HELP}/scripts/frontend-status.sh {IDEA_DIR}
```

输出实现摘要和产出文件列表。

<IMPORTANT>
本技能到此完成。你现在必须立即回到调用你的编排器，继续执行编排器的下一个步骤（展示完成状态 → 合并分支）。禁止停下来等待用户指令。
</IMPORTANT>
