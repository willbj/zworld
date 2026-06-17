#!/usr/bin/env zsh
# ZWorld 一键环境配置：将 zworld 命令注册到 ~/.zshrc
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
MARKER="# >>> zworld >>>"
MARKER_END="# <<< zworld <<<"

# 生成函数定义（复用于写入 .zshrc 和当前 session）
_zworld_block() {
  cat << BLOCK
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
  echo "✓ 已就绪 → http://localhost:4567"
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
        echo "Studio 运行中 → http://localhost:4567"
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
BLOCK
}

# 检测是否以 source 方式运行
_is_sourced=false
[[ "${ZSH_EVAL_CONTEXT}" == *:file* ]] && _is_sourced=true

# 1. 写入或更新 ~/.zshrc（持久化）
if grep -q "$MARKER" "$ZSHRC" 2>/dev/null; then
  # 已存在则替换旧内容（用 Python 处理多行替换更可靠）
  python3 - "$ZSHRC" "$MARKER" "$MARKER_END" "$(_zworld_block)" << 'PY'
import sys
path, start, end, new_block = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(path) as f: content = f.read()
import re
content = re.sub(
  re.escape(start) + r'.*?' + re.escape(end),
  start + '\n' + new_block + '\n' + end,
  content, flags=re.DOTALL
)
with open(path, 'w') as f: f.write(content)
PY
  echo "✓ zworld 已更新 ~/.zshrc"
else
  { echo; echo "$MARKER"; _zworld_block; echo "$MARKER_END"; } >> "$ZSHRC"
  echo "✓ zworld 已写入 ~/.zshrc"
fi

# 2. source 模式下直接 eval，当前终端立即生效
if $_is_sourced; then
  eval "$(_zworld_block)"
fi

echo ""
echo "可用命令："
echo "  zworld           → 启动 Studio"
echo "  zworld restart   → 重启"
echo "  zworld stop      → 停止"
echo "  zworld status    → 查看状态"
echo "  zworld log       → 查看日志"
echo "  zworld build     → 重新构建"
echo "  zworld update    → 拉最新代码并重建"
echo "  zworld book create --title '书名' --genre xuanhuan"
echo ""
if $_is_sourced; then
  echo "✓ 当前终端已生效，新终端自动生效。"
else
  echo "✓ source ./setup.sh  → 当前终端立即生效，新终端自动生效"
  echo "  ./setup.sh         → 仅写入 ~/.zshrc，需新开终端才生效"
fi
