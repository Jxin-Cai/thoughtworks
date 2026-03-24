#!/usr/bin/env bash
# gate-check.sh — HARD-GATE 程序化检查脚本
#
# 用法: gate-check.sh <idea-dir> <gate-id> [extra-args...]
# 输出: YAML 格式 { pass: true/false, reason: "..." }
#
# 门控 ID 与 orchestration.yaml 中的 gate 字段对应。
# 所有门控检查均为非阻塞、幂等操作。

set -euo pipefail

IDEA_DIR="${1:?用法: gate-check.sh <idea-dir> <gate-id> [extra-args...]}"
GATE_ID="${2:?用法: gate-check.sh <idea-dir> <gate-id> [extra-args...]}"
shift 2

# ── 输出辅助 ──

gate_pass() {
  echo "pass: true"
  exit 0
}

gate_fail() {
  local reason="$1"
  printf 'pass: false\nreason: "%s"\n' "$reason"
  exit 0
}

# ── 门控检查 ──

case "$GATE_ID" in

  # idea 目录存在性
  idea-dir-exists)
    if [ -d "$IDEA_DIR" ]; then
      gate_pass
    else
      gate_fail "idea directory does not exist: $IDEA_DIR"
    fi
    ;;

  # 后端需求澄清完成
  requirement-exists)
    if [ -f "$IDEA_DIR/requirement.md" ]; then
      gate_pass
    else
      gate_fail "requirement.md 不存在于 $IDEA_DIR/"
    fi
    ;;

  # 前端需求澄清完成
  frontend-requirement-exists)
    if [ -f "$IDEA_DIR/frontend-requirement.md" ]; then
      gate_pass
    else
      gate_fail "frontend-requirement.md 不存在于 $IDEA_DIR/"
    fi
    ;;

  # 后端层级评估完成
  assessment-exists)
    if [ -f "$IDEA_DIR/assessment.md" ]; then
      gate_pass
    else
      gate_fail "assessment.md 不存在于 $IDEA_DIR/"
    fi
    ;;

  # 前端评估完成
  frontend-assessment-exists)
    if [ -f "$IDEA_DIR/frontend-assessment.md" ]; then
      gate_pass
    else
      gate_fail "frontend-assessment.md 不存在于 $IDEA_DIR/"
    fi
    ;;

  # 工作流状态文件已初始化（后端）
  workflow-state-exists)
    if [ -f "$IDEA_DIR/workflow-state.yaml" ]; then
      gate_pass
    else
      gate_fail "workflow-state.yaml 不存在于 $IDEA_DIR/"
    fi
    ;;

  # 工作流状态文件已初始化（前端）
  frontend-workflow-state-exists)
    if [ -f "$IDEA_DIR/frontend-workflow-state.yaml" ]; then
      gate_pass
    else
      gate_fail "frontend-workflow-state.yaml 不存在于 $IDEA_DIR/"
    fi
    ;;

  # 检查指定层的上游是否就绪（需要 extra-args: <layer> <stack>）
  upstream-ready)
    LAYER="${1:?upstream-ready 需要指定层名}"
    STACK="${2:-backend}"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
    if [ "$STACK" = "frontend" ]; then
      STATUS_SCRIPT="$REPO_ROOT/frontend/skills/frontend-help/scripts/frontend-workflow-status.sh"
    else
      STATUS_SCRIPT="$REPO_ROOT/backend/skills/backend-help/scripts/backend-workflow-status.sh"
    fi
    if [ -f "$STATUS_SCRIPT" ]; then
      result=$(bash "$STATUS_SCRIPT" "$IDEA_DIR" --check-upstream "$LAYER" 2>/dev/null || echo '{}')
      if echo "$result" | grep -q '"upstream_ready": true\|"upstream_ready":true'; then
        gate_pass
      else
        gate_fail "层 $LAYER 的上游依赖未就绪"
      fi
    else
      gate_fail "workflow-status 脚本不存在: $STATUS_SCRIPT"
    fi
    ;;

  # 后端设计文件存在（支持按层分目录和旧版 *.md 目录）
  designs-exist)
    found=false
    # 新模式：按层分目录（domain/, infr/, application/, ohs/）
    for layer_dir in "$IDEA_DIR/backend-designs"/*/; do
      [ -d "$layer_dir" ] || continue
      if ls "$layer_dir"*.md >/dev/null 2>&1; then
        found=true
        break
      fi
    done
    # 旧模式回退：backend-designs/*.md
    if ! $found && [ -d "$IDEA_DIR/backend-designs" ] && ls "$IDEA_DIR/backend-designs/"*.md >/dev/null 2>&1; then
      found=true
    fi
    if $found; then
      gate_pass
    else
      gate_fail "backend-designs/ 目录不存在或无设计文件"
    fi
    ;;

  # 前端设计文件存在（支持按层分目录和旧版 *.md 目录）
  frontend-designs-exist)
    found=false
    # 新模式：按层分目录
    for layer_dir in "$IDEA_DIR/frontend-designs"/*/; do
      [ -d "$layer_dir" ] || continue
      if ls "$layer_dir"*.md >/dev/null 2>&1; then
        found=true
        break
      fi
    done
    # 旧模式回退：frontend-designs/*.md
    if ! $found && [ -d "$IDEA_DIR/frontend-designs" ] && ls "$IDEA_DIR/frontend-designs/"*.md >/dev/null 2>&1; then
      found=true
    fi
    if $found; then
      gate_pass
    else
      gate_fail "frontend-designs/ 目录不存在或无设计文件"
    fi
    ;;

  # 后端设计已确认
  approved)
    if [ -f "$IDEA_DIR/.approved" ]; then
      gate_pass
    else
      gate_fail ".approved 标记不存在于 $IDEA_DIR/"
    fi
    ;;

  # 前端设计已确认
  frontend-approved)
    if [ -f "$IDEA_DIR/.frontend-approved" ]; then
      gate_pass
    else
      gate_fail ".frontend-approved 标记不存在于 $IDEA_DIR/"
    fi
    ;;

  # 当前在 feature 分支上
  branch-ready)
    IDEA_NAME=$(basename "$IDEA_DIR")
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [ "$CURRENT_BRANCH" = "feature/$IDEA_NAME" ]; then
      gate_pass
    elif echo "$CURRENT_BRANCH" | grep -q "^feature/"; then
      gate_pass
    else
      gate_fail "当前不在 feature 分支上（当前: $CURRENT_BRANCH）"
    fi
    ;;

  # 工程支撑任务文件存在
  supplementary-tasks-exist)
    if [ -f "$IDEA_DIR/supplementary-tasks.md" ] && [ -s "$IDEA_DIR/supplementary-tasks.md" ]; then
      gate_pass
    else
      gate_fail "supplementary-tasks.md 不存在或为空"
    fi
    ;;

  # 后端需求遗漏审查完成
  supplementary-reviewed)
    if [ -f "$IDEA_DIR/.supplementary-reviewed" ]; then
      gate_pass
    else
      gate_fail ".supplementary-reviewed 标记不存在"
    fi
    ;;

  # 前端需求遗漏审查完成
  frontend-supplementary-reviewed)
    if [ -f "$IDEA_DIR/.frontend-supplementary-reviewed" ]; then
      gate_pass
    else
      gate_fail ".frontend-supplementary-reviewed 标记不存在"
    fi
    ;;

  # 清理残留的 .current-task 文件（超过 30 分钟的视为残留）
  stale-tasks)
    cleaned=0
    for task_file in "$IDEA_DIR"/.current-task-*.json; do
      [ -f "$task_file" ] || continue
      if [ "$(uname)" = "Darwin" ]; then
        file_age=$(( $(date +%s) - $(stat -f %m "$task_file") ))
      else
        file_age=$(( $(date +%s) - $(stat -c %Y "$task_file") ))
      fi
      if [ "$file_age" -gt 1800 ]; then
        rm -f "$task_file"
        cleaned=$((cleaned + 1))
      fi
    done
    if [ "$cleaned" -gt 0 ]; then
      printf 'pass: true\ncleaned: %d\n' "$cleaned"
    else
      gate_pass
    fi
    ;;

  *)
    printf 'pass: false\nreason: "未知门控 ID: %s"\n' "$GATE_ID"
    exit 1
    ;;
esac
