#!/usr/bin/env node
// orchestration-status.mjs — 程序化编排恢复点检测（从 orchestration-status.sh 迁移）
// 用法: node orchestration-status.mjs <idea-dir|none> <stack>
import { existsSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { getTrackedLayers, getTrackedStatus } from './workflow-lib.mjs';
import { checkGate as checkGateImpl } from './gate-check.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const IDEA_DIR = process.argv[2];
const STACK = process.argv[3];

if (!IDEA_DIR || !STACK) {
  process.stderr.write('用法: node orchestration-status.mjs <idea-dir|none> <stack>\n');
  process.exit(1);
}

// ── 辅助函数 ──

function checkGate(gateId, ...extra) {
  return checkGateImpl(IDEA_DIR, gateId, extra).pass;
}

function subStepPriority(s) {
  switch (s) { case 'design': return 1; case 'confirm': return 2; case 'code': return 3; default: return 9; }
}

const completedSteps = [];
function addCompleted(step) { completedSteps.push(step); }

function emitResult(resumeStep, reason, currentPhase, subStep, layers) {
  console.log(`resume_step: ${resumeStep}`);
  console.log(`reason: "${reason}"`);
  if (currentPhase) {
    console.log('phase_detail:');
    console.log(`  current_phase: ${currentPhase}`);
    console.log(`  sub_step: ${subStep}`);
    console.log(`  layers: ${(layers || '').replace(/\s+/g, ',')}`);
  }
}

// ── 共享层检查函数 ──

function _checkBackendSubdomains(stepPrefix) {
  const stateFile = `${IDEA_DIR}/workflow-state.yaml`;
  const tracked = getTrackedLayers(stateFile);
  if (tracked.length === 0) {
    emitResult(`${stepPrefix}assessment`, 'workflow-state.yaml has no tracked subdomains');
    return false;
  }
  let firstSubStep = '', incompleteSubdomains = '';
  for (const subdomain of tracked) {
    const st = getTrackedStatus(stateFile, subdomain);
    let subStep = '';
    switch (st) {
      case 'coded': continue;
      case 'pending': case 'failed': case 'designing': subStep = 'design'; break;
      case 'designed': subStep = 'confirm'; break;
      case 'confirmed': case 'coding': subStep = 'code'; break;
    }
    if (!firstSubStep || subStepPriority(subStep) < subStepPriority(firstSubStep)) {
      firstSubStep = subStep;
    }
    incompleteSubdomains += (incompleteSubdomains ? ' ' : '') + subdomain;
  }
  if (firstSubStep) {
    emitResult(`${stepPrefix}subdomain-loop`, `backend subdomain(s) incomplete`, '', firstSubStep, incompleteSubdomains);
    return false;
  }
  return true;
}

function _checkFrontendLayers(stepPrefix) {
  const stateFile = `${IDEA_DIR}/frontend-workflow-state.yaml`;
  const tracked = getTrackedLayers(stateFile);
  if (tracked.length === 0) {
    emitResult(`${stepPrefix}assessment`, 'frontend-workflow-state.yaml has no tracked layers');
    return false;
  }
  let hasIncomplete = false, firstSubStep = '', incompleteLayers = '';
  for (const layer of tracked) {
    const st = getTrackedStatus(stateFile, layer);
    switch (st) {
      case 'coded': break;
      case 'pending': case 'failed': case 'designing':
        hasIncomplete = true;
        if (!firstSubStep || firstSubStep !== 'design') firstSubStep = 'design';
        incompleteLayers += (incompleteLayers ? ' ' : '') + layer;
        break;
      case 'designed':
        hasIncomplete = true;
        if (!firstSubStep) firstSubStep = 'confirm';
        incompleteLayers += (incompleteLayers ? ' ' : '') + layer;
        break;
      case 'confirmed': case 'coding':
        hasIncomplete = true;
        if (!firstSubStep) firstSubStep = 'code';
        incompleteLayers += (incompleteLayers ? ' ' : '') + layer;
        break;
    }
  }
  if (hasIncomplete) {
    switch (firstSubStep) {
      case 'design':
        emitResult(`${stepPrefix}design`, 'frontend layer(s) need design', '', firstSubStep, incompleteLayers);
        break;
      case 'confirm':
        emitResult(`${stepPrefix}confirm-layers`, 'frontend layer(s) designed, need confirmation', '', firstSubStep, incompleteLayers);
        break;
      case 'code':
        emitResult(`${stepPrefix}code`, 'frontend layer(s) confirmed, need coding', '', firstSubStep, incompleteLayers);
        break;
    }
    return false;
  }
  return true;
}

// ── Backend 检查链 ──

function checkBackend() {
  if (IDEA_DIR === 'none' || !existsSync(IDEA_DIR)) {
    emitResult('receive-requirement', 'idea directory does not exist'); return;
  }
  addCompleted('receive-requirement');
  if (!checkGate('requirement-exists')) { emitResult('clarify', 'requirement.md does not exist'); return; }
  addCompleted('clarify');
  if (!checkGate('branch-ready')) { emitResult('branch', 'not on feature branch'); return; }
  addCompleted('branch');
  if (!checkGate('assessment-exists')) { emitResult('assessment', 'assessment.md does not exist'); return; }
  addCompleted('assessment');
  if (!checkGate('workflow-state-exists')) { emitResult('assessment', 'workflow-state.yaml not initialized (assessment step incomplete)'); return; }
  if (!_checkBackendSubdomains('')) return;
  addCompleted('subdomain-loop');
  if (!checkGate('approved')) { emitResult('mark-approved', 'all layers coded, .approved not yet set'); return; }
  addCompleted('mark-approved');
  if (!checkGate('supplementary-reviewed')) { emitResult('supplementary', 'requirement review not done yet'); return; }
  addCompleted('supplementary');
  emitResult('merge', 'backend approved, ready to merge');
}

// ── Frontend 检查链 ──

function checkFrontend() {
  if (IDEA_DIR === 'none' || !existsSync(IDEA_DIR)) {
    emitResult('receive-idea', 'idea directory does not exist'); return;
  }
  addCompleted('receive-idea');
  if (!checkGate('frontend-requirement-exists')) { emitResult('clarify', 'frontend-requirement.md does not exist'); return; }
  addCompleted('clarify');
  if (!checkGate('branch-ready')) { emitResult('branch', 'not on feature branch'); return; }
  addCompleted('branch');
  if (!checkGate('frontend-assessment-exists')) { emitResult('assessment', 'frontend-assessment.md does not exist'); return; }
  addCompleted('assessment');
  if (!checkGate('frontend-workflow-state-exists')) { emitResult('assessment', 'frontend-workflow-state.yaml not initialized'); return; }
  if (!_checkFrontendLayers('')) return;
  addCompleted('design'); addCompleted('confirm-layers'); addCompleted('code');
  if (!checkGate('frontend-approved')) { emitResult('confirm-layers', 'all frontend layers coded but .frontend-approved not set'); return; }
  addCompleted('frontend-approved');
  if (!checkGate('frontend-supplementary-reviewed')) { emitResult('supplementary', 'frontend requirement review not done yet'); return; }
  addCompleted('supplementary');
  emitResult('merge', 'frontend approved, ready to merge');
}

// ── All 检查链 ──

function checkAll() {
  if (IDEA_DIR === 'none' || !existsSync(IDEA_DIR)) {
    emitResult('receive-requirement', 'idea directory does not exist'); return;
  }
  addCompleted('receive-requirement');
  if (!checkGate('requirement-exists')) { emitResult('backend:clarify', 'requirement.md does not exist'); return; }
  addCompleted('backend:clarify');
  if (!checkGate('frontend-requirement-exists')) { emitResult('frontend:clarify', 'frontend-requirement.md does not exist'); return; }
  addCompleted('frontend:clarify');
  if (!checkGate('branch-ready')) { emitResult('branch', 'not on feature branch'); return; }
  addCompleted('branch');
  // Backend 子检查
  if (!checkGate('assessment-exists')) { emitResult('backend:assessment', 'assessment.md does not exist'); return; }
  addCompleted('backend:assessment');
  if (!checkGate('workflow-state-exists')) { emitResult('backend:assessment', 'workflow-state.yaml not initialized'); return; }
  if (!_checkBackendSubdomains('backend:')) return;
  addCompleted('backend:subdomain-loop');
  if (!checkGate('approved')) { emitResult('backend:mark-approved', 'all backend layers coded, .approved not yet set'); return; }
  addCompleted('backend:mark-approved');
  // Frontend 子检查
  if (!checkGate('frontend-assessment-exists')) { emitResult('frontend:assessment', 'frontend-assessment.md does not exist'); return; }
  addCompleted('frontend:assessment');
  if (!checkGate('frontend-workflow-state-exists')) { emitResult('frontend:assessment', 'frontend-workflow-state.yaml not initialized'); return; }
  if (!_checkFrontendLayers('frontend:')) return;
  addCompleted('frontend:design'); addCompleted('frontend:confirm-layers'); addCompleted('frontend:code');
  if (!checkGate('frontend-approved')) { emitResult('frontend:mark-approved', 'frontend layers coded but .frontend-approved not set'); return; }
  addCompleted('frontend:mark-approved');
  const beReviewed = checkGate('supplementary-reviewed');
  const feReviewed = checkGate('frontend-supplementary-reviewed');
  if (!beReviewed || !feReviewed) { emitResult('supplementary', 'requirement review not done for all stacks'); return; }
  addCompleted('supplementary');
  emitResult('merge', 'all stacks approved, ready to merge');
}

// ── 主入口 ──
switch (STACK) {
  case 'backend': checkBackend(); break;
  case 'frontend': checkFrontend(); break;
  case 'all': checkAll(); break;
  default:
    process.stderr.write(`error: unknown stack '${STACK}', expected: backend | frontend | all\n`);
    process.exit(1);
}
