# 中断处理与级联影响

## 中断处理选项表

设计确认在子技能内部完成（thought 子技能的 HARD-GATE）。如果用户在子技能内部选择了"修改设计"或"终止"，子技能会自行处理。

| 用户输入 | 编排器决策 |
|---------|-----------|
| 确认/继续 | 按当前流程推进 |
| "修改 {layer} 设计" | 将修改说明 + 现有设计传给 thought skill → 只启动该层 thinker → 覆写设计 → 重新校验 → 级联重做下游层 |
| "重新澄清需求" | 回到 Step 2 |
| "终止" | 保存当前状态后退出 |

## 前端级联影响规则

前端 3 层为线性依赖链，修改上游必然级联所有下游：

```
修改 frontend-architecture → 级联重做 frontend-components → 级联重做 frontend-checklist
修改 frontend-components → 级联重做 frontend-checklist
修改 frontend-checklist → 无下游级联
```

## 中断修改时的 thought skill 调用

```
/thoughtworks-skills-frontend-thought <idea-name> --layers <layer> --modification "<修改说明>"
```

thought skill 内部只启动指定层的 thinker，不重跑整个流程。
