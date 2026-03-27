#!/usr/bin/env node
// subagent-stop.mjs — SubagentStop hook：subagent 结束时自动收敛状态
//
// 编排器在启动 subagent 前写入 .thoughtworks/<idea>/.current-task-<layer>-<timestamp>.json：
//   { "role": "thinker|worker", "layer": "<layer>", "idea_dir": "<path>", "stack": "backend|frontend" }
//
// Task 级模式（含 task_id 字段）：
//   { "role": "thinker|worker", "task_id": "<id>", "layer": "<layer>", "idea_dir": "<path>", "stack": "backend|frontend" }
//   有 task_id 时：先更新 task 级状态（--set-task），再同步层级状态（--sync-layer-status）
//   无 task_id 时：走旧逻辑，直接更新层级状态（--set）
//
// thinker: 标记状态 (designing → designed)
// worker:  只清理任务文件（coded 状态由编排器在验证产出后写入）
//
// 如果无任务文件（非 DDD 流程调用），静默退出。
// 超过 30 分钟的残留任务文件视为过期，清理而非处理。
import { existsSync, readdirSync, readFileSync, statSync, unlinkSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = dirname(dirname(__dirname));
const STALE_THRESHOLD = 1800; // 30 分钟（秒）

// ── 收集所有 .current-task-*.json 文件 ──

function collectTaskFiles() {
  const twDir = resolve(process.cwd(), '.thoughtworks');
  if (!existsSync(twDir)) return [];
  const files = [];
  let ideaDirs;
  try { ideaDirs = readdirSync(twDir, { withFileTypes: true }); } catch { return []; }
  for (const entry of ideaDirs) {
    if (!entry.isDirectory()) continue;
    const ideaPath = resolve(twDir, entry.name);
    let children;
    try { children = readdirSync(ideaPath); } catch { continue; }
    for (const f of children) {
      if (f.startsWith('.current-task-') && f.endsWith('.json')) {
        files.push(resolve(ideaPath, f));
      }
    }
  }
  return files;
}

// ── 检查文件是否过期 ──

function isStale(filePath) {
  try {
    const mtime = statSync(filePath).mtimeMs;
    const age = (Date.now() - mtime) / 1000;
    return age > STALE_THRESHOLD;
  } catch { return true; }
}

// ── 安全删除 ──

function safeRemove(filePath) {
  try { unlinkSync(filePath); } catch {}
}

// ── 主逻辑 ──

const taskFiles = collectTaskFiles();
if (taskFiles.length === 0) process.exit(0);

for (const taskFile of taskFiles) {
  // 清理过期残留
  if (isStale(taskFile)) {
    safeRemove(taskFile);
    continue;
  }

  // 解析 JSON
  let data;
  try { data = JSON.parse(readFileSync(taskFile, 'utf-8')); } catch { safeRemove(taskFile); continue; }

  const { role, layer, idea_dir, stack, task_id } = data;

  // 验证必要字段
  if (!role || !layer || !idea_dir) {
    safeRemove(taskFile);
    continue;
  }

  // worker 分支：coded 状态由编排器在验证产出后写入，hook 只清理任务文件
  if (role !== 'thinker') {
    safeRemove(taskFile);
    continue;
  }

  const targetStatus = 'designed';
  const expectedCurrent = 'designing';

  // 确定使用哪个 workflow-status 脚本
  let statusScript;
  if (stack === 'frontend') {
    statusScript = resolve(REPO_ROOT, 'frontend/skills/frontend-help/scripts/frontend-workflow-status.mjs');
  } else {
    statusScript = resolve(REPO_ROOT, 'backend/skills/backend-help/scripts/backend-workflow-status.mjs');
  }

  if (!existsSync(statusScript) || !existsSync(idea_dir)) {
    safeRemove(taskFile);
    continue;
  }

  try {
    if (task_id) {
      // Task 级模式：先更新 task 状态，再同步层级状态
      const currentTaskStatus = execFileSync('node', [statusScript, idea_dir, '--get-task-status', task_id],
        { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
      if (currentTaskStatus === expectedCurrent) {
        execFileSync('node', [statusScript, idea_dir, '--set-task', task_id, targetStatus],
          { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
        execFileSync('node', [statusScript, idea_dir, '--sync-layer-status'],
          { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
      }
    } else {
      // 层级模式（旧逻辑）：直接更新层级状态
      const currentStatus = execFileSync('node', [statusScript, idea_dir, '--get-status', layer],
        { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
      if (currentStatus === expectedCurrent) {
        execFileSync('node', [statusScript, idea_dir, '--set', layer, targetStatus],
          { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
      }
    }
  } catch {}

  safeRemove(taskFile);
}
