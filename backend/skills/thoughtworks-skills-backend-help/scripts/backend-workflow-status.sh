#!/usr/bin/env bash
# 后端工作流状态管理脚本
# 用法:
#   backend-workflow-status.sh <idea-dir>                          — 查看当前状态（非阻塞）
#   backend-workflow-status.sh <idea-dir> --init <idea-name> <layer1> [layer2...]  — 初始化状态文件
#   backend-workflow-status.sh <idea-dir> --set <layer> <status>   — 设置某层状态
#   backend-workflow-status.sh <idea-dir> --check-upstream <layer> — 非阻塞检查上游是否 ready
#   backend-workflow-status.sh <idea-dir> --check-all              — 非阻塞检查是否全部完成（含校验）
#   backend-workflow-status.sh <idea-dir> --get-status <layer>     — 获取指定层的纯文本状态值
#
# 状态文件: <idea-dir>/workflow-state.yaml
# 状态机: pending → designing → designed → confirmed → coding → coded / failed

set -euo pipefail

IDEA_DIR="${1:?用法: backend-workflow-status.sh <idea-dir> [--init|--set|--check-upstream|--check-all]}"
MODE="${2:-status}"

STATE_FILE="$IDEA_DIR/workflow-state.yaml"
DESIGNS_DIR="$IDEA_DIR/designs"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW="$SCRIPT_DIR/../workflow.yaml"
VALIDATE_SCRIPT="$SCRIPT_DIR/backend-output-validate.sh"

# source 共享库
CORE_LIB="$SCRIPT_DIR/../../../../core/scripts/workflow-lib.sh"
source "$CORE_LIB"

# ── 后端独有函数 ──

get_requires() {
  local layer_id="$1"
  awk -v lid="$layer_id" '
    BEGIN { found=0 }
    $0 ~ "^  - id: " lid "$" { found=1; next }
    found && /^  - id:/ { exit }
    found && /requires:/ { gsub(/.*requires:[[:space:]]*/, ""); gsub(/\[/, ""); gsub(/\]/, ""); gsub(/,/, " "); print; exit }
  ' "$WORKFLOW" | tr -s ' '
}

build_layers_snapshot() {
  local tracked
  tracked=$(get_tracked_layers)
  local snap=""
  for layer in $tracked; do
    local st
    st=$(get_tracked_status "$layer")
    if [ -z "$snap" ]; then
      snap="\"$layer\": \"$st\""
    else
      snap="$snap, \"$layer\": \"$st\""
    fi
  done
  echo "$snap"
}

# ── 状态转换合法性校验 ──

validate_transition() {
  local layer="$1" new_status="$2"
  local current_status
  current_status=$(get_tracked_status "$layer")

  # 如果无当前状态（刚初始化），只允许 pending
  if [ -z "$current_status" ]; then
    return 0
  fi

  # 从 workflow.yaml 的 state-machine.transitions 中验证
  # 简化实现：硬编码合法转换表（与 workflow.yaml state-machine 保持一致）
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

  # ── 默认模式：查看整体状态（非阻塞）──
  status|--status)
    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "workflow-state.yaml 不存在"}' >&2
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
        domain|infr|application|ohs) ;;
        *) echo "{\"error\": \"无效层名: $layer，可选: domain|infr|application|ohs\"}" >&2; exit 1 ;;
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
      echo '{"error": "workflow-state.yaml 不存在，请先执行 --init"}' >&2
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

  # ── --check-upstream 模式（非阻塞）──
  --check-upstream)
    LAYER="${3:?--check-upstream 需要指定层名}"

    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "workflow-state.yaml 不存在"}' >&2
      exit 1
    fi

    requires=$(get_requires "$LAYER")

    # 过滤：只检查在 tracked_layers 中的上游
    wait_for=""
    for req in $requires; do
      req=$(echo "$req" | tr -d ' ')
      [ -z "$req" ] && continue
      if is_tracked "$req"; then
        wait_for="$wait_for $req"
      fi
    done
    wait_for=$(echo "$wait_for" | tr -s ' ' | sed 's/^ //')

    # 无需等待的上游 → 直接 ready
    if [ -z "$wait_for" ]; then
      echo "{\"upstream_ready\": true, \"layer\": \"$LAYER\"}"
      exit 0
    fi

    # 非阻塞检查每个上游的状态
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

  # ── --check-all 模式（非阻塞，含校验）──
  --check-all)
    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "workflow-state.yaml 不存在"}' >&2
      exit 1
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
      # 全部 done → 执行全量校验
      validation_output=""
      if [ -x "$VALIDATE_SCRIPT" ]; then
        validation_output=$("$VALIDATE_SCRIPT" "$IDEA_DIR" 2>&1 || true)
      fi
      if [ -n "$validation_output" ]; then
        echo "{\"overall\": \"all_done\", \"validation\": $validation_output}"
      else
        echo "{\"overall\": \"all_done\", \"validation\": {}}"
      fi
    elif $has_failed; then
      snap=$(build_layers_snapshot)
      echo "{\"overall\": \"blocked\", \"layers\": { $snap }}"
    else
      snap=$(build_layers_snapshot)
      echo "{\"overall\": \"in_progress\", \"layers\": { $snap }}"
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

  *)
    echo "未知模式: $MODE" >&2
    echo "用法: backend-workflow-status.sh <idea-dir> [--init|--set|--check-upstream|--check-all|--get-status]" >&2
    exit 1
    ;;
esac
