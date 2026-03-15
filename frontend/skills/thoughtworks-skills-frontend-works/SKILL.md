---
name: thoughtworks-skills-frontend-works
description: Use when user wants to start frontend coding, execute implementation checklists from frontend design docs.
argument-hint: "<idea-name>"
agents:
  - thoughtworks-agent-frontend-worker
---

# Frontend Spec-Driven Development — 执行流程

用户传入的参数：`$ARGUMENTS`

---

## 铁律

1. **checklist 驱动编码** — Worker 从 `frontend-checklist.md` 提取实现清单作为主执行清单，`frontend-architecture.md` 和 `frontend-components.md` 作为上下文参考
2. **禁止修改实现清单** — 实现清单由 thought skill 产出，执行阶段不能修改
3. **禁止未验证就标记 done** — agent 完成后必须验证文件已创建

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

## Step 2: 读取状态与设计文件

```bash
bash {FRONTEND_HELP}/scripts/frontend-status.sh {IDEA_DIR}
```

- `all_done` → 提示已完成
- `blocked` → 列出 failed 文件
- 其他 → 继续执行

读取 3 个设计文件：
- `{DESIGNS_DIR}/frontend-architecture.md` — 架构设计（FSD 层级、路由、依赖契约）
- `{DESIGNS_DIR}/frontend-components.md` — 组件设计（Props/State/API 映射）
- `{DESIGNS_DIR}/frontend-checklist.md` — 实现清单（主执行清单）

从 `frontend-checklist.md` 提取实现清单表格作为 Worker 的执行清单。

---

## Step 2.5: UI/UX 需求提取

从 `{IDEA_DIR}/frontend-requirement.md` 中提取 UI/UX 相关信息（产品类型、风格关键词等），存为 `UI_UX_CONTEXT`。如无明确风格信息则留空。

此信息将在 Step 3 注入 prompt，供 Worker agent 内置的 `ui-ux-pro-max` 技能使用（若该技能已安装）。

---

## Step 3: 执行

**标记进入编码阶段**：在开始执行前，运行：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-checklist coding
```

读取 `frontend-checklist.md` 的 frontmatter，将 status 更新为 `in_progress`。

启动 worker agent：

```
Task(
  subagent_type: "thoughtworks-frontend:thoughtworks-agent-frontend-worker",
  max_turns: 15,
  description: "Frontend: {frontend-checklist.md 的 description}",
  prompt: "
    # TASK

    根据以下实现清单，逐项创建前端代码文件：

    {frontend-checklist.md 中的实现清单表格}

    ---

    # CONTEXT

    ## 前端架构设计
    {frontend-architecture.md 完整内容}

    ## 前端组件设计
    {frontend-components.md 完整内容}

    ## 前端实现清单
    {frontend-checklist.md 完整内容}

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

**标记编码完成**：Worker 执行完毕后（验证通过），运行：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-checklist coded
```

如果 Worker 失败，运行：
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
