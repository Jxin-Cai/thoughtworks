#!/usr/bin/env node
// workflow-status.mjs — 统一工作流状态管理脚本（从 workflow-status.sh 迁移）
// 用法: node workflow-status.mjs <idea-dir> <command> [args...]
//   需设置 STACK 环境变量 (backend|frontend)

import { existsSync, readFileSync, realpathSync } from 'node:fs';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import {
  readIdea, getTrackedLayers, getTrackedStatus, isTracked, updateLayerStatus, initState,
  getLayerPhase, getTaskIds, getTaskStatus, getTaskLayer, getTaskFile, getTaskDepends,
  getTaskDescription, validateTaskTransition, updateTaskStatus, syncLayerStatusFromTasks,
  getNextExecutableTasks, initTaskState, hasTaskState, startTask, finishTask,
} from './workflow-lib.mjs';

export async function main(argv) {
  const ideaDir = argv[0];
  const mode = argv[1] || 'status';

  if (!ideaDir) {
    process.stderr.write('用法: workflow-status.mjs <idea-dir> [command] [args...]\n');
    process.exit(1);
  }

  // ── STACK 差异化配置 ──
  const STACK = process.env.STACK;
  if (!STACK || (STACK !== 'backend' && STACK !== 'frontend')) {
    process.stderr.write('{"error": "需要设置 STACK 环境变量 (backend|frontend)"}\n');
    process.exit(1);
  }

  let stateFile, taskStateFile, validLayers, validLayersDisplay;
  if (STACK === 'backend') {
    stateFile = join(ideaDir, 'workflow-state.yaml');
    taskStateFile = join(ideaDir, 'task-workflow-state.yaml');
    validLayers = ['domain', 'infr', 'application', 'ohs'];
    validLayersDisplay = 'domain|infr|application|ohs';
  } else {
    stateFile = join(ideaDir, 'frontend-workflow-state.yaml');
    taskStateFile = join(ideaDir, 'frontend-task-workflow-state.yaml');
    validLayers = ['frontend-architecture', 'frontend-components', 'frontend-checklist'];
    validLayersDisplay = 'frontend-architecture, frontend-components, frontend-checklist';
  }

  // ── 定位脚本目录和 validate 脚本 ──
  const __dirname = dirname(fileURLToPath(import.meta.url));
  const callerDir = process.env.CALLER_SCRIPT_DIR || __dirname;
  let validateScript, workflowFile;
  if (STACK === 'backend') {
    validateScript = resolve(callerDir, 'backend-output-validate.mjs');
    workflowFile = resolve(callerDir, '..', 'workflow.yaml');
  } else {
    validateScript = resolve(callerDir, 'frontend-output-validate.mjs');
    workflowFile = resolve(callerDir, '..', 'workflow.yaml');
  }

  // ── 层级状态转换合法性校验 ──
  function validateTransition(layer, newStatus) {
    const currentStatus = getTrackedStatus(stateFile, layer);
    if (!currentStatus) return true;
    const validTransitions = new Set([
      'pending:designing', 'designing:designed', 'designed:confirmed',
      'confirmed:coding', 'coding:coded',
      'designing:failed', 'coding:failed', 'failed:pending',
    ]);
    if (newStatus === 'failed' || newStatus === 'pending') return true;
    if (validTransitions.has(`${currentStatus}:${newStatus}`)) return true;
    process.stderr.write(`{"error": "非法状态转换: ${layer} ${currentStatus} → ${newStatus}"}\n`);
    return false;
  }

  // ── 后端独有函数 ──
  function getRequires(layerId) {
    if (!existsSync(workflowFile)) return [];
    const content = readFileSync(workflowFile, 'utf-8');
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

  const validStatuses = ['pending', 'designing', 'designed', 'confirmed', 'coding', 'coded', 'failed'];

  // ── 模式分发 ──
  switch (mode) {
    case 'status':
    case '--status': {
      if (!existsSync(stateFile)) {
        process.stderr.write(`{"error": "${stateFile.split('/').pop()} 不存在"}\n`);
        process.exit(1);
      }
      const idea = readIdea(stateFile);
      const tracked = getTrackedLayers(stateFile);
      let hasDone = false, hasInProgress = false, hasFailed = false, hasPending = false;
      let allDone = true, allPending = true;
      const layerEntries = [];
      for (const layer of tracked) {
        const st = getTrackedStatus(stateFile, layer);
        layerEntries.push(`"${layer}": { "status": "${st}" }`);
        switch (st) {
          case 'done': case 'coded': hasDone = true; break;
          case 'designing': case 'coding': hasInProgress = true; allDone = false; allPending = false; break;
          case 'designed': case 'confirmed': allDone = false; allPending = false; break;
          case 'failed': hasFailed = true; allDone = false; allPending = false; break;
          case 'pending': hasPending = true; allDone = false; break;
          default: allDone = false; allPending = false; break;
        }
      }
      let overall;
      if (allDone && tracked.length > 0) overall = 'all_done';
      else if (hasFailed) overall = 'blocked';
      else if (hasInProgress) overall = 'in_progress';
      else if (allPending) overall = 'not_started';
      else overall = 'in_progress';
      console.log(`{ "idea": "${idea}", "tracked_layers": { ${layerEntries.join(', ')} }, "overall": "${overall}" }`);
      break;
    }

    case '--init': {
      const ideaName = argv[2];
      const layers = argv.slice(3);
      if (!ideaName) { process.stderr.write('{"error": "--init 需要指定 idea-name"}\n'); process.exit(1); }
      if (layers.length === 0) { process.stderr.write('{"error": "--init 需要至少一个层名"}\n'); process.exit(1); }
      for (const layer of layers) {
        if (!validLayers.includes(layer)) {
          process.stderr.write(`{"error": "无效层名: ${layer}, 可选: ${validLayersDisplay}"}\n`);
          process.exit(1);
        }
      }
      initState(stateFile, ideaName, layers);
      const layersJson = layers.map(l => `"${l}"`).join(', ');
      console.log(`{"initialized": true, "idea": "${ideaName}", "layers": [${layersJson}]}`);
      break;
    }

    case '--set': {
      const layer = argv[2];
      const status = argv[3];
      if (!layer) { process.stderr.write('{"error": "--set 需要指定层名"}\n'); process.exit(1); }
      if (!status) { process.stderr.write('{"error": "--set 需要指定状态"}\n'); process.exit(1); }
      if (!validStatuses.includes(status)) {
        process.stderr.write(`{"error": "无效状态: ${status}，可选: ${validStatuses.join('|')}"}\n`);
        process.exit(1);
      }
      if (!existsSync(stateFile)) {
        process.stderr.write(`{"error": "${stateFile.split('/').pop()} 不存在，请先执行 --init"}\n`);
        process.exit(1);
      }
      if (!isTracked(stateFile, layer)) {
        process.stderr.write(`{"error": "层 ${layer} 不在 tracked_layers 中"}\n`);
        process.exit(1);
      }
      if (!validateTransition(layer, status)) process.exit(1);
      updateLayerStatus(stateFile, layer, status);
      console.log(`{"updated": true, "layer": "${layer}", "status": "${status}"}`);
      break;
    }

    case '--check-upstream': {
      if (STACK !== 'backend') {
        process.stderr.write('{"error": "--check-upstream 仅 backend 支持"}\n');
        process.exit(1);
      }
      const layer = argv[2];
      if (!layer) { process.stderr.write('{"error": "--check-upstream 需要指定层名"}\n'); process.exit(1); }
      if (!existsSync(stateFile)) {
        process.stderr.write(`{"error": "${stateFile.split('/').pop()} 不存在"}\n`);
        process.exit(1);
      }
      const requires = getRequires(layer);
      const waitFor = requires.filter(r => isTracked(stateFile, r));
      if (waitFor.length === 0) {
        console.log(`{"upstream_ready": true, "layer": "${layer}"}`);
        break;
      }
      let allUpstreamDone = true;
      let failedLayer = '';
      const pendingLayers = [];
      for (const req of waitFor) {
        const st = getTrackedStatus(stateFile, req);
        if (st === 'done' || st === 'coded') continue;
        if (st === 'failed') { failedLayer = req; break; }
        allUpstreamDone = false;
        pendingLayers.push(`"${req}"`);
      }
      if (failedLayer) {
        console.log(`{"upstream_ready": false, "layer": "${layer}", "reason": "upstream ${failedLayer} failed"}`);
      } else if (allUpstreamDone) {
        console.log(`{"upstream_ready": true, "layer": "${layer}"}`);
      } else {
        console.log(`{"upstream_ready": false, "layer": "${layer}", "waiting_for": [${pendingLayers.join(', ')}]}`);
      }
      break;
    }

    case '--check-all': {
      if (!existsSync(stateFile)) {
        process.stderr.write(`{"error": "${stateFile.split('/').pop()} 不存在"}\n`);
        process.exit(1);
      }
      let verbose = false, checkLayer = '';
      const restArgs = argv.slice(2);
      for (let i = 0; i < restArgs.length; i++) {
        if (restArgs[i] === '--verbose') verbose = true;
        else if (restArgs[i] === '--layer') checkLayer = restArgs[++i] || '';
      }
      const tracked = getTrackedLayers(stateFile);
      let allDone = true, hasFailed = false;
      for (const layer of tracked) {
        const st = getTrackedStatus(stateFile, layer);
        if (st === 'done' || st === 'coded') continue;
        if (st === 'failed') { hasFailed = true; allDone = false; }
        else allDone = false;
      }
      if (allDone) {
        let validationOutput = '';
        if (existsSync(validateScript)) {
          const vArgs = [validateScript, ideaDir];
          if (checkLayer) vArgs.push('--layer', checkLayer);
          if (!verbose) vArgs.push('--summary');
          try {
            validationOutput = execFileSync('node', vArgs, { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
          } catch (e) {
            validationOutput = e.stdout ? e.stdout.trim() : '';
          }
        }
        if (validationOutput) {
          console.log(`{"overall": "all_done", "validation": ${validationOutput}}`);
        } else {
          console.log('{"overall": "all_done", "validation": {}}');
        }
      } else if (hasFailed) {
        console.log('{"overall": "blocked"}');
      } else {
        console.log('{"overall": "in_progress"}');
      }
      break;
    }

    case '--get-status': {
      const layer = argv[2];
      if (!layer) { process.stderr.write('{"error": "--get-status 需要指定层名"}\n'); process.exit(1); }
      if (!existsSync(stateFile)) process.exit(1);
      if (!isTracked(stateFile, layer)) process.exit(1);
      console.log(getTrackedStatus(stateFile, layer));
      break;
    }

    // ════════════════════════════════════════════════════
    // ── Task 级命令 ──
    // ════════════════════════════════════════════════════

    case '--init-tasks': {
      const ideaName = argv[2];
      const taskSpecs = argv.slice(3);
      if (!ideaName) { process.stderr.write('{"error": "--init-tasks 需要指定 idea-name"}\n'); process.exit(1); }
      if (taskSpecs.length === 0) {
        process.stderr.write('{"error": "--init-tasks 需要至少一个 task 规格 (task_id:layer:depends:description:file)"}\n');
        process.exit(1);
      }
      initTaskState(taskStateFile, ideaName, taskSpecs);
      console.log(`{"initialized": true, "idea": "${ideaName}", "task_count": ${taskSpecs.length}}`);
      break;
    }

    case '--set-task': {
      const taskId = argv[2];
      const taskStatus = argv[3];
      if (!taskId) { process.stderr.write('{"error": "--set-task 需要指定 task_id"}\n'); process.exit(1); }
      if (!taskStatus) { process.stderr.write('{"error": "--set-task 需要指定状态"}\n'); process.exit(1); }
      if (!validStatuses.includes(taskStatus)) {
        process.stderr.write(`{"error": "无效状态: ${taskStatus}"}\n`);
        process.exit(1);
      }
      if (!existsSync(taskStateFile)) {
        process.stderr.write(`{"error": "${taskStateFile.split('/').pop()} 不存在，请先执行 --init-tasks"}\n`);
        process.exit(1);
      }
      if (!validateTaskTransition(taskStateFile, taskId, taskStatus)) process.exit(1);
      updateTaskStatus(taskStateFile, taskId, taskStatus);
      syncLayerStatusFromTasks(stateFile, taskStateFile);
      console.log(`{"updated": true, "task_id": "${taskId}", "status": "${taskStatus}"}`);
      break;
    }

    case '--start-task': {
      const taskId = argv[2];
      if (!taskId) { process.stderr.write('{"error": "--start-task 需要指定 task_id"}\n'); process.exit(1); }
      if (!existsSync(taskStateFile)) {
        process.stderr.write(`{"error": "${taskStateFile.split('/').pop()} 不存在，请先执行 --init-tasks"}\n`);
        process.exit(1);
      }
      if (!existsSync(stateFile)) {
        process.stderr.write(`{"error": "${stateFile.split('/').pop()} 不存在"}\n`);
        process.exit(1);
      }
      if (!startTask(stateFile, taskStateFile, taskId)) process.exit(1);
      console.log(`{"started": true, "task_id": "${taskId}", "status": "coding"}`);
      break;
    }

    case '--finish-task': {
      const taskId = argv[2];
      const taskStatus = argv[3];
      if (!taskId) { process.stderr.write('{"error": "--finish-task 需要指定 task_id"}\n'); process.exit(1); }
      if (!taskStatus) { process.stderr.write('{"error": "--finish-task 需要指定目标状态 (coded|failed)"}\n'); process.exit(1); }
      if (!existsSync(taskStateFile)) {
        process.stderr.write(`{"error": "${taskStateFile.split('/').pop()} 不存在"}\n`);
        process.exit(1);
      }
      if (!existsSync(stateFile)) {
        process.stderr.write(`{"error": "${stateFile.split('/').pop()} 不存在"}\n`);
        process.exit(1);
      }
      if (!finishTask(stateFile, taskStateFile, taskId, taskStatus)) process.exit(1);
      console.log(`{"finished": true, "task_id": "${taskId}", "status": "${taskStatus}"}`);
      break;
    }

    case '--get-task-status': {
      const taskId = argv[2];
      if (!taskId) { process.stderr.write('{"error": "--get-task-status 需要指定 task_id"}\n'); process.exit(1); }
      if (!existsSync(taskStateFile)) process.exit(1);
      console.log(getTaskStatus(taskStateFile, taskId));
      break;
    }

    case '--sync-layer-status': {
      if (!existsSync(taskStateFile)) {
        process.stderr.write(`{"error": "${taskStateFile.split('/').pop()} 不存在"}\n`);
        process.exit(1);
      }
      if (!existsSync(stateFile)) {
        process.stderr.write(`{"error": "${stateFile.split('/').pop()} 不存在"}\n`);
        process.exit(1);
      }
      syncLayerStatusFromTasks(stateFile, taskStateFile);
      console.log('{"synced": true}');
      break;
    }

    case '--next-tasks': {
      const phase = argv[2] || 'design';
      if (!existsSync(taskStateFile)) {
        process.stderr.write(`{"error": "${taskStateFile.split('/').pop()} 不存在"}\n`);
        process.exit(1);
      }
      const nextTasks = getNextExecutableTasks(taskStateFile, phase);
      if (nextTasks.length === 0) {
        console.log('{"next_tasks": [], "count": 0}');
      } else {
        const entries = nextTasks.map(tid => {
          const tl = getTaskLayer(taskStateFile, tid);
          const tf = getTaskFile(taskStateFile, tid);
          const td = getTaskDescription(taskStateFile, tid);
          return `{"task_id": "${tid}", "layer": "${tl}", "file": "${tf}", "description": "${td}"}`;
        });
        console.log(`{"next_tasks": [${entries.join(', ')}], "count": ${nextTasks.length}}`);
      }
      break;
    }

    default: {
      process.stderr.write(`未知模式: ${mode}\n`);
      process.stderr.write('用法: workflow-status.mjs <idea-dir> [command] [args...]\n');
      process.exit(1);
    }
  }
}

// 直接执行时调用 main
if (import.meta.url === `file://${process.argv[1]}` || import.meta.url === `file://${realpathSync(process.argv[1])}`) {
  main(process.argv.slice(2));
}
