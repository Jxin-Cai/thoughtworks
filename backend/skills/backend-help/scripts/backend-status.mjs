#!/usr/bin/env node
// backend-status.mjs — 后端设计状态查询脚本（从 backend-status.sh 迁移）
// 用法: node backend-status.mjs <idea-dir> [--pretty|--brief]
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { basename, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { extractField, extractDepends, getLayerPhase, getTrackedLayers, getTrackedStatus as getWorkflowStatus } from '../../../../core/scripts/workflow-lib.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const IDEA_DIR = process.argv[2];
const PRETTY = process.argv[3] || '';

if (!IDEA_DIR) {
  process.stderr.write('用法: node backend-status.mjs <idea-dir> [--pretty|--brief]\n');
  process.exit(1);
}

const BACKEND_DESIGNS_DIR = `${IDEA_DIR}/backend-designs`;
const LAYER_DIRS = ['domain', 'infr', 'application', 'ohs'];
const WORKFLOW = resolve(__dirname, '..', 'workflow.yaml');
const STATE_FILE = `${IDEA_DIR}/workflow-state.yaml`;
const IDEA_NAME = basename(IDEA_DIR);

if (!existsSync(BACKEND_DESIGNS_DIR)) {
  const json = { idea: IDEA_NAME, layers: [], overall: { total: 0, done: 0, pending: 0, in_progress: 0, failed: 0 }, state: 'not_started', next_thoughts: [] };
  if (PRETTY === '--pretty') {
    console.log(`\n== ${IDEA_NAME} ==\n\nState: not_started (backend-designs 目录尚未创建)\n`);
  } else {
    console.log(JSON.stringify(json));
  }
  process.exit(0);
}

// 收集设计文件
let designFiles = [];
for (const layerName of LAYER_DIRS) {
  const layerPath = `${BACKEND_DESIGNS_DIR}/${layerName}`;
  if (existsSync(layerPath)) {
    try {
      for (const f of readdirSync(layerPath)) {
        if (f.endsWith('.md')) designFiles.push(`${layerPath}/${f}`);
      }
    } catch {}
  }
}
if (designFiles.length === 0) {
  try {
    for (const f of readdirSync(BACKEND_DESIGNS_DIR)) {
      if (f.endsWith('.md')) designFiles.push(`${BACKEND_DESIGNS_DIR}/${f}`);
    }
  } catch {}
}

// 收集所有 thought 文件信息
const allEntries = [];
for (const df of designFiles) {
  const filename = basename(df);
  const layer = extractField(df, 'layer');
  if (!layer) continue;
  const order = parseInt(extractField(df, 'order') || '1', 10);
  const status = extractField(df, 'status') || 'pending';
  const description = extractField(df, 'description') || '';
  const taskId = extractField(df, 'task_id') || filename;
  const depends = extractDepends(df);
  allEntries.push({ layer, filename, order, status, description, taskId, depends });
}

// 按 workflow.yaml 中的层顺序获取唯一层
const uniqueLayers = [];
for (const l of LAYER_DIRS) {
  if (allEntries.some(e => e.layer === l) && !uniqueLayers.includes(l)) {
    uniqueLayers.push(l);
  }
}

// 辅助函数
function isLayerWfCoded(checkLayer) {
  const st = getWorkflowStatus(STATE_FILE, checkLayer);
  return st === 'coded' || st === 'done';
}
function isFileDone(checkFile) {
  return allEntries.some(e => e.filename === checkFile && e.status === 'done');
}
function getLayerRequires(layerId) {
  if (!existsSync(WORKFLOW)) return [];
  const content = readFileSync(WORKFLOW, 'utf-8');
  const lines = content.split('\n');
  let found = false;
  for (const line of lines) {
    if (line.match(new RegExp(`^  - id: ${layerId}$`))) { found = true; continue; }
    if (found && /^  - id:/.test(line)) break;
    if (found && /requires:/.test(line)) {
      return line.replace(/.*requires:\s*/, '').replace(/[\[\]]/g, '').split(',').map(s => s.trim()).filter(Boolean);
    }
  }
  return [];
}

// 构建 JSON
const layersResult = [];
let overallTotal = 0, overallDone = 0, overallPending = 0, overallInProgress = 0, overallFailed = 0;

for (const layerId of uniqueLayers) {
  const phase = parseInt(getLayerPhase(WORKFLOW, layerId) || '0', 10);
  const layerEntries = allEntries.filter(e => e.layer === layerId);
  let lTotal = 0, lDone = 0, lPending = 0, lInProgress = 0, lFailed = 0;
  const thoughts = layerEntries.map(e => {
    lTotal++;
    switch (e.status) {
      case 'done': lDone++; break;
      case 'pending': lPending++; break;
      case 'in_progress': lInProgress++; break;
      case 'failed': lFailed++; break;
    }
    const depsArr = e.depends ? e.depends.split(/\s+/).filter(Boolean) : [];
    return { task_id: e.taskId, file: e.filename, order: e.order, status: e.status, depends_on: depsArr, description: e.description };
  });
  overallTotal += lTotal; overallDone += lDone; overallPending += lPending; overallInProgress += lInProgress; overallFailed += lFailed;
  layersResult.push({ id: layerId, phase, thoughts, summary: { total: lTotal, done: lDone, pending: lPending, in_progress: lInProgress, failed: lFailed } });
}

// 计算整体状态
let state;
if (overallFailed > 0) state = 'blocked';
else if (overallTotal === 0) state = 'not_started';
else if (overallDone === overallTotal) state = 'all_done';
else if (overallDone > 0 || overallInProgress > 0) state = 'in_progress';
else state = 'not_started';

// 计算 next_thoughts
const nextThoughts = [];
for (const e of allEntries) {
  if (e.status !== 'pending') continue;
  const requires = getLayerRequires(e.layer);
  let crossOk = true;
  for (const req of requires) {
    if (existsSync(STATE_FILE)) {
      if (!isLayerWfCoded(req)) { crossOk = false; break; }
    }
  }
  if (!crossOk) continue;
  const deps = e.depends ? e.depends.split(/\s+/).filter(Boolean) : [];
  let innerOk = true;
  for (const dep of deps) {
    if (!isFileDone(dep)) { innerOk = false; break; }
  }
  if (!innerOk) continue;
  nextThoughts.push(e.taskId);
}

// workflow_phases
const workflowPhases = {};
if (existsSync(STATE_FILE)) {
  for (const lid of LAYER_DIRS) {
    const wfSt = getWorkflowStatus(STATE_FILE, lid);
    if (wfSt) workflowPhases[lid] = wfSt;
  }
}

// 输出
if (PRETTY === '--pretty') {
  console.log(`\n== ${IDEA_NAME} ==\n`);
  console.log(`${'Layer'.padEnd(15)} ${'Phase'.padEnd(7)} ${'Thoughts'.padEnd(10)} ${'Done'.padEnd(6)} ${'Pending'.padEnd(8)} ${'WF-State'.padEnd(12)} Status`);
  console.log(`${'─'.repeat(15)} ${'─'.repeat(7)} ${'─'.repeat(10)} ${'─'.repeat(6)} ${'─'.repeat(8)} ${'─'.repeat(12)} ${'─'.repeat(10)}`);
  for (const lr of layersResult) {
    const lDone = lr.summary.done, lTotal = lr.summary.total, lPending = lr.summary.pending;
    const statusStr = lDone === lTotal ? '✓ done' : lDone > 0 ? '◐ partial' : '○ pending';
    const wfSt = workflowPhases[lr.id] || '-';
    console.log(`${lr.id.padEnd(15)} ${String(lr.phase).padEnd(7)} ${String(lTotal).padEnd(10)} ${String(lDone).padEnd(6)} ${String(lPending).padEnd(8)} ${wfSt.padEnd(12)} ${statusStr}`);
  }
  console.log(`${'─'.repeat(15)} ${'─'.repeat(7)} ${'─'.repeat(10)} ${'─'.repeat(6)} ${'─'.repeat(8)}`);
  console.log(`${'Total'.padEnd(15)} ${''.padEnd(7)} ${String(overallTotal).padEnd(10)} ${String(overallDone).padEnd(6)} ${String(overallPending).padEnd(8)}`);
  console.log(`\nState: ${state}`);
  if (nextThoughts.length > 0) console.log(`Next:  ${nextThoughts.join(', ')}`);
  console.log('');
} else if (PRETTY === '--brief') {
  console.log(JSON.stringify({ idea: IDEA_NAME, state, overall: { total: overallTotal, done: overallDone, pending: overallPending, failed: overallFailed }, next_thoughts: nextThoughts }));
} else {
  console.log(JSON.stringify({ idea: IDEA_NAME, layers: layersResult, overall: { total: overallTotal, done: overallDone, pending: overallPending, in_progress: overallInProgress, failed: overallFailed }, state, workflow_phases: workflowPhases, next_thoughts: nextThoughts }));
}
