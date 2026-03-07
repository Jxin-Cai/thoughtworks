# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

基于契约驱动设计的 Claude Code 插件，采用 backend/ + frontend/ + 根级三层子插件架构。后端通过多智能体协同生成 DDD 四层架构的 Java 代码，前端基于 OHS 导出契约独立闭环生成前端代码。设计与实现严格分离：Thinker agent 只产设计文档，Worker agent 只按设计写代码。跨层一致性通过导出契约与依赖契约的签名匹配来保证。

## 插件加载

Claude Code 通过 `.claude-plugin/plugin.json` 发现并加载本插件。三个插件完全独立闭环——只装后端就只有后端能力，只装前端就只有前端能力，装 all 才有全栈能力。

- **根级 `thoughtworks-all`**：`skills` 字段声明 `["./skills/", "./backend/skills/", "./frontend/skills/"]`，`commands` 声明 `["./commands/", "./backend/commands/", "./frontend/commands/"]`，将所有技能和命令拉入 all 命名空间。`agents` 为空数组——agent 只通过各自子插件注册，避免产生冲突的 `thoughtworks-all:*` 注册项。
- **后端 `thoughtworks-backend`**：独立声明 `agents`（8 个后端 agent）、`skills: ["./skills/"]`、`commands: ["./commands/"]`，独立安装时自包含。
- **前端 `thoughtworks-frontend`**：独立声明 `agents`（2 个前端 agent）、`skills: ["./skills/"]`、`commands: ["./commands/"]`，独立安装时自包含。

每个插件有各自的 `hooks/session-start` 脚本，在会话启动时注入自身命名空间内的技能触发索引。技能引用不使用跨插件前缀（如 `thoughtworks-backend:`），因为技能始终在当前安装的插件命名空间内查找。

## 架构：三层子插件

```
根级（thoughtworks-all）
├── skills/using-thoughtworks/     — 入口技能（session-start 注入）
├── skills/thoughtworks-skills-all/ — 全栈编排器（直接调度子技能，不依赖 Decision-Maker）
├── commands/thoughtworks-all.md   — 全栈命令
├── hooks/session-start            — 全栈 session-start hook
│
├── backend/（thoughtworks-backend）
│   ├── agents/                                  — 后端 agent 定义（DDD 四层 thinker + worker）
│   ├── skills/using-thoughtworks-backend/       — 后端入口技能（独立安装时使用）
│   ├── skills/thoughtworks-skills-ddd/          — 后端 Decision-Maker
│   ├── skills/thoughtworks-skills-ddd-clarify/  — 后端需求澄清（项目上下文扫描 + 结构化提问）
│   ├── skills/thoughtworks-skills-ddd-thought/  — 后端设计编排
│   ├── skills/thoughtworks-skills-ddd-works/    — 后端编码编排
│   ├── skills/thoughtworks-skills-ddd-help/     — 后端共享资源（workflow.yaml + 脚本）
│   ├── skills/thoughtworks-skills-java-spec/    — Java 编码规范
│   ├── commands/                                — 后端命令
│   └── hooks/session-start                      — 后端 session-start hook
│
└── frontend/（thoughtworks-frontend）
    ├── agents/                                       — 前端 agent 定义（thinker + worker）
    ├── skills/using-thoughtworks-frontend/           — 前端入口技能（独立安装时使用）
    ├── skills/thoughtworks-skills-frontend/          — 前端 Decision-Maker
    ├── skills/thoughtworks-skills-frontend-clarify/  — 前端需求澄清（项目上下文扫描 + 结构化提问）
    ├── skills/thoughtworks-skills-frontend-thought/  — 前端设计编排
    ├── skills/thoughtworks-skills-frontend-works/    — 前端编码编排
    ├── skills/thoughtworks-skills-frontend-help/     — 前端共享资源（workflow.yaml + 脚本）
    ├── skills/thoughtworks-skills-frontend-spec/     — 前端编码规范
    ├── commands/                                     — 前端命令
    └── hooks/session-start                           — 前端 session-start hook
```

后端 Decision-Maker 调用 `/thoughtworks-backend-clarify` 执行需求澄清、`/thoughtworks-backend-thought` 执行设计、`/thoughtworks-backend-works` 执行编码。按 Phase 编排：Phase 1（domain）→ Phase 2（infr + application 并行）→ Phase 3（ohs）。

前端 Decision-Maker 调用 `/thoughtworks-frontend-clarify` 执行需求澄清、`/thoughtworks-frontend-thought` 执行设计、`/thoughtworks-frontend-works` 执行编码。前端依赖后端 OHS 层导出契约。

全栈编排器（`/thoughtworks-all`）直接调度澄清、设计、编码子技能，不通过 Decision-Maker 中转。编排思路与各 Decision-Maker 一致，但独立闭环。

## 关键设计规则

**使用自定义 agent 类型，而非 general-purpose。** 每层有专属的 agent 定义文件（如 `thoughtworks-agent-ddd-domain-thinker`），frontmatter 配置了 `skills: [thoughtworks-skills-java-spec]`。SKILL.md 中 `subagent_type` 必须使用带命名空间前缀的全限定名（如 `thoughtworks-backend:thoughtworks-agent-ddd-domain-thinker`），因为 Claude Code 注册 agent 时注册名 = `<plugin.name>:<agent文件名去掉.md>`。后端 agent 使用 `thoughtworks-backend:` 前缀，前端 agent 使用 `thoughtworks-frontend:` 前缀。动态 prompt 只需包含 MISSION、TEMPLATE、CONTEXT、OUTPUT，禁止重复内联 INSTRUCTION 或 CODING-SPEC。

**Agent 权限分级。** Thinker agent 配置 `permissionMode: default` + `disallowedTools: Edit`（禁止修改已有文件，只能用 Write 创建新设计文档）+ `maxTurns: 20`。Worker agent 配置 `permissionMode: acceptEdits`（自动接受文件编辑）+ `maxTurns: 15`。这些字段在 agent frontmatter 中声明，由 Claude Code 运行时强制执行，无需 skill prompt 重复指定。

**需求澄清独立为技能。** 后端和前端各有独立的澄清技能（`thoughtworks-skills-ddd-clarify` / `thoughtworks-skills-frontend-clarify`）。澄清技能的第一步是项目上下文扫描（Glob 目录结构、读关键文档、git log、扫描已有代码），然后基于上下文向用户提问，避免问出已有答案的问题。Decision-Maker 和全栈编排器都通过调用澄清技能完成需求澄清，不再内联澄清逻辑。

**契约驱动的跨层一致性。** 每个设计文档包含「导出契约」和「依赖契约」区块。下游层必须从上游层的导出契约逐条抄入依赖契约。后端 `ddd-output-validate.sh` 执行签名匹配校验（规则 C1–C5）。前端 `frontend-output-validate.sh` 执行前端契约校验（C6：Frontend 依赖契约 ⊆ OHS 导出契约）。

**Thinker agent 启动步骤带目标描述。** 每个 Thinker agent 的「启动后第一步」不仅列出要加载的规范文件，还说明加载目标（获取什么约束、作为什么基准），以聚焦模型行为。Infrastructure 层的 `database.md` 规范文件按需加载 — 只在需求涉及数据库变更时才读取。

**强制反思循环。** 每个 Thinker agent 完成初稿后必须执行 2–5 轮自验证：目标覆盖验证、下游可消费性/上游契约一致性验证、规范符合性验证。

## 关键文件关系

后端 `backend/skills/thoughtworks-skills-ddd-help/workflow.yaml` 是后端 DAG 的唯一数据源。每层定义：
- `thinker-ref` / `worker-ref` → agent `.md` 文件（全限定 `subagent_type` = `<plugin-name>:<文件名去掉.md>`，如 `thoughtworks-backend:thoughtworks-agent-ddd-domain-thinker`）
- `design-template` → `assets/{layer}-design.md`（注入到 prompt 的模板）
- `requires` → 上游层依赖
- `verify` → 实现后验证的 glob 模式

前端 `frontend/skills/thoughtworks-skills-frontend-help/workflow.yaml` 是前端 DAG 的数据源。

Agent 文件引用 `skills: [thoughtworks-skills-java-spec]`（后端）或 `skills: [thoughtworks-skills-frontend-spec]`（前端）。该 skill 的 SKILL.md 是一个路由器，根据层级关键词映射到 `references/` 下的规范文件。

## 脚本

后端脚本位于 `backend/skills/thoughtworks-skills-ddd-help/scripts/`，前端脚本位于 `frontend/skills/thoughtworks-skills-frontend-help/scripts/`。使用纯 bash（不依赖 jq），兼容 macOS bash 3.2。

### 后端脚本

```bash
bash backend/skills/thoughtworks-skills-ddd-help/scripts/ddd-workflow-status.sh <idea-dir> --init <idea-name> domain infr application ohs
bash backend/skills/thoughtworks-skills-ddd-help/scripts/ddd-workflow-status.sh <idea-dir> --set <layer> <status>
bash backend/skills/thoughtworks-skills-ddd-help/scripts/ddd-workflow-status.sh <idea-dir> --check-all
bash backend/skills/thoughtworks-skills-ddd-help/scripts/ddd-output-validate.sh <idea-dir>
bash backend/skills/thoughtworks-skills-ddd-help/scripts/ddd-status.sh <idea-dir>
```

### 前端脚本

```bash
bash frontend/skills/thoughtworks-skills-frontend-help/scripts/frontend-workflow-status.sh <idea-dir> --init <idea-name> frontend
bash frontend/skills/thoughtworks-skills-frontend-help/scripts/frontend-workflow-status.sh <idea-dir> --set frontend <status>
bash frontend/skills/thoughtworks-skills-frontend-help/scripts/frontend-workflow-status.sh <idea-dir> --check-all
bash frontend/skills/thoughtworks-skills-frontend-help/scripts/frontend-output-validate.sh <idea-dir>
bash frontend/skills/thoughtworks-skills-frontend-help/scripts/frontend-status.sh <idea-dir>
```

## 产出目录结构

```
.thoughtworks/<idea-name>/
├── requirement.md                # 后端需求存档
├── assessment.md                 # 后端层级评估结果
├── workflow-state.json           # 后端工作流状态
├── .approved                     # 后端设计确认标记
├── backend-designs/              # 后端各层设计文档
│   ├── domain.md
│   ├── infr.md
│   ├── application.md
│   └── ohs.md
├── frontend-requirement.md       # 前端需求
├── frontend-assessment.md        # 前端评估
├── frontend-workflow-state.json  # 前端工作流状态
├── .frontend-approved            # 前端设计确认标记
└── frontend-designs/             # 前端设计文档
    └── frontend.md
```

## 约束
项目的 README.md 同步由 pre-commit hook 检查保证，不需要手动维护。
