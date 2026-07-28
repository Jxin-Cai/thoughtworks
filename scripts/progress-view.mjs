#!/usr/bin/env node
// progress-view.mjs — 工作流进度 DAG 可视化
// 用法: node progress-view.mjs <idea-dir> [backend|frontend|all]
// 输出: ANSI 彩色终端渲染

import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { getTrackedLayers, getTrackedStatus, readIdea } from './workflow-lib.mjs';
import { extractDepends } from './markdown-utils.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ── ANSI 颜色 ──

const C = {
  reset:     '\x1b[0m',
  bold:      '\x1b[1m',
  dim:       '\x1b[2m',
  pending:   '\x1b[90m',
  designing: '\x1b[34m',
  designed:  '\x1b[36m',
  confirmed: '\x1b[33m',
  coding:    '\x1b[38;5;208m',
  coded:     '\x1b[32m',
  failed:    '\x1b[31m',
};

const ICONS = {
  pending:   '○',
  designing: '◐',
  designed:  '◑',
  confirmed: '◕',
  coding:    '⚙',
  coded:     '●',
  failed:    '✗',
};

// ── 收集设计文件（支持平铺和子目录两种结构）──

function collectDesignFiles(designDir) {
  const results = [];
  for (const entry of readdirSync(designDir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      const subDir = join(designDir, entry.name);
      for (const f of readdirSync(subDir).filter(n => n.endsWith('.md'))) {
        results.push({ filePath: join(subDir, f), fileName: f });
      }
    } else if (entry.name.endsWith('.md')) {
      results.push({ filePath: join(designDir, entry.name), fileName: entry.name });
    }
  }
  return results;
}

// ── DAG 构建 ──

function buildDAG(ideaDir, stack) {
  const layers = [];
  const deps = {};

  if (stack === 'backend' || stack === 'all') {
    const stateFile = join(ideaDir, 'workflow-state.yaml');
    if (existsSync(stateFile)) {
      const names = getTrackedLayers(stateFile);
      for (const name of names) {
        const status = getTrackedStatus(stateFile, name);
        layers.push({ name, status: status || 'pending', stack: 'backend' });
        deps[name] = [];
      }
      // 从设计文件读取依赖（支持平铺和子目录两种结构）
      const designDir = join(ideaDir, 'backend-designs');
      if (existsSync(designDir)) {
        const mdFiles = collectDesignFiles(designDir);
        for (const { filePath, fileName } of mdFiles) {
          const depStr = extractDepends(filePath);
          const slug = fileName.replace(/^\d+-/, '').replace(/\.md$/, '');
          const match = layers.find(l => l.stack === 'backend' && slugMatch(l.name, slug));
          if (match && depStr) {
            deps[match.name] = depStr.split(/\s+/).filter(Boolean);
          }
        }
      }
    }
  }

  if (stack === 'frontend' || stack === 'all') {
    const stateFile = join(ideaDir, 'frontend-workflow-state.yaml');
    if (existsSync(stateFile)) {
      const names = getTrackedLayers(stateFile);
      for (const name of names) {
        const status = getTrackedStatus(stateFile, name);
        const key = stack === 'all' ? `fe:${name}` : name;
        layers.push({ name: key, displayName: name, status: status || 'pending', stack: 'frontend' });
        deps[key] = [];
      }
      // 从前端设计文件读取依赖（支持平铺和子目录两种结构）
      const designDir = join(ideaDir, 'frontend-designs');
      if (existsSync(designDir)) {
        const mdFiles = collectDesignFiles(designDir);
        for (const { filePath, fileName } of mdFiles) {
          const depStr = extractDepends(filePath);
          const slug = fileName.replace(/^\d+-/, '').replace(/\.md$/, '');
          const match = layers.find(l => l.stack === 'frontend' && slugMatch(l.displayName || l.name, slug));
          if (match && depStr) {
            const prefix = stack === 'all' ? 'fe:' : '';
            deps[match.name] = depStr.split(/\s+/).filter(Boolean).map(d => `${prefix}${d}`);
          }
        }
      }
    }
  }

  return { layers, deps };
}

function slugMatch(name, slug) {
  return name === slug || name.replace(/[-_]/g, '') === slug.replace(/[-_]/g, '');
}

// ── 拓扑排序 ──

function topoSort(layers, deps) {
  const visited = new Set();
  const result = [];
  const inStack = new Set();

  function visit(name) {
    if (visited.has(name)) return;
    if (inStack.has(name)) return; // 避免循环
    inStack.add(name);
    for (const dep of (deps[name] || [])) {
      visit(dep);
    }
    inStack.delete(name);
    visited.add(name);
    result.push(name);
  }

  for (const layer of layers) {
    visit(layer.name);
  }
  return result;
}

// ── 计算层级深度 ──

function computeDepths(layers, deps) {
  const depths = {};
  const layerNames = new Set(layers.map(l => l.name));

  function getDepth(name) {
    if (depths[name] !== undefined) return depths[name];
    const nodeDeps = (deps[name] || []).filter(d => layerNames.has(d));
    if (nodeDeps.length === 0) {
      depths[name] = 0;
      return 0;
    }
    depths[name] = 0; // 防止循环
    const maxDep = Math.max(...nodeDeps.map(d => getDepth(d)));
    depths[name] = maxDep + 1;
    return depths[name];
  }

  for (const layer of layers) {
    getDepth(layer.name);
  }
  return depths;
}

// ── 进度条渲染 ──

function renderProgressBar(coded, total, width = 30) {
  const pct = total === 0 ? 0 : Math.round((coded / total) * 100);
  const filled = Math.round((coded / total) * width) || 0;
  const empty = width - filled;
  const bar = `${C.coded}${'█'.repeat(filled)}${C.dim}${'░'.repeat(empty)}${C.reset}`;
  return `${bar} ${C.bold}${pct}%${C.reset} (${coded}/${total})`;
}

// ── 获取编排步骤 ──

function getOrcheStep(ideaDir, stack) {
  try {
    const scriptPath = join(__dirname, 'orchestration-status.mjs');
    const output = execFileSync('node', [scriptPath, ideaDir, stack], {
      encoding: 'utf-8',
      timeout: 5000,
    }).trim();
    const stepMatch = output.match(/^resume_step:\s*(.+)$/m);
    return stepMatch ? stepMatch[1].trim() : '—';
  } catch {
    return '—';
  }
}

// ── 主渲染函数 ──

export function renderProgress(ideaDir, stack) {
  const { layers, deps } = buildDAG(ideaDir, stack);

  if (layers.length === 0) {
    return `${C.dim}(无工作流状态数据)${C.reset}`;
  }

  const idea = readIdea(join(ideaDir, 'workflow-state.yaml')) ||
               readIdea(join(ideaDir, 'frontend-workflow-state.yaml')) || '—';

  const lines = [];

  // 标题
  lines.push('');
  lines.push(`${C.bold}┌─ 工作流进度: ${idea} ─────────────────────${C.reset}`);
  lines.push(`${C.bold}│${C.reset}`);

  // 分 stack 渲染
  const stacks = stack === 'all' ? ['backend', 'frontend'] : [stack];

  for (const s of stacks) {
    const stackLayers = layers.filter(l => l.stack === s);
    if (stackLayers.length === 0) continue;

    if (stack === 'all') {
      const label = s === 'backend' ? '后端 (Backend)' : '前端 (Frontend)';
      lines.push(`${C.bold}│  ┌─ ${label} ──────────────────${C.reset}`);
    }

    const prefix = stack === 'all' ? '│  │' : '│';

    // 进度条
    const coded = stackLayers.filter(l => l.status === 'coded').length;
    lines.push(`${prefix}  ${renderProgressBar(coded, stackLayers.length)}`);
    lines.push(`${prefix}`);

    // DAG 渲染
    const depths = computeDepths(stackLayers, deps);
    const sorted = topoSort(stackLayers, deps);
    const sortedLayers = sorted
      .map(name => stackLayers.find(l => l.name === name))
      .filter(Boolean);

    for (let i = 0; i < sortedLayers.length; i++) {
      const layer = sortedLayers[i];
      const isLast = i === sortedLayers.length - 1;
      const connector = isLast ? '└──' : '├──';
      const displayName = layer.displayName || layer.name;
      const color = C[layer.status] || C.pending;
      const icon = ICONS[layer.status] || '?';
      const depth = depths[layer.name] || 0;
      const indent = '  '.repeat(depth);
      const depList = (deps[layer.name] || []).filter(d => layers.some(l => l.name === d));
      const depHint = depList.length > 0 ? ` ${C.dim}← ${depList.map(d => {
        const dl = layers.find(l => l.name === d);
        return dl ? (dl.displayName || dl.name) : d;
      }).join(', ')}${C.reset}` : '';

      lines.push(`${prefix}  ${indent}${connector} ${color}${icon} ${displayName}${C.reset} ${C.dim}(${layer.status})${C.reset}${depHint}`);
    }

    if (stack === 'all') {
      lines.push(`${C.bold}│  └────────────────────────────────${C.reset}`);
    }

    lines.push(`${C.bold}│${C.reset}`);
  }

  // 当前编排步骤
  const step = getOrcheStep(ideaDir, stack);
  lines.push(`${C.bold}│${C.reset}  ${C.dim}当前步骤:${C.reset} ${step}`);
  lines.push(`${C.bold}└──────────────────────────────────────────${C.reset}`);
  lines.push('');

  return lines.join('\n');
}

// ── CLI 入口（仅直接运行时执行）──

const isCLI = process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));

if (isCLI) {
  const ideaDir = process.argv[2];
  const stack = process.argv[3] || 'all';

  if (!ideaDir) {
    console.error('用法: node progress-view.mjs <idea-dir> [backend|frontend|all]');
    process.exit(1);
  }

  if (!existsSync(ideaDir)) {
    console.error(`错误: 目录不存在 ${ideaDir}`);
    process.exit(1);
  }

  // 自动检测 stack
  let effectiveStack = stack;
  if (effectiveStack === 'all') {
    const hasBackend = existsSync(join(ideaDir, 'workflow-state.yaml'));
    const hasFrontend = existsSync(join(ideaDir, 'frontend-workflow-state.yaml'));
    if (hasBackend && !hasFrontend) effectiveStack = 'backend';
    else if (!hasBackend && hasFrontend) effectiveStack = 'frontend';
  }

  console.log(renderProgress(ideaDir, effectiveStack));
}
