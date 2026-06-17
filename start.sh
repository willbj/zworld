#!/bin/bash
# ZWorld 一键启动：进入 novels 目录，启动 Studio
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR/novels"
exec node "$REPO_DIR/packages/cli/dist/index.js" "$@"
