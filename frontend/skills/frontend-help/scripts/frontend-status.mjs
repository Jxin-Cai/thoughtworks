#!/usr/bin/env node
// frontend-status.mjs — 前端设计状态查询脚本（从 frontend-status.sh 迁移）
// 用法: node frontend-status.mjs <idea-dir> [--pretty|--brief]
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { basename, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { extractField, extractDepends, getLayerPhase, getTrackedStatus as getWorkflowStatus } from '../../../../core/scripts/workflow-lib.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const IDEA_DIR = process.argv[2];
const PRETTY = process.argv[3] || '';

if (!IDEA_DIR) {
  process.stderr.write('用法: node frontend-status.mjs <idea-dir> [--pretty|--brief]\n');
  process.exit(1);
}

const FRONTEND_DESIGNS_DIR = `${IDEA_DIR}/frontend-designs`;
const LAYER_DIRS = ['frontend-architecture', 'frontend-components', 'frontend-checklist'];
const WORKFLOW = resolve(__dirname, '..', 'workflow.yaml');
const STATE_FILE = `${IDEA_DIR}/frontend-workflow-state.yaml`;
const IDEA_NAME = basename(IDEA_DIR);

if (!existsSync(FRONTEND_DESIGNS_DIR)) {
  const json = { idea: IDEA_NAME, layers: [], overall: { total: 0, done: 0, pending: 0, in_progress: 0, failed: 0 }, state: 'not_started' };
  if (PRETTY === '--pretty') {
    console.log(`\n== ${IDEA_NAME} (frontend) ==\n\nState: not_started (frontend-designs 目录尚未创建)\n`);
  } else {
    console.log(JSON.stringify(json));
  }
  process.exit(0);
}

// 收集设计文件
let designFiles = [];
for (const layerName of LAYER_DIRS) {
  const layerPath = `${FRONTEND_DESIGNS_DIR}/${layerName}`;
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
    for (const f of readdirSync(FRONTEND_DESIGNS_DIR)) {
      if (f.endsWith('.md')) designFiles.push(`${FRONTEND_DESIGNS_DIR}/${f}`);
    }
  } catch {}
}

// frontmatter 读取 layer
function getLayerFromFrontmatter(filePath) {
  return extractField(filePath, 'layer');
}
function layerFromFilepath(fpath) {
  const parentDir = basename(dirname(fpath));
  if (LAYER_DIRS.includes(parentDir)) return parentDir;
  const fname = basename(fpath);
  if (fname.startsWith('arch-') || fname.startsWith('frontend-architecture')) return 'frontend-architecture';
  if (fname.startsWith('comp-') || fname.startsWith('frontend-components')) return 'frontend-components';
  if (fname.startsWith('impl-') || fname.startsWith('frontend-checklist')) return 'frontend-checklist';
  return 'frontend';
}

// 收集 thought 文件信息
const allEntries = [];
for (const df of designFiles) {
  const filename = basename(df);
  let layer = getLayerFromFrontmatter(df);
  if (!layer) layer = layerFromFilepath(df);
  if (!layer) continue;
  const order = parseInt(extractField(df, 'order') || '1', 10);
  const status = extractField(df, 'status') || 'pending';
  const description = extractField(df, 'description') || '';
  const taskId = extractField(df, 'task_id') || filename;
  const depends = extractDepends(df);
  allEntries.push({ layer, filename, order, status, description, taskId, depends });
}

const uniqueLayers = [];
for (const l of LAYER_DIRS) {
  if (allEntries.some(e => e.layer === l) && !uniqueLayers.includes(l)) uniqueLayers.push(l);
}

const layersResult = [];
let overallTotal = 0, overallDone = 0, overallPending = 0, overallInProgress = 0, overallFailed = 0;

for (const layerId of uniqueLayers) {
  const phase = parseInt(getLayerPhase(WORKFLOW, layerId) || '0', 10);
  const layerEntries = allEntries.filter(e => e.layer === layerId);
  let lTotal = 0, lDone = 0, lPending = 0, lInProgress = 0, lFailed = 0;
  const thoughts = layerEntries.map(e => {
    lTotal++;
    switch (e.status) { case 'done': lDone++; break; case 'pending': lPending++; break; case 'in_progress': lInProgress++; break; case 'failed': lFailed++; break; }
    const depsArr = e.depends ? e.depends.split(/\s+/).filter(Boolean) : [];
    return { task_id: e.taskId, file: e.filename, order: e.order, status: e.status, depends_on: depsArr, description: e.description };
  });
  overallTotal += lTotal; overallDone += lDone; overallPending += lPending; overallInProgress += lInProgress; overallFailed += lFailed;
  layersResult.push({ id: layerId, phase, thoughts, summary: { total: lTotal, done: lDone, pending: lPending, in_progress: lInProgress, failed: lFailed } });
}

let state;
if (overallFailed > 0) state = 'blocked';
else if (overallTotal === 0) state = 'not_started';
else if (overallDone === overallTotal) state = 'all_done';
else if (overallDone > 0 || overallInProgress > 0) state = 'in_progress';
else state = 'not_started';

// workflow_phases
const workflowPhases = {};
if (existsSync(STATE_FILE)) {
  for (const lid of LAYER_DIRS) {
    const wfSt = getWorkflowStatus(STATE_FILE, lid);
    if (wfSt) workflowPhases[lid] = wfSt;
  }
}

if (PRETTY === '--pretty') {
  console.log(`\n== ${IDEA_NAME} (frontend) ==\n`);
  console.log(`${'Layer'.padEnd(15)} ${'Phase'.padEnd(7)} ${'Thoughts'.padEnd(10)} ${'Done'.padEnd(6)} ${'Pending'.padEnd(8)} ${'WF-State'.padEnd(12)} Status`);
  console.log(`${'─'.repeat(15)} ${'─'.repeat(7)} ${'─'.repeat(10)} ${'─'.repeat(6)} ${'─'.repeat(8)} ${'─'.repeat(12)} ${'─'.repeat(10)}`);
  for (const lr of layersResult) {
    const statusStr = lr.summary.done === lr.summary.total ? '✓ done' : '○ pending';
    const wfSt = workflowPhases[lr.id] || '-';
    console.log(`${lr.id.padEnd(15)} ${String(lr.phase).padEnd(7)} ${String(lr.summary.total).padEnd(10)} ${String(lr.summary.done).padEnd(6)} ${String(lr.summary.pending).padEnd(8)} ${wfSt.padEnd(12)} ${statusStr}`);
  }
  console.log(`\nState: ${state}\n`);
} else if (PRETTY === '--brief') {
  console.log(JSON.stringify({ idea: IDEA_NAME, state, overall: { total: overallTotal, done: overallDone, pending: overallPending, failed: overallFailed } }));
} else {
  console.log(JSON.stringify({ idea: IDEA_NAME, layers: layersResult, overall: { total: overallTotal, done: overallDone, pending: overallPending, in_progress: overallInProgress, failed: overallFailed }, state, workflow_phases: workflowPhases }));
}
