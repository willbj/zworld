#!/bin/bash
# ZWorld 一键启动：进入 novels 目录，启动 Studio
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

stop_studio() {
  local pid
  pid=$(lsof -ti :4567 2>/dev/null)
  if [ -n "$pid" ]; then
    echo "停止旧进程 (pid: $pid)..."
    kill "$pid" 2>/dev/null
    sleep 1
  fi
}

case "$1" in
  stop)
    stop_studio
    echo "ZWorld Studio 已停止"
    ;;
  restart)
    stop_studio
    cd "$REPO_DIR/novels"
    exec node "$REPO_DIR/packages/cli/dist/index.js"
    ;;
  *)
    cd "$REPO_DIR/novels"
    exec node "$REPO_DIR/packages/cli/dist/index.js" "$@"
    ;;
esac
