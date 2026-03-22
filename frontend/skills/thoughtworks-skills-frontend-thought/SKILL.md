---
name: thoughtworks-skills-frontend-thought
description: Frontend design phase orchestrating architecture, components, and checklist thinkers
argument-hint: "<idea-name>"
disable-model-invocation: true
---

# Frontend Spec-Driven Development — 思考流程

用户传入的参数：`$ARGUMENTS`

本 skill 专注于前端设计编排：接收 Decision-Maker 的指令 → 按 Phase 串行派发 Thinker subagent → 校验产出。

所有层共用同一个通用 thinker agent（`thoughtworks-agent-frontend-thinker`），其 frontmatter 配置了：
- **skills**：`[thoughtworks-skills-frontend-spec, thoughtworks-skills-frontend-guide]`，自动注入编码规范和层级设计指令
- **tools**：`Read, Write, Edit, Glob, Grep`
- **model**：`opus`

主 agent 统一使用 `thoughtworks-frontend:thoughtworks-agent-frontend-thinker` 作为 `subagent_type`。层级差异通过 CONTEXT 中的 `target_layer` 字段传递，agent 启动后通过 `frontend-guide` skill 路由加载对应层级的设计指令。

---

## 铁律

1. **上游依赖通过扫描已有代码获取** — 构建 thinker prompt 时，OHS 层依赖接口通过指引 Thinker 扫描已有 OHS 代码获取，不从设计文档内联导出契约；Phase 2/3 的上游设计文档（architecture/components）通过提供路径让 Agent 自行 Read 加载，避免链式内联导致 prompt 膨胀
2. **Phase 串行** — Phase 1 (architecture) 完成后才能启动 Phase 2 (components)，Phase 2 完成后才能启动 Phase 3 (checklist)
3. **禁止跳过用户确认** — 所有 3 个 Phase 完成后（Step 3），必须等用户确认

---

## 产出目录

```
.thoughtworks/<idea-name>/
├── frontend-requirement.md       # 前端需求（由 Decision-Maker 写入）
├── frontend-assessment.md        # 前端评估（由 Decision-Maker 写入）
└── frontend-designs/             # 前端设计文档
    ├── frontend-architecture.md  # Phase 1: 架构 + 路由 + 依赖契约
    ├── frontend-components.md    # Phase 2: 组件设计 + API 调用层
    └── frontend-checklist.md     # Phase 3: 实现清单
```

---

## Step 1: 确定 idea 并读取上下文

解析 `$ARGUMENTS` 确定 idea-name。

检查前置条件：
1. `.thoughtworks/<idea-name>/frontend-requirement.md` 必须存在
2. 项目中已有 OHS 层代码（Thinker 将从已有代码扫描 API 端点）

读取 `{IDEA_DIR}/frontend-assessment.md`（如存在），确定前端工作范围。

设置变量：
- `IDEA_DIR` = `.thoughtworks/<idea-name>`
- `FRONTEND_HELP` = `../thoughtworks-skills-frontend-help/`
- `DESIGNS_DIR` = `{IDEA_DIR}/frontend-designs`

---

## Step 1.5: 检测 UI/UX 设计技能与 UI 风格

### UI/UX 增强（可选）

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

### UI 风格模板注入

读取 `{IDEA_DIR}/frontend-requirement.md`，检查是否包含 `## UI 风格` 章节：

- **如果包含** → 提取风格标识（如 `minimalist-luxury`、`tech-futuristic`、`classic-elegant`），构建 `UI_STYLE_GUIDANCE` 变量：

```
## UI 风格规范
风格：{风格标识}
请使用 Read 工具加载 UI 风格规范文件，获取色彩系统、字体方案、设计 Token 和组件风格指引：
`{frontend-spec references/ui-styles/{风格标识}.md 的绝对路径}`

在设计文档的「## UI 风格」章节中，按模板填写设计 Token 概要和组件风格要点。
```

- **如果不包含** → 不注入 UI 风格信息

注意：UI 风格模板是内置基础风格指引，与 `ui-ux-pro-max` 互补 — 风格模板提供色彩/字体/组件视觉规范，`ui-ux-pro-max` 提供布局/交互/用户体验建议。两者可同时注入。

---

## Step 2: Phase 循环 — 启动 3 个 Thinker

读取 `../thoughtworks-skills-frontend-help/workflow.yaml`，获取 3 个层的 `thinker-ref` 和 `design-template`。

按 Phase 顺序串行执行：

### Phase 1: Architecture Thinker

**启动前准备**：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-architecture designing
cat > {IDEA_DIR}/.current-task-frontend-architecture.json << 'TASK_EOF'
{"role":"thinker","layer":"frontend-architecture","idea_dir":"{IDEA_DIR}","stack":"frontend"}
TASK_EOF
```

构建 subagent prompt：

```
Agent(
  subagent_type: "thoughtworks-frontend:thoughtworks-agent-frontend-thinker",
  max_turns: 20,
  description: "Frontend 架构设计",
  prompt: "
    # MISSION

    {根据 frontend-assessment.md 总结前端工作目标}

    ---

    # TEMPLATE

    使用 Read 工具加载设计文档模板：`{frontend-architecture-design.md 的绝对路径}`
    严格按照模板结构输出设计文档。

    ---

    # CONTEXT

    ## 目标层级
    target_layer: frontend-architecture

    ## OHS 层已有代码

    你需要根据 MISSION 中的工作目标，使用 Glob 和 Grep 工具从已有代码中按需扫描所需的 API 端点。

    ### 扫描指引
    - 根据后端语言（从 `{IDEA_DIR}/requirement.md` 的 `## 技术选型` 确认）扫描对应路径：
      - Java: `**/ohs/**/*Controller.java`（@RequestMapping/@GetMapping/@PostMapping 注解）
      - Python: `**/ohs/**/*_router.py`（FastAPI router 装饰器 @router.get/@router.post）
      - Go: `**/ohs/**/*_handler.go`（gin handler 函数和路由注册）
    - 关注 Request/Response DTO 类的字段定义

    ### 扫描原则
    1. 需求驱动 — 只扫描前端需求涉及的 API 端点
    2. 签名提取 — 读取 Controller 方法签名和 DTO 字段
    3. 来源标注 — 依赖契约子表标题标注（来自已有代码），每行说明列附注源文件路径

    {如果 UI_STYLE_GUIDANCE 存在：}
    {UI_STYLE_GUIDANCE}

    {如果 UI_UX_GUIDANCE 存在：}
    {UI_UX_GUIDANCE}

    ## 前端需求
    使用 Read 工具加载：`{IDEA_DIR}/frontend-requirement.md`

    ---

    # OUTPUT

    将设计文档写入：`{IDEA_DIR}/frontend-designs/frontend-architecture.md`

    ## frontmatter 要求

    - layer: frontend-architecture
    - order: 1
    - status: pending
    - depends_on: []
    - description: 一句话描述
  "
)
```

Architecture Thinker 完成后，继续 Phase 2。**不再提取导出契约内联，Components Thinker 通过 Read 工具按需加载。**

### Phase 2: Components Thinker

**启动前准备**：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-components designing
cat > {IDEA_DIR}/.current-task-frontend-components.json << 'TASK_EOF'
{"role":"thinker","layer":"frontend-components","idea_dir":"{IDEA_DIR}","stack":"frontend"}
TASK_EOF
```

构建 subagent prompt：

```
Agent(
  subagent_type: "thoughtworks-frontend:thoughtworks-agent-frontend-thinker",
  max_turns: 20,
  description: "Frontend 组件设计",
  prompt: "
    # MISSION

    {根据 frontend-assessment.md 总结前端工作目标}

    ---

    # TEMPLATE

    使用 Read 工具加载设计文档模板：`{frontend-components-design.md 的绝对路径}`
    严格按照模板结构输出设计文档。

    ---

    # CONTEXT

    ## 目标层级
    target_layer: frontend-components

    ## 上游架构设计（必读 — 按需提取导出契约和架构决策）
    使用 Read 工具加载：`{IDEA_DIR}/frontend-designs/frontend-architecture.md`
    重点关注 `## 导出契约` 区（页面路由、FSD 层级、共享类型定义）和架构决策，作为本层设计的上游依据。

    ## OHS 层设计文档
    如需参考 OHS 层完整设计（API 端点、DTO 字段），使用 Read 工具加载：`{ohs.md 的绝对路径}`

    ## 前端需求
    使用 Read 工具加载：`{IDEA_DIR}/frontend-requirement.md`

    ---

    # OUTPUT

    将设计文档写入：`{IDEA_DIR}/frontend-designs/frontend-components.md`

    ## frontmatter 要求

    - layer: frontend-components
    - order: 2
    - status: pending
    - depends_on: [frontend-architecture]
    - description: 一句话描述
  "
)
```

Components Thinker 完成后，继续 Phase 3。

### Phase 3: Checklist Thinker

**启动前准备**：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-checklist designing
cat > {IDEA_DIR}/.current-task-frontend-checklist.json << 'TASK_EOF'
{"role":"thinker","layer":"frontend-checklist","idea_dir":"{IDEA_DIR}","stack":"frontend"}
TASK_EOF
```

构建 subagent prompt：

```
Agent(
  subagent_type: "thoughtworks-frontend:thoughtworks-agent-frontend-thinker",
  max_turns: 20,
  description: "Frontend 实现清单",
  prompt: "
    # MISSION

    {根据 frontend-assessment.md 总结前端工作目标}

    ---

    # TEMPLATE

    使用 Read 工具加载设计文档模板：`{frontend-checklist-design.md 的绝对路径}`
    严格按照模板结构输出设计文档。

    ---

    # CONTEXT

    ## 目标层级
    target_layer: frontend-checklist

    ## 上游组件设计（必读 — 按需提取导出契约和组件列表）
    使用 Read 工具加载：`{IDEA_DIR}/frontend-designs/frontend-components.md`
    重点关注 `## 导出契约` 区（组件列表、Props 接口、API 调用映射），作为本层清单编制的依据。

    ## 前端架构设计
    如需参考架构设计（路由、FSD 层级），使用 Read 工具加载：`{IDEA_DIR}/frontend-designs/frontend-architecture.md`

    ## 前端需求
    使用 Read 工具加载：`{IDEA_DIR}/frontend-requirement.md`

    ---

    # OUTPUT

    将设计文档写入：`{IDEA_DIR}/frontend-designs/frontend-checklist.md`

    ## frontmatter 要求

    - layer: frontend-checklist
    - order: 3
    - status: pending
    - depends_on: [frontend-architecture, frontend-components]
    - description: 一句话描述

    ## 实现清单要求

    设计文档必须包含实现清单表格，列出所有需要创建的文件路径、关键实现点和对应章节。
  "
)
```

### 重试机制

每个 Phase 的 Thinker 完成后，执行 `frontend-output-validate.sh` 校验对应文件。校验失败时重启 thinker，在 prompt 开头追加：

```
---

# PREVIOUS ATTEMPT FAILURE

上次设计验证发现以下问题，请在本次输出中修正：

{逐条列出 validation.checks 中 pass: false 的 rule + detail}

---
```

**每个 Phase 最多重试 2 次**，超过后暂停并用 AskUserQuestion 询问用户是手动修复还是跳过。

---

## Step 2.5: 校验所有设计文件

所有 3 个 Phase 完成后，执行全量校验：

```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --check-all
```

如果校验不通过，根据失败的规则判断需要重新执行哪个 Phase 的 Thinker。

---

## Step 3: 汇总展示

向用户展示：
1. **页面列表** — 设计了哪些页面（来自 frontend-architecture.md）
2. **FSD 架构概要** — Entities/Features/Widgets 列表（来自 frontend-architecture.md）
3. **组件列表** — 设计了哪些组件（按 Entity/Feature 分组，来自 frontend-components.md）
4. **API 调用映射** — 每个页面调用哪些 API（来自 frontend-components.md）
5. **产出文件列表** — 3 个设计文件路径

<HARD-GATE>
使用 AskUserQuestion 询问用户是否确认设计。
用户确认后，本技能完成。你现在必须立即回到调用你的编排器，继续执行编排器的下一个步骤（标记 confirmed → 编码）。禁止停下来等待用户指令，禁止提示用户手动运行任何命令。
</HARD-GATE>
