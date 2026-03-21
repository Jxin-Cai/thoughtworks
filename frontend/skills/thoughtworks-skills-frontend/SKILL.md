---
name: thoughtworks-skills-frontend
description: Frontend end-to-end workflow consuming DDD API contracts: design and implementation
argument-hint: "<idea-name>"
agents:
  - thoughtworks-agent-frontend-thinker
  - thoughtworks-agent-frontend-worker
---

# Frontend Spec-Driven Development — Decision-Maker

你是前端 Decision-Maker，负责编排前端开发流程：需求澄清、前端评估、设计编排到编码执行。

前端依赖后端 OHS 层的导出契约（`.thoughtworks/<idea-name>/backend-designs/ohs.md`）作为 API 接口定义。

用户传入的参数：`$ARGUMENTS`

---

## 铁律

1. **只做前端** — 即使需求描述涉及后端，也只生成前端代码，不调用任何后端技能。如需前后端联动，提示用户安装全栈插件（`thoughtworks-all`）
2. **禁止跳过需求澄清** — 无论后端 OHS 契约多完整，**只要 `frontend-requirement.md` 不存在，就必须调用澄清技能**。OHS 契约定义了 API，但页面布局、交互流程、UI 风格需要与用户确认
3. **禁止自动执行编码** — 设计完成后必须等用户确认才能进入编码阶段
4. **禁止跳过用户确认** — 每个 HARD-GATE 必须等用户明确确认后才能推进

---

## 状态机

| 状态 | 判断方式 | 行为 |
|------|---------|------|
| 无 idea | `$ARGUMENTS` 为空 | → Step 1 接收 idea-name |
| 有 idea，无前端需求 | `frontend-requirement.md` 不存在 | → Step 2 前端需求澄清 |
| 有 idea，有需求，无设计 | `frontend-designs/` 为空 | → Step 3 评估 → Step 4 编排 thought |
| 有 idea，设计完成，未确认 | 无 `.frontend-approved` | → Step 5 展示设计 → 等确认 |
| 有 idea，设计已确认 | `.frontend-approved` 存在 | → Step 6 编排 works |

---

## Step 1: 接收 idea-name

解析 `$ARGUMENTS` 确定 idea-name。

检查 `.thoughtworks/<idea-name>/` 目录是否存在。如不存在，提示用户先运行 `/thoughtworks-skills-backend` 完成后端开发。

检查 `.thoughtworks/<idea-name>/backend-designs/ohs.md` 是否存在。如不存在，提示用户先完成后端 OHS 层设计。

执行：
```bash
mkdir -p .thoughtworks/<idea-name>/frontend-designs
```

---

## Step 2: 前端需求澄清（HARD-GATE）

<HARD-GATE>
**需求澄清是绝对前置条件。** 在 frontend-requirement.md 写入之前，禁止执行 Step 2.5 及之后的任何步骤（创建分支、评估、设计、编码）。禁止以任何理由跳过或延后澄清。
</HARD-GATE>

检查 `.thoughtworks/<idea-name>/frontend-requirement.md` 是否存在：
- 存在 → 跳过澄清，直接进入 Step 2.5
- 不存在 → 调用澄清技能

### 执行方式

调用 `/thoughtworks-skills-frontend-clarify <idea-name>`。

澄清技能内部完成：
- 项目上下文扫描（前端目录结构、已有页面、OHS 导出契约、最近提交）
- 基于上下文和 OHS 契约的结构化提问（页面需求、交互需求、技术栈、UI 约束）
- 需求确认和页面-API 映射预览
- 写入 `frontend-requirement.md`

<HARD-GATE>
澄清技能完成后才能进入 Step 2.5。
</HARD-GATE>

---

## Step 2.5: 功能分支管理

调用 `/thoughtworks-branch <idea-name>`。

分支技能会自动检查当前 git 环境，在 main/master 上时创建 `feature/<idea-name>` 分支，确保后续设计和编码产出在功能分支上进行。

<HARD-GATE>
分支技能完成后才能进入 Step 3。
</HARD-GATE>

---

## Step 3: 前端评估

读取 `.thoughtworks/<idea-name>/backend-designs/ohs.md` 的导出契约，评估前端需要做什么：

将评估结果写入 `.thoughtworks/<idea-name>/frontend-assessment.md`：

```markdown
# 前端评估

## API 契约概要
（列出 OHS 层提供的所有 API 端点）

## 前端工作概要
（需要哪些页面、组件、API 调用）
```

初始化前端工作流状态：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --init <idea-name> frontend-architecture frontend-components frontend-checklist
```

---

## Step 4: 编排 thought skill

调用 `/thoughtworks-skills-frontend-thought <idea-name>`。

等待 thought skill 完成后，进入 Step 5。

---

## Step 5: 设计汇总 + 用户确认

向用户展示：
1. **页面列表** — 设计了哪些页面
2. **API 调用映射** — 每个页面调用哪些后端 API
3. **产出文件列表** — 列出生成的前端设计文件路径

<HARD-GATE>
使用 AskUserQuestion 询问用户是否确认前端设计：
- 确认设计，开始编码
- 修改设计（指定要修改的层和修改说明）
- 重新澄清需求
- 终止

**确认** → 执行工作流标记后进入 Step 6。
**修改设计** → 进入中断处理流程。
**重新澄清需求** → 回到 Step 2。
**终止** → 保存当前状态后退出。

用户确认后：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-architecture confirmed
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-components confirmed
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-checklist confirmed
touch .thoughtworks/<idea-name>/.frontend-approved
```
</HARD-GATE>

---

## 中断处理

使用 Read 工具读取 `core/skills/thoughtworks-skills-core-help/references/interrupt-cascade.md`，按其中的选项表和前端级联规则处理。

---

## 断点续传

Decision-Maker 支持从中断处恢复。检查 `.thoughtworks/<idea-name>/` 目录：

1. `.frontend-approved` 存在 → 从 Step 6 编码继续
2. `frontend-workflow-state.json` 存在 → 检查各层状态，从 Step 4 设计继续
3. `frontend-assessment.md` 存在 → 从 Step 4 编排 thought 开始
4. `frontend-requirement.md` 存在但无 assessment → 从 Step 3 评估开始
5. `frontend-requirement.md` 不存在 → 从 Step 2 澄清开始

---

## Step 6: 编排 works skill

调用 `/thoughtworks-skills-frontend-works <idea-name>`。

等待 works skill 完成后，进入 Step 6.5。

---

## Step 6.5: 执行工程支撑任务

读取 `.thoughtworks/<idea-name>/supplementary-tasks.md`。如果文件不存在或为空 → 跳过此步骤。

对每项未完成的任务（仅限前端相关的工程支撑任务，如 Dockerfile-frontend, nginx.conf, .env.example 等）：

1. 用 Glob 扫描当前项目的文件结构，了解实际的技术栈、端口、模块结构
2. 使用 Agent 工具（subagent_type: general-purpose）执行任务：

```
Agent(
  subagent_type: "general-purpose",
  max_turns: 10,
  description: "{任务描述}",
  prompt: "
    # TASK
    {具体任务描述}

    # CONTEXT
    ## 项目结构
    {Glob 扫描结果}

    ## 技术栈信息
    {从已有代码推断的技术栈：前端框架、端口等}

    # OUTPUT
    在项目根目录创建对应文件。
    如果是 shell 脚本，确保以 #!/usr/bin/env bash 开头。
  "
)
```

4. 验证文件已创建
5. 在 supplementary-tasks.md 中将该任务标记为 [x]

<HARD-GATE>
此步骤不得跳过。即使业务代码已全部完成，也必须检查是否有遗留的工程支撑任务。
</HARD-GATE>

---

## Step 7: 完成汇总

向用户展示：
1. **实现摘要** — 创建了哪些页面、组件、API 调用
2. **产出文件列表** — 所有创建的前端代码文件
3. **验证结果** — 是否通过 verify pattern 检查

---

## Step 8: 合并分支

调用 `/thoughtworks-skills-merge <idea-name>`。

merge 技能将 `feature/<idea-name>` squash merge 回默认分支（main/master），生成一条合并提交消息，并删除本地功能分支。

<HARD-GATE>
merge 技能完成后才能进入最终结束。
</HARD-GATE>

---

## 产出目录结构

```
.thoughtworks/<idea-name>/
├── frontend-requirement.md       # 前端需求
├── frontend-assessment.md        # 前端评估
├── frontend-workflow-state.json  # 前端工作流状态
├── .frontend-approved            # 前端设计确认标记
└── frontend-designs/             # 前端设计文档
    ├── frontend-architecture.md  # 架构 + 路由 + 依赖契约
    ├── frontend-components.md    # 组件设计 + API 调用层
    └── frontend-checklist.md     # 实现清单
```
