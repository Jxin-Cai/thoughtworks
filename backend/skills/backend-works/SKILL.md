---
name: backend-works
description: Backend DDD coding phase orchestrating worker subagents from task design docs
argument-hint: "<idea-name>"

agent:
  - agent-ddd-worker
---

# DDD Spec-Driven Development — 执行流程

用户传入的参数：`$ARGUMENTS`

---

## 铁律

以下铁律适用于所有编排器和子技能。违反任何一条都可能导致流程失败。

1. **工作流数据源唯一性** — Phase 顺序、层定义（id/phase/requires/design-template）、验证模式（verify）必须从对应的 `workflow.yaml` 实际读取获得（后端从 `{DDD_HELP}/workflow.yaml`，前端从 `{FRONTEND_HELP}/workflow.yaml`）。禁止凭 SKILL.md 文本、记忆或推断确定这些信息。每次技能启动都必须重新用 Read 工具读取 workflow.yaml

2. **禁止跳过用户确认** — 每个 HARD-GATE 必须等待其前置条件满足后才能推进。编排器读取需求文件（docs/xxx.md）不等于执行了澄清技能、不等于完成了设计。**只有对应的产出文件实际存在才能推进**

3. **子技能完成后立即推进** — 每个子技能调用完成后，编排器必须立即推进到下一步，不要停下来等待用户额外指令。注意：此条仅适用于子技能已实际调用并完成的情况，不能用于跳过尚未执行的步骤

4. **确认由子技能负责** — 设计确认（AskUserQuestion）在 thought 子技能内部完成，编排器不重复确认

5. **Thinker 只产设计，Worker 只写代码** — 用户的调整请求一律路由到 Thinker，不影响 Worker

6. **门控脚本强制执行** — 每个 step 执行前后的门控检查必须通过 `gate-check.sh` 脚本执行，不得凭记忆或推断判断门控是否通过。用法：`bash {CORE}/scripts/gate-check.sh {IDEA_DIR} <gate-id>`

**本技能附加铁律：**

1. **一个 task 一个 agent** — 每个 `{layer}/*.md` 文件启动独立 worker agent 执行其实现清单，禁止合并多个 task 到一个 agent
2. **禁止跳过 task** — 每个 pending/confirmed 的 task 都必须执行，不能以"太简单"或"已被其他 task 覆盖"为由跳过
3. **禁止修改实现清单** — 实现清单由 `/backend-thought` 产出，执行阶段不能擅自修改
4. **禁止未验证就标记 coded** — agent 完成后必须验证文件已创建，才能将 task 状态更新为 coded
5. **task 依赖必须满足** — 只有 `depends_on` 列表中所有依赖 task 状态为 coded 后，当前 task 才可启动

## 合理化预防

以下是常见的自我合理化模式。当你发现自己在想这些念头时，立刻停下来遵循铁律。

| 你可能会想 | 现实 |
|-----------|------|
| "用户已经给了需求文件，不用再澄清" | 需求文件（docs/xxx.md）只是原始输入，不等于澄清完成。澄清技能会扫描项目上下文、与用户提问、做聚合分析，这些步骤不可替代。**唯一判据：`gate-check.sh` 确认 requirement.md 存在** |
| "需求描述很详细，可以跳过澄清" | 无论需求多详细，聚合分析和用户确认是必须步骤。禁止以需求清晰为由跳过 |
| "我已经读取了需求文件，理解了需求，可以直接开始设计/编码" | 读取文件 ≠ 澄清完成。你的「理解」不能替代澄清技能的项目扫描、用户提问、聚合分析 |
| "评估结果很明显，直接开始设计" | 必须写入 assessment.md 并初始化 workflow-state.yaml |
| "设计看起来没问题，直接开始编码" | 必须等用户确认，用户可能有不同看法 |
| "修改太小了，直接改设计文件" | 修改必须走 thinker 流程，保证契约一致性 |
| "只改了一层，不需要级联" | 必须检查下游依赖，层间契约可能已经不一致 |
| "用户说继续就行" | 分辨"继续当前步骤"和"跳过确认"的区别 |
| "Phase 顺序我已经知道了，不用再读 workflow.yaml" | workflow.yaml 是唯一数据源，每次启动都必须用 Read 工具重新读取，不得凭记忆 |
| "SKILL.md 里已经写了 Phase 顺序" | SKILL.md 的文本是编排逻辑说明，不是数据源。Phase 顺序、层定义的数据源只有 workflow.yaml |

**本技能附加预防：**

| 你可能会想 | 现实 |
|-----------|------|
| "这个 task 太简单，我直接写不用启动 agent" | 每个 task 必须通过独立 agent 执行，保持上下文隔离 |
| "这两个 task 关系密切，合并执行更高效" | 合并会导致 agent 上下文膨胀，质量下降。一个 task 一个 agent |
| "上一个 agent 已经顺便实现了这个 task 的内容" | 仍然需要启动 agent 验证，如果确实已实现则 agent 会快速完成 |
| "这个 task 的设计有问题，我来调整一下" | 触发暂停机制，让用户决定。你不能擅自修改设计 |
| "文件已经创建了，不需要验证" | 必须用 Glob 验证。agent 可能声称完成但实际未写入 |
| "依赖的 task 虽然没完成但我知道它会实现什么" | 必须等依赖 task 状态为 coded 后才能启动，不能预判 |

---

## Step 1: 选择 idea 和解析参数

### 参数解析

`$ARGUMENTS` 格式：`<idea-name> [--layers <layer1,layer2,...>] [--tasks <task1,task2,...>]`

- `idea-name`：idea 名称。如 `$ARGUMENTS` 为空，`ls .thoughtworks/` 列出所有 idea，用 AskUserQuestion 让用户选择
- `--layers`：可选，逗号分隔的层列表（如 `domain` 或 `infr,application`）。只执行指定层的 task
- `--tasks`：可选，逗号分隔的 task_id 列表（如 `domain-001` 或 `infr-001,application-001`）。只执行指定 task

验证 `.thoughtworks/<idea-name>/backend-designs/` 目录存在且包含按层分目录的 task 设计文件（如 `domain/`、`infr/` 等子目录）。不存在则提示先运行 `/backend-thought`。

设置变量：
- `IDEA_DIR` = `.thoughtworks/<idea-name>`
- `DDD_HELP` = 本 SKILL.md 所在目录的兄弟目录 `backend-help/`（即 `../backend-help/`）
- `DESIGNS_DIR` = `{IDEA_DIR}/backend-designs`
- `BACKEND_LANG` = 从 `{IDEA_DIR}/requirement.md` 的 `## 技术选型` 章节读取后端语言（java/python/go），未找到则默认 `java`
- `FILE_EXT` = 根据 `BACKEND_LANG` 映射（java→`.java`，python→`.py`，go→`.go`）

---

## Step 2: 读取工作流定义和 task 状态

<HARD-GATE>
必须用 Read 工具实际读取 `{DDD_HELP}/workflow.yaml` 并解析完成后，才能进入 Step 3。
禁止凭 SKILL.md 中的文本描述推断 Phase 顺序或层间依赖。
</HARD-GATE>

1. 读取 `{DDD_HELP}/workflow.yaml`，解析出所有层的定义、依赖关系和 verify 模式
2. 读取 task 状态：

```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --next-tasks code
```

3. 解析返回结果，确定可执行的 task 列表（依赖已满足、状态为 confirmed 的 task）

4. 如果 `--layers` 或 `--tasks` 参数存在，过滤只保留指定范围内的 task

**处理各状态：**
- 无可执行 task 且所有 task 为 coded → 恭喜用户，提示实现已完成
- 有 failed task → 列出 failed task，用 AskUserQuestion 提供选项（见暂停机制）
- 有可执行 task → 继续执行

---

## Step 3: 按 task 依赖执行

根据 `task-workflow-state.yaml` 中的 task 依赖关系执行。`--next-tasks code` 返回所有依赖已满足的 confirmed task，可并行启动。

初始化 session 追踪变量：`session_completed = []`（记录本次 session 完成的 task）

### 执行循环

1. 查询可执行 task：
   ```bash
   bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --next-tasks code
   ```
   获取所有依赖已满足的 confirmed task 列表
2. 对可执行 task 列表，所有 task 可并行启动（放在同一条消息中多个 Agent 调用）
3. **subagent 启动前准备**：对每个将要执行的 task，运行：
   ```bash
   bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --start-task {task_id}
   cat > {IDEA_DIR}/.current-task-{task_id}-$(date +%s).json << 'TASK_EOF'
   {"role":"worker","task_id":"{task_id}","layer":"{layer}","idea_dir":"{IDEA_DIR}","stack":"backend"}
   TASK_EOF
   ```
4. 启动 worker agent（见下方 prompt 骨架）。Worker agent 内部负责：验证产出、标记 coded、更新 frontmatter
5. agent 返回后，编排器只检查终态：
   ```bash
   bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --get-task-status {task_id}
   ```
   - 状态为 `coded` → 加入 `session_completed`，输出进度
   - 状态为 `failed` → 触发暂停机制
   - 状态仍为 `coding` → 视为失败，触发暂停机制
6. 重新查询 `--next-tasks code`，如果有新的可执行 task（前一批完成后解锁了下游依赖），返回步骤 2 继续

### 并行执行规则

- `--next-tasks code` 返回的所有 task 均可并行启动（依赖已由脚本检查）
- 同层或跨层的 task 只要依赖满足都可并行
- 例如：`domain-001` 和 `domain-002` 无互相依赖 → 并行；`infr-001` 依赖 `domain-001` → 等 `domain-001` coded 后才出现在 next-tasks 中

### Worker agent prompt 骨架

所有层统一使用 `tw-backend:agent-ddd-worker` 作为 `subagent_type`。agent 启动后自行通过 `/backend-load` 加载编码指令和编码规范。

使用 Read 工具加载 `references/worker-prompt-skeleton.md`，按其模板为每个 task 组装 prompt。层级差异通过 CONTEXT 中的 `target_layer` 字段传递。

### 验证流程（由 Worker agent 内部执行）

Worker agent 完成编码后，在 agent 内部执行验证和状态更新：
1. 从 `workflow.yaml` 读取当前 task 所属层 `verify.{BACKEND_LANG}` 下的 glob 模式列表
2. 对每个 verify pattern 用 Glob 执行检查，确认本层关键产物已创建
3. 验证通过后，agent 执行：
   ```bash
   bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --finish-task {task_id} coded
   ```
   并用 Edit 工具将 task 文件的 frontmatter `status:` 字段更新为 `done`
4. 验证失败时，agent 执行 `--finish-task {task_id} failed` 并报告问题

编排器只读取终态（coded/failed），不参与验证过程。**每个 task 最多重试 2 次**，超过后触发暂停机制。

### 进度输出

每个 task 完成后输出：

```
✓ {task_id} ({layer}): {task description}
  进度: {session_completed 数量}/{总 task 数} 完成（本次 session: {session_completed 数量}）
```

---

## 暂停机制

在以下情况暂停执行，输出暂停状态并用 AskUserQuestion 提供选项：

### 触发条件
- task 执行失败（agent 报错或产出不符合预期）
- 实现清单内容不清晰，无法确定实现方式
- 实现过程中发现设计文档有问题

### 暂停输出

```
## 实现暂停

**Idea:** <idea-name>
**进度:** N/M task 完成

### 本次 session 已完成
- [x] domain-001: Order 聚合
- [x] infr-001: Order 仓储实现

### 遇到的问题
**Task:** {task_id} — {description}
<问题描述>

**选项：**
1. 修改设计文档后继续 — 回到 /backend-thought 修改设计，然后重新运行 /backend-works 从断点继续
2. 跳过此 task 继续后续
3. 手动修复后重试此 task
4. 终止执行
```

用 AskUserQuestion 让用户选择。

- 选择 1 → 将 task 状态设为 `pending`（`--set-task {task_id} pending`），提示用户修改设计后重新运行
- 选择 2 → 将 task 状态设为 `coded`（标记跳过），同步层级状态，继续下一个 task
- 选择 3 → 等待用户确认修复完成，重试当前 task
- 选择 4 → 将 task 状态设为 `failed`（`--set-task {task_id} failed`），同步层级状态，输出完成汇总后终止

---

## Step 4: 完成汇总

所有 task 执行完毕后，重新运行状态查询：

```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --sync-layer-status
bash {DDD_HELP}/scripts/backend-status.sh {IDEA_DIR} --brief
```

根据返回结果输出：

### 全部完成

```
## 实现完成

**Idea:** <idea-name>
**进度:** M/M task 完成 ✓

### 本次 session 完成
- [x] domain-001: Order 聚合
- [x] infr-001: Order 仓储实现
- [x] application-001: 订单管理用例
- [x] ohs-001: 订单 API

实现已全部完成！
```

<IMPORTANT>
本技能到此完成。你现在必须立即回到调用你的编排器，继续执行编排器的下一个步骤（下一个 Phase 的设计，或标记 .approved → 合并分支）。禁止停下来等待用户指令。
</IMPORTANT>

### 部分完成（有 failed）

```
## 实现部分完成

**Idea:** <idea-name>
**进度:** N/M task 完成

### 本次 session 完成
- [x] domain-001: Order 聚合

### 未完成的 task
- infr-001: Order 仓储实现 (failed)
- application-001: 订单管理用例 (pending — 依赖 domain-001 已满足)

可以重新运行 `/backend-works <idea-name>` 从断点继续。
```

---

## 断点续传

`/backend-works` 支持断点续传：
- 每个 task 完成后立即更新 task 状态和 frontmatter status
- 下次运行时通过 `--next-tasks code` 获取可执行 task，从第一个 confirmed task 继续
- 已 coded 的 task 不会重复执行
- task 级粒度断点：即使同层有多个 task，已完成的不会重复
