#!/usr/bin/env node
// 前端设计文档校验脚本（支持按层分目录和旧版 *.md 目录）
// 用法: node frontend-output-validate.mjs <idea-dir> [--layer <layer>] [--summary]
//
// 校验规则：
// S1: frontmatter 必填字段（按层分目录模式下增加 task_id）
// S3: 结论章节存在且非空
// S4: 实现清单表格存在（frontend-checklist 层文件）
// S6: 依赖契约章节存在
// C6: Frontend 依赖契约 API 端点 ⊆ OHS 已有代码 API 端点（扫描代码或 ohs.md 回退）
// C7: frontend-components 依赖契约 ⊆ frontend-architecture 导出契约（跨文件一致性）

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, basename, dirname } from 'node:path';
import {
  hasFrontmatterField,
  hasSection,
  extractSectionContent,
  extractSubsectionContent,
  extractTableDataRows,
  extractFrontmatterText,
} from '../../../../core/scripts/markdown-utils.mjs';

// ── CLI 参数解析 ──
const args = process.argv.slice(2);
if (args.length === 0) {
  console.error('用法: node frontend-output-validate.mjs <idea-dir> [--layer <layer>] [--summary]');
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

const FRONTEND_DESIGNS_DIR = join(IDEA_DIR, 'frontend-designs');
const VALID_LAYERS = ['frontend-architecture', 'frontend-components', 'frontend-checklist'];
let LAYER_DIRS = [...VALID_LAYERS];
const STATE_FILE = join(IDEA_DIR, 'frontend-workflow-state.yaml');

// ── 前置检查 ──
if (!existsSync(FRONTEND_DESIGNS_DIR) || !statSync(FRONTEND_DESIGNS_DIR).isDirectory()) {
  console.log(JSON.stringify({
    status: 'fail',
    checks: [{ layer: '', file: '', rule: 'INIT', pass: false, detail: 'frontend-designs 目录不存在' }],
  }));
  process.exit(1);
}

if (!existsSync(STATE_FILE)) {
  console.log(JSON.stringify({
    status: 'fail',
    checks: [{ layer: '', file: '', rule: 'INIT', pass: false, detail: 'frontend-workflow-state.yaml 不存在' }],
  }));
  process.exit(1);
}

// ── 判断是否使用按层分目录 ──
let USE_LAYER_DIRS = false;
for (const ld of VALID_LAYERS) {
  const layerPath = join(FRONTEND_DESIGNS_DIR, ld);
  if (existsSync(layerPath) && statSync(layerPath).isDirectory()) {
    const mdFiles = readdirSync(layerPath).filter(f => f.endsWith('.md'));
    if (mdFiles.length > 0) {
      USE_LAYER_DIRS = true;
      break;
    }
  }
}

// ── 辅助函数 ──

function getLayerDir(layer) {
  if (USE_LAYER_DIRS) {
    return join(FRONTEND_DESIGNS_DIR, layer);
  }
  return FRONTEND_DESIGNS_DIR;
}

function getLayerFromFrontmatter(filePath) {
  let content;
  try { content = readFileSync(filePath, 'utf-8'); } catch { return ''; }
  const fm = extractFrontmatterText(content);
  for (const line of fm.split('\n')) {
    const m = line.match(/^layer:\s*(.*)/);
    if (m) return m[1].trim();
  }
  return '';
}

function layerFromFilepath(fpath) {
  const parentDir = basename(dirname(fpath));
  if (VALID_LAYERS.includes(parentDir)) return parentDir;
  const fname = basename(fpath);
  if (/^arch-|^frontend-architecture/.test(fname)) return 'frontend-architecture';
  if (/^comp-|^frontend-components/.test(fname)) return 'frontend-components';
  if (/^impl-|^frontend-checklist/.test(fname)) return 'frontend-checklist';
  return 'frontend';
}

function getLayerFiles(targetLayer) {
  const scanDir = getLayerDir(targetLayer);
  if (!existsSync(scanDir) || !statSync(scanDir).isDirectory()) return [];
  const allMd = readdirSync(scanDir).filter(f => f.endsWith('.md')).sort();
  if (USE_LAYER_DIRS) {
    // 新模式：层目录下所有 .md 都属于该层
    return allMd.filter(f => {
      const fp = join(scanDir, f);
      return existsSync(fp) && statSync(fp).isFile();
    });
  }
  // 旧模式：按 frontmatter 或文件名前缀匹配
  return allMd.filter(f => {
    const fp = join(scanDir, f);
    if (!existsSync(fp) || !statSync(fp).isFile()) return false;
    let fl = getLayerFromFrontmatter(fp);
    if (!fl) fl = layerFromFilepath(fp);
    return fl === targetLayer;
  });
}

/**
 * 合并某层所有文件中指定 ### 子章节内容
 */
function mergeLayerSubsection(targetLayer, subsection) {
  const scanDir = getLayerDir(targetLayer);
  const files = getLayerFiles(targetLayer);
  const parts = [];
  for (const fname of files) {
    const fpath = join(scanDir, fname);
    if (!existsSync(fpath)) continue;
    const content = extractSubsectionContent(fpath, subsection);
    if (content) parts.push(content);
  }
  return parts.join('\n');
}

/**
 * 从表格内容提取第一列值（col index 1，因为 split('|') 后 index 0 为空）
 */
function extractTableCol1Values(content) {
  const rows = extractTableDataRows(content);
  return rows
    .map(row => {
      const cols = row.split('|');
      if (cols.length >= 2) {
        return cols[1].trim();
      }
      return '';
    })
    .filter(v => v !== '');
}

/**
 * 从 ### API 端点 表格提取第二列值（方法签名）
 */
function extractApiEndpointCol2(content) {
  // 提取 ### API 端点 子章节
  const lines = content.split('\n');
  let found = false;
  const sectionLines = [];
  for (const line of lines) {
    if (line === '### API 端点' || (line.startsWith('### API 端点') && line.length === '### API 端点'.length)) {
      found = true;
      continue;
    }
    if (found && /^### /.test(line)) break;
    if (found) sectionLines.push(line);
  }
  const sectionContent = sectionLines.join('\n');
  const rows = extractTableDataRows(sectionContent);
  return rows
    .map(row => {
      const cols = row.split('|');
      if (cols.length >= 3) {
        return cols[2].trim().replace(/`/g, '');
      }
      return '';
    })
    .filter(v => v !== '');
}

// ── JSON 输出辅助（默认只记录失败，减少输出体积）──
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

// ── --layer 过滤 ──
if (FILTER_LAYER) {
  if (!VALID_LAYERS.includes(FILTER_LAYER)) {
    console.log(JSON.stringify({
      status: 'fail',
      checks: [{
        layer: FILTER_LAYER, file: '', rule: 'INIT', pass: false,
        detail: `无效层名: ${FILTER_LAYER}，可选: frontend-architecture|frontend-components|frontend-checklist`,
      }],
    }));
    process.exit(1);
  }
  LAYER_DIRS = [FILTER_LAYER];
}

// ── 开始校验：遍历所有设计文件 ──

for (const layer of LAYER_DIRS) {
  const scanDir = getLayerDir(layer);
  if (!existsSync(scanDir) || !statSync(scanDir).isDirectory()) continue;

  const mdFiles = readdirSync(scanDir).filter(f => f.endsWith('.md')).sort();
  for (const fname of mdFiles) {
    const filepath = join(scanDir, fname);
    if (!existsSync(filepath) || !statSync(filepath).isFile()) continue;

    // 确定文件属于哪个 layer
    let layerId = getLayerFromFrontmatter(filepath);
    if (!layerId) layerId = layerFromFilepath(filepath);

    // 在非按层分目录模式下，只处理属于当前 layer 的文件
    if (!USE_LAYER_DIRS && layerId !== layer) continue;

    // S1: frontmatter 必填字段
    let s1Pass = true;
    let s1Detail = '';
    const requiredFields = USE_LAYER_DIRS
      ? ['task_id', 'layer', 'order', 'status', 'depends_on', 'description']
      : ['layer', 'order', 'status', 'depends_on', 'description'];
    for (const field of requiredFields) {
      if (!hasFrontmatterField(filepath, field)) {
        s1Pass = false;
        s1Detail = `frontmatter 缺少 ${field} 字段`;
        break;
      }
    }
    addCheck(layerId, fname, 'S1', s1Pass, s1Detail);

    // S3: 结论章节存在且非空
    if (hasSection(filepath, '结论')) {
      const conclusionContent = extractSectionContent(filepath, '结论');
      const nonEmpty = conclusionContent.split('\n').some(line => line.trim() !== '');
      if (nonEmpty) {
        addCheck(layerId, fname, 'S3', true);
      } else {
        addCheck(layerId, fname, 'S3', false, '结论章节下方没有非空内容');
      }
    } else {
      addCheck(layerId, fname, 'S3', false, '缺少 ## 结论 章节');
    }

    // S4: 实现清单表格存在（frontend-checklist 层文件）
    if (layerId === 'frontend-checklist' || fname === 'frontend-checklist.md') {
      if (hasSection(filepath, '实现清单')) {
        const implContent = extractSectionContent(filepath, '实现清单');
        const implRows = extractTableDataRows(implContent);
        if (implRows.length > 0) {
          addCheck(layerId, fname, 'S4', true);
        } else {
          addCheck(layerId, fname, 'S4', false, '实现清单表格数据行数为 0');
        }
      } else {
        addCheck(layerId, fname, 'S4', false, '缺少 ## 实现清单 章节');
      }
    }

    // S6: 依赖契约存在
    if (hasSection(filepath, '依赖契约')) {
      addCheck(layerId, fname, 'S6', true);
    } else {
      addCheck(layerId, fname, 'S6', false, '缺少 ## 依赖契约 章节');
    }
  }
}

// ── C6: Frontend 依赖契约 > API 端点 ⊆ OHS API 端点 ──
// --layer 过滤：仅当指定 frontend-architecture 或未指定 --layer 时执行
if (!FILTER_LAYER || FILTER_LAYER === 'frontend-architecture') {
  const archFiles = getLayerFiles('frontend-architecture');
  const archScanDir = getLayerDir('frontend-architecture');
  const frontendApiSigs = [];

  for (const fname of archFiles) {
    const fpath = join(archScanDir, fname);
    if (!existsSync(fpath)) continue;
    const content = readFileSync(fpath, 'utf-8');
    const sigs = extractApiEndpointCol2(content);
    frontendApiSigs.push(...sigs);
  }

  if (frontendApiSigs.length > 0) {
    // 收集 OHS API 端点签名
    let ohsApiSigs = [];

    // 方式1: 从 backend-designs/ohs/*.md 提取（按层分目录模式）
    const backendOhsDir = join(IDEA_DIR, 'backend-designs', 'ohs');
    if (existsSync(backendOhsDir) && statSync(backendOhsDir).isDirectory()) {
      const ohsFiles = readdirSync(backendOhsDir).filter(f => f.endsWith('.md')).sort();
      for (const ohsFile of ohsFiles) {
        const ohsPath = join(backendOhsDir, ohsFile);
        if (!existsSync(ohsPath) || !statSync(ohsPath).isFile()) continue;
        const content = readFileSync(ohsPath, 'utf-8');
        // 提取 ## API 端点 下的 ### 标题
        const sigs = extractOhsApiSections(content);
        ohsApiSigs.push(...sigs);
      }
    }

    // 方式2: 从旧版 backend-designs/ohs.md 提取
    const backendOhsFile = join(IDEA_DIR, 'backend-designs', 'ohs.md');
    if (ohsApiSigs.length === 0 && existsSync(backendOhsFile)) {
      const content = readFileSync(backendOhsFile, 'utf-8');
      const sigs = extractOhsApiSections(content);
      ohsApiSigs.push(...sigs);
    }

    // 执行匹配
    const archFileForReport = archFiles.length > 0 ? archFiles[0] : 'frontend-architecture.md';
    if (ohsApiSigs.length > 0) {
      let c6Pass = true;
      let c6Detail = '';
      for (const sig of frontendApiSigs) {
        if (!sig) continue;
        if (!ohsApiSigs.some(ohsSig => ohsSig.includes(sig))) {
          c6Pass = false;
          c6Detail = `Frontend 依赖契约中 \`${sig}\` 在 OHS API 端点中未找到匹配`;
          break;
        }
      }
      addCheck('frontend-architecture', archFileForReport, 'C6', c6Pass, c6Detail);
    } else {
      // 无 OHS 设计文件可比对，跳过 C6
      addCheck('frontend-architecture', archFileForReport, 'C6', true,
        'OHS 设计文件不存在，C6 跳过（前端依赖 OHS 代码扫描）');
    }
  }
}

// ── C7: frontend-components 依赖契约 ⊆ frontend-architecture 导出契约 ──
// --layer 过滤：仅当指定 frontend-components 或未指定 --layer 时执行
if (!FILTER_LAYER || FILTER_LAYER === 'frontend-components') {
  // 合并所有 architecture 文件的导出契约
  const archEntityContent = mergeLayerSubsection('frontend-architecture', 'Entity 列表');
  const archEntities = extractTableCol1Values(archEntityContent);

  const archFeatureContent = mergeLayerSubsection('frontend-architecture', 'Feature 列表');
  const archFeatures = extractTableCol1Values(archFeatureContent);

  // 合并所有 components 文件的依赖契约
  const compDepEntityContent = mergeLayerSubsection('frontend-components', 'Entity 列表');
  const compDepEntities = extractTableCol1Values(compDepEntityContent);

  const compDepFeatureContent = mergeLayerSubsection('frontend-components', 'Feature 列表');
  const compDepFeatures = extractTableCol1Values(compDepFeatureContent);

  // 只在有 components 文件时执行 C7
  const compFiles = getLayerFiles('frontend-components');
  const archFiles = getLayerFiles('frontend-architecture');

  if (compFiles.length > 0 && archFiles.length > 0) {
    const compFileForReport = compFiles[0];
    let c7Pass = true;
    let c7Detail = '';

    // 检查 Entity 列表一致性
    if (compDepEntities.length > 0) {
      for (const entity of compDepEntities) {
        if (!entity) continue;
        if (archEntities.length === 0 || !archEntities.some(ae => ae.includes(entity))) {
          c7Pass = false;
          c7Detail = `Components 依赖契约中 Entity \`${entity}\` 在 Architecture 导出契约中未找到`;
          break;
        }
      }
    }

    // 检查 Feature 列表一致性
    if (c7Pass && compDepFeatures.length > 0) {
      for (const feature of compDepFeatures) {
        if (!feature) continue;
        if (archFeatures.length === 0 || !archFeatures.some(af => af.includes(feature))) {
          c7Pass = false;
          c7Detail = `Components 依赖契约中 Feature \`${feature}\` 在 Architecture 导出契约中未找到`;
          break;
        }
      }
    }

    addCheck('frontend-components', compFileForReport, 'C7', c7Pass, c7Detail);
  }
}

// ── 辅助：从 OHS 文件提取 ## API 端点 下的 ### 标题 ──
function extractOhsApiSections(content) {
  const lines = content.split('\n');
  let found = false;
  const sigs = [];
  for (const line of lines) {
    if (line === '## API 端点' || (line.startsWith('## API 端点') && line.length === '## API 端点'.length)) {
      found = true;
      continue;
    }
    if (found && /^## /.test(line) && !line.startsWith('## API 端点')) break;
    if (found && line.startsWith('### ')) {
      sigs.push(line.replace(/^### /, ''));
    }
  }
  return sigs;
}

// ── 计算最终状态并输出 ──
const status = failCount === 0 ? 'pass' : 'fail';

if (SUMMARY_ONLY) {
  // --summary: 精简摘要
  const failedRulesSet = new Set(checks.map(c => c.rule));
  const failedRules = [...failedRulesSet].sort();
  console.log(JSON.stringify({
    status,
    total: totalCount,
    failed: failCount,
    failed_rules: failedRules,
  }));
} else {
  // 默认输出：checks 已只含失败项
  console.log(JSON.stringify({
    status,
    total: totalCount,
    failed: failCount,
    checks,
  }));
}
