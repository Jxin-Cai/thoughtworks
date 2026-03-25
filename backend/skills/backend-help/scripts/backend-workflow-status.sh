#!/usr/bin/env bash
# 后端工作流状态管理 — 薄包装，委托给 core/scripts/workflow-status.sh
export STACK=backend
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export CALLER_SCRIPT_DIR="$SCRIPT_DIR"
exec bash "$SCRIPT_DIR/../../../../core/scripts/workflow-status.sh" "$@"
