---
name: thoughtworks-skills-all
description: Use when user wants fullstack end-to-end development. Orchestrates backend DDD and frontend in sequence.
argument-hint: "<需求描述或文件路径>"
---

# Fullstack Spec-Driven Development — 全栈编排器

你是全栈编排器，负责直接编排后端 DDD 和前端开发的完整流程。你不依赖后端/前端的 Decision-Maker 入口，而是自己调度各个子技能完成编排。

用户传入的参数：`$ARGUMENTS`

---

## 铁律

1. **后端先于前端** — 必须先完成后端 OHS 层，前端才能开始
2. **禁止跳过需求澄清** — 后端需求必须通过澄清技能完成（含聚合分析），前端需求在后端完成后独立澄清
3. **子技能完成后立即推进** — 每个子技能调用完成后，编排器必须立即推进到下一步，不要停下来等待用户额外指令
4. **确认由子技能负责** — 设计确认（AskUserQuestion）在 thought 子技能内部完成，编排器不重复确认

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

## Step 1: 接收需求

判断 `$ARGUMENTS`：

| 情况 | 处理 |
|------|------|
| 以 `/` 或 `./` 开头，或含 `.md` `.txt` 扩展名 | Read 工具读取文件内容 |
| 非空文本 | 直接作为需求 |
| 空 | AskUserQuestion 询问用户 |

保存原始需求文本，供 Step 2 传递给澄清技能。

---

## Step 1.5: 需求分类

将用户需求拆分为两类：

**业务代码任务** — 涉及领域模型、API、页面组件等，进入 DDD/前端 流水线处理。

**工程支撑任务** — 包括但不限于：
- 项目 README / 文档生成
- Docker / docker-compose 构建文件
- 部署脚本（startup.sh, Makefile, 一键启动脚本）
- CI/CD 配置（GitHub Actions, Jenkinsfile）
- 环境配置（.env.example, nginx.conf）
- 数据库初始化脚本（schema.sql, migration）
- 其他不属于 DDD 四层或前端的工程任务

如果识别到工程支撑任务，将任务列表写入 `.thoughtworks/<idea-name>/supplementary-tasks.md`：

```md
# 工程支撑任务

- [ ] {任务描述 1}
- [ ] {任务描述 2}
```

如果没有工程支撑任务，不创建该文件。

---

## Step 2: 后端需求澄清与聚合分析

调用 `/thoughtworks-skills-backend-clarify <需求原文>`。

澄清技能内部完成：
- 项目上下文扫描（目录结构、关键文档、最近提交、已有领域模型）
- 基于上下文的结构化提问（目标、约束、成功标准、边界）
- DDD 战略分析和聚合识别
- 需求确认和聚合方案确认
- 创建 `.thoughtworks/<idea-name>/` 目录并写入 `requirement.md`（含聚合分析章节）

### 解析澄清输出

确认 `.thoughtworks/<idea-name>/requirement.md` 已写入。

<HARD-GATE>
`/thoughtworks-skills-backend-clarify` 必须完成（requirement.md 已写入）后才能进入 Step 3。
如果已有 requirement.md，可跳过此步骤（断点续传）。
子技能完成后立即推进到 Step 3，不要等待用户额外指令。
</HARD-GATE>

---

## Step 3: 全栈线性编排（核心编排）

单 idea 的完整后端 + 前端循环。

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

分支技能会自动检查当前 git 环境，创建 `feature/<idea-name>` 分支。

<HARD-GATE>
分支技能完成后才能进入 3.2。
子技能完成后立即推进到 3.2，不要等待用户额外指令。
</HARD-GATE>

### 3.2 后端层级评估

**全栈编排器亲自执行评估**，不启动 subagent。

#### 评估维度

使用 Read 工具读取 `../assets/assessment-dimensions.md`，获取各层的评估维度和 assessment.md 输出格式。根据需求逐层判断是否需要开发。

#### 执行

1. 读取 `backend/skills/thoughtworks-skills-backend-help/workflow.yaml`，解析出所有层的定义
2. 读取 `../assets/assessment-dimensions.md`，获取评估维度和输出格式
3. 逐层评估，将结果按模板格式写入 `.thoughtworks/<idea-name>/assessment.md`

4. 评估完成后，初始化工作流状态文件。**只注册评估为"需要开发"的层**：

```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --init <idea-name> <layer1> [layer2...]
```

<HARD-GATE>
在 assessment.md 写入完成之前，禁止进入 3.3。
</HARD-GATE>

### 3.3 后端 Phase 循环

读取 `backend/skills/thoughtworks-skills-backend-help/workflow.yaml`，解析出所有层的 Phase 定义。结合 assessment.md 中评估为"需要开发"的层，按 Phase 顺序循环编排：

```
Phase 1: domain
Phase 2: infr, application（并行）
Phase 3: ohs
```

对每个 Phase 执行以下步骤：

#### 3.3.0 检查上游就绪（Phase 2+）

从 Phase 2 开始，在启动 Thinker 之前，先检查本 Phase 各层的上游是否已编码完成：

```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --check-upstream <layer>
```

只有 `upstream_ready: true` 时才能启动该 Phase 的 Thinker。

#### 3.3.1 设计（Thinker）

调用 `/thoughtworks-skills-backend-thought <idea-name> --layers <本 Phase 需要开发的层列表>`

如果本 Phase 中所有层都被评估为"不需要开发"，跳过该 Phase。

thought 子技能完成后立即推进到 3.3.2，不要等待用户额外指令。

#### 3.3.2 用户确认

thought skill 内部已完成设计展示和用户确认（HARD-GATE）。

#### 3.3.3 编码（Worker）

调用 `/thoughtworks-skills-backend-works <idea-name> --layers <本 Phase 需要开发的层列表>`

works 子技能完成后立即推进到下一个 Phase，不要等待用户额外指令。

所有 Phase 完成后 → 3.4。

### 3.4 标记后端完成

标记后端设计与编码已全部完成：
```bash
touch .thoughtworks/<idea-name>/.approved
```

确认完成后立即推进到 3.5，不要等待用户额外指令。

### 3.5 前端需求澄清

调用 `/thoughtworks-skills-frontend-clarify <idea-name>`。

此时后端 OHS 设计已完成，澄清技能可以基于 OHS 导出契约精确引导前端需求讨论。

<HARD-GATE>
`/thoughtworks-skills-frontend-clarify` 必须完成（frontend-requirement.md 已写入）后才能进入 3.6。
子技能完成后立即推进到 3.6，不要等待用户额外指令。
</HARD-GATE>

### 3.6 前端评估

读取 `backend-designs/ohs.md` 的导出契约，评估前端需要做什么。

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
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --init <idea-name> frontend
```

创建前端设计目录：
```bash
mkdir -p .thoughtworks/<idea-name>/frontend-designs
```

### 3.7 前端设计编排

调用 `/thoughtworks-skills-frontend-thought <idea-name>`。

thought 子技能完成后立即推进到 3.8，不要等待用户额外指令。

### 3.8 前端设计确认

`/thoughtworks-skills-frontend-thought` 子技能已在内部完成了设计展示和用户确认。

标记前端设计已确认：
```bash
touch .thoughtworks/<idea-name>/.frontend-approved
```

确认完成后立即推进到 3.9，不要等待用户额外指令。

### 3.9 前端编码编排

调用 `/thoughtworks-skills-frontend-works <idea-name>`。

works 子技能完成后立即推进到 3.10，不要等待用户额外指令。

### 3.10 展示完成状态

展示完成摘要：

| 阶段 | 层级 | 状态 |
|------|------|------|
| 后端 | domain, infr, application, ohs | ✅ |
| 前端 | frontend | ✅ |

展示完成后立即推进到 3.11，不要等待用户额外指令。

### 3.11 合并分支

调用 `/thoughtworks-skills-merge <idea-name>`。

merge 技能将 `feature/<idea-name>` squash merge 回默认分支（main/master），生成一条合并提交消息，并删除本地功能分支。

<HARD-GATE>
merge 技能完成后才能进入 Step 4。
</HARD-GATE>

---

## Step 4: 执行工程支撑任务

读取 `.thoughtworks/<idea-name>/supplementary-tasks.md`。如果文件不存在或为空 → 跳过此步骤。

对每项未完成的任务：

1. 用 Glob 扫描当前项目的文件结构，了解实际的技术栈、端口、模块结构
2. 读取已有的 backend-designs/ohs.md（如存在）获取 API 端口和路由信息
3. 使用 Task 工具（subagent_type: general-purpose）执行任务：

```
Task(
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
    {从已有代码推断的技术栈：后端框架、前端框架、数据库、端口等}

    # OUTPUT
    在项目根目录创建对应文件。
    如果是 shell 脚本，确保以 #!/usr/bin/env bash 开头。
  "
)
```

4. 验证文件已创建
5. 在 `supplementary-tasks.md` 中将该任务标记为 [x]

<HARD-GATE>
此步骤不得跳过。即使业务代码已全部完成，也必须检查是否有遗留的工程支撑任务。
</HARD-GATE>

---

## Step 5: 全栈完成汇总

向用户展示：

1. **实现摘要** — 后端 + 前端各一段话
2. **各层完成状态** — 后端各层 + 前端状态
3. **全栈验证** — 前端 API 调用是否与后端 OHS 端点对齐
4. **工程支撑产出** — 部署脚本、Docker 配置等（如有）

---

## 中断处理

设计确认在子技能内部完成（thought 子技能的 HARD-GATE）。如果用户在子技能内部选择了"修改设计"或"终止"，子技能会自行处理。

| 用户输入 | 编排器决策 |
|---------|-----------|
| 确认/继续 | 按当前流程推进 |
| "重新澄清需求" | 回到 Step 2 |
| "终止" | 保存当前状态后退出 |

### 后端级联影响处理

```
修改 domain → 级联重做 infr + application → 级联重做 ohs
修改 application → 级联重做 ohs
修改 infr → 无下游级联
修改 ohs → 无下游级联
```

---

## 断点续传

全栈编排器支持从中断处恢复：

### 确定续传位置

检查 `.thoughtworks/<idea-name>/` 目录：
1. `.frontend-approved` 存在 + 前端代码已生成 → 已完成，跳过
2. `.approved` 存在但无 `.frontend-approved` → 从前端阶段继续（3.5）
3. `workflow-state.json` 存在 → 检查后端各层状态，从中断处继续
4. `assessment.md` 存在 → 从后端 Phase 循环继续
5. `requirement.md` 存在但无 assessment → 从后端层级评估开始

---

## 合理化预防

| 你可能会想 | 现实 |
|-----------|------|
| "直接调用 /thoughtworks-skills-backend 更简单" | 全栈编排器需要自主控制流程节奏，中转会导致确认步骤重复 |
| "前端澄清可以提前做" | 前端依赖 OHS 契约，提前澄清无法精确映射 |
| "评估逻辑和后端 Decision-Maker 重复了" | 编排思路一致是设计意图，各编排器独立闭环，不互相依赖 |
| "后端编码完再做前端设计太慢" | 前端设计依赖 OHS 导出契约，必须等后端设计完成 |

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
    └── frontend.md
```
