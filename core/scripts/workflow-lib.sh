#!/usr/bin/env bash
# 工作流脚本共享库 — backend/frontend workflow-status 脚本共用
# 使用方式: source 本文件，确保调用前设置 STATE_FILE 变量

# ── 文件锁（防止并发写入竞态）──

locked_write() {
  local content="$1"
  local tmp_file="${STATE_FILE}.tmp.$$"
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$content" > "$tmp_file"
  if command -v flock >/dev/null 2>&1; then
    (
      flock -x 200
      mv "$tmp_file" "$STATE_FILE"
    ) 200>"${STATE_FILE}.lock"
  else
    # macOS fallback: mkdir 原子锁
    local lock_dir="${STATE_FILE}.lockdir"
    local max_wait=30
    local waited=0
    while ! mkdir "$lock_dir" 2>/dev/null; do
      sleep 0.1
      waited=$((waited + 1))
      if [ "$waited" -ge "$max_wait" ]; then
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
  if [ ! -f "$STATE_FILE" ]; then echo ""; return; fi
  sed -n 's/.*"idea"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_FILE" | head -1
}

# get_tracked_layers 需要调用者定义 LAYER_PATTERN 变量
# 后端: LAYER_PATTERN="domain|infr|application|ohs"
# 前端: LAYER_PATTERN="frontend-architecture|frontend-components|frontend-checklist"
get_tracked_layers() {
  if [ ! -f "$STATE_FILE" ]; then return; fi
  grep -oE "\"(${LAYER_PATTERN})\"[[:space:]]*:" "$STATE_FILE" | sed 's/"//g;s/[[:space:]]*://g'
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

# ── status-status.sh 共享函数 ──

# 从 YAML frontmatter 提取字段值
extract_field() {
  local file="$1" field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/"
}

# 从 frontmatter 提取 depends_on 数组
extract_depends() {
  local file="$1"
  local deps
  deps=$(sed -n '/^---$/,/^---$/p' "$file" | grep "^depends_on:" | head -1 | sed 's/^depends_on:[[:space:]]*//')
  echo "$deps" | sed 's/\[//;s/\]//;s/,/ /g' | tr -s ' '
}

# 从 workflow.yaml 获取层的 phase（需要调用者设置 WORKFLOW 变量）
get_layer_phase() {
  local layer_id="$1"
  awk -v lid="$layer_id" '
    BEGIN { found=0 }
    $0 ~ "^  - id: " lid "$" { found=1; next }
    found && /^  - id:/ { exit }
    found && /phase:/ { gsub(/.*phase:[[:space:]]*/, ""); print; exit }
  ' "$WORKFLOW"
}

# 从 workflow-state.json 读取某层的工作流状态（需要调用者设置 STATE_FILE 变量）
get_workflow_status() {
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
