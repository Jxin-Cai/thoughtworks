---
name: backend-thought
description: DDD 垂直子域设计编排——为每个子域启动 Thinker subagent 产出全层设计文档
argument-hint: "<idea-name>"

agent:
  - agent-ddd-thinker
---

# DDD 垂直子域设计编排

用户传入的参数：`$ARGUMENTS`

本 skill 编排设计阶段：接收 Decision-Maker 指令 → 为每个子域启动 Thinker subagent → 校验产出。

---

## 路径变量

| 变量 | 路径 |
|------|------|
| `{DDD_HELP}` | `../backend-help` |
| `{SCRIPTS}` | `../../scripts` |

---

## 铁律

<HARD-GATE>
使用 Read 工具加载 `../_shared/references/iron-rules.md`，严格遵守其中所有条目。
</HARD-GATE>

---

## Step 1: 确定 idea 并读取上下文

解析 `$ARGUMENTS` 确定 idea-name（必选）和可选参数 `--modification "<修改说明>"`。

检查前置条件：

```bash
node {SCRIPTS}/gate-check.mjs {IDEA_DIR} --batch requirement-exists,assessment-exists
```

<HARD-GATE>
两个检查都必须 `pass`。否则提示用户先运行 `/backend <需求>` 完成需求澄清和评估。
</HARD-GATE>

读取 `.thoughtworks/<idea-name>/assessment.md`，确定：
- 哪些**子域**需要设计（assessment 新格式按子域列出）
- 子域间的依赖关系

读取 `.thoughtworks/<idea-name>/requirement.md`，提取 `BACKEND_LANG`（默认 java）。

---

## Step 2: 读取工作流定义

<HARD-GATE>
必须用 Read 工具读取 `../backend-help/workflow.yaml`。
</HARD-GATE>

解析出：
- `agents.thinker` 引用
- `design-template` 路径
- `verify` patterns（用于后续验证）

---

## Step 3: 子域设计（并行 subagent 执行）

为每个需要设计的子域启动独立 Thinker subagent，**无依赖的子域并行启动**。

### 执行方式（并行批次）

1. **确定子域列表**：从 assessment.md 提取子域及其依赖关系
2. **计算并行批次**：所有无依赖（或依赖已 `designed`/`confirmed`/`coded`）的子域组成当前批次
3. **对批次内所有子域同时执行启动准备**（标记 designing + 写任务文件）
4. **在同一个 tool call 消息中并行启动所有 Thinker subagent**
5. **所有并行 subagent 返回后**：逐个执行产出验证 + 设计审查
6. **展示进度**：`node {SCRIPTS}/progress-view.mjs {IDEA_DIR} backend`
7. **检查下一批**：上游 designed 后可能解锁了下游子域，重复步骤 2-6
8. **所有子域完成后**：初始化 `workflow-state.yaml`，执行汇总校验

### 并行批次判定规则

子域 X 可进入当前批次的条件：
- X 的 status 为 `pending`（或 `failed` 待重试）
- X 的 `depends_on` 列表中所有子域的 status 已为 `designed`、`confirmed` 或 `coded`

如果当前批次只有 1 个子域，退化为单子域执行（无并行开销）。

### subagent 启动前准备

对**批次内每个**子域：

1. **标记状态为 designing**：
```bash
STACK=backend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --set {subdomain} designing
```

2. **写入任务文件**（供 SubagentStop hook 收敛状态）：
```bash
cat > {IDEA_DIR}/.current-task-{subdomain}-$(date +%s).json << 'TASK_EOF'
{"role":"thinker","subdomain":"{subdomain}","idea_dir":"{IDEA_DIR}","stack":"backend"}
TASK_EOF
```

> SubagentStop hook 自动将 `designing` → `designed`。

### 并行启动 subagent

<HARD-GATE>
批次内有多个子域时，必须在**同一个 Agent tool call 块中**并行启动所有 Thinker subagent。
禁止逐个启动等待返回再启动下一个。
</HARD-GATE>

```
// 并行启动示例（2 个子域）
Agent(subagent_type: "tw:agent-ddd-thinker", prompt: subdomain_A_prompt)
Agent(subagent_type: "tw:agent-ddd-thinker", prompt: subdomain_B_prompt)
```

### 构建 subagent prompt

使用 Read 工具加载 `references/thinker-prompt-skeleton.md`，按其模板组装 prompt。

每个子域的 prompt 包含：
- **MISSION**：子域范围和工作项（从 assessment.md 提取）
- **DECISIONS**：subdomain_name、backend_language、依赖的其他子域
- **TEMPLATE**：`assets/subdomain-design.md` 的绝对路径
- **CONTEXT**：requirement.md 路径 + 上游代码扫描指引
- **OUTPUT**：写入路径 `backend-designs/{nnn}-{subdomain-slug}.md`

**`--modification` 处理**：如存在，在 MISSION 前注入修改说明块。

### 产出验证（逐子域串行）

并行 subagent 全部返回后，**逐个**验证每个子域产出：

```bash
node {DDD_HELP}/scripts/backend-output-validate.mjs {IDEA_DIR} --subdomain {subdomain}
```

失败时重启 thinker（最多 2 次），附加上次失败信息。超过 2 次暂停询问用户。

### 设计审查（逐子域串行，对抗性质量校验）

每个子域设计验证通过后，启动多维对抗审查 Workflow：

1. **确定审查力度**：读取 assessment.md 中该子域的复杂度标注：
   - `simple` → mode=`light`（3 reviewer，无盲验证）
   - `normal`（默认）→ mode=`standard`（3 reviewer + 盲验证）
   - `complex` → mode=`deep`（3 reviewer + 盲验证 + 交叉评审）
   - 若 `$ARGUMENTS` 含 `--review-mode <mode>` 则覆盖

2. **调用 Workflow**：

```
Workflow({
  name: 'design-review',
  args: {
    designPath: "{IDEA_DIR}/backend-designs/{nnn}-{subdomain-slug}.md",
    requirementPath: "{IDEA_DIR}/requirement.md",
    principlesPath: "skills/backend-principles/references/architecture.md",
    subdomain: "{subdomain}",
    language: "{BACKEND_LANG}",
    mode: "{review_mode}"
  }
})
```

3. **结果处理**：
   - `status: "pass"` → 继续下一步
   - `status: "revise"` → 用 `--modification` 重新调用 Thinker（最多 1 次修订），修改内容从 `modifications[]` 拼接
   - 修订后再次审查仍为 `revise` → 暂停，向用户展示审查报告，由用户决定是否接受当前设计

### 错误处理（并行场景）

- 批次内某子域失败**不影响**同批其他子域的验证和审查流程
- 失败子域不阻塞下一批次的启动（只要下一批的依赖不包含该失败子域）
- 失败子域在所有批次完成后集中重试

### Workflow State 初始化

所有子域设计完成（含审查通过）后：

```bash
STACK=backend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --init {idea-name} {subdomain1} {subdomain2} ...
```

然后执行汇总校验：
```bash
STACK=backend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --check-all
```

---

## Step 4: 汇总展示与确认

向用户展示：

1. **子域列表** — 每个子域一句话概括
2. **子域间依赖** — DAG 关系
3. **产出文件列表** — 所有设计文件路径

<HARD-GATE>
使用 AskUserQuestion 询问用户是否确认设计。
确认后执行 `touch {IDEA_DIR}/.design-confirmed`。
然后立即返回调用编排器，继续下一步（标记 confirmed → 编码）。
</HARD-GATE>
