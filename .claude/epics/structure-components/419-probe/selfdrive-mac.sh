#!/bin/bash
# usage: selfdrive-mac.sh <MODE> <CAPTURE> <DEPTH> [extra --env args...]
set -uo pipefail
ROOT="${SPIKE_ROOT:?set SPIKE_ROOT to the directory holding TreeSpike.xcodeproj}"
APPBUNDLE="$ROOT/dd-mac/Build/Products/Debug/TreeSpikeMac.app"
MODE="$1"; CAP="$2"; DEPTH="$3"; TAG="${4:-base}"; shift 4 || shift 3
LOGDIR="$ROOT/out/sd-$MODE-$CAP-$TAG"

pkill -f TreeSpikeMac >/dev/null 2>&1
sleep 1
rm -rf "$LOGDIR"; mkdir -p "$LOGDIR"

open -n -a "$APPBUNDLE" \
  --env "SPIKE_LOG_DIR=$LOGDIR" \
  --env "SPIKE_MODE=$MODE" \
  --env "SPIKE_CAPTURE=$CAP" \
  --env "SPIKE_EXPAND_DEPTH=$DEPTH" \
  --env "SPIKE_SELFDRIVE=1" \
  --env "SPIKE_RESET=1" "$@"

for _ in $(seq 1 60); do
  sleep 1
  if grep -q "DONE" "$LOGDIR/events.tsv" 2>/dev/null; then break; fi
done
sleep 1
pkill -f TreeSpikeMac >/dev/null 2>&1
echo "=== events.tsv ($MODE/$CAP/$TAG) ==="
cat "$LOGDIR/events.tsv" 2>/dev/null || echo "(no events.tsv)"
echo "=== state.json ==="
cat "$LOGDIR/state.json" 2>/dev/null || echo "(no state.json)"
