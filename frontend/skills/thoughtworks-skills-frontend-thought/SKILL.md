---
name: thoughtworks-skills-frontend-thought
description: Use when called by frontend Decision-Maker or directly to execute frontend design phase. Orchestrates frontend thinker subagent.
argument-hint: "<idea-name>"
agents:
  - thinkers/thoughtworks-agent-frontend-thinker
---

# Frontend Spec-Driven Development — 思考流程

用户传入的参数：`$ARGUMENTS`

本 skill 专注于前端设计编排：接收 Decision-Maker 的指令 → 派发 Frontend Thinker subagent → 校验产出。

---

## 铁律

1. **上游契约必须内联** — 构建 thinker prompt 时，OHS 层导出契约必须完整内联；OHS 设计文档全文改为提供路径让 Agent 自行 Read 加载
2. **禁止跳过用户确认** — Step 3 展示设计摘要后，必须等用户确认

---

## 产出目录

```
.thoughtworks/<idea-name>/
├── frontend-requirement.md       # 前端需求（由 Decision-Maker 写入）
├── frontend-assessment.md        # 前端评估（由 Decision-Maker 写入）
└── frontend-designs/             # 前端设计文档
    └── frontend.md
```

---

## Step 1: 确定 idea 并读取上下文

解析 `$ARGUMENTS` 确定 idea-name。

检查前置条件：
1. `.thoughtworks/<idea-name>/frontend-requirement.md` 必须存在
2. `.thoughtworks/<idea-name>/backend-designs/ohs.md` 存在，或者项目中已有 OHS 层代码（此时 Thinker 将从已有代码扫描 API 端点）

读取 frontend-assessment.md（如存在），确定前端工作范围。

---

## Step 1.5: 检测 UI/UX 设计技能

检查当前会话环境中是否有 `ui-ux-pro-max` 技能可用。

如果可用：
1. 调用 Skill 工具加载 `ui-ux-pro-max`，传入参数 `plan` 和前端需求摘要
2. 获取 UI/UX 设计建议（配色方案、组件风格、布局模式、字体推荐）
3. 将建议存储为 `UI_UX_GUIDANCE` 变量，在 Step 2 构建 thinker prompt 时注入到 CONTEXT 区：

```
## UI/UX 设计指引
{ui-ux-pro-max 的设计建议}

你的页面设计和组件设计应参考以上 UI/UX 指引：
- 组件 Props 中体现样式变体（如 variant, size, color scheme）
- 页面布局遵循建议的布局模式
- 在设计文档中标注所采用的设计风格
```

如果不可用 → 跳过此步骤，Thinker 按原有逻辑自行设计。

注意：此步骤为增强性优化，不可用时不影响核心流程。

---

## Step 2: 启动 Frontend Thinker

读取 `../thoughtworks-skills-frontend-help/workflow.yaml`，获取 frontend 层的 `thinker-ref` 和 `design-template`。

构建 subagent prompt：

```
Task(
  subagent_type: "thoughtworks-frontend:thoughtworks-agent-frontend-thinker",
  max_turns: 20,
  description: "Frontend 层思考",
  prompt: "
    # 启动后第一步

    执行以下命令标记开始设计：
    ```bash
    bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend in_progress
    ```

    ---

    # MISSION

    {根据 frontend-assessment.md 总结前端工作目标}

    ---

    # TEMPLATE

    使用 Read 工具加载设计文档模板：`{design-template 的绝对路径}`
    严格按照模板结构输出设计文档。

    ---

    # CONTEXT

    {如果 backend-designs/ohs.md 存在：}
    ## OHS 层导出契约
    {从 backend-designs/ohs.md 提取的 ## 导出契约 区原文，如无则提取 ## API 端点 区}

    ## OHS 层设计文档
    如需参考 OHS 层完整设计，使用 Read 工具加载：`{ohs.md 的绝对路径}`

    {如果 backend-designs/ohs.md 不存在：}
    ## OHS 层已有代码（无当前设计文档）

    OHS 层在本次需求中不需要新开发，已有 API 端点存在于代码库中。
    你需要根据 MISSION 中的工作目标，使用 Glob 和 Grep 工具从已有代码中按需扫描所需的 API 端点。

    ### 扫描指引
    - 建议扫描的包路径模式：`**/ohs/**/*Controller.java`
    - 关注 @RequestMapping、@GetMapping、@PostMapping 等注解提取 URL 和方法签名
    - 关注 Request/Response DTO 类的字段定义

    ### 扫描原则
    1. 需求驱动 — 只扫描前端需求涉及的 API 端点
    2. 签名提取 — 读取 Controller 方法签名和 DTO 字段
    3. 来源标注 — 依赖契约子表标题标注（来自已有代码），每行说明列附注源文件路径

    ## 前端需求
    {frontend-requirement.md 完整内容}

    ---

    # OUTPUT

    将设计文档写入：`{IDEA_DIR}/frontend-designs/frontend.md`

    完成后执行：
    ```bash
    bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend done
    ```

    ## frontmatter 要求

    - layer: frontend
    - order: 1
    - status: pending
    - depends_on: []
    - description: 一句话描述

    ## 实现清单要求

    设计文档末尾必须包含实现清单表格。
  "
)
```

Thinker 完成后，执行 `frontend-workflow-status.sh --check-all` 校验。校验失败时重启 thinker，在 prompt 开头追加：

```
---

# PREVIOUS ATTEMPT FAILURE

上次设计验证发现以下问题，请在本次输出中修正：

{逐条列出 validation.checks 中 pass: false 的 rule + detail}

---
```

**最多重试 2 次**，超过后暂停并用 AskUserQuestion 询问用户是手动修复还是跳过。

---

## Step 3: 汇总展示

向用户展示：
1. **页面列表** — 设计了哪些页面
2. **组件列表** — 设计了哪些组件
3. **API 调用映射** — 每个页面调用哪些 API
4. **产出文件列表**

<HARD-GATE>
使用 AskUserQuestion 询问用户是否确认设计。
用户确认后才能提示下一步：运行 `/thoughtworks-frontend-works <idea-name>`。
</HARD-GATE>
