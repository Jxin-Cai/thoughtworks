#!/usr/bin/env bash
# 工作流脚本共享库 — backend/frontend workflow-status 脚本共用
# 使用方式: source 本文件，确保调用前设置 STATE_FILE 变量
#
# 层级状态文件格式 (STATE_FILE, YAML):
#   idea: user-management
#   layers:
#     domain: coded
#     infr: coding
#     application: pending
#     ohs: pending
#
# Task 级状态文件格式 (TASK_STATE_FILE, YAML):
#   idea: user-management
#   tasks:
#     domain-001:
#       layer: domain
#       status: coded
#       depends_on: []
#       description: "Order 聚合"
#       file: domain/001-order-aggregate.md
#   execution_order:
#     parallel_groups:
#       - group: 1
#         tasks: [domain-001, domain-002]

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

# ════════════════════════════════════════════════════
# ── Task 级状态函数 ──
# 调用前需设置 TASK_STATE_FILE 变量指向 task-workflow-state.yaml
# ════════════════════════════════════════════════════

# 带锁写入 task 状态文件
locked_write_task() {
  local content="$1"
  local tmp_file="${TASK_STATE_FILE}.tmp.$$"
  mkdir -p "$(dirname "$TASK_STATE_FILE")"
  printf '%s\n' "$content" > "$tmp_file"
  if command -v flock >/dev/null 2>&1; then
    (
      flock -x 200
      mv "$tmp_file" "$TASK_STATE_FILE"
    ) 200>"${TASK_STATE_FILE}.lock"
  else
    local lock_dir="${TASK_STATE_FILE}.lockdir"
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
    mv "$tmp_file" "$TASK_STATE_FILE"
    rmdir "$lock_dir" 2>/dev/null || true
  fi
}

# 获取所有 task id 列表
get_task_ids() {
  if [ ! -f "$TASK_STATE_FILE" ]; then return; fi
  # 匹配 tasks: 区块下缩进2空格的顶层 key（task_id），排除子字段
  awk '
    /^tasks:/ { in_tasks=1; next }
    /^[^ ]/ && !/^tasks:/ { in_tasks=0 }
    in_tasks && /^  [a-zA-Z]/ && !/^    / {
      sub(/:.*/, "")
      gsub(/^[[:space:]]+/, "")
      print
    }
  ' "$TASK_STATE_FILE"
}

# 获取指定 task 的某个字段值
_get_task_field() {
  local task_id="$1" field="$2"
  if [ ! -f "$TASK_STATE_FILE" ]; then echo ""; return; fi
  awk -v tid="$task_id" -v fld="$field" '
    /^tasks:/ { in_tasks=1; next }
    /^[^ ]/ && !/^tasks:/ { in_tasks=0 }
    in_tasks && $0 ~ "^  "tid":" { in_task=1; next }
    in_tasks && in_task && /^  [a-zA-Z]/ { exit }
    in_task && $0 ~ "^    "fld":" {
      sub(/^[[:space:]]*[a-zA-Z_]+:[[:space:]]*/, "")
      # 去掉引号
      gsub(/^["'\'']|["'\'']$/, "")
      # 去掉方括号（数组值）
      gsub(/^\[|\]$/, "")
      print
      exit
    }
  ' "$TASK_STATE_FILE"
}

# 获取 task 状态
get_task_status() {
  _get_task_field "$1" "status"
}

# 获取 task 所属 layer
get_task_layer() {
  _get_task_field "$1" "layer"
}

# 获取 task 文件路径
get_task_file() {
  _get_task_field "$1" "file"
}

# 获取 task 的 depends_on 列表（空格分隔）
get_task_depends() {
  local raw
  raw=$(_get_task_field "$1" "depends_on")
  # 清理：去方括号、逗号转空格、去多余空格
  echo "$raw" | sed 's/\[//g;s/\]//g;s/,/ /g' | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# 获取 task 描述
get_task_description() {
  _get_task_field "$1" "description"
}

# ── Task 级状态转换合法性校验 ──
# 与层级 validate_transition 对齐，防止跳步
validate_task_transition() {
  local task_id="$1" new_status="$2"
  local current_status
  current_status=$(get_task_status "$task_id")

  # task 不存在或无状态时放行（init 场景）
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
    *:failed)              valid=true ;;  # 任何状态 → failed 允许（异常恢复）
    *:pending)             valid=true ;;  # 任何状态 → pending 允许（重置）
  esac

  if [ "$valid" = "false" ]; then
    echo "{\"error\": \"非法 task 状态转换: $task_id $current_status → $new_status\"}" >&2
    return 1
  fi
  return 0
}

# 更新 task 状态（带锁，防止并发写入竞态）
update_task_status() {
  local task_id="$1" new_status="$2"
  if [ ! -f "$TASK_STATE_FILE" ]; then return 1; fi
  # 使用 awk 精确替换指定 task 的 status 字段
  local tmp_file="${TASK_STATE_FILE}.tmp.$$"
  awk -v tid="$task_id" -v ns="$new_status" '
    /^tasks:/ { in_tasks=1 }
    /^[^ ]/ && !/^tasks:/ { in_tasks=0 }
    in_tasks && $0 ~ "^  "tid":" { in_task=1 }
    in_tasks && in_task && /^  [a-zA-Z]/ && !($0 ~ "^  "tid":") { in_task=0 }
    in_task && /^    status:/ {
      sub(/status:.*/, "status: "ns)
    }
    { print }
  ' "$TASK_STATE_FILE" > "$tmp_file"
  if command -v flock >/dev/null 2>&1; then
    (
      flock -x 200
      mv "$tmp_file" "$TASK_STATE_FILE"
    ) 200>"${TASK_STATE_FILE}.lock"
  else
    # macOS fallback: mkdir 原子锁
    local lock_dir="${TASK_STATE_FILE}.lockdir"
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
    mv "$tmp_file" "$TASK_STATE_FILE"
    rmdir "$lock_dir" 2>/dev/null || true
  fi
}

# 获取指定 layer 的所有 task id
get_tasks_by_layer() {
  local target_layer="$1"
  for tid in $(get_task_ids); do
    local tl
    tl=$(get_task_layer "$tid")
    if [ "$tl" = "$target_layer" ]; then
      echo "$tid"
    fi
  done
}

# 从 task 状态聚合推导层级状态
# 优先级: failed > coding > designing > confirmed > designed > coded > pending
aggregate_layer_status() {
  local layer="$1"
  local has_tasks=false
  local all_coded=true any_failed=false any_coding=false any_designing=false
  local any_confirmed=false any_designed=false any_pending=false

  for tid in $(get_task_ids); do
    local tl
    tl=$(get_task_layer "$tid")
    [ "$tl" != "$layer" ] && continue
    has_tasks=true
    local ts
    ts=$(get_task_status "$tid")
    case "$ts" in
      coded)      ;;
      failed)     any_failed=true;     all_coded=false ;;
      coding)     any_coding=true;     all_coded=false ;;
      designing)  any_designing=true;  all_coded=false ;;
      confirmed)  any_confirmed=true;  all_coded=false ;;
      designed)   any_designed=true;   all_coded=false ;;
      pending)    any_pending=true;    all_coded=false ;;
      *)          all_coded=false ;;
    esac
  done

  if ! $has_tasks; then echo "pending"; return; fi
  if $any_failed; then echo "failed"
  elif $all_coded; then echo "coded"
  elif $any_coding; then echo "coding"
  elif $any_designing; then echo "designing"
  elif $any_confirmed; then echo "confirmed"
  elif $any_designed; then echo "designed"
  else echo "pending"
  fi
}

# 同步所有层的状态到 workflow-state.yaml（从 task 状态推导）
# 需要 STATE_FILE 和 TASK_STATE_FILE 同时设置
sync_layer_status_from_tasks() {
  if [ ! -f "$TASK_STATE_FILE" ] || [ ! -f "$STATE_FILE" ]; then return 1; fi
  local layers
  layers=$(get_tracked_layers)
  for layer in $layers; do
    local new_status
    new_status=$(aggregate_layer_status "$layer")
    update_layer_status "$layer" "$new_status"
  done
}

# 获取下一批可执行的 task（依赖已满足的 pending task）
# 对于 thinker 阶段：依赖 task 需要 designed|confirmed|coded
# 对于 worker 阶段：依赖 task 需要 coded
# 参数: $1 = "design" 或 "code"（决定依赖满足条件）
get_next_executable_tasks() {
  local phase="${1:-design}"
  for tid in $(get_task_ids); do
    local ts
    ts=$(get_task_status "$tid")

    # design 阶段找 pending task，code 阶段找 confirmed task
    if [ "$phase" = "design" ]; then
      [ "$ts" != "pending" ] && continue
    else
      [ "$ts" != "confirmed" ] && continue
    fi

    # 检查所有依赖是否已满足
    local deps
    deps=$(get_task_depends "$tid")
    local deps_met=true
    for dep in $deps; do
      dep=$(echo "$dep" | tr -d ' ')
      [ -z "$dep" ] && continue
      local dep_status
      dep_status=$(get_task_status "$dep")
      if [ "$phase" = "design" ]; then
        # 设计阶段：上游 task 至少 designed
        case "$dep_status" in
          designed|confirmed|coding|coded) ;;
          *) deps_met=false; break ;;
        esac
      else
        # 编码阶段：上游 task 必须 coded
        case "$dep_status" in
          coded) ;;
          *) deps_met=false; break ;;
        esac
      fi
    done

    $deps_met && echo "$tid"
  done
}

# 初始化 task 工作流状态文件
# 用法: init_task_state <idea> <task_id:layer:depends:description:file> ...
# 每个参数格式: task_id:layer:depends_on:description:file
# depends_on 用逗号分隔多个依赖, 无依赖用空字符串
init_task_state() {
  local idea="$1"; shift
  local content
  content=$(printf "idea: %s\n\ntasks:" "$idea")
  for task_spec in "$@"; do
    local tid tl deps desc tfile
    tid=$(echo "$task_spec" | cut -d: -f1)
    tl=$(echo "$task_spec" | cut -d: -f2)
    deps=$(echo "$task_spec" | cut -d: -f3)
    desc=$(echo "$task_spec" | cut -d: -f4)
    tfile=$(echo "$task_spec" | cut -d: -f5)
    # 格式化 depends_on
    local deps_yaml
    if [ -z "$deps" ]; then
      deps_yaml="[]"
    else
      deps_yaml="[$(echo "$deps" | sed 's/,/, /g')]"
    fi
    content=$(printf '%s\n  %s:\n    layer: %s\n    status: pending\n    depends_on: %s\n    description: "%s"\n    file: %s' \
      "$content" "$tid" "$tl" "$deps_yaml" "$desc" "$tfile")
  done
  locked_write_task "$content"
}

# 检查 task-workflow-state.yaml 是否存在
has_task_state() {
  [ -f "$TASK_STATE_FILE" ]
}

# ── 原子 task 命令 ──
# 将状态转换 + 层级同步合并为一步，减少调用方代码

# 启动 task：confirmed → coding + 同步层级状态
start_task() {
  local task_id="$1"
  local current
  current=$(get_task_status "$task_id")
  if [ "$current" != "confirmed" ]; then
    echo "{\"error\": \"start_task: $task_id 当前状态为 $current，期望 confirmed\"}" >&2
    return 1
  fi
  update_task_status "$task_id" "coding"
  sync_layer_status_from_tasks
}

# 完成 task：coding → coded|failed + 同步层级状态
finish_task() {
  local task_id="$1"
  local target_status="${2:?finish_task 需要指定目标状态 (coded|failed)}"
  case "$target_status" in
    coded|failed) ;;
    *) echo "{\"error\": \"finish_task: 无效目标状态 $target_status，可选 coded|failed\"}" >&2; return 1 ;;
  esac
  local current
  current=$(get_task_status "$task_id")
  if [ "$current" != "coding" ]; then
    echo "{\"error\": \"finish_task: $task_id 当前状态为 $current，期望 coding\"}" >&2
    return 1
  fi
  update_task_status "$task_id" "$target_status"
  sync_layer_status_from_tasks
}
