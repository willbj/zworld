#!/usr/bin/env zsh
# ZWorld 一键环境配置：将 zworld 命令注册到 ~/.zshrc
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
MARKER="# >>> zworld >>>"
MARKER_END="# <<< zworld <<<"
ZWORLD_PORT=4567

# ── 检测是否以 source 方式运行 ───────────────────────────────────────────────
_is_sourced=false
[[ "${ZSH_EVAL_CONTEXT}" == *:file* ]] && _is_sourced=true

_abort() {
  echo "$1"
  $_is_sourced && return 1 || exit 1
}

# ── 前置检查 ─────────────────────────────────────────────────────────────────
if ! command -v node >/dev/null 2>&1; then
  _abort "✗ 未找到 Node.js，请先安装 Node.js >= 20（https://nodejs.org）"
fi
_node_major=$(node -e "process.stdout.write(process.versions.node.split('.')[0])")
if [ "$_node_major" -lt 20 ] 2>/dev/null; then
  _abort "✗ Node.js 版本过低（当前 v$(node -v)），需要 >= 20"
fi

if ! command -v pnpm >/dev/null 2>&1; then
  _abort "✗ 未找到 pnpm，请先安装：npm install -g pnpm"
fi

if [ ! -f "$REPO_DIR/packages/cli/dist/index.js" ]; then
  echo "⚠ 尚未构建，正在执行 pnpm install && pnpm build..."
  (cd "$REPO_DIR" && pnpm install && pnpm build) || _abort "✗ 构建失败，请检查上方错误后重试"
  echo "✓ 构建完成"
fi

# ── 生成函数定义（复用于写入 .zshrc 和当前 session）─────────────────────────
_zworld_block() {
  cat << BLOCK
export ZWORLD_REPO="$REPO_DIR"
export ZWORLD_PORT="${ZWORLD_PORT}"
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
  local pids; pids=\$(lsof -ti :\$ZWORLD_PORT 2>/dev/null)
  [ -n "\$pids" ] && echo "\$pids" | xargs kill -9 2>/dev/null && rm -f "\$__zworld_pid_file"
}

__zworld_start() {
  if [ ! -f "\$ZWORLD_REPO/packages/cli/dist/index.js" ]; then
    echo "✗ 尚未构建，请先运行：zworld build"
    return 1
  fi
  mkdir -p "\$ZWORLD_REPO/novels"
  cd "\$ZWORLD_REPO/novels"
  NODE_NO_WARNINGS=1 nohup node "\$ZWORLD_REPO/packages/cli/dist/index.js" >> "\$__zworld_log_file" 2>&1 &
  echo \$! > "\$__zworld_pid_file"
  echo "ZWorld Studio 启动中..."
  local i=0
  while ! curl -s http://localhost:\$ZWORLD_PORT >/dev/null 2>&1; do
    sleep 0.5; i=\$((i+1))
    if [ \$i -ge 20 ]; then
      echo "✗ 启动超时，最近日志："
      tail -n 15 "\$__zworld_log_file"
      return 1
    fi
  done
  echo "✓ 已就绪 → http://localhost:\$ZWORLD_PORT"
}

zworld() {
  case "\$1" in
    stop)
      __zworld_stop; echo "已停止"
      ;;
    restart)
      __zworld_stop; sleep 0.5; __zworld_start
      ;;
    log)
      tail -f "\$__zworld_log_file"
      ;;
    status)
      __zworld_is_running && echo "运行中 (pid: \$(cat "\$__zworld_pid_file"))" || echo "未运行"
      ;;
    build)
      cd "\$ZWORLD_REPO" && pnpm build
      ;;
    update)
      local was_running=false
      __zworld_is_running && was_running=true
      \$was_running && __zworld_stop
      cd "\$ZWORLD_REPO" && git pull && pnpm install && pnpm build && echo "更新完成"
      \$was_running && __zworld_start
      ;;
    "")
      if __zworld_is_running; then
        echo "Studio 运行中 → http://localhost:\$ZWORLD_PORT"
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

# ── 写入或更新 ~/.zshrc（用 awk 删旧块再追加，无需 Python3）──────────────────
if grep -q "$MARKER" "$ZSHRC" 2>/dev/null; then
  awk '/# >>> zworld >>>/,/# <<< zworld <<</{next}1' "$ZSHRC" > "${ZSHRC}.zworld.tmp" \
    && mv "${ZSHRC}.zworld.tmp" "$ZSHRC"
  echo "✓ zworld 已更新 ~/.zshrc"
else
  echo "✓ zworld 已写入 ~/.zshrc"
fi
{ echo; echo "$MARKER"; _zworld_block; echo "$MARKER_END"; } >> "$ZSHRC"

# ── source 模式下直接 eval，当前终端立即生效 ─────────────────────────────────
if $_is_sourced; then
  eval "$(_zworld_block)"
fi

# ── 首次配置提示 ─────────────────────────────────────────────────────────────
if [ ! -f "$REPO_DIR/novels/.zworld/secrets.json" ]; then
  echo ""
  echo "⚠ 未检测到 API Key 配置，启动后请先运行："
  echo "  zworld config"
fi

echo ""
echo "可用命令："
echo "  zworld           → 启动 Studio"
echo "  zworld restart   → 重启"
echo "  zworld stop      → 停止"
echo "  zworld status    → 查看状态"
echo "  zworld log       → 查看日志"
echo "  zworld build     → 重新构建"
echo "  zworld update    → 拉最新代码并重建（运行中则自动重启）"
echo "  zworld book create --title '书名' --genre xuanhuan"
echo ""
if $_is_sourced; then
  echo "✓ 当前终端已生效，新终端自动生效。"
else
  echo "✓ source ./setup.sh  → 当前终端立即生效，新终端自动生效"
  echo "  ./setup.sh         → 仅写入 ~/.zshrc，需新开终端才生效"
fi
