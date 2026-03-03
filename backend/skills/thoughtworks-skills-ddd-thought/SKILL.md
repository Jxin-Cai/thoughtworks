---
name: thoughtworks-skills-ddd-thought
description: Use when called by Decision-Maker or directly to execute DDD design phase. Orchestrates thinker subagents for layered design.
argument-hint: "<idea-name>"
agents:
  - thinkers/thoughtworks-agent-ddd-domain-thinker
  - thinkers/thoughtworks-agent-ddd-infr-thinker
  - thinkers/thoughtworks-agent-ddd-application-thinker
  - thinkers/thoughtworks-agent-ddd-ohs-thinker
---

# DDD Spec-Driven Development — 思考流程

用户传入的参数：`$ARGUMENTS`

本 skill 专注于设计编排：接收 Decision-Maker 的指令 → 派发 Thinker subagent → 校验产出。

需求澄清和层级评估由 Decision-Maker（`/thoughtworks-backend`）负责，本 skill 不再处理。

---

## 铁律

1. **上游契约必须内联** — 构建 thinker subagent prompt 时，上游导出契约必须完整内联；上游设计文档全文改为提供路径让 Agent 自行 Read 加载
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
    ├── domain.md                     # 领域层设计（含 frontmatter + 实现清单）
    ├── domain-{N}-{topic}.md         # 复杂场景拆分为多文件
    ├── infr.md                       # 基础设施层设计
    ├── application.md                # 应用层设计
    └── ohs.md                        # OHS 层设计
```

---

## Step 1: 确定 idea 并读取上下文

解析 `$ARGUMENTS` 确定 idea-name。

检查前置条件：
1. `.thoughtworks/<idea-name>/requirement.md` 必须存在
2. `.thoughtworks/<idea-name>/assessment.md` 必须存在

如果不存在，提示用户先运行 `/thoughtworks-backend <需求>` 完成需求澄清和层级评估。

读取 assessment.md，确定哪些层需要开发。

---

## Step 2: 读取工作流定义

读取 `../thoughtworks-skills-ddd-help/workflow.yaml`（thoughtworks-skills-ddd-help skill 目录下），解析出：
- 所有层的定义（id、phase、design-template、thinker-ref、requires）
- 层之间的依赖关系（DAG）

---

## Step 3: 分层设计（subagent 执行）

为每个**需要开发**的层启动独立 Task subagent。

subagent 之间信息隔离，因此设计文档模板和输入文档必须在 prompt 中提供。

**重要：使用自定义 agent 类型（而非 general-purpose）**

每个层都有对应的自定义 agent 定义文件（如 `thoughtworks-agent-ddd-domain-thinker`），其 frontmatter 配置了：
- **system prompt**（agent body）：包含设计步骤、反思循环、命名规范等静态指引
- **skills**：`[thoughtworks-skills-java-spec]`，自动注入编码规范路由规则到 subagent 上下文
- **tools**：`Read, Write, Glob, Grep`
- **model**：`sonnet`

主 agent 在构建 Task 调用时，使用 `workflow.yaml` 中 `thinker-ref` 对应的 agent name 作为 `subagent_type`。这样 agent body 和 skills 会自动加载，动态 prompt 只需包含 MISSION、TEMPLATE、CONTEXT、OUTPUT 等动态内容，无需重复内联 INSTRUCTION 和 CODING-SPEC。

### 执行方式（主 agent DAG 编排）

主 agent 负责按 `workflow.yaml` 的 Phase 顺序编排，保证上游完成后再启动下游：

1. **Phase 1**：启动所有 phase=1 的层的 thinker subagent（如 domain）
2. **等待 Phase 1 完成**：所有 Phase 1 的 subagent 返回后，执行 `ddd-workflow-status.sh --check-all` 检查状态
3. **Phase 2**：Phase 1 全部 done 后，**并行启动**所有 phase=2 的层（如 infr + application，放在同一条消息的多个 Task 调用中）
4. **等待 Phase 2 完成**
5. **Phase 3**：Phase 2 全部 done 后，启动 phase=3 的层（如 ohs）
6. 所有 Phase 完成后，执行 `ddd-workflow-status.sh --check-all` 获取全量校验结果
7. 校验通过 → 进入 Step 4；校验失败 → 只重启失败层的 thinker，附加失败原因

**禁止使用 --wait-upstream 或 --wait-all 的阻塞轮询模式**（与 Claude Code Bash 120s 超时不兼容）。

如果某层不需要开发，不注册到 workflow-state.json，该层的 Phase 直接跳过。

### 构建 subagent prompt

对每个需要的层，从 `workflow.yaml` 中读取该层的 `thinker-ref`（获取 agent name）和 `design-template`（指向 `assets/{layer}-design.md`）路径，然后按以下结构组装 prompt：

**agent name 映射：** 从 `thinker-ref` 路径提取文件名（去掉 `.md`）作为 `subagent_type`：
- domain → `thoughtworks-agent-ddd-domain-thinker`
- infr → `thoughtworks-agent-ddd-infr-thinker`
- application → `thoughtworks-agent-ddd-application-thinker`
- ohs → `thoughtworks-agent-ddd-ohs-thinker`

这些自定义 agent 的 body 已包含设计步骤、反思循环、命名规范等静态指引（即原来的 INSTRUCTION 区块内容），`skills: [thoughtworks-skills-java-spec]` 已配置自动注入编码规范（即原来的 CODING-SPEC 区块内容）。因此动态 prompt 只需包含 MISSION、TEMPLATE、CONTEXT、OUTPUT 四个动态区块。

```
Task(
  subagent_type: "{thinker-ref 文件名，去掉 .md}",
  max_turns: 20,
  description: "{Layer} 层思考",
  prompt: "
    # 启动后第一步

    执行以下命令标记本层开始设计：
    ```bash
    bash {DDD_HELP}/scripts/ddd-workflow-status.sh {IDEA_DIR} --set {layer} in_progress
    ```

    ---

    # MISSION（工作目标 — 结论先行，先理解你要做什么）

    {主 agent 根据 assessment.md 中该层的评估结论，用 2-4 句话总结该层的核心工作目标}

    具体包括：
    {主 agent 根据评估结论列出的该层需要完成的具体工作项，每项一行}

    你的设计方案完成后，必须回头逐条验证上述每个工作项都有对应的设计产出。

    ---

    # TEMPLATE（产出骨架 — 写入文件的结构）

    使用 Read 工具加载设计文档模板：`{design-template 的绝对路径}`
    严格按照模板结构输出设计文档。

    ---

    # CONTEXT（输入文档 — 读取作为上下文）

    ## 上游导出契约（你的依赖契约必须与此精确对应）
    {从上游设计文档中提取的 ## 导出契约 区的原文，如无上游则省略}

    ## 需求
    {requirement.md 的完整内容}

    ## 上游设计文档
    如需参考上游设计文档原文，使用 Read 工具按需加载以下文件：
    {列出上游设计文档的绝对路径列表}

    以上文件包含上游层的完整设计，你的依赖契约必须与上游导出契约精确对应。

    ---

    # OUTPUT

    将设计文档写入：`{产出文件的绝对路径}`
    使用 Write 工具写入。

    完成后执行：
    ```bash
    bash {DDD_HELP}/scripts/ddd-workflow-status.sh {IDEA_DIR} --set {layer} done
    ```

    ## frontmatter 要求

    设计文档必须以 YAML frontmatter 开头，包含以下字段：
    - spec_id: 设计文件标识，格式为 `Spec_{Layer}`（如 `Spec_Domain`、`Spec_Application`）
    - layer: 层标识（domain / infr / application / ohs）
    - order: 文件序号（单文件时为 1）
    - status: pending
    - depends_on: 同层内依赖的文件名列表（无依赖时为 []）
    - description: 一句话描述本文件的设计内容

    ## 实现清单要求

    设计文档末尾必须包含实现清单表格，列出本文件涉及的所有待实现项，格式：

    | # | output_id | 实现项 | 类型 | 说明 |
    |---|-----------|--------|------|------|
    | 1 | Output_{Layer}_{IdeaName}_01 | XxxClass | 新增 | ... |

    output_id 格式为 `Output_{Layer}_{IdeaName}_{两位序号}`，其中：
    - Layer: 当前层标识（Domain / Infr / Application / OHS）
    - IdeaName: idea-name 的 PascalCase 形式（如 user-registration → UserRegistration）
    - 序号: 从 01 开始的两位递增序号，在同一设计文件内递增

    ## 拆分规则

    - 默认产出单文件 `{layer}.md`，order 为 1
    - 当预估内容超过约 3000 字时，按功能独立性拆分为 `{layer}-{order}-{topic}.md`（如 `domain-1-user-aggregate.md`、`domain-2-order-aggregate.md`）
    - 有关联的内容不拆，保持在同一文件中
    - 拆分后的文件通过 depends_on 声明同层内依赖

    重要：TEMPLATE 是你的产出结构，MISSION / CONTEXT 是你的参考约束，不要将它们复制到产出文件中。
  "
)
```

### MISSION 区块填充规则

主 agent 在组装 prompt 时，需要从 `assessment.md` 的该层评估部分提取信息，生成结论先行的工作目标描述：

1. **总结句** — 用 2-4 句话说明这一层要做什么、为什么要做
2. **具体工作项** — 从评估结论中提炼出 numbered list，每项是一个可验证的工作目标（如"设计 Order 聚合根，包含创建、修改状态、计算总价三个核心业务方法"）
3. **验证锚点** — 这些工作项将成为 thinker 反思循环中逐条验证的基准

注意：自定义 agent 的 `skills: [thoughtworks-skills-java-spec]` 字段会自动将编码规范注入到 subagent 上下文中，无需主 agent 手动内联。

### 产出验证

每个 Phase 的 subagent 全部返回后，主 agent 执行 `ddd-workflow-status.sh --check-all` 获取校验结果。

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
用户确认后才能提示下一步。禁止自动跳到"运行 /thoughtworks-backend-works"。
</HARD-GATE>

5. **下一步** — 用户确认后，提示运行 `/thoughtworks-backend-works <idea-name>` 开始执行
