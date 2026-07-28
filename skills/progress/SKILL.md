---
name: progress
description: 显示工作流进度可视化（子域状态 DAG、完成百分比、当前编排步骤）
argument-hint: "[idea-name]"
---

# 工作流进度可视化

用户传入的参数：`$ARGUMENTS`

## 路径变量

| 变量 | 路径 |
|------|------|
| `{SCRIPTS}` | `../../scripts` |

---

## 执行逻辑

1. **确定 idea 目录**：
   - 如果 `$ARGUMENTS` 非空，idea-dir = `.thoughtworks/$ARGUMENTS`
   - 否则，扫描 `.thoughtworks/` 目录，选择最近修改的子目录

2. **检测 stack**：
   - 如果 `{IDEA_DIR}/workflow-state.yaml` 存在且 `{IDEA_DIR}/frontend-workflow-state.yaml` 也存在 → stack = `all`
   - 仅有 `workflow-state.yaml` → stack = `backend`
   - 仅有 `frontend-workflow-state.yaml` → stack = `frontend`

3. **运行可视化脚本**：

```bash
node {SCRIPTS}/progress-view.mjs {IDEA_DIR} {stack}
```

4. **直接输出**脚本的终端渲染结果（ANSI 彩色格式）
