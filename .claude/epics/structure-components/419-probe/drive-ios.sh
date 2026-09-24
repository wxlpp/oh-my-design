#!/bin/bash
# usage: drive-ios.sh <MODE> <CAPTURE> <DEPTH> <TAG> [extra SIMCTL_CHILD_ env assignments...]
set -uo pipefail
ROOT="${SPIKE_ROOT:?set SPIKE_ROOT to the directory holding TreeSpike.xcodeproj}"
UDID="${SPIKE_UDID:?set SPIKE_UDID to a dedicated iOS 26 simulator}"
BUNDLE="com.ohmydesign.spike.ios"
APP="$ROOT/dd-ios/Build/Products/Debug-iphonesimulator/TreeSpikeiOS.app"
MODE="$1"; CAP="$2"; DEPTH="$3"; TAG="$4"; TABS="$5"; shift 5
OUT="$ROOT/out/ios-$MODE-$CAP-$TAG"
rm -rf "$OUT"; mkdir -p "$OUT"

xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
xcrun simctl install "$UDID" "$APP" || exit 1

CONT=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)
rm -f "$CONT/Documents/events.tsv" "$CONT/Documents/state.json"

env SIMCTL_CHILD_SPIKE_MODE="$MODE" \
    SIMCTL_CHILD_SPIKE_CAPTURE="$CAP" \
    SIMCTL_CHILD_SPIKE_EXPAND_DEPTH="$DEPTH" \
    SIMCTL_CHILD_SPIKE_RESET=1 \
    "$@" \
    xcrun simctl launch "$UDID" "$BUNDLE" || exit 1
sleep 4

send() {
  echo "--- $1"
  shift
  axe "$@" --udid "$UDID" >/dev/null 2>&1 || echo "    (axe returned non-zero)"
  sleep 0.4
}

if [ "$TABS" -gt 0 ]; then
  for i in $(seq 1 "$TABS"); do send "prelude-tab-$i" key 43; done
fi

send "downArrow-1"     key 81
send "downArrow-2"     key 81
send "upArrow"         key 82
send "rightArrow"      key 79
send "leftArrow"       key 80
send "home"            key 74
send "end"             key 77
send "space"           key 44
send "return"          key 40
send "shift+downArrow" key-combo --modifiers 225 --key 81
send "shift+upArrow"   key-combo --modifiers 225 --key 82
send "control+a"       key-combo --modifiers 224 --key 4
send "command+a"       key-combo --modifiers 227 --key 4
send "char-g"          key 10
send "asterisk"        key-combo --modifiers 225 --key 37
send "shift+g"         key-combo --modifiers 225 --key 10
send "F2"              key 59
send "tab"             key 43

sleep 1
axe screenshot --output "$OUT/screen.png" --udid "$UDID" >/dev/null 2>&1
axe describe-ui --udid "$UDID" > "$OUT/describe-ui.json" 2>&1
cp "$CONT/Documents/events.tsv" "$OUT/events.tsv" 2>/dev/null
cp "$CONT/Documents/state.json" "$OUT/state.json" 2>/dev/null
echo "=== events.tsv ($MODE/$CAP/$TAG) ==="
cat "$OUT/events.tsv" 2>/dev/null || echo "(no events.tsv)"
echo "=== state.json ==="
cat "$OUT/state.json" 2>/dev/null || echo "(no state.json)"
