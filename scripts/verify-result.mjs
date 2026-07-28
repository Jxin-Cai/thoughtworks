#!/usr/bin/env node
// verify-result.mjs — 解析 Verifier Agent 输出并持久化验证结果
// 用法: node verify-result.mjs <idea-dir> <subdomain> <result-json>
// 输出: YAML 格式 { pass: true/false, reason: "..." }

import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { lockedWrite } from './workflow-lib.mjs';

const ideaDir = process.argv[2];
const subdomain = process.argv[3];
const resultArg = process.argv[4];

if (!ideaDir || !subdomain || !resultArg) {
  console.error('用法: node verify-result.mjs <idea-dir> <subdomain> <result-json>');
  process.exit(1);
}

// ── 从 agent 输出中提取 JSON ──

function extractVerifyJSON(raw) {
  // 尝试直接解析
  try {
    const parsed = JSON.parse(raw);
    if (parsed.verify_result) return parsed;
    return null;
  } catch {}

  // 从文本中提取包含 verify_result 的 JSON 块（使用括号平衡匹配）
  const startIdx = raw.indexOf('"verify_result"');
  if (startIdx !== -1) {
    // 向前找到包含它的最近的 {
    let braceStart = raw.lastIndexOf('{', startIdx);
    if (braceStart !== -1) {
      // 向后平衡括号找到对应的 }
      let depth = 0;
      for (let i = braceStart; i < raw.length; i++) {
        if (raw[i] === '{') depth++;
        else if (raw[i] === '}') { depth--; if (depth === 0) { try { return JSON.parse(raw.slice(braceStart, i + 1)); } catch {} break; } }
      }
    }
  }

  // 尝试提取 ```json ... ``` 代码块
  const codeBlockMatch = raw.match(/```(?:json)?\s*\n([\s\S]*?)\n```/);
  if (codeBlockMatch) {
    try {
      const parsed = JSON.parse(codeBlockMatch[1]);
      if (parsed.verify_result) return parsed;
    } catch {}
  }

  return null;
}

// ── 验证结构 ──

function validateResult(data) {
  if (!data || !data.verify_result) return { valid: false, reason: '缺少 verify_result 字段' };
  const vr = data.verify_result;
  if (!vr.compile) return { valid: false, reason: '缺少 compile 字段' };
  if (!['pass', 'fail', 'skip'].includes(vr.compile.status)) {
    return { valid: false, reason: `无效的 compile.status: ${vr.compile.status}` };
  }
  return { valid: true };
}

// ── 评估结果 ──

function evaluateResult(data) {
  const compile = data.verify_result.compile;

  if (compile.status === 'fail') {
    const errors = (compile.errors || []).slice(0, 5).join('; ');
    return { pass: false, reason: `编译失败: ${errors || '(无详细错误)'}` };
  }

  if (compile.status === 'skip') {
    return { pass: true, reason: '编译验证跳过（构建工具不可用）' };
  }

  return { pass: true, reason: '' };
}

// ── 主逻辑 ──

let rawInput = resultArg;

// 如果是文件路径，读取文件内容
if (existsSync(resultArg)) {
  rawInput = readFileSync(resultArg, 'utf-8');
}

const data = extractVerifyJSON(rawInput);
if (!data) {
  console.log('pass: false');
  console.log('reason: "无法从 agent 输出中解析验证结果 JSON"');
  process.exit(1);
}

const validation = validateResult(data);
if (!validation.valid) {
  console.log('pass: false');
  console.log(`reason: "${validation.reason}"`);
  process.exit(1);
}

// 持久化结果
const outputFile = join(ideaDir, `verify-${subdomain}.json`);
lockedWrite(outputFile, JSON.stringify(data.verify_result, null, 2));

// 输出门控结果
const result = evaluateResult(data);
console.log(`pass: ${result.pass}`);
if (result.reason) {
  console.log(`reason: "${result.reason}"`);
}

process.exit(result.pass ? 0 : 1);
