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

## Step 3: 子域设计（subagent 执行）

为每个需要设计的子域启动独立 Thinker subagent。

### 执行方式

1. **确定子域列表**：从 assessment.md 提取子域及其依赖关系
2. **按依赖排序**：无依赖的子域先设计（可并行），有依赖的等上游子域 designed 后再启动
3. **对每个子域执行启动准备**（见下方），然后启动 subagent
4. **subagent 返回后**：执行产出验证
5. **所有子域完成后**：初始化 `workflow-state.yaml`，执行汇总校验

### subagent 启动前准备

对每个子域：

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

### 构建 subagent prompt

使用 Read 工具加载 `references/thinker-prompt-skeleton.md`，按其模板组装 prompt。

每个子域的 prompt 包含：
- **MISSION**：子域范围和工作项（从 assessment.md 提取）
- **DECISIONS**：subdomain_name、backend_language、依赖的其他子域
- **TEMPLATE**：`assets/subdomain-design.md` 的绝对路径
- **CONTEXT**：requirement.md 路径 + 上游代码扫描指引
- **OUTPUT**：写入路径 `backend-designs/{nnn}-{subdomain-slug}.md`

**`--modification` 处理**：如存在，在 MISSION 前注入修改说明块。

### 产出验证

每个 subagent 返回后验证：

```bash
node {DDD_HELP}/scripts/backend-output-validate.mjs {IDEA_DIR} --subdomain {subdomain}
```

失败时重启 thinker（最多 2 次），附加上次失败信息。超过 2 次暂停询问用户。

### Workflow State 初始化

所有子域设计完成后：

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
