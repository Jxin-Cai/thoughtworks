# Frontend Thinker Prompt 骨架与 CONTEXT 规则

## Prompt 模板

```
Agent(
  subagent_type: "tw-frontend:agent-frontend-thinker",
  max_turns: 20,
  description: "Frontend {layer-id} 设计",
  prompt: "
    # MISSION
    {根据 frontend-assessment.md 总结前端工作目标}

    ---

    # TEMPLATE
    使用 Read 工具加载设计文档模板：`{workflow.yaml 中该层 design-template 的绝对路径}`
    严格按照模板结构输出设计文档。

    ---

    # CONTEXT
    ## 目标层级
    target_layer: {layer-id}

    {按层级 CONTEXT 差异规则构建 — 见下方}

    ## 前端需求
    使用 Read 工具加载：`{IDEA_DIR}/frontend-requirement.md`

    ---

    # OUTPUT
    将设计文档写入：`{IDEA_DIR}/frontend-designs/{layer-id}/` 目录
    每个 task 一个文件，命名格式：`{nnn}-{topic-slug}.md`

    ## Task 拆分规则
    - frontend-architecture 层：按 Entity/Feature 拆 task，小需求可合为一个 task
    - frontend-components 层：按组件组拆 task
    - frontend-checklist 层：按 FSD slice 拆 task，小需求可合为一个 task
    - 单个 task 文件不超过 800 行
    - 每个 task 的 frontmatter 必须包含 task_id、layer、order、status、depends_on、description

    ## frontmatter 要求
    - layer: {layer-id}
    - order: {workflow.yaml 中的 phase 值}
    - status: pending
    - depends_on: {具体的上游 task_id 列表}
    - description: 一句话描述

    {如果该层是 workflow.yaml 中最后一个 Phase 的层，追加：}
    ## 实现清单要求
    设计文档必须包含实现清单表格，列出所有需要创建的文件路径、关键实现点和对应章节。
  "
)
```

## 层级 CONTEXT 差异规则

### 无上游依赖（requires 为空，即第一个 Phase）

```
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

{如果 UI_STYLE_GUIDANCE 存在则注入}
{如果 UI_UX_GUIDANCE 存在则注入}
```

### 有上游依赖（requires 非空）

对 requires 中列出的每个上游层，添加：

```
## 上游设计（{upstream-layer-id} — 必读）
使用 Read 工具加载上游层设计文档，扫描 `{IDEA_DIR}/frontend-designs/{upstream-layer-id}/` 目录下所有 task 文件。
重点关注 `## 导出契约` 区，作为本层设计的上游依据。
```

如果 requires 中直接或间接依赖了 OHS 层（即上游链追溯到第一个 Phase），追加：

```
## OHS 层设计文档
如需参考 OHS 层完整设计（API 端点、DTO 字段），使用 Read 工具加载：`{ohs.md 的绝对路径}`
```

上一个 Thinker 完成后，不再提取导出契约内联，下游 Thinker 通过 Read 工具按需加载。
