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

## 使用

### 全栈（推荐）

```
/thoughtworks-all 实现一个用户注册功能
```

### 仅后端

```
/thoughtworks-backend 实现一个用户注册功能，支持邮箱注册和手机号注册
```

### 仅前端（需先完成后端 OHS 设计）

```
/thoughtworks-frontend <idea-name>
```

### 分步执行

```bash
/thoughtworks-backend-clarify <idea-name>        # 后端需求澄清
/thoughtworks-backend-thought <idea-name>        # 后端设计
/thoughtworks-backend-works <idea-name>          # 后端编码

/thoughtworks-frontend-clarify <idea-name>   # 前端需求澄清
/thoughtworks-frontend-thought <idea-name>   # 前端设计
/thoughtworks-frontend-works <idea-name>     # 前端编码
```

### 加载编码规范

```bash
/thoughtworks-skills-java-spec domain|application|infr|ohs
/thoughtworks-skills-frontend-spec react-ts
```

## License

[MIT](LICENSE)
