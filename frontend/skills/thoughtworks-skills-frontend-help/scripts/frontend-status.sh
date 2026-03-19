#!/usr/bin/env bash
# 前端设计文档状态查询脚本
# 用法: frontend-status.sh <idea-dir> [--pretty]

set -euo pipefail

IDEA_DIR="${1:?用法: frontend-status.sh <idea-dir> [--pretty]}"
PRETTY="${2:-}"
FRONTEND_DESIGNS_DIR="$IDEA_DIR/frontend-designs"

if [ ! -d "$FRONTEND_DESIGNS_DIR" ]; then
  IDEA_NAME=$(basename "$IDEA_DIR")
  json="{\"idea\":\"$IDEA_NAME\",\"layers\":[],\"overall\":{\"total\":0,\"done\":0,\"pending\":0,\"in_progress\":0,\"failed\":0},\"state\":\"not_started\"}"
  if [ "${2:-}" = "--pretty" ]; then
    echo ""
    echo "== $IDEA_NAME (frontend) =="
    echo ""
    echo "State: not_started (frontend-designs 目录尚未创建)"
    echo ""
  else
    echo "$json"
  fi
  exit 0
fi

design_files=""
for f in "$FRONTEND_DESIGNS_DIR"/*.md; do
  [ -f "$f" ] && design_files="$design_files $f"
done

IDEA_NAME=$(basename "$IDEA_DIR")

extract_field() {
  local file="$1" field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/"
}

extract_depends() {
  local file="$1"
  local deps
  deps=$(sed -n '/^---$/,/^---$/p' "$file" | grep "^depends_on:" | head -1 | sed 's/^depends_on:[[:space:]]*//')
  echo "$deps" | sed 's/\[//;s/\]//;s/,/ /g' | tr -s ' '
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW="$SCRIPT_DIR/../workflow.yaml"
STATE_FILE="$IDEA_DIR/frontend-workflow-state.json"

get_layer_phase() {
  local layer_id="$1"
  awk -v lid="$layer_id" '
    BEGIN { found=0 }
    $0 ~ "^  - id: " lid "$" { found=1; next }
    found && /^  - id:/ { exit }
    found && /phase:/ { gsub(/.*phase:[[:space:]]*/, ""); print; exit }
  ' "$WORKFLOW"
}

# 从 frontend-workflow-state.json 读取某层的工作流状态
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

unique_layers=""
for l in frontend-architecture frontend-components frontend-checklist; do
  for i in $(seq 0 $((layer_count - 1))); do
    if [ "${all_layers[$i]}" = "$l" ]; then
      if ! echo "$unique_layers" | grep -qw "$l"; then
        unique_layers="$unique_layers $l"
      fi
      break
    fi
  done
done

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
    deps_json="[]"
    if [ -n "${all_depends[$i]}" ]; then
      deps_arr=""
      for d in ${all_depends[$i]}; do
        d=$(echo "$d" | tr -d ' ')
        [ -z "$d" ] && continue
        if [ -z "$deps_arr" ]; then deps_arr="\"$d\""; else deps_arr="$deps_arr,\"$d\""; fi
      done
      [ -n "$deps_arr" ] && deps_json="[$deps_arr]"
    fi
    escaped_desc=$(echo "${all_descriptions[$i]}" | sed 's/"/\\"/g')
    thought="{\"file\":\"${all_files[$i]}\",\"order\":${all_orders[$i]},\"status\":\"${all_statuses[$i]}\",\"depends_on\":$deps_json,\"description\":\"$escaped_desc\"}"
    if [ -z "$thoughts_json" ]; then thoughts_json="$thought"; else thoughts_json="$thoughts_json,$thought"; fi
  done

  overall_total=$((overall_total + l_total))
  overall_done=$((overall_done + l_done))
  overall_pending=$((overall_pending + l_pending))
  overall_in_progress=$((overall_in_progress + l_in_progress))
  overall_failed=$((overall_failed + l_failed))

  layer_json="{\"id\":\"$layer_id\",\"phase\":$phase,\"thoughts\":[$thoughts_json],\"summary\":{\"total\":$l_total,\"done\":$l_done,\"pending\":$l_pending,\"in_progress\":$l_in_progress,\"failed\":$l_failed}}"
  if [ -z "$layers_json" ]; then layers_json="$layer_json"; else layers_json="$layers_json,$layer_json"; fi
done

if [ "$overall_failed" -gt 0 ]; then state="blocked"
elif [ "$overall_total" -eq 0 ]; then state="not_started"
elif [ "$overall_done" -eq "$overall_total" ]; then state="all_done"
elif [ "$overall_done" -gt 0 ] || [ "$overall_in_progress" -gt 0 ]; then state="in_progress"
else state="not_started"
fi

# 构建 workflow_phases JSON（从 frontend-workflow-state.json）
workflow_phases_json=""
if [ -f "$STATE_FILE" ]; then
  for layer_id in frontend-architecture frontend-components frontend-checklist; do
    wf_st=$(get_workflow_status "$layer_id")
    [ -z "$wf_st" ] && continue
    entry="\"$layer_id\":\"$wf_st\""
    if [ -z "$workflow_phases_json" ]; then
      workflow_phases_json="$entry"
    else
      workflow_phases_json="$workflow_phases_json,$entry"
    fi
  done
fi

json="{\"idea\":\"$IDEA_NAME\",\"layers\":[$layers_json],\"overall\":{\"total\":$overall_total,\"done\":$overall_done,\"pending\":$overall_pending,\"in_progress\":$overall_in_progress,\"failed\":$overall_failed},\"state\":\"$state\",\"workflow_phases\":{$workflow_phases_json}}"

if [ "$PRETTY" = "--pretty" ]; then
  echo ""
  echo "== $IDEA_NAME (frontend) =="
  echo ""
  printf "%-15s %-7s %-10s %-6s %-8s %-12s %s\n" "Layer" "Phase" "Thoughts" "Done" "Pending" "WF-State" "Status"
  printf "%-15s %-7s %-10s %-6s %-8s %-12s %s\n" "───────────────" "───────" "──────────" "──────" "────────" "────────────" "──────────"
  for layer_id in $unique_layers; do
    phase=$(get_layer_phase "$layer_id")
    l_total=0 l_done=0 l_pending=0
    for i in $(seq 0 $((layer_count - 1))); do
      [ "${all_layers[$i]}" != "$layer_id" ] && continue
      l_total=$((l_total + 1))
      [ "${all_statuses[$i]}" = "done" ] && l_done=$((l_done + 1))
      [ "${all_statuses[$i]}" = "pending" ] && l_pending=$((l_pending + 1))
    done
    if [ "$l_done" -eq "$l_total" ]; then status_str="✓ done"; else status_str="○ pending"; fi
    wf_st=$(get_workflow_status "$layer_id")
    [ -z "$wf_st" ] && wf_st="-"
    printf "%-15s %-7s %-10s %-6s %-8s %-12s %s\n" "$layer_id" "$phase" "$l_total" "$l_done" "$l_pending" "$wf_st" "$status_str"
  done
  echo ""
  echo "State: $state"
  echo ""
else
  echo "$json"
fi
