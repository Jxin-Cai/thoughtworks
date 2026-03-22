---
name: thoughtworks-skills-frontend-help
description: 前端框架共享资源，包含工作流定义和状态查询脚本
---

# 前端共享资源

本 skill 不直接被用户调用，而是作为前端框架的共享基础设施。

## 包含的资源

- `workflow.yaml` — 前端工作流定义（DAG 依赖关系 + 状态机转换规则）
- `orchestration.yaml` — 前端编排定义（步骤序列、门控检查、断点续传表）
- `scripts/frontend-status.sh` — 前端设计文档状态查询脚本，扫描 frontend-designs/*.md 的 YAML frontmatter，输出结构化 JSON
- `scripts/frontend-output-validate.sh` — 前端设计文档校验脚本，执行结构校验和契约匹配，输出 JSON 格式结果
- `scripts/frontend-workflow-status.sh` — 前端工作流状态管理脚本，支持初始化、设置状态、非阻塞检查、获取层状态(--get-status)、状态转换合法性校验

## 被以下 skill 引用

- `/thoughtworks-skills-frontend` — 前端 Decision-Maker 主 skill
- `/thoughtworks-skills-frontend-thought` — 读取 workflow.yaml 决定 thinker 启动顺序
- `/thoughtworks-skills-frontend-works` — 读取 workflow.yaml 决定执行顺序，调用 frontend-status.sh 查询状态

## 被以下 agent 引用

- `thoughtworks-agent-frontend-thinker` — 用 Read 工具加载 workflow.yaml 了解层间依赖，加载 frontend-workflow-state.yaml 确认上游完成状态
- `thoughtworks-agent-frontend-worker` — 用 Bash 运行 frontend-status.sh 了解整体进度，运行 frontend-workflow-status.sh --set 自主标记 coded/failed 状态
