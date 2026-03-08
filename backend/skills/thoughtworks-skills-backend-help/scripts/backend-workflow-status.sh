#!/usr/bin/env bash
# 后端工作流状态管理脚本
# 用法:
#   backend-workflow-status.sh <idea-dir>                          — 查看当前状态（非阻塞）
#   backend-workflow-status.sh <idea-dir> --init <idea-name> <layer1> [layer2...]  — 初始化状态文件
#   backend-workflow-status.sh <idea-dir> --set <layer> <status>   — 设置某层状态
#   backend-workflow-status.sh <idea-dir> --check-upstream <layer> — 非阻塞检查上游是否 ready
#   backend-workflow-status.sh <idea-dir> --check-all              — 非阻塞检查是否全部完成（含校验）
#
# 状态文件: <idea-dir>/workflow-state.json
# 状态机: pending → designing → designed → coding → coded / failed
#
# 重要变更（v2）:
#   - 移除 --wait-upstream / --wait-all 的阻塞轮询模式（与 Claude Code Bash 120s 超时不兼容）
#   - 新增 --init 模式创建初始状态文件
#   - 新增 --check-upstream / --check-all 非阻塞检查模式
#   - 新增 flock 文件锁防止并发写入竞态
#   - 简化状态机：移除 waiting/blocked 中间态，由主 agent DAG 编排保证顺序
#
# 重要变更（v3）:
#   - 精细化状态：pending → designing → designed → coding → coded / failed
#   - 向后兼容：--check-upstream / --check-all 中 done 与 coded 等价
#   - --set 不再接受 in_progress / done（旧状态值被拒绝）

set -euo pipefail

IDEA_DIR="${1:?用法: backend-workflow-status.sh <idea-dir> [--init|--set|--check-upstream|--check-all]}"
MODE="${2:-status}"

STATE_FILE="$IDEA_DIR/workflow-state.json"
DESIGNS_DIR="$IDEA_DIR/designs"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW="$SCRIPT_DIR/../workflow.yaml"
VALIDATE_SCRIPT="$SCRIPT_DIR/backend-output-validate.sh"
LOCK_FILE="${STATE_FILE}.lock"

# ── 文件锁（防止并发写入竞态）──

locked_write() {
  local content="$1"
  local tmp_file="${STATE_FILE}.tmp.$$"
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$content" > "$tmp_file"
  # 使用 flock 保证原子性（macOS 需要 brew install flock，降级为 mkdir 原子锁）
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

# ── JSON 辅助函数（纯 bash + awk，不依赖 jq/python）──

read_idea() {
  if [ ! -f "$STATE_FILE" ]; then
    echo ""
    return
  fi
  sed -n 's/.*"idea"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_FILE" | head -1
}

get_tracked_layers() {
  if [ ! -f "$STATE_FILE" ]; then
    return
  fi
  grep -oE '"(domain|infr|application|ohs)"[[:space:]]*:' "$STATE_FILE" | sed 's/"//g;s/[[:space:]]*://g'
}

get_tracked_status() {
  local layer="$1"
  if [ ! -f "$STATE_FILE" ]; then
    echo ""
    return
  fi
  awk -v layer="$layer" '
    BEGIN { in_tracked=0; in_layer=0 }
    /"tracked_layers"/ { in_tracked=1; next }
    in_tracked && !in_layer {
      if ($0 ~ "\"" layer "\"[[:space:]]*:") {
        in_layer=1
      }
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
  if [ ! -f "$STATE_FILE" ]; then
    echo ""
    return
  fi
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

get_requires() {
  local layer_id="$1"
  awk -v lid="$layer_id" '
    BEGIN { found=0 }
    $0 ~ "^  - id: " lid "$" { found=1; next }
    found && /^  - id:/ { exit }
    found && /requires:/ { gsub(/.*requires:[[:space:]]*/, ""); gsub(/\[/, ""); gsub(/\]/, ""); gsub(/,/, " "); print; exit }
  ' "$WORKFLOW" | tr -s ' '
}

is_tracked() {
  local layer="$1"
  local tracked
  tracked=$(get_tracked_layers)
  for t in $tracked; do
    if [ "$t" = "$layer" ]; then
      return 0
    fi
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
        if [ -z "$items" ]; then
          items="\"$p\""
        else
          items="$items, \"$p\""
        fi
      done
      [ -n "$items" ] && files_arr="[$items]"
    fi

    local entry="    \"$layer\": {\n      \"status\": \"$st\",\n      \"files\": $files_arr\n    }"
    if [ -z "$layers_json" ]; then
      layers_json="$entry"
    else
      layers_json="$layers_json,\n$entry"
    fi
  done

  local content
  content=$(printf "{\n  \"idea\": \"$idea\",\n  \"tracked_layers\": {\n$layers_json\n  }\n}")
  locked_write "$content"
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

# ── 模式分发 ──

case "$MODE" in

  # ── 默认模式：查看整体状态（非阻塞）──
  status|--status)
    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "workflow-state.json 不存在"}' >&2
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
      files_csv=$(get_tracked_files "$layer")

      files_arr="[]"
      if [ -n "$files_csv" ]; then
        items=""
        IFS=',' read -ra parts <<< "$files_csv"
        for p in "${parts[@]}"; do
          p=$(echo "$p" | tr -d ' ')
          [ -z "$p" ] && continue
          if [ -z "$items" ]; then
            items="\"$p\""
          else
            items="$items, \"$p\""
          fi
        done
        [ -n "$items" ] && files_arr="[$items]"
      fi

      entry="\"$layer\": { \"status\": \"$st\", \"files\": $files_arr }"
      if [ -z "$layers_json" ]; then
        layers_json="$entry"
      else
        layers_json="$layers_json, $entry"
      fi

      case "$st" in
        done|coded)   has_done=true ;;
        designing|coding)  has_in_progress=true; all_done=false; all_pending=false ;;
        designed)     all_done=false; all_pending=false ;;
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

    layers_json=""
    for layer in $LAYERS; do
      case "$layer" in
        domain|infr|application|ohs) ;;
        *) echo "{\"error\": \"无效层名: $layer，可选: domain|infr|application|ohs\"}" >&2; exit 1 ;;
      esac
      entry="    \"$layer\": {\n      \"status\": \"pending\",\n      \"files\": []\n    }"
      if [ -z "$layers_json" ]; then
        layers_json="$entry"
      else
        layers_json="$layers_json,\n$entry"
      fi
    done

    mkdir -p "$(dirname "$STATE_FILE")"
    init_content=$(printf "{\n  \"idea\": \"$IDEA_NAME\",\n  \"tracked_layers\": {\n$layers_json\n  }\n}")
    locked_write "$init_content"
    echo "{\"initialized\": true, \"idea\": \"$IDEA_NAME\", \"layers\": [$(echo "$LAYERS" | sed 's/ /", "/g;s/^/"/;s/$/"/' )]}"
    ;;

  # ── --set 模式 ──
  --set)
    LAYER="${3:?--set 需要指定层名}"
    STATUS="${4:?--set 需要指定状态 (pending|designing|designed|coding|coded|failed)}"

    case "$STATUS" in
      pending|designing|designed|coding|coded|failed) ;;
      *) echo "{\"error\": \"无效状态: ${STATUS}，可选: pending|designing|designed|coding|coded|failed\"}" >&2; exit 1 ;;
    esac

    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "workflow-state.json 不存在，请先执行 --init"}' >&2
      exit 1
    fi

    if ! is_tracked "$LAYER"; then
      echo "{\"error\": \"层 $LAYER 不在 tracked_layers 中\"}" >&2
      exit 1
    fi

    update_layer_status "$LAYER" "$STATUS"
    echo "{\"updated\": true, \"layer\": \"$LAYER\", \"status\": \"$STATUS\"}"
    ;;

  # ── --check-upstream 模式（非阻塞）──
  --check-upstream)
    LAYER="${3:?--check-upstream 需要指定层名}"

    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "workflow-state.json 不存在"}' >&2
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
      echo '{"error": "workflow-state.json 不存在"}' >&2
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

  *)
    echo "未知模式: $MODE" >&2
    echo "用法: backend-workflow-status.sh <idea-dir> [--init|--set|--check-upstream|--check-all]" >&2
    exit 1
    ;;
esac
