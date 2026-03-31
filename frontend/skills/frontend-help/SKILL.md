---
name: frontend-help
description: 前端框架共享资源，包含工作流定义和状态查询脚本
---

# 前端共享资源

本 skill 不直接被用户调用，而是作为前端框架的共享基础设施。

## 包含的资源

- `workflow.yaml` — 前端工作流定义（DAG 依赖关系 + 状态机转换规则）
- `orchestration.yaml` — 前端编排定义（步骤序列、门控检查、断点续传表）
- `scripts/frontend-status.mjs` — 前端设计文档状态查询脚本，优先扫描 `frontend-designs/{layer-id}/*.md`（按层分目录），回退到 `frontend-designs/*.md`，输出结构化 JSON
- `scripts/frontend-output-validate.mjs` — 前端设计文档校验脚本，支持按层分目录和旧版单文件两种模式。执行结构校验和契约匹配，按层分目录模式下 S1 额外要求 `task_id` 字段，C6 从后端 OHS 代码扫描 API 端点（非读取 ohs.md），C7 合并多 task 文件的导出契约后比对
- `scripts/frontend-workflow-status.mjs` — 前端工作流状态管理脚本，支持层级和 task 双层状态管理：
  - 层级命令：`--check-upstream`、`--check-all`、`--set`、`--get-status`
  - Task 命令：`--init-tasks`（初始化 frontend-task-workflow-state.yaml）、`--set-task <task_id> <status>`（更新 task 状态）、`--get-task-status <task_id>`、`--next-tasks`（获取下一批可执行 task）、`--sync-layer-status`（从 task 状态聚合推导层级状态）

## 被以下 skill 引用

- `/frontend` — 前端 Decision-Maker 主 skill
- `/frontend-thought` — 读取 workflow.yaml 决定 thinker 启动顺序
- `/frontend-works` — 读取 workflow.yaml 决定执行顺序，调用 frontend-status.mjs 查询状态

## 被以下 agent 引用

- `agent-frontend-thinker` — 用 Read 工具加载 workflow.yaml 了解层间依赖，加载 frontend-workflow-state.yaml 确认上游完成状态。产出写入 `frontend-designs/{layer-id}/` 目录，每个 task 文件 ≤800 行
- `agent-frontend-worker` — 用 Bash 运行 `frontend-status.mjs` 了解整体进度，完成编码后运行 `frontend-workflow-status.mjs --finish-task <task_id> coded` 标记 task 完成（原子命令，内部自动同步层级状态）
