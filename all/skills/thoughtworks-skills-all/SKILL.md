---
name: thoughtworks-skills-all
description: Use when user wants fullstack end-to-end development. Orchestrates backend DDD and frontend in sequence.
argument-hint: "<需求描述或文件路径>"
---

# Fullstack Spec-Driven Development — 全栈编排器

你是全栈编排器，负责直接编排后端 DDD 和前端开发的完整流程。你不依赖后端/前端的 Decision-Maker 入口，而是自己调度各个子技能完成编排。

用户传入的参数：`$ARGUMENTS`

---

## 路径变量

| 变量 | 路径（从项目根目录） |
|------|---------------------|
| `{CORE_HELP}` | `core/skills/thoughtworks-skills-core-help` |
| `{DDD_HELP}` | `backend/skills/thoughtworks-skills-backend-help` |
| `{FRONTEND_HELP}` | `frontend/skills/thoughtworks-skills-frontend-help` |

---

## 铁律

使用 Read 工具读取 `{CORE_HELP}/references/iron-rules-backend.md`，严格遵守其中所有条目。

**全栈附加铁律：**

1. **后端先于前端** — 必须先完成后端 OHS 层，前端才能开始

---

## 架构

```
本 skill (全栈编排器: 接收需求、调度澄清、评估、编排设计和编码)
  ├── /thoughtworks-skills-backend-clarify       (后端需求澄清 + 聚合分析)
  ├── /thoughtworks-skills-frontend-clarify  (前端需求澄清)
  ├── /thoughtworks-branch            (功能分支管理: 创建 feature/<idea-name>)
  ├── /thoughtworks-skills-backend-thought       (后端设计编排)
  ├── /thoughtworks-skills-backend-works         (后端编码编排)
  ├── /thoughtworks-skills-frontend-thought  (前端设计编排)
  ├── /thoughtworks-skills-frontend-works    (前端编码编排)
  └── /thoughtworks-skills-merge             (功能分支合并: squash merge feature/<idea-name> → main/master)
```

---

## 状态机

使用 Read 工具读取 `{CORE_HELP}/references/state-machine-backend.md`，按其中的启动检查流程和状态决策表执行。

**全栈扩展状态行：**

| 状态 | 判断方式 | 行为 |
|------|---------|------|
| 有 idea，后端完成，无前端 | `.approved` 存在但无 `.frontend-approved` | → Step 3.5 前端需求澄清 |
| 有 idea，前端设计中 | `frontend-workflow-state.json` 存在 | → 检查前端各层状态，从中断处继续 |
| 有 idea，全部完成 | `.frontend-approved` 存在 + 前端代码已生成 | → 提示已完成 |

---

## Step 1: 接收需求

判断 `$ARGUMENTS`：

| 情况 | 处理 |
|------|------|
| 以 `/` 或 `./` 开头，或含 `.md` `.txt` 扩展名 | Read 工具读取文件内容 |
| 非空文本 | 直接作为需求 |
| 空 | AskUserQuestion 询问用户 |

保存原始需求文本，供 Step 2 传递给澄清技能。

**注意：读取需求文件只是 Step 1 的"接收"动作。不能基于读取到的内容跳过 Step 2 的澄清。**

---

## Step 1.5: 需求分类

将用户需求拆分为两类：

**业务代码任务** — 涉及领域模型、API、页面组件等，进入 DDD/前端 流水线处理。

**工程支撑任务** — 项目 README、Docker、部署脚本、CI/CD、环境配置、数据库初始化脚本等不属于 DDD 四层或前端的工程任务。

如果识别到工程支撑任务，写入 `.thoughtworks/<idea-name>/supplementary-tasks.md`（checklist 格式）。

分类完成后 → 进入 Step 2。**禁止从 Step 1.5 直接跳到 Step 3。**

---

## Step 2: 后端需求澄清与聚合分析

### 前置检查

```bash
ls .thoughtworks/*/requirement.md 2>/dev/null
```

- **文件不存在** → 必须调用澄清技能
- **文件已存在** → 跳过此步骤（断点续传），直接进入 Step 3

### 执行

调用 `/thoughtworks-skills-backend-clarify <需求原文>`。

<HARD-GATE>
`/thoughtworks-skills-backend-clarify` 必须完成（requirement.md 已写入）后才能进入 Step 3。
子技能完成后立即推进到 Step 3，不要等待用户额外指令。
</HARD-GATE>

---

## Step 3: 全栈线性编排（核心编排）

```
3.1  创建功能分支
--- 后端 ---
3.2  后端层级评估
3.3  后端 Phase 循环
3.4  标记后端完成（.approved）
--- 前端 ---
3.5  前端需求澄清
3.6  前端评估
3.7  前端设计
3.8  前端设计确认（.frontend-approved）
3.9  前端编码
3.10 展示完成状态
3.11 合并分支
```

### 3.1 创建功能分支

调用 `/thoughtworks-branch <idea-name>`。

<HARD-GATE>
分支技能完成后才能进入 3.2。子技能完成后立即推进。
</HARD-GATE>

### 3.2 后端层级评估

**全栈编排器亲自执行评估**，不启动 subagent。

1. 读取 `{DDD_HELP}/workflow.yaml`，解析出所有层的定义
2. 读取 `{CORE_HELP}/references/assessment-dimensions.md`，获取评估维度和输出格式
3. 逐层评估，将结果按模板格式写入 `.thoughtworks/<idea-name>/assessment.md`
4. 初始化工作流状态（**只注册评估为"需要开发"的层**）：

```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --init <idea-name> <layer1> [layer2...]
```

<HARD-GATE>
在 assessment.md 写入完成之前，禁止进入 3.3。
</HARD-GATE>

### 3.3 后端 Phase 循环

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

**3.3.2 用户确认：** thought skill 内部已完成。确认后标记：

```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --set {layer} confirmed
```

**3.3.3 编码：** 调用 `/thoughtworks-skills-backend-works <idea-name> --layers <层列表>`

所有 Phase 完成后 → 3.4。

### 3.4 标记后端完成

```bash
touch .thoughtworks/<idea-name>/.approved
```

确认完成后立即推进到 3.5。

### 3.5 前端需求澄清

```bash
ls .thoughtworks/<idea-name>/frontend-requirement.md 2>/dev/null
```

- **文件不存在** → 调用 `/thoughtworks-skills-frontend-clarify <idea-name>`
- **文件已存在** → 跳过，进入 3.6

<HARD-GATE>
frontend-requirement.md 已写入后才能进入 3.6。子技能完成后立即推进。
</HARD-GATE>

### 3.6 前端评估

读取 `backend-designs/ohs.md` 的导出契约，评估前端工作。写入 `.thoughtworks/<idea-name>/frontend-assessment.md`。

初始化前端工作流状态：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --init <idea-name> frontend-architecture frontend-components frontend-checklist
mkdir -p .thoughtworks/<idea-name>/frontend-designs
```

### 3.7 前端设计编排

调用 `/thoughtworks-skills-frontend-thought <idea-name>`。

### 3.8 前端设计确认

子技能已在内部完成设计展示和用户确认。标记：

```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-architecture confirmed
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-components confirmed
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-checklist confirmed
touch .thoughtworks/<idea-name>/.frontend-approved
```

### 3.9 前端编码编排

调用 `/thoughtworks-skills-frontend-works <idea-name>`。

### 3.10 展示完成状态

展示后端 + 前端各层完成状态。

### 3.11 合并分支

调用 `/thoughtworks-skills-merge <idea-name>`。

<HARD-GATE>
merge 技能完成后才能进入 Step 4。
</HARD-GATE>

---

## Step 4: 执行工程支撑任务

读取 `.thoughtworks/<idea-name>/supplementary-tasks.md`。如果文件不存在或为空 → 跳过。

对每项未完成的任务，使用 Task 工具（subagent_type: general-purpose, max_turns: 10）执行，传入项目结构和技术栈信息作为上下文。完成后在 supplementary-tasks.md 中标记为 [x]。

<HARD-GATE>
此步骤不得跳过。即使业务代码已全部完成，也必须检查是否有遗留的工程支撑任务。
</HARD-GATE>

---

## Step 5: 全栈完成汇总

向用户展示：实现摘要、各层完成状态、全栈验证（前端 API 与后端 OHS 对齐）、工程支撑产出。

---

## 中断处理

使用 Read 工具读取 `{CORE_HELP}/references/interrupt-cascade.md`，按其中的选项表和级联规则处理。

---

## 合理化预防

使用 Read 工具读取以下两个文件，严格遵守：
- `{CORE_HELP}/references/rationalization-backend.md`
- `{CORE_HELP}/references/rationalization-fullstack.md`

---

## 产出目录结构

```
.thoughtworks/<idea-name>/
├── requirement.md                # 需求存档（含聚合分析章节）
├── assessment.md                 # 后端层级评估结果
├── workflow-state.json           # 后端工作流状态
├── .approved                     # 后端完成标记
├── backend-designs/              # 后端设计文档
│   ├── domain.md
│   ├── infr.md
│   ├── application.md
│   └── ohs.md
├── supplementary-tasks.md        # 工程支撑任务（如有）
├── frontend-requirement.md       # 前端需求
├── frontend-assessment.md        # 前端评估
├── frontend-workflow-state.json  # 前端工作流状态
├── .frontend-approved            # 前端完成标记
└── frontend-designs/             # 前端设计文档
    ├── frontend-architecture.md  # 架构 + 路由 + 依赖契约
    ├── frontend-components.md    # 组件设计 + API 调用层
    └── frontend-checklist.md     # 实现清单
```
