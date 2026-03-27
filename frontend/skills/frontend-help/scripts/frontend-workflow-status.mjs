#!/usr/bin/env node
// frontend-workflow-status.mjs — 前端工作流状态管理薄包装
// 设置 STACK=frontend 后委托给 core/scripts/workflow-status.mjs
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { main } from '../../../../core/scripts/workflow-status.mjs';

process.env.STACK = 'frontend';
process.env.CALLER_SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
await main(process.argv.slice(2));
