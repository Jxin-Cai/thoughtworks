---
name: thoughtworks-skills-branch
description: Git feature branch management for development ideas
argument-hint: "<idea-name>"
---

# Feature Branch Management

在需求澄清完成后、层级评估之前，确保后续设计和编码产出在功能分支上进行。

用户传入的参数：`$ARGUMENTS`（即 `<idea-name>`）

---

## Step 1: 检查 git 环境

执行：
```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

- 如果返回非零（不是 git 仓库）→ 输出 `"当前目录不是 git 仓库，跳过功能分支管理。"` 并**结束**
- 如果返回 `true` → 继续 Step 2

---

## Step 2: 判断当前分支

执行：
```bash
git branch --show-current
```

设目标分支名 = `feature/$ARGUMENTS`（即 `feature/<idea-name>`）。

如果命令返回空字符串（detached HEAD 状态），视为"其他分支"，跳到 Step 4。

| 当前分支 | 行为 |
|---------|------|
| 等于目标分支 `feature/<idea-name>` | 输出 `"已在功能分支 feature/<idea-name> 上，无需切换。"` 并**结束** |
| `main` 或 `master` | → Step 3 |
| 其他分支 / detached HEAD | → Step 4 |

---

## Step 3: 从 main/master 创建功能分支

### 3.1 检查未提交变更

执行：
```bash
git status --porcelain
```

如果有输出（存在未提交变更），使用 AskUserQuestion 提示用户：

> 检测到未提交的变更。这些变更将被带到新的功能分支上。
>
> 选项：
> - 继续创建分支（变更会保留在工作区）
> - 取消，先处理未提交变更

用户选择取消 → 输出 `"用户取消了分支创建。"` 并**结束**。

### 3.2 创建或切换分支

检查目标分支是否已存在：
```bash
git branch --list "feature/<idea-name>"
```

| 情况 | 执行 |
|------|------|
| 目标分支已存在（输出非空） | `git checkout feature/<idea-name>` |
| 目标分支不存在（输出为空） | `git checkout -b feature/<idea-name>` |

输出 `"已切换到功能分支 feature/<idea-name>。"`

**结束。**

---

## Step 4: 处理其他分支

当前不在 main/master，也不在目标功能分支。使用 AskUserQuestion 询问用户：

> 当前在分支 `<current-branch>`，目标功能分支是 `feature/<idea-name>`。
>
> 选项：
> - 从当前分支创建 `feature/<idea-name>`
> - 先切回 main/master，再创建 `feature/<idea-name>`
> - 跳过分支管理，继续在当前分支上工作

| 用户选择 | 执行 |
|---------|------|
| 从当前分支创建 | 检查目标分支是否存在，存在则 `git checkout`，不存在则 `git checkout -b feature/<idea-name>` |
| 先切回 main/master | 检测默认分支（`git branch --list main` 或 `master`），`git checkout <default>`，然后按 Step 3 逻辑创建功能分支 |
| 跳过 | 输出 `"保持当前分支 <current-branch>，继续工作。"` 并**结束** |

**结束。**
