---
name: thoughtworks-skills-frontend-help
description: 前端框架共享资源，包含工作流定义和状态查询脚本
disable-model-invocation: true
---

# 前端共享资源

本 skill 不直接被用户调用，而是作为前端框架的共享基础设施。

## 包含的资源

- `workflow.yaml` — 前端工作流定义
- `scripts/frontend-status.sh` — 前端设计文档状态查询脚本，扫描 frontend-designs/*.md 的 YAML frontmatter，输出结构化 JSON
- `scripts/frontend-output-validate.sh` — 前端设计文档校验脚本，执行结构校验和契约匹配，输出 JSON 格式结果
- `scripts/frontend-workflow-status.sh` — 前端工作流状态管理脚本，支持初始化、设置状态、非阻塞检查
- `references/interrupt-cascade.md` — 前端中断处理选项与级联影响规则

## 被以下 skill 引用

- `/thoughtworks-skills-frontend` — 前端 Decision-Maker 主 skill
- `/thoughtworks-skills-frontend-thought` — 读取 workflow.yaml 决定 thinker 启动顺序
- `/thoughtworks-skills-frontend-works` — 读取 workflow.yaml 决定执行顺序，调用 frontend-status.sh 查询状态
