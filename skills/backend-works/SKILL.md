---
name: backend-works
description: DDD 垂直子域编码编排——为每个子域启动 Worker subagent 实现完整垂直切片
argument-hint: "<idea-name>"

agent:
  - agent-ddd-worker
  - agent-verifier
---

# DDD 垂直子域编码编排

用户传入的参数：`$ARGUMENTS`

本 skill 编排编码阶段：查询就绪子域 → 为每个子域启动 Worker subagent → 验证产出。

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

## Step 1: 确定 idea 并检查前置条件

解析 `$ARGUMENTS` 确定 idea-name。

```bash
node {SCRIPTS}/gate-check.mjs {IDEA_DIR} --batch requirement-exists,assessment-exists,designs-exist
```

<HARD-GATE>
全部 `pass` 才能继续。`designs-exist` 检查 `backend-designs/` 下有子域设计文件。
</HARD-GATE>

读取 `.thoughtworks/<idea-name>/requirement.md` 提取 `BACKEND_LANG`（默认 java）。

---

## Step 2: 读取工作流配置

读取 `../backend-help/workflow.yaml`，获取：
- `agents.worker` 引用
- `verify` patterns（按语言×层）

---

## Step 3: 编码执行循环（并行批次）

### 查询就绪子域

```bash
STACK=backend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --next-subdomains code
```

返回所有 status=confirmed 且依赖已满足的子域（可能多个）。

### 并行启动所有就绪子域

对**所有**返回的就绪子域同时执行：

1. **对每个就绪子域标记状态为 coding**：
```bash
STACK=backend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --set {subdomain} coding
```

2. **对每个就绪子域写入任务文件**：
```bash
cat > {IDEA_DIR}/.current-task-{subdomain}-$(date +%s).json << 'TASK_EOF'
{"role":"worker","subdomain":"{subdomain}","idea_dir":"{IDEA_DIR}","stack":"backend"}
TASK_EOF
```

3. **在同一个 tool call 消息中并行启动所有 Worker subagent**：

<HARD-GATE>
就绪子域有多个时，必须在**同一个 Agent tool call 块中**并行启动所有 Worker subagent。
禁止逐个启动等待返回再启动下一个。
</HARD-GATE>

```
// 并行启动示例（多个就绪子域）
Agent(subagent_type: "tw:agent-ddd-worker", prompt: subdomain_X_prompt)
Agent(subagent_type: "tw:agent-ddd-worker", prompt: subdomain_Y_prompt)
```

使用 Read 工具加载 `references/worker-prompt-skeleton.md`，按模板组装每个子域的 prompt。

Prompt 包含：
- **TASK**：子域设计文档中的实现清单
- **EXECUTION CONTRACT**：subdomain_name、backend_language、实现顺序（domain→infr→app→ohs）
- **CONTEXT**：设计文档路径、verify patterns
- **OUTPUT**：在项目目录中创建代码文件

### 批次返回后处理（逐子域串行）

所有并行 subagent 返回后，**逐个**对每个子域执行：

4. **产物验证**：SubagentStop hook 已自动清理任务文件。用 Glob 按 verify patterns 检查各层产物。

5. **代码审查（对抗性质量校验）**：

产物验证通过后，启动多维对抗审查 Workflow：

**确定审查力度**：读取 assessment.md 中该子域的复杂度标注：
- `simple` → mode=`light`（4 reviewer，无对抗验证）
- `normal`（默认）→ mode=`standard`（4 reviewer + 对抗验证 + 自动修复）
- `complex` → mode=`deep`（4 reviewer + 对抗验证 + 自动修复）
- 若 `$ARGUMENTS` 含 `--review-mode <mode>` 则覆盖

**调用 Workflow**：

```
Workflow({
  name: 'code-review',
  args: {
    designPath: "{IDEA_DIR}/backend-designs/{nnn}-{subdomain-slug}.md",
    codePaths: ["{从 verify patterns 推导出的 glob 列表}"],
    conventionsPath: "skills/backend-principles/references/{BACKEND_LANG}/conventions.md",
    subdomain: "{subdomain}",
    language: "{BACKEND_LANG}",
    mode: "{review_mode}",
    ideaDir: "{IDEA_DIR}"
  }
})
```

**结果处理**：
- `status: "pass"` → 保持 `coded` 状态
- `status: "fixed"` → 保持 `coded` 状态（workflow 已自动修复代码）
- `status: "needs_fix"` → 重新调用 Worker（最多 1 次），prompt 追加审查 findings 作为修复指引
- `status: "blocked"` → 标记 `failed`，向用户报告回归问题

6. **独立编译验证**（code-review 通过后）：

启动 Verifier Agent 执行实际编译：

```
Agent(subagent_type: "tw:agent-verifier", prompt: "
  # CONTEXT
  - subdomain_name: {subdomain}
  - backend_language: {BACKEND_LANG}
  - project_root: {项目根目录}
  - scope: {从 verify patterns 推导的文件范围}
  # 仅执行编译验证，不跑测试和 lint
")
```

**验证结果处理**：
```bash
node {SCRIPTS}/verify-result.mjs {IDEA_DIR} {subdomain} '<agent输出的JSON>'
```
- `pass` → 保持 `coded` 状态
- `fail` → 提取编译错误信息，重新调用 Worker（最多 1 次），prompt 包含编译错误作为修复上下文
- 重试仍 fail → 标记 `failed`，向用户报告具体编译错误

### 展示进度

每个并行批次全部处理完成后，展示工作流进度：
```bash
node {SCRIPTS}/progress-view.mjs {IDEA_DIR} backend
```

### 循环逻辑

- 并行批次完成后 → 再次查询 `--next-subdomains code`
- 上一批有子域 coded 后，其下游子域的依赖可能已满足，会出现在新查询结果中
- 循环直到无更多就绪子域

### 错误处理（并行场景）

- 批次内某子域失败**不影响**同批其他子域的审查和验证流程
- 失败子域不阻塞下一批次的启动（只要下一批的依赖不包含该失败子域）
- 最多重试 2 次，重试时在 prompt 开头追加 PRIOR ATTEMPT 信息（含编译错误或 review findings）
- 超过 2 次暂停询问用户

---

## Step 4: 汇总验证

所有子域 coded 后：

```bash
STACK=backend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --check-all
```

向用户报告编码完成状态，然后返回调用编排器继续下一步。
