---
name: merge
description: Squash merge feature branch back to main/master
argument-hint: "<idea-name>"
---

# Feature Branch Merge

功能分支开发完成后，将 `feature/<idea-name>` 通过 squash merge 合并回默认分支（main/master），在默认分支上只留一条提交消息。

用户传入的参数：`$ARGUMENTS`（即 `<idea-name>`）

---

## Step 1: 检查 git 环境

执行：
```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

- 如果返回非零（不是 git 仓库）→ 输出 `"当前目录不是 git 仓库，跳过分支合并。"` 并**结束**
- 如果返回 `true` → 继续 Step 2

---

## Step 2: 判断当前分支

执行：
```bash
git branch --show-current
```

设目标功能分支名 = `feature/$ARGUMENTS`（即 `feature/<idea-name>`）。

| 当前分支 | 行为 |
|---------|------|
| 等于目标功能分支 `feature/<idea-name>` | → Step 3 |
| `main` 或 `master` | 输出 `"已在默认分支上，无需合并。"` 并**结束** |
| 其他分支 / detached HEAD | 输出 `"当前不在功能分支 feature/<idea-name> 上，无法执行合并。请先切换到目标功能分支。"` 并**结束** |

---

## Step 3: 提交所有未提交变更

执行：
```bash
git status --porcelain
```

如果有输出（存在未提交变更）：

先向用户展示 `git status --porcelain` 结果并确认要纳入本次合并的文件范围。

确认后按文件显式暂存并提交（不要使用 `git add -A`）：
```bash
git add <file1> <file2> ...
git commit -m "wip: uncommitted changes before merge"
```

如果没有输出（工作区干净）→ 跳过，直接进入 Step 4。

> 注意：此中间提交会在 squash merge 后消失，不会出现在默认分支的提交历史中。

---

## Step 4: 检测默认分支

执行：
```bash
git branch --list main
```

- 如果输出非空 → 默认分支 = `main`
- 如果输出为空 → 检查 `git branch --list master`
  - 如果输出非空 → 默认分支 = `master`
  - 如果输出为空 → 输出 `"未找到 main 或 master 分支，无法执行合并。"` 并**结束**

---

## Step 5: 生成 squash 提交消息

### 5.1 收集信息

读取 `.thoughtworks/$ARGUMENTS/requirement.md`（如果存在），提取需求摘要。

执行：
```bash
git diff --stat <默认分支>...HEAD
```

获取变更文件统计。

### 5.2 合成提交消息

合成格式：
```
feat(<idea-name>): <一句话需求摘要>

<变更统计摘要：新增/修改了哪些模块>
```

### 5.3 用户确认

使用 AskUserQuestion 展示合成的提交消息，让用户确认或修改：

> 即将将功能分支 `feature/<idea-name>` squash merge 到 `<默认分支>`，提交消息如下：
>
> ```
> <合成的提交消息>
> ```
>
> 选项：
> - 确认合并
> - 修改提交消息（请在"其他"中输入新消息）
> - 取消合并

用户选择取消 → 输出 `"用户取消了分支合并。"` 并**结束**。

用户选择修改 → 使用用户提供的新消息作为提交消息。

---

## Step 6: 执行 squash merge

### 6.1 切回默认分支

```bash
git checkout <默认分支>
```

### 6.2 执行 squash merge

```bash
git merge --squash feature/<idea-name>
```

如果命令返回非零（存在冲突）：

输出 `"合并存在冲突，请手动解决冲突后提交。已切回 <默认分支> 分支，feature/<idea-name> 的变更已暂存但未提交。"` 并**结束**。

### 6.3 提交

```bash
git commit -m "<确认后的提交消息>"
```

输出 `"已将 feature/<idea-name> squash merge 到 <默认分支>。"`

---

## Step 7: 清理

删除本地功能分支（优先安全删除）：
```bash
git branch -d feature/<idea-name>
```

如果 `-d` 删除失败（例如仍有未合并提交），先向用户说明原因并询问是否改用强制删除：
```bash
git branch -D feature/<idea-name>
```

输出 `"已删除本地分支 feature/<idea-name>。"`

> 注意：不自动推送远程，不自动删除远程分支。用户可自行执行 `git push` 和 `git push origin --delete feature/<idea-name>`。

**结束。**
