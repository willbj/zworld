#!/bin/bash
# ZWorld 启动脚本 — 后台运行，终端立即返回
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$REPO_DIR/.zworld-studio.pid"
LOG_FILE="$REPO_DIR/.zworld-studio.log"
NODE="node"
CLI="$REPO_DIR/packages/cli/dist/index.js"
NOVELS="$REPO_DIR/novels"

is_running() {
  [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

start_studio() {
  mkdir -p "$NOVELS"
  cd "$NOVELS"
  NODE_NO_WARNINGS=1 nohup "$NODE" "$CLI" >> "$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  echo "ZWorld Studio 启动中... 日志：$LOG_FILE"
  # 等待服务就绪
  local i=0
  while ! curl -s http://localhost:4567 >/dev/null 2>&1; do
    sleep 0.5; i=$((i+1)); [ $i -ge 20 ] && break
  done
  open http://localhost:4567 2>/dev/null || true
  echo "已就绪：http://localhost:4567"
}

stop_studio() {
  if is_running; then
    echo "停止 ZWorld Studio (pid: $(cat "$PID_FILE"))..."
    kill "$(cat "$PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE"
  else
    # 兜底：用端口查杀
    local pids; pids=$(lsof -ti :4567 2>/dev/null)
    [ -n "$pids" ] && echo "$pids" | xargs kill -9 2>/dev/null && rm -f "$PID_FILE"
  fi
}

case "$1" in
  stop)
    stop_studio
    echo "已停止"
    ;;
  restart)
    stop_studio
    sleep 0.5
    start_studio
    ;;
  log)
    tail -f "$LOG_FILE"
    ;;
  status)
    is_running && echo "运行中 (pid: $(cat "$PID_FILE"))" || echo "未运行"
    ;;
  "")
    if is_running; then
      echo "Studio 已在运行 (pid: $(cat "$PID_FILE"))，直接打开浏览器"
      open http://localhost:4567 2>/dev/null || true
    else
      start_studio
    fi
    ;;
  *)
    cd "$NOVELS"
    exec "$NODE" "$CLI" "$@"
    ;;
esac
