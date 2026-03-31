---
name: all
description: Fullstack DDD orchestrator for backend and frontend in sequence
argument-hint: "<需求描述或文件路径>"
---

# Fullstack Spec-Driven Development — 全栈编排器

你是全栈编排器，负责直接编排后端 DDD 和前端开发的完整流程。你不依赖后端/前端的 Decision-Maker 入口，而是自己调度各个子技能完成编排。

用户传入的参数：`$ARGUMENTS`

---

## 路径变量

| 变量 | 路径（相对于当前 skill） |
|------|---------------------|
| `{DDD_HELP}` | `../backend-help` |
| `{FRONTEND_HELP}` | `../frontend-help` |
| `{SCRIPTS}` | `../../scripts`（通过 symlink 指向 core 共享脚本） |

---

## 铁律

<HARD-GATE>
使用 Read 工具加载 `../../../core/references/iron-rules.md`，严格遵守其中所有条目。
</HARD-GATE>

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
  ├── /clarify backend    (后端需求澄清 + 领域建模分析)
  ├── /clarify frontend   (前端需求澄清)
  ├── /branch                    (功能分支管理)
  ├── /backend-thought    (后端设计编排)
  ├── /backend-works      (后端编码编排)
  ├── /frontend-thought   (前端设计编排)
  ├── /frontend-works     (前端编码编排)
  └── /merge              (功能分支合并)
```

---

## 启动

1. 使用 Read 工具加载后端编排定义：`{DDD_HELP}/orchestration.yaml`
2. 使用 Read 工具加载后端工作流定义：`{DDD_HELP}/workflow.yaml`（含 `state-machine` 段）
3. 使用 Read 工具加载前端编排定义：`{FRONTEND_HELP}/orchestration.yaml`
4. 使用 Read 工具加载前端工作流定义：`{FRONTEND_HELP}/workflow.yaml`（含 `state-machine` 段）
5. 确定 idea-dir：
   - 从 `$ARGUMENTS` 解析 idea-name，检查 `.thoughtworks/<idea-name>/` 是否存在
   - 如果 `$ARGUMENTS` 为空或目录不存在，idea-dir = `none`
6. **运行编排状态检查**：`node {SCRIPTS}/orchestration-status.mjs <idea-dir> all`
7. 严格按脚本输出的 `resume_step` 作为起点，进入步骤执行循环

---

## 步骤执行循环

<HARD-GATE>
编排器必须严格按以下循环执行。脚本输出是唯一权威的恢复点判定。
禁止跳过状态检查自行决定下一步，禁止凭记忆、推断或合理化跳过任何步骤。
**特别警告：上下文变长时，你可能产生"需求已经很清楚了，直接开始编码"的冲动——这是典型的跳步违规。
每次循环必须调用 `orchestration-status.mjs`，只执行它返回的 `resume_step`，不得自行决定下一步。**
</HARD-GATE>

```
LOOP:
  1. result = node {SCRIPTS}/orchestration-status.mjs <idea-dir> all
  2. IF result.resume_step == "merge" 且已完成合并 → 执行 summary 步骤，退出
  3. 根据 result.resume_step 执行对应步骤：

     | resume_step             | 执行动作 |
     |------------------------|---------|
     | receive-requirement     | 接收需求（self），创建 idea-dir |
     | backend:clarify         | /clarify backend {payload} |
     | frontend:clarify        | /clarify frontend {idea-name} |
     | branch                  | /branch {idea-name} |
     | backend:assessment      | 自行执行后端层级评估（参照 backend orchestration.yaml assessment step） |
     | backend:phase-loop      | 根据 phase_detail 执行后端设计/确认/编码 |
     | backend:mark-approved   | touch {IDEA_DIR}/.approved |
     | frontend:assessment     | 自行执行前端评估（参照 frontend orchestration.yaml assessment step） |
     | frontend:design         | /frontend-thought {idea-name} |
     | frontend:confirm-layers | 标记各层 confirmed + touch .frontend-approved |
     | frontend:code           | /frontend-works {idea-name} |
     | frontend:mark-approved  | touch {IDEA_DIR}/.frontend-approved |
     | supplementary           | 自行执行需求遗漏审查（参照 backend/frontend orchestration.yaml supplementary step） |
     | merge                   | /merge {idea-name} |

     - backend:phase-loop 的 phase_detail：
       sub_step=design → /backend-thought
       sub_step=confirm → node backend-workflow-status.mjs --set {layer} confirmed
       sub_step=code → /backend-works
     - supplementary 的执行逻辑：
       1. Read requirement.md，识别后端遗漏 → 有则生成 supplementary-tasks.md 并执行 → touch .supplementary-reviewed
       2. Read frontend-requirement.md，识别前端遗漏 → 有则追加 supplementary-tasks.md 并执行 → touch .frontend-supplementary-reviewed
  4. 步骤完成后，如有 postcondition → 运行 {SCRIPTS}/gate-check.mjs 验证（不重复调 orchestration-status.mjs）
  5. 更新 idea-dir（receive-requirement 步骤会创建目录），GOTO LOOP
```

**优化要点：** `orchestration-status.mjs` 只在循环顶部调用一次（决定下一步），步骤执行后靠 `gate-check.mjs` 验证即可，不需要重复调用 `orchestration-status.mjs` 来确认步骤是否成功。

---

## 步骤执行规则

- `type: skill` → 调用对应 slash 命令
- `type: script` → 用 Bash 执行
- `type: self` → 自己执行（如有 `read-first` 则先 Read 这些文件）
- 每个 step 执行后，如果有 `postcondition.check`，运行 `node {SCRIPTS}/gate-check.mjs {IDEA_DIR} <gate-id>` 验证

---

## 全栈编排步骤参考

> 以下表格为参考文档，实际执行由 `{SCRIPTS}/orchestration-status.mjs` 驱动。

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
  3.10 需求遗漏审查与工程支撑任务执行
  3.11 合并分支
Step 4:   全栈完成汇总
```

**关键：** 后端和前端各自的编排步骤细节参照对应的 `orchestration.yaml`。全栈编排器的职责是按正确顺序串联两个编排定义中的步骤。

---

## 合理化预防

使用 Read 工具加载 `../../../core/references/rationalization-prevention.md`，熟记其中所有条目。

**本技能附加预防：**

| 你可能会想 | 现实 |
|-----------|------|
| "直接调用 /backend 更简单" | 全栈编排器需要自主控制流程节奏，中转会导致确认步骤重复 |
| "前端澄清可以提前做" | 前端依赖 OHS 契约，提前澄清无法精确映射 |
| "评估逻辑和后端 Decision-Maker 重复了" | 编排思路一致是设计意图，各编排器独立闭环，不互相依赖 |
| "后端编码完再做前端设计太慢" | 前端设计依赖 OHS 导出契约，必须等后端设计完成 |
