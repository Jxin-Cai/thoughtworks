// markdown-utils.mjs — 共享 Markdown 解析工具
// 供 validate 和 status 脚本使用
import { readFileSync } from 'node:fs';

/**
 * 从文件内容提取 YAML frontmatter（--- 之间的内容）
 * @param {string} content - 文件完整内容
 * @returns {string} frontmatter 文本（不含 --- 分隔符）
 */
export function extractFrontmatterText(content) {
  const lines = content.split('\n');
  let start = -1, end = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim() === '---') {
      if (start === -1) { start = i; }
      else { end = i; break; }
    }
  }
  if (start === -1 || end === -1) return '';
  return lines.slice(start + 1, end).join('\n');
}

/**
 * 从 frontmatter 中提取指定字段值
 * @param {string} filePath - 文件路径
 * @param {string} field - 字段名
 * @returns {string} 字段值（去掉引号和首尾空白）
 */
export function extractField(filePath, field) {
  let content;
  try { content = readFileSync(filePath, 'utf-8'); } catch { return ''; }
  const fm = extractFrontmatterText(content);
  for (const line of fm.split('\n')) {
    const m = line.match(new RegExp(`^${field}:\\s*(.*)`));
    if (m) {
      let val = m[1].trim();
      // 去掉引号
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.slice(1, -1);
      }
      return val;
    }
  }
  return '';
}

/**
 * 从 frontmatter 中提取 depends_on 数组
 * @param {string} filePath - 文件路径
 * @returns {string} 空格分隔的依赖列表
 */
export function extractDepends(filePath) {
  const raw = extractField(filePath, 'depends_on');
  return raw.replace(/[\[\]]/g, '').replace(/,/g, ' ').replace(/\s+/g, ' ').trim();
}

/**
 * 检查 frontmatter 是否包含某字段
 */
export function hasFrontmatterField(filePath, field) {
  let content;
  try { content = readFileSync(filePath, 'utf-8'); } catch { return false; }
  const fm = extractFrontmatterText(content);
  return fm.split('\n').some(line => line.match(new RegExp(`^${field}:`)));
}

/**
 * 检查文件是否包含指定级别的章节
 * @param {string} filePath - 文件路径
 * @param {string} section - 章节标题
 * @param {number} level - 标题级别（默认2，即 ##）
 */
export function hasSection(filePath, section, level = 2) {
  let content;
  try { content = readFileSync(filePath, 'utf-8'); } catch { return false; }
  const prefix = '#'.repeat(level) + ' ';
  return content.split('\n').some(line => line === `${prefix}${section}`);
}

/**
 * 提取指定二级章节到下一个同级章节之间的内容
 */
export function extractSectionContent(filePathOrContent, section, level = 2) {
  let content;
  if (filePathOrContent.includes('\n') || !filePathOrContent.includes('/')) {
    content = filePathOrContent;
  } else {
    try { content = readFileSync(filePathOrContent, 'utf-8'); } catch { return ''; }
  }
  const prefix = '#'.repeat(level) + ' ';
  const lines = content.split('\n');
  let found = false;
  const result = [];
  for (const line of lines) {
    if (line === `${prefix}${section}`) {
      found = true;
      continue;
    }
    if (found && line.startsWith(prefix) && !line.startsWith(prefix + '#')) {
      break;
    }
    if (found) result.push(line);
  }
  return result.join('\n');
}

/**
 * 提取指定三级章节（### ）到下一个二级或三级章节之间的内容
 */
export function extractSubsectionContent(filePathOrContent, section) {
  let content;
  if (filePathOrContent.includes('\n') || !filePathOrContent.includes('/')) {
    content = filePathOrContent;
  } else {
    try { content = readFileSync(filePathOrContent, 'utf-8'); } catch { return ''; }
  }
  const lines = content.split('\n');
  let found = false;
  const result = [];
  for (const line of lines) {
    if (line === `### ${section}` || (line.startsWith(`### ${section}`) && line.length === `### ${section}`.length)) {
      found = true;
      continue;
    }
    if (found && /^##[#]? /.test(line)) break;
    if (found) result.push(line);
  }
  return result.join('\n');
}

/**
 * 提取指定四级章节（#### ）内容
 */
export function extractH4SectionContent(filePathOrContent, section) {
  let content;
  if (filePathOrContent.includes('\n') || !filePathOrContent.includes('/')) {
    content = filePathOrContent;
  } else {
    try { content = readFileSync(filePathOrContent, 'utf-8'); } catch { return ''; }
  }
  const lines = content.split('\n');
  let found = false;
  const result = [];
  for (const line of lines) {
    if (line === `#### ${section}` || (line.startsWith(`#### ${section}`) && line.length === `#### ${section}`.length)) {
      found = true;
      continue;
    }
    if (found && /^##[#]?[#]? /.test(line)) break;
    if (found) result.push(line);
  }
  return result.join('\n');
}

/**
 * 从一段内容中提取 markdown 表格数据行（跳过表头和分隔行）
 * @param {string} content - 含表格的文本
 * @returns {string[]} 数据行数组
 */
export function extractTableDataRows(content) {
  const lines = content.split('\n').filter(l => l.startsWith('|'));
  // 去掉分隔行（含 --- 或 ——）
  const nonSep = lines.filter(l => !/^\|[\s\-—|]+$/.test(l));
  // 跳过表头行（第一行）
  return nonSep.slice(1);
}

/**
 * 提取表格指定列（0-indexed）的值，去掉空格和反引号
 * @param {string[]} rows - 表格行（含 | 分隔）
 * @param {number} colIndex - 列索引（0-based，但跳过前导空分隔符，实际从1开始）
 * @returns {string[]} 列值数组
 */
export function extractColumn(rows, colIndex) {
  return rows
    .map(row => {
      const cols = row.split('|');
      if (cols.length > colIndex) {
        return cols[colIndex].trim().replace(/`/g, '');
      }
      return '';
    })
    .filter(v => v !== '');
}

/**
 * 提取表格第二列（方法签名），与 shell 版 extract_col2 对齐
 * 表格格式: | col1 | col2 | col3 | ...
 * split('|') 后 index 0 为空，col1=1, col2=2
 */
export function extractCol2(rows) {
  return extractColumn(rows, 2);
}

/**
 * 提取导出契约之前的正文内容（application 层使用）
 */
export function extractBodyBeforeExport(filePath) {
  let content;
  try { content = readFileSync(filePath, 'utf-8'); } catch { return ''; }
  const lines = content.split('\n');
  let fmCount = 0;
  const result = [];
  for (const line of lines) {
    if (line.trim() === '---') { fmCount++; continue; }
    if (fmCount < 2) continue;
    if (line === '## 导出契约') break;
    result.push(line);
  }
  return result.join('\n');
}

// ── domain 多聚合结构辅助函数 ──

/**
 * 检查 domain.md 是否包含聚合级导出契约（### 导出契约）
 */
export function hasAggregateExportContracts(filePath) {
  let content;
  try { content = readFileSync(filePath, 'utf-8'); } catch { return false; }
  return content.split('\n').some(l => l === '### 导出契约');
}

/**
 * 提取 domain.md 所有聚合的 ### 导出契约下指定 #### 子表的合并内容
 */
export function extractAllAggregateH4Content(filePath, h4Title) {
  let content;
  try { content = readFileSync(filePath, 'utf-8'); } catch { return ''; }
  const lines = content.split('\n');
  let inAgg = false, inExport = false, inH4 = false;
  const result = [];
  const h4Line = `#### ${h4Title}`;
  for (const line of lines) {
    if (line.startsWith('## 聚合:')) { inAgg = true; inExport = false; inH4 = false; continue; }
    if (line.startsWith('## ') && !line.startsWith('## 聚合:')) { inAgg = false; inExport = false; inH4 = false; continue; }
    if (inAgg && line === '### 导出契约') { inExport = true; inH4 = false; continue; }
    if (inAgg && line.startsWith('### ') && line !== '### 导出契约') { inExport = false; inH4 = false; continue; }
    if (inExport && line === h4Line) { inH4 = true; continue; }
    if (inExport && inH4 && line.startsWith('####')) { inH4 = false; continue; }
    if (inExport && inH4 && line.startsWith('###')) { inH4 = false; inExport = false; continue; }
    if (inH4) result.push(line);
  }
  return result.join('\n');
}

/**
 * 提取 domain.md 所有聚合的 ### 导出契约的全部内容（合并）
 */
export function extractAllAggregateExportContent(filePath) {
  let content;
  try { content = readFileSync(filePath, 'utf-8'); } catch { return ''; }
  const lines = content.split('\n');
  let inAgg = false, inExport = false;
  const result = [];
  for (const line of lines) {
    if (line.startsWith('## 聚合:')) { inAgg = true; inExport = false; continue; }
    if (line.startsWith('## ') && !line.startsWith('## 聚合:')) { inAgg = false; inExport = false; continue; }
    if (inAgg && line === '### 导出契约') { inExport = true; continue; }
    if (inAgg && line.startsWith('### ') && line !== '### 导出契约') { inExport = false; continue; }
    if (inExport) result.push(line);
  }
  return result.join('\n');
}

/**
 * 提取 domain.md 中所有聚合章节的正文（导出契约之前的内容合并）
 */
export function extractAggregateBodyBeforeExport(filePath) {
  let content;
  try { content = readFileSync(filePath, 'utf-8'); } catch { return ''; }
  const lines = content.split('\n');
  let inAgg = false, printBody = false;
  const result = [];
  for (const line of lines) {
    if (line.startsWith('## 聚合:')) { inAgg = true; printBody = true; continue; }
    if (line.startsWith('## ') && !line.startsWith('## 聚合:')) { inAgg = false; printBody = false; continue; }
    if (inAgg && line === '### 导出契约') { printBody = false; continue; }
    if (inAgg && line.startsWith('### ') && !printBody) continue;
    if (inAgg && printBody) result.push(line);
  }
  return result.join('\n');
}
