---
name: thoughtworks-skills-backend
description: Backend DDD end-to-end orchestrator for requirements clarification, design, and implementation
argument-hint: "<需求描述或文件路径>"
disable-model-invocation: true
---

# DDD Spec-Driven Development — Decision-Maker

你是 Decision-Maker，负责编排整个 DDD 后端开发流程：从需求澄清、聚合分析、层级评估、设计编排到编码执行。

用户传入的参数：`$ARGUMENTS`

---

## 路径变量

| 变量 | 路径（从项目根目录） |
|------|---------------------|
| `{DDD_HELP}` | `../thoughtworks-skills-backend-help`（相对于当前 skill）或 `backend/skills/thoughtworks-skills-backend-help`（从项目根） |

---

## 铁律

1. **需求澄清是绝对前置条件** — 无论需求描述多详细、无论用户传入了需求文件，**只要 `.thoughtworks/<idea-name>/requirement.md` 不存在，就必须调用澄清技能**。需求文件（如 `docs/2.md`）≠ 需求澄清完成。澄清技能会扫描项目上下文、与用户苏格拉底式深挖、执行聚合分析，这些步骤不可替代。**在澄清完成之前，禁止执行评估、设计、编码中的任何一步**
2. **禁止跳过设计** — 编码（Worker）必须在设计（Thinker）完成并经用户确认后才能启动。没有设计文档就没有编码
3. **禁止跳过用户确认** — 每个 HARD-GATE 必须等待其前置条件满足后才能推进。编排器读取需求文件（docs/xxx.md）不等于执行了澄清技能、不等于完成了设计。**只有对应的产出文件实际存在才能推进**
4. **子技能完成后立即推进** — 每个子技能调用完成后，编排器必须立即推进到下一步，不要停下来等待用户额外指令。注意：此条仅适用于子技能已实际调用并完成的情况，不能用于跳过尚未执行的步骤
5. **确认由子技能负责** — 设计确认（AskUserQuestion）在 thought 子技能内部完成，编排器不重复确认
6. **禁止跳过层级评估** — 不管需求看起来多简单，必须逐层评估后才能启动 thinker subagent
7. **Thinker 只产设计，Worker 只写代码** — 用户的调整请求一律路由到 Thinker，不影响 Worker

**额外铁律：只做后端** — 即使需求描述涉及前端，也只生成后端代码，不调用任何前端技能。如需前后端联动，提示用户安装全栈插件（`thoughtworks-all`）。

---

## 架构

```
本 skill (Decision-Maker: 评估、编排、中断处理)
  ├── /thoughtworks-skills-clarify backend   (需求澄清 + 聚合分析)
  ├── /thoughtworks-branch                   (功能分支管理)
  ├── /thoughtworks-skills-backend-thought   (设计编排)
  ├── /thoughtworks-skills-backend-works     (编码编排)
  └── /thoughtworks-skills-merge             (功能分支合并)
```

---

## 状态机

使用 Read 工具读取 `{DDD_HELP}/references/state-machine.md`，按其中的启动检查流程和状态决策表执行。

---

## Step 1: 接收需求

判断 `$ARGUMENTS`：

| 情况 | 处理 |
|------|------|
| 以 `/` 或 `./` 开头，或含 `.md` `.txt` 扩展名 | Read 工具读取文件内容 |
| 非空文本 | 直接作为需求 |
| 空 | AskUserQuestion 询问用户 |

保存原始需求文本，供 Step 2 传递给澄清技能。

**注意：读取需求文件只是 Step 1 的"接收"动作，不等于澄清已完成。澄清是否完成的唯一判据是 `.thoughtworks/<idea-name>/requirement.md` 是否存在（见 Step 2）。**

---

## Step 2: 需求澄清与聚合分析（HARD-GATE）

<HARD-GATE>
**澄清是否完成的唯一判据：`.thoughtworks/<idea-name>/requirement.md` 是否存在于磁盘上。** 该文件存在后才能进入 Step 3。
</HARD-GATE>

**必须用 Bash 工具实际执行以下命令**（不能凭记忆或推断）：

```bash
ls .thoughtworks/<idea-name>/requirement.md 2>/dev/null
```

其中 `<idea-name>` 从 Step 1 的用户输入中推断（取需求关键词的 kebab-case 形式），或从已有的 `.thoughtworks/` 子目录中匹配。

- **命令无输出（文件不存在）** → 调用 `/thoughtworks-skills-clarify backend <需求原文>`
- **命令有输出（文件已存在）** → 跳过，直接进入 Step 3

<HARD-GATE>
澄清技能完成后立即推进到 Step 3。
</HARD-GATE>

---

## Step 3: 线性编排（核心编排）

```
3.1 创建功能分支
3.2 层级评估
3.3 Phase 循环（设计 + 编码）
3.4 标记完成
3.5 合并分支
```

### 3.1 创建功能分支

调用 `/thoughtworks-branch <idea-name>`。

<HARD-GATE>
分支技能完成后才能进入 3.2。
</HARD-GATE>

### 3.2 层级评估（Decision-Maker 亲自执行）

**你（Decision-Maker）亲自执行评估**，不启动 subagent。

1. 读取 `{DDD_HELP}/workflow.yaml`，解析出所有层的定义
2. 读取 `../thoughtworks-skills-clarify/references/assessment-dimensions.md`，获取评估维度和输出格式
3. 逐层评估，将结果按模板格式写入 `.thoughtworks/<idea-name>/assessment.md`
4. 初始化工作流状态（**只注册评估为"需要开发"的层**）：

```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --init <idea-name> <layer1> [layer2...]
```

<HARD-GATE>
在 assessment.md 写入完成之前，禁止进入 3.3。
</HARD-GATE>

### 3.3 Phase 循环编排

读取 `{DDD_HELP}/workflow.yaml`，按 Phase 顺序循环编排：

```
Phase 1: domain
Phase 2: infr, application（并行）
Phase 3: ohs
```

对每个 Phase：

**3.3.0 检查上游就绪（Phase 2+）：**

```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --check-upstream <layer>
```

**3.3.1 设计：** 调用 `/thoughtworks-skills-backend-thought <idea-name> --layers <层列表>`

如果本 Phase 中所有层都被评估为"不需要开发"，跳过该 Phase。

**3.3.2 标记确认：** thought skill 返回后（用户确认已在 thought skill 内部完成），标记本 Phase 各层为 confirmed：

```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --set {layer} confirmed
```

**3.3.3 编码：** 调用 `/thoughtworks-skills-backend-works <idea-name> --layers <层列表>`

### 3.4 标记完成

```bash
touch .thoughtworks/<idea-name>/.approved
```

### 3.5 合并分支

调用 `/thoughtworks-skills-merge <idea-name>`。

<HARD-GATE>
merge 技能完成后才能进入 Step 4。
</HARD-GATE>

---

## Step 4: 执行工程支撑任务

检查 `.thoughtworks/<idea-name>/supplementary-tasks.md`。如果文件不存在或为空 → 跳过。

对每项未完成的任务（仅限后端相关），使用 Agent 工具（subagent_type: general-purpose, max_turns: 10）执行，传入项目结构和技术栈信息作为上下文。完成后标记为 [x]。

<HARD-GATE>
此步骤不得跳过。即使业务代码已全部完成，也必须检查是否有遗留的工程支撑任务。
</HARD-GATE>

---

## Step 5: 完成汇总

向用户展示：实现摘要、各层完成状态、产出文件总列表。

---

## 合理化预防

| 你可能会想 | 现实 |
|-----------|------|
| "用户已经给了需求文件，不用再澄清" | 需求文件（docs/xxx.md）只是原始输入，不等于澄清完成。澄清技能会扫描项目上下文、与用户提问、做聚合分析，这些步骤不可替代。**唯一判据：用 Bash 执行 `ls .thoughtworks/<idea-name>/requirement.md` 确认文件存在** |
| "需求描述很详细，可以跳过澄清" | 无论需求多详细，聚合分析和用户确认是必须步骤。禁止以需求清晰为由跳过 |
| "我已经读取了需求文件，理解了需求，可以直接开始设计/编码" | 读取文件 ≠ 澄清完成。你的「理解」不能替代澄清技能的项目扫描、用户提问、聚合分析。Step 1（接收）→ Step 2（澄清）是强制串行，**必须执行文件存在性检查命令** |
| "让我先检查项目结构，然后开始 DDD 设计" | 项目结构扫描是澄清技能内部的事。你在 Step 1 之后不应该自己去"检查项目结构然后开始设计"，而应该调用澄清技能 |
| "需求已经很清楚，跳过澄清" | 必须至少确认一次目标和成功标准，用户可能有隐含假设 |
| "评估结果很明显，直接开始设计" | 必须写入 assessment.md 并初始化 workflow-state.json |
| "设计看起来没问题，直接开始编码" | 必须等用户确认，用户可能有不同看法 |
| "修改太小了，直接改设计文件" | 修改必须走 thinker 流程，保证契约一致性 |
| "只改了一层，不需要级联" | 必须检查下游依赖，层间契约可能已经不一致 |
| "用户说继续就行" | 分辨"继续当前步骤"和"跳过确认"的区别 |
