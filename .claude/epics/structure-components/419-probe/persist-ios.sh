#!/bin/bash
set -uo pipefail
ROOT="${SPIKE_ROOT:?set SPIKE_ROOT to the directory holding TreeSpike.xcodeproj}"
UDID="${SPIKE_UDID:?set SPIKE_UDID to a dedicated iOS 26 simulator}"
BUNDLE="com.ohmydesign.spike.ios"
APP="$ROOT/dd-ios/Build/Products/Debug-iphonesimulator/TreeSpikeiOS.app"
OUT="$ROOT/out/ios-persist"
rm -rf "$OUT"; mkdir -p "$OUT"

xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
xcrun simctl install "$UDID" "$APP" || exit 1
CONT=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)
rm -f "$CONT/Documents/events.tsv" "$CONT/Documents/state.json" "$CONT/Documents/expanded-persisted.json"

echo "### phase 1: launch with SPIKE_EXPAND_DEPTH=1 (all collapsed), persist-on-change ON"
env SIMCTL_CHILD_SPIKE_MODE=A-core \
    SIMCTL_CHILD_SPIKE_CAPTURE=passthrough \
    SIMCTL_CHILD_SPIKE_EXPAND_DEPTH=1 \
    SIMCTL_CHILD_SPIKE_PERSIST_ON_CHANGE=1 \
    SIMCTL_CHILD_SPIKE_RESTYLE_NESTED=1 \
    SIMCTL_CHILD_SPIKE_RESET=1 \
    xcrun simctl launch "$UDID" "$BUNDLE" || exit 1
sleep 4
echo "state after launch:"; cat "$CONT/Documents/state.json"

echo "### tap the 'Alpha' disclosure header (caller-owned Set must change)"
axe tap --id row-alpha --element-type Button --udid "$UDID" || echo "(tap failed)"
sleep 2
echo "### tap the 'Alpha One' disclosure header (nested, level 2)"
axe tap --id row-alpha-one --element-type Button --udid "$UDID" || echo "(tap failed)"
sleep 2
cp "$CONT/Documents/events.tsv" "$OUT/phase1-events.tsv" 2>/dev/null
cp "$CONT/Documents/state.json" "$OUT/phase1-state.json" 2>/dev/null
cp "$CONT/Documents/expanded-persisted.json" "$OUT/phase1-persisted.json" 2>/dev/null
axe screenshot --output "$OUT/phase1.png" --udid "$UDID" >/dev/null 2>&1
echo "phase1 events:"; cat "$OUT/phase1-events.tsv"
echo "phase1 persisted file:"; cat "$OUT/phase1-persisted.json" 2>/dev/null || echo "(missing)"

echo "### phase 2: relaunch WITHOUT SPIKE_EXPAND_DEPTH -> must restore from the persisted Set"
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
sleep 1
env SIMCTL_CHILD_SPIKE_MODE=A-core \
    SIMCTL_CHILD_SPIKE_CAPTURE=passthrough \
    SIMCTL_CHILD_SPIKE_RESTYLE_NESTED=1 \
    SIMCTL_CHILD_SPIKE_RESET=1 \
    xcrun simctl launch "$UDID" "$BUNDLE" || exit 1
sleep 4
cp "$CONT/Documents/events.tsv" "$OUT/phase2-events.tsv" 2>/dev/null
cp "$CONT/Documents/state.json" "$OUT/phase2-state.json" 2>/dev/null
axe screenshot --output "$OUT/phase2.png" --udid "$UDID" >/dev/null 2>&1
echo "phase2 events:"; cat "$OUT/phase2-events.tsv"
echo "phase2 state:"; cat "$OUT/phase2-state.json"
