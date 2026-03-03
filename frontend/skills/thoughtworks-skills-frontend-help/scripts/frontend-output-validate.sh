#!/usr/bin/env bash
# 前端设计文档校验脚本
# 用法: frontend-output-validate.sh <idea-dir>

set -euo pipefail

IDEA_DIR="${1:?用法: frontend-output-validate.sh <idea-dir>}"
FRONTEND_DESIGNS_DIR="$IDEA_DIR/frontend-designs"
STATE_FILE="$IDEA_DIR/frontend-workflow-state.json"

if [ ! -d "$FRONTEND_DESIGNS_DIR" ]; then
  echo '{"status":"fail","checks":[{"layer":"","file":"","rule":"INIT","pass":false,"detail":"frontend-designs 目录不存在"}]}'
  exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
  echo '{"status":"fail","checks":[{"layer":"","file":"","rule":"INIT","pass":false,"detail":"frontend-workflow-state.json 不存在"}]}'
  exit 1
fi

CHECKS=""
add_check() {
  local layer="$1" file="$2" rule="$3" pass="$4" detail="${5:-}"
  local entry="{\"layer\":\"$layer\",\"file\":\"$file\",\"rule\":\"$rule\",\"pass\":$pass"
  if [ "$pass" = "false" ] && [ -n "$detail" ]; then
    entry="$entry,\"detail\":\"$detail\""
  fi
  entry="$entry}"
  if [ -z "$CHECKS" ]; then CHECKS="$entry"; else CHECKS="$CHECKS,$entry"; fi
}

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

# 校验所有 frontend-designs/*.md
for filepath in "$FRONTEND_DESIGNS_DIR"/*.md; do
  [ -f "$filepath" ] || continue
  fname=$(basename "$filepath")

  # S1: frontmatter 必填字段
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
    add_check "frontend" "$fname" "S1" "true"
  else
    add_check "frontend" "$fname" "S1" "false" "$s1_detail"
  fi

  # S3: 结论章节存在
  if has_section "$filepath" "结论"; then
    conclusion_content=$(extract_section_content "$filepath" "结论")
    non_empty=$(echo "$conclusion_content" | grep -v '^[[:space:]]*$' | head -1 || true)
    if [ -n "$non_empty" ]; then
      add_check "frontend" "$fname" "S3" "true"
    else
      add_check "frontend" "$fname" "S3" "false" "结论章节下方没有非空内容"
    fi
  else
    add_check "frontend" "$fname" "S3" "false" "缺少 ## 结论 章节"
  fi

  # S4: 实现清单表格存在
  if has_section "$filepath" "实现清单"; then
    impl_rows=$(extract_section_content "$filepath" "实现清单" | grep '^|' | grep -v '^|[[:space:]]*[-—]' | tail -n +2 | grep -c '^|' || true)
    if [ "$impl_rows" -gt 0 ]; then
      add_check "frontend" "$fname" "S4" "true"
    else
      add_check "frontend" "$fname" "S4" "false" "实现清单表格数据行数为 0"
    fi
  else
    add_check "frontend" "$fname" "S4" "false" "缺少 ## 实现清单 章节"
  fi

  # S6: 依赖契约存在
  if has_section "$filepath" "依赖契约"; then
    add_check "frontend" "$fname" "S6" "true"
  else
    add_check "frontend" "$fname" "S6" "false" "缺少 ## 依赖契约 章节"
  fi
done

# C6: Frontend 依赖契约 > API 端点 ⊆ OHS 设计文档 > API 端点（如果 backend-designs/ohs.md 存在）
BACKEND_OHS="$IDEA_DIR/backend-designs/ohs.md"
if [ -f "$BACKEND_OHS" ]; then
  ohs_api_sigs=$(awk '
    /^## API 端点/ { found=1; next }
    found && /^## / { exit }
    found && /^### / { sub(/^### /, ""); print }
  ' "$BACKEND_OHS" || true)

  for filepath in "$FRONTEND_DESIGNS_DIR"/*.md; do
    [ -f "$filepath" ] || continue
    fname=$(basename "$filepath")
    frontend_api_sigs=$(awk '
      /^### API 端点/ { found=1; next }
      found && /^### / { exit }
      found && /^\|/ && !/^\|[[:space:]]*[-—]/ { print }
    ' "$filepath" | tail -n +2 | awk -F'|' '{ if (NF >= 3) { val=$3; gsub(/^[[:space:]]+|[[:space:]]+$/, "", val); gsub(/`/, "", val); if (val != "") print val } }' || true)

    c6_pass=true
    c6_detail=""
    if [ -n "$frontend_api_sigs" ]; then
      while IFS= read -r sig; do
        [ -z "$sig" ] && continue
        if [ -z "$ohs_api_sigs" ] || ! echo "$ohs_api_sigs" | grep -qF "$sig"; then
          c6_pass=false
          c6_detail="Frontend 依赖契约中 \`${sig}\` 在 OHS 设计文档中未找到匹配"
          break
        fi
      done <<< "$frontend_api_sigs"
    fi
    if [ "$c6_pass" = "true" ]; then
      add_check "frontend" "$fname" "C6" "true"
    else
      add_check "frontend" "$fname" "C6" "false" "$c6_detail"
    fi
  done
fi

ALL_PASS=true
if echo "$CHECKS" | grep -q '"pass":false'; then ALL_PASS=false; fi
if [ "$ALL_PASS" = "true" ]; then STATUS="pass"; else STATUS="fail"; fi
echo "{\"status\":\"$STATUS\",\"checks\":[$CHECKS]}"
