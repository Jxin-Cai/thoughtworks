---
name: thoughtworks-skills-core-help
description: Shared reference resources for orchestrators: iron rules, state machine, assessment dimensions
---

# Core 共享引用资源

本技能是资源路由器，提供编排器共享的引用文件。编排器通过 Read 工具直接读取 `references/` 下的文件。

## 引用文件清单

| 文件 | 用途 | 使用者 |
|------|------|--------|
| `references/assessment-dimensions.md` | 后端层级评估维度和 assessment.md 输出格式 | all 编排器、backend 编排器 |
| `references/iron-rules-backend.md` | 后端铁律（禁止跳过澄清/设计/确认等） | all 编排器、backend 编排器 |
| `references/state-machine-backend.md` | 启动检查 + 后端状态决策表 | all 编排器、backend 编排器 |
| `references/interrupt-cascade.md` | 中断处理选项表 + 后端级联影响规则 | all 编排器、backend 编排器 |
| `references/rationalization-backend.md` | 后端合理化预防表 | all 编排器、backend 编排器 |
| `references/rationalization-fullstack.md` | 全栈特有的合理化预防行 | all 编排器 |

## 引用方式

编排器在 SKILL.md 中通过相对路径引用：

- all 编排器：`Read core/skills/thoughtworks-skills-core-help/references/<file>.md`
- backend 编排器：`Read ../thoughtworks-skills-core-help/references/<file>.md`（需 core 已通过符号链接或直接安装）
