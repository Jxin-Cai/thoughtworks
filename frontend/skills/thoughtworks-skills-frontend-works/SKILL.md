---
name: thoughtworks-skills-frontend-works
description: Use when user wants to start frontend coding, execute implementation checklists from frontend design docs.
argument-hint: "<idea-name>"
agents:
  - thoughtworks-agent-frontend-worker
---

# Frontend Spec-Driven Development — 执行流程

用户传入的参数：`$ARGUMENTS`

---

## 铁律

1. **checklist 驱动编码** — Worker 从 `frontend-checklist.md` 提取实现清单作为主执行清单，`frontend-architecture.md` 和 `frontend-components.md` 作为上下文参考
2. **禁止修改实现清单** — 实现清单由 thought skill 产出，执行阶段不能修改
3. **禁止未验证就标记 done** — agent 完成后必须验证文件已创建

---

## Step 1: 选择 idea

判断 `$ARGUMENTS`：
- 有参数 → 使用指定的 idea-name
- 无参数 → 列出所有 idea，让用户选择

验证 `.thoughtworks/<idea-name>/frontend-designs/` 目录存在且包含设计文件。

设置变量：
- `IDEA_DIR` = `.thoughtworks/<idea-name>`
- `FRONTEND_HELP` = `../thoughtworks-skills-frontend-help/`
- `DESIGNS_DIR` = `{IDEA_DIR}/frontend-designs`

---

## Step 2: 读取状态与设计文件

```bash
bash {FRONTEND_HELP}/scripts/frontend-status.sh {IDEA_DIR}
```

- `all_done` → 提示已完成
- `blocked` → 列出 failed 文件
- 其他 → 继续执行

读取 3 个设计文件：
- `{DESIGNS_DIR}/frontend-architecture.md` — 架构设计（FSD 层级、路由、依赖契约）
- `{DESIGNS_DIR}/frontend-components.md` — 组件设计（Props/State/API 映射）
- `{DESIGNS_DIR}/frontend-checklist.md` — 实现清单（主执行清单）

从 `frontend-checklist.md` 提取实现清单表格作为 Worker 的执行清单。

---

## Step 2.5: UI/UX 实现能力准备

检查当前会话环境中是否有 `ui-ux-pro-max` 技能可用。

如果可用：
1. 从 `frontend-requirement.md` 中提取产品类型和风格关键词（如有 `## UI 风格` 章节则提取风格标识）
2. 运行 design-system 生成命令获取设计系统：
   ```bash
   python3 {UI_UX_SKILL_DIR}/scripts/search.py "{产品类型} {风格关键词}" --design-system -f markdown
   ```
3. 检测项目技术栈（从 package.json 读取，如 react/vue/nextjs），运行 stack guidelines 获取实现指引：
   ```bash
   python3 {UI_UX_SKILL_DIR}/scripts/search.py "{关键词}" --stack {tech-stack}
   ```
4. 将以上输出存储为 `UI_UX_IMPL_GUIDANCE`，在 Step 3 构建 worker prompt 时注入

如果不可用 → 跳过此步骤，Worker 按原有逻辑编码。

注意：`UI_UX_SKILL_DIR` = `~/.claude/skills/ui-ux-pro-max`（ui-ux-pro-max 技能的安装路径）。

---

## Step 3: 执行

**标记进入编码阶段**：在开始执行前，运行：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-checklist coding
```

读取 `frontend-checklist.md` 的 frontmatter，将 status 更新为 `in_progress`。

启动 worker agent：

```
Task(
  subagent_type: "thoughtworks-frontend:thoughtworks-agent-frontend-worker",
  max_turns: 15,
  description: "Frontend: {frontend-checklist.md 的 description}",
  prompt: "
    # TASK

    根据以下实现清单，逐项创建前端代码文件：

    {frontend-checklist.md 中的实现清单表格}

    ---

    # CONTEXT

    ## 前端架构设计
    {frontend-architecture.md 完整内容}

    ## 前端组件设计
    {frontend-components.md 完整内容}

    ## 前端实现清单
    {frontend-checklist.md 完整内容}

    ## OHS 层设计（只读参考）
    如需参考 OHS 层设计，使用 Read 工具加载：`{ohs.md 的绝对路径}`

    {如果 UI_UX_IMPL_GUIDANCE 存在：}
    ## UI/UX 实现指引

    以下是 ui-ux-pro-max 生成的设计系统和实现最佳实践，编码时必须遵循：

    ### 设计系统
    {design-system 输出}

    ### 技术栈最佳实践
    {stack guidelines 输出}

    ### 编码完成前检查清单
    在声称完成之前，按以下清单逐项验证：
    - [ ] 不使用 emoji 作为 icon（使用 SVG icon 库）
    - [ ] 所有可点击元素有 cursor-pointer
    - [ ] hover 状态有视觉反馈（颜色/阴影过渡）
    - [ ] 颜色对比度满足 4.5:1（WCAG AA）
    - [ ] 触控目标 >= 44x44px
    - [ ] 使用 prefers-reduced-motion 尊重用户动效偏好
    - [ ] 表单输入有 label
    - [ ] 图片有 alt 文本
    - [ ] transition 时长 150-300ms

    ---

    # OUTPUT

    在项目中创建前端代码文件。
    保持代码变更最小化，只实现当前实现清单涉及的文件。
  "
)
```

验证产出：用 Glob 搜索确认文件已创建。如果有文件未创建，重新启动 worker agent，在 prompt 开头追加：

```
---

# PREVIOUS ATTEMPT FAILURE

上次实现验证发现以下文件未创建：
{未创建的文件路径列表}

请确保本次执行后这些文件存在。

---
```

**最多重试 2 次**，超过后暂停并用 AskUserQuestion 询问用户。

验证通过后，将 `frontend-checklist.md` 的 frontmatter status 更新为 `done`。

**标记编码完成**：Worker 执行完毕后（验证通过），运行：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-checklist coded
```

如果 Worker 失败，运行：
```bash
bash {FRONTEND_HELP}/scripts/frontend-workflow-status.sh {IDEA_DIR} --set frontend-checklist failed
```

---

## Step 4: 完成汇总

```bash
bash {FRONTEND_HELP}/scripts/frontend-status.sh {IDEA_DIR}
```

输出实现摘要和产出文件列表。
