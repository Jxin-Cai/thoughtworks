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

使用 Read 工具加载通用铁律：`core/references/iron-rules.md`

**本技能附加铁律：**

1. **只做前端** — 即使需求描述涉及后端，也只生成前端代码，不调用任何后端技能。如需前后端联动，提示用户安装全栈插件（`thoughtworks-all`）
2. **禁止跳过需求澄清** — 无论后端 OHS 契约多完整，**只要 `frontend-requirement.md` 不存在，就必须调用澄清技能**
3. **禁止自动执行编码** — 设计完成后必须等用户确认才能进入编码阶段

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

## 启动

1. 使用 Read 工具加载编排定义：`{FRONTEND_HELP}/orchestration.yaml`
2. 使用 Read 工具加载工作流定义：`{FRONTEND_HELP}/workflow.yaml`
3. 如果 `.thoughtworks/` 下已有 idea 目录：从 orchestration.yaml 的 `resume-table` 判断恢复点
4. 按 orchestration.yaml 的 `steps` 顺序执行

---

## 执行规则

- 每个 step 执行前，如果有 `gate.check`，运行 `bash core/scripts/gate-check.sh {IDEA_DIR} <gate-id>`
- `gate.on-pass: skip` → 门控通过时跳过该步骤（表示已完成）
- `gate.on-fail: execute` → 门控不通过时执行该步骤
- 每个 step 执行后，如果有 `postcondition.check`，运行门控脚本验证
- `type: skill` → 调用对应 slash 命令
- `type: script` → 用 Bash 执行
- `type: self` → 自己执行（如有 `read-first` 则先 Read 这些文件）
- `for-each` → 对列出的每个元素重复执行 action
