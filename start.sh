#!/bin/bash
# ZWorld 一键启动：进入 novels 目录，启动 Studio
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

stop_studio() {
  local pids
  pids=$(lsof -ti :4567 2>/dev/null)
  if [ -n "$pids" ]; then
    echo "停止旧进程 (pid: $(echo $pids | tr '\n' ' '))..."
    echo "$pids" | xargs kill -9 2>/dev/null
    # 等待端口真正释放
    local i=0
    while lsof -ti :4567 >/dev/null 2>&1; do
      sleep 0.5
      i=$((i+1))
      [ $i -ge 10 ] && break
    done
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
