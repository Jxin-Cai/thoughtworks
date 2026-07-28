# Worker Subagent Prompt 骨架

编排器为每个子域构建 worker subagent prompt 时使用以下结构。

## Prompt 模板

```
Agent(
  subagent_type: "tw:agent-ddd-worker",
  max_turns: 20,
  description: "{subdomain_name} 垂直实现",
  prompt: "
    {如有重试，插入 PRIOR ATTEMPT 块}

    # TASK

    实现子域「{subdomain_name}」的完整垂直切片代码（Domain → Infrastructure → Application → OHS）。

    实现清单：
    {从设计文档末尾的「实现清单」表格中提取}

    # EXECUTION CONTRACT

    - subdomain_name: {subdomain_name}
    - backend_language: {BACKEND_LANG}
    - implementation_order: domain → infr → application → ohs（严格按依赖顺序）
    - must_implement: {实现清单中的所有类}
    - may_infer: DDL 完整字段、PO 对象、DTO 字段（从设计文档推导）
    - must_NOT_change: 设计文档、其他子域的代码、不相关文件
    - escalate_if: 签名冲突、缺失信息、需修改其他子域

    # CONTEXT

    - 设计文档：使用 Read 加载 {子域设计文件绝对路径}
    - 项目结构扫描：
      - `**/domain/**/*.{ext}` — 已有领域模型
      - `**/infr/**/*.{ext}` — 已有基础设施
      - `**/ohs/**/Response.{ext}` — 复用统一响应包装
      - `**/ohs/**/*Advice.{ext}` — 复用全局异常处理

    # VERIFY & FINALIZE

    实现完成后按以下 Glob 模式验证各层产物：
    {从 workflow.yaml 的 verify.{BACKEND_LANG} 中列出每层的 pattern}

    全部通过 → 运行:
    STACK=backend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --set {subdomain_name} coded

    如有未通过 → 运行:
    STACK=backend node {SCRIPTS}/workflow-status.mjs {IDEA_DIR} --set {subdomain_name} failed
    并报告缺失的产物。
  "
)
```

## PRIOR ATTEMPT 块模板（仅在重试时使用）

```
# PRIOR ATTEMPT FAILURE

上次实现验证发现以下问题，请在本次输出中修正：

验证失败的 patterns：
{列出 Glob 未命中的 pattern 和对应描述}

失败原因：{subagent 上次的失败报告}
```
