---
name: frontend-thought
description: Frontend design phase orchestrating architecture, components, and checklist thinkers
argument-hint: "<idea-name>"

agent:
  - agent-frontend-thinker
---

# Frontend Spec-Driven Development — 思考流程

用户传入的参数：`$ARGUMENTS`

本 skill 专注于前端设计编排：接收 Decision-Maker 的指令 → 按 Phase 串行派发 Thinker subagent → 校验产出。

所有层共用同一个通用 thinker agent（`agent-frontend-thinker`），其 frontmatter 配置了：
- **skills**：`[frontend-help, frontend-load]`
- **tools**：`Read, Write, Edit, Glob, Grep`
- **model**：`opus`

主 agent 统一使用 `tw-frontend:agent-frontend-thinker` 作为 `subagent_type`。agent 启动后自行通过 `/frontend-load` 加载设计指令和编码规范。层级差异通过 CONTEXT 中的 `target_layer` 字段传递。

---

## 铁律

以下铁律适用于所有编排器和子技能。违反任何一条都可能导致流程失败。

1. **工作流数据源唯一性** — Phase 顺序、层定义（id/phase/requires/design-template）、验证模式（verify）必须从对应的 `workflow.yaml` 实际读取获得（后端从 `{DDD_HELP}/workflow.yaml`，前端从 `{FRONTEND_HELP}/workflow.yaml`）。禁止凭 SKILL.md 文本、记忆或推断确定这些信息。每次技能启动都必须重新用 Read 工具读取 workflow.yaml

2. **禁止跳过用户确认** — 每个 HARD-GATE 必须等待其前置条件满足后才能推进。编排器读取需求文件（docs/xxx.md）不等于执行了澄清技能、不等于完成了设计。**只有对应的产出文件实际存在才能推进**

3. **子技能完成后立即推进** — 每个子技能调用完成后，编排器必须立即推进到下一步，不要停下来等待用户额外指令。注意：此条仅适用于子技能已实际调用并完成的情况，不能用于跳过尚未执行的步骤

4. **确认由子技能负责** — 设计确认（AskUserQuestion）在 thought 子技能内部完成，编排器不重复确认

5. **Thinker 只产设计，Worker 只写代码** — 用户的调整请求一律路由到 Thinker，不影响 Worker

6. **门控脚本强制执行** — 每个 step 执行前后的门控检查必须通过 `gate-check.sh` 脚本执行，不得凭记忆或推断判断门控是否通过。用法：`bash {CORE}/scripts/gate-check.sh {IDEA_DIR} <gate-id>`

**本技能附加铁律：**

1. **上游依赖通过扫描已有代码获取** — 构建 thinker prompt 时，OHS 层依赖接口通过指引 Thinker 扫描已有 OHS 代码获取，不从设计文档内联导出契约
2. **Phase 串行** — 按 workflow.yaml 的 phase 字段从小到大串行执行，前一个 Phase 完成后才能启动下一个 Phase

---

## 产出目录

```
.thoughtworks/<idea-name>/
├── frontend-requirement.md              # 前端需求（由 Decision-Maker 写入）
├── frontend-assessment.md               # 前端评估（由 Decision-Maker 写入）
├── frontend-workflow-state.yaml         # 层级状态（由 task 状态聚合推导）
├── frontend-task-workflow-state.yaml    # Task 级工作流状态
└── frontend-designs/
    ├── frontend-architecture/          # 架构设计 task
    │   ├── 001-entity-order.md
    │   └── 002-feature-create-order.md
    ├── frontend-components/            # 组件设计 task
    │   └── 001-order-components.md
    └── frontend-checklist/             # 实现清单 task
        └── 001-order-checklist.md
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
- `FRONTEND_HELP` = `../frontend-help/`
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

## Step 2: Phase 循环 — 按 workflow.yaml 串行启动 Thinker

<HARD-GATE>
必须用 Read 工具实际读取 `../frontend-help/workflow.yaml` 并解析完成后，才能启动任何 Phase 的 Thinker。
禁止凭 SKILL.md 文本中的 Phase 描述编排顺序。层的数量、id、phase 分组、design-template 路径、requires 依赖全部从 workflow.yaml 获取。
</HARD-GATE>

读取 `../frontend-help/workflow.yaml`，获取所有层的 `thinker-ref` 和 `design-template`。

按 workflow.yaml 中各层的 `phase` 字段从小到大串行遍历，对每个层启动 Thinker subagent。

### 通用启动前准备（每个层都执行）

```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set {layer-id} designing
cat > {IDEA_DIR}/.current-task-{layer-id}-$(date +%s).json << 'TASK_EOF'
{"role":"thinker","layer":"{layer-id}","idea_dir":"{IDEA_DIR}","stack":"frontend"}
TASK_EOF
```

### 通用 subagent prompt 骨架

使用 Read 工具加载 `references/thinker-prompt-skeleton.md`，按其模板和 CONTEXT 差异规则为每个层组装 prompt。

从 `workflow.yaml` 中读取该层的 `thinker-ref` 和 `design-template` 路径。

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

## Step 2.5: Task 工作流状态初始化

所有 Phase 的 Thinker 完成后，编排器负责扫描 `frontend-designs/` 下各层子目录中所有 task 文件的 frontmatter，构建 `--init-tasks` 命令的参数。

```bash
# 对每个 task 文件提取 frontmatter 后拼接参数，格式：task_id:layer:depends_on:description:file
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --init-tasks {idea-name} \
  "arch-001:frontend-architecture::Entity Order:frontend-architecture/001-entity-order.md" \
  "comp-001:frontend-components:arch-001:Order 组件:frontend-components/001-order-components.md" \
  "impl-001:frontend-checklist:comp-001:Order 实现:frontend-checklist/001-order-checklist.md"
```

注意：`depends_on` 多个依赖用逗号分隔，无依赖用空字符串。

---

## Step 3: 校验所有设计文件

所有 Phase 完成后，执行全量校验：

```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --check-all
```

如果校验不通过（`validation.status` 为 `fail`），执行 `--check-all --verbose` 获取完整失败详情，根据失败的规则判断需要重新执行哪个 Phase 的 Thinker。

---

## Step 4: 汇总展示

向用户展示：
1. **页面列表** — 设计了哪些页面
2. **FSD 架构概要** — Entities/Features/Widgets 列表
3. **组件列表** — 设计了哪些组件（按 Entity/Feature 分组）
4. **Task 列表** — 每个 task 的 task_id、层、描述、依赖关系
5. **产出文件列表** — 各 task 文件路径

<HARD-GATE>
使用 AskUserQuestion 询问用户是否确认设计。
用户确认后，本技能完成。你现在必须立即回到调用你的编排器，继续执行编排器的下一个步骤（标记 confirmed → 编码）。禁止停下来等待用户指令，禁止提示用户手动运行任何命令。
</HARD-GATE>
