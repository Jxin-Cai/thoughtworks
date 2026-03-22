#!/usr/bin/env bash
# SubagentStop hook — subagent 结束时自动收敛状态
#
# 编排器在启动 subagent 前写入 .thoughtworks/<idea>/.current-task-<layer>-<timestamp>.json：
#   { "role": "thinker|worker", "layer": "<layer>", "idea_dir": "<path>", "stack": "backend|frontend" }
#
# 文件名中的 timestamp 用于避免并发 session 的文件冲突。
#
# 本脚本在 subagent 结束后读取所有匹配的任务文件，逐个标记状态：
#   thinker (designing → designed)
#   worker  (coding → coded)
#
# 如果无任务文件（非 DDD 流程调用），静默退出。
# 超过 30 分钟的残留任务文件视为过期，清理而非处理。
#
# 使用方式: 在 hooks.json 的 SubagentStop 中配置

set -euo pipefail

STALE_THRESHOLD=1800  # 30 分钟（秒）

# 收集所有 .current-task-*.json 文件
collect_task_files() {
  local files=()
  if [ -d ".thoughtworks" ]; then
    for idea_dir in .thoughtworks/*/; do
      for task_file in "${idea_dir}".current-task-*.json; do
        [ -f "$task_file" ] && files+=("$task_file")
      done
    done
  fi
  if [ ${#files[@]} -eq 0 ]; then
    return 1
  fi
  printf '%s\n' "${files[@]}"
}

# 检查文件是否过期（创建时间超过阈值）
is_stale() {
  local file="$1"
  local now file_mtime age
  now=$(date +%s)
  # macOS 兼容: stat -f %m (macOS) 或 stat -c %Y (Linux)
  if stat -f %m "$file" >/dev/null 2>&1; then
    file_mtime=$(stat -f %m "$file")
  else
    file_mtime=$(stat -c %Y "$file")
  fi
  age=$((now - file_mtime))
  [ "$age" -gt "$STALE_THRESHOLD" ]
}

TASK_FILES=$(collect_task_files) || exit 0

# 解析物理路径以穿透 symlink（backend/scripts → ../core/scripts）
# core/scripts → dirname → core → dirname → thoughtworks（仓库根）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

while IFS= read -r TASK_FILE; do
  # 清理过期的残留任务文件
  if is_stale "$TASK_FILE"; then
    rm -f "$TASK_FILE"
    continue
  fi

  # 解析任务文件（纯 bash，不依赖 jq）
  ROLE=$(sed -n 's/.*"role"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TASK_FILE" | head -1)
  LAYER=$(sed -n 's/.*"layer"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TASK_FILE" | head -1)
  IDEA_DIR=$(sed -n 's/.*"idea_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TASK_FILE" | head -1)
  STACK=$(sed -n 's/.*"stack"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TASK_FILE" | head -1)

  # 验证必要字段
  if [ -z "$ROLE" ] || [ -z "$LAYER" ] || [ -z "$IDEA_DIR" ]; then
    rm -f "$TASK_FILE"
    continue
  fi

  # 确定状态标记目标
  if [ "$ROLE" = "thinker" ]; then
    TARGET_STATUS="designed"
    EXPECTED_CURRENT="designing"
  elif [ "$ROLE" = "worker" ]; then
    TARGET_STATUS="coded"
    EXPECTED_CURRENT="coding"
  else
    rm -f "$TASK_FILE"
    continue
  fi

  # 确定使用哪个 workflow-status.sh（基于仓库根目录）
  if [ "$STACK" = "frontend" ]; then
    STATUS_SCRIPT="$REPO_ROOT/frontend/skills/thoughtworks-skills-frontend-help/scripts/frontend-workflow-status.sh"
  else
    STATUS_SCRIPT="$REPO_ROOT/backend/skills/thoughtworks-skills-backend-help/scripts/backend-workflow-status.sh"
  fi

  # 只在状态为预期值时才标记完成（避免重复标记或覆盖 failed）
  if [ -f "$STATUS_SCRIPT" ] && [ -d "$IDEA_DIR" ]; then
    CURRENT_STATUS=$(bash "$STATUS_SCRIPT" "$IDEA_DIR" --get-status "$LAYER" 2>/dev/null || echo "")
    if [ "$CURRENT_STATUS" = "$EXPECTED_CURRENT" ]; then
      bash "$STATUS_SCRIPT" "$IDEA_DIR" --set "$LAYER" "$TARGET_STATUS" 2>/dev/null || true
    fi
  fi

  # 清理任务文件
  rm -f "$TASK_FILE"
done <<< "$TASK_FILES"
