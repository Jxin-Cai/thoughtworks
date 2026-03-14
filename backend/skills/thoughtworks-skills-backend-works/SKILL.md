---
name: thoughtworks-skills-backend-works
description: Use when user wants to start coding, execute implementation checklists from design docs, or resume previously interrupted development work.
argument-hint: "<idea-name>"
agents:
  - workers/thoughtworks-agent-ddd-worker-domain
  - workers/thoughtworks-agent-ddd-worker-infr
  - workers/thoughtworks-agent-ddd-worker-application
  - workers/thoughtworks-agent-ddd-worker-ohs
---

# DDD Spec-Driven Development — 执行流程

用户传入的参数：`$ARGUMENTS`

---

## 铁律

1. **一个设计文件一个 agent** — 每个 backend-designs/*.md 文件启动独立 worker agent 执行其实现清单，禁止合并多个文件到一个 agent
2. **禁止跳过设计文件** — 每个 pending 的设计文件都必须执行，不能以"太简单"或"已被其他文件覆盖"为由跳过
3. **禁止修改实现清单** — 实现清单由 `/thoughtworks-skills-backend-thought` 产出，执行阶段不能擅自修改
4. **禁止未验证就标记 done** — agent 完成后必须验证文件已创建，才能将 frontmatter status 更新为 done

## 合理化预防

| 你可能会想 | 现实 |
|-----------|------|
| "这个设计文件太简单，我直接写不用启动 agent" | 每个设计文件必须通过独立 agent 执行，保持上下文隔离 |
| "这两个设计文件关系密切，合并执行更高效" | 合并会导致 agent 上下文膨胀，质量下降。一个文件一个 agent |
| "上一个 agent 已经顺便实现了这个文件的内容" | 仍然需要启动 agent 验证，如果确实已实现则 agent 会快速完成 |
| "这个设计文件的内容有问题，我来调整一下" | 触发暂停机制，让用户决定。你不能擅自修改设计 |
| "文件已经创建了，不需要验证" | 必须用 Glob 验证。agent 可能声称完成但实际未写入 |

---

## Step 1: 选择 idea 和解析参数

### 参数解析

`$ARGUMENTS` 格式：`<idea-name> [--layers <layer1,layer2,...>]`

- `idea-name`：idea 名称。如 `$ARGUMENTS` 为空，`ls .thoughtworks/` 列出所有 idea，用 AskUserQuestion 让用户选择
- `--layers`：可选，逗号分隔的层列表（如 `domain` 或 `infr,application`）。如不提供，执行所有有 pending 设计文件的层

验证 `.thoughtworks/<idea-name>/backend-designs/` 目录存在且包含设计文件。不存在则提示先运行 `/thoughtworks-skills-backend-thought`。

设置变量：
- `IDEA_DIR` = `.thoughtworks/<idea-name>`
- `DDD_HELP` = 本 SKILL.md 所在目录的兄弟目录 `thoughtworks-skills-backend-help/`（即 `../thoughtworks-skills-backend-help/`）
- `DESIGNS_DIR` = `{IDEA_DIR}/backend-designs`

---

## Step 2: 读取工作流定义和状态

1. 读取 `{DDD_HELP}/workflow.yaml`，解析出所有层的定义和依赖关系
2. 运行状态查询脚本获取结构化状态：

```bash
bash {DDD_HELP}/scripts/backend-status.sh {IDEA_DIR}
```

3. 解析返回的 JSON，确定：
   - `state`：整体状态（`not_started` / `in_progress` / `blocked` / `all_done`）
   - `current_phase`：当前应执行的 Phase
   - `workflow_phases`：各层的工作流状态（`designing` / `designed` / `coding` / `coded`）
   - 各 phase 的设计文件列表和 frontmatter status

**处理各状态：**
- `all_done` → 恭喜用户，提示实现已完成
- `blocked` → 列出 failed 的设计文件，用 AskUserQuestion 提供选项（见暂停机制）
- `not_started` / `in_progress` → 继续执行

---

## Step 3: 按 Phase 执行

根据 `workflow.yaml` 中的层定义和依赖关系，按 DAG 拓扑序执行。

**层的确定方式**：
- 如有 `--layers` 参数，只执行指定层的设计文件
- 无 `--layers` 参数时，执行所有有 pending 设计文件的层（保持现有行为）

初始化 session 追踪变量：`session_completed = []`（记录本次 session 完成的设计文件）

### 执行逻辑

1. 从 `current_phase` 开始，找到该 phase 中所有有 pending 设计文件的层
2. **标记层进入编码阶段**：对该 phase 中每个将要执行的层，在开始执行其第一个设计文件前，运行：
   ```bash
   bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --set {layer} coding
   ```
3. 同一 phase 内的不同层可以**并行**（同时启动多个 Task 调用放在同一条消息中），每层内部的设计文件**串行**（按 frontmatter order 排序）
4. 当前 phase 所有层的设计文件全部 done 后，**标记层编码完成**：对该 phase 中每个完成的层，运行：
   ```bash
   bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --set {layer} coded
   ```
   如果某层执行失败（有 failed 设计文件），则运行：
   ```bash
   bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --set {layer} failed
   ```
5. 进入下一个 phase，重复直到所有 phase 完成

### 对每个设计文件的执行流程

1. 读取设计文件内容，提取 frontmatter 和实现清单
2. 将 frontmatter status 更新为 `in_progress`（用 Edit 工具修改设计文件的 frontmatter `status:` 字段）
3. 读取 `workflow.yaml` 中该层的 `worker-ref` 路径，获取编码指引
4. 启动 worker agent，使用自定义 agent 类型（从 `workflow.yaml` 的 `worker-ref` 提取 agent name）：

**agent name 映射：** 从 `worker-ref` 路径提取文件名（去掉 `.md`），加上 `thoughtworks-backend:` 前缀作为 `subagent_type`：
- domain → `thoughtworks-backend:thoughtworks-agent-ddd-worker-domain`
- infr → `thoughtworks-backend:thoughtworks-agent-ddd-worker-infr`
- application → `thoughtworks-backend:thoughtworks-agent-ddd-worker-application`
- ohs → `thoughtworks-backend:thoughtworks-agent-ddd-worker-ohs`

自定义 agent 的 body 已包含编码要求、合理化预防、完成标准等静态指引，`skills: [thoughtworks-skills-java-spec]` 已配置自动注入编码规范。动态 prompt 只需包含 TASK、CONTEXT、OUTPUT 三个动态区块：

```
Task(
  subagent_type: "thoughtworks-backend:{worker-ref 文件名，去掉 .md}",
  max_turns: 15,
  description: "{Layer}: {设计文件 frontmatter description}",
  prompt: "
    # TASK（实现清单）

    根据以下实现清单，逐项创建/修改代码文件：

    {设计文件末尾的实现清单表格}

    ---

    # CONTEXT（设计文档 — 读取作为上下文）

    ## 本层设计
    {当前设计文件的完整内容}

    ## 上游设计（只读参考）
    如需参考上游设计文档，使用 Read 工具按需加载：
    {列出 workflow.yaml 中 requires 对应的上游层设计文档的绝对路径列表}

    ---

    # OUTPUT

    在项目中创建/修改代码文件。

    保持代码变更最小化，只实现当前实现清单涉及的类。

    重要：CONTEXT 是你的参考约束，不要将它们复制到代码注释中。
  "
)
```

5. agent 完成后，**验证产出**：
   - 读取实现清单中的类名列表，对每个类用 Glob 搜索 `**/{ClassName}.java` 确认文件已创建
   - 如果有文件未创建，重新启动该设计文件的 worker agent，在 prompt 开头追加：

```
---

# PREVIOUS ATTEMPT FAILURE

上次实现验证发现以下文件未创建：
{未创建的文件路径列表}

请确保本次执行后这些文件存在。

---
```

**每个设计文件最多重试 2 次**，超过后触发暂停机制
6. 验证通过后，将 frontmatter status 更新为 `done`（用 Edit 工具修改设计文件的 `status:` 字段）
7. 将设计文件加入 `session_completed`
8. 输出 session 进度：

```
✓ {layer}: {设计文件 description}
  进度: {session_completed 数量}/{总设计文件数} 完成（本次 session: {session_completed 数量}）
```

### 并行执行

同一 phase 内如果有多个层（如 phase 2 的 infr 和 application），对每层的第一个 pending 设计文件**同时启动**（放在同一条消息中）。两个 agent 都完成后，更新状态，继续各层的下一个 pending 设计文件。

如果某层的设计文件先全部完成，另一层剩余的设计文件单独串行执行。

---

## 暂停机制

在以下情况暂停执行，输出暂停状态并用 AskUserQuestion 提供选项：

### 触发条件
- 设计文件执行失败（agent 报错或产出不符合预期）
- 实现清单内容不清晰，无法确定实现方式
- 实现过程中发现设计文档有问题

### 暂停输出

```
## 实现暂停

**Idea:** <idea-name>
**进度:** N/M 设计文件完成

### 本次 session 已完成
- [x] domain: xxx
- [x] infr: xxx

### 遇到的问题
<问题描述>

**选项：**
1. 修改设计文档后继续 — 回到 /thoughtworks-skills-backend-thought 修改设计，然后重新运行 /thoughtworks-skills-backend-works 从断点继续
2. 跳过此设计文件继续后续
3. 手动修复后重试此设计文件
4. 终止执行
```

用 AskUserQuestion 让用户选择。

- 选择 1 → 将 frontmatter status 设为 `pending`，提示用户修改设计后重新运行 `/thoughtworks-skills-backend-works`
- 选择 2 → 将 frontmatter status 设为 `done`（标记跳过），继续下一个设计文件
- 选择 3 → 等待用户确认修复完成，重试当前设计文件
- 选择 4 → 将 frontmatter status 设为 `failed`，输出完成汇总后终止

---

## Step 4: 完成汇总

所有 Phase 执行完毕后，重新运行状态查询脚本：

```bash
bash {DDD_HELP}/scripts/backend-status.sh {IDEA_DIR}
```

根据返回的 JSON 输出：

### 全部完成

```
## 实现完成

**Idea:** <idea-name>
**进度:** M/M 设计文件完成 ✓

### 本次 session 完成
- [x] domain: xxx
- [x] infr: xxx
...

实现已全部完成！
```

<IMPORTANT>
本技能到此完成。你现在必须立即回到调用你的编排器，继续执行编排器的下一个步骤（下一个 Phase 的设计，或标记 .approved → 合并分支）。禁止停下来等待用户指令。
</IMPORTANT>

### 部分完成（有 failed）

```
## 实现部分完成

**Idea:** <idea-name>
**进度:** N/M 设计文件完成

### 本次 session 完成
- [x] domain: xxx

### 未完成的设计文件
- infr: xxx (failed)
- application: xxx (pending)

可以重新运行 `/thoughtworks-skills-backend-works <idea-name>` 从断点继续。
```

---

## 断点续传

`/thoughtworks-skills-backend-works` 支持断点续传：
- 每个设计文件完成后立即更新 frontmatter status
- 下次运行时通过 `backend-status.sh` 获取状态，从第一个 `pending` 设计文件继续
- 已 `done` 的设计文件不会重复执行
