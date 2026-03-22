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

使用 Read 工具读取 `{DDD_HELP}/references/iron-rules.md`，严格遵守其中所有条目。

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
2. 读取 `{DDD_HELP}/references/assessment-dimensions.md`，获取评估维度和输出格式
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

## 中断处理

使用 Read 工具读取 `{DDD_HELP}/references/interrupt-cascade.md`，按其中的选项表和级联规则处理。

---

## 合理化预防

使用 Read 工具读取 `{DDD_HELP}/references/rationalization-backend.md`，严格遵守。
