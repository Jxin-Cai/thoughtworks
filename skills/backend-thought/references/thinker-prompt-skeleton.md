# Thinker Subagent Prompt 骨架

编排器为每个层构建 subagent prompt 时使用以下结构。

## Prompt 模板

```
Agent(
  subagent_type: "tw-backend:agent-ddd-thinker",
  max_turns: 20,
  description: "{Layer} 层思考",
  prompt: "
    {仅当 --modification 参数存在时注入以下区块，否则省略：}

    # MODIFICATION（设计修正指令 — 优先级高于 MISSION）

    本次是对已有设计的修正，而非全新设计。你必须：
    1. 先 Read 已有的设计文档（`{DESIGNS_DIR}/{layer}/` 目录下的 task 文件）
    2. 根据以下修改说明，定向修改受影响的部分，保持未涉及部分不变
    3. 修改完成后，仍需执行反思循环验证所有工作项覆盖

    修改说明：{--modification 参数值}

    ---

    # MISSION（工作目标 — 结论先行，先理解你要做什么）

    {主 agent 根据 assessment.md 中该层的评估结论，用 2-4 句话总结该层的核心工作目标}

    具体包括：
    {主 agent 根据评估结论列出的该层需要完成的具体工作项，每项一行}

    {仅 domain 层追加以下内容：}
    ## 领域建模结构要求

    requirement.md 的领域建模分析章节列出了识别出的领域建模单元及其依赖关系。
    为每个领域建模单元输出独立的 task 文件（`{nnn}-{domain-topic-slug}.md`，写入 `backend-designs/domain/` 目录），每个 task 包含该领域主题的完整设计。
    领域建模单元可以是聚合、领域服务，或二者结合；强相关的小型单元可合并为一个 task，但单个 task 不超过 800 行。

    你的设计方案完成后，必须回头逐条验证上述每个工作项都有对应的设计产出。

    ---

    # DECISIONS ALREADY MADE（编排器已确认的事实 — 不需要你重新判断）

    - idea_name: {idea}
    - target_layer: {layer}
    - backend_language: {BACKEND_LANG}
    - this_layer_is_required_because: {从 assessment.md 该层评估部分提取 2-3 句结论}
    - out_of_scope: {本次不涉及的层/能力，从 assessment.md 提取不需要开发的层列表}
    - upstream_source:
      {对每个上游层，标注来源类型：}
      - {upstream_layer}: {implemented → scan code | designed → scan design | not_in_scope → scan historical code}
    - task_granularity: {domain: 一个领域建模单元 | infr: 一个实现主题 | application: 一个用例组 | ohs: 一个资源组}

    ---

    # TEMPLATE（产出骨架 — 写入文件的结构）

    使用 Read 工具加载设计文档模板：`{design-template 的绝对路径}`
    严格按照模板结构输出设计文档。

    ---

    # CONTEXT（输入文档 — 读取作为上下文）

    ## 目标层级
    target_layer: {layer}

    ## 后端语言
    backend_language: {BACKEND_LANG}

    {对每个上游层，按 upstream-scan-guide.md 的情况 A 或 B 生成对应子区块}

    {无上游依赖时（如 domain 层）：省略上游相关子区块}

    ## 需求
    使用 Read 工具加载需求文档：`{IDEA_DIR}/requirement.md`

    ---

    # OUTPUT

    将设计文档写入：`.thoughtworks/<idea-name>/backend-designs/{layer}/` 目录
    每个 task 一个文件，命名格式：`{nnn}-{topic-slug}.md`

    ## Task 拆分规则
    - domain 层：每个领域建模单元一个 task（聚合、领域服务或混合建模，小型相关单元可合并）
    - infr 层：每个实现主题一个 task（常见为仓储实现或外部集成主题）
    - application 层：每个用例组一个 task
    - ohs 层：每个 API 资源组一个 task
    - 单个 task 文件不超过 800 行
    - 每个 task 的 frontmatter 必须包含 task_id、layer、order、status、depends_on、description

    使用 Write 工具写入。

    重要：TEMPLATE 是你的产出结构，MISSION / CONTEXT 是你的参考约束，不要将它们复制到产出文件中。
  "
)
```

## MISSION 区块填充规则

主 agent 在组装 prompt 时，需要从 `assessment.md` 的该层评估部分提取信息，生成结论先行的工作目标描述：

1. **总结句** — 用 2-4 句话说明这一层要做什么、为什么要做
2. **具体工作项** — 从评估结论中提炼出 numbered list，每项是一个可验证的工作目标
3. **验证锚点** — 这些工作项将成为 thinker 反思循环中逐条验证的基准

注意：设计指令和编码规范由 thinker agent 在完成必要扫描后、开始写设计方案前，通过 `/backend-load thinker {target_layer} {backend_language}` 自行加载，编排器无需预读内联。

## DECISIONS 区块填充规则

主 agent 在组装 prompt 时，需要从 `assessment.md` 和 `workflow.yaml` 中提取已确认的事实，直接注入 DECISIONS 区块：

1. **this_layer_is_required_because** — 从 assessment.md 该层评估部分提取 2-3 句结论
2. **out_of_scope** — 列出 assessment.md 中标记为"不需要开发"的层
3. **upstream_source** — 对每个上游层（workflow.yaml `requires` 列出的），判断来源类型：
   - 上游层状态为 coded → `implemented → scan code`
   - 上游层状态为 designed/confirmed → `designed → scan design`
   - 上游层未注册（不在本次开发范围）→ `not_in_scope → scan historical code`
4. **task_granularity** — 根据 target_layer 填入对应的拆分单位

这些字段是编排器的已确认决策，thinker 不需要重新判断，直接遵循即可。
