---
name: thoughtworks-skills-backend-clarify
description: Backend DDD requirements clarification with project context scanning and aggregate analysis
argument-hint: "<需求描述文本>"
---

# 后端需求澄清技能

你是后端需求澄清专家，负责在开始 DDD 设计之前，充分理解项目现状和用户需求，并执行聚合分析识别聚合边界和依赖关系。

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
2. `{CORE_HELP}/references/clarify-backend.md` — 后端澄清维度、聚合分析步骤、产出模板

---

## 执行流程

按以下步骤顺序执行，每一步的具体操作细节见上方加载的引用文件：

### Step 1: 项目上下文扫描

按 `clarify-backend.md` 的「项目上下文扫描」章节执行。将扫描结果整理为内部参考（不输出给用户），用于指导后续提问。

### Step 2: 需求澄清

按 `clarify-common.md` 的「提问策略」和 `clarify-backend.md` 的「澄清维度清单」执行。使用 AskUserQuestion 工具逐步澄清。

按 `clarify-backend.md` 的「完成检查表」逐条确认所有 7 个维度已覆盖后，才能进入 Step 3。

### Step 3: 聚合识别

按 `clarify-backend.md` 的「聚合识别」章节执行 DDD 战略分析。

### Step 4: 聚合确认

按 `clarify-backend.md` 的「聚合确认」章节执行。这是 HARD-GATE，用户确认后才能继续。

### Step 5: 目录创建与需求写入

1. **检查 `.gitignore`** — 如果项目根目录的 `.gitignore` 不包含 `.thoughtworks/`，则追加一行 `.thoughtworks/`
2. **创建 idea 目录**：`mkdir -p .thoughtworks/<idea-name>/backend-designs`
3. **写入需求文档** — 按 `clarify-backend.md` 的「产出模板」将需求写入 `.thoughtworks/<idea-name>/requirement.md`
4. **通知调用者并继续流程**：

```
需求已写入 .thoughtworks/<idea-name>/requirement.md
聚合分析：识别了 N 个聚合，建议实现顺序为 A → B → C
```

<IMPORTANT>
本技能到此完成。你现在必须立即回到调用你的编排器（`/thoughtworks-skills-backend` 或 `/thoughtworks-skills-all`），继续执行编排器的下一个步骤（创建功能分支 → 层级评估 → Phase 循环）。禁止停下来等待用户指令。
</IMPORTANT>
