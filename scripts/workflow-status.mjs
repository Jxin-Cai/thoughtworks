#!/usr/bin/env node
// workflow-status.mjs — 统一工作流状态管理脚本（垂直子域模式）
// 用法: node workflow-status.mjs <idea-dir> <command> [args...]
//   需设置 STACK 环境变量 (backend|frontend)

import { existsSync, readFileSync, realpathSync } from 'node:fs';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import {
  readIdea, getTrackedLayers, getTrackedStatus, isTracked, updateLayerStatus, initState,
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

  let stateFile;
  if (STACK === 'backend') {
    stateFile = join(ideaDir, 'workflow-state.yaml');
  } else {
    stateFile = join(ideaDir, 'frontend-workflow-state.yaml');
  }

  // ── 定位脚本目录 ──
  const __dirname = dirname(fileURLToPath(import.meta.url));
  const callerDir = process.env.CALLER_SCRIPT_DIR || __dirname;
  let validateScript;
  if (STACK === 'backend') {
    validateScript = resolve(callerDir, 'backend-output-validate.mjs');
  } else {
    validateScript = resolve(callerDir, 'frontend-output-validate.mjs');
  }

  // ── 状态转换合法性校验 ──
  const validStatuses = ['pending', 'designing', 'designed', 'confirmed', 'coding', 'coded', 'failed'];
  const validTransitions = new Set([
    'pending:designing', 'designing:designed', 'designed:confirmed',
    'pending:confirmed', 'confirmed:coding', 'coding:coded',
    'designing:failed', 'coding:failed', 'failed:pending',
    'designing:designing', 'designed:designing',
  ]);

  function validateTransition(subdomain, newStatus) {
    const currentStatus = getTrackedStatus(stateFile, subdomain);
    if (!currentStatus) return true;
    if (newStatus === 'failed' || newStatus === 'pending') return true;
    if (validTransitions.has(`${currentStatus}:${newStatus}`)) return true;
    process.stderr.write(`{"error": "非法状态转换: ${subdomain} ${currentStatus} → ${newStatus}"}\n`);
    return false;
  }

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
      let allDone = true, allPending = true, hasFailed = false, hasInProgress = false;
      const entries = [];
      for (const subdomain of tracked) {
        const st = getTrackedStatus(stateFile, subdomain);
        entries.push(`"${subdomain}": "${st}"`);
        if (st === 'coded') { /* done */ }
        else if (st === 'failed') { hasFailed = true; allDone = false; allPending = false; }
        else if (st === 'designing' || st === 'coding') { hasInProgress = true; allDone = false; allPending = false; }
        else if (st === 'pending') { allDone = false; }
        else { allDone = false; allPending = false; }
      }
      let overall;
      if (allDone && tracked.length > 0) overall = 'all_done';
      else if (hasFailed) overall = 'blocked';
      else if (hasInProgress) overall = 'in_progress';
      else if (allPending) overall = 'not_started';
      else overall = 'in_progress';
      console.log(`{"idea": "${idea}", "subdomains": {${entries.join(', ')}}, "overall": "${overall}"}`);
      break;
    }

    case '--init': {
      // --init <idea-name> <subdomain1> [subdomain2] ...
      // 子域名称是动态的（不再校验固定列表）
      const ideaName = argv[2];
      const subdomains = argv.slice(3);
      if (!ideaName) { process.stderr.write('{"error": "--init 需要指定 idea-name"}\n'); process.exit(1); }
      if (subdomains.length === 0) { process.stderr.write('{"error": "--init 需要至少一个子域名"}\n'); process.exit(1); }
      initState(stateFile, ideaName, subdomains);
      const json = subdomains.map(s => `"${s}"`).join(', ');
      console.log(`{"initialized": true, "idea": "${ideaName}", "subdomains": [${json}]}`);
      break;
    }

    case '--set': {
      // --set <subdomain> <status>
      const subdomain = argv[2];
      const status = argv[3];
      if (!subdomain) { process.stderr.write('{"error": "--set 需要指定子域名"}\n'); process.exit(1); }
      if (!status) { process.stderr.write('{"error": "--set 需要指定状态"}\n'); process.exit(1); }
      if (!validStatuses.includes(status)) {
        process.stderr.write(`{"error": "无效状态: ${status}，可选: ${validStatuses.join('|')}"}\n`);
        process.exit(1);
      }
      if (!existsSync(stateFile)) {
        process.stderr.write(`{"error": "${stateFile.split('/').pop()} 不存在，请先执行 --init"}\n`);
        process.exit(1);
      }
      if (!isTracked(stateFile, subdomain)) {
        process.stderr.write(`{"error": "子域 ${subdomain} 不在 tracked_layers 中"}\n`);
        process.exit(1);
      }
      if (!validateTransition(subdomain, status)) process.exit(1);
      updateLayerStatus(stateFile, subdomain, status);
      console.log(`{"updated": true, "subdomain": "${subdomain}", "status": "${status}"}`);
      break;
    }

    case '--get-status': {
      const subdomain = argv[2];
      if (!subdomain) { process.stderr.write('{"error": "--get-status 需要指定子域名"}\n'); process.exit(1); }
      if (!existsSync(stateFile)) process.exit(1);
      if (!isTracked(stateFile, subdomain)) process.exit(1);
      console.log(getTrackedStatus(stateFile, subdomain));
      break;
    }

    case '--next-subdomains': {
      // 返回 status=confirmed 且依赖已满足（depends_on 中所有子域都是 coded）的子域
      // 依赖信息从设计文件的 frontmatter 中读取
      if (!existsSync(stateFile)) {
        process.stderr.write(`{"error": "${stateFile.split('/').pop()} 不存在"}\n`);
        process.exit(1);
      }
      const phase = argv[2] || 'code'; // design 或 code
      const tracked = getTrackedLayers(stateFile);
      const targetStatus = phase === 'design' ? 'pending' : 'confirmed';
      const ready = [];

      for (const subdomain of tracked) {
        const st = getTrackedStatus(stateFile, subdomain);
        if (st !== targetStatus) continue;

        // 尝试从设计文件读取 depends_on
        const designsDir = join(ideaDir, 'backend-designs');
        let dependsSatisfied = true;
        if (existsSync(designsDir)) {
          const files = existsSync(designsDir) ?
            require('node:fs').readdirSync(designsDir).filter(f => f.endsWith('.md')) : [];
          for (const f of files) {
            const content = readFileSync(join(designsDir, f), 'utf-8');
            const taskIdMatch = content.match(/^task_id:\s*(.+)$/m);
            if (taskIdMatch && taskIdMatch[1].trim() === subdomain) {
              const depsMatch = content.match(/^depends_on:\s*\[([^\]]*)\]/m);
              if (depsMatch && depsMatch[1].trim()) {
                const deps = depsMatch[1].split(',').map(d => d.trim().replace(/['"]/g, '')).filter(Boolean);
                for (const dep of deps) {
                  const depStatus = getTrackedStatus(stateFile, dep);
                  if (depStatus !== 'coded') {
                    dependsSatisfied = false;
                    break;
                  }
                }
              }
              break;
            }
          }
        }
        if (dependsSatisfied) ready.push(subdomain);
      }

      const entries = ready.map(s => `"${s}"`).join(', ');
      console.log(`{"next_subdomains": [${entries}], "count": ${ready.length}, "phase": "${phase}"}`);
      break;
    }

    case '--check-all': {
      if (!existsSync(stateFile)) {
        process.stderr.write(`{"error": "${stateFile.split('/').pop()} 不存在"}\n`);
        process.exit(1);
      }
      const tracked = getTrackedLayers(stateFile);
      let allDone = true, hasFailed = false;
      for (const subdomain of tracked) {
        const st = getTrackedStatus(stateFile, subdomain);
        if (st === 'coded') continue;
        if (st === 'failed') { hasFailed = true; allDone = false; }
        else allDone = false;
      }
      if (allDone) {
        let validationOutput = '';
        if (existsSync(validateScript)) {
          try {
            validationOutput = execFileSync('node', [validateScript, ideaDir, '--summary'],
              { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
          } catch (e) {
            validationOutput = e.stdout ? e.stdout.trim() : '';
          }
        }
        console.log(`{"overall": "all_done", "validation": ${validationOutput || '{}'}}`);
      } else if (hasFailed) {
        console.log('{"overall": "blocked"}');
      } else {
        console.log('{"overall": "in_progress"}');
      }
      break;
    }

    default: {
      process.stderr.write(`未知模式: ${mode}\n`);
      process.stderr.write('可用命令: status, --init, --set, --get-status, --next-subdomains, --check-all\n');
      process.exit(1);
    }
  }
}

// 直接执行时调用 main
if (import.meta.url === `file://${process.argv[1]}` || import.meta.url === `file://${realpathSync(process.argv[1])}`) {
  main(process.argv.slice(2));
}
