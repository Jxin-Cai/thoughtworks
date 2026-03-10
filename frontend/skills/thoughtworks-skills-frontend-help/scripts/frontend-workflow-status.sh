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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATE_SCRIPT="$SCRIPT_DIR/frontend-output-validate.sh"
LOCK_FILE="${STATE_FILE}.lock"

locked_write() {
  local content="$1"
  local tmp_file="${STATE_FILE}.tmp.$$"
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$content" > "$tmp_file"
  if command -v flock >/dev/null 2>&1; then
    (
      flock -x 200
      mv "$tmp_file" "$STATE_FILE"
    ) 200>"$LOCK_FILE"
  else
    # macOS fallback: mkdir 原子锁
    local lock_dir="${STATE_FILE}.lockdir"
    local max_wait=30
    local waited=0
    while ! mkdir "$lock_dir" 2>/dev/null; do
      sleep 0.1
      waited=$((waited + 1))
      if [ "$waited" -ge "$max_wait" ]; then
        # 超时强制获取锁（清理遗留锁）
        rm -rf "$lock_dir"
        mkdir "$lock_dir" 2>/dev/null || true
        break
      fi
    done
    mv "$tmp_file" "$STATE_FILE"
    rmdir "$lock_dir" 2>/dev/null || true
  fi
}

read_idea() {
  if [ ! -f "$STATE_FILE" ]; then echo ""; return; fi
  sed -n 's/.*"idea"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_FILE" | head -1
}

get_tracked_layers() {
  if [ ! -f "$STATE_FILE" ]; then return; fi
  grep -oE '"(frontend)"[[:space:]]*:' "$STATE_FILE" | sed 's/"//g;s/[[:space:]]*://g'
}

get_tracked_status() {
  local layer="$1"
  if [ ! -f "$STATE_FILE" ]; then echo ""; return; fi
  awk -v layer="$layer" '
    BEGIN { in_tracked=0; in_layer=0 }
    /"tracked_layers"/ { in_tracked=1; next }
    in_tracked && !in_layer {
      if ($0 ~ "\"" layer "\"[[:space:]]*:") { in_layer=1 }
    }
    in_tracked && in_layer {
      if ($0 ~ /"status"/) {
        gsub(/.*"status"[[:space:]]*:[[:space:]]*"/, "")
        gsub(/".*/, "")
        print
        exit
      }
    }
  ' "$STATE_FILE"
}

get_tracked_files() {
  local layer="$1"
  if [ ! -f "$STATE_FILE" ]; then echo ""; return; fi
  awk -v layer="$layer" '
    BEGIN { in_tracked=0; in_layer=0; in_files=0 }
    /"tracked_layers"/ { in_tracked=1; next }
    in_tracked && !in_layer {
      if ($0 ~ "\"" layer "\"[[:space:]]*:") { in_layer=1 }
    }
    in_tracked && in_layer {
      if ($0 ~ /"files"/) {
        in_files=1
        line=$0
        gsub(/.*"files"[[:space:]]*:[[:space:]]*\[/, "", line)
        gsub(/\].*/, "", line)
        gsub(/"/, "", line)
        gsub(/[[:space:]]/, "", line)
        if (line != "") print line
        if ($0 ~ /\]/) { in_files=0 }
        next
      }
      if (in_files) {
        if ($0 ~ /\]/) { in_files=0; next }
        line=$0
        gsub(/"/, "", line)
        gsub(/[[:space:]]/, "", line)
        gsub(/,/, "", line)
        if (line != "") print line
      }
    }
  ' "$STATE_FILE" | paste -sd',' -
}

is_tracked() {
  local layer="$1"
  local tracked
  tracked=$(get_tracked_layers)
  for t in $tracked; do
    if [ "$t" = "$layer" ]; then return 0; fi
  done
  return 1
}

update_layer_status() {
  local target_layer="$1"
  local new_status="$2"
  local idea
  idea=$(read_idea)
  local tracked_layers
  tracked_layers=$(get_tracked_layers)

  local layers_json=""
  for layer in $tracked_layers; do
    local st files_csv
    if [ "$layer" = "$target_layer" ]; then
      st="$new_status"
    else
      st=$(get_tracked_status "$layer")
    fi
    files_csv=$(get_tracked_files "$layer")

    local files_arr="[]"
    if [ -n "$files_csv" ]; then
      local items=""
      IFS=',' read -ra parts <<< "$files_csv"
      for p in "${parts[@]}"; do
        p=$(echo "$p" | tr -d ' ')
        [ -z "$p" ] && continue
        if [ -z "$items" ]; then items="\"$p\""; else items="$items, \"$p\""; fi
      done
      [ -n "$items" ] && files_arr="[$items]"
    fi

    local entry="    \"$layer\": {\n      \"status\": \"$st\",\n      \"files\": $files_arr\n    }"
    if [ -z "$layers_json" ]; then layers_json="$entry"; else layers_json="$layers_json,\n$entry"; fi
  done

  local content
  content=$(printf "{\n  \"idea\": \"$idea\",\n  \"tracked_layers\": {\n$layers_json\n  }\n}")
  locked_write "$content"
}

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
        frontend) ;;
        *) echo "{\"error\": \"无效层名: $layer，可选: frontend\"}" >&2; exit 1 ;;
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
