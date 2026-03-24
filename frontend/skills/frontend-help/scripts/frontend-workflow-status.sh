#!/usr/bin/env bash
# 前端工作流状态管理脚本
# 用法:
#   frontend-workflow-status.sh <idea-dir>                          — 查看当前状态
#   frontend-workflow-status.sh <idea-dir> --init <idea-name> <layer1> [layer2...]  — 初始化
#   frontend-workflow-status.sh <idea-dir> --set <layer> <status>   — 设置某层状态
#   frontend-workflow-status.sh <idea-dir> --check-all [--verbose]   — 非阻塞检查是否全部完成（默认 brief）
#   frontend-workflow-status.sh <idea-dir> --get-status <layer>     — 获取指定层的纯文本状态值
#   frontend-workflow-status.sh <idea-dir> --init-tasks <idea-name> <task_spec>... — 初始化 task 级状态文件
#   frontend-workflow-status.sh <idea-dir> --set-task <task_id> <status>  — 设置 task 状态
#   frontend-workflow-status.sh <idea-dir> --get-task-status <task_id>    — 获取 task 的纯文本状态值
#   frontend-workflow-status.sh <idea-dir> --sync-layer-status            — 从 task 状态同步层级状态
#   frontend-workflow-status.sh <idea-dir> --next-tasks <design|code>     — 获取下一批可执行 task
#
# 状态文件: <idea-dir>/frontend-workflow-state.yaml
# 状态机: pending → designing → designed → confirmed → coding → coded / failed

set -euo pipefail

IDEA_DIR="${1:?用法: frontend-workflow-status.sh <idea-dir> [--init|--set|--check-all]}"
MODE="${2:-status}"

STATE_FILE="$IDEA_DIR/frontend-workflow-state.yaml"
TASK_STATE_FILE="$IDEA_DIR/frontend-task-workflow-state.yaml"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATE_SCRIPT="$SCRIPT_DIR/frontend-output-validate.sh"

# source 共享库
CORE_LIB="$SCRIPT_DIR/../../../../core/scripts/workflow-lib.sh"
source "$CORE_LIB"

# ── 状态转换合法性校验 ──

validate_transition() {
  local layer="$1" new_status="$2"
  local current_status
  current_status=$(get_tracked_status "$layer")

  if [ -z "$current_status" ]; then
    return 0
  fi

  local valid=false
  case "${current_status}:${new_status}" in
    pending:designing)     valid=true ;;
    designing:designed)    valid=true ;;
    designed:confirmed)    valid=true ;;
    confirmed:coding)      valid=true ;;
    coding:coded)          valid=true ;;
    designing:failed)      valid=true ;;
    coding:failed)         valid=true ;;
    failed:pending)        valid=true ;;
    # 允许编排器强制覆盖
    *:failed)              valid=true ;;
    *:pending)             valid=true ;;
  esac

  if [ "$valid" = "false" ]; then
    echo "{\"error\": \"非法状态转换: $layer $current_status → $new_status\"}" >&2
    return 1
  fi
  return 0
}

# ── 模式分发 ──

case "$MODE" in

  status|--status)
    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "frontend-workflow-state.yaml 不存在"}' >&2
      exit 1
    fi
    idea=$(read_idea)
    tracked=$(get_tracked_layers)
    layers_json=""
    all_done=true
    has_failed=false
    has_in_progress=false

    for layer in $tracked; do
      st=$(get_tracked_status "$layer")

      entry="\"$layer\": { \"status\": \"$st\" }"
      if [ -z "$layers_json" ]; then
        layers_json="$entry"
      else
        layers_json="$layers_json, $entry"
      fi

      case "$st" in
        done|coded)   ;;
        designing|coding)  has_in_progress=true; all_done=false ;;
        failed)       has_failed=true; all_done=false ;;
        *)            all_done=false ;;
      esac
    done

    if $all_done && [ -n "$tracked" ]; then
      overall="all_done"
    elif $has_failed; then
      overall="blocked"
    elif $has_in_progress; then
      overall="in_progress"
    else
      overall="in_progress"
    fi

    echo "{ \"idea\": \"$idea\", \"tracked_layers\": { $layers_json }, \"overall\": \"$overall\" }"
    ;;

  # ── --init 模式：创建初始状态文件 ──
  --init)
    IDEA_NAME="${3:?--init 需要指定 idea-name}"
    shift 3
    LAYERS="$*"

    if [ -z "$LAYERS" ]; then
      echo '{"error": "--init 需要至少一个层名"}' >&2
      exit 1
    fi

    for layer in $LAYERS; do
      case "$layer" in
        frontend-architecture|frontend-components|frontend-checklist) ;;
        *) echo "{\"error\": \"无效层名: $layer，可选: frontend-architecture, frontend-components, frontend-checklist\"}" >&2; exit 1 ;;
      esac
    done

    init_state "$IDEA_NAME" $LAYERS
    echo "{\"initialized\": true, \"idea\": \"$IDEA_NAME\", \"layers\": [$(echo "$LAYERS" | sed 's/ /", "/g;s/^/"/;s/$/"/' )]}"
    ;;

  # ── --set 模式 ──
  --set)
    LAYER="${3:?--set 需要指定层名}"
    STATUS="${4:?--set 需要指定状态 (pending|designing|designed|confirmed|coding|coded|failed)}"

    case "$STATUS" in
      pending|designing|designed|confirmed|coding|coded|failed) ;;
      *) echo "{\"error\": \"无效状态: ${STATUS}，可选: pending|designing|designed|confirmed|coding|coded|failed\"}" >&2; exit 1 ;;
    esac

    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "frontend-workflow-state.yaml 不存在，请先执行 --init"}' >&2
      exit 1
    fi

    if ! is_tracked "$LAYER"; then
      echo "{\"error\": \"层 $LAYER 不在 tracked_layers 中\"}" >&2
      exit 1
    fi

    if ! validate_transition "$LAYER" "$STATUS"; then
      exit 1
    fi

    update_layer_status "$LAYER" "$STATUS"
    echo "{\"updated\": true, \"layer\": \"$LAYER\", \"status\": \"$STATUS\"}"
    ;;

  # ── --check-all 模式（非阻塞，含校验，默认 brief）──
  --check-all)
    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "frontend-workflow-state.yaml 不存在"}' >&2
      exit 1
    fi

    # 解析 --verbose 选项
    VERBOSE=false
    if [ "${3:-}" = "--verbose" ]; then
      VERBOSE=true
    fi

    tracked=$(get_tracked_layers)
    all_done=true
    has_failed=false

    for layer in $tracked; do
      st=$(get_tracked_status "$layer")
      case "$st" in
        done|coded) ;;
        failed)  has_failed=true; all_done=false ;;
        *)       all_done=false ;;
      esac
    done

    if $all_done; then
      if [ "$VERBOSE" = "true" ]; then
        # --verbose: 完整校验输出
        validation_output=""
        if [ -x "$VALIDATE_SCRIPT" ]; then
          validation_output=$("$VALIDATE_SCRIPT" "$IDEA_DIR" 2>&1 || true)
        fi
        if [ -n "$validation_output" ]; then
          echo "{\"overall\": \"all_done\", \"validation\": $validation_output}"
        else
          echo "{\"overall\": \"all_done\", \"validation\": {}}"
        fi
      else
        # 默认 brief: 调用 validate --summary
        validation_output=""
        if [ -x "$VALIDATE_SCRIPT" ]; then
          validation_output=$("$VALIDATE_SCRIPT" "$IDEA_DIR" --summary 2>&1 || true)
        fi
        if [ -n "$validation_output" ]; then
          echo "{\"overall\": \"all_done\", \"validation\": $validation_output}"
        else
          echo "{\"overall\": \"all_done\", \"validation\": {}}"
        fi
      fi
    elif $has_failed; then
      echo "{\"overall\": \"blocked\"}"
    else
      echo "{\"overall\": \"in_progress\"}"
    fi
    ;;

  # ── --get-status 模式：获取指定层的纯文本状态值（供 SubagentStop hook 使用）──
  --get-status)
    LAYER="${3:?--get-status 需要指定层名}"

    if [ ! -f "$STATE_FILE" ]; then
      exit 1
    fi

    if ! is_tracked "$LAYER"; then
      exit 1
    fi

    get_tracked_status "$LAYER"
    ;;

  # ════════════════════════════════════════════════════
  # ── Task 级命令 ──
  # ════════════════════════════════════════════════════

  # ── --init-tasks 模式：初始化 task 级状态文件 ──
  --init-tasks)
    IDEA_NAME="${3:?--init-tasks 需要指定 idea-name}"
    shift 3
    TASK_SPECS="$*"

    if [ -z "$TASK_SPECS" ]; then
      echo '{"error": "--init-tasks 需要至少一个 task 规格 (task_id:layer:depends:description:file)"}' >&2
      exit 1
    fi

    init_task_state "$IDEA_NAME" $TASK_SPECS
    echo "{\"initialized\": true, \"idea\": \"$IDEA_NAME\", \"task_count\": $(echo "$TASK_SPECS" | wc -w | tr -d ' ')}"
    ;;

  # ── --set-task 模式：设置 task 状态 ──
  --set-task)
    TASK_ID="${3:?--set-task 需要指定 task_id}"
    TASK_STATUS="${4:?--set-task 需要指定状态}"

    case "$TASK_STATUS" in
      pending|designing|designed|confirmed|coding|coded|failed) ;;
      *) echo "{\"error\": \"无效状态: ${TASK_STATUS}\"}" >&2; exit 1 ;;
    esac

    if [ ! -f "$TASK_STATE_FILE" ]; then
      echo '{"error": "frontend-task-workflow-state.yaml 不存在，请先执行 --init-tasks"}' >&2
      exit 1
    fi

    update_task_status "$TASK_ID" "$TASK_STATUS"
    echo "{\"updated\": true, \"task_id\": \"$TASK_ID\", \"status\": \"$TASK_STATUS\"}"
    ;;

  # ── --get-task-status 模式：获取 task 的纯文本状态值 ──
  --get-task-status)
    TASK_ID="${3:?--get-task-status 需要指定 task_id}"

    if [ ! -f "$TASK_STATE_FILE" ]; then
      exit 1
    fi

    get_task_status "$TASK_ID"
    ;;

  # ── --sync-layer-status 模式：从 task 状态同步层级状态到 frontend-workflow-state.yaml ──
  --sync-layer-status)
    if [ ! -f "$TASK_STATE_FILE" ]; then
      echo '{"error": "frontend-task-workflow-state.yaml 不存在"}' >&2
      exit 1
    fi
    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "frontend-workflow-state.yaml 不存在"}' >&2
      exit 1
    fi

    sync_layer_status_from_tasks
    echo "{\"synced\": true}"
    ;;

  # ── --next-tasks 模式：获取下一批可执行的 task ──
  --next-tasks)
    PHASE="${3:-design}"

    if [ ! -f "$TASK_STATE_FILE" ]; then
      echo '{"error": "frontend-task-workflow-state.yaml 不存在"}' >&2
      exit 1
    fi

    next_tasks=$(get_next_executable_tasks "$PHASE")
    if [ -z "$next_tasks" ]; then
      echo '{"next_tasks": [], "count": 0}'
    else
      task_json=""
      count=0
      for tid in $next_tasks; do
        tl=$(get_task_layer "$tid")
        tf=$(get_task_file "$tid")
        td=$(get_task_description "$tid")
        entry="{\"task_id\": \"$tid\", \"layer\": \"$tl\", \"file\": \"$tf\", \"description\": \"$td\"}"
        if [ -z "$task_json" ]; then
          task_json="$entry"
        else
          task_json="$task_json, $entry"
        fi
        count=$((count + 1))
      done
      echo "{\"next_tasks\": [$task_json], \"count\": $count}"
    fi
    ;;

  *)
    echo "未知模式: $MODE" >&2
    echo "用法: frontend-workflow-status.sh <idea-dir> [--init|--set|--check-all|--get-status|--init-tasks|--set-task|--get-task-status|--sync-layer-status|--next-tasks]" >&2
    exit 1
    ;;
esac
