#!/bin/bash
#
# VAC capture harness (plan 2026-10-24-activity-monitor-parity-top-processes,
# §4a VAC-1…VAC-6). Reuses the prior plan's capture-te.sh launch flags
# (--open-popover --popover-cycles 1 --popover-hold, --capture-appearance
# per-app appearance switch, --expand-processes disclosure seed) and
# windowid.swift polling. Adds:
#   - a display-awake guard (AGENTS.md: an asleep display stalls popover
#     close, which invalidates captures); the run aborts if
#     CGDisplayIsAsleep reports 1.
#   - the VAC-2 fixture env key (STATSLITE_VAC2_FAKE_CPU_FRACTION) so one
#     expanded CPU capture carries a forced ≥100% row through the
#     production processPercentTenth label path.
# Capture set: dark+light for collapsed CPU, expanded CPU (live rows),
# expanded CPU with the VAC-2 fixture, and expanded Memory.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/artifacts/2026-10-24-am-parity-top-processes"
APP="$ROOT/.derivedData/Build/Products/Release/StatsLite.app"

# Display-awake guard (AGENTS.md popover close is display-sleep-sensitive).
AWAKE=$(swift -e 'import CoreGraphics; print(CGDisplayIsAsleep(CGMainDisplayID()))')
if [ "$AWAKE" != "0" ]; then
  echo "error: display is asleep (CGDisplayIsAsleep=$AWAKE); wake it and rerun" >&2
  exit 1
fi

capture() {
  local name="$1" appearance="$2" expand="$3" fixture="${4:-}"
  pkill -x StatsLite 2>/dev/null || true
  sleep 1
  local args=(--open-popover --popover-cycles 1 --popover-hold 20
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
    echo "error: no StatsLite popover window for $name" >&2
    return 1
  fi
  sleep 3
  screencapture -x -o -l"$id" "$OUT/$name.png"
  echo "captured $OUT/$name.png (window id $id)"
  pkill -x StatsLite 2>/dev/null || true
  sleep 1
}

mkdir -p "$OUT"

# VAC-1: caption absent from the collapsed CPU disclosure button.
# No --expand-processes hook: the CPU section stays collapsed, so
# this is the true collapsed-state falsifier for the caption.
capture vac1-dark-collapsed-cpu dark ""
capture vac1-light-collapsed-cpu light ""

# VAC-1/3/4/5: expanded CPU with live rows (caption below last row,
# real titles, max-normalized gauges, container height).
capture vac3-dark-cpu-expanded dark cpu
capture vac3-light-cpu-expanded light cpu

# VAC-2: fixture forces a ≥100% row through the production label path.
STATSLITE_VAC2_FAKE_CPU_FRACTION=1.918 \
  capture vac2-dark-cpu-fixture dark cpu
STATSLITE_VAC2_FAKE_CPU_FRACTION=1.918 \
  capture vac2-light-cpu-fixture light cpu

# VAC-1: caption absent from the Memory section.
capture vac1-dark-memory dark memory
capture vac1-light-memory light memory

echo "all VAC captures done"
