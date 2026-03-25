#!/usr/bin/env bash
# 统一工作流状态管理脚本 — backend/frontend 共用
#
# 调用方式:
#   直接调用（需设置 STACK 环境变量）:
#     STACK=backend workflow-status.sh <idea-dir> <command> [args...]
#     STACK=frontend workflow-status.sh <idea-dir> <command> [args...]
#
#   或通过薄包装脚本调用（推荐，向后兼容）:
#     backend-workflow-status.sh <idea-dir> <command> [args...]
#     frontend-workflow-status.sh <idea-dir> <command> [args...]
#
# 命令:
#   (无参数)                                    — 查看当前状态
#   --init <idea-name> <layer1> [layer2...]    — 初始化状态文件
#   --set <layer> <status>                     — 设置某层状态
#   --check-upstream <layer>                   — 非阻塞检查上游是否 ready（仅 backend）
#   --check-all [--verbose] [--layer <layer>]   — 非阻塞检查是否全部完成（含校验）
#   --get-status <layer>                       — 获取指定层的纯文本状态值
#   --init-tasks <idea-name> <task_spec>...    — 初始化 task 级状态文件
#   --set-task <task_id> <status>              — 设置 task 状态
#   --start-task <task_id>                     — 原子启动 task（confirmed→coding + 同步层级）
#   --finish-task <task_id> <coded|failed>     — 原子完成 task（coding→coded|failed + 同步层级）
#   --get-task-status <task_id>                — 获取 task 的纯文本状态值
#   --sync-layer-status                        — 从 task 状态同步层级状态
#   --next-tasks <design|code>                 — 获取下一批可执行 task
#
# 状态机: pending → designing → designed → confirmed → coding → coded / failed

set -euo pipefail

IDEA_DIR="${1:?用法: workflow-status.sh <idea-dir> [command] [args...]}"
MODE="${2:-status}"

# ── STACK 差异化配置 ──

STACK="${STACK:?需要设置 STACK 环境变量 (backend|frontend)}"

case "$STACK" in
  backend)
    STATE_FILE="$IDEA_DIR/workflow-state.yaml"
    TASK_STATE_FILE="$IDEA_DIR/task-workflow-state.yaml"
    VALID_LAYERS="domain|infr|application|ohs"
    VALID_LAYERS_DISPLAY="domain|infr|application|ohs"
    ;;
  frontend)
    STATE_FILE="$IDEA_DIR/frontend-workflow-state.yaml"
    TASK_STATE_FILE="$IDEA_DIR/frontend-task-workflow-state.yaml"
    VALID_LAYERS="frontend-architecture|frontend-components|frontend-checklist"
    VALID_LAYERS_DISPLAY="frontend-architecture, frontend-components, frontend-checklist"
    ;;
  *)
    echo "{\"error\": \"无效 STACK: ${STACK}, 可选: backend|frontend\"}" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# 支持从 core/scripts 直接调用，或通过 symlink/薄包装调用
if [ -f "$SCRIPT_DIR/workflow-lib.sh" ]; then
  CORE_LIB="$SCRIPT_DIR/workflow-lib.sh"
else
  CORE_LIB="$SCRIPT_DIR/../../../../core/scripts/workflow-lib.sh"
fi
source "$CORE_LIB"

# 定位 validate 脚本和 workflow.yaml（通过 CALLER_SCRIPT_DIR 环境变量传入）
CALLER_DIR="${CALLER_SCRIPT_DIR:-$SCRIPT_DIR}"
if [ "$STACK" = "backend" ]; then
  VALIDATE_SCRIPT="${CALLER_DIR}/backend-output-validate.sh"
  WORKFLOW="${CALLER_DIR}/../workflow.yaml"
else
  VALIDATE_SCRIPT="${CALLER_DIR}/frontend-output-validate.sh"
  WORKFLOW="${CALLER_DIR}/../workflow.yaml"
fi

# ── 后端独有函数 ──

get_requires() {
  local layer_id="$1"
  if [ ! -f "$WORKFLOW" ]; then return; fi
  awk -v lid="$layer_id" '
    BEGIN { found=0 }
    $0 ~ "^  - id: " lid "$" { found=1; next }
    found && /^  - id:/ { exit }
    found && /requires:/ { gsub(/.*requires:[[:space:]]*/, ""); gsub(/\[/, ""); gsub(/\]/, ""); gsub(/,/, " "); print; exit }
  ' "$WORKFLOW" | tr -s ' '
}

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

  # ── 默认模式：查看整体状态 ──
  status|--status)
    if [ ! -f "$STATE_FILE" ]; then
      echo "{\"error\": \"${STATE_FILE##*/} 不存在\"}" >&2
      exit 1
    fi

    idea=$(read_idea)
    tracked=$(get_tracked_layers)

    has_done=false
    has_in_progress=false
    has_failed=false
    has_pending=false
    all_done=true
    all_pending=true

    layers_json=""
    for layer in $tracked; do
      st=$(get_tracked_status "$layer")

      entry="\"$layer\": { \"status\": \"$st\" }"
      if [ -z "$layers_json" ]; then
        layers_json="$entry"
      else
        layers_json="$layers_json, $entry"
      fi

      case "$st" in
        done|coded)   has_done=true ;;
        designing|coding)  has_in_progress=true; all_done=false; all_pending=false ;;
        designed|confirmed)     all_done=false; all_pending=false ;;
        failed)       has_failed=true; all_done=false; all_pending=false ;;
        pending)      has_pending=true; all_done=false ;;
        *)            all_done=false; all_pending=false ;;
      esac
    done

    if $all_done && [ -n "$tracked" ]; then
      overall="all_done"
    elif $has_failed; then
      overall="blocked"
    elif $has_in_progress; then
      overall="in_progress"
    elif $all_pending; then
      overall="not_started"
    else
      overall="in_progress"
    fi

    echo "{ \"idea\": \"$idea\", \"tracked_layers\": { $layers_json }, \"overall\": \"$overall\" }"
    ;;

  # ── --init 模式 ──
  --init)
    IDEA_NAME="${3:?--init 需要指定 idea-name}"
    shift 3
    LAYERS="$*"

    if [ -z "$LAYERS" ]; then
      echo '{"error": "--init 需要至少一个层名"}' >&2
      exit 1
    fi

    for layer in $LAYERS; do
      if ! echo "$layer" | grep -qE "^(${VALID_LAYERS})$"; then
        echo "{\"error\": \"无效层名: ${layer}, 可选: ${VALID_LAYERS_DISPLAY}\"}" >&2
        exit 1
      fi
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
      echo "{\"error\": \"${STATE_FILE##*/} 不存在，请先执行 --init\"}" >&2
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

  # ── --check-upstream 模式（仅 backend 有效）──
  --check-upstream)
    if [ "$STACK" != "backend" ]; then
      echo "{\"error\": \"--check-upstream 仅 backend 支持\"}" >&2
      exit 1
    fi

    LAYER="${3:?--check-upstream 需要指定层名}"

    if [ ! -f "$STATE_FILE" ]; then
      echo "{\"error\": \"${STATE_FILE##*/} 不存在\"}" >&2
      exit 1
    fi

    requires=$(get_requires "$LAYER")

    wait_for=""
    for req in $requires; do
      req=$(echo "$req" | tr -d ' ')
      [ -z "$req" ] && continue
      if is_tracked "$req"; then
        wait_for="$wait_for $req"
      fi
    done
    wait_for=$(echo "$wait_for" | tr -s ' ' | sed 's/^ //')

    if [ -z "$wait_for" ]; then
      echo "{\"upstream_ready\": true, \"layer\": \"$LAYER\"}"
      exit 0
    fi

    all_upstream_done=true
    failed_layer=""
    pending_layers=""

    for req in $wait_for; do
      st=$(get_tracked_status "$req")
      case "$st" in
        done|coded) ;;
        failed)
          failed_layer="$req"
          break
          ;;
        *)
          all_upstream_done=false
          if [ -z "$pending_layers" ]; then
            pending_layers="\"$req\""
          else
            pending_layers="$pending_layers, \"$req\""
          fi
          ;;
      esac
    done

    if [ -n "$failed_layer" ]; then
      echo "{\"upstream_ready\": false, \"layer\": \"$LAYER\", \"reason\": \"upstream $failed_layer failed\"}"
      exit 0
    fi

    if $all_upstream_done; then
      echo "{\"upstream_ready\": true, \"layer\": \"$LAYER\"}"
    else
      echo "{\"upstream_ready\": false, \"layer\": \"$LAYER\", \"waiting_for\": [$pending_layers]}"
    fi
    ;;

  # ── --check-all 模式 ──
  --check-all)
    if [ ! -f "$STATE_FILE" ]; then
      echo "{\"error\": \"${STATE_FILE##*/} 不存在\"}" >&2
      exit 1
    fi

    VERBOSE=false
    CHECK_LAYER=""
    shift 2  # 跳过 idea-dir 和 --check-all
    while [ $# -gt 0 ]; do
      case "$1" in
        --verbose) VERBOSE=true; shift ;;
        --layer) CHECK_LAYER="$2"; shift 2 ;;
        *) shift ;;
      esac
    done

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
      validation_output=""
      if [ -x "$VALIDATE_SCRIPT" ]; then
        validate_args=""
        if [ -n "$CHECK_LAYER" ]; then
          validate_args="--layer $CHECK_LAYER"
        fi
        if [ "$VERBOSE" = "true" ]; then
          validation_output=$("$VALIDATE_SCRIPT" "$IDEA_DIR" $validate_args 2>&1 || true)
        else
          validation_output=$("$VALIDATE_SCRIPT" "$IDEA_DIR" $validate_args --summary 2>&1 || true)
        fi
      fi
      if [ -n "$validation_output" ]; then
        echo "{\"overall\": \"all_done\", \"validation\": $validation_output}"
      else
        echo "{\"overall\": \"all_done\", \"validation\": {}}"
      fi
    elif $has_failed; then
      echo "{\"overall\": \"blocked\"}"
    else
      echo "{\"overall\": \"in_progress\"}"
    fi
    ;;

  # ── --get-status 模式 ──
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

  --set-task)
    TASK_ID="${3:?--set-task 需要指定 task_id}"
    TASK_STATUS="${4:?--set-task 需要指定状态}"

    case "$TASK_STATUS" in
      pending|designing|designed|confirmed|coding|coded|failed) ;;
      *) echo "{\"error\": \"无效状态: ${TASK_STATUS}\"}" >&2; exit 1 ;;
    esac

    if [ ! -f "$TASK_STATE_FILE" ]; then
      echo "{\"error\": \"${TASK_STATE_FILE##*/} 不存在，请先执行 --init-tasks\"}" >&2
      exit 1
    fi

    update_task_status "$TASK_ID" "$TASK_STATUS"
    echo "{\"updated\": true, \"task_id\": \"$TASK_ID\", \"status\": \"$TASK_STATUS\"}"
    ;;

  --start-task)
    TASK_ID="${3:?--start-task 需要指定 task_id}"

    if [ ! -f "$TASK_STATE_FILE" ]; then
      echo "{\"error\": \"${TASK_STATE_FILE##*/} 不存在，请先执行 --init-tasks\"}" >&2
      exit 1
    fi
    if [ ! -f "$STATE_FILE" ]; then
      echo "{\"error\": \"${STATE_FILE##*/} 不存在\"}" >&2
      exit 1
    fi

    start_task "$TASK_ID"
    echo "{\"started\": true, \"task_id\": \"$TASK_ID\", \"status\": \"coding\"}"
    ;;

  --finish-task)
    TASK_ID="${3:?--finish-task 需要指定 task_id}"
    TASK_STATUS="${4:?--finish-task 需要指定目标状态 (coded|failed)}"

    if [ ! -f "$TASK_STATE_FILE" ]; then
      echo "{\"error\": \"${TASK_STATE_FILE##*/} 不存在\"}" >&2
      exit 1
    fi
    if [ ! -f "$STATE_FILE" ]; then
      echo "{\"error\": \"${STATE_FILE##*/} 不存在\"}" >&2
      exit 1
    fi

    finish_task "$TASK_ID" "$TASK_STATUS"
    echo "{\"finished\": true, \"task_id\": \"$TASK_ID\", \"status\": \"$TASK_STATUS\"}"
    ;;

  --get-task-status)
    TASK_ID="${3:?--get-task-status 需要指定 task_id}"

    if [ ! -f "$TASK_STATE_FILE" ]; then
      exit 1
    fi

    get_task_status "$TASK_ID"
    ;;

  --sync-layer-status)
    if [ ! -f "$TASK_STATE_FILE" ]; then
      echo "{\"error\": \"${TASK_STATE_FILE##*/} 不存在\"}" >&2
      exit 1
    fi
    if [ ! -f "$STATE_FILE" ]; then
      echo "{\"error\": \"${STATE_FILE##*/} 不存在\"}" >&2
      exit 1
    fi

    sync_layer_status_from_tasks
    echo "{\"synced\": true}"
    ;;

  --next-tasks)
    PHASE="${3:-design}"

    if [ ! -f "$TASK_STATE_FILE" ]; then
      echo "{\"error\": \"${TASK_STATE_FILE##*/} 不存在\"}" >&2
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
    echo "用法: workflow-status.sh <idea-dir> [command] [args...]" >&2
    exit 1
    ;;
esac
