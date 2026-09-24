#!/bin/bash
# usage: hid-mac.sh <MODE> <CAPTURE> <DEPTH> <TAG> <PRELUDE_TABS> [extra --env args...]
set -uo pipefail
ROOT="${SPIKE_ROOT:?set SPIKE_ROOT to the directory holding TreeSpike.xcodeproj}"
APPBUNDLE="$ROOT/dd-mac/Build/Products/Debug/TreeSpikeMac.app"
MODE="$1"; CAP="$2"; DEPTH="$3"; TAG="$4"; TABS="$5"; shift 5
LOGDIR="$ROOT/out/hid-$MODE-$CAP-$TAG"

pkill -f TreeSpikeMac >/dev/null 2>&1
sleep 1
rm -rf "$LOGDIR"; mkdir -p "$LOGDIR"

open -n -a "$APPBUNDLE" \
  --env "SPIKE_LOG_DIR=$LOGDIR" \
  --env "SPIKE_MODE=$MODE" \
  --env "SPIKE_CAPTURE=$CAP" \
  --env "SPIKE_EXPAND_DEPTH=$DEPTH" \
  --env "SPIKE_RESET=1" "$@"
sleep 4

osascript -e 'tell application "System Events" to tell process "TreeSpikeMac" to set frontmost to true' >/dev/null 2>&1
sleep 1
FRONT=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')
echo "FRONTMOST=$FRONT"
if [ "$FRONT" != "TreeSpikeMac" ]; then
  echo "ABORT: spike app is not frontmost; refusing to send keys"
  pkill -f TreeSpikeMac
  exit 3
fi

send() {
  echo "--- $1"
  osascript -e "tell application \"System Events\" to $2" >/dev/null 2>&1
  sleep 0.4
}

if [ "$TABS" -gt 0 ]; then
  for i in $(seq 1 "$TABS"); do send "prelude-tab-$i" 'key code 48'; done
fi

send "downArrow-1"      'key code 125'
send "downArrow-2"      'key code 125'
send "upArrow"          'key code 126'
send "rightArrow"       'key code 124'
send "leftArrow"        'key code 123'
send "home"             'key code 115'
send "end"              'key code 119'
send "space"            'key code 49'
send "return"           'key code 36'
send "shift+downArrow"  'key code 125 using {shift down}'
send "shift+upArrow"    'key code 126 using {shift down}'
send "control+a"        'key code 0 using {control down}'
send "command+a"        'key code 0 using {command down}'
send "char-g"           'key code 5'
send "shift+8"          'key code 28 using {shift down}'
send "shift+g"          'key code 5 using {shift down}'
send "F2"               'key code 120'
send "tab"              'key code 48'

sleep 1
screencapture -x -o -l "$(osascript -e 'tell application "System Events" to tell process "TreeSpikeMac" to get id of window 1' 2>/dev/null)" "$LOGDIR/window.png" >/dev/null 2>&1
cp "$LOGDIR/state.json" "$LOGDIR/state-final.json" 2>/dev/null
pkill -f TreeSpikeMac >/dev/null 2>&1
echo "=== events.tsv ($MODE/$CAP/$TAG tabs=$TABS) ==="
cat "$LOGDIR/events.tsv" 2>/dev/null || echo "(no events.tsv)"
echo "=== state-final.json ==="
cat "$LOGDIR/state-final.json" 2>/dev/null || echo "(no state.json)"
