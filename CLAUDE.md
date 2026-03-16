# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

基于契约驱动设计的 Claude Code 插件，采用 backend/ + frontend/ + 根级三层子插件架构。后端通过多智能体协同生成 DDD 四层架构的 Java 代码，前端基于 OHS 导出契约独立闭环生成前端代码。设计与实现严格分离：Thinker agent 只产设计文档，Worker agent 只按设计写代码。跨层一致性通过导出契约与依赖契约的签名匹配来保证。DDD 战略分析在澄清阶段识别聚合并记录依赖关系，所有聚合在同一个 idea 目录下统一走 Phase 循环，domain 层按聚合分章节设计。

## 插件加载

Claude Code 通过 `.claude-plugin/marketplace.json` 发现 marketplace 中的三个插件，通过各自目录下的 `.claude-plugin/plugin.json` 加载插件。三个插件完全独立闭环——只装后端就只有后端能力，只装前端就只有前端能力，装 all 才有全栈能力。

- **`thoughtworks-all`（`all/` 子目录）**：`skills` 字段声明 `["./skills/", "./backend/skills/", "./frontend/skills/"]`，`commands` 声明 `["./commands/", "./backend/commands/", "./frontend/commands/"]`，通过符号链接（`all/backend -> ../backend`、`all/frontend -> ../frontend`）将所有技能和命令拉入 all 命名空间。`agents` 为空数组——agent 只通过各自子插件注册，避免产生冲突的 `thoughtworks-all:*` 注册项。
- **后端 `thoughtworks-backend`（`backend/` 子目录）**：独立声明 `agents`（8 个后端 agent）、`skills: ["./skills/"]`、`commands: ["./commands/"]`，独立安装时自包含。
- **前端 `thoughtworks-frontend`（`frontend/` 子目录）**：独立声明 `agents`（4 个前端 agent）、`skills: ["./skills/"]`、`commands: ["./commands/"]`，独立安装时自包含。

每个插件有各自的 `hooks/session-start` 脚本，在会话启动时注入自身命名空间内的技能触发索引。技能引用不使用跨插件前缀（如 `thoughtworks-backend:`），因为技能始终在当前安装的插件命名空间内查找。

## 架构：三层子插件

```
根级仓库
├── .claude-plugin/marketplace.json  — marketplace 定义（注册三个插件）
├── CLAUDE.md
│
├── all/（thoughtworks-all）
│   ├── .claude-plugin/plugin.json   — 全栈插件定义
│   ├── backend -> ../backend        — 符号链接
│   ├── frontend -> ../frontend      — 符号链接
│   ├── skills/using-thoughtworks/     — 入口技能（session-start 注入）
│   ├── skills/thoughtworks-skills-all/ — 全栈编排器（直接调度子技能，不依赖 Decision-Maker）
│   ├── skills/thoughtworks-skills-branch/ — 功能分支管理（三层共享，澄清后评估前自动创建 feature/<idea-name>）
│   ├── skills/thoughtworks-skills-merge/ — 功能分支合并（三层共享，上下文完成后 squash merge 回 main/master）
│   ├── commands/thoughtworks-skills-all.md   — 全栈命令
│   └── hooks/session-start            — 全栈 session-start hook
│
├── backend/（thoughtworks-backend）
│   ├── agents/                                  — 后端 agent 定义（DDD 四层 thinker + worker）
│   ├── skills/using-thoughtworks-backend/       — 后端入口技能（独立安装时使用）
│   ├── skills/thoughtworks-skills-backend/          — 后端 Decision-Maker
│   ├── skills/thoughtworks-skills-backend-clarify/  — 后端需求澄清（项目上下文扫描 + 结构化提问）
│   ├── skills/thoughtworks-skills-backend-thought/  — 后端设计编排
│   ├── skills/thoughtworks-skills-backend-works/    — 后端编码编排
│   ├── skills/thoughtworks-skills-backend-help/     — 后端共享资源（workflow.yaml + 脚本）
│   ├── skills/thoughtworks-skills-branch/           — 功能分支管理（后端独立安装时使用）
│   ├── skills/thoughtworks-skills-merge/            — 功能分支合并（后端独立安装时使用）
│   ├── skills/thoughtworks-skills-java-spec/    — Java 编码规范
│   ├── commands/                                — 后端命令
│   └── hooks/session-start                      — 后端 session-start hook
│
└── frontend/（thoughtworks-frontend）
    ├── agents/                                       — 前端 agent 定义（3 thinker + 1 worker）
    ├── skills/using-thoughtworks-frontend/           — 前端入口技能（独立安装时使用）
    ├── skills/thoughtworks-skills-frontend/          — 前端 Decision-Maker
    ├── skills/thoughtworks-skills-frontend-clarify/  — 前端需求澄清（项目上下文扫描 + 结构化提问）
    ├── skills/thoughtworks-skills-frontend-thought/  — 前端设计编排
    ├── skills/thoughtworks-skills-frontend-works/    — 前端编码编排
    ├── skills/thoughtworks-skills-frontend-help/     — 前端共享资源（workflow.yaml + 脚本）
    ├── skills/thoughtworks-skills-branch/            — 功能分支管理（前端独立安装时使用）
    ├── skills/thoughtworks-skills-merge/             — 功能分支合并（前端独立安装时使用）
    ├── skills/thoughtworks-skills-frontend-spec/     — 前端编码规范
    ├── commands/                                     — 前端命令
    └── hooks/session-start                           — 前端 session-start hook
```

后端 Decision-Maker 调用 `/thoughtworks-skills-backend-clarify` 执行需求澄清、`/thoughtworks-branch` 管理功能分支、`/thoughtworks-skills-backend-thought` 执行设计、`/thoughtworks-skills-backend-works` 执行编码、`/thoughtworks-skills-merge` 在上下文完成后 squash merge 回默认分支。按 Phase 串行编排：每个 Phase 内 Thinker→用户确认→Worker 串行执行，Phase 1（domain）→ Phase 2（infr + application 并行）→ Phase 3（ohs）。下游层的 Thinker 通过扫描已实现的上游代码获取依赖接口列表。

前端 Decision-Maker 调用 `/thoughtworks-skills-frontend-clarify` 执行需求澄清、`/thoughtworks-branch` 管理功能分支、`/thoughtworks-skills-frontend-thought` 执行设计（按 Phase 串行启动 3 个 Thinker：architecture → components → checklist）、`/thoughtworks-skills-frontend-works` 执行编码、`/thoughtworks-skills-merge` 在完成后 squash merge 回默认分支。前端依赖后端 OHS 层导出契约。

全栈编排器（`/thoughtworks-skills-all`）直接调度澄清、分支管理、设计、编码、分支合并子技能，不通过 Decision-Maker 中转。编排思路与各 Decision-Maker 一致，但独立闭环。

## 关键设计规则

**使用自定义 agent 类型，而非 general-purpose。** 每层有专属的 agent 定义文件（如 `thoughtworks-agent-ddd-domain-thinker`），frontmatter 配置了 `skills: [thoughtworks-skills-java-spec]`。SKILL.md 中 `subagent_type` 必须使用带命名空间前缀的全限定名（如 `thoughtworks-backend:thoughtworks-agent-ddd-domain-thinker`），因为 Claude Code 注册 agent 时注册名 = `<plugin.name>:<agent文件名去掉.md>`。后端 agent 使用 `thoughtworks-backend:` 前缀，前端 agent 使用 `thoughtworks-frontend:` 前缀。动态 prompt 只需包含 MISSION、TEMPLATE、CONTEXT、OUTPUT，禁止重复内联 INSTRUCTION 或 CODING-SPEC。

**Agent 权限分级。** Thinker agent 配置 `permissionMode: default` + `tools: Read, Write, Edit, Glob, Grep` + `maxTurns: 20`。Edit 工具仅用于分段追加自己的设计文档，角色约束中明确禁止修改已有文件。设计文档必须分段写入：先用 Write 写入 frontmatter + 前半部分章节，再用 Edit 追加剩余章节，每段不超过 300 行，防止单次写入失败。Worker agent 配置 `permissionMode: acceptEdits`（自动接受文件编辑）+ `maxTurns: 15`。这些字段在 agent frontmatter 中声明，由 Claude Code 运行时强制执行，无需 skill prompt 重复指定。

**需求澄清独立为技能。** 后端和前端各有独立的澄清技能（`thoughtworks-skills-backend-clarify` / `thoughtworks-skills-frontend-clarify`）。澄清技能的第一步是项目上下文扫描（Glob 目录结构、读关键文档、git log、扫描已有代码），然后基于上下文向用户提问，避免问出已有答案的问题。Decision-Maker 和全栈编排器都通过调用澄清技能完成需求澄清，不再内联澄清逻辑。

**契约驱动的跨层一致性。** 每个设计文档包含「导出契约」和「依赖契约」区块。下游层必须从上游层的导出契约逐条抄入依赖契约。后端 `backend-output-validate.sh` 执行签名匹配校验（规则 C1–C5）。前端 `frontend-output-validate.sh` 执行前端契约校验（C6：Frontend 依赖契约 ⊆ OHS 导出契约，C7：Components 依赖契约 ⊆ Architecture 导出契约）。

**Thinker agent 启动步骤带目标描述。** 每个 Thinker agent 的「启动后第一步」不仅列出要加载的规范文件，还说明加载目标（获取什么约束、作为什么基准），以聚焦模型行为。Infrastructure 层的 `database.md` 规范文件按需加载 — 只在需求涉及数据库变更时才读取。

**强制反思循环。** 每个 Thinker agent 完成初稿后必须执行自验证：后端 Thinker 执行 2–5 轮（目标覆盖验证、下游可消费性/上游契约一致性验证、规范符合性验证），前端 Thinker 各执行 1–2 轮（验证步骤分散到 3 个 thinker）。

**功能分支管理。** 三个编排器在需求澄清完成后、层级评估之前调用 `/thoughtworks-branch <idea-name>` 技能，自动检查并创建 `feature/<idea-name>` 分支。该技能以纯 bash 指令内联（非外部脚本），三层各放一份相同的 SKILL.md。非 git 仓库或已在目标分支时静默跳过；在 main/master 上自动创建；在其他分支时询问用户选择。

**功能分支合并。** 三个编排器在上下文开发完成后调用 `/thoughtworks-skills-merge <idea-name>` 技能，将 `feature/<idea-name>` 通过 squash merge 合并回默认分支（main/master），在默认分支上只留一条提交消息，然后删除本地功能分支。该技能与 `thoughtworks-skills-branch` 对称，同样以纯 bash 指令内联，三层各放一份相同的 SKILL.md。合并前自动提交未提交变更（中间提交，squash 后消失）；合并消息基于 requirement.md 和 diff stat 合成，经用户确认后执行；遇冲突中断通知用户；不自动推送远程。

**聚合分析在澄清技能中执行。** 后端澄清技能（`thoughtworks-skills-backend-clarify`）在需求澄清后执行 DDD 战略分析，识别聚合边界和依赖关系，产出写入 requirement.md 的聚合分析章节（聚合列表、依赖关系、建议实现顺序）。所有聚合在同一个 idea 目录下统一走 Phase 循环，domain 层设计按聚合分章节（`## 聚合: {Name}`），infr/app/ohs 依赖契约按聚合分组。

**UI/UX 实现增强。** 前端 Worker agent 的 `skills` 配置中包含 `ui-ux-pro-max`。若该技能已安装，Worker 启动后完全按照 `ui-ux-pro-max` 技能自身的工作流生成设计系统并遵循其最佳实践，Worker agent 不硬编码任何技能内部细节（脚本路径、参数等）。若该技能未安装，skill 注入静默跳过，Worker 按原有逻辑编码。编排层（`thoughtworks-skills-frontend-works`）仅负责从 `frontend-requirement.md` 提取 UI/UX 需求上下文并通过 prompt 传递给 Worker。

## 关键文件关系

后端 `backend/skills/thoughtworks-skills-backend-help/workflow.yaml` 是后端 DAG 的唯一数据源。每层定义：
- `thinker-ref` / `worker-ref` → agent `.md` 文件（全限定 `subagent_type` = `<plugin-name>:<文件名去掉.md>`，如 `thoughtworks-backend:thoughtworks-agent-ddd-domain-thinker`）
- `design-template` → `assets/{layer}-design.md`（注入到 prompt 的模板）
- `requires` → 上游层依赖
- `verify` → 实现后验证的 glob 模式

前端 `frontend/skills/thoughtworks-skills-frontend-help/workflow.yaml` 是前端 DAG 的数据源。

Agent 文件引用 `skills: [thoughtworks-skills-java-spec]`（后端）或 `skills: [thoughtworks-skills-frontend-spec]`（前端）。该 skill 的 SKILL.md 是一个路由器，根据层级关键词映射到 `references/` 下的规范文件。

## 脚本

后端脚本位于 `backend/skills/thoughtworks-skills-backend-help/scripts/`，前端脚本位于 `frontend/skills/thoughtworks-skills-frontend-help/scripts/`。使用纯 bash（不依赖 jq），兼容 macOS bash 3.2。

### 后端脚本

```bash
bash backend/skills/thoughtworks-skills-backend-help/scripts/backend-workflow-status.sh <idea-dir> --init <idea-name> domain infr application ohs
bash backend/skills/thoughtworks-skills-backend-help/scripts/backend-workflow-status.sh <idea-dir> --set <layer> <status>
bash backend/skills/thoughtworks-skills-backend-help/scripts/backend-workflow-status.sh <idea-dir> --check-all
bash backend/skills/thoughtworks-skills-backend-help/scripts/backend-output-validate.sh <idea-dir>
bash backend/skills/thoughtworks-skills-backend-help/scripts/backend-status.sh <idea-dir>
```

### 前端脚本

```bash
bash frontend/skills/thoughtworks-skills-frontend-help/scripts/frontend-workflow-status.sh <idea-dir> --init <idea-name> frontend-architecture frontend-components frontend-checklist
bash frontend/skills/thoughtworks-skills-frontend-help/scripts/frontend-workflow-status.sh <idea-dir> --set <layer> <status>
bash frontend/skills/thoughtworks-skills-frontend-help/scripts/frontend-workflow-status.sh <idea-dir> --check-all
bash frontend/skills/thoughtworks-skills-frontend-help/scripts/frontend-output-validate.sh <idea-dir>
bash frontend/skills/thoughtworks-skills-frontend-help/scripts/frontend-status.sh <idea-dir>
```

## 产出目录结构

```
.thoughtworks/<idea-name>/
├── requirement.md                # 需求存档（含聚合分析章节）
├── assessment.md                 # 后端层级评估结果
├── workflow-state.json           # 后端工作流状态
├── .approved                     # 后端设计确认标记
├── backend-designs/              # 后端各层设计文档
│   ├── domain.md                 # domain 层按聚合分章节（## 聚合: {Name}）
│   ├── infr.md
│   ├── application.md
│   └── ohs.md
├── supplementary-tasks.md        # 工程支撑任务（全栈编排器使用，如有）
├── frontend-requirement.md       # 前端需求
├── frontend-assessment.md        # 前端评估
├── frontend-workflow-state.json  # 前端工作流状态
├── .frontend-approved            # 前端设计确认标记
└── frontend-designs/             # 前端设计文档
    ├── frontend-architecture.md  # 架构 + 路由 + 依赖契约（Phase 1）
    ├── frontend-components.md    # 组件设计 + API 调用层（Phase 2）
    └── frontend-checklist.md     # 实现清单（Phase 3）
```

## 约束
项目的 README.md 同步由 pre-commit hook 检查保证，不需要手动维护。
