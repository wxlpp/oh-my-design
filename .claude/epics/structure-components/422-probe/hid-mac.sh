#!/bin/bash
# usage: PROBE_ROOT=... hid-mac.sh <TAG> [PRELUDE_TABS]
# 手法沿用 419-probe/hid-mac.sh（真 HID via System Events，需要屏幕已解锁 +
# 终端有「辅助功能」权限）；差别只在按键序列与标记行。
set -uo pipefail
ROOT="${PROBE_ROOT:?set PROBE_ROOT to the directory holding TreeProbe.xcodeproj}"
APPBUNDLE="$ROOT/dd-mac/Build/Products/Debug/TreeProbeMac.app"
TAG="${1:-base}"
TABS="${2:-1}"
LOGDIR="$ROOT/out/mac-$TAG"

pkill -f TreeProbeMac >/dev/null 2>&1
sleep 1
rm -rf "$LOGDIR"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/events.tsv"

open -n -a "$APPBUNDLE" \
  --env "PROBE_LOG_DIR=$LOGDIR" \
  --env "PROBE_MODE=multiple" \
  --env "PROBE_EXPAND_DEPTH=2" \
  --env "PROBE_RESET=1"
sleep 4

osascript -e 'tell application "System Events" to tell process "TreeProbeMac" to set frontmost to true' >/dev/null 2>&1
sleep 1
FRONT=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')
echo "FRONTMOST=$FRONT"
if [ "$FRONT" != "TreeProbeMac" ]; then
  echo "ABORT: probe app is not frontmost; refusing to send keys"
  pkill -f TreeProbeMac
  exit 3
fi

mark() { printf '#\tMARK\t%s\n' "$1" >> "$LOG"; }
send() { mark "$1"; osascript -e "tell application \"System Events\" to $2" >/dev/null 2>&1; sleep 0.35; }

# 前奏：macOS 上 Tab 把焦点送进树容器（`.focusable()`），随后第一个 Space 会先按
# W3C 规则解析初始焦点（无选中 → 第一个节点）再执行 ⇒ 这一步同时测初始焦点。
for i in $(seq 1 "$TABS"); do send "P0-tab-$i" 'key code 48'; done
send "P1-space"       'key code 49'

send "01-down"        'key code 125'
send "02-space"       'key code 49'
send "03-down"        'key code 125'
send "04-space"       'key code 49'
send "05-up"          'key code 126'
send "06-space"       'key code 49'
send "07-right"       'key code 124'
send "08-right"       'key code 124'
send "09-space"       'key code 49'
send "10-right"       'key code 124'
send "11-space"       'key code 49'
send "12-left"        'key code 123'
send "13-space"       'key code 49'
send "14-left"        'key code 123'
send "15-left"        'key code 123'
send "16-space"       'key code 49'
send "17-left"        'key code 123'
send "18-left"        'key code 123'
send "19-space"       'key code 49'
send "20-end"         'key code 119'
send "21-space"       'key code 49'
send "22-home"        'key code 115'
send "23-space"       'key code 49'
send "24-return"      'key code 36'
send "25-shift+down"  'key code 125 using {shift down}'
send "26-control+a"   'key code 0 using {control down}'
send "27-end"         'key code 119'
send "28-down"        'key code 125'
send "29-space"       'key code 49'
send "30-char-g"      'key code 5'
send "31-tab"         'key code 48'

sleep 1
screencapture -x -o -l "$(osascript -e 'tell application "System Events" to tell process "TreeProbeMac" to get id of window 1' 2>/dev/null)" "$LOGDIR/window.png" >/dev/null 2>&1
pkill -f TreeProbeMac >/dev/null 2>&1
echo "=== events.tsv (mac/$TAG tabs=$TABS) ==="
cat "$LOG" 2>/dev/null || echo "(no events.tsv)"
echo "=== state.json ==="
cat "$LOGDIR/state.json" 2>/dev/null || echo "(no state.json)"
