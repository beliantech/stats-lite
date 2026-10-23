#!/bin/bash
#
# T-E capture harness (deviation D1, plan 2026-10-23-top-processes-breakdown).
#
# scripts/capture_baseline.sh cannot run in this session: its system
# appearance switch (`osascript ... System Events ... dark mode`)
# fails with -1743 (Not authorized to send Apple events) because the
# host process holds no TCC Automation permission, and the grant
# requires an interactive dialog. The script stays unmodified.
#
# This harness replicates the script's capture sequence exactly —
# same launch flags (--open-popover --popover-cycles 1
# --popover-hold 20), same windowid.swift polling, same 1.5 s
# settle, same `screencapture -x -o -l<id>` — and switches appearance
# PER-APP through the `--capture-appearance <dark|light>` launch
# hook (StatsLiteApp.swift, clearly marked verification hook) instead
# of switching the system appearance. No system state is touched.
#
# Extra captures beyond the script: the expanded Top Processes
# disclosure states (VAC-3..9, VAC-13) via the `--expand-processes
# <cpu|memory|gpu>` verification hook (PopoverContentView.swift).
# Expanded captures settle 3 s so at least two sampler ticks land
# before the shutter.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="$ROOT/artifacts/2026-10-23-top-processes-breakdown/post"
APP="$ROOT/.derivedData/Build/Products/Release/StatsLite.app"
HOLD=20

capture() {
  local name="$1" appearance="$2" expand="${3:-}"
  pkill -x StatsLite 2>/dev/null || true
  sleep 1
  local args=(--open-popover --popover-cycles 1 --popover-hold "$HOLD"
              --capture-appearance "$appearance")
  if [ -n "$expand" ]; then args+=(--expand-processes "$expand"); fi
  "$APP/Contents/MacOS/StatsLite" "${args[@]}" >/dev/null 2>&1 &
  local id="" attempt
  for attempt in $(seq 1 30); do
    id=$(swift "$ROOT/scripts/windowid.swift" 2>/dev/null) || id=""
    if [ -n "$id" ]; then break; fi
    sleep 0.5
  done
  if [ -z "$id" ]; then
    echo "error: no StatsLite popover window appeared for $name" >&2
    return 1
  fi
  if [ -n "$expand" ]; then sleep 3; else sleep 1.5; fi
  screencapture -x -o -l"$id" "$OUT_DIR/$name.png"
  echo "captured $OUT_DIR/$name.png (window id $id, appearance $appearance, expand '${expand:-collapsed}')"
  pkill -x StatsLite 2>/dev/null || true
  sleep 1
}

mkdir -p "$OUT_DIR"

# Collapsed captures on the script's paths (dark.png, light.png).
capture dark dark
capture light light

# Expanded disclosure captures for VAC-3..9 and VAC-13.
capture dark-cpu-expanded dark cpu
capture light-cpu-expanded light cpu
capture dark-memory-expanded dark memory
capture light-memory-expanded light memory
capture dark-gpu-expanded dark gpu
capture light-gpu-expanded light gpu

echo "all captures done; no system state was modified"
