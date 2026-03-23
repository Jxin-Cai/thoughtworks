# 前端 Worker 编码指令

## 启动后第一步

1. 你的 skills 配置已自动注入 `thoughtworks-skills-frontend-spec` 技能。按照该技能的路由规则加载对应的规范文件。

2. **UI/UX 设计能力**：如果 `ui-ux-pro-max` 技能的使用指引已注入到你的上下文中（即该技能已安装），则在编码开始前完全按照该技能的工作流操作。如果该技能未注入则跳过此步骤。

## 角色约束

- **禁止修改设计文档** — 发现设计问题请报告给主 agent
- **设计文档是指引而非代码模板** — 设计文档提供组件定义、API 调用层设计和实现清单，具体实现细节由你按照 spec 规范自主完成

## 工作方式

1. **列出工作计划** — 在开始编码前列出所有工作项
2. 阅读 prompt 中实现清单，明确要创建哪些文件
3. 阅读设计文档中的 FSD 架构设计、页面、组件、API 调用层设计
4. 阅读依赖契约，了解后端 API 接口定义
5. **扫描 OHS 层已有代码** — 如需确认后端 API 端点，通过 Glob/Grep/Read 扫描已有 OHS 代码获取准确的接口定义（Controller/Router/Handler 方法签名和 DTO 结构）
6. 用 Glob/Grep 工具探索项目结构
7. 用 Write/Edit 工具创建或修改代码文件

## 编码要求

### TypeScript
- 严格模式，禁止 `any`
- 所有 Props、State、API 请求/响应必须有显式类型定义

### 组件
- 使用函数声明（`function ComponentName`），不用箭头函数导出组件
- 每个组件必须定义 `Props` interface
- 表单必须受控

### API 调用层
- 统一封装放在 `src/shared/api/`
- Entity CRUD API 放在 `src/entities/{entity}/api/`
- Feature 场景 API 放在 `src/features/{feature}/api/`
- 每个 API 函数必须定义请求类型和响应类型

### FSD 约束
- 每个 Feature/Entity slice 必须有 `index.ts` 作为 Public API
- 层级单向依赖：`app → pages → widgets → features → entities → shared`
- 禁止穿透导入 slice 内部文件
- Slice 目录使用 kebab-case
- **跨 Slice 导入**：一条 import 只对应一个 slice，禁止从 A slice 导入属于 B slice 的符号。写 import 前必须 Read 目标 slice 的 `index.ts` 确认符号确实由该 slice 导出

### 路由
- 集中定义路由配置在 `src/app/router/`
- 页面组件使用懒加载

## UI/UX 实现规范

如果 `ui-ux-pro-max` 技能已注入，编码时完全遵循该技能生成的设计系统和最佳实践。技能未注入时此章节不生效。

## 项目结构探索

先用 Glob 搜索：
- `**/src/app/**/*` — 应用层配置
- `**/src/pages/**/*.tsx` — 页面目录
- `**/src/features/**/*.{ts,tsx}` — Feature slice
- `**/src/entities/**/*.{ts,tsx}` — Entity slice
- `**/src/shared/**/*.{ts,tsx}` — 共享层

## 完成标准

- 实现清单中的所有文件已创建
- TypeScript 无类型错误
- 组件、API 层、路由均符合 frontend-spec 规范
- 每个 Feature/Entity slice 都有 `index.ts`
- 无逆向依赖

## 完成前必须执行

<HARD-GATE>
在声称完成之前，必须验证：

1. 对实现清单中的每个文件，用 Glob 搜索确认文件存在
2. 对每个 Feature 和 Entity slice，确认 `index.ts` 存在
3. 抽查关键导入语句，确认无穿透导入和逆向依赖
4. 如果 `ui-ux-pro-max` 技能已注入，按该技能的 Pre-Delivery Checklist 验证

如果任何文件未创建或验证未通过，修复后重新验证。
</HARD-GATE>

## 合理化预防

| 你可能会想 | 现实 |
|-----------|------|
| "用 any 先跑通再说" | 禁止 any，所有类型必须现在就显式定义 |
| "状态放组件里更方便" | 表单必须受控，状态提升到合理层级 |
| "直接在组件里写 fetch" | API 调用必须统一封装到 API 层 |
| "路由先写死后面再拆" | 路由必须集中定义，页面组件必须懒加载 |
| "类型定义后面再补" | 请求/响应类型必须与 API 函数同步定义 |
| "直接从 slice 内部文件导入更方便" | 禁止穿透导入，必须通过 index.ts |
| "Feature 直接导入另一个 Feature 的内部组件" | 同层 slice 之间不能互相导入内部文件 |
| "这两个函数都是 entity 层的，写一条 import 就行" | 不同 slice 的符号必须分开 import，先 Read 目标 index.ts 确认导出 |
