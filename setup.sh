#!/bin/bash
# ZWorld 一键环境配置：将 zworld 命令注册到 ~/.zshrc
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
MARKER="# >>> zworld >>>"
MARKER_END="# <<< zworld <<<"

# 检查是否已安装
if grep -q "$MARKER" "$ZSHRC" 2>/dev/null; then
  echo "zworld 已配置，跳过写入"
else
  cat >> "$ZSHRC" << SHELL

$MARKER
export ZWORLD_REPO="$REPO_DIR"
__zworld_pid_file="\$ZWORLD_REPO/.zworld-studio.pid"
__zworld_log_file="\$ZWORLD_REPO/.zworld-studio.log"

__zworld_is_running() {
  [ -f "\$__zworld_pid_file" ] && kill -0 "\$(cat "\$__zworld_pid_file")" 2>/dev/null
}

__zworld_stop() {
  if __zworld_is_running; then
    echo "停止 ZWorld Studio (pid: \$(cat "\$__zworld_pid_file"))..."
    kill "\$(cat "\$__zworld_pid_file")" 2>/dev/null
    rm -f "\$__zworld_pid_file"
  fi
  local pids; pids=\$(lsof -ti :4567 2>/dev/null)
  [ -n "\$pids" ] && echo "\$pids" | xargs kill -9 2>/dev/null && rm -f "\$__zworld_pid_file"
}

__zworld_start() {
  mkdir -p "\$ZWORLD_REPO/novels"
  cd "\$ZWORLD_REPO/novels"
  NODE_NO_WARNINGS=1 nohup node "\$ZWORLD_REPO/packages/cli/dist/index.js" >> "\$__zworld_log_file" 2>&1 &
  echo \$! > "\$__zworld_pid_file"
  echo "ZWorld Studio 启动中..."
  local i=0
  while ! curl -s http://localhost:4567 >/dev/null 2>&1; do
    sleep 0.5; i=\$((i+1)); [ \$i -ge 20 ] && break
  done
  open http://localhost:4567 2>/dev/null || true
  echo "已就绪：http://localhost:4567"
}

zworld() {
  case "\$1" in
    stop)    __zworld_stop; echo "已停止" ;;
    restart) __zworld_stop; sleep 0.5; __zworld_start ;;
    log)     tail -f "\$__zworld_log_file" ;;
    status)  __zworld_is_running && echo "运行中 (pid: \$(cat "\$__zworld_pid_file"))" || echo "未运行" ;;
    build)   cd "\$ZWORLD_REPO" && pnpm build ;;
    update)  cd "\$ZWORLD_REPO" && git pull && pnpm install && pnpm build && echo "更新完成" ;;
    "")
      if __zworld_is_running; then
        echo "Studio 已运行，打开浏览器..."
        open http://localhost:4567 2>/dev/null || true
      else
        __zworld_start
      fi
      ;;
    *)
      cd "\$ZWORLD_REPO/novels"
      NODE_NO_WARNINGS=1 node "\$ZWORLD_REPO/packages/cli/dist/index.js" "\$@"
      ;;
  esac
}
$MARKER_END
SHELL
  echo "✓ zworld 已写入 $ZSHRC"
fi

# 立即生效
source "$ZSHRC"
echo ""
echo "配置完成！现在可以用："
echo "  zworld           → 启动 Studio"
echo "  zworld restart   → 重启"
echo "  zworld stop      → 停止"
echo "  zworld status    → 查看状态"
echo "  zworld log       → 查看日志"
echo "  zworld build     → 重新构建"
echo "  zworld update    → 拉最新代码并重建"
echo "  zworld book create --title '书名' --genre xuanhuan"
echo ""
echo "新终端直接使用，无需任何额外设置。"
