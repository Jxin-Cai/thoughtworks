---
name: frontend-thought
description: 前端垂直 Feature 设计编排——为每个 Feature 启动 Thinker subagent 产出全层设计文档
argument-hint: "<idea-name>"

agent:
  - agent-frontend-thinker
---

# 前端垂直 Feature 设计编排

用户传入的参数：`$ARGUMENTS`

本 skill 编排前端设计阶段：接收 Decision-Maker 指令 → 为每个 Feature 启动 Thinker subagent → 校验产出。

---

## 路径变量

| 变量 | 路径 |
|------|------|
| `{FRONTEND_HELP}` | `../frontend-help` |
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
node {SCRIPTS}/gate-check.mjs {IDEA_DIR} --batch frontend-requirement-exists,frontend-assessment-exists
```

<HARD-GATE>
两个检查都必须 `pass`。
</HARD-GATE>

读取 `.thoughtworks/<idea-name>/frontend-assessment.md`，确定：
- 哪些 **Features** 需要设计
- Feature 间的依赖关系
- UI 风格（如有）

---

## Step 2: 读取工作流定义

<HARD-GATE>
必须用 Read 工具读取 `../frontend-help/workflow.yaml`。
</HARD-GATE>

解析出：
- `agents.thinker` 引用
- `design-template` 路径
- `verify` patterns

---

## Step 3: Feature 设计（subagent 执行）

为每个需要设计的 Feature 启动独立 Thinker subagent。

### 执行方式

1. **确定 Feature 列表**：从 frontend-assessment.md 提取 Feature 及依赖关系
2. **按依赖排序**：无依赖的 Feature 先设计（可并行）
3. **对每个 Feature 执行启动准备**，然后启动 subagent
4. **subagent 返回后**：执行产出验证
5. **所有 Feature 完成后**：初始化 `frontend-workflow-state.yaml`，执行汇总校验

### subagent 启动前准备

对每个 Feature：

1. **标记状态为 designing**：
```bash
STACK=frontend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --set {feature} designing
```

2. **写入任务文件**：
```bash
cat > {IDEA_DIR}/.current-task-{feature}-$(date +%s).json << 'TASK_EOF'
{"role":"thinker","feature":"{feature}","idea_dir":"{IDEA_DIR}","stack":"frontend"}
TASK_EOF
```

### 构建 subagent prompt

使用 `tw:agent-frontend-thinker` 作为 subagent_type。每个 Feature 的 prompt 包含：

- **MISSION**：Feature 范围和工作项（从 assessment 提取）
- **DECISIONS**：feature_name、ui_style（如有）、依赖的其他 Feature
- **TEMPLATE**：`assets/feature-design.md` 的绝对路径
- **CONTEXT**：frontend-requirement.md 路径 + 后端 OHS API 契约 + 已有前端代码扫描指引
- **OUTPUT**：写入路径 `frontend-designs/{nnn}-{feature-slug}.md`

### 产出验证

每个 subagent 返回后验证设计文件存在。失败最多重试 2 次。

### 设计审查（对抗性质量校验）

每个 Feature 设计验证通过后，启动多维对抗审查 Workflow：

1. **确定审查力度**：读取 frontend-assessment.md 中该 Feature 的复杂度标注：
   - `simple` → mode=`light`
   - `normal`（默认）→ mode=`standard`
   - `complex` → mode=`deep`
   - 若 `$ARGUMENTS` 含 `--review-mode <mode>` 则覆盖

2. **调用 Workflow**：

```
Workflow({
  name: 'design-review',
  args: {
    designPath: "{IDEA_DIR}/frontend-designs/{nnn}-{feature-slug}.md",
    requirementPath: "{IDEA_DIR}/frontend-requirement.md",
    principlesPath: "skills/frontend-principles/references/architecture.md",
    subdomain: "{feature}",
    language: "react-ts",
    mode: "{review_mode}"
  }
})
```

3. **结果处理**：
   - `status: "pass"` → 继续下一步
   - `status: "revise"` → 用 `--modification` 重新调用 Thinker（最多 1 次修订）
   - 修订后仍为 `revise` → 暂停，向用户展示审查报告

### Workflow State 初始化

所有 Feature 设计完成（含审查通过）后：

```bash
STACK=frontend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --init {idea-name} {feature1} {feature2} ...
```

---

## Step 4: 汇总展示与确认

向用户展示：

1. **Feature 列表** — 每个 Feature 一句话概括
2. **Feature 间依赖** — DAG 关系
3. **产出文件列表**

<HARD-GATE>
使用 AskUserQuestion 询问用户是否确认设计。
确认后执行 `touch {IDEA_DIR}/.frontend-design-confirmed`。
然后立即返回调用编排器。
</HARD-GATE>
