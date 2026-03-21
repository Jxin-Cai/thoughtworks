#!/usr/bin/env bash
# SubagentStop hook — 子代理结束时保底执行状态标记
#
# 读取 .thoughtworks/<idea>/.current-task.json 获取当前任务上下文：
#   { "role": "thinker|worker", "layer": "<layer>", "idea_dir": "<path>" }
#
# 编排器在启动 subagent 前写入该文件，本脚本在 subagent 结束后读取并标记状态。
# 如果 .current-task.json 不存在（非 DDD 流程调用），静默退出。
#
# 使用方式: 在 hooks.json 的 SubagentStop 中配置

set -euo pipefail

# 遍历 .thoughtworks/ 下所有 idea 目录，查找 .current-task.json
find_current_task() {
  local base_dir="."
  if [ -d ".thoughtworks" ]; then
    for idea_dir in .thoughtworks/*/; do
      local task_file="${idea_dir}.current-task.json"
      if [ -f "$task_file" ]; then
        echo "$task_file"
        return 0
      fi
    done
  fi
  return 1
}

TASK_FILE=$(find_current_task) || exit 0

# 解析 .current-task.json（纯 bash，不依赖 jq）
ROLE=$(sed -n 's/.*"role"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TASK_FILE" | head -1)
LAYER=$(sed -n 's/.*"layer"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TASK_FILE" | head -1)
IDEA_DIR=$(sed -n 's/.*"idea_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TASK_FILE" | head -1)
STACK=$(sed -n 's/.*"stack"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TASK_FILE" | head -1)

# 验证必要字段
[ -z "$ROLE" ] || [ -z "$LAYER" ] || [ -z "$IDEA_DIR" ] && exit 0

# 确定状态标记目标
if [ "$ROLE" = "thinker" ]; then
  TARGET_STATUS="designed"
elif [ "$ROLE" = "worker" ]; then
  TARGET_STATUS="coded"
else
  exit 0
fi

# 确定使用哪个 workflow-status.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$STACK" = "frontend" ]; then
  STATUS_SCRIPT="$(dirname "$SCRIPT_DIR")/frontend/skills/thoughtworks-skills-frontend-help/scripts/frontend-workflow-status.sh"
else
  STATUS_SCRIPT="$(dirname "$SCRIPT_DIR")/backend/skills/thoughtworks-skills-backend-help/scripts/backend-workflow-status.sh"
fi

# 检查当前层状态 — 只在状态为 designing/coding 时才标记完成（避免重复标记）
if [ -f "$STATUS_SCRIPT" ] && [ -d "$IDEA_DIR" ]; then
  CURRENT_STATUS=$(bash "$STATUS_SCRIPT" "$IDEA_DIR" --get-status "$LAYER" 2>/dev/null || echo "")

  if [ "$ROLE" = "thinker" ] && [ "$CURRENT_STATUS" = "designing" ]; then
    bash "$STATUS_SCRIPT" "$IDEA_DIR" --set "$LAYER" "$TARGET_STATUS" 2>/dev/null || true
  elif [ "$ROLE" = "worker" ] && [ "$CURRENT_STATUS" = "coding" ]; then
    bash "$STATUS_SCRIPT" "$IDEA_DIR" --set "$LAYER" "$TARGET_STATUS" 2>/dev/null || true
  fi
fi

# 清理 .current-task.json
rm -f "$TASK_FILE"
