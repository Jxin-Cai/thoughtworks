# 暂停机制

在以下情况暂停执行，输出暂停状态并用 AskUserQuestion 提供选项：

## 触发条件
- task 执行失败（agent 报错或产出不符合预期）
- 实现清单内容不清晰，无法确定实现方式
- 实现过程中发现设计文档有问题

## 暂停输出

```
## 实现暂停

**Idea:** <idea-name>
**进度:** N/M task 完成

### 本次 session 已完成
- [x] domain-001: Order 聚合
- [x] infr-001: Order 仓储实现

### 遇到的问题
**Task:** {task_id} — {description}
<问题描述>

**选项：**
1. 修改设计文档后继续 — 回到 /backend-thought 修改设计，然后重新运行 /backend-works 从断点继续
2. 跳过此 task 继续后续
3. 手动修复后重试此 task
4. 终止执行
```

用 AskUserQuestion 让用户选择。

- 选择 1 → 将 task 状态设为 `pending`（`--set-task {task_id} pending`），提示用户修改设计后重新运行
- 选择 2 → 将 task 状态设为 `coded`（标记跳过），同步层级状态，继续下一个 task
- 选择 3 → 等待用户确认修复完成，重试当前 task
- 选择 4 → 将 task 状态设为 `failed`（`--set-task {task_id} failed`），同步层级状态，输出完成汇总后终止
