// workflow-lib.mjs — 工作流脚本共享库（从 workflow-lib.sh 迁移）
// 使用方式: import { ... } from './workflow-lib.mjs'
import { readFileSync, writeFileSync, mkdirSync, rmdirSync, renameSync, existsSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { spawnSync } from 'node:child_process';

// ── 文件锁（防止并发写入竞态）──

function acquireLock(lockDir, maxWait = 3000) {
  const start = Date.now();
  while (true) {
    try {
      mkdirSync(lockDir);
      return;
    } catch (e) {
      if (e.code !== 'EEXIST') throw e;
      if (Date.now() - start > maxWait) {
        try { rmdirSync(lockDir); } catch {}
        try { mkdirSync(lockDir); return; } catch {}
      }
      // 短暂等待 100ms
      spawnSync('sleep', ['0.1']);
    }
  }
}

function releaseLock(lockDir) {
  try { rmdirSync(lockDir); } catch {}
}

export function lockedWrite(stateFile, content) {
  mkdirSync(dirname(stateFile), { recursive: true });
  const tmpFile = `${stateFile}.tmp.${process.pid}`;
  writeFileSync(tmpFile, content + '\n', 'utf-8');
  const lockDir = `${stateFile}.lockdir`;
  acquireLock(lockDir);
  try {
    renameSync(tmpFile, stateFile);
  } finally {
    releaseLock(lockDir);
  }
}

export function lockedWriteTask(taskStateFile, content) {
  mkdirSync(dirname(taskStateFile), { recursive: true });
  const tmpFile = `${taskStateFile}.tmp.${process.pid}`;
  writeFileSync(tmpFile, content + '\n', 'utf-8');
  const lockDir = `${taskStateFile}.lockdir`;
  acquireLock(lockDir);
  try {
    renameSync(tmpFile, taskStateFile);
  } finally {
    releaseLock(lockDir);
  }
}

// ── YAML 读取函数（行级解析，与 shell 版行为对齐）──

export function readIdea(stateFile) {
  if (!existsSync(stateFile)) return '';
  const content = readFileSync(stateFile, 'utf-8');
  for (const line of content.split('\n')) {
    const m = line.match(/^idea:\s*(.*)/);
    if (m) return m[1].trim();
  }
  return '';
}

export function getTrackedLayers(stateFile) {
  if (!existsSync(stateFile)) return [];
  const content = readFileSync(stateFile, 'utf-8');
  const lines = content.split('\n');
  let inLayers = false;
  const layers = [];
  for (const line of lines) {
    if (line === 'layers:') { inLayers = true; continue; }
    if (inLayers && /^[^ ]/.test(line)) break;
    if (inLayers && /^  [a-zA-Z]/.test(line)) {
      const name = line.replace(/:.*/, '').trim();
      if (name) layers.push(name);
    }
  }
  return layers;
}

export function getTrackedStatus(stateFile, layer) {
  if (!existsSync(stateFile)) return '';
  const content = readFileSync(stateFile, 'utf-8');
  const lines = content.split('\n');
  let inLayers = false;
  for (const line of lines) {
    if (line === 'layers:') { inLayers = true; continue; }
    if (inLayers && /^[^ ]/.test(line)) break;
    const m = line.match(new RegExp(`^  ${layer}:\\s*(.*)`));
    if (inLayers && m) return m[1].trim();
  }
  return '';
}

export function isTracked(stateFile, layer) {
  return getTrackedLayers(stateFile).includes(layer);
}

export function updateLayerStatus(stateFile, targetLayer, newStatus) {
  if (!existsSync(stateFile)) return;
  let content = readFileSync(stateFile, 'utf-8');
  const re = new RegExp(`^(  ${targetLayer}:)\\s*.*$`, 'm');
  content = content.replace(re, `$1 ${newStatus}`);
  writeFileSync(stateFile, content, 'utf-8');
}

export function initState(stateFile, idea, layers) {
  let content = `idea: ${idea}\nlayers:`;
  for (const layer of layers) {
    content += `\n  ${layer}: pending`;
  }
  lockedWrite(stateFile, content);
}

// ── 设计文件 frontmatter 辅助函数 ──

export function extractField(filePath, field) {
  let content;
  try { content = readFileSync(filePath, 'utf-8'); } catch { return ''; }
  // 提取 frontmatter 区域
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
        return val;
      }
    }
  }
  return '';
}

export function extractDepends(filePath) {
  const raw = extractField(filePath, 'depends_on');
  return raw.replace(/[\[\]]/g, '').replace(/,/g, ' ').replace(/\s+/g, ' ').trim();
}

export function getLayerPhase(workflowFile, layerId) {
  if (!existsSync(workflowFile)) return '';
  const content = readFileSync(workflowFile, 'utf-8');
  const lines = content.split('\n');
  let found = false;
  for (const line of lines) {
    if (line.match(new RegExp(`^  - id: ${layerId}$`))) { found = true; continue; }
    if (found && /^  - id:/.test(line)) break;
    if (found && /phase:/.test(line)) {
      return line.replace(/.*phase:\s*/, '').trim();
    }
  }
  return '';
}

export function getWorkflowStatus(stateFile, layer) {
  return getTrackedStatus(stateFile, layer);
}

// ════════════════════════════════════════════════════
// ── Task 级状态函数 ──
// ════════════════════════════════════════════════════

export function getTaskIds(taskStateFile) {
  if (!existsSync(taskStateFile)) return [];
  const content = readFileSync(taskStateFile, 'utf-8');
  const lines = content.split('\n');
  let inTasks = false;
  const ids = [];
  for (const line of lines) {
    if (/^tasks:/.test(line)) { inTasks = true; continue; }
    if (inTasks && /^[^ ]/.test(line) && !/^tasks:/.test(line)) { inTasks = false; }
    if (inTasks && /^  [a-zA-Z]/.test(line) && !/^    /.test(line)) {
      const id = line.replace(/:.*/, '').trim();
      if (id) ids.push(id);
    }
  }
  return ids;
}

function _getTaskField(taskStateFile, taskId, field) {
  if (!existsSync(taskStateFile)) return '';
  const content = readFileSync(taskStateFile, 'utf-8');
  const lines = content.split('\n');
  let inTasks = false, inTask = false;
  for (const line of lines) {
    if (/^tasks:/.test(line)) { inTasks = true; continue; }
    if (inTasks && /^[^ ]/.test(line) && !/^tasks:/.test(line)) { inTasks = false; }
    if (inTasks && line.match(new RegExp(`^  ${taskId}:`))) { inTask = true; continue; }
    if (inTasks && inTask && /^  [a-zA-Z]/.test(line)) break;
    if (inTask) {
      const m = line.match(new RegExp(`^    ${field}:\\s*(.*)`));
      if (m) {
        let val = m[1].trim();
        val = val.replace(/^["']|["']$/g, '');
        val = val.replace(/^\[|\]$/g, '');
        return val;
      }
    }
  }
  return '';
}

export function getTaskStatus(taskStateFile, taskId) {
  return _getTaskField(taskStateFile, taskId, 'status');
}

export function getTaskLayer(taskStateFile, taskId) {
  return _getTaskField(taskStateFile, taskId, 'layer');
}

export function getTaskFile(taskStateFile, taskId) {
  return _getTaskField(taskStateFile, taskId, 'file');
}

export function getTaskDepends(taskStateFile, taskId) {
  const raw = _getTaskField(taskStateFile, taskId, 'depends_on');
  return raw.replace(/[\[\]]/g, '').replace(/,/g, ' ').replace(/\s+/g, ' ').trim();
}

export function getTaskDescription(taskStateFile, taskId) {
  return _getTaskField(taskStateFile, taskId, 'description');
}

// ── Task 级状态转换合法性校验 ──

export function validateTaskTransition(taskStateFile, taskId, newStatus) {
  const currentStatus = getTaskStatus(taskStateFile, taskId);
  if (!currentStatus) return true; // task 不存在或无状态时放行

  const key = `${currentStatus}:${newStatus}`;
  const validTransitions = new Set([
    'pending:designing', 'designing:designed', 'designed:confirmed',
    'confirmed:coding', 'coding:coded',
    'designing:failed', 'coding:failed', 'failed:pending',
  ]);
  // 任何状态 → failed 或 → pending 允许
  if (newStatus === 'failed' || newStatus === 'pending') return true;
  if (validTransitions.has(key)) return true;

  process.stderr.write(`{"error": "非法 task 状态转换: ${taskId} ${currentStatus} → ${newStatus}"}\n`);
  return false;
}

export function updateTaskStatus(taskStateFile, taskId, newStatus) {
  if (!existsSync(taskStateFile)) return;
  const content = readFileSync(taskStateFile, 'utf-8');
  const lines = content.split('\n');
  let inTasks = false, inTask = false;
  const result = [];
  for (const line of lines) {
    if (/^tasks:/.test(line)) inTasks = true;
    if (inTasks && /^[^ ]/.test(line) && !/^tasks:/.test(line)) inTasks = false;
    if (inTasks && line.match(new RegExp(`^  ${taskId}:`))) inTask = true;
    if (inTasks && inTask && /^  [a-zA-Z]/.test(line) && !line.match(new RegExp(`^  ${taskId}:`))) inTask = false;
    if (inTask && /^    status:/.test(line)) {
      result.push(line.replace(/status:.*/, `status: ${newStatus}`));
    } else {
      result.push(line);
    }
  }
  const tmpFile = `${taskStateFile}.tmp.${process.pid}`;
  writeFileSync(tmpFile, result.join('\n'), 'utf-8');
  const lockDir = `${taskStateFile}.lockdir`;
  acquireLock(lockDir);
  try {
    renameSync(tmpFile, taskStateFile);
  } finally {
    releaseLock(lockDir);
  }
}

export function getTasksByLayer(taskStateFile, targetLayer) {
  const ids = [];
  for (const tid of getTaskIds(taskStateFile)) {
    if (getTaskLayer(taskStateFile, tid) === targetLayer) {
      ids.push(tid);
    }
  }
  return ids;
}

export function aggregateLayerStatus(taskStateFile, layer) {
  const tids = getTasksByLayer(taskStateFile, layer);
  if (tids.length === 0) return 'pending';

  let allCoded = true, anyFailed = false, anyCoding = false, anyDesigning = false;
  let anyConfirmed = false, anyDesigned = false;

  for (const tid of tids) {
    const ts = getTaskStatus(taskStateFile, tid);
    switch (ts) {
      case 'coded': break;
      case 'failed': anyFailed = true; allCoded = false; break;
      case 'coding': anyCoding = true; allCoded = false; break;
      case 'designing': anyDesigning = true; allCoded = false; break;
      case 'confirmed': anyConfirmed = true; allCoded = false; break;
      case 'designed': anyDesigned = true; allCoded = false; break;
      default: allCoded = false; break;
    }
  }

  if (anyFailed) return 'failed';
  if (allCoded) return 'coded';
  if (anyCoding) return 'coding';
  if (anyDesigning) return 'designing';
  if (anyConfirmed) return 'confirmed';
  if (anyDesigned) return 'designed';
  return 'pending';
}

export function syncLayerStatusFromTasks(stateFile, taskStateFile) {
  if (!existsSync(taskStateFile) || !existsSync(stateFile)) return;
  const layers = getTrackedLayers(stateFile);
  for (const layer of layers) {
    const newStatus = aggregateLayerStatus(taskStateFile, layer);
    updateLayerStatus(stateFile, layer, newStatus);
  }
}

export function getNextExecutableTasks(taskStateFile, phase = 'design') {
  const result = [];
  for (const tid of getTaskIds(taskStateFile)) {
    const ts = getTaskStatus(taskStateFile, tid);
    if (phase === 'design' && ts !== 'pending') continue;
    if (phase !== 'design' && ts !== 'confirmed') continue;

    const deps = getTaskDepends(taskStateFile, tid).split(/\s+/).filter(Boolean);
    let depsMet = true;
    for (const dep of deps) {
      const depStatus = getTaskStatus(taskStateFile, dep);
      if (phase === 'design') {
        if (!['designed', 'confirmed', 'coding', 'coded'].includes(depStatus)) { depsMet = false; break; }
      } else {
        if (depStatus !== 'coded') { depsMet = false; break; }
      }
    }
    if (depsMet) result.push(tid);
  }
  return result;
}

export function initTaskState(taskStateFile, idea, taskSpecs) {
  let content = `idea: ${idea}\n\ntasks:`;
  for (const spec of taskSpecs) {
    const parts = spec.split(':');
    const tid = parts[0] || '';
    const tl = parts[1] || '';
    const deps = parts[2] || '';
    const desc = parts[3] || '';
    const tfile = parts[4] || '';
    const depsYaml = deps ? `[${deps.split(',').join(', ')}]` : '[]';
    content += `\n  ${tid}:\n    layer: ${tl}\n    status: pending\n    depends_on: ${depsYaml}\n    description: "${desc}"\n    file: ${tfile}`;
  }
  lockedWriteTask(taskStateFile, content);
}

export function hasTaskState(taskStateFile) {
  return existsSync(taskStateFile);
}

// ── 原子 task 命令 ──

export function startTask(stateFile, taskStateFile, taskId) {
  const current = getTaskStatus(taskStateFile, taskId);
  if (current !== 'confirmed') {
    process.stderr.write(`{"error": "start_task: ${taskId} 当前状态为 ${current}，期望 confirmed"}\n`);
    return false;
  }
  updateTaskStatus(taskStateFile, taskId, 'coding');
  syncLayerStatusFromTasks(stateFile, taskStateFile);
  return true;
}

export function finishTask(stateFile, taskStateFile, taskId, targetStatus) {
  if (targetStatus !== 'coded' && targetStatus !== 'failed') {
    process.stderr.write(`{"error": "finish_task: 无效目标状态 ${targetStatus}，可选 coded|failed"}\n`);
    return false;
  }
  const current = getTaskStatus(taskStateFile, taskId);
  if (current !== 'coding') {
    process.stderr.write(`{"error": "finish_task: ${taskId} 当前状态为 ${current}，期望 coding"}\n`);
    return false;
  }
  updateTaskStatus(taskStateFile, taskId, targetStatus);
  syncLayerStatusFromTasks(stateFile, taskStateFile);
  return true;
}
