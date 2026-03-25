---
name: frontend-works
description: Frontend coding phase orchestrating worker from frontend task design docs
argument-hint: "<idea-name>"

agent:
  - agent-frontend-worker
---

# Frontend Spec-Driven Development — 执行流程

用户传入的参数：`$ARGUMENTS`

---

## 铁律

<HARD-GATE>
使用 Read 工具加载 `core/references/iron-rules.md`，严格遵守其中所有条目。
</HARD-GATE>

**本技能附加铁律：**

1. **一个 task 一个 agent** — 每个 `frontend-checklist/*.md` 文件启动独立 worker agent 执行其实现清单，禁止合并多个 task 到一个 agent
2. **禁止跳过 task** — 每个 pending/confirmed 的 impl task 都必须执行
3. **禁止修改实现清单** — 实现清单由 thought skill 产出，执行阶段不能修改
4. **禁止未验证就标记 coded** — agent 完成后必须验证文件已创建
5. **task 依赖必须满足** — 只有 `depends_on` 列表中所有依赖 task 状态为 coded/designed 后，当前 task 才可启动

---

## Step 1: 选择 idea

判断 `$ARGUMENTS`：
- 有参数 → 使用指定的 idea-name
- 无参数 → 列出所有 idea，让用户选择

验证前置条件（必须用 gate-check.sh 脚本验证，不得凭推断）：

```bash
bash core/scripts/gate-check.sh {IDEA_DIR} frontend-requirement-exists
bash core/scripts/gate-check.sh {IDEA_DIR} frontend-designs-exist
```

<HARD-GATE>
两个检查都必须返回 `pass: true` 才能继续。如果 frontend-designs-exist 返回 `pass: false`，提示先运行 `/frontend-thought`。
禁止跳过前置条件检查直接进入编码。上下文中出现过设计信息不等于设计文件存在。
</HARD-GATE>

设置变量：
- `IDEA_DIR` = `.thoughtworks/<idea-name>`
- `FRONTEND_HELP` = `../frontend-help/`
- `DESIGNS_DIR` = `{IDEA_DIR}/frontend-designs`

---

## Step 2: 读取工作流定义、状态与 task 文件

<HARD-GATE>
必须用 Read 工具实际读取 `{FRONTEND_HELP}/workflow.yaml` 并解析前端层定义后，才能进入 Step 3。
</HARD-GATE>

读取 `{FRONTEND_HELP}/workflow.yaml`，解析出前端层定义（id、phase、requires、verify、worker-ref）。

读取 task 状态：

```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --next-tasks code
```

确定可执行的 impl task 列表（依赖已满足、状态为 confirmed 的 task）。

**注意**：只有 `frontend-checklist` 层的 task（即 `impl-*.md`）需要 Worker 执行。`frontend-architecture` 和 `frontend-components` 层的 task（`arch-*.md`、`comp-*.md`）是纯设计文档，不启动 Worker。

**处理各状态：**
- 无可执行 impl task 且所有 impl task 为 coded → 提示已完成
- 有 failed task → 列出 failed task，用 AskUserQuestion 提供选项
- 有可执行 task → 继续执行

<HARD-GATE>
在进入编码循环前，必须执行工作流完整性校验：
```bash
bash core/scripts/gate-check.sh {IDEA_DIR} task-workflow-integrity frontend
```
必须返回 `pass: true`。如果返回 `pass: false`，说明有 task 处于 coding/coded 状态但对应设计文件不存在，这是流程违规，必须停止并报告。
</HARD-GATE>

---

## Step 2.5: UI/UX 需求提取

从 `{IDEA_DIR}/frontend-requirement.md` 中提取 UI/UX 相关信息（产品类型、风格关键词等），存为 `UI_UX_CONTEXT`。如无明确风格信息则留空。

此信息将在 Step 3 注入 prompt，供 Worker agent 内置的 `ui-ux-pro-max` 技能使用（若该技能已安装）。

---

## Step 3: 按 task 执行

初始化 session 追踪变量：`session_completed = []`

### 执行循环

1. 查询可执行 task：
   ```bash
   bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --next-tasks code
   ```
   过滤出 `frontend-checklist` 层的 impl task
2. 对可执行的 impl task，所有 task 可并行启动（放在同一条消息中多个 Agent 调用）
3. **subagent 启动前准备**：对每个将要执行的 task，运行：
   ```bash
   bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --start-task {task_id}
   cat > {IDEA_DIR}/.current-task-{task_id}-$(date +%s).json << 'TASK_EOF'
   {"role":"worker","task_id":"{task_id}","layer":"frontend-checklist","idea_dir":"{IDEA_DIR}","stack":"frontend"}
   TASK_EOF
   ```
4. 启动 worker agent（见下方 prompt 骨架）。Worker agent 内部负责：验证产出、标记 coded、更新 frontmatter
5. agent 返回后，编排器只检查终态：
   ```bash
   bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --get-task-status {task_id}
   ```
   - 状态为 `coded` → 加入 `session_completed`，输出进度
   - 状态为 `failed` → 触发暂停机制
   - 状态仍为 `coding` → 视为失败，触发暂停机制
6. 重新查询 `--next-tasks code`，如有新的可执行 impl task（前一批完成后解锁了下游依赖）则继续

### Worker agent prompt 骨架

agent 启动后自行通过 `/frontend-load` 加载编码指令和编码规范。

使用 Read 工具加载 `references/worker-prompt-skeleton.md`，按其模板为每个 task 组装 prompt。

### 验证流程（由 Worker agent 内部执行）

Worker agent 完成编码后，在 agent 内部执行验证和状态更新：
1. 从 `workflow.yaml` 读取 `frontend-checklist` 层 `verify` 下的 glob 模式列表
2. 对每个 verify pattern 用 Glob 验证关键产物已创建
3. 验证通过 → agent 执行状态标记（coded）和 frontmatter 更新
4. 验证失败 → agent 标记 failed 并报告问题

编排器只读取终态（coded/failed），不参与验证过程。**每个 task 最多重试 2 次**，超过后暂停。

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
bash {FRONTEND_HELP}/scripts/frontend-status.sh {IDEA_DIR} --brief
```

输出实现摘要和产出文件列表。

<IMPORTANT>
本技能到此完成。你现在必须立即回到调用你的编排器，继续执行编排器的下一个步骤（展示完成状态 → 合并分支）。禁止停下来等待用户指令。
</IMPORTANT>

---

## 断点续传

`/frontend-works` 支持断点续传：
- 每个 task 完成后立即更新 task 状态和 frontmatter status
- 下次运行时通过 `--next-tasks code` 获取可执行 task，从第一个 confirmed impl task 继续
- 已 coded 的 task 不会重复执行
