# ThoughtWorks DDD

基于契约驱动设计的 Claude Code 插件，通过多智能体协同实现从需求澄清到 DDD 四层架构代码生成的完整工作流。

## 安装

添加 marketplace（只需一次）：

```bash
/plugin marketplace add Jxin-Cai/thoughtworks
```

按需安装：

```bash
# 仅共享能力层（branch / merge / 共享引用资源）
/plugin install thoughtworks-core@thoughtworks

# 全栈（后端 + 前端）
/plugin install thoughtworks-all@thoughtworks

# 仅后端
/plugin install thoughtworks-backend@thoughtworks

# 仅前端
/plugin install thoughtworks-frontend@thoughtworks
```

更新 / 卸载：

```bash
/plugin update thoughtworks-all
/plugin uninstall thoughtworks-all
```

### 本地开发

```bash
git clone git@github.com:Jxin-Cai/thoughtworks.git
claude --plugin-dir ./thoughtworks                # 全栈
claude --plugin-dir ./thoughtworks/backend        # 仅后端
claude --plugin-dir ./thoughtworks/frontend       # 仅前端
```

> ⚠️ 安装或更新插件后，需要重启 Claude Code 才能生效。

## 插件职责边界

三种安装模式的能力范围互不越界：

| 安装模式 | 后端（DDD 四层） | 前端 | 前后端联动 |
|---------|:-:|:-:|:-:|
| `thoughtworks-backend` | ✅ | ❌ | ❌ |
| `thoughtworks-frontend` | ❌ | ✅ | ❌ |
| `thoughtworks-all` | ✅ | ✅ | ✅ |

- 仅安装后端插件时，即使需求描述涉及前端，也只生成后端代码
- 仅安装前端插件时，即使需求描述涉及后端，也只生成前端代码
- 安装全栈插件后，才会自动编排前后端联动（后端先行，前端消费 OHS 导出契约）

## 设计思路

### 1) 四层子插件架构

项目拆分为 `core/`、`backend/`、`frontend/`、`all/` 四个子插件：

- `thoughtworks-core`：共享能力层，提供 branch/merge 技能和共享引用资源。
- `thoughtworks-backend`：后端 DDD 闭环（澄清 → 设计 → 编码）。
- `thoughtworks-frontend`：前端闭环（消费后端 OHS 契约进行设计与编码）。
- `thoughtworks-all`：全栈编排入口，统一调度前后端能力。

这种拆分确保“按需安装、能力边界清晰、复用集中在 core”。

### 2) 设计与实现分离

流程按角色分为 Thinker 与 Worker：

- Thinker 负责产出设计文档，不直接改业务代码。
- Worker 只按设计文档落地实现，不反向篡改设计。

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
/thoughtworks-skills-all 实现一个用户注册功能
```

### 仅后端

```
/thoughtworks-skills-backend 实现一个用户注册功能，支持邮箱注册和手机号注册
```

### 仅前端（需先完成后端 OHS 设计）

```
/thoughtworks-skills-frontend <idea-name>
```

### 分步执行

```bash
/thoughtworks-skills-backend-clarify <idea-name>        # 后端需求澄清
/thoughtworks-skills-backend-thought <idea-name>        # 后端设计
/thoughtworks-skills-backend-works <idea-name>          # 后端编码

/thoughtworks-skills-frontend-clarify <idea-name>   # 前端需求澄清
/thoughtworks-skills-frontend-thought <idea-name>   # 前端设计
/thoughtworks-skills-frontend-works <idea-name>     # 前端编码
```

### 会话行为说明

- 安装对应插件后，SessionStart 会**优先**引导使用匹配的编排技能（backend / frontend / all）。
- 对明显不属于编排流程的请求（如代码审查、文档解释、小范围修复），允许直接响应，不强制进入编排技能。
- 当需求属于标准 DDD 编排流程时，建议直接调用对应 skill，而不是手工拆解内部步骤。

### 分支合并行为

- `/thoughtworks-skills-merge <idea-name>` 在合并前会检查未提交变更，并提示确认要纳入合并的文件范围。
- 清理功能分支时默认采用安全删除（`git branch -d`）；若存在未合并提交，再由用户确认是否强制删除。

### 加载编码规范

```bash
/thoughtworks-skills-backend-spec java|python|go <domain|application|infr|ohs>
/thoughtworks-skills-frontend-spec react-ts
```

## License

[MIT](LICENSE)
