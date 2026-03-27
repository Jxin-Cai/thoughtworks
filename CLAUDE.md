# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

基于契约驱动设计的 Claude Code 插件，采用 core/ + backend/ + frontend/ + all/ 四层子插件架构。设计与实现严格分离：Thinker agent 产设计文档，Worker agent 按设计写代码。跨层一致性通过扫描上游已实现代码获取。

## 架构要点

- **core/**：内部共享层（branch/merge/clarify 技能、hook、脚本库），不对外暴露，通过 symlink 引用
- **backend/**：2 agent（thinker + worker）+ DDD 四层设计/编码技能 + 编码规范
- **frontend/**：2 agent（thinker + worker）+ 前端三层设计/编码技能 + 编码规范
- **all/**：通过 symlink 组合 core/backend/frontend，全栈编排
- Agent frontmatter 配置 `skills: [*-guide, *-spec]`，启动后按 `target_layer` 路由加载指令
- `workflow.yaml` 是 DAG 唯一数据源；`workflow-status.mjs` 管理状态机；`orchestration-status.mjs` 检测恢复点

## 关键文件

- `core/scripts/workflow-status.mjs` — 统一工作流状态管理（backend/frontend 入口脚本为薄包装）
- `core/scripts/workflow-lib.mjs` — 共享库
- `core/scripts/orchestration-status.mjs` — 编排恢复点检测
- `backend/skills/backend-help/workflow.yaml` — 后端 DAG
- `frontend/skills/frontend-help/workflow.yaml` — 前端 DAG
- `core/hooks/hooks.json` — Hook 配置唯一真本（SessionStart + SubagentStop）

## 产出目录

运行时产出在 `.thoughtworks/<idea-name>/` 下，含需求文档、评估、工作流状态、按层分目录的 task 设计文件。每个 task 文件 ≤800 行，frontmatter 含 `task_id`。层级状态从 task 状态聚合推导。

## 约束

项目的 README.md 同步由 pre-commit hook 检查保证，不需要手动维护。
