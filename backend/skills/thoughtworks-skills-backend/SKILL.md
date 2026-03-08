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

你是 Decision-Maker，负责编排整个 DDD 后端开发流程：从需求澄清、层级评估、设计编排到编码执行。

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
  ├── /thoughtworks-backend-clarify  (需求澄清: 项目上下文扫描 + 结构化提问)
  ├── /thoughtworks-branch           (功能分支管理: 创建 feature/<idea-name>)
  ├── /thoughtworks-backend-thought  (Thinker 编排: 并行启动 + 自协调 + 校验)
  └── /thoughtworks-backend-works    (Worker 编排: DAG 拓扑序执行 + 验证)
```

---

## 状态机

启动时根据当前状态决策行为：

| 状态 | 判断方式 | 行为 |
|------|---------|------|
| 无 idea | `$ARGUMENTS` 为空或新需求 | → Step 1 接收需求 → Step 2 澄清 |
| 有 idea，无 designs | `backend-designs/` 为空 | → Step 3 评估 → Step 4 Phase 循环编排 |
| 有 idea，designs 部分 pending | frontmatter status 有 pending | → Step 4 继续 Phase 循环编排 |
| 有 idea，某层 designing | `workflow-state.json` 某层为 `designing` | → Step 4 从该层重新启动 Thinker |
| 有 idea，某层 designed | `workflow-state.json` 某层为 `designed`，未确认 | → Step 4.2 等用户确认该 Phase 设计 |
| 有 idea，某层 coding | `workflow-state.json` 某层为 `coding` | → Step 4.3 从该层重新启动 Worker |
| 有 idea，designs 全 done，未确认 | 无 `.approved` 标记 | → Step 5 标记完成 |
| 有 idea，设计已确认，未编码 | `.approved` 存在，代码未生成 | → Step 4 从未编码的 Phase 继续 |
| 用户要求修改设计 | 用户中断提出修改请求 | → 中断处理 |

启动时检查：
1. 解析 `$ARGUMENTS` 确定 idea-name
2. 检查 `.thoughtworks/<idea-name>/` 目录是否存在
3. 如存在，检查 `backend-designs/` 是否有设计文件、frontmatter status、`.approved` 标记
4. 根据上表决定从哪个 Step 开始

---

## Step 1: 接收需求

判断 `$ARGUMENTS`：

| 情况 | 处理 |
|------|------|
| 以 `/` 或 `./` 开头，或含 `.md` `.txt` 扩展名 | Read 工具读取文件内容 |
| 非空文本 | 直接作为需求 |
| 空 | AskUserQuestion 询问用户 |

从需求中提取 kebab-case 名称作为 `idea-name`（如"用户注册功能" → `user-registration`）。

执行：

1. `mkdir -p .thoughtworks/<idea-name>/backend-designs`
2. 如果 `.thoughtworks/<idea-name>/requirement.md` 已存在，使用 AskUserQuestion 询问用户：是覆盖已有需求重新开始，还是基于已有需求继续。用户确认覆盖后才写入；否则保留已有内容，跳到 Step 2
3. 将需求原文写入 `.thoughtworks/<idea-name>/requirement.md`
4. 检查项目根目录的 `.gitignore` 文件，如果不包含 `.thoughtworks/`，则追加一行 `.thoughtworks/`。

---

## Step 2: 需求澄清

调用澄清技能完成需求澄清，不再内联澄清逻辑。

### 执行方式

调用 `/thoughtworks-backend-clarify <idea-name>`。

澄清技能内部完成：
- 项目上下文扫描（目录结构、关键文档、最近提交、已有领域模型）
- 基于上下文的结构化提问（目标、约束、成功标准、边界）
- 需求确认和分工预览
- 写入 `requirement.md`（如已存在则更新）

<HARD-GATE>
澄清技能完成后才能进入 Step 2.5。
如果 `requirement.md` 已存在且用户未要求重新澄清，可跳过此步骤直接进入 Step 2.5。
</HARD-GATE>

---

## Step 2.5: 功能分支管理

调用 `/thoughtworks-branch <idea-name>`。

分支技能会自动检查当前 git 环境，在 main/master 上时创建 `feature/<idea-name>` 分支，确保后续设计和编码产出在功能分支上进行。

<HARD-GATE>
分支技能完成后才能进入 Step 3。
</HARD-GATE>

---

## Step 3: 层级评估（Decision-Maker 亲自执行）

**你（Decision-Maker）亲自执行评估**，不启动 subagent。

### 评估维度

使用 Read 工具读取 `../../assets/assessment-dimensions.md`，获取各层的评估维度和 assessment.md 输出格式。根据需求逐层判断是否需要开发。

### 执行

1. 读取 `../thoughtworks-skills-backend-help/workflow.yaml`，解析出所有层的定义
2. 读取 `../../assets/assessment-dimensions.md`，获取评估维度和输出格式
3. 逐层评估，将结果按模板格式写入 `.thoughtworks/<idea-name>/assessment.md`

3. 评估完成后，初始化工作流状态文件。**只注册评估为"需要开发"的层**：

```bash
# 一次性初始化，传入 idea-name 和所有需要开发的层
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --init <idea-name> <layer1> [layer2...]
# 示例：bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --init user-registration domain infr application ohs
```

不在 `workflow-state.json` 中的层不会被等待、不会被校验。

<HARD-GATE>
在 assessment.md 写入完成之前，禁止进入 Step 4。
禁止以"需求很明确，不需要评估"为由跳过此步骤。
</HARD-GATE>

---

## Step 4: 按 Phase 编排设计与编码

Decision-Maker 不直接操控 thinker/worker subagent，而是调用 thought 和 works 子技能完成编排。

### 执行方式

读取 `../thoughtworks-skills-backend-help/workflow.yaml`，解析出所有层的 Phase 定义。结合 assessment.md 中评估为"需要开发"的层，按 Phase 顺序循环编排：

```
Phase 1: domain
Phase 2: infr, application（并行）
Phase 3: ohs
```

对每个 Phase 执行以下步骤：

#### 4.0 检查上游就绪（Phase 2+）

从 Phase 2 开始，在启动 Thinker 之前，先检查本 Phase 各层的上游是否已编码完成：

```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --check-upstream <layer>
```

只有 `upstream_ready: true` 时才能启动该 Phase 的 Thinker。如果上游尚未 `coded`，需要先完成上游 Phase 的编码。

#### 4.1 设计（Thinker）

调用 `/thoughtworks-backend-thought <idea-name> --layers <本 Phase 需要开发的层列表>`

例如：
- Phase 1: `/thoughtworks-backend-thought <idea-name> --layers domain`
- Phase 2: `/thoughtworks-backend-thought <idea-name> --layers infr,application`
- Phase 3: `/thoughtworks-backend-thought <idea-name> --layers ohs`

如果本 Phase 中所有层都被评估为"不需要开发"，跳过该 Phase。

#### 4.2 用户确认（HARD-GATE）

thought skill 完成后，展示本 Phase 的设计摘要：
1. **本 Phase 层级** — 哪些层已完成设计
2. **各层设计摘要** — 每层一句话概括
3. **产出文件列表** — 本 Phase 生成的设计文件

使用 AskUserQuestion 询问用户是否确认本 Phase 设计，提供以下选项：
- 确认设计，继续
- 修改某层设计（说明需要修改什么）
- 终止

<HARD-GATE>
用户确认后才能进入 4.3 编码阶段。禁止自动跳到编码。
</HARD-GATE>

#### 4.3 编码（Worker）

调用 `/thoughtworks-backend-works <idea-name> --layers <本 Phase 需要开发的层列表>`

例如：
- Phase 1: `/thoughtworks-backend-works <idea-name> --layers domain`
- Phase 2: `/thoughtworks-backend-works <idea-name> --layers infr,application`
- Phase 3: `/thoughtworks-backend-works <idea-name> --layers ohs`

#### 4.4 验证编码产出

works skill 返回后，验证本 Phase 的编码产出是否通过 verify pattern 检查。

所有 Phase 完成后 → Step 5。

---

## Step 5: 标记完成

所有 Phase 的设计与编码完成后，写入确认标记：
```bash
touch .thoughtworks/<idea-name>/.approved
```

进入 Step 6。

---

## Step 6: 执行工程支撑任务

读取 `.thoughtworks/<idea-name>/supplementary-tasks.md`。如果文件不存在或为空 → 跳过此步骤。

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

## Step 7: 完成汇总

works skill 完成后，向用户展示：

1. **实现摘要** — 各层实现了什么
2. **产出文件列表** — 所有创建/修改的代码文件
3. **验证结果** — 代码产出是否通过 verify pattern 检查

---

## 中断处理

在 Step 4（Phase 循环中的用户确认和执行中发现问题）时，Decision-Maker 识别用户意图：

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
6. 重新展示设计摘要，回到 Step 4.2 等用户确认

### 中断修改时的 thought skill 调用

单独调用 thought skill 重做某一层时，传入修改指令：

```
/thoughtworks-backend-thought <idea-name> --layers <layer> --modification "<修改说明>"
```

thought skill 内部只启动指定层的 thinker，不重跑整个流程。

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

所有产出写入 `.thoughtworks/<idea-name>/` 目录：

```
.thoughtworks/<idea-name>/
├── requirement.md                    # 原始需求存档
├── assessment.md                     # 层级评估结果
├── workflow-state.json               # 工作流状态
├── .approved                         # 设计确认标记
└── backend-designs/                  # 各层设计文档
    ├── domain.md
    ├── infr.md
    ├── application.md
    └── ohs.md
```
