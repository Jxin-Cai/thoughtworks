---
name: verify
description: 对子域代码执行独立编译验证（检测代码能否通过编译）
argument-hint: "<idea-name> <subdomain>"

agent:
  - agent-verifier
---

# 独立编译验证

用户传入的参数：`$ARGUMENTS`

## 路径变量

| 变量 | 路径 |
|------|------|
| `{SCRIPTS}` | `../../scripts` |

---

## 执行逻辑

1. **解析参数**：从 `$ARGUMENTS` 提取 idea-name 和 subdomain（空格分隔）

2. **检测项目语言**：读取 `.thoughtworks/<idea-name>/requirement.md`，提取 `BACKEND_LANG`（默认 java）

3. **确定项目根目录**：扫描当前工作目录查找构建工具文件（pom.xml、go.mod 等）

4. **确定子域文件范围**：读取 `../backend-help/workflow.yaml` 的 verify patterns，推导该子域的文件 glob

5. **启动 Verifier Agent**：

```
Agent(
  subagent_type: "tw:agent-verifier",
  description: "{subdomain} 编译验证",
  prompt: "
    # CONTEXT
    - subdomain_name: {subdomain}
    - backend_language: {BACKEND_LANG}
    - project_root: {项目根目录}
    - scope: {文件范围 glob}
    # 仅执行编译验证
  "
)
```

6. **解析结果**：

```bash
node {SCRIPTS}/verify-result.mjs .thoughtworks/{idea-name} {subdomain} '<agent输出的JSON>'
```

7. **向用户报告**验证结果摘要
