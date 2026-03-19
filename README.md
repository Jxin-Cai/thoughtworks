# ThoughtWorks DDD

基于契约驱动设计的 Claude Code 插件，通过多智能体协同实现从需求澄清到 DDD 四层架构代码生成的完整工作流。

## 安装

添加 marketplace（只需一次）：

```bash
/plugin marketplace add Jxin-Cai/thoughtworks
```

按需安装：

```bash
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
/thoughtworks-skills-java-spec domain|application|infr|ohs
/thoughtworks-skills-frontend-spec react-ts
```

## License

[MIT](LICENSE)
