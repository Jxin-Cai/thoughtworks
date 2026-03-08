---
name: thoughtworks-skills-backend-clarify
description: Use when backend DDD requirements need clarification. Scans project context first, then clarifies requirements with user through structured questions, and performs domain decomposition into bounded contexts.
argument-hint: "<需求描述文本>"
---

# 后端需求澄清技能

你是后端需求澄清专家，负责在开始 DDD 设计之前，充分理解项目现状和用户需求，并执行领域拆分将需求分解为独立的迭代单元。

用户传入的参数：`$ARGUMENTS`

---

## 铁律

1. **禁止跳过项目上下文扫描** — 必须先了解项目现状，再向用户提问
2. **控制提问节奏** — 使用 AskUserQuestion 工具，相关维度可合并提问（最多 2-3 个），不相关维度分开问
3. **禁止自行假设需求** — 所有不确定的点必须向用户确认
4. **禁止跳过领域拆分** — 即使需求只涉及一个聚合，也必须执行拆分分析并确认
5. **聚合上下文 = 迭代单元** — 拆分粒度为聚合上下文（可含多个聚合根），不是单个聚合根

---

## Step 1: 项目上下文扫描

在向用户提任何问题之前，先扫描项目现状，目标是了解项目的技术栈、已有代码结构和最近的开发动态，避免问出已有答案的问题：

1. **扫描项目根目录结构** — 使用 Glob 工具查看项目顶层目录和关键配置文件（`pom.xml`、`build.gradle`、`application.yml` 等），目标是确定技术栈和模块划分
2. **读取关键文档** — 使用 Read 工具读取项目的 `README.md`、`CLAUDE.md`（如存在），目标是获取项目背景、架构约定和开发规范
3. **查看最近提交** — 使用 Bash 执行 `git log --oneline -10`，目标是了解最近的开发方向和活跃模块
4. **扫描已有领域模型** — 使用 Glob 查找 `**/domain/**/*.java`、`**/entity/**/*.java`，目标是了解已有的领域概念，避免重复设计
5. **检查已有 idea** — 检查 `.thoughtworks/` 目录下是否有相关的已有需求或设计，目标是避免重复工作

将扫描结果整理为内部参考（不输出给用户），用于指导后续提问。

---

## Step 2: 需求澄清

基于项目上下文扫描的结果，使用 AskUserQuestion 工具，**相关维度合并提问（最多 2-3 个），不相关维度分开问**，逐步澄清以下维度：

1. **目标** — 这个功能要解决什么业务问题？期望的最终效果是什么？
2. **约束** — 有哪些技术约束、业务规则、性能要求、兼容性要求？
3. **成功标准** — 怎样才算做完了？有哪些验收条件？
4. **边界** — 哪些是本次范围内的，哪些明确不做？

### 提问策略

- 如果项目上下文扫描中已经能回答某个维度的问题，跳过该维度或直接向用户确认你的理解
- 如果发现项目中已有相关的领域模型或代码，在提问时提及，帮助用户更精准地描述需求
- 每次收到用户回答后，判断是否还有不明确的点。如果有，继续提问；如果已经足够清晰，进入下一步

---

## Step 3: 领域拆分

需求澄清完成后，执行 DDD 战略分析，将需求拆分为独立的聚合上下文（迭代单元）。

### 3.1 DDD 战略分析

基于已澄清的需求和项目上下文，执行以下分析：

1. **识别聚合上下文** — 分析需求涉及的业务概念，按以下维度划分聚合上下文：
   - **事务边界**：哪些操作必须在同一事务中完成？
   - **业务独立性**：哪些业务概念可以独立变化、独立部署？
   - **变更频率**：哪些概念经常一起变更？
   - **数据一致性**：哪些数据之间需要强一致性？

2. **参考已有代码** — 检查 Step 1 扫描到的已有领域模型：
   - 如果新需求属于已有上下文的扩展，复用已有名称
   - 如果新需求与已有上下文有交叉，明确边界

3. **分析上下文间依赖关系** — 构建有向无环图（DAG）：
   - 识别哪些上下文依赖其他上下文的数据或能力
   - **禁止循环依赖** — 如果发现循环依赖，重新调整上下文边界
   - 标记依赖方向（如 order 依赖 product，product 不依赖 order）

4. **为每个上下文命名** — 使用 kebab-case，作为 idea-name（如 `product-management`、`order-processing`）

### 3.2 特殊情况处理

| 情况 | 处理方式 |
|------|---------|
| 单上下文 | 仍执行分析，产出单项方案，idea-name 即为该上下文名称 |
| 扩展已有上下文 | 复用已有 `.thoughtworks/<name>/` 目录名称 |
| 边界模糊 | 向用户提问确认（"A 和 B 是否应该在同一个上下文中？"） |
| 跨上下文的聚合根 | 拆分到主要职责所在的上下文，另一个上下文通过依赖契约引用 |

### 3.3 展示拆分方案

向用户展示拆分结果：

1. **上下文列表**（Markdown 表格）：

| # | 上下文 (idea-name) | 核心概念 | 聚合根 | 依赖上游 |
|---|-------------------|---------|-------|---------|
| 1 | product-management | 商品、分类、品牌 | Product | 无 |
| 2 | inventory-management | 库存、仓库 | Inventory | product-management |
| 3 | order-processing | 订单、订单项 | Order | product-management, inventory-management |

2. **DAG 依赖图**（文字描述或 ASCII）：
```
product-management → inventory-management → order-processing
                   ↘                      ↗
```

3. **执行顺序**（拓扑序）：按 DAG 拓扑排序后的执行顺序

4. **各上下文需求概要** — 每个上下文一段简短描述

使用 AskUserQuestion 确认拆分方案，提供选项：
- 确认方案
- 调整拆分（合并/拆分/重命名/调整依赖）

---

## Step 4: 拆分确认

<HARD-GATE>
用户确认拆分方案后才能继续。
支持以下调整操作：
- **合并**：将两个上下文合并为一个
- **拆分**：将一个上下文拆为多个
- **重命名**：修改上下文的 idea-name
- **调整依赖**：修改上下文间的依赖关系

用户调整后，重新展示更新的方案，再次确认。
禁止以"拆分已经很合理"为由跳过确认。
</HARD-GATE>

---

## Step 5: 多目录创建与需求写入

用户确认拆分方案后：

1. **检查 `.gitignore`** — 如果项目根目录的 `.gitignore` 不包含 `.thoughtworks/`，则追加一行 `.thoughtworks/`

2. **创建上下文目录** — 对每个上下文执行：
```bash
mkdir -p .thoughtworks/<context-idea-name>/backend-designs
```

3. **写入需求文档** — 对每个上下文，将需求写入 `.thoughtworks/<context-idea-name>/requirement.md`，包含以下结构化元数据：

```markdown
# <上下文名称> 需求文档

## 元数据

- **上下文名称**: <context-idea-name>
- **所属领域拆分**: [<所有同批上下文的 idea-name 列表，逗号分隔>]
- **上游依赖**: [<依赖的上下文 idea-name 列表，无依赖则为空>]

## 需求描述

<该上下文的详细需求描述>

## 聚合根

- <聚合根 1>: <简要说明>
- <聚合根 2>: <简要说明>

## 业务规则

- <规则 1>
- <规则 2>

## 跨上下文交互

- 依赖 <上游上下文>: <交互说明>
- 被 <下游上下文> 依赖: <交互说明>

## 成功标准

- <标准 1>
- <标准 2>
```

4. **输出上下文清单** — 向调用者输出上下文清单，供 Decision-Maker 或全栈编排器解析：

**Markdown 表格**：

| # | context-idea-name | 依赖上游 | 状态 |
|---|-------------------|---------|------|
| 1 | product-management | 无 | 待开发 |
| 2 | inventory-management | product-management | 待开发 |
| 3 | order-processing | product-management, inventory-management | 待开发 |

**JSON DAG**（用于程序解析）：

```json
{
  "contexts": [
    {"name": "product-management", "depends_on": []},
    {"name": "inventory-management", "depends_on": ["product-management"]},
    {"name": "order-processing", "depends_on": ["product-management", "inventory-management"]}
  ],
  "topological_order": ["product-management", "inventory-management", "order-processing"]
}
```

---

## 合理化预防

| 你可能会想 | 现实 |
|-----------|------|
| "项目扫描太慢，直接问用户" | 扫描能避免问出已有答案的问题，节省用户时间 |
| "需求已经很清楚，跳过澄清" | 必须至少确认一次目标和成功标准，用户可能有隐含假设 |
| "git log 没什么用" | 最近提交能揭示项目当前的开发重点和潜在冲突 |
| "已有代码不影响新需求" | 已有领域模型决定了新功能的集成方式和命名一致性 |
| "不需要拆分，放一起更方便" | 领域拆分保证了每个迭代单元的聚焦性和可管理性，即使只有一个上下文也必须经过分析确认 |
| "放一起更高效" | 大需求线性处理会导致设计膨胀、应用服务跨多个不相关聚合、迭代粒度过粗 |
| "已有上下文不用分析" | 新需求可能需要扩展已有上下文或与其交互，必须分析已有上下文的边界 |
