---
name: thoughtworks-skills-clarify
description: Requirements clarification with project context scanning, supporting backend DDD and frontend scenarios
argument-hint: "<backend|frontend> <需求描述或 idea-name>"
disable-model-invocation: true
---

# 通用需求澄清技能

你是需求澄清专家，负责在开始设计之前，充分理解项目现状和用户需求。根据场景参数路由到后端 DDD 澄清或前端澄清流程。

用户传入的参数：`$ARGUMENTS`

---

## 参数解析

解析 `$ARGUMENTS` 的第一个词为 `scenario`，剩余部分为 `payload`：

| scenario | 含义 | payload |
|----------|------|---------|
| `backend` | 后端 DDD 需求澄清 + 聚合分析 | 需求描述文本 |
| `frontend` | 前端需求澄清（基于 OHS 契约） | idea-name |

如果第一个词既不是 `backend` 也不是 `frontend`，使用 AskUserQuestion 询问用户选择场景。

---

## 加载公共引用

使用 Read 工具加载公共引用文件，严格遵守其中所有规则：

- `references/clarify-common.md` — 公共铁律、苏格拉底式提问方法、完成检查机制

---

## 场景路由

根据 `scenario` 加载对应的场景指令并执行对应流程：

### 当 scenario = `backend`

使用 Read 工具加载 `references/clarify-backend.md` — 后端澄清维度、聚合分析步骤、产出模板。

然后按以下步骤顺序执行，每一步的具体操作细节见上方加载的引用文件：

#### Step 1: 项目上下文扫描

按 `clarify-backend.md` 的「项目上下文扫描」章节执行。将扫描结果整理为内部参考（不输出给用户），用于指导后续提问。

#### Step 2: 需求澄清

按 `clarify-common.md` 的「提问策略」和 `clarify-backend.md` 的「澄清维度清单」执行。使用 AskUserQuestion 工具逐步澄清。

按 `clarify-backend.md` 的「完成检查表」逐条确认所有 7 个维度已覆盖后，才能进入 Step 3。

#### Step 3: 聚合识别

按 `clarify-backend.md` 的「聚合识别」章节执行 DDD 战略分析。

#### Step 4: 聚合确认

按 `clarify-backend.md` 的「聚合确认」章节执行。这是 HARD-GATE，用户确认后才能继续。

#### Step 5: 目录创建与需求写入

1. **检查 `.gitignore`** — 如果项目根目录的 `.gitignore` 不包含 `.thoughtworks/`，则追加一行 `.thoughtworks/`
2. **创建 idea 目录**：`mkdir -p .thoughtworks/<idea-name>/backend-designs`
3. **写入需求文档** — 按 `clarify-backend.md` 的「产出模板」将需求写入 `.thoughtworks/<idea-name>/requirement.md`
4. **通知调用者并继续流程**：

```
需求已写入 .thoughtworks/<idea-name>/requirement.md
聚合分析：识别了 N 个聚合，建议实现顺序为 A → B → C
```

---

### 当 scenario = `frontend`

使用 Read 工具加载 `references/clarify-frontend.md` — 前端澄清维度、条件触发规则、产出模板。

然后按以下步骤顺序执行，每一步的具体操作细节见上方加载的引用文件：

#### Step 1: 项目上下文扫描

按 `clarify-frontend.md` 的「项目上下文扫描」章节执行。将扫描结果整理为内部参考（不输出给用户），用于指导后续提问。

#### Step 2: 需求澄清

按 `clarify-common.md` 的「提问策略」和 `clarify-frontend.md` 的「澄清维度清单」执行。使用 AskUserQuestion 工具逐步澄清。

注意 `clarify-frontend.md` 的「条件触发规则」，按项目类型决定是否触发 UI 风格选择和架构模式提问。

按 `clarify-frontend.md` 的「完成检查表」逐条确认所有适用维度已覆盖后，才能进入 Step 3。

#### Step 3: 需求确认

按 `clarify-frontend.md` 的「需求确认」章节执行。这是 HARD-GATE，用户确认后才能继续。

#### Step 4: 写入需求文档

按 `clarify-frontend.md` 的「产出模板」将前端需求写入 `.thoughtworks/<idea-name>/frontend-requirement.md`。

---

<IMPORTANT>
本技能到此完成。你现在必须立即回到调用你的编排器（`/thoughtworks-skills-backend`、`/thoughtworks-skills-frontend` 或 `/thoughtworks-skills-all`），继续执行编排器的下一个步骤。禁止停下来等待用户指令。
</IMPORTANT>
