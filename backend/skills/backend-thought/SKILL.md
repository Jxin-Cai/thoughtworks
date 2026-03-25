---
name: backend-thought
description: Backend DDD design phase orchestrating thinker subagents for layered design docs
argument-hint: "<idea-name>"

agent:
  - agent-ddd-thinker
---

# DDD Spec-Driven Development — 思考流程

用户传入的参数：`$ARGUMENTS`

本 skill 专注于设计编排：接收 Decision-Maker 的指令 → 派发 Thinker subagent → 校验产出。

需求澄清和层级评估由 Decision-Maker（`/backend`）负责，本 skill 不再处理。

---

## 铁律

以下铁律适用于所有编排器和子技能。违反任何一条都可能导致流程失败。

1. **工作流数据源唯一性** — Phase 顺序、层定义（id/phase/requires/design-template）、验证模式（verify）必须从对应的 `workflow.yaml` 实际读取获得（后端从 `{DDD_HELP}/workflow.yaml`，前端从 `{FRONTEND_HELP}/workflow.yaml`）。禁止凭 SKILL.md 文本、记忆或推断确定这些信息。每次技能启动都必须重新用 Read 工具读取 workflow.yaml

2. **禁止跳过用户确认** — 每个 HARD-GATE 必须等待其前置条件满足后才能推进。编排器读取需求文件（docs/xxx.md）不等于执行了澄清技能、不等于完成了设计。**只有对应的产出文件实际存在才能推进**

3. **子技能完成后立即推进** — 每个子技能调用完成后，编排器必须立即推进到下一步，不要停下来等待用户额外指令。注意：此条仅适用于子技能已实际调用并完成的情况，不能用于跳过尚未执行的步骤

4. **确认由子技能负责** — 设计确认（AskUserQuestion）在 thought 子技能内部完成，编排器不重复确认

5. **Thinker 只产设计，Worker 只写代码** — 用户的调整请求一律路由到 Thinker，不影响 Worker

6. **门控脚本强制执行** — 每个 step 执行前后的门控检查必须通过 `gate-check.sh` 脚本执行，不得凭记忆或推断判断门控是否通过。用法：`bash {CORE}/scripts/gate-check.sh {IDEA_DIR} <gate-id>`

**本技能附加铁律：**

1. **上游依赖通过扫描已实现代码获取** — 构建 thinker subagent prompt 时，上游依赖接口通过指引 Thinker 扫描已实现的代码获取，不再从上游设计文档内联导出契约
2. **禁止在评估前启动设计** — assessment.md 必须已存在才能进入设计

---

## 产出目录

所有产出写入 `.thoughtworks/<idea-name>/` 目录：

```
.thoughtworks/<idea-name>/
├── requirement.md                    # 原始需求存档（由 Decision-Maker 写入）
├── assessment.md                     # 层级评估结果（由 Decision-Maker 写入）
├── workflow-state.yaml               # 层级状态（由 task 状态聚合推导）
├── task-workflow-state.yaml          # Task 级工作流状态
└── backend-designs/
    ├── domain/                          # Domain 层 task 设计文档
    │   ├── 001-order-aggregate.md
    │   └── 002-payment-aggregate.md
    ├── infr/                            # Infr 层 task 设计文档
    │   └── 001-order-repository.md
    ├── application/                     # Application 层 task 设计文档
    │   └── 001-order-management.md
    └── ohs/                             # OHS 层 task 设计文档
        └── 001-order-api.md
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

如果不存在，提示用户先运行 `/backend <需求>` 完成需求澄清和层级评估。

读取 `.thoughtworks/<idea-name>/assessment.md`，确定哪些层需要开发。

读取 `.thoughtworks/<idea-name>/requirement.md`，从 `## 技术选型` 章节提取后端语言（`BACKEND_LANG`）。如果未找到技术选型章节，默认 `BACKEND_LANG = java`。

根据 `BACKEND_LANG` 确定文件扩展名映射：
- `java` → `.java`
- `python` → `.py`
- `go` → `.go`

---

## Step 2: 读取工作流定义

<HARD-GATE>
必须用 Read 工具实际读取 `../backend-help/workflow.yaml` 并解析完成后，才能进入 Step 3。
禁止凭记忆或 SKILL.md 文本中的示例编排 Phase 顺序。
</HARD-GATE>

读取 `../backend-help/workflow.yaml`（backend-help skill 目录下），解析出：
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

所有层共用同一个通用 thinker agent（`agent-ddd-thinker`），其 frontmatter 配置了：
- **skills**：`[backend-help, backend-guide, backend-spec]`
- **tools**：`Read, Write, Edit, Glob, Grep`
- **model**：`opus`

主 agent 统一使用 `tw-backend:agent-ddd-thinker` 作为 `subagent_type`。agent 启动后自行通过 `/backend-guide` 和 `/backend-spec` 加载设计指令和编码规范。层级差异通过 CONTEXT 中的 `target_layer` 字段传递。动态 prompt 包含 MISSION、TEMPLATE、CONTEXT、OUTPUT 四个区块。

### 执行方式（主 agent DAG 编排）

主 agent 负责按 `workflow.yaml` 的 Phase 顺序编排，保证上游完成后再启动下游：

1. **确定要执行的层**：根据 `--layers` 参数（如有）过滤出本次要执行的层
2. **按 Phase 分组**：将要执行的层按 workflow.yaml 中的 `phase` 字段分组（phase 值相同的层属于同一 Phase）
3. **按 phase 从小到大遍历**：对每个 Phase 中的目标层，先执行启动前准备（见下方），再启动 thinker subagent。同一 Phase 内多层可**并行启动**（放在同一条消息的多个 Agent 调用中）
4. **等待当前 Phase 完成**：当前 Phase 所有 subagent 返回后，执行 `backend-workflow-status.sh --check-all` 检查状态
5. **进入下一 Phase**：当前 Phase 全部 done 后，继续下一个 Phase，重复步骤 3-4
6. 所有目标 Phase 完成后：
   - 扫描 `backend-designs/` 下各层子目录（domain/, infr/, application/, ohs/），提取每个 task 文件的 frontmatter，初始化 `task-workflow-state.yaml`（见下方）
   - 执行 `backend-workflow-status.sh --check-all` 获取全量校验结果
7. 校验通过 → 进入 Step 4；校验失败 → 只重启失败层的 thinker，附加失败原因

### Task 工作流状态初始化

所有 Thinker 完成后，编排器负责扫描 `backend-designs/` 下各层子目录中所有 task 文件的 frontmatter，构建 `--init-tasks` 命令的参数。每个 task 文件提取 `task_id`、`layer`、`depends_on`、`description` 字段，文件相对路径（`{layer}/{filename}`）作为 `file`。

```bash
# 对每个 task 文件提取 frontmatter 后拼接参数，格式：task_id:layer:depends_on:description:file
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --init-tasks {idea-name} \
  "domain-001:domain::Order 聚合:domain/001-order-aggregate.md" \
  "infr-001:infr:domain-001:Order 仓储:infr/001-order-repository.md" \
  "application-001:application:domain-001:订单管理:application/001-order-management.md" \
  "ohs-001:ohs:application-001:订单 API:ohs/001-order-api.md"
```

注意：`depends_on` 多个依赖用逗号分隔（如 `domain-001,domain-002`），无依赖用空字符串。

### subagent 启动前准备（每个层都执行）

在启动 thinker subagent **之前**，编排器必须执行以下两步：

1. **标记状态为 designing**：
```bash
bash {DDD_HELP}/scripts/backend-workflow-status.sh {IDEA_DIR} --set {layer} designing
```

2. **写入任务文件**（供 SubagentStop hook 收敛状态，文件名含时间戳避免并发冲突）：
```bash
cat > {IDEA_DIR}/.current-task-{layer}-$(date +%s).json << 'TASK_EOF'
{"role":"thinker","layer":"{layer}","idea_dir":"{IDEA_DIR}","stack":"backend"}
TASK_EOF
```

> SubagentStop hook 会在 subagent 结束后自动将 `designing` → `designed`。编排器无需手动设置 `designed` 状态。

如果某个 Phase 中没有目标层（因为 `--layers` 过滤或评估为不需要），直接跳过该 Phase。

**禁止使用 --wait-upstream 或 --wait-all 的阻塞轮询模式**（与 Claude Code Bash 120s 超时不兼容）。

如果某层不需要开发，不注册到 workflow-state.yaml，该层的 Phase 直接跳过。

### CONTEXT 区块构建规则（上游依赖来源判定）

对于当前层的每个上游依赖（`workflow.yaml` 中 `requires` 列出的层），使用 Read 工具加载 `references/upstream-scan-guide.md`，按情况 A 或 B 生成对应的 CONTEXT 子区块。无上游依赖时（如 domain 层）省略。

### 构建 subagent prompt

使用 Read 工具加载 `references/thinker-prompt-skeleton.md`，按其模板为每个层组装 prompt。

从 `workflow.yaml` 中读取该层的 `thinker-ref`（获取 agent name）和 `design-template`（指向 `assets/{layer}-design.md`）路径。

### 产出验证

每个 Phase 的 subagent 全部返回后，主 agent 执行 `backend-workflow-status.sh --check-all` 获取校验结果。

根据 `validation.status` 判断：
- `pass` — 全部通过，进入 Step 4
- `fail` — 执行 `backend-workflow-status.sh --check-all --verbose` 获取完整失败详情，查看 `validation.checks` 中 `pass: false` 的条目，只重启对应层的 thinker subagent。**每层最多重试 2 次**，超过后暂停并用 AskUserQuestion 询问用户是手动修复还是跳过该层

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
3. **Task 列表** — 每个 task 的 task_id、层、描述、依赖关系
4. **产出文件列表** — 列出所有生成的 task 文件路径

<HARD-GATE>
展示完毕后，使用 AskUserQuestion 询问用户是否确认设计。
用户确认后，本技能完成。你现在必须立即回到调用你的编排器，继续执行编排器的下一个步骤（标记 confirmed → 编码）。禁止停下来等待用户指令，禁止提示用户手动运行任何命令。
</HARD-GATE>
