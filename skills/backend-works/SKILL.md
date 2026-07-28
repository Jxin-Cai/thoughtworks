---
name: backend-works
description: DDD 垂直子域编码编排——为每个子域启动 Worker subagent 实现完整垂直切片
argument-hint: "<idea-name>"

agent:
  - agent-ddd-worker
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

## Step 3: 编码执行循环

### 查询就绪子域

```bash
STACK=backend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --next-subdomains code
```

返回所有 status=confirmed 且依赖已满足的子域。

### 对每个就绪子域

1. **标记状态为 coding**：
```bash
STACK=backend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --set {subdomain} coding
```

2. **写入任务文件**：
```bash
cat > {IDEA_DIR}/.current-task-{subdomain}-$(date +%s).json << 'TASK_EOF'
{"role":"worker","subdomain":"{subdomain}","idea_dir":"{IDEA_DIR}","stack":"backend"}
TASK_EOF
```

3. **启动 Worker subagent**：

使用 Read 工具加载 `references/worker-prompt-skeleton.md`，按模板组装 prompt。

Prompt 包含：
- **TASK**：子域设计文档中的实现清单
- **EXECUTION CONTRACT**：subdomain_name、backend_language、实现顺序（domain→infr→app→ohs）
- **CONTEXT**：设计文档路径、verify patterns
- **OUTPUT**：在项目目录中创建代码文件

无依赖的子域可**并行启动**。

4. **subagent 返回后**：SubagentStop hook 自动将 `coding` → `coded`。验证产物：

```bash
# 用 Glob 按 verify patterns 检查各层产物
```

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

### 循环逻辑

- 查询 `--next-subdomains code` → 启动 → 等待返回 → 再次查询
- 如果某子域 coded 后解锁了下游子域（depends_on 满足），下一轮会返回它
- 循环直到无更多就绪子域

### 失败处理

- Worker subagent 标记失败 → 状态为 `failed`
- 最多重试 2 次，重试时在 prompt 开头追加 PRIOR ATTEMPT 信息
- 超过 2 次暂停询问用户

---

## Step 4: 汇总验证

所有子域 coded 后：

```bash
STACK=backend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --check-all
```

向用户报告编码完成状态，然后返回调用编排器继续下一步。
