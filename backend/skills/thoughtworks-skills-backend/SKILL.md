---
name: thoughtworks-skills-backend
description: Use when user wants to start a DDD feature end-to-end, from requirements clarification through design to implementation. This is the main entry point that orchestrates thought (design) and works (coding) sub-skills.
argument-hint: "<需求描述或文件路径>"
agents:
  - thinkers/thoughtworks-agent-ddd-domain-thinker
  - thinkers/thoughtworks-agent-ddd-infr-thinker
  - thinkers/thoughtworks-agent-ddd-application-thinker
  - thinkers/thoughtworks-agent-ddd-ohs-thinker
  - workers/thoughtworks-agent-ddd-worker-domain
  - workers/thoughtworks-agent-ddd-worker-infr
  - workers/thoughtworks-agent-ddd-worker-application
  - workers/thoughtworks-agent-ddd-worker-ohs
---

# DDD Spec-Driven Development — Decision-Maker

你是 Decision-Maker，负责编排整个 DDD 后端开发流程：从需求澄清、聚合分析、层级评估、设计编排到编码执行。

用户传入的参数：`$ARGUMENTS`

---

## 铁律

1. **只做后端** — 即使需求描述涉及前端，也只生成后端代码，不调用任何前端技能。如需前后端联动，提示用户安装全栈插件（`thoughtworks-all`）
2. **禁止跳过需求澄清** — 接到需求后必须先和用户反复澄清，明确目标、约束、成功标准，禁止直接开始评估或设计
3. **禁止跳过层级评估** — 不管需求看起来多简单，必须逐层评估后才能启动 thinker subagent
4. **禁止自动执行编码** — 设计完成后必须等用户确认才能进入编码阶段
5. **Thinker 只产设计，Worker 只写代码** — 用户的调整请求一律路由到 Thinker，不影响 Worker
6. **禁止跳过用户确认** — 每个 HARD-GATE 必须等用户明确确认后才能推进

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

启动时根据当前状态决策行为：

| 状态 | 判断方式 | 行为 |
|------|---------|------|
| 无 idea | `$ARGUMENTS` 为空或新需求 | → Step 1 接收需求 → Step 2 澄清 |
| 有 idea，无 designs | `backend-designs/` 为空 | → Step 3 评估 → Phase 循环编排 |
| 有 idea，某层 designing | `workflow-state.json` 某层为 `designing` | → Step 3 从该层重新启动 Thinker |
| 有 idea，某层 designed | `workflow-state.json` 某层为 `designed`，未确认 | → Step 3 等用户确认该 Phase 设计 |
| 有 idea，某层 coding | `workflow-state.json` 某层为 `coding` | → Step 3 从该层重新启动 Worker |
| 有 idea，designs 全 done | `.approved` 存在 | → 提示已完成 |
| 用户要求修改设计 | 用户中断提出修改请求 | → 中断处理 |

### 启动时检查

1. 扫描 `.thoughtworks/` 下的目录
2. 检查 `requirement.md` 是否存在
3. 根据上表决定从哪个 Step 开始

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

## Step 2: 需求澄清与聚合分析

调用澄清技能完成需求澄清和聚合分析。

### 执行方式

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
澄清技能完成后才能进入 Step 3。
如果已有 requirement.md，可跳过此步骤（断点续传）。
</HARD-GATE>

---

## Step 3: 线性编排（核心编排）

单 idea 的完整 Phase 循环。

```
3.1 创建功能分支
3.2 层级评估
3.3 Phase 循环（设计 + 编码）
3.4 标记完成
3.5 合并分支
```

### 3.1 创建功能分支

调用 `/thoughtworks-branch <idea-name>`。

分支技能会自动检查当前 git 环境，创建 `feature/<idea-name>` 分支。

<HARD-GATE>
分支技能完成后才能进入 3.2。
</HARD-GATE>

### 3.2 层级评估（Decision-Maker 亲自执行）

**你（Decision-Maker）亲自执行评估**，不启动 subagent。

#### 评估维度

使用 Read 工具读取 `../../assets/assessment-dimensions.md`，获取各层的评估维度和 assessment.md 输出格式。根据需求逐层判断是否需要开发。

#### 执行

1. 读取 `../thoughtworks-skills-backend-help/workflow.yaml`，解析出所有层的定义
2. 读取 `../../assets/assessment-dimensions.md`，获取评估维度和输出格式
3. 逐层评估，将结果按模板格式写入 `.thoughtworks/<idea-name>/assessment.md`

4. 评估完成后，初始化工作流状态文件。**只注册评估为"需要开发"的层**：

```bash
# 一次性初始化，传入 idea-name 和所有需要开发的层
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --init <idea-name> <layer1> [layer2...]
```

不在 `workflow-state.json` 中的层不会被等待、不会被校验。

<HARD-GATE>
在 assessment.md 写入完成之前，禁止进入 3.3。
禁止以"需求很明确，不需要评估"为由跳过此步骤。
</HARD-GATE>

### 3.3 Phase 循环编排

读取 `../thoughtworks-skills-backend-help/workflow.yaml`，解析出所有层的 Phase 定义。结合 assessment.md 中评估为"需要开发"的层，按 Phase 顺序循环编排：

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

只有 `upstream_ready: true` 时才能启动该 Phase 的 Thinker。如果上游尚未 `coded`，需要先完成上游 Phase 的编码。

#### 3.3.1 设计（Thinker）

调用 `/thoughtworks-skills-backend-thought <idea-name> --layers <本 Phase 需要开发的层列表>`

例如：
- Phase 1: `/thoughtworks-skills-backend-thought <idea-name> --layers domain`
- Phase 2: `/thoughtworks-skills-backend-thought <idea-name> --layers infr,application`
- Phase 3: `/thoughtworks-skills-backend-thought <idea-name> --layers ohs`

如果本 Phase 中所有层都被评估为"不需要开发"，跳过该 Phase。

#### 3.3.2 用户确认（HARD-GATE）

thought skill 完成后，展示本 Phase 的设计摘要：
1. **本 Phase 层级** — 哪些层已完成设计
2. **各层设计摘要** — 每层一句话概括
3. **产出文件列表** — 本 Phase 生成的设计文件

使用 AskUserQuestion 询问用户是否确认本 Phase 设计，提供以下选项：
- 确认设计，继续
- 修改某层设计（说明需要修改什么）
- 终止

<HARD-GATE>
用户确认后，对本 Phase 中每个层标记设计已确认：
```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --set {layer} confirmed
```
然后进入 3.3.3 编码阶段。禁止自动跳到编码。
</HARD-GATE>

#### 3.3.3 编码（Worker）

调用 `/thoughtworks-skills-backend-works <idea-name> --layers <本 Phase 需要开发的层列表>`

例如：
- Phase 1: `/thoughtworks-skills-backend-works <idea-name> --layers domain`
- Phase 2: `/thoughtworks-skills-backend-works <idea-name> --layers infr,application`
- Phase 3: `/thoughtworks-skills-backend-works <idea-name> --layers ohs`

#### 3.3.4 验证编码产出

works skill 返回后，验证本 Phase 的编码产出是否通过 verify pattern 检查。

### 3.4 标记完成

所有 Phase 完成后：

```bash
touch .thoughtworks/<idea-name>/.approved
```

### 3.5 合并分支

调用 `/thoughtworks-skills-merge <idea-name>`。

merge 技能将 `feature/<idea-name>` squash merge 回默认分支（main/master），生成一条合并提交消息，并删除本地功能分支。

<HARD-GATE>
merge 技能完成后才能进入 Step 4。
</HARD-GATE>

---

## Step 4: 执行工程支撑任务

检查 `.thoughtworks/<idea-name>/supplementary-tasks.md`：

```bash
cat .thoughtworks/<idea-name>/supplementary-tasks.md 2>/dev/null
```

如果文件不存在或为空 → 跳过此步骤。

对每项未完成的任务（仅限后端相关的工程支撑任务，如 Dockerfile-backend, application.yml 模板等）：

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
    {从已有代码推断的技术栈：后端框架、数据库、端口等}

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

## Step 5: 完成汇总

向用户展示：

1. **实现摘要** — 概括实现了什么
2. **各层完成状态** — 哪些层完成了设计和编码
3. **产出文件总列表** — 所有创建/修改的代码文件

---

## 中断处理

在 Step 3（Phase 执行和用户确认）时，Decision-Maker 识别用户意图：

| 用户输入 | Decision-Maker 决策 |
|---------|-------------------|
| 确认/继续 | 按当前流程推进 |
| "修改 {layer} 设计" | 将修改说明 + 现有设计传给 thought skill → 只启动该层 thinker → 覆写设计 → 重新校验 → 级联重做下游层 |
| "重新澄清需求" | 回到 Step 2 |
| "终止" | 保存当前状态后退出 |

### 级联影响处理

修改某层设计后，按 `workflow.yaml` 的 `requires` 反向查找下游层，重新派发受影响层的 Thinker：

```
修改 domain → 级联重做 infr + application → 级联重做 ohs
修改 application → 级联重做 ohs
修改 infr → 无下游级联
修改 ohs → 无下游级联
```

步骤：
1. 识别用户要修改哪一层
2. 将修改说明作为额外上下文，调用 thought skill 只重做该层的 thinker
3. 校验产出
4. 查找下游受影响的层（requires 中包含被修改层的层）
5. 如有下游层，继续调用 thought skill 重做受影响层
6. 重新展示设计摘要，回到 3.3.2 等用户确认

### 中断修改时的 thought skill 调用

单独调用 thought skill 重做某一层时，传入修改指令：

```
/thoughtworks-skills-backend-thought <idea-name> --layers <layer> --modification "<修改说明>"
```

thought skill 内部只启动指定层的 thinker，不重跑整个流程。

---

## 断点续传

Decision-Maker 支持从中断处恢复：

### 确定续传位置

检查 `.thoughtworks/<idea-name>/` 目录：
1. `.approved` 存在 → 已完成
2. `workflow-state.json` 存在 → 检查各层状态，从中断处继续
3. `assessment.md` 存在 → 从 Phase 循环继续
4. `requirement.md` 存在但无 assessment → 从层级评估开始

---

## 合理化预防

| 你可能会想 | 现实 |
|-----------|------|
| "需求已经很清楚，跳过澄清" | 必须至少确认一次目标和成功标准，用户可能有隐含假设 |
| "评估结果很明显，直接开始设计" | 必须写入 assessment.md 并初始化 workflow-state.json |
| "设计看起来没问题，直接开始编码" | 必须等用户确认，用户可能有不同看法 |
| "修改太小了，直接改设计文件" | 修改必须走 thinker 流程，保证契约一致性 |
| "只改了一层，不需要级联" | 必须检查下游依赖，层间契约可能已经不一致 |
| "用户说继续就行" | 分辨"继续当前步骤"和"跳过确认"的区别 |

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
