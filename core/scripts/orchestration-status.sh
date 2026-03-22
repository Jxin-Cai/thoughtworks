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
BACKEND_WF_STATUS="$REPO_ROOT/backend/skills/thoughtworks-skills-backend-help/scripts/backend-workflow-status.sh"
BACKEND_WORKFLOW_YAML="$REPO_ROOT/backend/skills/thoughtworks-skills-backend-help/workflow.yaml"
FRONTEND_WF_STATUS="$REPO_ROOT/frontend/skills/thoughtworks-skills-frontend-help/scripts/frontend-workflow-status.sh"
FRONTEND_WORKFLOW_YAML="$REPO_ROOT/frontend/skills/thoughtworks-skills-frontend-help/workflow.yaml"

# source 共享库（需要 STATE_FILE 变量，按需设置）
source "$SCRIPT_DIR/workflow-lib.sh"

# ── 辅助函数 ──

# 调用 gate-check.sh 并返回 0(pass) / 1(fail)
check_gate() {
  local gate_id="$1"; shift
  local result
  result=$(bash "$GATE_CHECK" "$IDEA_DIR" "$gate_id" "$@" 2>/dev/null || echo "pass: false")
  echo "$result" | grep -q "^pass: true"
}

# 从 workflow.yaml 提取所有层 id（按文件中出现顺序，即 phase 升序）
get_layers_from_workflow() {
  local wf_yaml="$1"
  awk '/^  - id:/ { gsub(/.*id:[[:space:]]*/, ""); print }' "$wf_yaml"
}

# 从 workflow.yaml 提取某层的 phase 值
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

# sub_step 优先级：design(1) < confirm(2) < code(3)
sub_step_priority() {
  case "$1" in
    design)  echo 1 ;;
    confirm) echo 2 ;;
    code)    echo 3 ;;
    *)       echo 9 ;;
  esac
}

# 全局变量收集 completed_steps
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
  # 可选: phase_detail 参数
  local current_phase="${3:-}"
  local sub_step="${4:-}"
  local layers="${5:-}"

  echo "resume_step: $resume_step"
  echo "idea_dir: $IDEA_DIR"
  echo "stack: $STACK"
  echo "reason: \"$reason\""

  # completed_steps
  echo "completed_steps:"
  if [ -n "$COMPLETED_STEPS" ]; then
    for s in $COMPLETED_STEPS; do
      echo "  - $s"
    done
  fi

  # phase_detail（仅 phase-loop 时输出）
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

# ── Backend 检查链 ──

check_backend() {
  # Step 1: idea-dir 存在性
  if [ "$IDEA_DIR" = "none" ] || [ ! -d "$IDEA_DIR" ]; then
    emit_result "receive-requirement" "idea directory does not exist"
    return
  fi
  add_completed "receive-requirement"

  # Step 2: clarify (requirement-exists)
  if ! check_gate "requirement-exists"; then
    emit_result "clarify" "requirement.md does not exist"
    return
  fi
  add_completed "clarify"

  # Step 3: branch (branch-ready)
  if ! check_gate "branch-ready"; then
    emit_result "branch" "not on feature branch"
    return
  fi
  add_completed "branch"

  # Step 4: assessment (assessment-exists)
  if ! check_gate "assessment-exists"; then
    emit_result "assessment" "assessment.md does not exist"
    return
  fi
  add_completed "assessment"

  # Step 5: workflow-state 初始化检查
  if ! check_gate "workflow-state-exists"; then
    emit_result "assessment" "workflow-state.yaml not initialized (assessment step incomplete)"
    return
  fi

  # Step 6: phase-loop — 遍历层状态
  STATE_FILE="$IDEA_DIR/workflow-state.yaml"
  local tracked
  tracked=$(get_tracked_layers)

  if [ -z "$tracked" ]; then
    emit_result "assessment" "workflow-state.yaml has no tracked layers"
    return
  fi

  # 按 workflow.yaml 中的 phase 排序遍历层
  # 收集每层的 phase 和 status
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
      coded)
        # 已完成，继续
        continue
        ;;
      pending|failed|designing)
        layer_sub_step="design"
        ;;
      designed)
        layer_sub_step="confirm"
        ;;
      confirmed|coding)
        layer_sub_step="code"
        ;;
    esac

    if [ -z "$first_incomplete_phase" ] || [ "$phase" -lt "$first_incomplete_phase" ]; then
      # 发现更早的 phase
      first_incomplete_phase="$phase"
      first_incomplete_sub_step="$layer_sub_step"
      incomplete_layers="$layer"
    elif [ "$phase" = "$first_incomplete_phase" ]; then
      # 同 phase，取最小 sub_step
      local cur_pri new_pri
      cur_pri=$(sub_step_priority "$first_incomplete_sub_step")
      new_pri=$(sub_step_priority "$layer_sub_step")
      if [ "$new_pri" -lt "$cur_pri" ]; then
        first_incomplete_sub_step="$layer_sub_step"
      fi
      incomplete_layers="$incomplete_layers $layer"
    fi
  done

  # 如果有未完成层，输出 phase-loop
  if [ -n "$first_incomplete_phase" ]; then
    emit_result "phase-loop" "layer(s) incomplete in phase $first_incomplete_phase" \
      "$first_incomplete_phase" "$first_incomplete_sub_step" "$incomplete_layers"
    return
  fi

  # 所有层 coded
  add_completed "phase-loop"

  # Step 7: mark-approved
  if ! check_gate "approved"; then
    emit_result "mark-approved" "all layers coded, .approved not yet set"
    return
  fi
  add_completed "mark-approved"

  # Step 8: merge
  emit_result "merge" "backend approved, ready to merge"
}

# ── Frontend 检查链 ──

check_frontend() {
  # Step 1: idea-dir 存在性
  if [ "$IDEA_DIR" = "none" ] || [ ! -d "$IDEA_DIR" ]; then
    emit_result "receive-idea" "idea directory does not exist"
    return
  fi
  add_completed "receive-idea"

  # Step 2: clarify (frontend-requirement-exists)
  if ! check_gate "frontend-requirement-exists"; then
    emit_result "clarify" "frontend-requirement.md does not exist"
    return
  fi
  add_completed "clarify"

  # Step 3: branch (branch-ready)
  if ! check_gate "branch-ready"; then
    emit_result "branch" "not on feature branch"
    return
  fi
  add_completed "branch"

  # Step 4: assessment (frontend-assessment-exists)
  if ! check_gate "frontend-assessment-exists"; then
    emit_result "assessment" "frontend-assessment.md does not exist"
    return
  fi
  add_completed "assessment"

  # Step 5: frontend-workflow-state 初始化检查
  if ! check_gate "frontend-workflow-state-exists"; then
    emit_result "assessment" "frontend-workflow-state.yaml not initialized"
    return
  fi

  # Step 6: 遍历前端层状态
  STATE_FILE="$IDEA_DIR/frontend-workflow-state.yaml"
  local tracked
  tracked=$(get_tracked_layers)

  if [ -z "$tracked" ]; then
    emit_result "assessment" "frontend-workflow-state.yaml has no tracked layers"
    return
  fi

  local has_incomplete=false
  local first_sub_step=""
  local incomplete_layers=""

  for layer in $tracked; do
    local st
    st=$(get_tracked_status "$layer")

    case "$st" in
      coded)
        ;;
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
        emit_result "design" "frontend layer(s) need design" "" "$first_sub_step" "$incomplete_layers"
        ;;
      confirm)
        emit_result "confirm-layers" "frontend layer(s) designed, need confirmation" "" "$first_sub_step" "$incomplete_layers"
        ;;
      code)
        emit_result "code" "frontend layer(s) confirmed, need coding" "" "$first_sub_step" "$incomplete_layers"
        ;;
    esac
    return
  fi

  # 所有层 coded
  add_completed "design"
  add_completed "confirm-layers"
  add_completed "code"

  # Step 7: frontend-approved
  if ! check_gate "frontend-approved"; then
    emit_result "confirm-layers" "all frontend layers coded but .frontend-approved not set"
    return
  fi
  add_completed "frontend-approved"

  # Step 8: merge
  emit_result "merge" "frontend approved, ready to merge"
}

# ── All 检查链（组合后端 + 前端）──

check_all() {
  # Step 1: idea-dir 存在性
  if [ "$IDEA_DIR" = "none" ] || [ ! -d "$IDEA_DIR" ]; then
    emit_result "receive-requirement" "idea directory does not exist"
    return
  fi
  add_completed "receive-requirement"

  # Step 2.1: backend clarify (requirement-exists)
  if ! check_gate "requirement-exists"; then
    emit_result "backend-clarify" "requirement.md does not exist"
    return
  fi
  add_completed "backend-clarify"

  # Step 2.2: frontend clarify (frontend-requirement-exists)
  if ! check_gate "frontend-requirement-exists"; then
    emit_result "frontend-clarify" "frontend-requirement.md does not exist"
    return
  fi
  add_completed "frontend-clarify"

  # Step 3.1: branch (branch-ready)
  if ! check_gate "branch-ready"; then
    emit_result "branch" "not on feature branch"
    return
  fi
  add_completed "branch"

  # ── Backend 子检查 ──

  # Step 3.2: backend assessment
  if ! check_gate "assessment-exists"; then
    emit_result "backend-assessment" "assessment.md does not exist"
    return
  fi
  add_completed "backend-assessment"

  # backend workflow-state
  if ! check_gate "workflow-state-exists"; then
    emit_result "backend-assessment" "workflow-state.yaml not initialized"
    return
  fi

  # Step 3.3: backend phase-loop
  STATE_FILE="$IDEA_DIR/workflow-state.yaml"
  local tracked
  tracked=$(get_tracked_layers)

  if [ -n "$tracked" ]; then
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
        pending|failed|designing)
          layer_sub_step="design"
          ;;
        designed)
          layer_sub_step="confirm"
          ;;
        confirmed|coding)
          layer_sub_step="code"
          ;;
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
      emit_result "backend-phase-loop" "backend layer(s) incomplete in phase $first_incomplete_phase" \
        "$first_incomplete_phase" "$first_incomplete_sub_step" "$incomplete_layers"
      return
    fi
  fi

  add_completed "backend-phase-loop"

  # Step 3.4: backend mark-approved
  if ! check_gate "approved"; then
    emit_result "backend-mark-approved" "all backend layers coded, .approved not yet set"
    return
  fi
  add_completed "backend-mark-approved"

  # ── Frontend 子检查 ──

  # Step 3.5: frontend assessment
  if ! check_gate "frontend-assessment-exists"; then
    emit_result "frontend-assessment" "frontend-assessment.md does not exist"
    return
  fi
  add_completed "frontend-assessment"

  # frontend workflow-state
  if ! check_gate "frontend-workflow-state-exists"; then
    emit_result "frontend-assessment" "frontend-workflow-state.yaml not initialized"
    return
  fi

  # Step 3.6-3.8: frontend layers
  STATE_FILE="$IDEA_DIR/frontend-workflow-state.yaml"
  tracked=$(get_tracked_layers)

  if [ -n "$tracked" ]; then
    local fe_has_incomplete=false
    local fe_first_sub_step=""
    local fe_incomplete_layers=""

    for layer in $tracked; do
      local st
      st=$(get_tracked_status "$layer")
      case "$st" in
        coded) ;;
        pending|failed|designing)
          fe_has_incomplete=true
          if [ -z "$fe_first_sub_step" ] || [ "$fe_first_sub_step" != "design" ]; then
            fe_first_sub_step="design"
          fi
          fe_incomplete_layers="$fe_incomplete_layers $layer"
          ;;
        designed)
          fe_has_incomplete=true
          if [ -z "$fe_first_sub_step" ]; then
            fe_first_sub_step="confirm"
          fi
          fe_incomplete_layers="$fe_incomplete_layers $layer"
          ;;
        confirmed|coding)
          fe_has_incomplete=true
          if [ -z "$fe_first_sub_step" ]; then
            fe_first_sub_step="code"
          fi
          fe_incomplete_layers="$fe_incomplete_layers $layer"
          ;;
      esac
    done

    fe_incomplete_layers=$(echo "$fe_incomplete_layers" | sed 's/^ //')

    if [ "$fe_has_incomplete" = "true" ]; then
      case "$fe_first_sub_step" in
        design)
          emit_result "frontend-design" "frontend layer(s) need design" "" "$fe_first_sub_step" "$fe_incomplete_layers"
          ;;
        confirm)
          emit_result "frontend-confirm-layers" "frontend layer(s) designed, need confirmation" "" "$fe_first_sub_step" "$fe_incomplete_layers"
          ;;
        code)
          emit_result "frontend-code" "frontend layer(s) confirmed, need coding" "" "$fe_first_sub_step" "$fe_incomplete_layers"
          ;;
      esac
      return
    fi
  fi

  add_completed "frontend-design"
  add_completed "frontend-confirm-layers"
  add_completed "frontend-code"

  # Step 3.9: frontend-approved
  if ! check_gate "frontend-approved"; then
    emit_result "frontend-mark-approved" "frontend layers coded but .frontend-approved not set"
    return
  fi
  add_completed "frontend-mark-approved"

  # Step 3.10: merge
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
    echo "error: unknown stack '$STACK', expected: backend | frontend | all" >&2
    exit 1
    ;;
esac
