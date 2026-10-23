#!/bin/bash
#
# T-H cue-dot capture (VAC-B6 / VAC-4, plan
# 2026-10-23-top-processes-breakdown §10 T-H).
#
# Same pattern as artifacts/.../post/capture-cue-dot.sh (T-E):
# 24 `yes` burners load every core before launch, the collapsed dark
# AND light popovers are captured after a 30 s settle so several
# 5 s CPU history samples land above the 0.80 warning boundary
# (CPUCardView.cpuCueState → the 4 pt amber cue dot next to
# `› Top Processes`). Output goes to fix/after/.
#
# The trap kills the burners and the app on every exit path.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="$ROOT/artifacts/2026-10-23-top-processes-breakdown/fix/after"
APP="$ROOT/.derivedData/Build/Products/Release/StatsLite.app"

pkill -x StatsLite 2>/dev/null || true
sleep 1

pids=()
cleanup() {
  trap - EXIT
  kill "${pids[@]}" 2>/dev/null || true
  pkill -x StatsLite 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 24); do
  yes >/dev/null &
  pids+=($!)
done
echo "started ${#pids[@]} CPU burners"
sleep 3

capture() {
  local name="$1" appearance="$2"
  pkill -x StatsLite 2>/dev/null || true
  sleep 1
  "$APP/Contents/MacOS/StatsLite" \
    --open-popover --popover-cycles 1 --popover-hold 45 \
    --capture-appearance "$appearance" >/dev/null 2>&1 &

  local id=""
  for _ in $(seq 1 30); do
    id=$(swift "$ROOT/scripts/windowid.swift" 2>/dev/null) || id=""
    if [ -n "$id" ]; then break; fi
    sleep 0.5
  done
  if [ -z "$id" ]; then
    echo "error: no StatsLite popover window appeared for $name" >&2
    exit 1
  fi

  sleep 30
  screencapture -x -o -l"$id" "$OUT_DIR/$name.png"
  echo "captured $OUT_DIR/$name.png (window id $id, $appearance, collapsed, CPU loaded)"
}

capture dark-cue-dot dark
capture light-cue-dot light
