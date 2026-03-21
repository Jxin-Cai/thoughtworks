#!/usr/bin/env bash
# 前端工作流状态管理脚本
# 用法:
#   frontend-workflow-status.sh <idea-dir>                          — 查看当前状态
#   frontend-workflow-status.sh <idea-dir> --init <idea-name> <layer1> [layer2...]  — 初始化
#   frontend-workflow-status.sh <idea-dir> --set <layer> <status>   — 设置某层状态
#   frontend-workflow-status.sh <idea-dir> --check-all              — 非阻塞检查是否全部完成

set -euo pipefail

IDEA_DIR="${1:?用法: frontend-workflow-status.sh <idea-dir> [--init|--set|--check-all]}"
MODE="${2:-status}"

STATE_FILE="$IDEA_DIR/frontend-workflow-state.json"
LAYER_PATTERN="frontend-architecture|frontend-components|frontend-checklist"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATE_SCRIPT="$SCRIPT_DIR/frontend-output-validate.sh"

# source 共享库
CORE_LIB="$SCRIPT_DIR/../../../../core/scripts/workflow-lib.sh"
source "$CORE_LIB"

case "$MODE" in

  status|--status)
    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "frontend-workflow-state.json 不存在"}' >&2
      exit 1
    fi
    idea=$(read_idea)
    tracked=$(get_tracked_layers)
    layers_json=""
    all_done=true
    for layer in $tracked; do
      st=$(get_tracked_status "$layer")
      files_csv=$(get_tracked_files "$layer")
      files_arr="[]"
      if [ -n "$files_csv" ]; then
        items=""
        IFS=',' read -ra parts <<< "$files_csv"
        for p in "${parts[@]}"; do
          p=$(echo "$p" | tr -d ' ')
          [ -z "$p" ] && continue
          if [ -z "$items" ]; then items="\"$p\""; else items="$items, \"$p\""; fi
        done
        [ -n "$items" ] && files_arr="[$items]"
      fi
      entry="\"$layer\": { \"status\": \"$st\", \"files\": $files_arr }"
      if [ -z "$layers_json" ]; then layers_json="$entry"; else layers_json="$layers_json, $entry"; fi
      case "$st" in
        done|coded) ;;
        *) all_done=false ;;
      esac
    done
    if $all_done && [ -n "$tracked" ]; then overall="all_done"; else overall="in_progress"; fi
    echo "{ \"idea\": \"$idea\", \"tracked_layers\": { $layers_json }, \"overall\": \"$overall\" }"
    ;;

  --init)
    IDEA_NAME="${3:?--init 需要指定 idea-name}"
    shift 3
    LAYERS="$*"
    if [ -z "$LAYERS" ]; then
      echo '{"error": "--init 需要至少一个层名"}' >&2
      exit 1
    fi
    layers_json=""
    for layer in $LAYERS; do
      case "$layer" in
        frontend-architecture|frontend-components|frontend-checklist) ;;
        *) echo "{\"error\": \"无效层名: $layer，可选: frontend-architecture, frontend-components, frontend-checklist\"}" >&2; exit 1 ;;
      esac
      entry="    \"$layer\": {\n      \"status\": \"pending\",\n      \"files\": []\n    }"
      if [ -z "$layers_json" ]; then layers_json="$entry"; else layers_json="$layers_json,\n$entry"; fi
    done
    mkdir -p "$(dirname "$STATE_FILE")"
    init_content=$(printf "{\n  \"idea\": \"$IDEA_NAME\",\n  \"tracked_layers\": {\n$layers_json\n  }\n}")
    locked_write "$init_content"
    echo "{\"initialized\": true, \"idea\": \"$IDEA_NAME\", \"layers\": [$(echo "$LAYERS" | sed 's/ /", "/g;s/^/"/;s/$/"/' )]}"
    ;;

  --set)
    LAYER="${3:?--set 需要指定层名}"
    STATUS="${4:?--set 需要指定状态 (pending|designing|designed|confirmed|coding|coded|failed)}"
    case "$STATUS" in
      pending|designing|designed|confirmed|coding|coded|failed) ;;
      *) echo "{\"error\": \"无效状态: $STATUS\"}" >&2; exit 1 ;;
    esac
    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "frontend-workflow-state.json 不存在，请先执行 --init"}' >&2
      exit 1
    fi
    if ! is_tracked "$LAYER"; then
      echo "{\"error\": \"层 $LAYER 不在 tracked_layers 中\"}" >&2
      exit 1
    fi
    update_layer_status "$LAYER" "$STATUS"
    echo "{\"updated\": true, \"layer\": \"$LAYER\", \"status\": \"$STATUS\"}"
    ;;

  --check-all)
    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "frontend-workflow-state.json 不存在"}' >&2
      exit 1
    fi
    tracked=$(get_tracked_layers)
    all_done=true
    for layer in $tracked; do
      st=$(get_tracked_status "$layer")
      case "$st" in
        done|coded) ;;
        *) all_done=false ;;
      esac
    done
    if $all_done; then
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
      echo "{\"overall\": \"in_progress\"}"
    fi
    ;;

  *)
    echo "未知模式: $MODE" >&2
    exit 1
    ;;
esac
