# 后端状态机

**启动后第一步：检查已有状态，决定从哪个 Step 开始。禁止跳过此检查直接执行 Step 1。**

## 启动时检查

1. 扫描 `.thoughtworks/` 下的目录
2. **判断 `$ARGUMENTS` 是恢复旧 idea 还是全新需求**：
   - 如果 `$ARGUMENTS` 完全匹配某个已有 idea 目录名（如用户传入 `user-management`，且 `.thoughtworks/user-management/` 存在）→ 恢复旧 idea
   - 如果 `$ARGUMENTS` 是一段需求描述文本（而非 idea 目录名）→ 全新需求，走 Step 1 → Step 2
   - 如果不确定，使用 AskUserQuestion 向用户确认：是要恢复已有 idea，还是开始新的需求
3. 全新需求始终从 Step 1 → Step 2 开始
4. 恢复旧 idea 时，按下表决定续传位置

## 后端状态决策表

| 状态 | 判断方式 | 行为 |
|------|---------|------|
| 无 idea | `.thoughtworks/` 下无匹配目录，或 `$ARGUMENTS` 为全新需求 | → Step 1 接收需求 → Step 2 澄清 |
| 有 idea，无 requirement | `requirement.md` 不存在 | → Step 2 澄清（补完未完成的澄清） |
| 有 idea，无 assessment | `requirement.md` 存在，`assessment.md` 不存在 | → 层级评估 |
| 有 idea，某层 designing | `workflow-state.json` 某层为 `designing` | → 从该层重新启动 Thinker |
| 有 idea，某层 designed | `workflow-state.json` 某层为 `designed`，未确认 | → 等用户确认该 Phase 设计 |
| 有 idea，某层 coding | `workflow-state.json` 某层为 `coding` | → 从该层重新启动 Worker |
| 有 idea，designs 全 done | `.approved` 存在 | → 提示已完成 |

## 后端断点续传

Decision-Maker 支持从中断处恢复。检查 `.thoughtworks/<idea-name>/` 目录：

1. `.approved` 存在 → 已完成
2. `workflow-state.json` 存在 → 检查各层状态，从中断处继续
3. `assessment.md` 存在 → 从 Phase 循环继续
4. `requirement.md` 存在但无 assessment → 从层级评估开始
5. `requirement.md` 不存在 → 从 Step 2 澄清开始
