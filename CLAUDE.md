# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

基于契约驱动设计的 Claude Code 插件（单一 "tw" 插件），扁平目录结构。设计与实现严格分离：Thinker agent 产设计文档，Worker agent 按设计写代码。跨层一致性通过扫描上游已实现代码获取。

## 架构要点

- **单一插件 "tw"**：通过不同入口 skill（/all /backend /frontend /easy）区分编排路径
- **agents/**：4 个 agent（backend thinker/worker + frontend thinker/worker）
- **垂直子域模式**：一个 Thinker 设计一个子域的全部 4 层（Domain→Infr→App→OHS），一个 Worker 实现完整垂直切片
- **原则驱动**：`backend-principles/` 取代按层拆分的 guide+spec，通过 7 条设计原则 + 参考实现引导模型
- **scripts/**：共享脚本库（工作流状态、编排检测、门控检查）
- Agent frontmatter 配置 `skills: [backend-help, backend-load]`，启动后按 role+language 路由加载原则和参考实现
- `workflow.yaml` 定义状态机；`workflow-status.mjs` 管理子域级状态；`orchestration-status.mjs` 检测恢复点

## 关键文件

- `skills/backend-principles/references/architecture.md` — DDD 7 条设计原则（根因引导）
- `skills/backend-principles/references/{lang}/reference-impl.md` — 完整垂直切片参考实现
- `scripts/workflow-status.mjs` — 子域级工作流状态管理
- `scripts/workflow-lib.mjs` — 共享库
- `scripts/orchestration-status.mjs` — 编排恢复点检测
- `skills/backend-help/workflow.yaml` — 后端工作流定义（状态机 + verify patterns）
- `skills/frontend-help/workflow.yaml` — 前端 DAG
- `hooks/hooks.json` — Hook 配置唯一真本（SessionStart + SubagentStop）

## 产出目录

运行时产出在 `.thoughtworks/<idea-name>/` 下：
- `requirement.md`、`assessment.md` — 需求和评估
- `workflow-state.yaml` — 子域级状态
- `backend-designs/{nnn}-{subdomain}.md` — 每个子域一个全层设计文件（≤800 行）

## 约束

项目的 README.md 同步由 pre-commit hook 检查保证，不需要手动维护。
