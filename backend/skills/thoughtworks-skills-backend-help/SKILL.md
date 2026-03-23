---
name: thoughtworks-skills-backend-help
description: 后端框架共享资源，包含工作流定义和状态查询脚本
---

# 后端共享资源

本 skill 不直接被用户调用，而是作为后端框架的共享基础设施。

## 包含的资源

- `workflow.yaml` — DDD 分层工作流定义（DAG 依赖关系 + 状态机转换规则）
- `orchestration.yaml` — 后端编排定义（步骤序列、门控检查、断点续传表）
- `scripts/backend-status.sh` — 设计文档状态查询脚本，优先扫描 `backend-designs/tasks/*.md`，回退到 `backend-designs/*.md`，输出结构化 JSON 或人类可读表格
- `scripts/backend-output-validate.sh` — 设计文档校验脚本，支持 `tasks/` 多文件和旧版单文件两种模式。执行结构校验(S1-S7)、契约匹配(C1-C5)、一致性校验(I1-I2)，tasks/ 模式下 S1 额外要求 `task_id` 字段，C1-C5 合并同层所有 task 的导出/依赖契约后比对
- `scripts/backend-workflow-status.sh` — 工作流状态管理脚本，支持层级和 task 双层状态管理：
  - 层级命令：`--check-upstream`、`--check-all`、`--set`、`--get-status`
  - Task 命令：`--init-tasks`（初始化 task-workflow-state.yaml）、`--set-task <task_id> <status>`（更新 task 状态）、`--get-task-status <task_id>`、`--check-task-deps <task_id>`（检查 task 依赖是否就绪）、`--next-tasks`（获取下一批可执行 task）、`--sync-layer-status`（从 task 状态聚合推导层级状态）

## 被以下 skill 引用

- `/thoughtworks-skills-backend` — Decision-Maker 主 skill，编排 thought 和 works 子 skill，负责需求澄清、层级评估、中断处理
- `/thoughtworks-skills-backend-thought` — 读取 workflow.yaml 决定 thinker 启动顺序（thinker agent 定义在 `../../agents/`）
- `/thoughtworks-skills-backend-works` — 读取 workflow.yaml 决定执行顺序，调用 backend-status.sh 查询状态（worker agent 定义在 `../../agents/`）

## 被以下 agent 引用

- `thoughtworks-agent-ddd-thinker` — 用 Read 工具加载 workflow.yaml 了解层间依赖，加载 workflow-state.yaml 确认上游完成状态。产出写入 `backend-designs/tasks/` 目录，每个 task 文件 ≤800 行
- `thoughtworks-agent-ddd-worker` — 用 Bash 运行 `backend-status.sh` 了解整体进度，完成编码后运行 `backend-workflow-status.sh --set-task <task_id> coded` 标记 task 完成，然后运行 `--sync-layer-status` 同步层级状态
