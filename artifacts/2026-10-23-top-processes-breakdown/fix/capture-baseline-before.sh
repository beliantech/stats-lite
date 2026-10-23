#!/bin/bash
#
# T-F G1 pre-edit baseline capture (fix cycle, plan
# 2026-10-23-top-processes-breakdown §10).
#
# Same capture pattern as artifacts/.../post/capture-te.sh: the
# Release build, the --open-popover / --popover-cycles 1 /
# --popover-hold 20 launch flags, windowid.swift polling, 1.5 s
# (collapsed) or 3 s (expanded) settle, `screencapture -x -o -l<id>`.
# Appearance switches per-app through --capture-appearance; the
# disclosure state through --expand-processes. No system state is
# touched.
#
# Capture set (G1, before ANY code edit): fully collapsed (GPU card
# collapsed), memory expanded, CPU expanded, GPU card collapsed AND
# expanded — dark and light each.
#
# Display guard: popover capture depends on an awake display (the
# plan's parked display-sleep issue). Each capture checks
# CGDisplayIsAsleep first. Run the whole script caffeinate-wrapped.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="$ROOT/artifacts/2026-10-23-top-processes-breakdown/fix/baseline-before"
APP="$ROOT/.derivedData/Build/Products/Release/StatsLite.app"
HOLD=20

# CGDisplayIsAsleep check: prints "awake" or "asleep".
AWAKE_SRC="$(mktemp /tmp/statslite-display-awake.XXXXXX)"
cat > "$AWAKE_SRC" <<'EOF'
import CoreGraphics
print(CGDisplayIsAsleep(0) != 0 ? "asleep" : "awake")
EOF

require_awake() {
  local state
  state=$(swift "$AWAKE_SRC" 2>/dev/null) || state="unknown"
  if [ "$state" != "awake" ]; then
    echo "error: display is $state; run inside caffeinate and retry" >&2
    rm -f "$AWAKE_SRC"
    exit 1
  fi
}

capture() {
  local name="$1" appearance="$2" expand="${3:-}"
  require_awake
  pkill -x StatsLite 2>/dev/null || true
  sleep 1
  local args=(--open-popover --popover-cycles 1 --popover-hold "$HOLD"
              --capture-appearance "$appearance")
  if [ -n "$expand" ]; then args+=(--expand-processes "$expand"); fi
  "$APP/Contents/MacOS/StatsLite" "${args[@]}" >/dev/null 2>&1 &
  local id=""
  for _ in $(seq 1 30); do
    id=$(swift "$ROOT/scripts/windowid.swift" 2>/dev/null) || id=""
    if [ -n "$id" ]; then break; fi
    sleep 0.5
  done
  if [ -z "$id" ]; then
    echo "error: no StatsLite popover window appeared for $name" >&2
    rm -f "$AWAKE_SRC"
    exit 1
  fi
  if [ -n "$expand" ]; then sleep 3; else sleep 1.5; fi
  require_awake
  screencapture -x -o -l"$id" "$OUT_DIR/$name.png"
  echo "captured $OUT_DIR/$name.png (window id $id, appearance $appearance, expand '${expand:-collapsed}')"
  pkill -x StatsLite 2>/dev/null || true
  sleep 1
}

mkdir -p "$OUT_DIR"

# Fully collapsed: GPU card collapsed too (VAC-B4 before-state).
capture dark dark
capture light light

# Expanded disclosure states.
capture dark-cpu-expanded dark cpu
capture light-cpu-expanded light cpu
capture dark-memory-expanded dark memory
capture light-memory-expanded light memory

# GPU card expanded (VAC-B3/B4 before-state: disclosure + dashed box).
capture dark-gpu-expanded dark gpu
capture light-gpu-expanded light gpu

rm -f "$AWAKE_SRC"
echo "all baseline-before captures done; no system state was modified"
