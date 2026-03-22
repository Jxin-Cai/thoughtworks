---
name: thoughtworks-skills-backend-thought
description: Backend DDD design phase orchestrating thinker subagents for layered design docs
argument-hint: "<idea-name>"

agent:
  - thoughtworks-agent-ddd-thinker
---

# DDD Spec-Driven Development — 思考流程

用户传入的参数：`$ARGUMENTS`

本 skill 专注于设计编排：接收 Decision-Maker 的指令 → 派发 Thinker subagent → 校验产出。

需求澄清和层级评估由 Decision-Maker（`/thoughtworks-skills-backend`）负责，本 skill 不再处理。

---

## 铁律

1. **上游依赖通过扫描已实现代码获取** — 构建 thinker subagent prompt 时，上游依赖接口通过指引 Thinker 扫描已实现的代码获取，不再从上游设计文档内联导出契约
2. **禁止在评估前启动设计** — assessment.md 必须已存在才能进入设计
3. **禁止跳过用户确认** — Step 4 展示设计摘要后，必须等用户确认才能提示下一步

---

## 产出目录

所有产出写入 `.thoughtworks/<idea-name>/` 目录：

```
.thoughtworks/<idea-name>/
├── requirement.md                    # 原始需求存档（由 Decision-Maker 写入）
├── assessment.md                     # 层级评估结果（由 Decision-Maker 写入）
└── backend-designs/                  # 各层设计文档（含 frontmatter + 实现清单）
    ├── domain.md                     # 领域层设计（按聚合分章节）
    ├── infr.md                       # 基础设施层设计
    ├── application.md                # 应用层设计
    └── ohs.md                        # OHS 层设计
```

---

## Step 1: 确定 idea 并读取上下文

解析 `$ARGUMENTS` 确定 idea-name 和可选参数。

### 参数解析

`$ARGUMENTS` 格式：`<idea-name> [--layers <layer1,layer2,...>] [--modification "<修改说明>"]`

- `idea-name`：必选，idea 名称
- `--layers`：可选，逗号分隔的层列表（如 `domain` 或 `infr,application`）。如不提供，执行所有评估为"需要开发"的层
- `--modification`：可选，修改说明（中断处理时由 Decision-Maker 传入）

检查前置条件：
1. `.thoughtworks/<idea-name>/requirement.md` 必须存在
2. `.thoughtworks/<idea-name>/assessment.md` 必须存在

如果不存在，提示用户先运行 `/thoughtworks-skills-backend <需求>` 完成需求澄清和层级评估。

读取 `.thoughtworks/<idea-name>/assessment.md`，确定哪些层需要开发。

读取 `.thoughtworks/<idea-name>/requirement.md`，从 `## 技术选型` 章节提取后端语言（`BACKEND_LANG`）。如果未找到技术选型章节，默认 `BACKEND_LANG = java`。

根据 `BACKEND_LANG` 确定文件扩展名映射：
- `java` → `.java`
- `python` → `.py`
- `go` → `.go`

---

## Step 2: 读取工作流定义

读取 `../thoughtworks-skills-backend-help/workflow.yaml`（thoughtworks-skills-backend-help skill 目录下），解析出：
- 所有层的定义（id、phase、design-template、thinker-ref、requires）
- 层之间的依赖关系（DAG）

---

## Step 3: 分层设计（subagent 执行）

为每个**需要设计**的层启动独立 Agent subagent。

**层的确定方式**：
- 如有 `--layers` 参数，只启动指定层的 Thinker（前提是这些层在 assessment.md 中被评估为"需要开发"）
- 无 `--layers` 参数时，启动所有评估为"需要开发"的层的 Thinker（保持现有行为）

subagent 之间信息隔离，因此设计文档模板和输入文档必须在 prompt 中提供。

**重要：使用自定义 agent 类型（而非 general-purpose）**

所有层共用同一个通用 thinker agent（`thoughtworks-agent-ddd-thinker`），其 frontmatter 配置了：
- **skills**：`[thoughtworks-skills-backend-spec, thoughtworks-skills-backend-guide]`，自动注入编码规范和层级设计指令
- **tools**：`Read, Write, Edit, Glob, Grep`
- **model**：`opus`

主 agent 统一使用 `thoughtworks-backend:thoughtworks-agent-ddd-thinker` 作为 `subagent_type`。层级差异通过 CONTEXT 中的 `target_layer` 字段传递，agent 启动后通过 `backend-guide` skill 路由加载对应层级的设计指令。动态 prompt 只需包含 MISSION、TEMPLATE、CONTEXT、OUTPUT 四个动态区块。

### 执行方式（主 agent DAG 编排）

主 agent 负责按 `workflow.yaml` 的 Phase 顺序编排，保证上游完成后再启动下游：

1. **确定要执行的层**：根据 `--layers` 参数（如有）过滤出本次要执行的层
2. **按 Phase 分组**：将要执行的层按 Phase 分组
3. **Phase 1**：对每个目标层，先执行启动前准备（见下方），再启动 thinker subagent（如 domain）
4. **等待 Phase 1 完成**：所有 Phase 1 的 subagent 返回后，执行 `backend-workflow-status.sh --check-all` 检查状态
5. **Phase 2**：Phase 1 全部 done 后，对每个目标层执行启动前准备，再**并行启动**所有 phase=2 的目标层（如 infr + application，放在同一条消息的多个 Agent 调用中）
6. **等待 Phase 2 完成**
7. **Phase 3**：Phase 2 全部 done 后，对目标层执行启动前准备，再启动 phase=3 的目标层（如 ohs）
8. 所有目标 Phase 完成后，执行 `backend-workflow-status.sh --check-all` 获取全量校验结果
9. 校验通过 → 进入 Step 4；校验失败 → 只重启失败层的 thinker，附加失败原因

### subagent 启动前准备（每个层都执行）

在启动 thinker subagent **之前**，编排器必须执行以下两步：

1. **标记状态为 designing**：
```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --set {layer} designing
```

2. **写入任务文件**（供 SubagentStop hook 收敛状态）：
```bash
cat > {IDEA_DIR}/.current-task-{layer}.json << 'TASK_EOF'
{"role":"thinker","layer":"{layer}","idea_dir":"{IDEA_DIR}","stack":"backend"}
TASK_EOF
```

> SubagentStop hook 会在 subagent 结束后自动将 `designing` → `designed`。编排器无需手动设置 `designed` 状态。

如果某个 Phase 中没有目标层（因为 `--layers` 过滤或评估为不需要），直接跳过该 Phase。

**禁止使用 --wait-upstream 或 --wait-all 的阻塞轮询模式**（与 Claude Code Bash 120s 超时不兼容）。

如果某层不需要开发，不注册到 workflow-state.json，该层的 Phase 直接跳过。

### CONTEXT 区块构建规则（上游依赖来源判定）

对于当前层的每个上游依赖（`workflow.yaml` 中 `requires` 列出的层），按以下规则判定：

**情况 A：上游层代码已实现（本 Phase 之前的 Phase 已执行 Worker）**
即上游层的 Worker 已完成编码，代码存在于项目中。
→ 在 CONTEXT 中生成 `## 上游已实现代码` 子区块，指引 Thinker 扫描已有代码获取依赖接口列表：

```
## 上游已实现代码（{upstream-layer} 层）

{upstream-layer} 层的代码已经实现，你需要通过扫描已有代码来获取你需要依赖的接口列表。

### 扫描指引
- 建议扫描的包路径模式（按需选用，扩展名根据 BACKEND_LANG：Java→`.java`，Python→`.py`，Go→`.go`）：
  - 聚合根/实体：`**/domain/**/model/*.{ext}`
  - 仓储接口：`**/domain/**/repository/*.{ext}`
  - 领域事件：`**/domain/**/event/*.{ext}`
  - 防腐层接口：`**/domain/**/acl/*.{ext}`
  - 领域服务：`**/domain/**/service/*.{ext}`
  - 应用服务：`**/application/**/*ApplicationService.{ext}`（Python/Go 中可能命名不同，按包名搜索）
  - Command：`**/application/**/*Command.{ext}`（Python/Go 中可能命名不同，按包名搜索）

### 扫描原则
1. **需求驱动** — 只扫描 MISSION 工作目标中涉及的类和方法，不做全量扫描
2. **签名提取** — 对找到的类，用 Read 工具读取其公有方法签名和关键字段
3. **来源标注** — 依赖契约子表标题标注（来自已有代码），每行说明列附注源文件路径
```

**情况 B：上游层被评估为"不需要"且无已实现代码**
即 `assessment.md` 中该上游层标记为"不需要"，但项目中可能有历史代码。
→ 使用与情况 A 相同的 `## 上游已有代码` 子区块模板，但补充说明该层在本次需求中不需要新开发：

```
## 上游已有代码（{upstream-layer} 层 — 无当前设计文档）

{upstream-layer} 层在本次需求中不需要新开发，已有实现存在于代码库中。
你需要根据 MISSION 中的工作目标，使用 Glob 和 Grep 工具从已有代码中**按需扫描**所需的上游能力。

### 扫描指引
- assessment.md 中关于该层的说明："{从 assessment.md 提取该层的说明}"
- 建议扫描的包路径模式（按需选用，扩展名根据 BACKEND_LANG：Java→`.java`，Python→`.py`，Go→`.go`）：
  - 聚合根/实体：`**/domain/**/model/*.{ext}`
  - 仓储接口：`**/domain/**/repository/*.{ext}`
  - 领域事件：`**/domain/**/event/*.{ext}`
  - 防腐层接口：`**/domain/**/acl/*.{ext}`
  - 领域服务：`**/domain/**/service/*.{ext}`
  - 应用服务：`**/application/**/*ApplicationService.{ext}`
  - Command：`**/application/**/*Command.{ext}`

### 扫描原则
1. **需求驱动** — 只扫描 MISSION 工作目标中涉及的类和方法，不做全量扫描
2. **签名提取** — 对找到的类，用 Read 工具读取其公有方法签名和关键字段
3. **来源标注** — 依赖契约子表标题标注（来自已有代码），每行说明列附注源文件路径
```

**无上游依赖时**（如 domain 层）：省略上游相关子区块。

### 构建 subagent prompt

对每个需要的层，从 `workflow.yaml` 中读取该层的 `thinker-ref`（获取 agent name）和 `design-template`（指向 `assets/{layer}-design.md`）路径，然后按以下结构组装 prompt：

**所有层统一使用同一个 agent：**

```
Agent(
  subagent_type: "thoughtworks-backend:thoughtworks-agent-ddd-thinker",
  max_turns: 20,
  description: "{Layer} 层思考",
  prompt: "
    # MISSION（工作目标 — 结论先行，先理解你要做什么）

    {主 agent 根据 assessment.md 中该层的评估结论，用 2-4 句话总结该层的核心工作目标}

    具体包括：
    {主 agent 根据评估结论列出的该层需要完成的具体工作项，每项一行}

    {仅 domain 层追加以下内容：}
    ## 聚合结构要求

    requirement.md 的聚合分析章节列出了所有识别的聚合及其依赖关系。
    按聚合分析中的建议实现顺序，为每个聚合输出独立的 `## 聚合: {Name}` 章节。
    如果只有一个聚合，仍使用 `## 聚合: {Name}` 结构。
    每个聚合章节内包含完整设计（聚合根与实体、值对象、仓储接口等）和独立的 `### 导出契约`。

    你的设计方案完成后，必须回头逐条验证上述每个工作项都有对应的设计产出。

    ---

    # TEMPLATE（产出骨架 — 写入文件的结构）

    使用 Read 工具加载设计文档模板：`{design-template 的绝对路径}`
    严格按照模板结构输出设计文档。

    ---

    # CONTEXT（输入文档 — 读取作为上下文）

    ## 目标层级
    target_layer: {layer}

    ## 后端语言
    backend_language: {BACKEND_LANG}

    {对每个上游层，按 CONTEXT 区块构建规则的情况 A 或 B 生成对应子区块：}

    {情况 A — 上游层代码已实现时：}
    ## 上游已实现代码（{upstream-layer} 层）
    {按 CONTEXT 区块构建规则情况 A 的模板生成，包含扫描指引和扫描原则}

    {情况 B — 上游层被评估为"不需要"时：}
    ## 上游已有代码（{upstream-layer} 层 — 无当前设计文档）
    {按 CONTEXT 区块构建规则情况 B 的模板生成，包含扫描指引和扫描原则}

    {无上游依赖时（如 domain 层）：省略上游相关子区块}

    ## 需求
    使用 Read 工具加载需求文档：`{IDEA_DIR}/requirement.md`

    ---

    # OUTPUT

    将设计文档写入：`.thoughtworks/<idea-name>/backend-designs/<layer>.md`
    （主 agent 构建 prompt 时，将 `<idea-name>` 和 `<layer>` 替换为实际值的绝对路径）
    使用 Write 工具写入。

    重要：TEMPLATE 是你的产出结构，MISSION / CONTEXT 是你的参考约束，不要将它们复制到产出文件中。
  "
)
```

### MISSION 区块填充规则

主 agent 在组装 prompt 时，需要从 `assessment.md` 的该层评估部分提取信息，生成结论先行的工作目标描述：

1. **总结句** — 用 2-4 句话说明这一层要做什么、为什么要做
2. **具体工作项** — 从评估结论中提炼出 numbered list，每项是一个可验证的工作目标（如"设计 Order 聚合根，包含创建、修改状态、计算总价三个核心业务方法"）
3. **验证锚点** — 这些工作项将成为 thinker 反思循环中逐条验证的基准

注意：自定义 agent 的 `skills: [thoughtworks-skills-backend-spec]` 字段会自动将编码规范注入到 subagent 上下文中，无需主 agent 手动内联。

### 产出验证

每个 Phase 的 subagent 全部返回后，主 agent 执行 `backend-workflow-status.sh --check-all` 获取校验结果。

根据 `validation.status` 判断：
- `pass` — 全部通过，进入 Step 4
- `fail` — 查看 `validation.checks` 中 `pass: false` 的条目，只重启对应层的 thinker subagent。**每层最多重试 2 次**，超过后暂停并用 AskUserQuestion 询问用户是手动修复还是跳过该层

重启 thinker 时，在 prompt 开头追加：

```
---

# PREVIOUS ATTEMPT FAILURE

上次设计验证发现以下问题，请在本次输出中修正：

{逐条列出 validation.checks 中 pass: false 的 rule + detail}

---
```

---

## Step 4: 汇总展示

所有 thinker 完成后，向用户展示：

1. **层级评估结论** — 哪些层需要开发
2. **各层设计摘要** — 每层一句话概括
3. **各层 thought 文件数** — 每个层产出了几个 thought 文件
4. **产出文件列表** — 列出所有生成的文件路径

<HARD-GATE>
展示完毕后，使用 AskUserQuestion 询问用户是否确认设计。
用户确认后，本技能完成。你现在必须立即回到调用你的编排器，继续执行编排器的下一个步骤（标记 confirmed → 编码）。禁止停下来等待用户指令，禁止提示用户手动运行任何命令。
</HARD-GATE>
