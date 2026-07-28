---
name: frontend-works
description: 前端垂直 Feature 编码编排——为每个 Feature 启动 Worker subagent 实现完整 FSD 切片
argument-hint: "<idea-name>"

agent:
  - agent-frontend-worker
  - agent-verifier
---

# 前端垂直 Feature 编码编排

用户传入的参数：`$ARGUMENTS`

本 skill 编排前端编码阶段：查询就绪 Feature → 启动 Worker subagent → 验证产出。

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

## Step 1: 确定 idea 并检查前置条件

解析 `$ARGUMENTS` 确定 idea-name。

```bash
node {SCRIPTS}/gate-check.mjs {IDEA_DIR} --batch frontend-requirement-exists,frontend-assessment-exists,frontend-designs-exist
```

<HARD-GATE>
全部 `pass` 才能继续。
</HARD-GATE>

---

## Step 2: 读取工作流配置

读取 `../frontend-help/workflow.yaml`，获取：
- `agents.worker` 引用
- `verify` patterns

---

## Step 3: 编码执行循环（并行批次）

### 查询就绪 Feature

```bash
STACK=frontend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --next-subdomains code
```

返回所有 status=confirmed 且依赖已满足的 Feature（可能多个）。

### 并行启动所有就绪 Feature

对**所有**返回的就绪 Feature 同时执行：

1. **对每个就绪 Feature 标记状态为 coding**：
```bash
STACK=frontend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --set {feature} coding
```

2. **对每个就绪 Feature 写入任务文件**：
```bash
cat > {IDEA_DIR}/.current-task-{feature}-$(date +%s).json << 'TASK_EOF'
{"role":"worker","feature":"{feature}","idea_dir":"{IDEA_DIR}","stack":"frontend"}
TASK_EOF
```

3. **在同一个 tool call 消息中并行启动所有 Worker subagent**：

<HARD-GATE>
就绪 Feature 有多个时，必须在**同一个 Agent tool call 块中**并行启动所有 Worker subagent。
禁止逐个启动等待返回再启动下一个。
</HARD-GATE>

使用 `tw:agent-frontend-worker` 作为 subagent_type。Prompt 包含：

- **TASK**：Feature 设计文档中的文件清单
- **EXECUTION CONTRACT**：feature_name、ui_style、实现顺序（Shared→Entities→Features→Pages→Router）
- **CONTEXT**：设计文档路径、verify patterns、已有代码扫描指引
- **OUTPUT**：在项目 src/ 目录中创建代码文件

### 批次返回后处理（逐 Feature 串行）

所有并行 subagent 返回后，**逐个**对每个 Feature 执行：

4. **产物验证**：SubagentStop hook 已自动清理任务文件。验证产出文件存在。

5. **代码审查（对抗性质量校验）**：

产物验证通过后，启动多维对抗审查 Workflow：

**确定审查力度**：读取 frontend-assessment.md 中该 Feature 的复杂度标注（同设计审查逻辑）。

**调用 Workflow**：

```
Workflow({
  name: 'code-review',
  args: {
    designPath: "{IDEA_DIR}/frontend-designs/{nnn}-{feature-slug}.md",
    codePaths: ["**/src/features/{feature}/**/*.*", "**/src/entities/{feature}/**/*.*", "**/src/pages/**/*.*"],
    conventionsPath: "skills/frontend-principles/references/react-ts/conventions.md",
    subdomain: "{feature}",
    language: "react-ts",
    mode: "{review_mode}",
    ideaDir: "{IDEA_DIR}"
  }
})
```

**结果处理**：
- `status: "pass"` → 保持 `coded`
- `status: "fixed"` → 保持 `coded`（workflow 已自动修复）
- `status: "needs_fix"` → 重新调用 Worker（最多 1 次）
- `status: "blocked"` → 标记 `failed`，向用户报告

6. **独立编译验证**（code-review 通过后）：

启动 Verifier Agent 执行前端编译：

```
Agent(subagent_type: "tw:agent-verifier", prompt: "
  # CONTEXT
  - subdomain_name: {feature}
  - backend_language: typescript
  - project_root: {项目根目录}
  - scope: src/features/{feature}/**
  # 仅执行编译验证（tsc --noEmit 或 npm run build）
")
```

**验证结果处理**：
```bash
node {SCRIPTS}/verify-result.mjs {IDEA_DIR} {feature} '<agent输出的JSON>'
```
- `pass` → 保持 `coded`
- `fail` → 重新调用 Worker（最多 1 次），prompt 包含编译错误
- 重试仍 fail → 标记 `failed`，向用户报告

### 展示进度

每个并行批次全部处理完成后：
```bash
node {SCRIPTS}/progress-view.mjs {IDEA_DIR} frontend
```

### 循环逻辑

- 并行批次完成后 → 再次查询 `--next-subdomains code`
- 上一批有 Feature coded 后可能解锁下游 Feature
- 循环直到无更多就绪 Feature

### 错误处理（并行场景）

- 批次内某 Feature 失败不影响同批其他 Feature
- 最多重试 2 次，超过后暂停询问用户

---

## Step 4: 汇总验证

所有 Feature coded 后：

```bash
STACK=frontend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --check-all
```

向用户报告编码完成状态，返回调用编排器。
