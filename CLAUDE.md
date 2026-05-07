# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

基于契约驱动设计的 Claude Code 插件（单一 "tw" 插件），扁平目录结构。设计与实现严格分离：Thinker agent 产设计文档，Worker agent 按设计写代码。跨层一致性通过扫描上游已实现代码获取。

## 架构要点

- **单一插件 "tw"**：通过不同入口 skill（/all /backend /frontend /easy）区分编排路径
- **agents/**：4 个 agent（backend thinker/worker + frontend thinker/worker）
- **skills/**：19 个 skill 目录，含后端 DDD 四层 + 前端三层 + 共享（branch/clarify/merge）+ 编排入口
- **scripts/**：共享脚本库（工作流状态、编排检测、门控检查）
- Agent frontmatter 配置 `skills: [*-help, *-load]`，启动后按 `target_layer` 路由加载指令
- `workflow.yaml` 是 DAG 唯一数据源；`workflow-status.mjs` 管理状态机；`orchestration-status.mjs` 检测恢复点

## 关键文件

- `scripts/workflow-status.mjs` — 统一工作流状态管理（backend/frontend 入口脚本为薄包装）
- `scripts/workflow-lib.mjs` — 共享库
- `scripts/orchestration-status.mjs` — 编排恢复点检测
- `skills/backend-help/workflow.yaml` — 后端 DAG
- `skills/frontend-help/workflow.yaml` — 前端 DAG
- `hooks/hooks.json` — Hook 配置唯一真本（SessionStart + SubagentStop）

## 产出目录

运行时产出在 `.thoughtworks/<idea-name>/` 下，含需求文档、评估、工作流状态、按层分目录的 task 设计文件。每个 task 文件 ≤800 行，frontmatter 含 `task_id`。层级状态从 task 状态聚合推导。

## 约束

项目的 README.md 同步由 pre-commit hook 检查保证，不需要手动维护。
