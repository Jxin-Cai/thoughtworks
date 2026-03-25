#!/usr/bin/env bash
# orchestration-status.sh — 程序化编排恢复点检测
#
# 用法: orchestration-status.sh <idea-dir|none> <stack>
#   idea-dir: .thoughtworks/<idea-name> 路径，或 "none" 表示尚无 idea 目录
#   stack:    backend | frontend | all
#
# 输出: YAML 格式，包含 resume_step / reason / completed_steps / phase_detail
#
# 本脚本依次检查编排步骤的前置条件，首个未满足条件即为 resume 点。
# 编排器（SKILL.md）在每步执行前后调用本脚本，严格按输出推进。

set -euo pipefail

IDEA_DIR="${1:?用法: orchestration-status.sh <idea-dir|none> <stack>}"
STACK="${2:?用法: orchestration-status.sh <idea-dir|none> <stack>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
GATE_CHECK="$SCRIPT_DIR/gate-check.sh"

# 路径设置
BACKEND_WORKFLOW_YAML="$REPO_ROOT/backend/skills/backend-help/workflow.yaml"

# source 共享库（需要 STATE_FILE 变量，按需设置）
source "$SCRIPT_DIR/workflow-lib.sh"

# ── 辅助函数 ──

check_gate() {
  local gate_id="$1"; shift
  local result
  result=$(bash "$GATE_CHECK" "$IDEA_DIR" "$gate_id" "$@" 2>/dev/null || echo "pass: false")
  echo "$result" | grep -q "^pass: true"
}

get_phase_for_layer() {
  local wf_yaml="$1" layer_id="$2"
  awk -v lid="$layer_id" '
    BEGIN { found=0 }
    $0 ~ "^  - id: " lid "$" { found=1; next }
    found && /^  - id:/ { exit }
    found && /phase:/ { gsub(/.*phase:[[:space:]]*/, ""); print; exit }
  ' "$wf_yaml"
}

# ── YAML 输出函数 ──

sub_step_priority() {
  case "$1" in
    design)  echo 1 ;;
    confirm) echo 2 ;;
    code)    echo 3 ;;
    *)       echo 9 ;;
  esac
}

COMPLETED_STEPS=""

add_completed() {
  local step="$1"
  if [ -z "$COMPLETED_STEPS" ]; then
    COMPLETED_STEPS="$step"
  else
    COMPLETED_STEPS="$COMPLETED_STEPS $step"
  fi
}

emit_result() {
  local resume_step="$1"
  local reason="$2"
  local current_phase="${3:-}"
  local sub_step="${4:-}"
  local layers="${5:-}"

  echo "resume_step: $resume_step"
  echo "idea_dir: $IDEA_DIR"
  echo "stack: $STACK"
  echo "reason: \"$reason\""

  local count=0
  for s in $COMPLETED_STEPS; do
    count=$((count + 1))
  done
  echo "completed_steps_count: $count"

  if [ -n "$current_phase" ]; then
    echo "phase_detail:"
    echo "  current_phase: $current_phase"
    echo "  sub_step: $sub_step"
    echo "  layers:"
    for l in $layers; do
      echo "    - $l"
    done
  fi
}

# ── 共享层检查函数 ──

# 检查后端层状态，返回 0 表示全部完成，返回 1 表示有未完成（已 emit_result）
# 参数: $1=step_prefix (""=backend单独, "backend:"=all模式)
_check_backend_layers() {
  local step_prefix="${1:-}"
  STATE_FILE="$IDEA_DIR/workflow-state.yaml"
  local tracked
  tracked=$(get_tracked_layers)

  if [ -z "$tracked" ]; then
    emit_result "${step_prefix}assessment" "workflow-state.yaml has no tracked layers"
    return 1
  fi

  local first_incomplete_phase=""
  local first_incomplete_sub_step=""
  local incomplete_layers=""

  for layer in $tracked; do
    local st
    st=$(get_tracked_status "$layer")
    local phase
    phase=$(get_phase_for_layer "$BACKEND_WORKFLOW_YAML" "$layer")
    local layer_sub_step=""

    case "$st" in
      coded) continue ;;
      pending|failed|designing) layer_sub_step="design" ;;
      designed) layer_sub_step="confirm" ;;
      confirmed|coding) layer_sub_step="code" ;;
    esac

    if [ -z "$first_incomplete_phase" ] || [ "$phase" -lt "$first_incomplete_phase" ]; then
      first_incomplete_phase="$phase"
      first_incomplete_sub_step="$layer_sub_step"
      incomplete_layers="$layer"
    elif [ "$phase" = "$first_incomplete_phase" ]; then
      local cur_pri new_pri
      cur_pri=$(sub_step_priority "$first_incomplete_sub_step")
      new_pri=$(sub_step_priority "$layer_sub_step")
      if [ "$new_pri" -lt "$cur_pri" ]; then
        first_incomplete_sub_step="$layer_sub_step"
      fi
      incomplete_layers="$incomplete_layers $layer"
    fi
  done

  if [ -n "$first_incomplete_phase" ]; then
    emit_result "${step_prefix}phase-loop" "backend layer(s) incomplete in phase $first_incomplete_phase" \
      "$first_incomplete_phase" "$first_incomplete_sub_step" "$incomplete_layers"
    return 1
  fi

  return 0
}

# 检查前端层状态，返回 0 表示全部完成，返回 1 表示有未完成（已 emit_result）
# 参数: $1=step_prefix (""=frontend单独, "frontend:"=all模式)
_check_frontend_layers() {
  local step_prefix="${1:-}"
  STATE_FILE="$IDEA_DIR/frontend-workflow-state.yaml"
  local tracked
  tracked=$(get_tracked_layers)

  if [ -z "$tracked" ]; then
    emit_result "${step_prefix}assessment" "frontend-workflow-state.yaml has no tracked layers"
    return 1
  fi

  local has_incomplete=false
  local first_sub_step=""
  local incomplete_layers=""

  for layer in $tracked; do
    local st
    st=$(get_tracked_status "$layer")
    case "$st" in
      coded) ;;
      pending|failed|designing)
        has_incomplete=true
        if [ -z "$first_sub_step" ] || [ "$first_sub_step" != "design" ]; then
          first_sub_step="design"
        fi
        incomplete_layers="$incomplete_layers $layer"
        ;;
      designed)
        has_incomplete=true
        if [ -z "$first_sub_step" ]; then
          first_sub_step="confirm"
        fi
        incomplete_layers="$incomplete_layers $layer"
        ;;
      confirmed|coding)
        has_incomplete=true
        if [ -z "$first_sub_step" ]; then
          first_sub_step="code"
        fi
        incomplete_layers="$incomplete_layers $layer"
        ;;
    esac
  done

  incomplete_layers=$(echo "$incomplete_layers" | sed 's/^ //')

  if [ "$has_incomplete" = "true" ]; then
    case "$first_sub_step" in
      design)
        emit_result "${step_prefix}design" "frontend layer(s) need design" "" "$first_sub_step" "$incomplete_layers"
        ;;
      confirm)
        emit_result "${step_prefix}confirm-layers" "frontend layer(s) designed, need confirmation" "" "$first_sub_step" "$incomplete_layers"
        ;;
      code)
        emit_result "${step_prefix}code" "frontend layer(s) confirmed, need coding" "" "$first_sub_step" "$incomplete_layers"
        ;;
    esac
    return 1
  fi

  return 0
}

# ── Backend 检查链 ──

check_backend() {
  if [ "$IDEA_DIR" = "none" ] || [ ! -d "$IDEA_DIR" ]; then
    emit_result "receive-requirement" "idea directory does not exist"
    return
  fi
  add_completed "receive-requirement"

  if ! check_gate "requirement-exists"; then
    emit_result "clarify" "requirement.md does not exist"
    return
  fi
  add_completed "clarify"

  if ! check_gate "branch-ready"; then
    emit_result "branch" "not on feature branch"
    return
  fi
  add_completed "branch"

  if ! check_gate "assessment-exists"; then
    emit_result "assessment" "assessment.md does not exist"
    return
  fi
  add_completed "assessment"

  if ! check_gate "workflow-state-exists"; then
    emit_result "assessment" "workflow-state.yaml not initialized (assessment step incomplete)"
    return
  fi

  if ! _check_backend_layers ""; then
    return
  fi
  add_completed "phase-loop"

  if ! check_gate "approved"; then
    emit_result "mark-approved" "all layers coded, .approved not yet set"
    return
  fi
  add_completed "mark-approved"

  if ! check_gate "supplementary-reviewed"; then
    emit_result "supplementary" "requirement review not done yet"
    return
  fi
  add_completed "supplementary"

  emit_result "merge" "backend approved, ready to merge"
}

# ── Frontend 检查链 ──

check_frontend() {
  if [ "$IDEA_DIR" = "none" ] || [ ! -d "$IDEA_DIR" ]; then
    emit_result "receive-idea" "idea directory does not exist"
    return
  fi
  add_completed "receive-idea"

  if ! check_gate "frontend-requirement-exists"; then
    emit_result "clarify" "frontend-requirement.md does not exist"
    return
  fi
  add_completed "clarify"

  if ! check_gate "branch-ready"; then
    emit_result "branch" "not on feature branch"
    return
  fi
  add_completed "branch"

  if ! check_gate "frontend-assessment-exists"; then
    emit_result "assessment" "frontend-assessment.md does not exist"
    return
  fi
  add_completed "assessment"

  if ! check_gate "frontend-workflow-state-exists"; then
    emit_result "assessment" "frontend-workflow-state.yaml not initialized"
    return
  fi

  if ! _check_frontend_layers ""; then
    return
  fi
  add_completed "design"
  add_completed "confirm-layers"
  add_completed "code"

  if ! check_gate "frontend-approved"; then
    emit_result "confirm-layers" "all frontend layers coded but .frontend-approved not set"
    return
  fi
  add_completed "frontend-approved"

  if ! check_gate "frontend-supplementary-reviewed"; then
    emit_result "supplementary" "frontend requirement review not done yet"
    return
  fi
  add_completed "supplementary"

  emit_result "merge" "frontend approved, ready to merge"
}

# ── All 检查链（组合后端 + 前端）──

check_all() {
  if [ "$IDEA_DIR" = "none" ] || [ ! -d "$IDEA_DIR" ]; then
    emit_result "receive-requirement" "idea directory does not exist"
    return
  fi
  add_completed "receive-requirement"

  if ! check_gate "requirement-exists"; then
    emit_result "backend:clarify" "requirement.md does not exist"
    return
  fi
  add_completed "backend:clarify"

  if ! check_gate "frontend-requirement-exists"; then
    emit_result "frontend:clarify" "frontend-requirement.md does not exist"
    return
  fi
  add_completed "frontend:clarify"

  if ! check_gate "branch-ready"; then
    emit_result "branch" "not on feature branch"
    return
  fi
  add_completed "branch"

  # ── Backend 子检查 ──
  if ! check_gate "assessment-exists"; then
    emit_result "backend:assessment" "assessment.md does not exist"
    return
  fi
  add_completed "backend:assessment"

  if ! check_gate "workflow-state-exists"; then
    emit_result "backend:assessment" "workflow-state.yaml not initialized"
    return
  fi

  if ! _check_backend_layers "backend:"; then
    return
  fi
  add_completed "backend:phase-loop"

  if ! check_gate "approved"; then
    emit_result "backend:mark-approved" "all backend layers coded, .approved not yet set"
    return
  fi
  add_completed "backend:mark-approved"

  # ── Frontend 子检查 ──
  if ! check_gate "frontend-assessment-exists"; then
    emit_result "frontend:assessment" "frontend-assessment.md does not exist"
    return
  fi
  add_completed "frontend:assessment"

  if ! check_gate "frontend-workflow-state-exists"; then
    emit_result "frontend:assessment" "frontend-workflow-state.yaml not initialized"
    return
  fi

  if ! _check_frontend_layers "frontend:"; then
    return
  fi
  add_completed "frontend:design"
  add_completed "frontend:confirm-layers"
  add_completed "frontend:code"

  if ! check_gate "frontend-approved"; then
    emit_result "frontend:mark-approved" "frontend layers coded but .frontend-approved not set"
    return
  fi
  add_completed "frontend:mark-approved"

  # supplementary
  local be_reviewed fe_reviewed
  be_reviewed=true
  fe_reviewed=true
  check_gate "supplementary-reviewed" || be_reviewed=false
  check_gate "frontend-supplementary-reviewed" || fe_reviewed=false
  if [ "$be_reviewed" = "false" ] || [ "$fe_reviewed" = "false" ]; then
    emit_result "supplementary" "requirement review not done for all stacks"
    return
  fi
  add_completed "supplementary"

  emit_result "merge" "all stacks approved, ready to merge"
}

# ── 主入口 ──

case "$STACK" in
  backend)
    check_backend
    ;;
  frontend)
    check_frontend
    ;;
  all)
    check_all
    ;;
  *)
    echo "error: unknown stack '${STACK}', expected: backend | frontend | all" >&2
    exit 1
    ;;
esac
