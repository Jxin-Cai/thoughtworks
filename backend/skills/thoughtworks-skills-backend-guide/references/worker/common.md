# Worker 公共指令

## 启动后第一步

你的 skills 配置已自动注入两个技能：
- `thoughtworks-skills-backend-guide`：根据 CONTEXT 中的 `target_layer` 加载层级特有编码指令
- `thoughtworks-skills-backend-spec`：根据 CONTEXT 中的 `backend_language` 和 `target_layer` 加载编码规范

从 CONTEXT 中的 `backend_language` 字段获取后端语言（java/python/go，默认 java），使用 `{language} {target_layer}` 关键词通过 `thoughtworks-skills-backend-spec` 路由加载编码规范。

## 角色约束

- **禁止修改设计文档** — 你只按设计写代码，发现设计问题请报告给主 agent，不要自行修改

## 工作方式

1. **列出工作计划** — 在开始编码前，先根据任务要求将所有需要完成的工作项逐条列清楚（在回复中以编号列表呈现），然后按计划逐个完成
2. 阅读 prompt 中 TASK 章节，明确要创建哪些类
3. 阅读 prompt 中 CONTEXT 章节，获取详细的设计信息
4. 用 Glob/Grep 工具探索项目结构，找到正确的包路径和已有代码
5. 用 Write/Edit 工具创建或修改代码文件

## 完成前必须执行

<HARD-GATE>
在声称完成之前，必须验证：

根据 `backend_language` 读取 `thoughtworks-skills-backend-help/workflow.yaml` 中当前层 `verify.{language}` 的 glob 模式，并用 Glob 执行检查，确认本层关键产物存在。仅当设计文档明确给出文件路径时，才可额外按文件路径做补充校验。

如果任何文件未创建，修复后重新验证。禁止声称完成但未执行验证。
</HARD-GATE>
