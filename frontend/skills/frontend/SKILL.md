---
name: frontend
description: Frontend end-to-end orchestrator consuming DDD API contracts for design and implementation
argument-hint: "<idea-name>"
---

# Frontend Spec-Driven Development — Decision-Maker

你是前端 Decision-Maker，负责编排前端开发流程：需求澄清、前端评估、设计编排到编码执行。

前端依赖后端 OHS 层的导出契约（`.thoughtworks/<idea-name>/backend-designs/ohs/*.md` 或旧格式 `ohs.md`）作为 API 接口定义。

用户传入的参数：`$ARGUMENTS`

---

## 路径变量

| 变量 | 路径（从项目根目录） |
|------|---------------------|
| `{FRONTEND_HELP}` | `../frontend-help`（相对于当前 skill）或 `frontend/skills/frontend-help`（从项目根） |

---

## 铁律

<HARD-GATE>
使用 Read 工具加载 `core/references/iron-rules.md`，严格遵守其中所有条目。
</HARD-GATE>

**本技能附加铁律：**

1. **只做前端** — 即使需求描述涉及后端，也只生成前端代码，不调用任何后端技能。如需前后端联动，提示用户安装全栈插件（`tw-all`）
2. **禁止跳过需求澄清** — 无论后端 OHS 契约多完整，**只要 `frontend-requirement.md` 不存在，就必须调用澄清技能**
3. **禁止自动执行编码** — 设计完成后必须等用户确认才能进入编码阶段

---

## 架构

```
本 skill (Decision-Maker: 评估、编排、中断处理)
  ├── /clarify frontend   (需求澄清)
  ├── /branch                    (功能分支管理)
  ├── /frontend-thought   (设计编排)
  ├── /frontend-works     (编码编排)
  └── /merge              (功能分支合并)
```

---

## 启动

1. 使用 Read 工具加载编排定义：`{FRONTEND_HELP}/orchestration.yaml`
2. 使用 Read 工具加载工作流定义：`{FRONTEND_HELP}/workflow.yaml`
3. 确定 idea-dir：
   - 从 `$ARGUMENTS` 解析 idea-name，检查 `.thoughtworks/<idea-name>/` 是否存在
   - 如果不存在，idea-dir = `none`
4. **运行编排状态检查**：`node core/scripts/orchestration-status.mjs <idea-dir> frontend`
5. 严格按脚本输出的 `resume_step` 作为起点，进入步骤执行循环

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
  1. result = node core/scripts/orchestration-status.mjs <idea-dir> frontend
  2. IF result.resume_step == "merge" 且已完成合并 → 执行 summary 步骤，退出
  3. 执行 orchestration.yaml 中 id == result.resume_step 的步骤：
     - 如果 resume_step 携带 phase_detail：
       sub_step=design → 调用 /frontend-thought
       sub_step=confirm → 标记各层 confirmed + touch .frontend-approved
       sub_step=code → 调用 /frontend-works
     - 如果 resume_step == "supplementary"：
       自行执行需求遗漏审查（参照 orchestration.yaml supplementary step 的 instructions）
  4. 步骤完成后，如有 postcondition → 运行 gate-check.mjs 验证（不重复调 orchestration-status.mjs）
  5. 更新 idea-dir（receive-idea 步骤会创建目录），GOTO LOOP
```

**优化要点：** `orchestration-status.mjs` 只在循环顶部调用一次（决定下一步），步骤执行后靠 `gate-check.mjs` 验证即可，不需要重复调用 `orchestration-status.mjs` 来确认步骤是否成功。

---

## 步骤执行规则

- `type: skill` → 调用对应 slash 命令
- `type: script` → 用 Bash 执行
- `type: self` → 自己执行（如有 `read-first` 则先 Read 这些文件）
- `for-each` → 对列出的每个元素重复执行 action
- 每个 step 执行后，如果有 `postcondition.check`，运行 `node core/scripts/gate-check.mjs {IDEA_DIR} <gate-id>` 验证
