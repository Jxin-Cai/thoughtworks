# 前端实现清单文档模板

按以下结构输出，所有占位符 `{...}` 替换为实际内容。

---

```markdown
---
task_id: impl-{nnn}
layer: frontend-checklist
order: {N}
status: pending
depends_on: [{上游 task_id 列表}]
description: "{一句话描述}"
---
# 前端实现清单

<!-- REQUIRED -->
## 结论

（一句话概括：本次前端实现包含多少个文件，覆盖哪些 FSD 层）

<!-- REQUIRED -->
## 依赖契约

> 以下列表来自 `frontend-components.md` 导出契约，作为实现清单的生成输入。

### 组件清单（来自 frontend-components.md 导出契约）

| 组件名称 | 所属 Slice | 类型 | 文件路径 |
|---------|-----------|------|---------|
| {ComponentName} | `src/entities/{entity-name}/ui/` | Entity 组件 | `{ComponentName}.tsx` |
| {ComponentName} | `src/features/{feature-name}/ui/` | Feature 组件 | `{ComponentName}.tsx` |

### API 函数清单（来自 frontend-components.md 导出契约）

| 函数名称 | 所属 Slice | 端点 | 文件路径 |
|---------|-----------|------|---------|
| {apiFunction} | `src/entities/{entity-name}/api/` | `{METHOD} /api/{resource}` | `{entity}Api.ts` |
| {apiFunction} | `src/features/{feature-name}/api/` | `{METHOD} /api/{resource}` | `{feature}Api.ts` |

<!-- REQUIRED -->
## 实现清单

| 序号 | output_id | FSD 层 | 文件路径 | 类型 | 说明 |
|------|-----------|--------|---------|------|------|
| 1 | Output_Frontend_{IdeaName}_01 | shared | `src/shared/api/client.ts` | API 客户端 | {说明} |
| 2 | Output_Frontend_{IdeaName}_02 | entity | `src/entities/{entity}/api/{entity}Api.ts` | Entity API | {说明} |
| 3 | Output_Frontend_{IdeaName}_03 | entity | `src/entities/{entity}/model/types.ts` | 类型定义 | {说明} |
| 4 | Output_Frontend_{IdeaName}_04 | entity | `src/entities/{entity}/ui/{Component}.tsx` | Entity 组件 | {说明} |
| 5 | Output_Frontend_{IdeaName}_05 | entity | `src/entities/{entity}/model/use{Entity}.ts` | Entity Hook | {说明} |
| 6 | Output_Frontend_{IdeaName}_06 | entity | `src/entities/{entity}/index.ts` | Public API | Entity slice 导出 |
| 7 | Output_Frontend_{IdeaName}_07 | feature | `src/features/{feature}/api/{api}.ts` | Feature API | {说明} |
| 8 | Output_Frontend_{IdeaName}_08 | feature | `src/features/{feature}/model/types.ts` | 类型定义 | {说明} |
| 9 | Output_Frontend_{IdeaName}_09 | feature | `src/features/{feature}/ui/{Component}.tsx` | Feature 组件 | {说明} |
| 10 | Output_Frontend_{IdeaName}_10 | feature | `src/features/{feature}/model/use{Feature}.ts` | Feature Hook | {说明} |
| 11 | Output_Frontend_{IdeaName}_11 | feature | `src/features/{feature}/index.ts` | Public API | Feature slice 导出 |
| 12 | Output_Frontend_{IdeaName}_12 | page | `src/pages/{PageName}.tsx` | 页面 | {说明} |
| 13 | Output_Frontend_{IdeaName}_13 | app | `src/app/router/index.tsx` | 路由配置 | {说明} |
| 14 | Output_Frontend_{IdeaName}_14 | config | `vite.config.ts` | 构建配置 | 配置层级路径别名（如项目已有则标注为"修改"） |
```
