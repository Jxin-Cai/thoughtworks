# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

基于契约驱动设计的 Claude Code 插件，采用 core/ + backend/ + frontend/ + all/ 四层子插件架构。core 承载共享能力（branch/merge 技能、引用资源文件、hook 脚本），后端通过多智能体协同生成 DDD 四层架构的 Java/Python/Go 代码，前端基于 OHS 层已有代码独立闭环生成前端代码。设计与实现严格分离：Thinker agent 只产设计文档，Worker agent 只按设计写代码。跨层一致性通过扫描上游已实现代码获取依赖契约来保证。

## 插件加载

Claude Code 通过 `.claude-plugin/marketplace.json` 发现三个可安装插件（backend/frontend/all），通过各自 `.claude-plugin/plugin.json` 加载。core 是内部共享层，不对外暴露为可安装插件，由 backend/frontend/all 通过符号链接引用。

- **`core/`（内部共享层，不在 marketplace 中暴露）**：branch/merge/clarify 技能（唯一真本）、hook 配置、shell 脚本库。`agents` 为空数组。backend/frontend/all 通过 symlink 引用 core 的技能和资源。
- **`thoughtworks-all`（`all/`）**：通过符号链接（`core/backend/frontend -> ../`）将所有技能拉入 all 命名空间。`agents` 为空数组。
- **`thoughtworks-backend`（`backend/`）**：2 个 agent（1 通用 thinker + 1 通用 worker）、DDD 四层设计/编码技能、编码规范、层级设计指令。
- **`thoughtworks-frontend`（`frontend/`）**：2 个 agent（1 通用 thinker + 1 通用 worker）、前端三层设计/编码技能、编码规范、层级设计指令。

技能仅通过用户显式 `/slash-command` 触发。技能引用不使用跨插件前缀。

## 关键设计规则

**通用 agent + 层级指令路由。** 后端 2 个通用 agent（`thoughtworks-agent-ddd-thinker` / `thoughtworks-agent-ddd-worker`），前端 2 个（`thoughtworks-agent-frontend-thinker` / `thoughtworks-agent-frontend-worker`）。每个 agent 的 frontmatter 配置了 `skills: [*-spec, *-guide]`，agent 启动后根据 CONTEXT 中的 `target_layer` 字段通过 `*-guide` skill 路由加载对应层级的设计/编码指令。SKILL.md 中 `subagent_type` 使用全限定名（如 `thoughtworks-backend:thoughtworks-agent-ddd-thinker`）。动态 prompt 只需包含 MISSION、TEMPLATE、CONTEXT、OUTPUT。

**Agent 权限分级。** Thinker: `permissionMode: default` + `tools: Read, Write, Edit, Glob, Grep` + `maxTurns: 20`。设计文档分段写入（先 Write 再 Edit，每段 ≤300 行）。Worker: `permissionMode: acceptEdits` + `maxTurns: 15`。

**契约驱动的跨层一致性。** 下游层依赖契约通过扫描上游已实现代码获取（按需引用，非全量）。`backend-output-validate.sh` 验证 C1–C5，`frontend-output-validate.sh` 验证 C6–C7。

**需求澄清为 core 通用技能。** `thoughtworks-skills-clarify` 在 core 中定义，通过首参数 `backend`/`frontend` 路由加载对应场景的澄清流程。澄清相关的引用资源（`clarify-common.md`、`clarify-backend.md`、`clarify-frontend.md`）和产出模板均归属 clarify 技能自身（`core/skills/thoughtworks-skills-clarify/references/`）。后端澄清还执行 DDD 战略分析（聚合识别）。backend/frontend 通过 symlink 引用此技能。

**功能分支管理。** `/thoughtworks-branch` 创建 `feature/<idea-name>`，`/thoughtworks-skills-merge` 完成后 squash merge 回默认分支。

**共享引用资源分层管理。** 铁律、状态机、中断处理等编排门控资源归属各自消费方的 `-help` 技能：后端铁律/状态机/中断处理/评估维度/合理化预防在 `backend/skills/thoughtworks-skills-backend-help/references/`，前端中断处理在 `frontend/skills/thoughtworks-skills-frontend-help/references/`，全栈合理化预防在 `all/skills/thoughtworks-skills-all/references/`，前端 thinker 公共指令在 `frontend/skills/thoughtworks-skills-frontend-guide/references/thinker/common.md`。编排器通过 Read 指令按路径变量引用。

## 关键文件关系

- `backend/skills/thoughtworks-skills-backend-help/workflow.yaml` — 后端 DAG 唯一数据源（层定义、phase、依赖、verify 模式）
- `frontend/skills/thoughtworks-skills-frontend-help/workflow.yaml` — 前端 DAG 数据源
- `backend/skills/thoughtworks-skills-backend-guide/` — 后端层级设计/编码指令路由器（`references/thinker/*.md` + `references/worker/*.md`）
- `frontend/skills/thoughtworks-skills-frontend-guide/` — 前端层级设计/编码指令路由器
- `backend/skills/thoughtworks-skills-backend-spec/` — 后端编码规范路由器（按语言 + 层级）
- `frontend/skills/thoughtworks-skills-frontend-spec/` — 前端编码规范路由器
- `core/scripts/workflow-lib.sh` — Shell 脚本共享库（纯 bash，兼容 macOS bash 3.2）
- `core/hooks/hooks.json` — Hook 配置唯一真本（SessionStart + SubagentStop），backend/frontend/all 通过符号链接引用

## 产出目录结构

```
.thoughtworks/<idea-name>/
├── requirement.md                # 需求存档（含聚合分析章节）
├── assessment.md                 # 后端层级评估结果
├── workflow-state.yaml           # 后端工作流状态
├── .approved                     # 后端设计确认标记
├── backend-designs/              # 后端各层设计文档（domain/infr/application/ohs.md）
├── frontend-requirement.md       # 前端需求
├── frontend-assessment.md        # 前端评估
├── frontend-workflow-state.yaml  # 前端工作流状态
├── .frontend-approved            # 前端设计确认标记
└── frontend-designs/             # 前端设计文档（architecture/components/checklist.md）
```

## 约束
项目的 README.md 同步由 pre-commit hook 检查保证，不需要手动维护。
