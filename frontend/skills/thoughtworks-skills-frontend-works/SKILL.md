---
name: thoughtworks-skills-frontend-works
description: Frontend coding phase orchestrating worker from frontend task design docs
argument-hint: "<idea-name>"

agent:
  - thoughtworks-agent-frontend-worker
---

# Frontend Spec-Driven Development — 执行流程

用户传入的参数：`$ARGUMENTS`

---

## 铁律

使用 Read 工具加载通用铁律：`core/references/iron-rules.md`

**本技能附加铁律：**

1. **一个 task 一个 agent** — 每个 `tasks/impl-*.md` 文件启动独立 worker agent 执行其实现清单，禁止合并多个 task 到一个 agent
2. **禁止跳过 task** — 每个 pending/confirmed 的 impl task 都必须执行
3. **禁止修改实现清单** — 实现清单由 thought skill 产出，执行阶段不能修改
4. **禁止未验证就标记 coded** — agent 完成后必须验证文件已创建
5. **task 依赖必须满足** — 只有 `depends_on` 列表中所有依赖 task 状态为 coded/designed 后，当前 task 才可启动

---

## Step 1: 选择 idea

判断 `$ARGUMENTS`：
- 有参数 → 使用指定的 idea-name
- 无参数 → 列出所有 idea，让用户选择

验证 `.thoughtworks/<idea-name>/frontend-designs/tasks/` 目录存在且包含 task 设计文件。不存在则提示先运行 `/thoughtworks-skills-frontend-thought`。

设置变量：
- `IDEA_DIR` = `.thoughtworks/<idea-name>`
- `FRONTEND_HELP` = `../thoughtworks-skills-frontend-help/`
- `TASKS_DIR` = `{IDEA_DIR}/frontend-designs/tasks`

---

## Step 2: 读取工作流定义、状态与 task 文件

<HARD-GATE>
必须用 Read 工具实际读取 `{FRONTEND_HELP}/workflow.yaml` 并解析前端层定义后，才能进入 Step 3。
</HARD-GATE>

读取 `{FRONTEND_HELP}/workflow.yaml`，解析出前端层定义（id、phase、requires、verify、worker-ref）。

读取 task 状态：

```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --next-tasks
```

确定可执行的 impl task 列表（依赖已满足、状态为 pending 或 confirmed 的 task）。

**注意**：只有 `frontend-checklist` 层的 task（即 `impl-*.md`）需要 Worker 执行。`frontend-architecture` 和 `frontend-components` 层的 task（`arch-*.md`、`comp-*.md`）是纯设计文档，不启动 Worker。

**处理各状态：**
- 无可执行 impl task 且所有 impl task 为 coded → 提示已完成
- 有 failed task → 列出 failed task，用 AskUserQuestion 提供选项
- 有可执行 task → 继续执行

---

## Step 2.5: UI/UX 需求提取

从 `{IDEA_DIR}/frontend-requirement.md` 中提取 UI/UX 相关信息（产品类型、风格关键词等），存为 `UI_UX_CONTEXT`。如无明确风格信息则留空。

此信息将在 Step 3 注入 prompt，供 Worker agent 内置的 `ui-ux-pro-max` 技能使用（若该技能已安装）。

---

## Step 3: 按 task 执行

初始化 session 追踪变量：`session_completed = []`

### 执行循环

1. 查询可执行 task（`--next-tasks`），过滤出 `frontend-checklist` 层的 impl task
2. 对可执行的 impl task，按 task_id 排序串行执行
3. **subagent 启动前准备**：对每个将要执行的 task，运行：
   ```bash
   bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set-task {task_id} coding
   bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --sync-layer-status
   ```
   然后写入任务文件（供 SubagentStop hook 收敛状态）：
   ```bash
   cat > {IDEA_DIR}/.current-task-{task_id}-$(date +%s).json << 'TASK_EOF'
   {"role":"worker","task_id":"{task_id}","layer":"frontend-checklist","idea_dir":"{IDEA_DIR}","stack":"frontend"}
   TASK_EOF
   ```
4. 读取 task 文件的 frontmatter，将 status 更新为 `in_progress`
5. 启动 worker agent（见下方 prompt 骨架）
6. agent 完成后验证产出
7. 验证通过后更新 task 状态：
   ```bash
   bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set-task {task_id} coded
   bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --sync-layer-status
   ```
8. 将 task 的 frontmatter status 更新为 `done`
9. 将 task 加入 `session_completed`，输出进度
10. 重新查询 `--next-tasks`，如有新的可执行 task 则继续

### Worker agent prompt 骨架

```
Agent(
  subagent_type: "thoughtworks-frontend:thoughtworks-agent-frontend-worker",
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
    {列出 task frontmatter depends_on 中引用的上游 task 文件绝对路径列表，格式如下：}
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
  "
)
```

### 验证流程

agent 完成后，验证产出：
1. 从 `workflow.yaml` 读取 `frontend-checklist` 层 `verify` 下的 glob 模式列表
2. 对每个 verify pattern 用 Glob 执行检查，确认关键产物已创建
3. 如 task 的实现清单已提供明确文件路径，可额外按文件路径做补充校验
4. 如果关键产物未创建，重新启动该 task 的 worker agent，在 prompt 开头追加：

```
---

# PREVIOUS ATTEMPT FAILURE

上次实现验证发现以下文件未创建：
{未创建的文件路径列表}

请确保本次执行后这些文件存在。

---
```

**每个 task 最多重试 2 次**，超过后暂停并用 AskUserQuestion 询问用户。

### 进度输出

每个 task 完成后输出：

```
✓ {task_id}: {task description}
  进度: {session_completed 数量}/{总 impl task 数} 完成
```

---

## 暂停机制

### 触发条件
- task 执行失败（agent 报错或产出不符合预期）
- 实现清单内容不清晰
- 实现过程中发现设计文档有问题

### 暂停处理

用 AskUserQuestion 提供选项：
1. 修改设计文档后继续 → `--set-task {task_id} pending`
2. 跳过此 task → `--set-task {task_id} coded`，同步层级状态
3. 手动修复后重试
4. 终止执行 → `--set-task {task_id} failed`，同步层级状态

---

## Step 4: 完成汇总

所有 impl task 执行完毕后：

```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --sync-layer-status
bash {FRONTEND_HELP}/scripts/frontend-status.sh {IDEA_DIR}
```

输出实现摘要和产出文件列表。

<IMPORTANT>
本技能到此完成。你现在必须立即回到调用你的编排器，继续执行编排器的下一个步骤（展示完成状态 → 合并分支）。禁止停下来等待用户指令。
</IMPORTANT>

---

## 断点续传

`/thoughtworks-skills-frontend-works` 支持断点续传：
- 每个 task 完成后立即更新 task 状态和 frontmatter status
- 下次运行时通过 `--next-tasks` 获取可执行 task，从第一个 pending/confirmed impl task 继续
- 已 coded 的 task 不会重复执行
