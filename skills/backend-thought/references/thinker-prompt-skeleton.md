# Thinker Subagent Prompt 骨架

编排器为每个子域构建 subagent prompt 时使用以下结构。

## Prompt 模板

```
Agent(
  subagent_type: "tw:agent-ddd-thinker",
  max_turns: 25,
  description: "{subdomain_name} 垂直设计",
  prompt: "
    {如有 --modification 参数，插入 MODIFICATION 块}

    # MISSION

    为子域「{subdomain_name}」设计完整的垂直切片方案（Domain → Infrastructure → Application → OHS）。

    {从 assessment.md 提取该子域的 2-4 句描述}

    工作项：
    {逐条列出该子域需要覆盖的业务能力}

    # DECISIONS ALREADY MADE

    - subdomain_name: {subdomain_name}
    - backend_language: {BACKEND_LANG}
    - depends_on_subdomains: {依赖的其他子域列表，无则为空}
    - already_designed: {已完成设计的其他子域列表}

    # TEMPLATE

    使用 Read 工具加载设计模板：{subdomain-design.md 的绝对路径}

    # CONTEXT

    - 需求文档：使用 Read 加载 {requirement.md 绝对路径}
    - 上游代码扫描：如果项目中已有代码，使用 Glob 搜索以下模式了解已有结构：
      - `**/domain/**/model/*.{ext}` — 已有领域模型
      - `**/application/**/*.{ext}` — 已有应用服务
      - `**/ohs/**/*.{ext}` — 已有接口
    - 已设计的其他子域：{如有，列出文件路径供参考}

    # OUTPUT

    写入：{IDEA_DIR}/backend-designs/{nnn}-{subdomain-slug}.md
    文件必须覆盖全部 4 层设计，格式遵循 TEMPLATE。
  "
)
```

## MODIFICATION 块模板（仅在有 --modification 参数时使用）

```
# MODIFICATION

用户对已有设计提出修改要求：

> {--modification 参数值}

请基于已有设计文件进行修改。已有设计路径：{DESIGNS_DIR}/{subdomain 设计文件}
先 Read 已有设计，理解当前方案，再按修改要求调整。
```
