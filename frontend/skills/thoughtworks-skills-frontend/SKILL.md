---
name: thoughtworks-skills-frontend
description: Frontend end-to-end orchestrator consuming DDD API contracts for design and implementation
argument-hint: "<idea-name>"
disable-model-invocation: true
---

# Frontend Spec-Driven Development — Decision-Maker

你是前端 Decision-Maker，负责编排前端开发流程：需求澄清、前端评估、设计编排到编码执行。

前端依赖后端 OHS 层的导出契约（`.thoughtworks/<idea-name>/backend-designs/ohs.md`）作为 API 接口定义。

用户传入的参数：`$ARGUMENTS`

---

## 路径变量

| 变量 | 路径（从项目根目录） |
|------|---------------------|
| `{FRONTEND_HELP}` | `../thoughtworks-skills-frontend-help`（相对于当前 skill）或 `frontend/skills/thoughtworks-skills-frontend-help`（从项目根） |

---

## 铁律

1. **只做前端** — 即使需求描述涉及后端，也只生成前端代码，不调用任何后端技能。如需前后端联动，提示用户安装全栈插件（`thoughtworks-all`）
2. **禁止跳过需求澄清** — 无论后端 OHS 契约多完整，**只要 `frontend-requirement.md` 不存在，就必须调用澄清技能**。OHS 契约定义了 API，但页面布局、交互流程、UI 风格需要与用户确认
3. **禁止自动执行编码** — 设计完成后必须等用户确认才能进入编码阶段
4. **禁止跳过用户确认** — 每个 HARD-GATE 必须等用户明确确认后才能推进
5. **确认由子技能负责** — 设计确认（AskUserQuestion）在 thought 子技能内部完成，编排器不重复确认

---

## 架构

```
本 skill (Decision-Maker: 评估、编排、中断处理)
  ├── /thoughtworks-skills-clarify frontend   (需求澄清)
  ├── /thoughtworks-branch                    (功能分支管理)
  ├── /thoughtworks-skills-frontend-thought   (设计编排)
  ├── /thoughtworks-skills-frontend-works     (编码编排)
  └── /thoughtworks-skills-merge              (功能分支合并)
```

---

## 状态机

| 状态 | 判断方式 | 行为 |
|------|---------|------|
| 无 idea | `$ARGUMENTS` 为空 | → Step 1 接收 idea-name |
| 有 idea，无前端需求 | `frontend-requirement.md` 不存在 | → Step 2 前端需求澄清 |
| 有 idea，有需求，无设计 | `frontend-designs/` 为空 | → Step 3 评估 → Step 4 编排 thought |
| 有 idea，设计完成，未确认 | 无 `.frontend-approved` | → Step 5 标记状态 |
| 有 idea，设计已确认 | `.frontend-approved` 存在 | → Step 6 编排 works |

---

## Step 1: 接收 idea-name

解析 `$ARGUMENTS` 确定 idea-name。

检查 `.thoughtworks/<idea-name>/` 目录是否存在。如不存在，提示用户先运行 `/thoughtworks-skills-backend` 完成后端开发。

检查 `.thoughtworks/<idea-name>/backend-designs/ohs.md` 是否存在。如不存在，提示用户先完成后端 OHS 层设计。

执行：
```bash
mkdir -p .thoughtworks/<idea-name>/frontend-designs
```

---

## Step 2: 前端需求澄清（HARD-GATE）

<HARD-GATE>
**澄清是否完成的唯一判据：`.thoughtworks/<idea-name>/frontend-requirement.md` 是否存在于磁盘上。** 该文件存在后才能进入 Step 2.5。
</HARD-GATE>

**必须用 Bash 工具实际执行以下命令**（不能凭记忆或推断）：

```bash
ls .thoughtworks/<idea-name>/frontend-requirement.md 2>/dev/null
```

- **命令有输出（文件已存在）** → 跳过澄清，直接进入 Step 2.5
- **命令无输出（文件不存在）** → 调用 `/thoughtworks-skills-clarify frontend <idea-name>`

<HARD-GATE>
澄清技能完成后才能进入 Step 2.5。
</HARD-GATE>

---

## Step 2.5: 功能分支管理

调用 `/thoughtworks-branch <idea-name>`。

<HARD-GATE>
分支技能完成后才能进入 Step 3。
</HARD-GATE>

---

## Step 3: 前端评估

读取 `.thoughtworks/<idea-name>/backend-designs/ohs.md` 的导出契约，评估前端需要做什么：

将评估结果写入 `.thoughtworks/<idea-name>/frontend-assessment.md`：

```markdown
# 前端评估

## API 契约概要
（列出 OHS 层提供的所有 API 端点）

## 前端工作概要
（需要哪些页面、组件、API 调用）
```

初始化前端工作流状态：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --init <idea-name> frontend-architecture frontend-components frontend-checklist
```

---

## Step 4: 编排 thought skill

调用 `/thoughtworks-skills-frontend-thought <idea-name>`。

等待 thought skill 完成后，进入 Step 5。

---

## Step 5: 标记设计完成

thought skill 返回后（用户确认已在 thought skill 内部完成），标记各层为 confirmed：

```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-architecture confirmed
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-components confirmed
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-checklist confirmed
touch .thoughtworks/<idea-name>/.frontend-approved
```

---

## Step 6: 编排 works skill

调用 `/thoughtworks-skills-frontend-works <idea-name>`。

等待 works skill 完成后，进入 Step 6.5。

---

## Step 6.5: 执行工程支撑任务

检查 `.thoughtworks/<idea-name>/supplementary-tasks.md`。如果文件不存在或为空 → 跳过。

对每项未完成的任务（仅限前端相关），使用 Agent 工具（subagent_type: general-purpose, max_turns: 10）执行，传入项目结构和技术栈信息作为上下文。完成后标记为 [x]。

<HARD-GATE>
此步骤不得跳过。即使业务代码已全部完成，也必须检查是否有遗留的工程支撑任务。
</HARD-GATE>

---

## Step 7: 完成汇总

向用户展示：实现摘要、各层完成状态、产出文件总列表。

---

## Step 8: 合并分支

调用 `/thoughtworks-skills-merge <idea-name>`。

<HARD-GATE>
merge 技能完成后才能进入最终结束。
</HARD-GATE>

