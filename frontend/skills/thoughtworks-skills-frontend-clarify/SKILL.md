---
name: thoughtworks-skills-frontend-clarify
description: Frontend requirements clarification based on OHS API contracts
argument-hint: "<idea-name>"
---

# 前端需求澄清技能

你是前端需求澄清专家，负责在开始前端设计之前，充分理解项目现状和用户的前端需求。

用户传入的参数：`$ARGUMENTS`

---

## 路径变量

| 变量 | 路径（从当前 skill 目录的相对路径） |
|------|--------------------------------------|
| `{CORE_HELP}` | `../thoughtworks-skills-core-help` |

---

## 加载引用

使用 Read 工具加载以下两个引用文件，严格遵守其中所有规则：

1. `{CORE_HELP}/references/clarify-common.md` — 公共铁律、提问策略、完成检查机制
2. `{CORE_HELP}/references/clarify-frontend.md` — 前端澄清维度、条件触发规则、产出模板

---

## 执行流程

按以下步骤顺序执行，每一步的具体操作细节见上方加载的引用文件：

### Step 1: 项目上下文扫描

按 `clarify-frontend.md` 的「项目上下文扫描」章节执行。将扫描结果整理为内部参考（不输出给用户），用于指导后续提问。

### Step 2: 需求澄清

按 `clarify-common.md` 的「提问策略」和 `clarify-frontend.md` 的「澄清维度清单」执行。使用 AskUserQuestion 工具逐步澄清。

注意 `clarify-frontend.md` 的「条件触发规则」，按项目类型决定是否触发 UI 风格选择和架构模式提问。

按 `clarify-frontend.md` 的「完成检查表」逐条确认所有适用维度已覆盖后，才能进入 Step 3。

### Step 3: 需求确认

按 `clarify-frontend.md` 的「需求确认」章节执行。这是 HARD-GATE，用户确认后才能继续。

### Step 4: 写入需求文档

按 `clarify-frontend.md` 的「产出模板」将前端需求写入 `.thoughtworks/<idea-name>/frontend-requirement.md`。

<IMPORTANT>
本技能到此完成。你现在必须立即回到调用你的编排器（`/thoughtworks-skills-frontend` 或 `/thoughtworks-skills-all`），继续执行编排器的下一个步骤（前端评估 → 设计 → 编码）。禁止停下来等待用户指令。
</IMPORTANT>
