#!/bin/bash
# usage: PROBE_ROOT=... PROBE_UDID=... drive-ios.sh <TAG>
# 手法沿用 419-probe/drive-ios.sh（真 HID via axe）；差别只在按键序列与标记行。
set -uo pipefail
ROOT="${PROBE_ROOT:?set PROBE_ROOT to the directory holding TreeProbe.xcodeproj}"
UDID="${PROBE_UDID:?set PROBE_UDID to a dedicated iOS 26 simulator}"
BUNDLE="com.ohmydesign.probe422.ios"
APP="$ROOT/dd-ios/Build/Products/Debug-iphonesimulator/TreeProbeiOS.app"
TAG="${1:-base}"
OUT="$ROOT/out/ios-$TAG"
rm -rf "$OUT"; mkdir -p "$OUT"

xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
xcrun simctl install "$UDID" "$APP" || exit 1
CONT=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)
rm -f "$CONT/Documents/events.tsv" "$CONT/Documents/state.json"
LOG="$CONT/Documents/events.tsv"

env SIMCTL_CHILD_PROBE_MODE=multiple \
    SIMCTL_CHILD_PROBE_EXPAND_DEPTH=2 \
    SIMCTL_CHILD_PROBE_RESET=1 \
    xcrun simctl launch "$UDID" "$BUNDLE" || exit 1
sleep 4

mark() { printf '#\tMARK\t%s\n' "$1" >> "$LOG"; }
send() { mark "$1"; shift; axe "$@" --udid "$UDID" >/dev/null 2>&1 || echo "    (axe returned non-zero)"; sleep 0.35; }

# 前奏：iOS 上 Tab 不移焦点（419 spike 实测）⇒ 只能点一行把焦点交给树。
send "P0-tap-row-a" tap --id row-a

send "01-down"        key 81
send "02-space"       key 44
send "03-down"        key 81
send "04-space"       key 44
send "05-up"          key 82
send "06-space"       key 44
send "07-right"       key 79
send "08-right"       key 79
send "09-space"       key 44
send "10-right"       key 79
send "11-space"       key 44
send "12-left"        key 80
send "13-space"       key 44
send "14-left"        key 80
send "15-left"        key 80
send "16-space"       key 44
send "17-left"        key 80
send "18-left"        key 80
send "19-space"       key 44
send "20-end"         key 77
send "21-space"       key 44
send "22-home"        key 74
send "23-space"       key 44
send "24-return"      key 40
send "25-shift+down"  key-combo --modifiers 225 --key 81
send "26-control+a"   key-combo --modifiers 224 --key 4
send "27-end"         key 77
send "28-down"        key 81
send "29-space"       key 44

# 焦点在 a1x 时点 a 的 chevron 把它折叠掉（a1x 随之隐藏），再按键：
# 焦点须归约到最近的可见祖先 a，键盘层不能整条失效。
send "30-home"        key 74
send "31-right"       key 79
send "32-right"       key 79
send "33-right"       key 79
send "34-right"       key 79
mark "35-click-chevron-a"
axe describe-ui --udid "$UDID" > "$OUT/describe-before-click.json" 2>&1
XY=$(python3 - "$OUT/describe-before-click.json" <<'PY'
import json, sys
def walk(n):
    yield n
    for c in n.get("children") or []:
        yield from walk(c)
root = json.load(open(sys.argv[1]))
nodes = [m for r in (root if isinstance(root, list) else [root]) for m in walk(r)]
row_a = next(n for n in nodes if n.get("AXUniqueId") == "row-a")["frame"]
cy = row_a["y"] + row_a["height"] / 2
cands = [n["frame"] for n in nodes if n.get("AXLabel") == "Collapse"]
f = min(cands, key=lambda f: abs(f["y"] + f["height"] / 2 - cy))
print(f'{f["x"] + f["width"] / 2:.0f} {f["y"] + f["height"] / 2:.0f}')
PY
)
echo "chevron(a) at $XY"
axe tap -x "${XY% *}" -y "${XY#* }" --udid "$UDID" >/dev/null 2>&1; sleep 0.5
send "36-down"        key 81
send "37-space"       key 44

# 按住 ↓：看系统是否送来 repeat、焦点是否连续移动。
send "38-home"        key 74
send "39-hold-down"   key 81 --duration 1.5
send "40-space"       key 44
send "41-char-g"      key 10
send "42-tab"         key 43

sleep 1
axe screenshot --output "$OUT/screen.png" --udid "$UDID" >/dev/null 2>&1
axe describe-ui --udid "$UDID" > "$OUT/describe-ui.json" 2>&1
cp "$CONT/Documents/events.tsv" "$OUT/events.tsv" 2>/dev/null
cp "$CONT/Documents/state.json" "$OUT/state.json" 2>/dev/null
echo "=== events.tsv (ios/$TAG) ==="
cat "$OUT/events.tsv" 2>/dev/null || echo "(no events.tsv)"
echo "=== state.json ==="
cat "$OUT/state.json" 2>/dev/null || echo "(no state.json)"
