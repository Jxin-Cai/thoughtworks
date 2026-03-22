---
name: thoughtworks-skills-backend-help
description: 后端框架共享资源，包含工作流定义和状态查询脚本
---

# 后端共享资源

本 skill 不直接被用户调用，而是作为后端框架的共享基础设施。

## 包含的资源

- `workflow.yaml` — DDD 分层工作流定义（DAG 依赖关系）
- `scripts/backend-status.sh` — 设计文档状态查询脚本，扫描 backend-designs/*.md 的 YAML frontmatter，输出结构化 JSON 或人类可读表格
- `scripts/backend-output-validate.sh` — 设计文档校验脚本，执行结构校验(S1-S7)、契约匹配(C1-C5)、一致性校验(I1-I2)，输出 JSON 格式结果
- `scripts/backend-workflow-status.sh` — 工作流状态管理脚本，支持查看状态、非阻塞检查上游层完成(--check-upstream)、全部完成(--check-all)、设置层状态(--set)、获取层状态(--get-status)
- `references/state-machine.md` — 后端状态机与断点续传决策表

## 被以下 skill 引用

- `/thoughtworks-skills-backend` — Decision-Maker 主 skill，编排 thought 和 works 子 skill，负责需求澄清、层级评估、中断处理
- `/thoughtworks-skills-backend-thought` — 读取 workflow.yaml 决定 thinker 启动顺序（thinker agent 定义在 `../../agents/`）
- `/thoughtworks-skills-backend-works` — 读取 workflow.yaml 决定执行顺序，调用 backend-status.sh 查询状态（worker agent 定义在 `../../agents/`）

## 被以下 agent 引用

- `thoughtworks-agent-ddd-thinker` — 用 Read 工具加载 workflow.yaml 了解层间依赖，加载 workflow-state.json 确认上游完成状态
- `thoughtworks-agent-ddd-worker` — 用 Bash 运行 backend-status.sh 了解整体进度，运行 backend-workflow-status.sh --set 自主标记 coded/failed 状态
