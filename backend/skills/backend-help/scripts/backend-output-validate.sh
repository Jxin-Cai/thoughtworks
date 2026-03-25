#!/usr/bin/env bash
# 后端设计文档校验脚本（支持按层分目录和旧版 *.md 目录）
# 用法: backend-output-validate.sh <idea-dir> [--layer <layer>]
# 输出: JSON 格式校验结果

set -euo pipefail

IDEA_DIR="${1:?用法: backend-output-validate.sh <idea-dir> [--layer <layer>] [--summary]}"
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

BACKEND_DESIGNS_DIR="$IDEA_DIR/backend-designs"
LAYER_DIRS="domain infr application ohs"
STATE_FILE="$IDEA_DIR/workflow-state.yaml"

if [ ! -d "$BACKEND_DESIGNS_DIR" ]; then
  echo '{"status":"fail","checks":[{"layer":"","file":"","rule":"INIT","pass":false,"detail":"backend-designs 目录不存在"}]}'
  exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
  echo '{"status":"fail","checks":[{"layer":"","file":"","rule":"INIT","pass":false,"detail":"workflow-state.yaml 不存在"}]}'
  exit 1
fi

# ── 解析 workflow-state.yaml 中的 tracked_layers ──
# 格式:
#   idea: xxx
#   layers:
#     domain: coded
#     infr: coding

# source 共享库（用于 get_tracked_layers / get_tracked_status）
CORE_LIB="$(cd "$(dirname "$0")" && pwd)/../../../../core/scripts/workflow-lib.sh"
source "$CORE_LIB"

# 提取所有 tracked layer 名称（status 为 done 或 coded 的层）
# 当 --layer 明确指定时，也接受 confirmed/coding 状态的层
parse_tracked_layers() {
  local all_layers
  all_layers=$(get_tracked_layers)
  for layer in $all_layers; do
    local st
    st=$(get_tracked_status "$layer")
    case "$st" in
      done|coded) echo "$layer" ;;
      confirmed|coding)
        # 仅当 --layer 明确指定该层时才接受
        if [ -n "$FILTER_LAYER" ] && [ "$FILTER_LAYER" = "$layer" ]; then
          echo "$layer"
        fi
        ;;
    esac
  done
}

TRACKED_LAYERS=$(parse_tracked_layers)

# 如果指定了 --layer，校验层名合法性并过滤
if [ -n "$FILTER_LAYER" ]; then
  case "$FILTER_LAYER" in
    domain|infr|application|ohs) ;;
    *) echo "{\"status\":\"fail\",\"checks\":[{\"layer\":\"$FILTER_LAYER\",\"file\":\"\",\"rule\":\"INIT\",\"pass\":false,\"detail\":\"无效层名: $FILTER_LAYER，可选: domain|infr|application|ohs\"}]}"
       exit 1 ;;
  esac
  if ! echo "$TRACKED_LAYERS" | grep -qx "$FILTER_LAYER"; then
    echo "{\"status\":\"pass\",\"checks\":[{\"layer\":\"$FILTER_LAYER\",\"file\":\"\",\"rule\":\"INIT\",\"pass\":true,\"detail\":\"该层不在 tracked_layers 中或未完成，跳过校验\"}]}"
    exit 0
  fi
  TRACKED_LAYERS="$FILTER_LAYER"
fi

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
    if [ -z "$CHECKS" ]; then
      CHECKS="$entry"
    else
      CHECKS="$CHECKS,$entry"
    fi
  fi
}

# ── 辅助函数 ──

# 从文件提取 frontmatter 字段值
extract_field() {
  local file="$1" field="$2"
  sed -n '1,/^---$/!{/^---$/,/^---$/p}' "$file" | sed -n '/^---$/,/^---$/p' | \
    grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | \
    sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

# 更健壮的 frontmatter 提取：取文件开头 --- 到第二个 --- 之间的内容
extract_frontmatter() {
  local file="$1"
  sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d'
}

# 检查 frontmatter 是否包含某字段
has_frontmatter_field() {
  local file="$1" field="$2"
  local fm
  fm=$(extract_frontmatter "$file")
  echo "$fm" | grep -q "^${field}:" 2>/dev/null
}

# 从文件完整路径推断 layer 名
# 新模式: backend-designs/domain/001-order.md → domain（从目录名）
# 旧模式: backend-designs/domain-001-order.md → domain（从文件名前缀）
layer_from_filepath() {
  local fpath="$1"
  local parent_dir
  parent_dir=$(basename "$(dirname "$fpath")")
  case "$parent_dir" in
    domain|infr|application|ohs) echo "$parent_dir" ;;
    *)
      # 旧模式回退：从文件名前缀推断
      local fname
      fname=$(basename "$fpath")
      echo "${fname%.md}" | sed 's/-.*//'
      ;;
  esac
}

# 检查文件是否包含某个二级章节
has_section() {
  local file="$1" section="$2"
  grep -q "^## ${section}" "$file" 2>/dev/null
}

# 检查文件是否包含某个三级章节
has_subsection() {
  local file="$1" section="$2"
  grep -q "^### ${section}" "$file" 2>/dev/null
}

# 提取某二级章节到下一个二级章节之间的内容
extract_section_content() {
  local file="$1" section="$2"
  awk -v sec="## ${section}" '
    $0 == sec || $0 ~ "^"sec"$" || index($0, sec) == 1 && length($0) == length(sec) { found=1; next }
    found && /^## / { exit }
    found { print }
  ' "$file"
}

# 提取某三级章节到下一个二级或三级章节之间的内容
extract_subsection_content() {
  local file="$1" section="$2"
  awk -v sec="### ${section}" '
    $0 == sec || index($0, sec) == 1 && length($0) == length(sec) { found=1; next }
    found && /^##[#]? / { exit }
    found { print }
  ' "$file"
}

# 提取某四级章节到下一个二级/三级/四级章节之间的内容
extract_h4_section_content() {
  local file="$1" section="$2"
  awk -v sec="#### ${section}" '
    $0 == sec || index($0, sec) == 1 && length($0) == length(sec) { found=1; next }
    found && /^##[#]?[#]? / { exit }
    found { print }
  ' "$file"
}

# 从一段内容中提取 markdown 表格数据行（跳过表头和分隔行）
# 输入：管道传入的文本
extract_table_data_rows() {
  grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2
}

# 从一段内容中提取表格第二列（方法签名），去掉前后空格和反引号
extract_col2() {
  awk -F'|' '{
    if (NF >= 3) {
      val = $3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      gsub(/`/, "", val)
      if (val != "") print val
    }
  }'
}

# 从导出契约区之前的正文内容（application 层使用）
extract_body_before_export() {
  local file="$1"
  awk '
    /^---$/ { fm++; next }
    fm < 2 { next }
    /^## 导出契约/ { exit }
    { print }
  ' "$file"
}

# ── domain 多聚合结构辅助函数 ──

# 检查 domain.md 是否包含至少一个聚合级导出契约（### 导出契约）
has_aggregate_export_contracts() {
  local file="$1"
  grep -q "^### 导出契约" "$file" 2>/dev/null
}

# 提取 domain.md 所有聚合的 ### 导出契约下指定 #### 子表的合并内容
extract_all_aggregate_h4_content() {
  local file="$1" h4_title="$2"
  awk -v h4="#### ${h4_title}" '
    /^## 聚合:/ { in_agg=1; in_export=0; in_h4=0; next }
    /^## / && !/^## 聚合:/ { in_agg=0; in_export=0; in_h4=0; next }
    in_agg && /^### 导出契约/ { in_export=1; in_h4=0; next }
    in_agg && /^### / && !/^### 导出契约/ { in_export=0; in_h4=0; next }
    in_export && $0 == h4 { in_h4=1; next }
    in_export && in_h4 && /^####/ { in_h4=0; next }
    in_export && in_h4 && /^###/ { in_h4=0; in_export=0; next }
    in_h4 { print }
  ' "$file"
}

# 提取 domain.md 所有聚合的 ### 导出契约的全部内容（合并）
extract_all_aggregate_export_content() {
  local file="$1"
  awk '
    /^## 聚合:/ { in_agg=1; in_export=0; next }
    /^## / && !/^## 聚合:/ { in_agg=0; in_export=0; next }
    in_agg && /^### 导出契约/ { in_export=1; next }
    in_agg && /^### / && !/^### 导出契约/ { in_export=0; next }
    in_export { print }
  ' "$file"
}

# 提取 domain.md 中所有聚合章节的正文（每个聚合的导出契约之前的内容合并）
extract_aggregate_body_before_export() {
  local file="$1"
  awk '
    /^## 聚合:/ { in_agg=1; print_body=1; next }
    /^## / && !/^## 聚合:/ { in_agg=0; print_body=0; next }
    in_agg && /^### 导出契约/ { print_body=0; next }
    in_agg && /^### / && print_body==0 { next }
    in_agg && print_body { print }
  ' "$file"
}

# ── 收集各层文件（优先按层分目录，回退到旧版 *.md）──

# 判断是否使用按层分目录模式
USE_LAYER_DIRS=""
for layer_name in $LAYER_DIRS; do
  if [ -d "$BACKEND_DESIGNS_DIR/$layer_name" ]; then
    has_files=$(find "$BACKEND_DESIGNS_DIR/$layer_name" -maxdepth 1 -name '*.md' 2>/dev/null | head -1)
    if [ -n "$has_files" ]; then
      USE_LAYER_DIRS="1"
      break
    fi
  fi
done

# 获取某层的文件目录
get_layer_dir() {
  local l="$1"
  if [ -n "$USE_LAYER_DIRS" ]; then
    echo "$BACKEND_DESIGNS_DIR/$l"
  else
    echo "$BACKEND_DESIGNS_DIR"
  fi
}

# 获取某层的文件列表（从文件系统扫描）
get_layer_files_cached() {
  local l="$1"
  local scan_dir
  scan_dir=$(get_layer_dir "$l")
  if [ ! -d "$scan_dir" ]; then return; fi
  if [ -n "$USE_LAYER_DIRS" ]; then
    # 新模式：目录即层，目录下所有 .md 都属于该层
    for f in "$scan_dir"/*.md; do
      [ -f "$f" ] || continue
      echo "$(basename "$f")"
    done
  else
    # 旧模式：按文件名前缀匹配
    for f in "$scan_dir"/*.md; do
      [ -f "$f" ] || continue
      local base
      base=$(basename "$f")
      local prefix
      prefix=$(echo "${base%.md}" | sed 's/-.*//')
      if [ "$prefix" = "$l" ]; then
        echo "$base"
      fi
    done
  fi
}

# 检查某层是否在 tracked_layers 中
is_tracked() {
  local layer="$1"
  echo "$TRACKED_LAYERS" | grep -qx "$layer" 2>/dev/null
}

# ── 开始校验 ──

for layer in $TRACKED_LAYERS; do
  files=$(get_layer_files_cached "$layer")
  [ -z "$files" ] && continue
  scan_dir=$(get_layer_dir "$layer")

  for fname in $files; do
    filepath="$scan_dir/$fname"
    [ -f "$filepath" ] || continue

    # ====== S1: frontmatter 必填字段 ======
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
      add_check "$layer" "$fname" "S1" "true"
    else
      add_check "$layer" "$fname" "S1" "false" "$s1_detail"
    fi

    # ====== S2: layer 值与文件所在目录/文件名前缀一致 ======
    fm_layer=$(extract_field "$filepath" "layer")
    expected_layer=$(layer_from_filepath "$filepath")
    if [ "$fm_layer" = "$expected_layer" ]; then
      add_check "$layer" "$fname" "S2" "true"
    else
      add_check "$layer" "$fname" "S2" "false" "frontmatter layer 值 '${fm_layer}' 与所在目录/文件名 '${expected_layer}' 不一致"
    fi

    # ====== S3: 结论章节存在且有非空内容 ======
    if has_section "$filepath" "结论"; then
      conclusion_content=$(extract_section_content "$filepath" "结论")
      non_empty=$(echo "$conclusion_content" | grep -v '^[[:space:]]*$' | head -1 || true)
      if [ -n "$non_empty" ]; then
        add_check "$layer" "$fname" "S3" "true"
      else
        add_check "$layer" "$fname" "S3" "false" "结论章节下方没有非空内容"
      fi
    else
      add_check "$layer" "$fname" "S3" "false" "缺少 ## 结论 章节"
    fi

    # ====== S4: 实现清单表格存在且数据行数 > 0 ======
    if has_section "$filepath" "实现清单"; then
      impl_rows=$(extract_section_content "$filepath" "实现清单" | extract_table_data_rows || true)
      impl_row_count=$(echo "$impl_rows" | grep -c '^|' || true)
      if [ "$impl_row_count" -gt 0 ]; then
        add_check "$layer" "$fname" "S4" "true"
      else
        add_check "$layer" "$fname" "S4" "false" "实现清单表格数据行数为 0"
      fi
    else
      add_check "$layer" "$fname" "S4" "false" "缺少 ## 实现清单 章节"
    fi

    # ====== S5: 导出契约存在（仅 domain 和 application） ======
    case "$layer" in
      domain)
        # 新模板：## 导出契约（二级章节）；旧模板：### 导出契约（在 ## 聚合: xxx 下）
        if has_section "$filepath" "导出契约" || has_aggregate_export_contracts "$filepath"; then
          add_check "$layer" "$fname" "S5" "true"
        else
          add_check "$layer" "$fname" "S5" "false" "缺少导出契约章节（## 导出契约 或 ### 导出契约）"
        fi
        ;;
      application)
        if has_section "$filepath" "导出契约"; then
          add_check "$layer" "$fname" "S5" "true"
        else
          add_check "$layer" "$fname" "S5" "false" "缺少 ## 导出契约 章节"
        fi
        ;;
    esac

    # ====== S6: 依赖契约存在（仅 infr、application、ohs） ======
    case "$layer" in
      infr|application|ohs)
        if has_section "$filepath" "依赖契约"; then
          add_check "$layer" "$fname" "S6" "true"
        else
          add_check "$layer" "$fname" "S6" "false" "缺少 ## 依赖契约 章节"
        fi
        ;;
    esac

    # ====== S7: 导出契约中每张子表至少有一行数据（仅 domain 和 application） ======
    case "$layer" in
      domain)
        if has_section "$filepath" "导出契约"; then
          # 新模板：## 导出契约 下的 ### 子表
          export_content=$(extract_section_content "$filepath" "导出契约")
          sub_sections=$(echo "$export_content" | grep '^### ' | sed 's/^### //')
          s7_pass=true
          s7_detail=""
          if [ -n "$sub_sections" ]; then
            while IFS= read -r sub; do
              [ -z "$sub" ] && continue
              sub_content=$(echo "$export_content" | awk -v sec="### ${sub}" '
                $0 == sec { found=1; next }
                found && /^### / { exit }
                found { print }
              ')
              sub_data_rows=$(echo "$sub_content" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | grep -c '^|' || true)
              if [ "$sub_data_rows" -eq 0 ]; then
                s7_pass=false
                s7_detail="导出契约子表 '${sub}' 没有数据行"
                break
              fi
            done <<< "$sub_sections"
          fi
          if [ "$s7_pass" = "true" ]; then
            add_check "$layer" "$fname" "S7" "true"
          else
            add_check "$layer" "$fname" "S7" "false" "$s7_detail"
          fi
        elif has_aggregate_export_contracts "$filepath"; then
          # 旧模板：## 聚合: xxx 下的 ### 导出契约 > #### 子表
          all_export_content=$(extract_all_aggregate_export_content "$filepath")
          sub_sections=$(echo "$all_export_content" | grep '^#### ' | sed 's/^#### //')
          s7_pass=true
          s7_detail=""
          if [ -n "$sub_sections" ]; then
            while IFS= read -r sub; do
              [ -z "$sub" ] && continue
              sub_content=$(extract_all_aggregate_h4_content "$filepath" "$sub")
              sub_data_rows=$(echo "$sub_content" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | grep -c '^|' || true)
              if [ "$sub_data_rows" -eq 0 ]; then
                s7_pass=false
                s7_detail="导出契约子表 '${sub}' 没有数据行"
                break
              fi
            done <<< "$sub_sections"
          fi
          if [ "$s7_pass" = "true" ]; then
            add_check "$layer" "$fname" "S7" "true"
          else
            add_check "$layer" "$fname" "S7" "false" "$s7_detail"
          fi
        fi
        ;;
      application)
        if has_section "$filepath" "导出契约"; then
          export_content=$(extract_section_content "$filepath" "导出契约")
          # 找到所有 ### 子区
          sub_sections=$(echo "$export_content" | grep '^### ' | sed 's/^### //')
          s7_pass=true
          s7_detail=""
          if [ -n "$sub_sections" ]; then
            while IFS= read -r sub; do
              [ -z "$sub" ] && continue
              sub_content=$(echo "$export_content" | awk -v sec="### ${sub}" '
                $0 == sec { found=1; next }
                found && /^### / { exit }
                found { print }
              ')
              sub_data_rows=$(echo "$sub_content" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | grep -c '^|' || true)
              if [ "$sub_data_rows" -eq 0 ]; then
                s7_pass=false
                s7_detail="导出契约子表 '${sub}' 没有数据行"
                break
              fi
            done <<< "$sub_sections"
          fi
          if [ "$s7_pass" = "true" ]; then
            add_check "$layer" "$fname" "S7" "true"
          else
            add_check "$layer" "$fname" "S7" "false" "$s7_detail"
          fi
        fi
        ;;
    esac

    # ====== I1: 导出契约中的方法签名能在正文中找到 ======
    case "$layer" in
      domain)
        if has_section "$filepath" "导出契约"; then
          # 新模板：## 导出契约 下的 ### 子表
          export_content=$(extract_section_content "$filepath" "导出契约")
          body_content=$(extract_body_before_export "$filepath")
          export_sigs=$(echo "$export_content" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
          i1_pass=true
          i1_detail=""
          if [ -n "$export_sigs" ]; then
            while IFS= read -r sig; do
              [ -z "$sig" ] && continue
              if ! echo "$body_content" | grep -qF "$sig"; then
                i1_pass=false
                i1_detail="导出契约中 \`${sig}\` 在正文中未找到对应"
                break
              fi
            done <<< "$export_sigs"
          fi
          if [ "$i1_pass" = "true" ]; then
            add_check "$layer" "$fname" "I1" "true"
          else
            add_check "$layer" "$fname" "I1" "false" "$i1_detail"
          fi
        elif has_aggregate_export_contracts "$filepath"; then
          # 旧模板：## 聚合: xxx 下的 ### 导出契约
          all_export_content=$(extract_all_aggregate_export_content "$filepath")
          body_content=$(extract_aggregate_body_before_export "$filepath")
          export_sigs=$(echo "$all_export_content" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
          i1_pass=true
          i1_detail=""
          if [ -n "$export_sigs" ]; then
            while IFS= read -r sig; do
              [ -z "$sig" ] && continue
              if ! echo "$body_content" | grep -qF "$sig"; then
                i1_pass=false
                i1_detail="导出契约中 \`${sig}\` 在正文中未找到对应"
                break
              fi
            done <<< "$export_sigs"
          fi
          if [ "$i1_pass" = "true" ]; then
            add_check "$layer" "$fname" "I1" "true"
          else
            add_check "$layer" "$fname" "I1" "false" "$i1_detail"
          fi
        fi
        ;;
      application)
        if has_section "$filepath" "导出契约"; then
          export_content=$(extract_section_content "$filepath" "导出契约")
          body_content=$(extract_body_before_export "$filepath")
          export_sigs=$(echo "$export_content" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
          i1_pass=true
          i1_detail=""
          if [ -n "$export_sigs" ]; then
            while IFS= read -r sig; do
              [ -z "$sig" ] && continue
              if ! echo "$body_content" | grep -qF "$sig"; then
                i1_pass=false
                i1_detail="导出契约中 \`${sig}\` 在正文中未找到对应"
                break
              fi
            done <<< "$export_sigs"
          fi
          if [ "$i1_pass" = "true" ]; then
            add_check "$layer" "$fname" "I1" "true"
          else
            add_check "$layer" "$fname" "I1" "false" "$i1_detail"
          fi
        fi
        ;;
    esac

    # ====== I2: 实现清单行数 >= 导出契约子表行数 + 依赖契约子表行数 ======
    if has_section "$filepath" "实现清单"; then
      impl_data_count=$(extract_section_content "$filepath" "实现清单" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | grep -c '^|' || true)

      export_data_count=0
      if [ "$layer" = "domain" ] && has_section "$filepath" "导出契约"; then
        export_data_count=$(extract_section_content "$filepath" "导出契约" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | grep -c '^|' || true)
      elif [ "$layer" = "domain" ] && has_aggregate_export_contracts "$filepath"; then
        export_data_count=$(extract_all_aggregate_export_content "$filepath" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | grep -c '^|' || true)
      elif has_section "$filepath" "导出契约"; then
        export_data_count=$(extract_section_content "$filepath" "导出契约" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | grep -c '^|' || true)
      fi

      dep_data_count=0
      if has_section "$filepath" "依赖契约"; then
        dep_data_count=$(extract_section_content "$filepath" "依赖契约" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | grep -c '^|' || true)
      fi

      required_count=$((export_data_count + dep_data_count))
      if [ "$impl_data_count" -ge "$required_count" ]; then
        add_check "$layer" "$fname" "I2" "true"
      else
        add_check "$layer" "$fname" "I2" "false" "实现清单数据行数(${impl_data_count}) < 导出契约行数(${export_data_count}) + 依赖契约行数(${dep_data_count})"
      fi
    fi

  done
done

# ── C: 跨文件契约匹配 ──

# 辅助：获取某层第一个文件路径（兼容旧版单文件场景）
get_layer_file() {
  local l="$1"
  local files
  files=$(get_layer_files_cached "$l")
  local first
  first=$(echo "$files" | head -1)
  if [ -n "$first" ]; then
    echo "$(get_layer_dir "$l")/$first"
  else
    echo ""
  fi
}

# 辅助：合并某层所有 task 文件的指定 ## 章节内容
# 用于从多个 task 文件中合并导出契约或依赖契约
merge_layer_section() {
  local l="$1" section="$2"
  local files scan_dir
  files=$(get_layer_files_cached "$l")
  scan_dir=$(get_layer_dir "$l")
  for fname in $files; do
    local fpath="$scan_dir/$fname"
    [ -f "$fpath" ] || continue
    if has_section "$fpath" "$section"; then
      extract_section_content "$fpath" "$section"
    fi
  done
}

# 辅助：合并某层所有 task 文件的指定 ### 子章节内容
merge_layer_subsection() {
  local l="$1" subsection="$2"
  local files scan_dir
  files=$(get_layer_files_cached "$l")
  scan_dir=$(get_layer_dir "$l")
  for fname in $files; do
    local fpath="$scan_dir/$fname"
    [ -f "$fpath" ] || continue
    extract_subsection_content "$fpath" "$subsection"
  done
}

# 辅助：合并某层所有 task 文件的指定 #### 子章节内容
merge_layer_h4_section() {
  local l="$1" h4_title="$2"
  local files scan_dir
  files=$(get_layer_files_cached "$l")
  scan_dir=$(get_layer_dir "$l")
  for fname in $files; do
    local fpath="$scan_dir/$fname"
    [ -f "$fpath" ] || continue
    extract_h4_section_content "$fpath" "$h4_title"
  done
}

# 辅助：获取 domain 层所有文件合并后的导出契约中指定子表签名
# 新模板：## 导出契约 > ### 子表；旧模板：## 聚合: xxx > ### 导出契约 > #### 子表
get_domain_export_sigs() {
  local sub_title="$1"
  local files scan_dir
  files=$(get_layer_files_cached "domain")
  scan_dir=$(get_layer_dir "domain")
  for fname in $files; do
    local fpath="$scan_dir/$fname"
    [ -f "$fpath" ] || continue
    if has_section "$fpath" "导出契约"; then
      # 新模板：从 ## 导出契约 > ### 子表 中提取
      extract_section_content "$fpath" "导出契约" | awk -v sec="### ${sub_title}" '
        $0 == sec { found=1; next }
        found && /^### / { exit }
        found { print }
      '
    elif has_aggregate_export_contracts "$fpath"; then
      # 旧模板：从所有聚合的 ### 导出契约 > #### 子表 中提取
      extract_all_aggregate_h4_content "$fpath" "$sub_title"
    fi
  done
}

# ── 预缓存 domain 导出签名（C1/C2/C3 共享）──
CACHED_DOMAIN_IFACE_SIGS=""
CACHED_DOMAIN_AGG_SIGS=""
if is_tracked "domain"; then
  CACHED_DOMAIN_IFACE_SIGS=$(get_domain_export_sigs "接口签名" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
  CACHED_DOMAIN_AGG_SIGS=$(get_domain_export_sigs "聚合根与实体 API" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
fi

# C1: Infr 依赖契约 > 仓储实现契约/Repository 实现 的方法签名 ⊆ Domain 导出契约 > 接口签名
if is_tracked "infr" && is_tracked "domain"; then
  if [ -n "$FILTER_LAYER" ] && [ "$FILTER_LAYER" != "infr" ]; then
    : # 跳过
  else
    infr_files_list=$(get_layer_files_cached "infr")
    domain_iface_sigs="$CACHED_DOMAIN_IFACE_SIGS"
    scan_dir=$(get_layer_dir "infr")
    for fname in $infr_files_list; do
      filepath="$scan_dir/$fname"
      [ -f "$filepath" ] || continue
      # 新模板: #### 仓储实现契约；旧模板: ### Repository 实现
      infr_repo_sigs=""
      if grep -q '^#### 仓储实现契约' "$filepath" 2>/dev/null; then
        infr_repo_sigs=$(extract_h4_section_content "$filepath" "仓储实现契约" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
      else
        infr_repo_sigs=$(extract_subsection_content "$filepath" "Repository 实现" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
      fi
      c1_pass=true
      c1_detail=""
      if [ -n "$infr_repo_sigs" ]; then
        while IFS= read -r sig; do
          [ -z "$sig" ] && continue
          if [ -z "$domain_iface_sigs" ] || ! echo "$domain_iface_sigs" | grep -qxF "$sig"; then
            c1_pass=false
            c1_detail="依赖契约中 \`${sig}\` 在 Domain 导出契约中未找到匹配"
            break
          fi
        done <<< "$infr_repo_sigs"
      fi
      if [ "$c1_pass" = "true" ]; then
        add_check "infr" "$fname" "C1" "true"
      else
        add_check "infr" "$fname" "C1" "false" "$c1_detail"
      fi
    done
  fi
fi

# C2: Application 依赖契约 > 聚合根 API 的方法签名 ⊆ Domain 导出契约 > 聚合根与实体 API
if is_tracked "application" && is_tracked "domain"; then
  if [ -n "$FILTER_LAYER" ] && [ "$FILTER_LAYER" != "application" ]; then
    : # 跳过
  else
    app_files_list=$(get_layer_files_cached "application")
    domain_agg_sigs="$CACHED_DOMAIN_AGG_SIGS"
    scan_dir=$(get_layer_dir "application")
    for fname in $app_files_list; do
      filepath="$scan_dir/$fname"
      [ -f "$filepath" ] || continue
      # 新模板: ##### 聚合根 API（来自已有代码）；旧模板: #### 聚合根 API
      app_agg_sigs=""
      if grep -q '^##### 聚合根 API' "$filepath" 2>/dev/null; then
        # 提取所有 ##### 聚合根 API 子章节内容
        app_agg_sigs=$(awk '
          /^##### 聚合根 API/ { found=1; next }
          found && /^#####/ { found=0; next }
          found && /^####/ { found=0; next }
          found && /^###/ { found=0; next }
          found { print }
        ' "$filepath" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
      else
        app_agg_sigs=$(extract_h4_section_content "$filepath" "聚合根 API" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
      fi
      c2_pass=true
      c2_detail=""
      if [ -n "$app_agg_sigs" ]; then
        while IFS= read -r sig; do
          [ -z "$sig" ] && continue
          if [ -z "$domain_agg_sigs" ] || ! echo "$domain_agg_sigs" | grep -qxF "$sig"; then
            c2_pass=false
            c2_detail="依赖契约中 \`${sig}\` 在 Domain 聚合根与实体 API 中未找到匹配"
            break
          fi
        done <<< "$app_agg_sigs"
      fi
      if [ "$c2_pass" = "true" ]; then
        add_check "application" "$fname" "C2" "true"
      else
        add_check "application" "$fname" "C2" "false" "$c2_detail"
      fi
    done
  fi
fi

# C3: Application 依赖契约 > Repository 接口 的方法签名 ⊆ Domain 导出契约 > 接口签名
if is_tracked "application" && is_tracked "domain"; then
  if [ -n "$FILTER_LAYER" ] && [ "$FILTER_LAYER" != "application" ]; then
    : # 跳过
  else
    app_files_list=$(get_layer_files_cached "application")
    domain_iface_sigs="$CACHED_DOMAIN_IFACE_SIGS"
    scan_dir=$(get_layer_dir "application")
    for fname in $app_files_list; do
      filepath="$scan_dir/$fname"
      [ -f "$filepath" ] || continue
      # 新模板: ##### Repository 接口（来自已有代码）；旧模板: #### Repository 接口
      app_repo_sigs=""
      if grep -q '^##### Repository 接口' "$filepath" 2>/dev/null; then
        app_repo_sigs=$(awk '
          /^##### Repository 接口/ { found=1; next }
          found && /^#####/ { found=0; next }
          found && /^####/ { found=0; next }
          found && /^###/ { found=0; next }
          found { print }
        ' "$filepath" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
      else
        app_repo_sigs=$(extract_h4_section_content "$filepath" "Repository 接口" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
      fi
      c3_pass=true
      c3_detail=""
      if [ -n "$app_repo_sigs" ]; then
        while IFS= read -r sig; do
          [ -z "$sig" ] && continue
          if [ -z "$domain_iface_sigs" ] || ! echo "$domain_iface_sigs" | grep -qxF "$sig"; then
            c3_pass=false
            c3_detail="依赖契约中 \`${sig}\` 在 Domain 接口签名中未找到匹配"
            break
          fi
        done <<< "$app_repo_sigs"
      fi
      if [ "$c3_pass" = "true" ]; then
        add_check "application" "$fname" "C3" "true"
      else
        add_check "application" "$fname" "C3" "false" "$c3_detail"
      fi
    done
  fi
fi

# C4: OHS 依赖契约 > ApplicationService 方法 的方法签名 ⊆ Application 导出契约 > 应用服务 API/ApplicationService 方法
if is_tracked "ohs" && is_tracked "application"; then
  if [ -n "$FILTER_LAYER" ] && [ "$FILTER_LAYER" != "ohs" ]; then
    : # 跳过
  else
    ohs_files_list=$(get_layer_files_cached "ohs")
    # 合并所有 application task 的导出 ApplicationService 方法签名
    # 新模板: ### 应用服务 API；旧模板: ### ApplicationService 方法
    app_svc_sigs=""
    app_svc_sigs_new=$(merge_layer_subsection "application" "应用服务 API" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
    app_svc_sigs_old=$(merge_layer_subsection "application" "ApplicationService 方法" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
    if [ -n "$app_svc_sigs_new" ]; then
      app_svc_sigs="$app_svc_sigs_new"
    fi
    if [ -n "$app_svc_sigs_old" ]; then
      if [ -n "$app_svc_sigs" ]; then
        app_svc_sigs="$app_svc_sigs
$app_svc_sigs_old"
      else
        app_svc_sigs="$app_svc_sigs_old"
      fi
    fi
    scan_dir=$(get_layer_dir "ohs")
    for fname in $ohs_files_list; do
      filepath="$scan_dir/$fname"
      [ -f "$filepath" ] || continue
      # 新模板: #### ApplicationService 方法（来自已有代码）；旧模板: #### ApplicationService 方法
      ohs_svc_sigs=$(extract_h4_section_content "$filepath" "ApplicationService 方法" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
      c4_pass=true
      c4_detail=""
      if [ -n "$ohs_svc_sigs" ]; then
        while IFS= read -r sig; do
          [ -z "$sig" ] && continue
          if [ -z "$app_svc_sigs" ] || ! echo "$app_svc_sigs" | grep -qxF "$sig"; then
            c4_pass=false
            c4_detail="依赖契约中 \`${sig}\` 在 Application 导出契约中未找到匹配"
            break
          fi
        done <<< "$ohs_svc_sigs"
      fi
      if [ "$c4_pass" = "true" ]; then
        add_check "ohs" "$fname" "C4" "true"
      else
        add_check "ohs" "$fname" "C4" "false" "$c4_detail"
      fi
    done
  fi
fi

# C5: OHS 依赖契约 > Command 定义 的每一行 = Application 导出契约 > Command 定义 的对应行（逐行全匹配）
if is_tracked "ohs" && is_tracked "application"; then
  if [ -n "$FILTER_LAYER" ] && [ "$FILTER_LAYER" != "ohs" ]; then
    : # 跳过
  else
    ohs_files_list=$(get_layer_files_cached "ohs")
    # 合并所有 application task 导出契约中的 Command 定义数据行
    app_cmd_rows=$(merge_layer_subsection "application" "Command 定义" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
    scan_dir=$(get_layer_dir "ohs")
    for fname in $ohs_files_list; do
      filepath="$scan_dir/$fname"
      [ -f "$filepath" ] || continue
      # 新模板: #### Command 类列表（来自已有代码）；旧模板: #### Command 定义
      ohs_cmd_rows=""
      if grep -q '^#### Command 类列表' "$filepath" 2>/dev/null; then
        ohs_cmd_rows=$(extract_h4_section_content "$filepath" "Command 类列表" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
      else
        ohs_cmd_rows=$(extract_h4_section_content "$filepath" "Command 定义" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
      fi
      c5_pass=true
      c5_detail=""
      if [ -n "$ohs_cmd_rows" ]; then
        # OHS 新模板的 Command 类列表只有 类名|说明|本层用途，
        # 与 Application 导出契约的 Command 定义 列不同，改为按第一列类名匹配
        while IFS= read -r row; do
          [ -z "$row" ] && continue
          # 提取第一列（类名）
          cmd_class=$(echo "$row" | awk -F'|' '{ if (NF >= 2) { val=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", val); gsub(/`/, "", val); print val } }')
          [ -z "$cmd_class" ] && continue
          if [ -z "$app_cmd_rows" ] || ! echo "$app_cmd_rows" | grep -qF "$cmd_class"; then
            c5_pass=false
            c5_detail="OHS 依赖契约 Command \`${cmd_class}\` 在 Application 导出契约中未找到匹配"
            break
          fi
        done <<< "$ohs_cmd_rows"
      fi
      if [ "$c5_pass" = "true" ]; then
        add_check "ohs" "$fname" "C5" "true"
      else
        add_check "ohs" "$fname" "C5" "false" "$c5_detail"
      fi
    done
  fi
fi

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
  # 默认和 --failures-only 等价：CHECKS 已只含失败项
  echo "{\"status\":\"$STATUS\",\"total\":$TOTAL_COUNT,\"failed\":$FAIL_COUNT,\"checks\":[$CHECKS]}"
fi
