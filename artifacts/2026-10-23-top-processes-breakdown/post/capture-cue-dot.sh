#!/bin/bash
#
# T-E VAC-4 cue-dot capture (deviation D3, plan
# 2026-10-23-top-processes-breakdown).
#
# The 8 planned captures all ran on an idle CPU, so none shows the
# collapsed high-use cue dot (VAC-4: 4 pt amber/red dot when the
# parent metric is at warning/critical). This one-off harness loads
# every core BEFORE the app launches, then captures the collapsed
# dark popover after 30 s so several 5 s CPU history samples land
# above the 0.80 warning boundary (CPUCardView.cpuCueState).
#
# Deviations from capture-te.sh: the settle is 30 s instead of 1.5 s
# (history needs two 5 s ticks past launch) and the host runs 24
# `yes` burners for the duration. The capture flags are otherwise
# identical. The trap kills the burners and the app on every exit
# path.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="$ROOT/artifacts/2026-10-23-top-processes-breakdown/post"
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

"$APP/Contents/MacOS/StatsLite" \
  --open-popover --popover-cycles 1 --popover-hold 45 \
  --capture-appearance dark >/dev/null 2>&1 &

id=""
for _ in $(seq 1 30); do
  id=$(swift "$ROOT/scripts/windowid.swift" 2>/dev/null) || id=""
  if [ -n "$id" ]; then break; fi
  sleep 0.5
done
if [ -z "$id" ]; then
  echo "error: no StatsLite popover window appeared" >&2
  exit 1
fi

sleep 30
screencapture -x -o -l"$id" "$OUT_DIR/dark-cue-dot.png"
echo "captured $OUT_DIR/dark-cue-dot.png (window id $id, dark, collapsed, CPU loaded)"
