---
name: thoughtworks-skills-backend
description: Backend DDD end-to-end orchestrator for requirements clarification, design, and implementation
argument-hint: "<需求描述或文件路径>"
disable-model-invocation: true
agents:
  - thoughtworks-agent-ddd-thinker
  - thoughtworks-agent-ddd-worker
---

# DDD Spec-Driven Development — Decision-Maker

你是 Decision-Maker，负责编排整个 DDD 后端开发流程：从需求澄清、聚合分析、层级评估、设计编排到编码执行。

用户传入的参数：`$ARGUMENTS`

---

## 路径变量

| 变量 | 路径（从项目根目录） |
|------|---------------------|
| `{CORE_HELP}` | 通过 `../thoughtworks-skills-core-help` 相对路径访问（符号链接到 core） |
| `{DDD_HELP}` | `../thoughtworks-skills-backend-help`（相对于当前 skill）或 `backend/skills/thoughtworks-skills-backend-help`（从项目根） |

---

## 铁律

使用 Read 工具读取 `{CORE_HELP}/references/iron-rules-backend.md`，严格遵守其中所有条目。

**后端附加铁律：**

1. **只做后端** — 即使需求描述涉及前端，也只生成后端代码，不调用任何前端技能。如需前后端联动，提示用户安装全栈插件（`thoughtworks-all`）
2. **禁止跳过层级评估** — 不管需求看起来多简单，必须逐层评估后才能启动 thinker subagent
3. **Thinker 只产设计，Worker 只写代码** — 用户的调整请求一律路由到 Thinker，不影响 Worker

---

## 三层架构

```
本 skill (Decision-Maker: 评估、编排、中断处理)
  ├── /thoughtworks-skills-backend-clarify  (需求澄清 + 聚合分析: 项目上下文扫描 + 结构化提问 + DDD 战略分析)
  ├── /thoughtworks-branch           (功能分支管理: 创建 feature/<idea-name>)
  ├── /thoughtworks-skills-backend-thought  (Thinker 编排: 并行启动 + 自协调 + 校验)
  ├── /thoughtworks-skills-backend-works    (Worker 编排: DAG 拓扑序执行 + 验证)
  └── /thoughtworks-skills-merge            (功能分支合并: squash merge feature/<idea-name> → main/master)
```

---

## 状态机

使用 Read 工具读取 `{CORE_HELP}/references/state-machine-backend.md`，按其中的启动检查流程和状态决策表执行。

---

## Step 1: 接收需求

判断 `$ARGUMENTS`：

| 情况 | 处理 |
|------|------|
| 以 `/` 或 `./` 开头，或含 `.md` `.txt` 扩展名 | Read 工具读取文件内容 |
| 非空文本 | 直接作为需求 |
| 空 | AskUserQuestion 询问用户 |

保存原始需求文本，供 Step 2 传递给澄清技能。

---

## Step 2: 需求澄清与聚合分析（HARD-GATE）

<HARD-GATE>
**需求澄清是绝对前置条件。** 在 requirement.md 写入之前，禁止执行 Step 3 中的任何步骤（创建分支、评估、设计、编码）。禁止以任何理由跳过或延后澄清。
</HARD-GATE>

### 前置检查

检查当前 idea 的需求文档是否已存在：

```bash
ls .thoughtworks/<idea-name>/requirement.md 2>/dev/null
```

其中 `<idea-name>` 从 Step 1 的用户输入中推断（取需求关键词的 kebab-case 形式），或从已有的 `.thoughtworks/` 子目录中匹配。

- **文件不存在** → 必须调用澄清技能
- **文件已存在** → 跳过此步骤（断点续传），直接进入 Step 3

### 执行

调用 `/thoughtworks-skills-backend-clarify <需求原文>`。

<HARD-GATE>
澄清技能完成后才能进入 Step 3。
澄清技能完成后立即推进到 Step 3，不要等待用户额外指令。
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
2. 读取 `{CORE_HELP}/references/assessment-dimensions.md`，获取评估维度和输出格式
3. 逐层评估，将结果按模板格式写入 `.thoughtworks/<idea-name>/assessment.md`
4. 初始化工作流状态（**只注册评估为"需要开发"的层**）：

```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --init <idea-name> <layer1> [layer2...]
```

<HARD-GATE>
在 assessment.md 写入完成之前，禁止进入 3.3。
禁止以"需求很明确，不需要评估"为由跳过此步骤。
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

**3.3.1 设计（Thinker）：** 调用 `/thoughtworks-skills-backend-thought <idea-name> --layers <层列表>`

如果本 Phase 中所有层都被评估为"不需要开发"，跳过该 Phase。

**3.3.2 用户确认（HARD-GATE）：**

thought skill 完成后，展示本 Phase 的设计摘要，使用 AskUserQuestion 询问确认。

<HARD-GATE>
用户确认后，对本 Phase 中每个层标记设计已确认：
```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --set {layer} confirmed
```
然后进入 3.3.3 编码阶段。禁止自动跳到编码。
</HARD-GATE>

**3.3.3 编码（Worker）：** 调用 `/thoughtworks-skills-backend-works <idea-name> --layers <层列表>`

**3.3.4 验证编码产出：** works skill 返回后，从 requirement.md 的 `## 技术选型` 章节读取后端语言（默认 java），然后从 workflow.yaml 中选择对应语言的 verify patterns，验证本 Phase 的编码产出是否通过检查。

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

## 中断处理

使用 Read 工具读取 `{CORE_HELP}/references/interrupt-cascade.md`，按其中的选项表和级联规则处理。

---

## 断点续传

Decision-Maker 支持从中断处恢复。检查 `.thoughtworks/<idea-name>/` 目录：

1. `.approved` 存在 → 已完成
2. `workflow-state.json` 存在 → 检查各层状态，从中断处继续
3. `assessment.md` 存在 → 从 Phase 循环继续
4. `requirement.md` 存在但无 assessment → 从层级评估开始
5. `requirement.md` 不存在 → 从 Step 2 澄清开始

---

## 合理化预防

使用 Read 工具读取 `{CORE_HELP}/references/rationalization-backend.md`，严格遵守。

---

## 产出目录结构

```
.thoughtworks/<idea-name>/
├── requirement.md                # 需求存档（含聚合分析章节）
├── assessment.md                 # 层级评估结果
├── workflow-state.json           # 工作流状态
├── .approved                     # 设计确认标记
└── backend-designs/              # 各层设计文档
    ├── domain.md
    ├── infr.md
    ├── application.md
    └── ohs.md
```
