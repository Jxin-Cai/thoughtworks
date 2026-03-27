#!/usr/bin/env node
// backend-workflow-status.mjs — 后端工作流状态管理薄包装
// 设置 STACK=backend 后委托给 core/scripts/workflow-status.mjs
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { main } from '../../../../core/scripts/workflow-status.mjs';

process.env.STACK = 'backend';
process.env.CALLER_SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
await main(process.argv.slice(2));
