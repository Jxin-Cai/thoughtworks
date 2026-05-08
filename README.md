# ThoughtWorks DDD

基于契约驱动设计的 Claude Code 插件，通过多智能体协同实现从需求澄清到 DDD 四层架构代码生成的完整工作流。

## 安装

添加 marketplace（只需一次）：

```bash
/plugin marketplace add Jxin-Cai/thoughtworks
```

安装插件：

```bash
/plugin install tw@thoughtworks
```

更新 / 卸载：

```bash
/plugin update tw
/plugin uninstall tw
```

### 本地开发

```bash
git clone git@github.com:Jxin-Cai/thoughtworks.git
claude --plugin-dir ./thoughtworks
```

> 安装或更新插件后，需要重启 Claude Code 才能生效。

## 插件职责边界

当前仓库提供单一 `tw` 插件，通过不同入口 skill 区分编排路径：

| 入口 | 后端（DDD 四层） | 前端 | 前后端联动 |
|------|:-:|:-:|:-:|
| `/backend` | ✅ | ❌ | ❌ |
| `/frontend` | ❌ | ✅ | ❌ |
| `/all` | ✅ | ✅ | ✅ |
| `/easy` | 按需 | 按需 | ❌ |

- `/backend` 只执行后端 DDD 闭环（澄清 → 设计 → 编码）
- `/frontend` 只执行前端闭环，消费既有 OHS 契约
- `/all` 按后端先行、前端消费 OHS 契约的顺序进行全栈编排
- `/easy` 走轻量路径：结构化需求澄清后交给 Claude Code 原生 plan & code

## 设计思路

### 1) 单插件扁平架构

项目采用符合 Claude Code 最新插件规范的单插件结构：

```
thoughtworks/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/
├── hooks/
├── scripts/
└── skills/
```

- `agents/`：后端与前端 thinker/worker 共 4 个 subagent
- `skills/`：所有入口 skill、子编排 skill、规范加载 skill 与共享 skill
- `skills/_shared/`：跨 skill 共享的参考资料
- `scripts/`：工作流状态、门控校验、subagent 收敛等共享脚本
- `hooks/`：SessionStart 与 SubagentStop hook 配置

### 2) 设计与实现分离

流程按角色分为 Thinker 与 Worker：

- Thinker 负责产出设计文档，不直接改业务代码
- Worker 只按设计文档落地实现，不反向篡改设计

这样可以把“需求理解偏差”和“代码实现偏差”拆开治理，提升可审查性与可恢复性。

### 3) 契约驱动的跨层一致性

每层设计文档维护导出契约与依赖契约。下游层只按需引用上游契约，并通过校验脚本进行签名匹配，保证跨层接口一致。

### 4) 编排策略

- 标准路径：`clarify → thought → works → merge`
- 同 phase 可并行，不同 phase 串行推进
- 中断后可根据状态文件恢复，避免整链重跑

## 使用

### 全栈（推荐）

```
/all 实现一个用户注册功能
```

### 仅后端

```
/backend 实现一个用户注册功能，支持邮箱注册和手机号注册
```

### 仅前端（需先完成后端 OHS 设计）

```
/frontend <idea-name>
```

### 轻量模式

```
/easy 实现一个用户注册功能
```

### 分步执行

```bash
/clarify backend <idea-name>        # 后端需求澄清
/backend-thought <idea-name>        # 后端设计
/backend-works <idea-name>          # 后端编码

/clarify frontend <idea-name>       # 前端需求澄清
/frontend-thought <idea-name>       # 前端设计
/frontend-works <idea-name>         # 前端编码
```

### 会话行为说明

- 安装 `tw` 后，SessionStart 会展示可用入口，但不会根据关键词自动触发技能。
- 对明显不属于编排流程的请求（如代码审查、文档解释、小范围修复），允许直接响应，不强制进入编排技能。
- 当需求属于标准 DDD 编排流程时，建议直接调用对应 skill，而不是手工拆解内部步骤。

### 分支合并行为

- `/merge <idea-name>` 在合并前会检查未提交变更，并提示确认要纳入合并的文件范围。
- 清理功能分支时默认采用安全删除（`git branch -d`）；若存在未合并提交，再由用户确认是否强制删除。

### 加载编码规范

```bash
/backend-spec java|python|go <domain|application|infr|ohs>
/frontend-spec react-ts
```

## License

[MIT](LICENSE)
