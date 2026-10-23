#!/bin/bash
#
# T-F D1 attribution run (plan §10 ISC, fix cycle).
#
# Runs the instrumented Release build with the Memory disclosure
# expanded so the fallback symptom is active while the sampler logs
# every name-lookup candidate: pid, cpu/memory list membership, budget
# order, lookup outcome, raw proc_pidpath / proc_name return values
# with errno, and the published row names per pass.
#
# Output: artifacts/2026-10-23-top-processes-breakdown/fix/
#         attribution-2026-10-23.txt  (header + raw log)
#         attribution-memory-symptom.png (symptom visible during the
#         logged run)
#
# Run caffeinate-wrapped: the display must stay awake.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="$ROOT/artifacts/2026-10-23-top-processes-breakdown/fix"
APP="$ROOT/.derivedData/Build/Products/Release/StatsLite.app"
LOG="/tmp/statslite-d1-attribution.log"
SHOT="$OUT_DIR/attribution-memory-symptom.png"
ARTIFACT="$OUT_DIR/attribution-2026-10-23.txt"

# Same display-awake guard as capture-baseline-before.sh.
AWAKE_SRC="$(mktemp /tmp/statslite-display-awake.XXXXXX)"
cat > "$AWAKE_SRC" <<'EOF'
import CoreGraphics
print(CGDisplayIsAsleep(0) != 0 ? "asleep" : "awake")
EOF
state=$(swift "$AWAKE_SRC" 2>/dev/null) || state="unknown"
rm -f "$AWAKE_SRC"
if [ "$state" != "awake" ]; then
  echo "error: display is $state; run inside caffeinate and retry" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
rm -f "$LOG"
pkill -x StatsLite 2>/dev/null || true
sleep 1

STATSLITE_D1_ATTRIB_FILE="$LOG" \
  "$APP/Contents/MacOS/StatsLite" \
    --open-popover --popover-cycles 1 --popover-hold 20 \
    --capture-appearance dark --expand-processes memory \
  >/dev/null 2>&1 &

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

# Pass cadence with the 5 s refresh interval: tick 0, warm-up at
# +250 ms, then +5.25 s, +10.25 s. Twelve seconds covers four
# logged passes with the symptom on screen.
sleep 12
screencapture -x -o -l"$id" "$SHOT"
sleep 1
pkill -x StatsLite 2>/dev/null || true
sleep 1

if [ ! -s "$LOG" ]; then
  echo "error: attribution log is empty" >&2
  exit 1
fi

{
  echo "D1 ATTRIBUTION RUN — plan 2026-10-23-top-processes-breakdown §10"
  echo "date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "build: Release, instrumented commit 7232dd5 (transient, reverted after this run)"
  echo "launch: --open-popover --popover-cycles 1 --popover-hold 20 --capture-appearance dark --expand-processes memory"
  echo "env: STATSLITE_D1_ATTRIB_FILE=$LOG"
  echo "refreshInterval: 5 s (tick 0, warm-up +250 ms, then +5 s)"
  echo "symptom shot during run: attribution-memory-symptom.png"
  echo "line format:"
  echo "  pass=N pid=P lists=cpu|memory|cpu+memory budget=K/8 lookedUp=yes name=... pathRC=... pathErrno=... nameRC=... nameErrno=..."
  echo "  pass=N pid=P lists=... budget=n/a lookedUp=no reason=budget-cap(8)|resolved-cap(5)|..."
  echo "  pass=N summary lookups=L resolved=R stop=... cpuPids=[...] memoryPids=[...]"
  echo "  pass=N published cpu=[...] memory=[...]   (fallback names prove the symptom)"
  echo "pathRC/nameRC: bytes written by proc_pidpath/proc_name; 0 = failure; nameRC -1 = proc_name not called."
  echo "---- raw log ----"
  cat "$LOG"
} > "$ARTIFACT"

echo "wrote $ARTIFACT"
echo "wrote $SHOT"
