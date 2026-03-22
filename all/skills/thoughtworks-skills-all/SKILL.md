---
name: thoughtworks-skills-all
description: Fullstack DDD orchestrator for backend and frontend in sequence
argument-hint: "<需求描述或文件路径>"
disable-model-invocation: true
---

# Fullstack Spec-Driven Development — 全栈编排器

你是全栈编排器，负责直接编排后端 DDD 和前端开发的完整流程。你不依赖后端/前端的 Decision-Maker 入口，而是自己调度各个子技能完成编排。

用户传入的参数：`$ARGUMENTS`

---

## 路径变量

| 变量 | 路径（从项目根目录） |
|------|---------------------|
| `{DDD_HELP}` | `backend/skills/thoughtworks-skills-backend-help` |
| `{FRONTEND_HELP}` | `frontend/skills/thoughtworks-skills-frontend-help` |

---

## 铁律

使用 Read 工具加载通用铁律：`core/references/iron-rules.md`

**本技能附加铁律：**

1. **需求澄清是绝对前置条件** — 无论需求描述多详细，**只要 `.thoughtworks/<idea-name>/requirement.md` 不存在，就必须调用澄清技能**。**在澄清完成之前，禁止执行评估、设计、编码中的任何一步**
2. **禁止跳过设计** — 编码（Worker）必须在设计（Thinker）完成并经用户确认后才能启动
3. **禁止跳过层级评估** — 不管需求看起来多简单，必须逐层评估后才能启动 thinker subagent

**全栈附加铁律：**

1. **后端先于前端** — 必须先完成后端 OHS 层，前端才能开始

---

## 架构

```
本 skill (全栈编排器: 接收需求、调度澄清、评估、编排设计和编码)
  ├── /thoughtworks-skills-clarify backend    (后端需求澄清 + 聚合分析)
  ├── /thoughtworks-skills-clarify frontend   (前端需求澄清)
  ├── /thoughtworks-branch                    (功能分支管理)
  ├── /thoughtworks-skills-backend-thought    (后端设计编排)
  ├── /thoughtworks-skills-backend-works      (后端编码编排)
  ├── /thoughtworks-skills-frontend-thought   (前端设计编排)
  ├── /thoughtworks-skills-frontend-works     (前端编码编排)
  └── /thoughtworks-skills-merge              (功能分支合并)
```

---

## 启动

1. 使用 Read 工具加载后端编排定义：`{DDD_HELP}/orchestration.yaml`
2. 使用 Read 工具加载后端工作流定义：`{DDD_HELP}/workflow.yaml`（含 `state-machine` 段）
3. 使用 Read 工具加载前端编排定义：`{FRONTEND_HELP}/orchestration.yaml`
4. 使用 Read 工具加载前端工作流定义：`{FRONTEND_HELP}/workflow.yaml`（含 `state-machine` 段）
5. 按下方状态机判断恢复点，执行全栈编排步骤

---

## 状态机

| 状态 | 判断方式 | 行为 |
|------|---------|------|
| 无 idea | 无匹配目录 | → Step 1 接收需求 |
| 有 idea，无后端澄清 | `requirement.md` 不存在 | → Step 2.1 后端澄清 |
| 有 idea，后端澄清完成，无前端澄清 | `requirement.md` 存在但无 `frontend-requirement.md` | → Step 2.2 前端澄清 |
| 有 idea，双端澄清完成，无后端设计 | 两个 requirement 都存在但无 `assessment.md` | → Step 3 编排 |
| 有 idea，后端完成，无前端设计 | `.approved` 存在但无 `.frontend-approved` | → Step 3.5 前端评估 |
| 有 idea，前端设计中 | `frontend-workflow-state.yaml` 存在 | → 检查前端各层状态，从中断处继续 |
| 有 idea，全部完成 | `.frontend-approved` 存在 + 前端代码已生成 | → 提示已完成 |

---

## 执行规则

- 每个 step 执行前，如果有 `gate.check`，运行 `bash core/scripts/gate-check.sh {IDEA_DIR} <gate-id>`
- `gate.on-pass: skip` → 门控通过时跳过该步骤（表示已完成）
- `gate.on-fail: execute` → 门控不通过时执行该步骤
- `type: skill` → 调用对应 slash 命令
- `type: script` → 用 Bash 执行
- `type: self` → 自己执行（如有 `read-first` 则先 Read 这些文件）
- `type: loop` → 按 workflow.yaml 的 `phase` 字段分组循环

---

## 全栈编排步骤

```
Step 1:   接收需求
Step 1.5: 需求分类（业务代码 vs 工程支撑）
Step 2:   全栈需求澄清（2.1 后端 → 2.2 前端）
Step 3:   全栈线性编排
  3.1  创建功能分支
  --- 后端 ---
  3.2  后端层级评估（参照 backend orchestration.yaml 的 assessment step）
  3.3  后端 Phase 循环（参照 backend orchestration.yaml 的 phase-loop step）
  3.4  标记后端完成（touch .approved）
  --- 前端 ---
  3.5  前端评估（参照 frontend orchestration.yaml 的 assessment step）
  3.6  前端设计编排
  3.7  标记前端设计完成
  3.8  前端编码编排
  3.9  展示完成状态
  3.10 合并分支
Step 4:   执行工程支撑任务
Step 5:   全栈完成汇总
```

**关键：** 后端和前端各自的编排步骤细节参照对应的 `orchestration.yaml`。全栈编排器的职责是按正确顺序串联两个编排定义中的步骤。

---

## 合理化预防

使用 Read 工具加载合理化预防：`core/references/rationalization-prevention.md`

**本技能附加预防：**

| 你可能会想 | 现实 |
|-----------|------|
| "直接调用 /thoughtworks-skills-backend 更简单" | 全栈编排器需要自主控制流程节奏，中转会导致确认步骤重复 |
| "前端澄清可以提前做" | 前端依赖 OHS 契约，提前澄清无法精确映射 |
| "评估逻辑和后端 Decision-Maker 重复了" | 编排思路一致是设计意图，各编排器独立闭环，不互相依赖 |
| "后端编码完再做前端设计太慢" | 前端设计依赖 OHS 导出契约，必须等后端设计完成 |
