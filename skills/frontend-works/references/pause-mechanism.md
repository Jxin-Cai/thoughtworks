# 暂停机制

当 task 执行失败、实现清单不清晰、或发现设计文档有问题时，暂停执行。

## 暂停处理

用 AskUserQuestion 提供选项：
1. 修改设计文档后继续 → `--set-task {task_id} pending`
2. 跳过此 task → `--set-task {task_id} coded`（内部自动同步层级状态）
3. 手动修复后重试
4. 终止执行 → `--set-task {task_id} failed`（内部自动同步层级状态）
