---
name: thoughtworks-skills-backend-works
description: Backend DDD coding phase orchestrating worker subagents from task design docs
argument-hint: "<idea-name>"

agent:
  - thoughtworks-agent-ddd-worker
---

# DDD Spec-Driven Development — 执行流程

用户传入的参数：`$ARGUMENTS`

---

## 铁律

使用 Read 工具加载通用铁律：`core/references/iron-rules.md`

**本技能附加铁律：**

1. **一个 task 一个 agent** — 每个 `tasks/*.md` 文件启动独立 worker agent 执行其实现清单，禁止合并多个 task 到一个 agent
2. **禁止跳过 task** — 每个 pending/confirmed 的 task 都必须执行，不能以"太简单"或"已被其他 task 覆盖"为由跳过
3. **禁止修改实现清单** — 实现清单由 `/thoughtworks-skills-backend-thought` 产出，执行阶段不能擅自修改
4. **禁止未验证就标记 coded** — agent 完成后必须验证文件已创建，才能将 task 状态更新为 coded
5. **task 依赖必须满足** — 只有 `depends_on` 列表中所有依赖 task 状态为 coded 后，当前 task 才可启动

## 合理化预防

使用 Read 工具加载合理化预防：`core/references/rationalization-prevention.md`

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

验证 `.thoughtworks/<idea-name>/backend-designs/tasks/` 目录存在且包含 task 设计文件。不存在则提示先运行 `/thoughtworks-skills-backend-thought`。

设置变量：
- `IDEA_DIR` = `.thoughtworks/<idea-name>`
- `DDD_HELP` = 本 SKILL.md 所在目录的兄弟目录 `thoughtworks-skills-backend-help/`（即 `../thoughtworks-skills-backend-help/`）
- `TASKS_DIR` = `{IDEA_DIR}/backend-designs/tasks`
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
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --next-tasks
```

3. 解析返回结果，确定可执行的 task 列表（依赖已满足、状态为 pending 或 confirmed 的 task）

4. 如果 `--layers` 或 `--tasks` 参数存在，过滤只保留指定范围内的 task

**处理各状态：**
- 无可执行 task 且所有 task 为 coded → 恭喜用户，提示实现已完成
- 有 failed task → 列出 failed task，用 AskUserQuestion 提供选项（见暂停机制）
- 有可执行 task → 继续执行

---

## Step 3: 按 task 依赖执行

根据 `task-workflow-state.yaml` 中的 task 依赖关系执行。无依赖或依赖已满足的 task 可并行启动。

初始化 session 追踪变量：`session_completed = []`（记录本次 session 完成的 task）

### 执行循环

1. 查询可执行 task（`--next-tasks`），获取依赖已满足的 pending/confirmed task 列表
2. 对可执行 task，按层分组。同层内按 task_id 排序串行，不同层的 task 可并行
3. **subagent 启动前准备**：对每个将要执行的 task，运行：
   ```bash
   bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --set-task {task_id} coding
   bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --sync-layer-status
   ```
   然后写入任务文件（供 SubagentStop hook 收敛状态，文件名含时间戳避免并发冲突）：
   ```bash
   cat > {IDEA_DIR}/.current-task-{task_id}-$(date +%s).json << 'TASK_EOF'
   {"role":"worker","task_id":"{task_id}","layer":"{layer}","idea_dir":"{IDEA_DIR}","stack":"backend"}
   TASK_EOF
   ```
4. 启动 worker agent（见下方 prompt 骨架）
5. agent 完成后验证产出（见验证流程）
6. 验证通过后更新 task 状态：
   ```bash
   bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --set-task {task_id} coded
   bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --sync-layer-status
   ```
7. 将 task 的 frontmatter status 更新为 `done`（用 Edit 工具修改 task 文件的 `status:` 字段）
8. 将 task 加入 `session_completed`，输出进度
9. 重新查询 `--next-tasks`，如果有新的可执行 task，返回步骤 2 继续

### 并行执行规则

- 不同层的 task 可同时启动（放在同一条消息中多个 Agent 调用）
- 同层内的 task 串行执行（按 task_id 排序）
- 例如：`domain-001` 和 `domain-002` 串行；`infr-001` 和 `application-001` 可并行

### Worker agent prompt 骨架

所有层统一使用 `thoughtworks-backend:thoughtworks-agent-ddd-worker` 作为 `subagent_type`。层级差异通过 CONTEXT 中的 `target_layer` 字段传递，agent 启动后通过 `backend-guide` skill 路由加载对应层级的编码指令。

`skills: [thoughtworks-skills-backend-spec, thoughtworks-skills-backend-guide]` 已配置自动注入编码规范和层级编码指令。动态 prompt 只需包含 TASK、CONTEXT、OUTPUT 三个动态区块：

```
Agent(
  subagent_type: "thoughtworks-backend:thoughtworks-agent-ddd-worker",
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
  "
)
```

### 验证流程

agent 完成后，**验证产出**：
1. 从 `workflow.yaml` 读取当前 task 所属层 `verify.{BACKEND_LANG}` 下的 glob 模式列表
2. 对每个 verify pattern 用 Glob 执行检查，确认本层关键产物已创建
3. 如 task 的实现清单已提供明确文件路径，可额外按文件路径做补充校验，但**统一以 workflow.yaml 的 verify patterns 为主验收基准**
4. 如果 verify patterns 对应的关键产物未创建，重新启动该 task 的 worker agent，在 prompt 开头追加：

```
---

# PREVIOUS ATTEMPT FAILURE

上次实现验证发现以下关键产物未通过 verify patterns 检查：
{未通过的 verify pattern 或缺失产物列表}

请确保本次执行后这些关键产物存在。

---
```

**每个 task 最多重试 2 次**，超过后触发暂停机制。

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
1. 修改设计文档后继续 — 回到 /thoughtworks-skills-backend-thought 修改设计，然后重新运行 /thoughtworks-skills-backend-works 从断点继续
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
bash {DDD_HELP}/scripts/backend-status.sh {IDEA_DIR}
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

可以重新运行 `/thoughtworks-skills-backend-works <idea-name>` 从断点继续。
```

---

## 断点续传

`/thoughtworks-skills-backend-works` 支持断点续传：
- 每个 task 完成后立即更新 task 状态和 frontmatter status
- 下次运行时通过 `--next-tasks` 获取可执行 task，从第一个 pending/confirmed task 继续
- 已 coded 的 task 不会重复执行
- task 级粒度断点：即使同层有多个 task，已完成的不会重复
