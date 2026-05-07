# 上游代码扫描指引

本文件定义 Thinker subagent prompt 中 CONTEXT 区块的上游依赖扫描模板。

## 情况 A：上游层代码已实现

当上游层的 Worker 已完成编码，代码存在于项目中时，使用以下模板：

```
## 上游已实现代码（{upstream-layer} 层）

{upstream-layer} 层的代码已经实现，你需要通过扫描已有代码来获取你需要依赖的接口列表。

### 扫描指引
- 建议扫描的包路径模式（按需选用，扩展名根据 BACKEND_LANG：Java→`.java`，Python→`.py`，Go→`.go`）：
  - 聚合根/实体：`**/domain/**/model/*.{ext}`
  - 仓储接口：`**/domain/**/repository/*.{ext}`
  - 领域事件：`**/domain/**/event/*.{ext}`
  - 防腐层接口：`**/domain/**/acl/*.{ext}`
  - 领域服务：`**/domain/**/service/*.{ext}`
  - 应用服务：`**/application/**/*ApplicationService.{ext}`（Python/Go 中可能命名不同，按包名搜索）
  - Command：`**/application/**/*Command.{ext}`（Python/Go 中可能命名不同，按包名搜索）

### 扫描原则
1. **需求驱动** — 只扫描 MISSION 工作目标中涉及的类和方法，不做全量扫描
2. **签名提取** — 对找到的类，用 Read 工具读取其公有方法签名和关键字段
3. **来源标注** — 依赖契约子表标题标注（来自已有代码），每行说明列附注源文件路径
```

## 情况 B：上游层被评估为"不需要"

当 `assessment.md` 中该上游层标记为"不需要"，但项目中可能有历史代码时，使用以下模板：

```
## 上游已有代码（{upstream-layer} 层 — 无当前设计文档）

{upstream-layer} 层在本次需求中不需要新开发，已有实现存在于代码库中。
你需要根据 MISSION 中的工作目标，使用 Glob 和 Grep 工具从已有代码中**按需扫描**所需的上游能力。

### 扫描指引
- assessment.md 中关于该层的说明："{从 assessment.md 提取该层的说明}"
- 建议扫描的包路径模式（同情况 A 的路径列表）

### 扫描原则
1. **需求驱动** — 只扫描 MISSION 工作目标中涉及的类和方法，不做全量扫描
2. **签名提取** — 对找到的类，用 Read 工具读取其公有方法签名和关键字段
3. **来源标注** — 依赖契约子表标题标注（来自已有代码），每行说明列附注源文件路径
```

## 无上游依赖时

如 domain 层，省略上游相关子区块。
