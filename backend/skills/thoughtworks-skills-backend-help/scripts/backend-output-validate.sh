#!/usr/bin/env bash
# 后端设计文档校验脚本
# 用法: backend-output-validate.sh <idea-dir> [--layer <layer>]
# 输出: JSON 格式校验结果

set -euo pipefail

IDEA_DIR="${1:?用法: backend-output-validate.sh <idea-dir> [--layer <layer>]}"
shift
FILTER_LAYER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --layer) FILTER_LAYER="$2"; shift 2 ;;
    *) shift ;;
  esac
done

BACKEND_DESIGNS_DIR="$IDEA_DIR/backend-designs"
STATE_FILE="$IDEA_DIR/workflow-state.json"

if [ ! -d "$BACKEND_DESIGNS_DIR" ]; then
  echo '{"status":"fail","checks":[{"layer":"","file":"","rule":"INIT","pass":false,"detail":"backend-designs 目录不存在"}]}'
  exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
  echo '{"status":"fail","checks":[{"layer":"","file":"","rule":"INIT","pass":false,"detail":"workflow-state.json 不存在"}]}'
  exit 1
fi

# ── 解析 workflow-state.json 中的 tracked_layers ──
# 格式: {"idea":"xxx","tracked_layers":{"domain":{"status":"done","files":["domain.md"]},...}}

# 提取所有 tracked layer 名称（status 为 done 的层）
parse_tracked_layers() {
  local content
  content=$(cat "$STATE_FILE")
  # 提取 tracked_layers 对象内的 key
  echo "$content" | sed -n 's/.*"tracked_layers"[[:space:]]*:[[:space:]]*{//p' | sed 's/}[^}]*$//' | \
    grep -oE '"[a-z]+"\s*:\s*\{[^}]*"status"\s*:\s*"done"' | \
    grep -oE '^"[a-z]+"' | tr -d '"'
}

# 提取某层的文件列表
parse_layer_files() {
  local layer="$1"
  local content
  content=$(cat "$STATE_FILE")
  # 提取该层的 files 数组内容
  echo "$content" | grep -oE "\"${layer}\"[[:space:]]*:[[:space:]]*\{[^}]*\}" | \
    grep -oE '"files"[[:space:]]*:[[:space:]]*\[[^]]*\]' | \
    grep -oE '"[^"]*\.md"' | tr -d '"'
}

TRACKED_LAYERS=$(parse_tracked_layers)

# 如果指定了 --layer，只校验该层
if [ -n "$FILTER_LAYER" ]; then
  if ! echo "$TRACKED_LAYERS" | grep -qx "$FILTER_LAYER"; then
    echo "{\"status\":\"pass\",\"checks\":[{\"layer\":\"$FILTER_LAYER\",\"file\":\"\",\"rule\":\"INIT\",\"pass\":true,\"detail\":\"该层不在 tracked_layers 中或未完成，跳过校验\"}]}"
    exit 0
  fi
  TRACKED_LAYERS="$FILTER_LAYER"
fi

# ── JSON 输出辅助 ──
CHECKS=""
add_check() {
  local layer="$1" file="$2" rule="$3" pass="$4" detail="${5:-}"
  local entry="{\"layer\":\"$layer\",\"file\":\"$file\",\"rule\":\"$rule\",\"pass\":$pass"
  if [ "$pass" = "false" ] && [ -n "$detail" ]; then
    entry="$entry,\"detail\":\"$detail\""
  fi
  entry="$entry}"
  if [ -z "$CHECKS" ]; then
    CHECKS="$entry"
  else
    CHECKS="$CHECKS,$entry"
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

# 从文件名前缀推断 layer 名
# domain.md -> domain, infr-1-xxx.md -> infr, application.md -> application, ohs-xxx.md -> ohs
layer_from_filename() {
  local fname="$1"
  local base="${fname%.md}"
  # 取第一个 - 之前的部分，或整个 base
  echo "$base" | sed 's/-.*//'
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

# ── 收集各层文件（bash 3.2 兼容：使用 _LAYER_FILES_<layer> 变量代替关联数组）──

for layer in $TRACKED_LAYERS; do
  files=$(parse_layer_files "$layer")
  eval "_LAYER_FILES_${layer}=\"\$files\""
done

# 获取某层的文件列表
get_layer_files_cached() {
  local l="$1"
  eval "echo \"\${_LAYER_FILES_${l}:-}\""
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

  for fname in $files; do
    filepath="$BACKEND_DESIGNS_DIR/$fname"
    [ -f "$filepath" ] || continue

    # ====== S1: frontmatter 必填字段 ======
    s1_pass=true
    s1_detail=""
    for field in layer order status depends_on description; do
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

    # ====== S2: layer 值与文件名前缀一致 ======
    fm_layer=$(extract_field "$filepath" "layer")
    expected_layer=$(layer_from_filename "$fname")
    if [ "$fm_layer" = "$expected_layer" ]; then
      add_check "$layer" "$fname" "S2" "true"
    else
      add_check "$layer" "$fname" "S2" "false" "frontmatter layer 值 '${fm_layer}' 与文件名前缀 '${expected_layer}' 不一致"
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
        # domain 层：导出契约在 ## 聚合: xxx 下的 ### 导出契约
        if has_aggregate_export_contracts "$filepath"; then
          add_check "$layer" "$fname" "S5" "true"
        else
          add_check "$layer" "$fname" "S5" "false" "缺少 ### 导出契约 章节（应在 ## 聚合: xxx 下）"
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
        # domain 层：检查每个聚合的 ### 导出契约下的 #### 子表
        if has_aggregate_export_contracts "$filepath"; then
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
        # domain 层：从所有聚合的导出契约中提取签名，在聚合正文中查找
        if has_aggregate_export_contracts "$filepath"; then
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
      if [ "$layer" = "domain" ] && has_aggregate_export_contracts "$filepath"; then
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

# 辅助：获取某层第一个文件路径
get_layer_file() {
  local l="$1"
  local files
  files=$(get_layer_files_cached "$l")
  local first
  first=$(echo "$files" | head -1)
  if [ -n "$first" ]; then
    echo "$BACKEND_DESIGNS_DIR/$first"
  else
    echo ""
  fi
}

# C1: Infr 依赖契约 > Repository 实现 的方法签名 ⊆ Domain 导出契约 > 接口签名
if is_tracked "infr" && is_tracked "domain"; then
  if [ -n "$FILTER_LAYER" ] && [ "$FILTER_LAYER" != "infr" ]; then
    : # 跳过
  else
    domain_file=$(get_layer_file "domain")
    infr_files_list=$(get_layer_files_cached "infr")
    if [ -n "$domain_file" ] && [ -f "$domain_file" ]; then
      # domain 多聚合结构：从所有聚合的 ### 导出契约 > #### 接口签名 中合并提取
      domain_iface_sigs=$(extract_all_aggregate_h4_content "$domain_file" "接口签名" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
      for fname in $infr_files_list; do
        filepath="$BACKEND_DESIGNS_DIR/$fname"
        [ -f "$filepath" ] || continue
        infr_repo_sigs=$(extract_subsection_content "$filepath" "Repository 实现" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
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
fi

# C2: Application 依赖契约 > 聚合根 API 的方法签名 ⊆ Domain 导出契约 > 聚合根与实体 API
if is_tracked "application" && is_tracked "domain"; then
  if [ -n "$FILTER_LAYER" ] && [ "$FILTER_LAYER" != "application" ]; then
    : # 跳过
  else
    domain_file=$(get_layer_file "domain")
    app_files_list=$(get_layer_files_cached "application")
    if [ -n "$domain_file" ] && [ -f "$domain_file" ]; then
      # domain 多聚合结构：从所有聚合的 ### 导出契约 > #### 聚合根与实体 API 中合并提取
      domain_agg_sigs=$(extract_all_aggregate_h4_content "$domain_file" "聚合根与实体 API" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
      for fname in $app_files_list; do
        filepath="$BACKEND_DESIGNS_DIR/$fname"
        [ -f "$filepath" ] || continue
        app_agg_sigs=$(extract_h4_section_content "$filepath" "聚合根 API" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
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
fi

# C3: Application 依赖契约 > Repository 接口 的方法签名 ⊆ Domain 导出契约 > 接口签名
if is_tracked "application" && is_tracked "domain"; then
  if [ -n "$FILTER_LAYER" ] && [ "$FILTER_LAYER" != "application" ]; then
    : # 跳过
  else
    domain_file=$(get_layer_file "domain")
    app_files_list=$(get_layer_files_cached "application")
    if [ -n "$domain_file" ] && [ -f "$domain_file" ]; then
      # domain 多聚合结构：从所有聚合的 ### 导出契约 > #### 接口签名 中合并提取
      domain_iface_sigs=$(extract_all_aggregate_h4_content "$domain_file" "接口签名" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
      for fname in $app_files_list; do
        filepath="$BACKEND_DESIGNS_DIR/$fname"
        [ -f "$filepath" ] || continue
        app_repo_sigs=$(extract_h4_section_content "$filepath" "Repository 接口" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
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
fi

# C4: OHS 依赖契约 > ApplicationService 方法 的方法签名 ⊆ Application 导出契约 > ApplicationService 方法
if is_tracked "ohs" && is_tracked "application"; then
  if [ -n "$FILTER_LAYER" ] && [ "$FILTER_LAYER" != "ohs" ]; then
    : # 跳过
  else
    app_file=$(get_layer_file "application")
    ohs_files_list=$(get_layer_files_cached "ohs")
    if [ -n "$app_file" ] && [ -f "$app_file" ]; then
      app_svc_sigs=$(extract_subsection_content "$app_file" "ApplicationService 方法" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | extract_col2 || true)
      for fname in $ohs_files_list; do
        filepath="$BACKEND_DESIGNS_DIR/$fname"
        [ -f "$filepath" ] || continue
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
fi

# C5: OHS 依赖契约 > Command 定义 的每一行 = Application 导出契约 > Command 定义 的对应行（逐行全匹配）
if is_tracked "ohs" && is_tracked "application"; then
  if [ -n "$FILTER_LAYER" ] && [ "$FILTER_LAYER" != "ohs" ]; then
    : # 跳过
  else
    app_file=$(get_layer_file "application")
    ohs_files_list=$(get_layer_files_cached "ohs")
    if [ -n "$app_file" ] && [ -f "$app_file" ]; then
      # 提取 Application 导出契约 > Command 定义 的所有数据行（整行，去掉前后空格）
      app_cmd_rows=$(extract_subsection_content "$app_file" "Command 定义" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
      for fname in $ohs_files_list; do
        filepath="$BACKEND_DESIGNS_DIR/$fname"
        [ -f "$filepath" ] || continue
        ohs_cmd_rows=$(extract_h4_section_content "$filepath" "Command 定义" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
        c5_pass=true
        c5_detail=""
        if [ -n "$ohs_cmd_rows" ]; then
          while IFS= read -r row; do
            [ -z "$row" ] && continue
            if [ -z "$app_cmd_rows" ] || ! echo "$app_cmd_rows" | grep -qxF "$row"; then
              # 转义双引号用于 JSON
              escaped_row=$(echo "$row" | sed 's/"/\\"/g')
              c5_pass=false
              c5_detail="OHS 依赖契约 Command 定义行在 Application 导出契约中未找到匹配"
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
fi

# ── 计算最终状态并输出 ──

ALL_PASS=true
if echo "$CHECKS" | grep -q '"pass":false'; then
  ALL_PASS=false
fi

if [ "$ALL_PASS" = "true" ]; then
  STATUS="pass"
else
  STATUS="fail"
fi

echo "{\"status\":\"$STATUS\",\"checks\":[$CHECKS]}"
