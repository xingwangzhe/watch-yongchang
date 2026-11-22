#!/usr/bin/env bash
# 《守望·永昌》一键测试脚本
# 用法见 ./run-test.sh help
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$ROOT/game"
GODOT="${GODOT:-${GDA_GODOT:-/home/xingwangzhe/桌面/Godot_v4.7.2-stable_linux.x86_64}}"
GDA="${GDA:-$HOME/.local/bin/gda}"

need() {
  if [ ! -x "$1" ]; then
    echo "错误：找不到可执行文件 $1" >&2
    exit 1
  fi
}

usage() {
  cat <<EOF
《守望·永昌》测试助手

用法: ./run-test.sh [命令]

  play      窗口模式启动游戏，直接试玩（默认）
  verify     CLI 验证：场景校验 + 启动预检 + 19 项断言（不打开窗口）
  live      启动 gda live daemon，便于用 CLI 观察运行中的场景状态
  stop      停止 live daemon 并卸载临时 harness
  check     先 verify，通过后自动 play
  help      显示本帮助

试玩操作:
  1 / 2 / 3   出兵（乡勇 / 弓手 / 龙灯队，消耗银）
  R           重开一局

EOF
}

do_verify() {
  need "$GDA"
  cd "$ROOT"
  echo "== 1/3 场景静态校验 =="
  "$GDA" scene validate res://scenes/main.tscn --project game --json
  echo "== 2/3 启动预检 =="
  "$GDA" scene preflight res://scenes/main.tscn --project game --frames 20 --json
  echo "== 3/3 自动化断言 =="
  "$GDA" script run res://tests/verify.gd --project game --json > /tmp/shouwang-verify.json 2>&1
  python3 - <<'PY'
import json
d = json.load(open('/tmp/shouwang-verify.json'))
if 'error' in d:
    print('验证脚本运行失败:', d['error'].get('message'))
    raise SystemExit(1)
out = d.get('stdout', '')
for line in out.splitlines():
    if line.startswith('[SUMMARY]') or line.startswith('[FAIL]'):
        print(line)
raise SystemExit(0 if d.get('exit_status') == 0 and '[SUMMARY] PASS=19 FAIL=0' in out else 1)
PY
  echo "验证通过。"
}

do_play() {
  need "$GODOT"
  echo "窗口模式启动游戏：$GODOT --path $GAME_DIR"
  exec "$GODOT" --path "$GAME_DIR" --windowed
}

do_live() {
  need "$GDA"
  cd "$ROOT"
  "$GDA" daemon start --project game --json
  "$GDA" daemon wait-ready --project game --json
  echo "live daemon 已就绪。可用命令："
  echo "  $GDA game call /root/GameState --method get_debug_snapshot --project game --json"
  echo "  $GDA logger tail --project game --json"
  echo "  $GDA diag errors --project game --json"
  echo "观察完毕后运行 ./run-test.sh stop 清理。"
}

do_stop() {
  need "$GDA"
  cd "$ROOT"
  "$GDA" daemon stop --project game --json || true
  "$GDA" daemon uninstall --project game --json || true
  echo "live daemon 已停止，harness 已清理。"
}

case "${1:-play}" in
  play)   do_play ;;
  verify) do_verify ;;
  live)   do_live ;;
  stop)   do_stop ;;
  check)  do_verify && do_play ;;
  help|-h|--help) usage ;;
  *) echo "未知命令: $1（用 ./run-test.sh help 查看用法）" >&2; exit 1 ;;
esac
