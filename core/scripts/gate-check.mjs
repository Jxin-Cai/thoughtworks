#!/usr/bin/env node
// gate-check.mjs — HARD-GATE 程序化检查脚本（从 gate-check.sh 迁移）
// 用法: node gate-check.mjs <idea-dir> <gate-id> [extra-args...]
// 输出: YAML 格式 { pass: true/false, reason: "..." }

import { existsSync, readdirSync, readFileSync, statSync, rmSync } from 'node:fs';
import { execSync, execFileSync } from 'node:child_process';
import { dirname, resolve, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const IDEA_DIR = process.argv[2];
const GATE_ID = process.argv[3];
const extraArgs = process.argv.slice(4);

if (!IDEA_DIR || !GATE_ID) {
  process.stderr.write('用法: node gate-check.mjs <idea-dir> <gate-id> [extra-args...]\n');
  process.exit(1);
}

function gatePass() {
  console.log('pass: true');
  process.exit(0);
}

function gateFail(reason) {
  console.log(`pass: false`);
  console.log(`reason: "${reason}"`);
  process.exit(0);
}

// ── 门控检查 ──

switch (GATE_ID) {
  case 'idea-dir-exists': {
    existsSync(IDEA_DIR) && statSync(IDEA_DIR).isDirectory() ? gatePass() : gateFail(`idea directory does not exist: ${IDEA_DIR}`);
    break;
  }

  case 'requirement-exists': {
    existsSync(`${IDEA_DIR}/requirement.md`) ? gatePass() : gateFail(`requirement.md 不存在于 ${IDEA_DIR}/`);
    break;
  }

  case 'frontend-requirement-exists': {
    existsSync(`${IDEA_DIR}/frontend-requirement.md`) ? gatePass() : gateFail(`frontend-requirement.md 不存在于 ${IDEA_DIR}/`);
    break;
  }

  case 'assessment-exists': {
    existsSync(`${IDEA_DIR}/assessment.md`) ? gatePass() : gateFail(`assessment.md 不存在于 ${IDEA_DIR}/`);
    break;
  }

  case 'frontend-assessment-exists': {
    existsSync(`${IDEA_DIR}/frontend-assessment.md`) ? gatePass() : gateFail(`frontend-assessment.md 不存在于 ${IDEA_DIR}/`);
    break;
  }

  case 'workflow-state-exists': {
    existsSync(`${IDEA_DIR}/workflow-state.yaml`) ? gatePass() : gateFail(`workflow-state.yaml 不存在于 ${IDEA_DIR}/`);
    break;
  }

  case 'frontend-workflow-state-exists': {
    existsSync(`${IDEA_DIR}/frontend-workflow-state.yaml`) ? gatePass() : gateFail(`frontend-workflow-state.yaml 不存在于 ${IDEA_DIR}/`);
    break;
  }

  case 'upstream-ready': {
    const layer = extraArgs[0];
    const stack = extraArgs[1] || 'backend';
    if (!layer) { gateFail('upstream-ready 需要指定层名'); break; }
    const repoRoot = dirname(dirname(__dirname));
    let statusScript;
    if (stack === 'frontend') {
      statusScript = resolve(repoRoot, 'frontend/skills/frontend-help/scripts/frontend-workflow-status.mjs');
    } else {
      statusScript = resolve(repoRoot, 'backend/skills/backend-help/scripts/backend-workflow-status.mjs');
    }
    if (existsSync(statusScript)) {
      try {
        const result = execFileSync('node', [statusScript, IDEA_DIR, '--check-upstream', layer], { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
        if (result.includes('"upstream_ready": true') || result.includes('"upstream_ready":true')) {
          gatePass();
        } else {
          gateFail(`层 ${layer} 的上游依赖未就绪`);
        }
      } catch {
        gateFail(`层 ${layer} 的上游依赖未就绪`);
      }
    } else {
      gateFail(`workflow-status 脚本不存在: ${statusScript}`);
    }
    break;
  }

  case 'designs-exist': {
    let found = false;
    const designsDir = `${IDEA_DIR}/backend-designs`;
    if (existsSync(designsDir)) {
      // 新模式：按层分目录
      try {
        for (const entry of readdirSync(designsDir, { withFileTypes: true })) {
          if (entry.isDirectory()) {
            const layerDir = `${designsDir}/${entry.name}`;
            const mdFiles = readdirSync(layerDir).filter(f => f.endsWith('.md'));
            if (mdFiles.length > 0) { found = true; break; }
          }
        }
      } catch {}
      // 旧模式回退
      if (!found) {
        try {
          const mdFiles = readdirSync(designsDir).filter(f => f.endsWith('.md'));
          if (mdFiles.length > 0) found = true;
        } catch {}
      }
    }
    found ? gatePass() : gateFail('backend-designs/ 目录不存在或无设计文件');
    break;
  }

  case 'frontend-designs-exist': {
    let found = false;
    const designsDir = `${IDEA_DIR}/frontend-designs`;
    if (existsSync(designsDir)) {
      try {
        for (const entry of readdirSync(designsDir, { withFileTypes: true })) {
          if (entry.isDirectory()) {
            const layerDir = `${designsDir}/${entry.name}`;
            const mdFiles = readdirSync(layerDir).filter(f => f.endsWith('.md'));
            if (mdFiles.length > 0) { found = true; break; }
          }
        }
      } catch {}
      if (!found) {
        try {
          const mdFiles = readdirSync(designsDir).filter(f => f.endsWith('.md'));
          if (mdFiles.length > 0) found = true;
        } catch {}
      }
    }
    found ? gatePass() : gateFail('frontend-designs/ 目录不存在或无设计文件');
    break;
  }

  case 'approved': {
    existsSync(`${IDEA_DIR}/.approved`) ? gatePass() : gateFail(`.approved 标记不存在于 ${IDEA_DIR}/`);
    break;
  }

  case 'frontend-approved': {
    existsSync(`${IDEA_DIR}/.frontend-approved`) ? gatePass() : gateFail(`.frontend-approved 标记不存在于 ${IDEA_DIR}/`);
    break;
  }

  case 'branch-ready': {
    const ideaName = basename(IDEA_DIR);
    let currentBranch = '';
    try {
      currentBranch = execSync('git rev-parse --abbrev-ref HEAD', { encoding: 'utf-8' }).trim();
    } catch {}
    if (currentBranch === `feature/${ideaName}` || currentBranch.startsWith('feature/')) {
      gatePass();
    } else {
      gateFail(`当前不在 feature 分支上（当前: ${currentBranch}）`);
    }
    break;
  }

  case 'supplementary-tasks-exist': {
    const stFile = `${IDEA_DIR}/supplementary-tasks.md`;
    if (existsSync(stFile)) {
      try {
        const content = readFileSync(stFile, 'utf-8');
        if (content.trim().length > 0) gatePass();
        else gateFail('supplementary-tasks.md 不存在或为空');
      } catch { gateFail('supplementary-tasks.md 不存在或为空'); }
    } else {
      gateFail('supplementary-tasks.md 不存在或为空');
    }
    break;
  }

  case 'supplementary-reviewed': {
    existsSync(`${IDEA_DIR}/.supplementary-reviewed`) ? gatePass() : gateFail('.supplementary-reviewed 标记不存在');
    break;
  }

  case 'frontend-supplementary-reviewed': {
    existsSync(`${IDEA_DIR}/.frontend-supplementary-reviewed`) ? gatePass() : gateFail('.frontend-supplementary-reviewed 标记不存在');
    break;
  }

  case 'task-workflow-integrity': {
    const checkStack = extraArgs[0] || 'backend';
    let taskState, designsDir;
    if (checkStack === 'backend') {
      taskState = `${IDEA_DIR}/task-workflow-state.yaml`;
      designsDir = `${IDEA_DIR}/backend-designs`;
    } else if (checkStack === 'frontend') {
      taskState = `${IDEA_DIR}/frontend-task-workflow-state.yaml`;
      designsDir = `${IDEA_DIR}/frontend-designs`;
    } else {
      gateFail(`无效 stack: ${checkStack}，可选: backend|frontend`);
      break;
    }

    if (!existsSync(taskState)) {
      gateFail(`task 状态文件不存在: ${basename(taskState)}`);
      break;
    }

    const content = readFileSync(taskState, 'utf-8');
    const lines = content.split('\n');
    let currentTask = '', currentStatus = '', currentFile = '';
    const violations = [];

    for (const line of lines) {
      if (/^  [a-zA-Z].*:$/.test(line)) {
        currentTask = line.trim().replace(/:$/, '');
        currentStatus = '';
        currentFile = '';
      } else if (/^    status:/.test(line)) {
        currentStatus = line.replace(/^.*status:\s*/, '').trim();
      } else if (/^    file:/.test(line)) {
        currentFile = line.replace(/^.*file:\s*/, '').trim();
        if (currentStatus && currentFile && (currentStatus === 'coding' || currentStatus === 'coded')) {
          if (!existsSync(`${designsDir}/${currentFile}`)) {
            violations.push(`task=${currentTask}(status=${currentStatus},file=${currentFile} 不存在)`);
          }
        }
      }
    }

    if (violations.length > 0) {
      gateFail(`工作流完整性违规: ${violations.join(';')}`);
    } else {
      gatePass();
    }
    break;
  }

  case 'stale-tasks': {
    let cleaned = 0;
    const now = Date.now();
    try {
      const entries = readdirSync(IDEA_DIR);
      for (const entry of entries) {
        if (!entry.startsWith('.current-task-') || !entry.endsWith('.json')) continue;
        const taskFile = `${IDEA_DIR}/${entry}`;
        try {
          const mtime = statSync(taskFile).mtimeMs;
          const ageSeconds = (now - mtime) / 1000;
          if (ageSeconds > 1800) {
            rmSync(taskFile);
            cleaned++;
          }
        } catch {}
      }
    } catch {}

    if (cleaned > 0) {
      console.log('pass: true');
      console.log(`cleaned: ${cleaned}`);
    } else {
      gatePass();
    }
    break;
  }

  default: {
    console.log('pass: false');
    console.log(`reason: "未知门控 ID: ${GATE_ID}"`);
    process.exit(1);
  }
}
