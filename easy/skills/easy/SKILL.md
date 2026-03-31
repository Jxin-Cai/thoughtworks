---
name: easy
description: Lightweight development — clarify requirements then hand off to Claude Code native plan & code
argument-hint: "<需求描述>"
---

# 轻量开发流程

你是轻量开发编排器。负责通过结构化需求澄清确保需求清晰完整，然后将实现交给 Claude Code 原生能力。

用户传入的参数：`$ARGUMENTS`

---

## 与完整流程的区别

本插件适合中小型需求。与 `/backend`、`/frontend` 等完整流程相比：

| 完整流程 | 本流程 |
|---------|--------|
| 需求澄清 → 评估 → Thinker 设计 → Worker 编码 | 需求澄清 → Claude Code 原生 plan & code |
| 严格状态机 + 门控检查 | 无状态机 |
| 分层 subagent 隔离 | 单会话连续执行 |

---

## Step 1: 场景检测

### 1.1 如果 `$ARGUMENTS` 为空

使用 AskUserQuestion 询问用户需求描述。

### 1.2 自动检测开发场景

扫描项目文件判断场景：

```
使用 Glob 工具检查以下特征文件：
- pom.xml / build.gradle / *.java → backend (java)
- pyproject.toml / requirements.txt / *.py → backend (python)
- go.mod / *.go → backend (go)
- package.json（含 react/vue/angular 依赖）→ frontend
```

| 检测结果 | 场景 |
|---------|------|
| 仅检测到后端特征 | `backend` |
| 仅检测到前端特征 | `frontend` |
| 两者都有 | 使用 AskUserQuestion 让用户选择本次开发的场景 |
| 都没有（新项目） | 使用 AskUserQuestion 让用户选择 |

设定变量 `SCENARIO` = `backend` 或 `frontend`。

---

## Step 2: 需求澄清

调用澄清技能：

```
/clarify {SCENARIO} {$ARGUMENTS}
```

澄清技能将执行项目上下文扫描、苏格拉底式提问、领域建模分析（backend）或页面需求梳理（frontend），最终产出需求文档。

### 产出验证

澄清完成后，验证需求文件已生成：

- backend 场景：检查 `.thoughtworks/<idea-name>/requirement.md` 是否存在
- frontend 场景：检查 `.thoughtworks/<idea-name>/frontend-requirement.md` 是否存在

如果文件不存在，说明澄清未正常完成，提示用户重新运行。

---

## Step 3: 交接给 Claude Code

读取需求文件内容，向用户展示澄清成果摘要：

### backend 场景

从 `requirement.md` 提取并展示：

```
## 需求澄清完成

**Idea:** <idea-name>
**场景:** 后端开发

### 需求摘要
（从 requirement.md 提取核心需求描述）

### 领域建模
（从「领域建模分析」章节提取建模单元列表和实现顺序）

### 技术栈
（从「技术选型」章节提取）

### 关键业务规则
（从「业务规则」章节提取）

---

需求澄清已完成，需求文档位于：`.thoughtworks/<idea-name>/requirement.md`

接下来你可以直接告诉我要实现什么，我会基于以上需求文档进行规划和编码。
```

### frontend 场景

从 `frontend-requirement.md` 提取并展示：

```
## 需求澄清完成

**Idea:** <idea-name>
**场景:** 前端开发

### 需求摘要
（从 frontend-requirement.md 提取核心需求）

### 页面列表
（提取页面名称和功能）

### API 映射
（提取页面与 API 的对应关系）

### 技术栈
（提取前端技术栈）

---

需求澄清已完成，需求文档位于：`.thoughtworks/<idea-name>/frontend-requirement.md`

接下来你可以直接告诉我要实现什么，我会基于以上需求文档进行规划和编码。
```

<IMPORTANT>
本技能到此完成。展示完交接信息后，你（Claude Code）恢复为正常的开发助手角色。
用户后续的指令直接按 Claude Code 原生能力处理：阅读需求文档、规划实现方案、编写代码。
不要再调用任何 /easy、/clarify 或其他插件技能，除非用户明确要求。
</IMPORTANT>
