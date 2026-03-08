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

1. **一个设计文件一个 agent** — 每个 frontend-designs/*.md 文件启动独立 worker agent
2. **禁止跳过设计文件** — 每个 pending 的设计文件都必须执行
3. **禁止修改实现清单** — 实现清单由 thought skill 产出，执行阶段不能修改
4. **禁止未验证就标记 done** — agent 完成后必须验证文件已创建

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

## Step 2: 读取状态

```bash
bash {FRONTEND_HELP}/scripts/frontend-status.sh {IDEA_DIR}
```

- `all_done` → 提示已完成
- `blocked` → 列出 failed 文件
- 其他 → 继续执行

---

## Step 3: 执行

**标记进入编码阶段**：在开始执行第一个设计文件前，运行：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend coding
```

对每个 pending 的设计文件：

1. 读取设计文件，提取 frontmatter 和实现清单
2. 将 frontmatter status 更新为 `in_progress`
3. 启动 worker agent：

```
Task(
  subagent_type: "thoughtworks-frontend:thoughtworks-agent-frontend-worker",
  max_turns: 15,
  description: "Frontend: {设计文件 description}",
  prompt: "
    # TASK

    根据以下实现清单，逐项创建前端代码文件：

    {设计文件末尾的实现清单表格}

    ---

    # CONTEXT

    ## 前端设计
    {当前设计文件完整内容}

    ## OHS 层设计（只读参考）
    如需参考 OHS 层设计，使用 Read 工具加载：`{ohs.md 的绝对路径}`

    ---

    # OUTPUT

    在项目中创建前端代码文件。
    保持代码变更最小化，只实现当前实现清单涉及的文件。
  "
)
```

4. 验证产出：用 Glob 搜索确认文件已创建。如果有文件未创建，重新启动 worker agent，在 prompt 开头追加：

```
---

# PREVIOUS ATTEMPT FAILURE

上次实现验证发现以下文件未创建：
{未创建的文件路径列表}

请确保本次执行后这些文件存在。

---
```

**每个设计文件最多重试 2 次**，超过后暂停并用 AskUserQuestion 询问用户
5. 验证通过后，将 frontmatter status 更新为 `done`

**标记编码完成**：所有设计文件执行完毕后（全部 done），运行：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend coded
```

如果有失败的设计文件，运行：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend failed
```

---

## Step 4: 完成汇总

```bash
bash {FRONTEND_HELP}/scripts/frontend-status.sh {IDEA_DIR}
```

输出实现摘要和产出文件列表。
