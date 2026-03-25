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

| 变量 | 路径（从项目根目录） |
|------|---------------------|
| `{DDD_HELP}` | `backend/skills/backend-help` |
| `{FRONTEND_HELP}` | `frontend/skills/frontend-help` |

---

## 铁律

以下铁律适用于所有编排器和子技能。违反任何一条都可能导致流程失败。

1. **工作流数据源唯一性** — Phase 顺序、层定义（id/phase/requires/design-template）、验证模式（verify）必须从对应的 `workflow.yaml` 实际读取获得（后端从 `{DDD_HELP}/workflow.yaml`，前端从 `{FRONTEND_HELP}/workflow.yaml`）。禁止凭 SKILL.md 文本、记忆或推断确定这些信息。每次技能启动都必须重新用 Read 工具读取 workflow.yaml

2. **禁止跳过用户确认** — 每个 HARD-GATE 必须等待其前置条件满足后才能推进。编排器读取需求文件（docs/xxx.md）不等于执行了澄清技能、不等于完成了设计。**只有对应的产出文件实际存在才能推进**

3. **子技能完成后立即推进** — 每个子技能调用完成后，编排器必须立即推进到下一步，不要停下来等待用户额外指令。注意：此条仅适用于子技能已实际调用并完成的情况，不能用于跳过尚未执行的步骤

4. **确认由子技能负责** — 设计确认（AskUserQuestion）在 thought 子技能内部完成，编排器不重复确认

5. **Thinker 只产设计，Worker 只写代码** — 用户的调整请求一律路由到 Thinker，不影响 Worker

6. **门控脚本强制执行** — 每个 step 执行前后的门控检查必须通过 `gate-check.sh` 脚本执行，不得凭记忆或推断判断门控是否通过。用法：`bash {CORE}/scripts/gate-check.sh {IDEA_DIR} <gate-id>`

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
  ├── /clarify backend    (后端需求澄清 + 聚合分析)
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
6. **运行编排状态检查**：`bash core/scripts/orchestration-status.sh <idea-dir> all`
7. 严格按脚本输出的 `resume_step` 作为起点，进入步骤执行循环

---

## 步骤执行循环

<HARD-GATE>
编排器必须严格按以下循环执行。脚本输出是唯一权威的恢复点判定。
禁止跳过状态检查自行决定下一步，禁止凭记忆、推断或合理化跳过任何步骤。
</HARD-GATE>

```
LOOP:
  1. result = bash core/scripts/orchestration-status.sh <idea-dir> all
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
       sub_step=confirm → bash backend-workflow-status.sh --set {layer} confirmed
       sub_step=code → /backend-works
     - supplementary 的执行逻辑：
       1. Read requirement.md，识别后端遗漏 → 有则生成 supplementary-tasks.md 并执行 → touch .supplementary-reviewed
       2. Read frontend-requirement.md，识别前端遗漏 → 有则追加 supplementary-tasks.md 并执行 → touch .frontend-supplementary-reviewed
  4. 步骤完成后，更新 idea-dir（receive-requirement 步骤会创建目录）
  5. GOTO LOOP
```

---

## 步骤执行规则

- `type: skill` → 调用对应 slash 命令
- `type: script` → 用 Bash 执行
- `type: self` → 自己执行（如有 `read-first` 则先 Read 这些文件）
- 每个 step 执行后，如果有 `postcondition.check`，运行 `bash core/scripts/gate-check.sh {IDEA_DIR} <gate-id>` 验证

---

## 全栈编排步骤参考

> 以下表格为参考文档，实际执行由 `core/scripts/orchestration-status.sh` 驱动。

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

以下是常见的自我合理化模式。当你发现自己在想这些念头时，立刻停下来遵循铁律。

| 你可能会想 | 现实 |
|-----------|------|
| "用户已经给了需求文件，不用再澄清" | 需求文件（docs/xxx.md）只是原始输入，不等于澄清完成。澄清技能会扫描项目上下文、与用户提问、做聚合分析，这些步骤不可替代。**唯一判据：`gate-check.sh` 确认 requirement.md 存在** |
| "需求描述很详细，可以跳过澄清" | 无论需求多详细，聚合分析和用户确认是必须步骤。禁止以需求清晰为由跳过 |
| "我已经读取了需求文件，理解了需求，可以直接开始设计/编码" | 读取文件 ≠ 澄清完成。你的「理解」不能替代澄清技能的项目扫描、用户提问、聚合分析 |
| "评估结果很明显，直接开始设计" | 必须写入 assessment.md 并初始化 workflow-state.yaml |
| "设计看起来没问题，直接开始编码" | 必须等用户确认，用户可能有不同看法 |
| "修改太小了，直接改设计文件" | 修改必须走 thinker 流程，保证契约一致性 |
| "只改了一层，不需要级联" | 必须检查下游依赖，层间契约可能已经不一致 |
| "用户说继续就行" | 分辨"继续当前步骤"和"跳过确认"的区别 |
| "Phase 顺序我已经知道了，不用再读 workflow.yaml" | workflow.yaml 是唯一数据源，每次启动都必须用 Read 工具重新读取，不得凭记忆 |
| "SKILL.md 里已经写了 Phase 顺序" | SKILL.md 的文本是编排逻辑说明，不是数据源。Phase 顺序、层定义的数据源只有 workflow.yaml |

**本技能附加预防：**

| 你可能会想 | 现实 |
|-----------|------|
| "直接调用 /backend 更简单" | 全栈编排器需要自主控制流程节奏，中转会导致确认步骤重复 |
| "前端澄清可以提前做" | 前端依赖 OHS 契约，提前澄清无法精确映射 |
| "评估逻辑和后端 Decision-Maker 重复了" | 编排思路一致是设计意图，各编排器独立闭环，不互相依赖 |
| "后端编码完再做前端设计太慢" | 前端设计依赖 OHS 导出契约，必须等后端设计完成 |
