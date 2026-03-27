#!/usr/bin/env node
// 后端设计文档校验脚本（从 backend-output-validate.sh 迁移到 Node.js ESM）
// 用法: node backend-output-validate.mjs <idea-dir> [--layer <layer>] [--summary]
// 输出: JSON 格式校验结果

import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { getTrackedLayers, getTrackedStatus } from '../../../../core/scripts/workflow-lib.mjs';
import {
  hasFrontmatterField,
  hasSection,
  extractSectionContent,
  extractSubsectionContent,
  extractH4SectionContent,
  extractTableDataRows,
  extractCol2,
  extractBodyBeforeExport,
  hasAggregateExportContracts,
  extractAllAggregateH4Content,
  extractAllAggregateExportContent,
  extractAggregateBodyBeforeExport,
} from '../../../../core/scripts/markdown-utils.mjs';

// ── CLI 参数解析 ──

const args = process.argv.slice(2);
if (args.length === 0) {
  process.stderr.write('用法: node backend-output-validate.mjs <idea-dir> [--layer <layer>] [--summary]\n');
  process.exit(1);
}

const IDEA_DIR = args[0];
let FILTER_LAYER = '';
let SUMMARY_ONLY = false;

for (let i = 1; i < args.length; i++) {
  if (args[i] === '--layer' && i + 1 < args.length) {
    FILTER_LAYER = args[++i];
  } else if (args[i] === '--summary') {
    SUMMARY_ONLY = true;
  }
}

const BACKEND_DESIGNS_DIR = join(IDEA_DIR, 'backend-designs');
const LAYER_DIRS = ['domain', 'infr', 'application', 'ohs'];
const STATE_FILE = join(IDEA_DIR, 'workflow-state.yaml');

// ── 前置检查 ──

if (!existsSync(BACKEND_DESIGNS_DIR) || !statSync(BACKEND_DESIGNS_DIR).isDirectory()) {
  console.log(JSON.stringify({
    status: 'fail',
    checks: [{ layer: '', file: '', rule: 'INIT', pass: false, detail: 'backend-designs 目录不存在' }],
  }));
  process.exit(1);
}

if (!existsSync(STATE_FILE)) {
  console.log(JSON.stringify({
    status: 'fail',
    checks: [{ layer: '', file: '', rule: 'INIT', pass: false, detail: 'workflow-state.yaml 不存在' }],
  }));
  process.exit(1);
}

// ── 解析 tracked layers ──

function parseTrackedLayers() {
  const allLayers = getTrackedLayers(STATE_FILE);
  const result = [];
  for (const layer of allLayers) {
    const st = getTrackedStatus(STATE_FILE, layer);
    if (st === 'done' || st === 'coded') {
      result.push(layer);
    } else if ((st === 'confirmed' || st === 'coding') && FILTER_LAYER && FILTER_LAYER === layer) {
      result.push(layer);
    }
  }
  return result;
}

let trackedLayers = parseTrackedLayers();

// 如果指定了 --layer，校验层名合法性并过滤
if (FILTER_LAYER) {
  if (!['domain', 'infr', 'application', 'ohs'].includes(FILTER_LAYER)) {
    console.log(JSON.stringify({
      status: 'fail',
      checks: [{ layer: FILTER_LAYER, file: '', rule: 'INIT', pass: false, detail: `无效层名: ${FILTER_LAYER}，可选: domain|infr|application|ohs` }],
    }));
    process.exit(1);
  }
  if (!trackedLayers.includes(FILTER_LAYER)) {
    console.log(JSON.stringify({
      status: 'pass',
      checks: [{ layer: FILTER_LAYER, file: '', rule: 'INIT', pass: true, detail: '该层不在 tracked_layers 中或未完成，跳过校验' }],
    }));
    process.exit(0);
  }
  trackedLayers = [FILTER_LAYER];
}

// ── JSON 输出辅助（默认只记录失败） ──

const checks = [];
let totalCount = 0;
let failCount = 0;

function addCheck(layer, file, rule, pass, detail) {
  totalCount++;
  if (!pass) {
    failCount++;
    const entry = { layer, file, rule, pass: false };
    if (detail) entry.detail = detail;
    checks.push(entry);
  }
}

// ── 辅助函数 ──

/** 从文件提取 frontmatter 字段值 */
function extractField(file, field) {
  let content;
  try { content = readFileSync(file, 'utf-8'); } catch { return ''; }
  const lines = content.split('\n');
  let inFm = false, fmCount = 0;
  for (const line of lines) {
    if (line.trim() === '---') {
      fmCount++;
      if (fmCount === 1) { inFm = true; continue; }
      if (fmCount === 2) break;
    }
    if (inFm) {
      const m = line.match(new RegExp(`^${field}:\\s*(.*)`));
      if (m) {
        let val = m[1].trim();
        if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
          val = val.slice(1, -1);
        }
        return val.trim();
      }
    }
  }
  return '';
}

/** 从完整路径推断 layer 名 */
function layerFromFilepath(fpath) {
  const parentDir = basename(dirname(fpath));
  if (['domain', 'infr', 'application', 'ohs'].includes(parentDir)) {
    return parentDir;
  }
  // 旧模式回退：从文件名前缀推断
  const fname = basename(fpath).replace(/\.md$/, '');
  return fname.replace(/-.*/, '');
}

/** 从内容中提取表格数据行并统计 | 开头的行数 */
function countTableDataRows(content) {
  const rows = extractTableDataRows(content);
  return rows.filter(r => r.startsWith('|')).length;
}

/** 从内容字符串中提取表格第2列签名 */
function getCol2Sigs(content) {
  const rows = extractTableDataRows(content);
  const dataRows = rows.filter(r => r.startsWith('|'));
  return extractCol2(dataRows);
}

// ── 收集各层文件（优先按层分目录，回退到旧版 *.md） ──

let useLayerDirs = false;
for (const layerName of LAYER_DIRS) {
  const layerDir = join(BACKEND_DESIGNS_DIR, layerName);
  if (existsSync(layerDir) && statSync(layerDir).isDirectory()) {
    try {
      const files = readdirSync(layerDir).filter(f => f.endsWith('.md'));
      if (files.length > 0) {
        useLayerDirs = true;
        break;
      }
    } catch { /* ignore */ }
  }
}

/** 获取某层的文件目录 */
function getLayerDir(l) {
  return useLayerDirs ? join(BACKEND_DESIGNS_DIR, l) : BACKEND_DESIGNS_DIR;
}

/** 获取某层的文件列表（文件名数组） */
function getLayerFilesCached(l) {
  const scanDir = getLayerDir(l);
  if (!existsSync(scanDir) || !statSync(scanDir).isDirectory()) return [];
  try {
    const allFiles = readdirSync(scanDir).filter(f => f.endsWith('.md'));
    if (useLayerDirs) {
      // 新模式：目录即层，目录下所有 .md 都属于该层
      return allFiles;
    }
    // 旧模式：按文件名前缀匹配
    return allFiles.filter(f => {
      const prefix = f.replace(/\.md$/, '').replace(/-.*/, '');
      return prefix === l;
    });
  } catch { return []; }
}

/** 检查某层是否在 trackedLayers 中 */
function isTracked(layer) {
  return trackedLayers.includes(layer);
}

// ── 开始校验 ──

for (const layer of trackedLayers) {
  const files = getLayerFilesCached(layer);
  if (files.length === 0) continue;
  const scanDir = getLayerDir(layer);

  for (const fname of files) {
    const filepath = join(scanDir, fname);
    if (!existsSync(filepath)) continue;

    // ====== S1: frontmatter 必填字段 ======
    let s1Pass = true;
    let s1Detail = '';
    const requiredFields = useLayerDirs
      ? ['task_id', 'layer', 'order', 'status', 'depends_on', 'description']
      : ['layer', 'order', 'status', 'depends_on', 'description'];
    for (const field of requiredFields) {
      if (!hasFrontmatterField(filepath, field)) {
        s1Pass = false;
        s1Detail = `frontmatter 缺少 ${field} 字段`;
        break;
      }
    }
    addCheck(layer, fname, 'S1', s1Pass, s1Pass ? undefined : s1Detail);

    // ====== S2: layer 值与文件所在目录/文件名前缀一致 ======
    const fmLayer = extractField(filepath, 'layer');
    const expectedLayer = layerFromFilepath(filepath);
    if (fmLayer === expectedLayer) {
      addCheck(layer, fname, 'S2', true);
    } else {
      addCheck(layer, fname, 'S2', false, `frontmatter layer 值 '${fmLayer}' 与所在目录/文件名 '${expectedLayer}' 不一致`);
    }

    // ====== S3: 结论章节存在且有非空内容 ======
    if (hasSection(filepath, '结论')) {
      const conclusionContent = extractSectionContent(filepath, '结论');
      const nonEmpty = conclusionContent.split('\n').some(l => l.trim() !== '');
      if (nonEmpty) {
        addCheck(layer, fname, 'S3', true);
      } else {
        addCheck(layer, fname, 'S3', false, '结论章节下方没有非空内容');
      }
    } else {
      addCheck(layer, fname, 'S3', false, '缺少 ## 结论 章节');
    }

    // ====== S4: 实现清单表格存在且数据行数 > 0 ======
    if (hasSection(filepath, '实现清单')) {
      const implContent = extractSectionContent(filepath, '实现清单');
      const implRowCount = countTableDataRows(implContent);
      if (implRowCount > 0) {
        addCheck(layer, fname, 'S4', true);
      } else {
        addCheck(layer, fname, 'S4', false, '实现清单表格数据行数为 0');
      }
    } else {
      addCheck(layer, fname, 'S4', false, '缺少 ## 实现清单 章节');
    }

    // ====== S5: 导出契约存在（仅 domain 和 application） ======
    if (layer === 'domain') {
      if (hasSection(filepath, '导出契约') || hasAggregateExportContracts(filepath)) {
        addCheck(layer, fname, 'S5', true);
      } else {
        addCheck(layer, fname, 'S5', false, '缺少导出契约章节（## 导出契约 或 ### 导出契约）');
      }
    } else if (layer === 'application') {
      if (hasSection(filepath, '导出契约')) {
        addCheck(layer, fname, 'S5', true);
      } else {
        addCheck(layer, fname, 'S5', false, '缺少 ## 导出契约 章节');
      }
    }

    // ====== S6: 依赖契约存在（仅 infr、application、ohs） ======
    if (['infr', 'application', 'ohs'].includes(layer)) {
      if (hasSection(filepath, '依赖契约')) {
        addCheck(layer, fname, 'S6', true);
      } else {
        addCheck(layer, fname, 'S6', false, '缺少 ## 依赖契约 章节');
      }
    }

    // ====== S7: 导出契约中每张子表至少有一行数据（仅 domain 和 application） ======
    if (layer === 'domain') {
      if (hasSection(filepath, '导出契约')) {
        // 新模板：## 导出契约 下的 ### 子表
        const exportContent = extractSectionContent(filepath, '导出契约');
        const subSections = exportContent.split('\n')
          .filter(l => l.startsWith('### '))
          .map(l => l.replace(/^### /, ''));
        let s7Pass = true;
        let s7Detail = '';
        for (const sub of subSections) {
          if (!sub) continue;
          const subContent = extractSubsectionContent(exportContent, sub);
          const subDataRows = countTableDataRows(subContent);
          if (subDataRows === 0) {
            s7Pass = false;
            s7Detail = `导出契约子表 '${sub}' 没有数据行`;
            break;
          }
        }
        addCheck(layer, fname, 'S7', s7Pass, s7Pass ? undefined : s7Detail);
      } else if (hasAggregateExportContracts(filepath)) {
        // 旧模板：## 聚合: xxx 下的 ### 导出契约 > #### 子表
        const allExportContent = extractAllAggregateExportContent(filepath);
        const subSections = allExportContent.split('\n')
          .filter(l => l.startsWith('#### '))
          .map(l => l.replace(/^#### /, ''));
        // 去重
        const uniqueSubs = [...new Set(subSections)];
        let s7Pass = true;
        let s7Detail = '';
        for (const sub of uniqueSubs) {
          if (!sub) continue;
          const subContent = extractAllAggregateH4Content(filepath, sub);
          const subDataRows = countTableDataRows(subContent);
          if (subDataRows === 0) {
            s7Pass = false;
            s7Detail = `导出契约子表 '${sub}' 没有数据行`;
            break;
          }
        }
        addCheck(layer, fname, 'S7', s7Pass, s7Pass ? undefined : s7Detail);
      }
    } else if (layer === 'application') {
      if (hasSection(filepath, '导出契约')) {
        const exportContent = extractSectionContent(filepath, '导出契约');
        const subSections = exportContent.split('\n')
          .filter(l => l.startsWith('### '))
          .map(l => l.replace(/^### /, ''));
        let s7Pass = true;
        let s7Detail = '';
        for (const sub of subSections) {
          if (!sub) continue;
          const subContent = extractSubsectionContent(exportContent, sub);
          const subDataRows = countTableDataRows(subContent);
          if (subDataRows === 0) {
            s7Pass = false;
            s7Detail = `导出契约子表 '${sub}' 没有数据行`;
            break;
          }
        }
        addCheck(layer, fname, 'S7', s7Pass, s7Pass ? undefined : s7Detail);
      }
    }

    // ====== I1: 导出契约中的方法签名能在正文中找到 ======
    if (layer === 'domain') {
      if (hasSection(filepath, '导出契约')) {
        const exportContent = extractSectionContent(filepath, '导出契约');
        const bodyContent = extractBodyBeforeExport(filepath);
        const exportSigs = getCol2Sigs(exportContent);
        let i1Pass = true;
        let i1Detail = '';
        for (const sig of exportSigs) {
          if (!sig) continue;
          if (!bodyContent.includes(sig)) {
            i1Pass = false;
            i1Detail = `导出契约中 \`${sig}\` 在正文中未找到对应`;
            break;
          }
        }
        addCheck(layer, fname, 'I1', i1Pass, i1Pass ? undefined : i1Detail);
      } else if (hasAggregateExportContracts(filepath)) {
        const allExportContent = extractAllAggregateExportContent(filepath);
        const bodyContent = extractAggregateBodyBeforeExport(filepath);
        const exportSigs = getCol2Sigs(allExportContent);
        let i1Pass = true;
        let i1Detail = '';
        for (const sig of exportSigs) {
          if (!sig) continue;
          if (!bodyContent.includes(sig)) {
            i1Pass = false;
            i1Detail = `导出契约中 \`${sig}\` 在正文中未找到对应`;
            break;
          }
        }
        addCheck(layer, fname, 'I1', i1Pass, i1Pass ? undefined : i1Detail);
      }
    } else if (layer === 'application') {
      if (hasSection(filepath, '导出契约')) {
        const exportContent = extractSectionContent(filepath, '导出契约');
        const bodyContent = extractBodyBeforeExport(filepath);
        const exportSigs = getCol2Sigs(exportContent);
        let i1Pass = true;
        let i1Detail = '';
        for (const sig of exportSigs) {
          if (!sig) continue;
          if (!bodyContent.includes(sig)) {
            i1Pass = false;
            i1Detail = `导出契约中 \`${sig}\` 在正文中未找到对应`;
            break;
          }
        }
        addCheck(layer, fname, 'I1', i1Pass, i1Pass ? undefined : i1Detail);
      }
    }

    // ====== I2: 实现清单行数 >= 导出契约子表行数 + 依赖契约子表行数 ======
    if (hasSection(filepath, '实现清单')) {
      const implDataCount = countTableDataRows(extractSectionContent(filepath, '实现清单'));

      let exportDataCount = 0;
      if (layer === 'domain' && hasSection(filepath, '导出契约')) {
        exportDataCount = countTableDataRows(extractSectionContent(filepath, '导出契约'));
      } else if (layer === 'domain' && hasAggregateExportContracts(filepath)) {
        exportDataCount = countTableDataRows(extractAllAggregateExportContent(filepath));
      } else if (hasSection(filepath, '导出契约')) {
        exportDataCount = countTableDataRows(extractSectionContent(filepath, '导出契约'));
      }

      let depDataCount = 0;
      if (hasSection(filepath, '依赖契约')) {
        depDataCount = countTableDataRows(extractSectionContent(filepath, '依赖契约'));
      }

      const requiredCount = exportDataCount + depDataCount;
      if (implDataCount >= requiredCount) {
        addCheck(layer, fname, 'I2', true);
      } else {
        addCheck(layer, fname, 'I2', false, `实现清单数据行数(${implDataCount}) < 导出契约行数(${exportDataCount}) + 依赖契约行数(${depDataCount})`);
      }
    }
  }
}

// ── C: 跨文件契约匹配 ──

/** 辅助：合并某层所有 task 文件的指定 ## 章节内容 */
function mergeLayerSection(l, section) {
  const files = getLayerFilesCached(l);
  const scanDir = getLayerDir(l);
  const parts = [];
  for (const fname of files) {
    const fpath = join(scanDir, fname);
    if (!existsSync(fpath)) continue;
    if (hasSection(fpath, section)) {
      parts.push(extractSectionContent(fpath, section));
    }
  }
  return parts.join('\n');
}

/** 辅助：合并某层所有 task 文件的指定 ### 子章节内容 */
function mergeLayerSubsection(l, subsection) {
  const files = getLayerFilesCached(l);
  const scanDir = getLayerDir(l);
  const parts = [];
  for (const fname of files) {
    const fpath = join(scanDir, fname);
    if (!existsSync(fpath)) continue;
    parts.push(extractSubsectionContent(fpath, subsection));
  }
  return parts.join('\n');
}

/** 辅助：合并某层所有 task 文件的指定 #### 子章节内容 */
function mergeLayerH4Section(l, h4Title) {
  const files = getLayerFilesCached(l);
  const scanDir = getLayerDir(l);
  const parts = [];
  for (const fname of files) {
    const fpath = join(scanDir, fname);
    if (!existsSync(fpath)) continue;
    parts.push(extractH4SectionContent(fpath, h4Title));
  }
  return parts.join('\n');
}

/** 获取 domain 层所有文件合并后的导出契约中指定子表签名 */
function getDomainExportSigs(subTitle) {
  const files = getLayerFilesCached('domain');
  const scanDir = getLayerDir('domain');
  const allContent = [];
  for (const fname of files) {
    const fpath = join(scanDir, fname);
    if (!existsSync(fpath)) continue;
    if (hasSection(fpath, '导出契约')) {
      // 新模板：从 ## 导出契约 > ### 子表 中提取
      const exportContent = extractSectionContent(fpath, '导出契约');
      const subContent = extractSubsectionContent(exportContent, subTitle);
      allContent.push(subContent);
    } else if (hasAggregateExportContracts(fpath)) {
      // 旧模板：从所有聚合的 ### 导出契约 > #### 子表 中提取
      allContent.push(extractAllAggregateH4Content(fpath, subTitle));
    }
  }
  return getCol2Sigs(allContent.join('\n'));
}

/** 从文件内容中提取 ##### 级别子章节内容（用于 C2/C3 新模板） */
function extractH5SectionContent(content, section) {
  const lines = content.split('\n');
  let found = false;
  const result = [];
  for (const line of lines) {
    if (line === `##### ${section}`) {
      found = true;
      continue;
    }
    if (found && /^#{2,5} /.test(line)) break;
    if (found) result.push(line);
  }
  return result.join('\n');
}

/** 检查文件是否包含指定的行 */
function fileContainsLine(filepath, linePrefix) {
  let content;
  try { content = readFileSync(filepath, 'utf-8'); } catch { return false; }
  return content.split('\n').some(l => l.startsWith(linePrefix));
}

// ── 预缓存 domain 导出签名（C1/C2/C3 共享）──
let cachedDomainIfaceSigs = [];
let cachedDomainAggSigs = [];
if (isTracked('domain')) {
  cachedDomainIfaceSigs = getDomainExportSigs('接口签名');
  cachedDomainAggSigs = getDomainExportSigs('聚合根与实体 API');
}

// C1: Infr 依赖契约 > 仓储实现契约/Repository 实现 的方法签名 ⊆ Domain 导出契约 > 接口签名
if (isTracked('infr') && isTracked('domain')) {
  if (!FILTER_LAYER || FILTER_LAYER === 'infr') {
    const infrFilesList = getLayerFilesCached('infr');
    const domainIfaceSigs = cachedDomainIfaceSigs;
    const scanDir = getLayerDir('infr');
    for (const fname of infrFilesList) {
      const filepath = join(scanDir, fname);
      if (!existsSync(filepath)) continue;
      // 新模板: #### 仓储实现契约；旧模板: ### Repository 实现
      let infrRepoSigs = [];
      if (fileContainsLine(filepath, '#### 仓储实现契约')) {
        infrRepoSigs = getCol2Sigs(extractH4SectionContent(filepath, '仓储实现契约'));
      } else {
        infrRepoSigs = getCol2Sigs(extractSubsectionContent(filepath, 'Repository 实现'));
      }
      let c1Pass = true;
      let c1Detail = '';
      for (const sig of infrRepoSigs) {
        if (!sig) continue;
        if (domainIfaceSigs.length === 0 || !domainIfaceSigs.includes(sig)) {
          c1Pass = false;
          c1Detail = `依赖契约中 \`${sig}\` 在 Domain 导出契约中未找到匹配`;
          break;
        }
      }
      addCheck('infr', fname, 'C1', c1Pass, c1Pass ? undefined : c1Detail);
    }
  }
}

// C2: Application 依赖契约 > 聚合根 API 的方法签名 ⊆ Domain 导出契约 > 聚合根与实体 API
if (isTracked('application') && isTracked('domain')) {
  if (!FILTER_LAYER || FILTER_LAYER === 'application') {
    const appFilesList = getLayerFilesCached('application');
    const domainAggSigs = cachedDomainAggSigs;
    const scanDir = getLayerDir('application');
    for (const fname of appFilesList) {
      const filepath = join(scanDir, fname);
      if (!existsSync(filepath)) continue;
      // 新模板: ##### 聚合根 API（来自已有代码）；旧模板: #### 聚合根 API
      let appAggSigs = [];
      if (fileContainsLine(filepath, '##### 聚合根 API')) {
        // 提取所有 ##### 聚合根 API 子章节内容
        const content = readFileSync(filepath, 'utf-8');
        const lines = content.split('\n');
        let found = false;
        const resultLines = [];
        for (const line of lines) {
          if (line.startsWith('##### 聚合根 API')) { found = true; continue; }
          if (found && /^#{3,5} /.test(line)) { found = false; continue; }
          if (found) resultLines.push(line);
        }
        appAggSigs = getCol2Sigs(resultLines.join('\n'));
      } else {
        appAggSigs = getCol2Sigs(extractH4SectionContent(filepath, '聚合根 API'));
      }
      let c2Pass = true;
      let c2Detail = '';
      for (const sig of appAggSigs) {
        if (!sig) continue;
        if (domainAggSigs.length === 0 || !domainAggSigs.includes(sig)) {
          c2Pass = false;
          c2Detail = `依赖契约中 \`${sig}\` 在 Domain 聚合根与实体 API 中未找到匹配`;
          break;
        }
      }
      addCheck('application', fname, 'C2', c2Pass, c2Pass ? undefined : c2Detail);
    }
  }
}

// C3: Application 依赖契约 > Repository 接口 的方法签名 ⊆ Domain 导出契约 > 接口签名
if (isTracked('application') && isTracked('domain')) {
  if (!FILTER_LAYER || FILTER_LAYER === 'application') {
    const appFilesList = getLayerFilesCached('application');
    const domainIfaceSigs = cachedDomainIfaceSigs;
    const scanDir = getLayerDir('application');
    for (const fname of appFilesList) {
      const filepath = join(scanDir, fname);
      if (!existsSync(filepath)) continue;
      // 新模板: ##### Repository 接口（来自已有代码）；旧模板: #### Repository 接口
      let appRepoSigs = [];
      if (fileContainsLine(filepath, '##### Repository 接口')) {
        const content = readFileSync(filepath, 'utf-8');
        const lines = content.split('\n');
        let found = false;
        const resultLines = [];
        for (const line of lines) {
          if (line.startsWith('##### Repository 接口')) { found = true; continue; }
          if (found && /^#{3,5} /.test(line)) { found = false; continue; }
          if (found) resultLines.push(line);
        }
        appRepoSigs = getCol2Sigs(resultLines.join('\n'));
      } else {
        appRepoSigs = getCol2Sigs(extractH4SectionContent(filepath, 'Repository 接口'));
      }
      let c3Pass = true;
      let c3Detail = '';
      for (const sig of appRepoSigs) {
        if (!sig) continue;
        if (domainIfaceSigs.length === 0 || !domainIfaceSigs.includes(sig)) {
          c3Pass = false;
          c3Detail = `依赖契约中 \`${sig}\` 在 Domain 接口签名中未找到匹配`;
          break;
        }
      }
      addCheck('application', fname, 'C3', c3Pass, c3Pass ? undefined : c3Detail);
    }
  }
}

// C4: OHS 依赖契约 > ApplicationService 方法 的方法签名 ⊆ Application 导出契约 > 应用服务 API/ApplicationService 方法
if (isTracked('ohs') && isTracked('application')) {
  if (!FILTER_LAYER || FILTER_LAYER === 'ohs') {
    const ohsFilesList = getLayerFilesCached('ohs');
    // 合并所有 application task 的导出 ApplicationService 方法签名
    const appSvcSigsNew = getCol2Sigs(mergeLayerSubsection('application', '应用服务 API'));
    const appSvcSigsOld = getCol2Sigs(mergeLayerSubsection('application', 'ApplicationService 方法'));
    const appSvcSigs = [...appSvcSigsNew, ...appSvcSigsOld];

    const scanDir = getLayerDir('ohs');
    for (const fname of ohsFilesList) {
      const filepath = join(scanDir, fname);
      if (!existsSync(filepath)) continue;
      const ohsSvcSigs = getCol2Sigs(extractH4SectionContent(filepath, 'ApplicationService 方法'));
      let c4Pass = true;
      let c4Detail = '';
      for (const sig of ohsSvcSigs) {
        if (!sig) continue;
        if (appSvcSigs.length === 0 || !appSvcSigs.includes(sig)) {
          c4Pass = false;
          c4Detail = `依赖契约中 \`${sig}\` 在 Application 导出契约中未找到匹配`;
          break;
        }
      }
      addCheck('ohs', fname, 'C4', c4Pass, c4Pass ? undefined : c4Detail);
    }
  }
}

// C5: OHS 依赖契约 > Command 定义 的每一行按第一列类名匹配 Application 导出契约 > Command 定义
if (isTracked('ohs') && isTracked('application')) {
  if (!FILTER_LAYER || FILTER_LAYER === 'ohs') {
    const ohsFilesList = getLayerFilesCached('ohs');
    // 合并所有 application task 导出契约中的 Command 定义数据行
    const appCmdContent = mergeLayerSubsection('application', 'Command 定义');
    const appCmdRows = extractTableDataRows(appCmdContent)
      .filter(r => r.startsWith('|'))
      .map(r => r.trim());

    const scanDir = getLayerDir('ohs');
    for (const fname of ohsFilesList) {
      const filepath = join(scanDir, fname);
      if (!existsSync(filepath)) continue;
      // 新模板: #### Command 类列表；旧模板: #### Command 定义
      let ohsCmdContent;
      if (fileContainsLine(filepath, '#### Command 类列表')) {
        ohsCmdContent = extractH4SectionContent(filepath, 'Command 类列表');
      } else {
        ohsCmdContent = extractH4SectionContent(filepath, 'Command 定义');
      }
      const ohsCmdRows = extractTableDataRows(ohsCmdContent)
        .filter(r => r.startsWith('|'))
        .map(r => r.trim());

      let c5Pass = true;
      let c5Detail = '';
      for (const row of ohsCmdRows) {
        if (!row) continue;
        // 提取第一列（类名）
        const cols = row.split('|');
        let cmdClass = '';
        if (cols.length >= 2) {
          cmdClass = cols[1].trim().replace(/`/g, '');
        }
        if (!cmdClass) continue;
        // 在 appCmdRows 中查找包含该类名的行
        if (appCmdRows.length === 0 || !appCmdRows.some(r => r.includes(cmdClass))) {
          c5Pass = false;
          c5Detail = `OHS 依赖契约 Command \`${cmdClass}\` 在 Application 导出契约中未找到匹配`;
          break;
        }
      }
      addCheck('ohs', fname, 'C5', c5Pass, c5Pass ? undefined : c5Detail);
    }
  }
}

// ── 计算最终状态并输出 ──

const status = failCount === 0 ? 'pass' : 'fail';

if (SUMMARY_ONLY) {
  // --summary: 精简摘要
  const failedRulesSet = new Set();
  for (const chk of checks) {
    failedRulesSet.add(chk.rule);
  }
  const failedRules = [...failedRulesSet].sort();
  console.log(JSON.stringify({ status, total: totalCount, failed: failCount, failed_rules: failedRules }));
} else {
  // 默认：CHECKS 已只含失败项
  console.log(JSON.stringify({ status, total: totalCount, failed: failCount, checks }));
}
