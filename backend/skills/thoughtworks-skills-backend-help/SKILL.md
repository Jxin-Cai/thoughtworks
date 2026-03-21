---
name: thoughtworks-skills-backend-help
description: 后端框架共享资源，包含工作流定义和状态查询脚本
disable-model-invocation: true
---

# 后端共享资源

本 skill 不直接被用户调用，而是作为后端框架的共享基础设施。

## 包含的资源

- `workflow.yaml` — DDD 分层工作流定义（DAG 依赖关系）
- `scripts/backend-status.sh` — 设计文档状态查询脚本，扫描 backend-designs/*.md 的 YAML frontmatter，输出结构化 JSON 或人类可读表格
- `scripts/backend-output-validate.sh` — 设计文档校验脚本，执行结构校验(S1-S7)、契约匹配(C1-C5)、一致性校验(I1-I2)，输出 JSON 格式结果
- `scripts/backend-workflow-status.sh` — 工作流状态管理脚本，支持查看状态、阻塞等待上游层完成(--wait-upstream)、等待全部完成(--wait-all)、设置层状态(--set)
- `references/assessment-dimensions.md` — 后端层级评估维度和 assessment.md 输出格式
- `references/rationalization-backend.md` — 后端合理化预防表
- `references/iron-rules.md` — 后端铁律（编排器 Read 引用）
- `references/state-machine.md` — 后端状态机与断点续传决策表
- `references/interrupt-cascade.md` — 后端中断处理选项与级联影响规则

## 被以下 skill 引用

- `/thoughtworks-skills-backend` — Decision-Maker 主 skill，编排 thought 和 works 子 skill，负责需求澄清、层级评估、中断处理
- `/thoughtworks-skills-backend-thought` — 读取 workflow.yaml 决定 thinker 启动顺序（thinker agent 定义在 `../../agents/`）
- `/thoughtworks-skills-backend-works` — 读取 workflow.yaml 决定执行顺序，调用 backend-status.sh 查询状态（worker agent 定义在 `../../agents/`）
