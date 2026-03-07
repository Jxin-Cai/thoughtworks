#!/usr/bin/env bash
# DDD 状态查询脚本
# 用法: ddd-status.sh <idea-dir> [--pretty]
# 输出: 结构化 JSON（默认）或人类可读表格（--pretty）

set -euo pipefail

IDEA_DIR="${1:?用法: ddd-status.sh <idea-dir> [--pretty]}"
PRETTY="${2:-}"
BACKEND_DESIGNS_DIR="$IDEA_DIR/backend-designs"

# 检查目录存在 — 不存在时返回 not_started 状态而非报错
if [ ! -d "$BACKEND_DESIGNS_DIR" ]; then
  IDEA_NAME=$(basename "$IDEA_DIR")
  json="{\"idea\":\"$IDEA_NAME\",\"layers\":[],\"overall\":{\"total\":0,\"done\":0,\"pending\":0,\"in_progress\":0,\"failed\":0},\"state\":\"not_started\",\"next_thoughts\":[]}"
  if [ "${2:-}" = "--pretty" ]; then
    echo ""
    echo "== $IDEA_NAME =="
    echo ""
    echo "State: not_started (backend-designs 目录尚未创建)"
    echo ""
  else
    echo "$json"
  fi
  exit 0
fi

# 收集设计文件列表
design_files=""
for f in "$BACKEND_DESIGNS_DIR"/*.md; do
  [ -f "$f" ] && design_files="$design_files $f"
done

IDEA_NAME=$(basename "$IDEA_DIR")

# 从 YAML frontmatter 提取字段值
extract_field() {
  local file="$1"
  local field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/"
}

# 从 frontmatter 提取 depends_on 数组
extract_depends() {
  local file="$1"
  local deps
  deps=$(sed -n '/^---$/,/^---$/p' "$file" | grep "^depends_on:" | head -1 | sed 's/^depends_on:[[:space:]]*//')
  echo "$deps" | sed 's/\[//;s/\]//;s/,/ /g' | tr -s ' '
}

# 读取 workflow.yaml 获取层的 phase 和 requires
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW="$SCRIPT_DIR/../workflow.yaml"

get_layer_phase() {
  local layer_id="$1"
  awk "/^  - id: ${layer_id}$/,/^  - id:/" "$WORKFLOW" | grep "phase:" | head -1 | sed 's/.*phase:[[:space:]]*//'
}

get_layer_requires() {
  local layer_id="$1"
  awk "/^  - id: ${layer_id}$/,/^  - id:/" "$WORKFLOW" | grep "requires:" | head -1 | sed 's/.*requires:[[:space:]]*//' | sed 's/\[//;s/\]//;s/,/ /g'
}

# 收集所有 thought 文件信息
layer_count=0
declare -a all_layers all_files all_orders all_statuses all_depends all_descriptions

for design_file in $design_files; do
  [ -f "$design_file" ] || continue
  filename=$(basename "$design_file")

  layer=$(extract_field "$design_file" "layer")
  order=$(extract_field "$design_file" "order")
  status=$(extract_field "$design_file" "status")
  description=$(extract_field "$design_file" "description")
  depends=$(extract_depends "$design_file")

  [ -z "$layer" ] && continue
  [ -z "$order" ] && order=1
  [ -z "$status" ] && status="pending"

  all_layers[$layer_count]="$layer"
  all_files[$layer_count]="$filename"
  all_orders[$layer_count]="$order"
  all_statuses[$layer_count]="$status"
  all_depends[$layer_count]="$depends"
  all_descriptions[$layer_count]="$description"
  layer_count=$((layer_count + 1))
done

# 获取唯一层列表（按 workflow.yaml 中的顺序）
unique_layers=""
for l in domain infr application ohs; do
  for i in $(seq 0 $((layer_count - 1))); do
    if [ "${all_layers[$i]}" = "$l" ]; then
      if ! echo "$unique_layers" | grep -qw "$l"; then
        unique_layers="$unique_layers $l"
      fi
      break
    fi
  done
done

# 辅助函数：检查某层是否全部 done
is_layer_done() {
  local check_layer="$1"
  for i in $(seq 0 $((layer_count - 1))); do
    if [ "${all_layers[$i]}" = "$check_layer" ] && [ "${all_statuses[$i]}" != "done" ]; then
      return 1
    fi
  done
  return 0
}

# 辅助函数：检查某文件是否 done
is_file_done() {
  local check_file="$1"
  for i in $(seq 0 $((layer_count - 1))); do
    if [ "${all_files[$i]}" = "$check_file" ] && [ "${all_statuses[$i]}" = "done" ]; then
      return 0
    fi
  done
  return 1
}

# 构建 JSON
layers_json=""
overall_total=0 overall_done=0 overall_pending=0 overall_in_progress=0 overall_failed=0

for layer_id in $unique_layers; do
  phase=$(get_layer_phase "$layer_id")
  [ -z "$phase" ] && phase=0

  thoughts_json=""
  l_total=0 l_done=0 l_pending=0 l_in_progress=0 l_failed=0

  for i in $(seq 0 $((layer_count - 1))); do
    [ "${all_layers[$i]}" != "$layer_id" ] && continue

    l_total=$((l_total + 1))
    case "${all_statuses[$i]}" in
      done) l_done=$((l_done + 1)) ;;
      pending) l_pending=$((l_pending + 1)) ;;
      in_progress) l_in_progress=$((l_in_progress + 1)) ;;
      failed) l_failed=$((l_failed + 1)) ;;
    esac

    # 构建 depends_on JSON 数组
    deps_json="[]"
    if [ -n "${all_depends[$i]}" ]; then
      deps_arr=""
      for d in ${all_depends[$i]}; do
        d=$(echo "$d" | tr -d ' ')
        [ -z "$d" ] && continue
        if [ -z "$deps_arr" ]; then
          deps_arr="\"$d\""
        else
          deps_arr="$deps_arr,\"$d\""
        fi
      done
      [ -n "$deps_arr" ] && deps_json="[$deps_arr]"
    fi

    escaped_desc=$(echo "${all_descriptions[$i]}" | sed 's/"/\\"/g')
    thought="{\"file\":\"${all_files[$i]}\",\"order\":${all_orders[$i]},\"status\":\"${all_statuses[$i]}\",\"depends_on\":$deps_json,\"description\":\"$escaped_desc\"}"

    if [ -z "$thoughts_json" ]; then
      thoughts_json="$thought"
    else
      thoughts_json="$thoughts_json,$thought"
    fi
  done

  overall_total=$((overall_total + l_total))
  overall_done=$((overall_done + l_done))
  overall_pending=$((overall_pending + l_pending))
  overall_in_progress=$((overall_in_progress + l_in_progress))
  overall_failed=$((overall_failed + l_failed))

  layer_json="{\"id\":\"$layer_id\",\"phase\":$phase,\"thoughts\":[$thoughts_json],\"summary\":{\"total\":$l_total,\"done\":$l_done,\"pending\":$l_pending,\"in_progress\":$l_in_progress,\"failed\":$l_failed}}"

  if [ -z "$layers_json" ]; then
    layers_json="$layer_json"
  else
    layers_json="$layers_json,$layer_json"
  fi
done

# 计算整体状态
if [ "$overall_failed" -gt 0 ]; then
  state="blocked"
elif [ "$overall_total" -eq 0 ]; then
  state="not_started"
elif [ "$overall_done" -eq "$overall_total" ]; then
  state="all_done"
elif [ "$overall_done" -gt 0 ] || [ "$overall_in_progress" -gt 0 ]; then
  state="in_progress"
else
  state="not_started"
fi

# 计算 next_thoughts：可执行的 thought 文件
next_thoughts=""

for i in $(seq 0 $((layer_count - 1))); do
  [ "${all_statuses[$i]}" != "pending" ] && continue

  # 检查跨层依赖
  requires=$(get_layer_requires "${all_layers[$i]}")
  cross_ok=1
  for req in $requires; do
    req=$(echo "$req" | tr -d ' ')
    [ -z "$req" ] && continue
    if ! is_layer_done "$req"; then
      cross_ok=0
      break
    fi
  done
  [ "$cross_ok" -eq 0 ] && continue

  # 检查同层内依赖
  inner_ok=1
  for dep in ${all_depends[$i]}; do
    dep=$(echo "$dep" | tr -d ' ')
    [ -z "$dep" ] && continue
    if ! is_file_done "$dep"; then
      inner_ok=0
      break
    fi
  done
  [ "$inner_ok" -eq 0 ] && continue

  if [ -z "$next_thoughts" ]; then
    next_thoughts="\"${all_files[$i]}\""
  else
    next_thoughts="$next_thoughts,\"${all_files[$i]}\""
  fi
done

# 输出
json="{\"idea\":\"$IDEA_NAME\",\"layers\":[$layers_json],\"overall\":{\"total\":$overall_total,\"done\":$overall_done,\"pending\":$overall_pending,\"in_progress\":$overall_in_progress,\"failed\":$overall_failed},\"state\":\"$state\",\"next_thoughts\":[$next_thoughts]}"

if [ "$PRETTY" = "--pretty" ]; then
  echo ""
  echo "== $IDEA_NAME =="
  echo ""
  printf "%-15s %-7s %-10s %-6s %-8s %s\n" "Layer" "Phase" "Thoughts" "Done" "Pending" "Status"
  printf "%-15s %-7s %-10s %-6s %-8s %s\n" "───────────────" "───────" "──────────" "──────" "────────" "──────────"

  for layer_id in $unique_layers; do
    phase=$(get_layer_phase "$layer_id")
    l_total=0 l_done=0 l_pending=0
    for i in $(seq 0 $((layer_count - 1))); do
      [ "${all_layers[$i]}" != "$layer_id" ] && continue
      l_total=$((l_total + 1))
      [ "${all_statuses[$i]}" = "done" ] && l_done=$((l_done + 1))
      [ "${all_statuses[$i]}" = "pending" ] && l_pending=$((l_pending + 1))
    done
    if [ "$l_done" -eq "$l_total" ]; then
      status_str="✓ done"
    elif [ "$l_done" -gt 0 ]; then
      status_str="◐ partial"
    else
      status_str="○ pending"
    fi
    printf "%-15s %-7s %-10s %-6s %-8s %s\n" "$layer_id" "$phase" "$l_total" "$l_done" "$l_pending" "$status_str"
  done

  printf "%-15s %-7s %-10s %-6s %-8s\n" "───────────────" "───────" "──────────" "──────" "────────"
  printf "%-15s %-7s %-10s %-6s %-8s\n" "Total" "" "$overall_total" "$overall_done" "$overall_pending"
  echo ""
  echo "State: $state"
  if [ -n "$next_thoughts" ]; then
    echo "Next:  $(echo "$next_thoughts" | sed 's/"//g;s/,/, /g')"
  fi
  echo ""
else
  echo "$json"
fi
