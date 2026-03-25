#!/usr/bin/env bash
# 前端设计文档校验脚本（支持按层分目录和旧版 *.md 目录）
# 用法: frontend-output-validate.sh <idea-dir> [--layer <layer>] [--summary]
#
# 校验规则：
# S1: frontmatter 必填字段（按层分目录模式下增加 task_id）
# S3: 结论章节存在且非空
# S4: 实现清单表格存在（frontend-checklist 层文件）
# S6: 依赖契约章节存在
# C6: Frontend 依赖契约 API 端点 ⊆ OHS 已有代码 API 端点（扫描代码或 ohs.md 回退）
# C7: frontend-components 依赖契约 ⊆ frontend-architecture 导出契约（跨文件一致性）

set -euo pipefail

IDEA_DIR="${1:?用法: frontend-output-validate.sh <idea-dir> [--layer <layer>] [--summary]}"
shift
FILTER_LAYER=""
SUMMARY_ONLY=false
while [ $# -gt 0 ]; do
  case "$1" in
    --layer) FILTER_LAYER="$2"; shift 2 ;;
    --summary) SUMMARY_ONLY=true; shift ;;
    *) shift ;;
  esac
done
FRONTEND_DESIGNS_DIR="$IDEA_DIR/frontend-designs"
# 前端三层目录列表
LAYER_DIRS="frontend-architecture frontend-components frontend-checklist"
STATE_FILE="$IDEA_DIR/frontend-workflow-state.yaml"

if [ ! -d "$FRONTEND_DESIGNS_DIR" ]; then
  echo '{"status":"fail","checks":[{"layer":"","file":"","rule":"INIT","pass":false,"detail":"frontend-designs 目录不存在"}]}'
  exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
  echo '{"status":"fail","checks":[{"layer":"","file":"","rule":"INIT","pass":false,"detail":"frontend-workflow-state.yaml 不存在"}]}'
  exit 1
fi

# ── 判断是否使用按层分目录 ──
USE_LAYER_DIRS=""
for _ld in $LAYER_DIRS; do
  if [ -d "$FRONTEND_DESIGNS_DIR/$_ld" ]; then
    _has_md=$(find "$FRONTEND_DESIGNS_DIR/$_ld" -maxdepth 1 -name '*.md' 2>/dev/null | head -1)
    if [ -n "$_has_md" ]; then
      USE_LAYER_DIRS="1"
      break
    fi
  fi
done

get_layer_dir() {
  local l="$1"
  if [ -n "$USE_LAYER_DIRS" ]; then
    echo "$FRONTEND_DESIGNS_DIR/$l"
  else
    echo "$FRONTEND_DESIGNS_DIR"
  fi
}

# ── JSON 输出辅助（默认只记录失败，减少输出体积）──
CHECKS=""
TOTAL_COUNT=0
FAIL_COUNT=0
add_check() {
  local layer="$1" file="$2" rule="$3" pass="$4" detail="${5:-}"
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  if [ "$pass" = "false" ]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    local entry="{\"layer\":\"$layer\",\"file\":\"$file\",\"rule\":\"$rule\",\"pass\":false"
    if [ -n "$detail" ]; then
      entry="$entry,\"detail\":\"$detail\""
    fi
    entry="$entry}"
    if [ -z "$CHECKS" ]; then CHECKS="$entry"; else CHECKS="$CHECKS,$entry"; fi
  fi
}

# ── 辅助函数 ──

extract_frontmatter() {
  local file="$1"
  sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d'
}

has_frontmatter_field() {
  local file="$1" field="$2"
  extract_frontmatter "$file" | grep -q "^${field}:" 2>/dev/null
}

has_section() {
  local file="$1" section="$2"
  grep -q "^## ${section}" "$file" 2>/dev/null
}

extract_section_content() {
  local file="$1" section="$2"
  awk -v sec="## ${section}" '
    $0 == sec || index($0, sec) == 1 && length($0) == length(sec) { found=1; next }
    found && /^## / { exit }
    found { print }
  ' "$file"
}

# 从 frontmatter 读取 layer 字段值
get_layer_from_frontmatter() {
  local file="$1"
  extract_frontmatter "$file" | sed -n 's/^layer:[[:space:]]*//p' | head -1
}

# 从文件路径推断层（优先检查父目录名，回退到文件名前缀）
layer_from_filepath() {
  local fpath="$1"
  local parent_dir
  parent_dir=$(basename "$(dirname "$fpath")")
  case "$parent_dir" in
    frontend-architecture|frontend-components|frontend-checklist) echo "$parent_dir" ;;
    *)
      local fname
      fname=$(basename "$fpath")
      case "$fname" in
        arch-*|frontend-architecture*) echo "frontend-architecture" ;;
        comp-*|frontend-components*) echo "frontend-components" ;;
        impl-*|frontend-checklist*) echo "frontend-checklist" ;;
        *) echo "frontend" ;;
      esac
      ;;
  esac
}

# 获取某层的文件列表
get_layer_files() {
  local target_layer="$1"
  local scan_dir
  scan_dir=$(get_layer_dir "$target_layer")
  [ -d "$scan_dir" ] || return
  if [ -n "$USE_LAYER_DIRS" ]; then
    # 新模式：层目录下所有 .md 都属于该层
    for f in "$scan_dir"/*.md; do
      [ -f "$f" ] || continue
      basename "$f"
    done
  else
    # 旧模式：按 frontmatter 或文件名前缀匹配
    for f in "$scan_dir"/*.md; do
      [ -f "$f" ] || continue
      local base
      base=$(basename "$f")
      local fl
      fl=$(get_layer_from_frontmatter "$f")
      [ -z "$fl" ] && fl=$(layer_from_filepath "$f")
      if [ "$fl" = "$target_layer" ]; then
        echo "$base"
      fi
    done
  fi
}

# 合并某层所有文件中指定 ### 子章节内容
merge_layer_subsection() {
  local target_layer="$1" subsection="$2"
  local scan_dir
  scan_dir=$(get_layer_dir "$target_layer")
  local files
  files=$(get_layer_files "$target_layer")
  for fname in $files; do
    local fpath="$scan_dir/$fname"
    [ -f "$fpath" ] || continue
    awk -v sec="### ${subsection}" '
      $0 == sec || index($0, sec) == 1 { found=1; next }
      found && /^### / { exit }
      found { print }
    ' "$fpath"
  done
}

# ── --layer 过滤 ──
if [ -n "$FILTER_LAYER" ]; then
  case "$FILTER_LAYER" in
    frontend-architecture|frontend-components|frontend-checklist) ;;
    *) echo "{\"status\":\"fail\",\"checks\":[{\"layer\":\"$FILTER_LAYER\",\"file\":\"\",\"rule\":\"INIT\",\"pass\":false,\"detail\":\"无效层名: $FILTER_LAYER，可选: frontend-architecture|frontend-components|frontend-checklist\"}]}"
       exit 1 ;;
  esac
  LAYER_DIRS="$FILTER_LAYER"
fi

# ── 开始校验：遍历所有设计文件 ──

for layer in $LAYER_DIRS; do
  scan_dir=$(get_layer_dir "$layer")
  [ -d "$scan_dir" ] || continue
  for filepath in "$scan_dir"/*.md; do
  [ -f "$filepath" ] || continue
  fname=$(basename "$filepath")
  layer_id=$(get_layer_from_frontmatter "$filepath")
  [ -z "$layer_id" ] && layer_id=$(layer_from_filepath "$filepath")

  # S1: frontmatter 必填字段
  s1_pass=true
  s1_detail=""
  required_fields="layer order status depends_on description"
  if [ -n "$USE_LAYER_DIRS" ]; then
    required_fields="task_id layer order status depends_on description"
  fi
  for field in $required_fields; do
    if ! has_frontmatter_field "$filepath" "$field"; then
      s1_pass=false
      s1_detail="frontmatter 缺少 ${field} 字段"
      break
    fi
  done
  if [ "$s1_pass" = "true" ]; then
    add_check "$layer_id" "$fname" "S1" "true"
  else
    add_check "$layer_id" "$fname" "S1" "false" "$s1_detail"
  fi

  # S3: 结论章节存在
  if has_section "$filepath" "结论"; then
    conclusion_content=$(extract_section_content "$filepath" "结论")
    non_empty=$(echo "$conclusion_content" | grep -v '^[[:space:]]*$' | head -1 || true)
    if [ -n "$non_empty" ]; then
      add_check "$layer_id" "$fname" "S3" "true"
    else
      add_check "$layer_id" "$fname" "S3" "false" "结论章节下方没有非空内容"
    fi
  else
    add_check "$layer_id" "$fname" "S3" "false" "缺少 ## 结论 章节"
  fi

  # S4: 实现清单表格存在（frontend-checklist 层文件）
  if [ "$layer_id" = "frontend-checklist" ] || [ "$fname" = "frontend-checklist.md" ]; then
    if has_section "$filepath" "实现清单"; then
      impl_rows=$(extract_section_content "$filepath" "实现清单" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | grep -c '^|' || true)
      if [ "$impl_rows" -gt 0 ]; then
        add_check "$layer_id" "$fname" "S4" "true"
      else
        add_check "$layer_id" "$fname" "S4" "false" "实现清单表格数据行数为 0"
      fi
    else
      add_check "$layer_id" "$fname" "S4" "false" "缺少 ## 实现清单 章节"
    fi
  fi

  # S6: 依赖契约存在
  if has_section "$filepath" "依赖契约"; then
    add_check "$layer_id" "$fname" "S6" "true"
  else
    add_check "$layer_id" "$fname" "S6" "false" "缺少 ## 依赖契约 章节"
  fi
done
done

# ── C6: Frontend 依赖契约 > API 端点 ⊆ OHS API 端点 ──
# 新模式：优先从 OHS 代码扫描 API 端点；回退到 backend-designs/ohs/*.md 或旧版 ohs.md
# --layer 过滤：仅当指定 frontend-architecture 或未指定 --layer 时执行
if [ -z "$FILTER_LAYER" ] || [ "$FILTER_LAYER" = "frontend-architecture" ]; then

# 收集 architecture 层所有文件的 API 端点依赖
arch_files=$(get_layer_files "frontend-architecture")
arch_scan_dir=$(get_layer_dir "frontend-architecture")
frontend_api_sigs=""
for fname in $arch_files; do
  fpath="$arch_scan_dir/$fname"
  [ -f "$fpath" ] || continue
  sigs=$(awk '
    /^### API 端点/ { found=1; next }
    found && /^### / { exit }
    found && /^\|/ && !/^\|[[:space:]]*[-—]/ { print }
  ' "$fpath" | tail -n +2 | awk -F'|' '{ if (NF >= 3) { val=$3; gsub(/^[[:space:]]+|[[:space:]]+$/, "", val); gsub(/`/, "", val); if (val != "") print val } }' || true)
  if [ -n "$sigs" ]; then
    if [ -n "$frontend_api_sigs" ]; then
      frontend_api_sigs="$frontend_api_sigs
$sigs"
    else
      frontend_api_sigs="$sigs"
    fi
  fi
done

if [ -n "$frontend_api_sigs" ]; then
  # 收集 OHS API 端点签名
  ohs_api_sigs=""

  # 方式1: 从 backend-designs/ohs/*.md 提取（按层分目录模式）
  BACKEND_OHS_DIR="$IDEA_DIR/backend-designs/ohs"
  if [ -d "$BACKEND_OHS_DIR" ]; then
    for ohs_file in "$BACKEND_OHS_DIR"/*.md; do
      [ -f "$ohs_file" ] || continue
      sigs=$(awk '
        /^## API 端点/ { found=1; next }
        found && /^## / { exit }
        found && /^### / { sub(/^### /, ""); print }
      ' "$ohs_file" || true)
      if [ -n "$sigs" ]; then
        if [ -n "$ohs_api_sigs" ]; then
          ohs_api_sigs="$ohs_api_sigs
$sigs"
        else
          ohs_api_sigs="$sigs"
        fi
      fi
    done
  fi

  # 方式2: 从旧版 backend-designs/ohs.md 提取
  BACKEND_OHS="$IDEA_DIR/backend-designs/ohs.md"
  if [ -z "$ohs_api_sigs" ] && [ -f "$BACKEND_OHS" ]; then
    ohs_api_sigs=$(awk '
      /^## API 端点/ { found=1; next }
      found && /^## / { exit }
      found && /^### / { sub(/^### /, ""); print }
    ' "$BACKEND_OHS" || true)
  fi

  # 执行匹配
  arch_file_for_report=$(echo "$arch_files" | head -1)
  [ -z "$arch_file_for_report" ] && arch_file_for_report="frontend-architecture.md"
  if [ -n "$ohs_api_sigs" ]; then
    c6_pass=true
    c6_detail=""
    while IFS= read -r sig; do
      [ -z "$sig" ] && continue
      if ! echo "$ohs_api_sigs" | grep -qF "$sig"; then
        c6_pass=false
        c6_detail="Frontend 依赖契约中 \`${sig}\` 在 OHS API 端点中未找到匹配"
        break
      fi
    done <<< "$frontend_api_sigs"
    if [ "$c6_pass" = "true" ]; then
      add_check "frontend-architecture" "$arch_file_for_report" "C6" "true"
    else
      add_check "frontend-architecture" "$arch_file_for_report" "C6" "false" "$c6_detail"
    fi
  else
    # 无 OHS 设计文件可比对，跳过 C6（OHS API 来自代码扫描，校验脚本无法执行代码扫描）
    add_check "frontend-architecture" "$arch_file_for_report" "C6" "true" "OHS 设计文件不存在，C6 跳过（前端依赖 OHS 代码扫描）"
  fi
fi

fi # --layer 过滤 C6

# ── C7: frontend-components 依赖契约 ⊆ frontend-architecture 导出契约 ──
# --layer 过滤：仅当指定 frontend-components 或未指定 --layer 时执行
if [ -z "$FILTER_LAYER" ] || [ "$FILTER_LAYER" = "frontend-components" ]; then

# 合并所有 architecture 文件的导出契约
arch_entities=$(merge_layer_subsection "frontend-architecture" "Entity 列表" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | awk -F'|' '{ if (NF >= 2) { val=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", val); if (val != "") print val } }' || true)
arch_features=$(merge_layer_subsection "frontend-architecture" "Feature 列表" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | awk -F'|' '{ if (NF >= 2) { val=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", val); if (val != "") print val } }' || true)

# 合并所有 components 文件的依赖契约
comp_dep_entities=$(merge_layer_subsection "frontend-components" "Entity 列表" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | awk -F'|' '{ if (NF >= 2) { val=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", val); if (val != "") print val } }' || true)
comp_dep_features=$(merge_layer_subsection "frontend-components" "Feature 列表" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | awk -F'|' '{ if (NF >= 2) { val=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", val); if (val != "") print val } }' || true)

# 只在有 components 文件时执行 C7
comp_files=$(get_layer_files "frontend-components")
if [ -n "$comp_files" ] && [ -n "$arch_files" ]; then
  comp_file_for_report=$(echo "$comp_files" | head -1)
  c7_pass=true
  c7_detail=""

  # 检查 Entity 列表一致性
  if [ -n "$comp_dep_entities" ]; then
    while IFS= read -r entity; do
      [ -z "$entity" ] && continue
      if [ -z "$arch_entities" ] || ! echo "$arch_entities" | grep -qF "$entity"; then
        c7_pass=false
        c7_detail="Components 依赖契约中 Entity \`${entity}\` 在 Architecture 导出契约中未找到"
        break
      fi
    done <<< "$comp_dep_entities"
  fi

  # 检查 Feature 列表一致性
  if [ "$c7_pass" = "true" ] && [ -n "$comp_dep_features" ]; then
    while IFS= read -r feature; do
      [ -z "$feature" ] && continue
      if [ -z "$arch_features" ] || ! echo "$arch_features" | grep -qF "$feature"; then
        c7_pass=false
        c7_detail="Components 依赖契约中 Feature \`${feature}\` 在 Architecture 导出契约中未找到"
        break
      fi
    done <<< "$comp_dep_features"
  fi

  if [ "$c7_pass" = "true" ]; then
    add_check "frontend-components" "$comp_file_for_report" "C7" "true"
  else
    add_check "frontend-components" "$comp_file_for_report" "C7" "false" "$c7_detail"
  fi
fi

fi # --layer 过滤 C7

# ── 计算最终状态并输出 ──

if [ "$FAIL_COUNT" -eq 0 ]; then
  STATUS="pass"
else
  STATUS="fail"
fi

if [ "$SUMMARY_ONLY" = "true" ]; then
  # --summary: 精简摘要（直接用计数器，无需 grep）
  failed_rules=""
  if [ "$FAIL_COUNT" -gt 0 ]; then
    failed_rules=$(echo "$CHECKS" | grep -o '"rule":"[^"]*"' | sed 's/"rule":"//;s/"$//' | sort -u | awk '{printf "\"%s\",", $0}' | sed 's/,$//')
  fi
  echo "{\"status\":\"$STATUS\",\"total\":$TOTAL_COUNT,\"failed\":$FAIL_COUNT,\"failed_rules\":[$failed_rules]}"
else
  # 默认输出：CHECKS 已只含失败项
  echo "{\"status\":\"$STATUS\",\"total\":$TOTAL_COUNT,\"failed\":$FAIL_COUNT,\"checks\":[$CHECKS]}"
fi
