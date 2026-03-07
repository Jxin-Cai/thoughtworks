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

1. **后端先于前端** — 必须先完成后端 OHS 层设计，前端才能开始
2. **禁止跳过需求澄清** — 后端和前端的需求都必须通过各自的澄清技能完成
3. **子技能完成后立即推进** — 每个子技能调用完成后，编排器必须立即推进到下一步，不要停下来等待用户额外指令
4. **确认由子技能负责** — 设计确认（AskUserQuestion）在 thought 子技能内部完成，编排器不重复确认

---

## 架构

```
本 skill (全栈编排器: 接收需求、调度澄清、评估、编排设计和编码)
  ├── /thoughtworks-backend-clarify       (后端需求澄清)
  ├── /thoughtworks-frontend-clarify  (前端需求澄清)
  ├── /thoughtworks-backend-thought       (后端设计编排)
  ├── /thoughtworks-backend-works         (后端编码编排)
  ├── /thoughtworks-frontend-thought  (前端设计编排)
  └── /thoughtworks-frontend-works    (前端编码编排)
```

---

## Step 1: 接收需求，提取 idea-name

判断 `$ARGUMENTS`：

| 情况 | 处理 |
|------|------|
| 以 `/` 或 `./` 开头，或含 `.md` `.txt` 扩展名 | Read 工具读取文件内容 |
| 非空文本 | 直接作为需求 |
| 空 | AskUserQuestion 询问用户 |

从需求中提取 kebab-case 名称作为 `idea-name`（如"用户注册功能" → `user-registration`）。

创建目录：
```bash
mkdir -p .thoughtworks/<idea-name>/backend-designs
mkdir -p .thoughtworks/<idea-name>/frontend-designs
```

检查项目根目录的 `.gitignore` 文件，如果不包含 `.thoughtworks/`，则追加一行 `.thoughtworks/`。

如果 `.thoughtworks/<idea-name>/requirement.md` 已存在，使用 AskUserQuestion 询问用户：是覆盖已有需求重新开始，还是基于已有需求继续。用户确认覆盖后才写入；否则保留已有内容，跳到 Step 2。

将需求原文写入 `.thoughtworks/<idea-name>/requirement.md`。

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

## Step 2: 后端需求澄清

调用 `/thoughtworks-backend-clarify <idea-name>`。

澄清技能内部完成：
- 项目上下文扫描（目录结构、关键文档、最近提交、已有领域模型）
- 基于上下文的结构化提问（目标、约束、成功标准、边界）
- 需求确认和分工预览
- 写入/更新 `requirement.md`

<HARD-GATE>
`/thoughtworks-backend-clarify` 必须完成（requirement.md 已写入）后才能进入 Step 3。
如果 `.thoughtworks/<idea-name>/requirement.md` 已存在且用户在 Step 1 选择了基于已有需求继续，可跳过此步骤直接进入 Step 3。
子技能完成后立即推进到 Step 3，不要等待用户额外指令。
</HARD-GATE>

---

## Step 3: 前端需求澄清

调用 `/thoughtworks-frontend-clarify <idea-name>`。

澄清技能内部完成：
- 项目上下文扫描（前端目录结构、已有页面、最近提交）
- 基于上下文的结构化提问（页面需求、交互需求、技术栈、UI 约束）
- 需求确认和页面预览
- 写入 `frontend-requirement.md`

注意：此时后端 OHS 设计尚未完成，澄清技能会基于后端需求（而非 OHS 契约）来引导前端需求讨论。

<HARD-GATE>
`/thoughtworks-frontend-clarify` 必须完成（frontend-requirement.md 已写入）后才能进入 Step 4。
如果 `.thoughtworks/<idea-name>/frontend-requirement.md` 已存在且用户选择基于已有需求继续，可跳过此步骤直接进入 Step 4。
子技能完成后立即推进到 Step 4，不要等待用户额外指令。
</HARD-GATE>

---

## Step 4: 后端层级评估

**全栈编排器亲自执行评估**，不启动 subagent。

### 评估维度

使用 Read 工具读取 `../assets/assessment-dimensions.md`，获取各层的评估维度和 assessment.md 输出格式。根据需求逐层判断是否需要开发。

### 执行

1. 读取 `backend/skills/thoughtworks-skills-ddd-help/workflow.yaml`，解析出所有层的定义
2. 读取 `../assets/assessment-dimensions.md`，获取评估维度和输出格式
3. 逐层评估，将结果按模板格式写入 `.thoughtworks/<idea-name>/assessment.md`

3. 评估完成后，初始化工作流状态文件。**只注册评估为"需要开发"的层**：

```bash
bash {DDD_HELP}/scripts/ddd-workflow-status.sh {IDEA_DIR} --init <idea-name> <layer1> [layer2...]
```

<HARD-GATE>
在 assessment.md 写入完成之前，禁止进入 Step 5。
</HARD-GATE>

---

## Step 5: 后端设计编排

调用 `/thoughtworks-backend-thought <idea-name>`。

thought skill 内部完成：
- 读取 workflow.yaml 和 assessment.md
- 按 DAG 拓扑序（Phase 顺序）编排 thinker subagent：Phase 1 先执行，完成后再启动 Phase 2，同 Phase 并行
- 校验产出（契约匹配、结构完整性）
- 返回设计结果

thought 子技能完成后立即推进到 Step 6，不要等待用户额外指令。

---

## Step 6: 后端设计确认

`/thoughtworks-backend-thought` 子技能已在内部完成了设计展示和用户确认。

标记后端设计已确认：
```bash
touch .thoughtworks/<idea-name>/.approved
```

确认完成后立即推进到 Step 7，不要等待用户额外指令。

---

## Step 7: 后端编码编排

调用 `/thoughtworks-backend-works <idea-name>`。

works skill 内部完成：
- 读取 workflow.yaml 和设计文档
- 按 DAG 拓扑序执行，同 phase 并行、层内串行
- 每个设计文件启动独立 worker subagent
- 验证产出

works 子技能完成后立即推进到 Step 8，不要等待用户额外指令。

---

## Step 8: 前端评估

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

---

## Step 9: 前端设计编排

调用 `/thoughtworks-frontend-thought <idea-name>`。

thought 子技能完成后立即推进到 Step 10，不要等待用户额外指令。

---

## Step 10: 前端设计确认

`/thoughtworks-frontend-thought` 子技能已在内部完成了设计展示和用户确认。

标记前端设计已确认：
```bash
touch .thoughtworks/<idea-name>/.frontend-approved
```

确认完成后立即推进到 Step 11，不要等待用户额外指令。

---

## Step 11: 前端编码编排

调用 `/thoughtworks-frontend-works <idea-name>`。

works 子技能完成后立即推进到 Step 11.5，不要等待用户额外指令。

---

## Step 11.5: 执行工程支撑任务

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
5. 在 supplementary-tasks.md 中将该任务标记为 [x]

<HARD-GATE>
此步骤不得跳过。即使业务代码已全部完成，也必须检查是否有遗留的工程支撑任务。
</HARD-GATE>

---

## Step 12: 全栈完成汇总

向用户展示：

1. **后端产出** — 各层实现摘要 + 产出文件列表
2. **前端产出** — 页面、组件、API 调用实现摘要 + 产出文件列表
3. **全栈验证** — 前端 API 调用是否与后端 OHS 端点对齐
4. **工程支撑产出** — 部署脚本、Docker 配置等（如有）

---

## 中断处理

设计确认在子技能内部完成（thought 子技能的 HARD-GATE）。如果用户在子技能内部选择了"修改设计"或"终止"，子技能会自行处理。

### 后端级联影响处理

```
修改 domain → 级联重做 infr + application → 级联重做 ohs
修改 application → 级联重做 ohs
修改 infr → 无下游级联
修改 ohs → 无下游级联
```

---

## 合理化预防

| 你可能会想 | 现实 |
|-----------|------|
| "直接调用 /thoughtworks-backend 更简单" | 全栈编排器需要自主控制流程节奏，中转会导致确认步骤重复 |
| "前端澄清可以等后端 OHS 完成后再做" | 前端需求（页面、交互）不完全依赖 API 细节，提前澄清能节省用户等待时间 |
| "评估逻辑和后端 Decision-Maker 重复了" | 编排思路一致是设计意图，各编排器独立闭环，不互相依赖 |
| "后端编码完再做前端设计太慢" | 前端设计依赖 OHS 导出契约，必须等后端设计完成；但前端需求可以提前澄清 |

---

## 产出目录结构

```
.thoughtworks/<idea-name>/
├── requirement.md                    # 后端需求存档
├── assessment.md                     # 后端层级评估结果
├── workflow-state.json               # 后端工作流状态
├── .approved                         # 后端设计确认标记
├── backend-designs/                  # 后端各层设计文档
│   ├── domain.md
│   ├── infr.md
│   ├── application.md
│   └── ohs.md
├── frontend-requirement.md           # 前端需求
├── frontend-assessment.md            # 前端评估
├── frontend-workflow-state.json      # 前端工作流状态
├── .frontend-approved                # 前端设计确认标记
└── frontend-designs/                 # 前端设计文档
    └── frontend.md
```
