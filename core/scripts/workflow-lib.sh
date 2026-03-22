#!/usr/bin/env bash
# 工作流脚本共享库 — backend/frontend workflow-status 脚本共用
# 使用方式: source 本文件，确保调用前设置 STATE_FILE 变量
#
# 状态文件格式 (YAML):
#   idea: user-management
#   layers:
#     domain: coded
#     infr: coding
#     application: pending
#     ohs: pending

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

# ── YAML 读取函数 ──

read_idea() {
  if [ ! -f "$STATE_FILE" ]; then echo ""; return; fi
  grep "^idea:" "$STATE_FILE" | head -1 | sed 's/^idea:[[:space:]]*//'
}

get_tracked_layers() {
  if [ ! -f "$STATE_FILE" ]; then return; fi
  sed -n '/^layers:/,/^[^ ]/p' "$STATE_FILE" | grep '^  [a-zA-Z]' | sed 's/:.*//' | tr -d ' '
}

get_tracked_status() {
  local layer="$1"
  if [ ! -f "$STATE_FILE" ]; then echo ""; return; fi
  sed -n '/^layers:/,/^[^ ]/p' "$STATE_FILE" | grep "^  ${layer}:" | head -1 | sed "s/^  ${layer}:[[:space:]]*//"
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
  if [ ! -f "$STATE_FILE" ]; then return 1; fi
  # sed 原地替换（macOS 兼容）
  sed -i.bak "s/^  ${target_layer}:.*$/  ${target_layer}: ${new_status}/" "$STATE_FILE"
  rm -f "${STATE_FILE}.bak"
}

init_state() {
  local idea="$1"; shift
  local content
  content=$(printf "idea: %s\nlayers:" "$idea")
  for layer in "$@"; do
    content=$(printf "%s\n  %s: pending" "$content" "$layer")
  done
  locked_write "$content"
}

# ── 设计文件 frontmatter 辅助函数 ──

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

# 从 workflow-state.yaml 读取某层的工作流状态（get_tracked_status 的别名，兼容旧调用）
get_workflow_status() {
  get_tracked_status "$1"
}
