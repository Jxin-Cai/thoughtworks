#!/usr/bin/env node
// gate-check.mjs — HARD-GATE 程序化检查脚本（从 gate-check.sh 迁移）
// 用法: node gate-check.mjs <idea-dir> <gate-id> [extra-args...]
//       node gate-check.mjs <idea-dir> --batch <gate1,gate2,...>
// 输出: YAML 格式 { pass: true/false, reason: "..." }

import { existsSync, readdirSync, readFileSync, statSync, rmSync } from 'node:fs';
import { execSync, execFileSync } from 'node:child_process';
import { dirname, resolve, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const IDEA_DIR = process.argv[2];
const GATE_ID = process.argv[3];
const extraArgs = process.argv.slice(4);

// ── 门控检查逻辑（返回结果，不直接退出） ──

function checkGate(ideaDir, gateId, extra) {
  switch (gateId) {
    case 'idea-dir-exists':
      return existsSync(ideaDir) && statSync(ideaDir).isDirectory()
        ? { pass: true }
        : { pass: false, reason: `idea directory does not exist: ${ideaDir}` };

    case 'requirement-exists':
      return existsSync(`${ideaDir}/requirement.md`)
        ? { pass: true }
        : { pass: false, reason: `requirement.md 不存在于 ${ideaDir}/` };

    case 'frontend-requirement-exists':
      return existsSync(`${ideaDir}/frontend-requirement.md`)
        ? { pass: true }
        : { pass: false, reason: `frontend-requirement.md 不存在于 ${ideaDir}/` };

    case 'assessment-exists':
      return existsSync(`${ideaDir}/assessment.md`)
        ? { pass: true }
        : { pass: false, reason: `assessment.md 不存在于 ${ideaDir}/` };

    case 'frontend-assessment-exists':
      return existsSync(`${ideaDir}/frontend-assessment.md`)
        ? { pass: true }
        : { pass: false, reason: `frontend-assessment.md 不存在于 ${ideaDir}/` };

    case 'workflow-state-exists':
      return existsSync(`${ideaDir}/workflow-state.yaml`)
        ? { pass: true }
        : { pass: false, reason: `workflow-state.yaml 不存在于 ${ideaDir}/` };

    case 'frontend-workflow-state-exists':
      return existsSync(`${ideaDir}/frontend-workflow-state.yaml`)
        ? { pass: true }
        : { pass: false, reason: `frontend-workflow-state.yaml 不存在于 ${ideaDir}/` };

    case 'upstream-ready': {
      const layer = extra[0];
      const stack = extra[1] || 'backend';
      if (!layer) return { pass: false, reason: 'upstream-ready 需要指定层名' };
      const repoRoot = dirname(dirname(__dirname));
      const statusScript = stack === 'frontend'
        ? resolve(repoRoot, 'frontend/skills/frontend-help/scripts/frontend-workflow-status.mjs')
        : resolve(repoRoot, 'backend/skills/backend-help/scripts/backend-workflow-status.mjs');
      if (!existsSync(statusScript)) return { pass: false, reason: `workflow-status 脚本不存在: ${statusScript}` };
      try {
        const result = execFileSync('node', [statusScript, ideaDir, '--check-upstream', layer], { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
        return (result.includes('"upstream_ready": true') || result.includes('"upstream_ready":true'))
          ? { pass: true }
          : { pass: false, reason: `层 ${layer} 的上游依赖未就绪` };
      } catch {
        return { pass: false, reason: `层 ${layer} 的上游依赖未就绪` };
      }
    }

    case 'designs-exist': {
      const designsDir = `${ideaDir}/backend-designs`;
      if (existsSync(designsDir)) {
        try {
          for (const entry of readdirSync(designsDir, { withFileTypes: true })) {
            if (entry.isDirectory()) {
              const mdFiles = readdirSync(`${designsDir}/${entry.name}`).filter(f => f.endsWith('.md'));
              if (mdFiles.length > 0) return { pass: true };
            }
          }
        } catch {}
        try {
          if (readdirSync(designsDir).filter(f => f.endsWith('.md')).length > 0) return { pass: true };
        } catch {}
      }
      return { pass: false, reason: 'backend-designs/ 目录不存在或无设计文件' };
    }

    case 'frontend-designs-exist': {
      const designsDir = `${ideaDir}/frontend-designs`;
      if (existsSync(designsDir)) {
        try {
          for (const entry of readdirSync(designsDir, { withFileTypes: true })) {
            if (entry.isDirectory()) {
              const mdFiles = readdirSync(`${designsDir}/${entry.name}`).filter(f => f.endsWith('.md'));
              if (mdFiles.length > 0) return { pass: true };
            }
          }
        } catch {}
        try {
          if (readdirSync(designsDir).filter(f => f.endsWith('.md')).length > 0) return { pass: true };
        } catch {}
      }
      return { pass: false, reason: 'frontend-designs/ 目录不存在或无设计文件' };
    }

    case 'design-confirmed':
      return existsSync(`${ideaDir}/.design-confirmed`)
        ? { pass: true }
        : { pass: false, reason: `.design-confirmed 标记不存在，thought 技能可能未完成用户确认` };

    case 'frontend-design-confirmed':
      return existsSync(`${ideaDir}/.frontend-design-confirmed`)
        ? { pass: true }
        : { pass: false, reason: `.frontend-design-confirmed 标记不存在，thought 技能可能未完成用户确认` };

    case 'approved':
      return existsSync(`${ideaDir}/.approved`)
        ? { pass: true }
        : { pass: false, reason: `.approved 标记不存在于 ${ideaDir}/` };

    case 'frontend-approved':
      return existsSync(`${ideaDir}/.frontend-approved`)
        ? { pass: true }
        : { pass: false, reason: `.frontend-approved 标记不存在于 ${ideaDir}/` };

    case 'branch-ready': {
      const ideaName = basename(ideaDir);
      let currentBranch = '';
      try { currentBranch = execSync('git rev-parse --abbrev-ref HEAD', { encoding: 'utf-8' }).trim(); } catch {}
      return (currentBranch === `feature/${ideaName}` || currentBranch.startsWith('feature/'))
        ? { pass: true }
        : { pass: false, reason: `当前不在 feature 分支上（当前: ${currentBranch}）` };
    }

    case 'supplementary-tasks-exist': {
      const stFile = `${ideaDir}/supplementary-tasks.md`;
      if (existsSync(stFile)) {
        try {
          if (readFileSync(stFile, 'utf-8').trim().length > 0) return { pass: true };
        } catch {}
      }
      return { pass: false, reason: 'supplementary-tasks.md 不存在或为空' };
    }

    case 'supplementary-reviewed':
      return existsSync(`${ideaDir}/.supplementary-reviewed`)
        ? { pass: true }
        : { pass: false, reason: '.supplementary-reviewed 标记不存在' };

    case 'frontend-supplementary-reviewed':
      return existsSync(`${ideaDir}/.frontend-supplementary-reviewed`)
        ? { pass: true }
        : { pass: false, reason: '.frontend-supplementary-reviewed 标记不存在' };

    case 'task-workflow-integrity': {
      const checkStack = extra[0] || 'backend';
      let taskState, dDir;
      if (checkStack === 'backend') {
        taskState = `${ideaDir}/task-workflow-state.yaml`;
        dDir = `${ideaDir}/backend-designs`;
      } else if (checkStack === 'frontend') {
        taskState = `${ideaDir}/frontend-task-workflow-state.yaml`;
        dDir = `${ideaDir}/frontend-designs`;
      } else {
        return { pass: false, reason: `无效 stack: ${checkStack}，可选: backend|frontend` };
      }
      if (!existsSync(taskState)) return { pass: false, reason: `task 状态文件不存在: ${basename(taskState)}` };
      const content = readFileSync(taskState, 'utf-8');
      const lines = content.split('\n');
      let currentTask = '', currentStatus = '', currentFile = '';
      const violations = [];
      for (const line of lines) {
        if (/^  [a-zA-Z].*:$/.test(line)) { currentTask = line.trim().replace(/:$/, ''); currentStatus = ''; currentFile = ''; }
        else if (/^    status:/.test(line)) { currentStatus = line.replace(/^.*status:\s*/, '').trim(); }
        else if (/^    file:/.test(line)) {
          currentFile = line.replace(/^.*file:\s*/, '').trim();
          if (currentStatus && currentFile && (currentStatus === 'coding' || currentStatus === 'coded')) {
            if (!existsSync(`${dDir}/${currentFile}`)) violations.push(`task=${currentTask}(status=${currentStatus},file=${currentFile} 不存在)`);
          }
        }
      }
      return violations.length > 0
        ? { pass: false, reason: `工作流完整性违规: ${violations.join(';')}` }
        : { pass: true };
    }

    case 'stale-tasks': {
      let cleaned = 0;
      const now = Date.now();
      try {
        for (const entry of readdirSync(ideaDir)) {
          if (!entry.startsWith('.current-task-') || !entry.endsWith('.json')) continue;
          try {
            if ((now - statSync(`${ideaDir}/${entry}`).mtimeMs) / 1000 > 1800) { rmSync(`${ideaDir}/${entry}`); cleaned++; }
          } catch {}
        }
      } catch {}
      return { pass: true, ...(cleaned > 0 ? { cleaned } : {}) };
    }

    default:
      return { pass: false, reason: `未知门控 ID: ${gateId}` };
  }
}

// ── 输出格式化 ──

function printResult(result) {
  console.log(`pass: ${result.pass}`);
  if (result.reason) console.log(`reason: "${result.reason}"`);
  if (result.cleaned) console.log(`cleaned: ${result.cleaned}`);
}

// ── 导出供内部模块直接调用 ──

export { checkGate };

// ── CLI 执行入口（仅当直接运行时） ──

const isCLI = process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));

if (isCLI) {
  if (!IDEA_DIR || !GATE_ID) {
    process.stderr.write('用法: node gate-check.mjs <idea-dir> <gate-id> [extra-args...]\n');
    process.stderr.write('      node gate-check.mjs <idea-dir> --batch <gate1,gate2,...>\n');
    process.exit(1);
  }

  if (GATE_ID === '--batch') {
    const gateIds = (extraArgs[0] || '').split(',').filter(Boolean);
    if (gateIds.length === 0) { process.stderr.write('--batch 需要逗号分隔的门控列表\n'); process.exit(1); }
    for (const gid of gateIds) {
      const result = checkGate(IDEA_DIR, gid, extraArgs.slice(1));
      console.log(`${gid}: ${result.pass ? 'pass' : `fail: ${result.reason}`}`);
    }
  } else {
    const result = checkGate(IDEA_DIR, GATE_ID, extraArgs);
    printResult(result);
  }
}
