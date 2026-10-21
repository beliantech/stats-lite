#!/bin/bash
#
# Measures StatsLite process footprint across automated popover cycles.
#
# Usage:
#   scripts/measure_popover_footprint.sh --output <file> \
#       [--binary <StatsLite.app>] [--cycles N] [--hold N] [--tail N]
#
# The script launches the release build with the --open-popover
# measurement hook, samples `footprint -w <pid>` every 0.4 s, and
# writes a summary plus the raw samples to <file>. Sampling and
# cleanup use the exact pid captured at launch ($!), so the sampler
# can never attach to another process. The launched app is killed on
# exit.
#
# Per-sample columns come from the footprint -w category table:
#   Footprint total, Owned physical footprint (unmapped) (graphics)
#   Dirty / Reclaimable / Wired / region count, IOSurface Dirty and
#   Reclaimable, Malloc Small Dirty, phys_footprint_peak.
#
# Cycle timing comes from the app hook: the first open is ~1 s after
# launch, each hold lasts <hold> s, the close goes through the normal
# close path, and the next open follows 2 s after the close.
# Defaults: 3 cycles, 5 s hold, 40 s tail. The tail measures how far
# the footprint falls after the last close.
#
# Without --binary, the script builds the worktree release config into
# <worktree>/.derivedData when the app is missing or older than the
# newest Swift source file.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT=""
BINARY=""
CYCLES=3
HOLD=5
TAIL=40

while [ $# -gt 0 ]; do
  case "$1" in
    --output) OUTPUT="$2"; shift 2 ;;
    --binary) BINARY="$2"; shift 2 ;;
    --cycles) CYCLES="$2"; shift 2 ;;
    --hold) HOLD="$2"; shift 2 ;;
    --tail) TAIL="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$OUTPUT" ]; then
  echo "error: --output <file> is required" >&2
  exit 2
fi

# Fail fast on malformed counts so the app never launches for a run
# that cannot complete.
validate_int() {
  case "$2" in
    ''|*[!0-9]*)
      echo "error: $1 must be a non-negative integer (got: $2)" >&2
      exit 2
      ;;
  esac
}
validate_int --cycles "$CYCLES"
validate_int --hold "$HOLD"
validate_int --tail "$TAIL"

build_release() {
  if ! xcodebuild -version >/dev/null 2>&1; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  fi
  xcodebuild -project "$ROOT/StatsLite.xcodeproj" -scheme StatsLite \
    -configuration Release -derivedDataPath "$ROOT/.derivedData" build
}

resolve_app() {
  if [ -n "$BINARY" ]; then
    APP="$BINARY"
  else
    APP="$ROOT/.derivedData/Build/Products/Release/StatsLite.app"
    local newest
    newest=$(ls -t "$ROOT"/StatsLite/*.swift | head -1)
    if [ ! -d "$APP" ] || [ "$newest" -nt "$APP/Contents/MacOS/StatsLite" ]; then
      build_release
    fi
  fi
  if [ ! -x "$APP/Contents/MacOS/StatsLite" ]; then
    echo "error: $APP/Contents/MacOS/StatsLite is not executable" >&2
    exit 1
  fi
}

resolve_app

WORK="$(mktemp -d)"
APPLOG="$WORK/app.log"
SAMPLES="$WORK/samples.txt"
APP_PID=""

cleanup() {
  trap - EXIT
  if [ -n "$APP_PID" ]; then
    kill "$APP_PID" 2>/dev/null || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

# Quit any running instance so the measurement runs with a single
# StatsLite process.
pkill -x StatsLite 2>/dev/null || true
for _ in $(seq 1 50); do
  if ! pgrep -x StatsLite >/dev/null; then break; fi
  sleep 0.1
done

"$APP/Contents/MacOS/StatsLite" \
  --open-popover --popover-cycles "$CYCLES" --popover-hold "$HOLD" \
  >"$APPLOG" 2>&1 &
APP_PID=$!
echo "launched pid $APP_PID"

sleep 0.5
if ! kill -0 "$APP_PID" 2>/dev/null; then
  echo "error: StatsLite did not stay running. App log:" >&2
  cat "$APPLOG" >&2
  exit 1
fi

# Samples for the whole cycle run plus the tail. The cycle run needs
# 1 s before the first open plus <hold> + 2 s per cycle.
DURATION=$((1 + CYCLES * (HOLD + 2) + TAIL))
SECONDS=0
while [ "$SECONDS" -lt "$DURATION" ]; do
  ts=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "$ts NO_PROCESS" >>"$SAMPLES"
  else
    footprint -w "$APP_PID" 2>/dev/null | awk -v ts="$ts" '
      function mb(v, u) {
        if (u == "MB") return v + 0
        if (u == "KB") return (v + 0) / 1024
        if (u == "GB") return (v + 0) * 1024
        if (u == "B")  return (v + 0) / 1048576
        return v + 0
      }
      /Footprint:/ {
        for (i = 1; i <= NF; i++) if ($i == "Footprint:") foot = mb($(i+1), $(i+2))
        found = 1
      }
      /Owned physical footprint \(unmapped\) \(graphics\)/ {
        gd = mb($1, $2); gr = mb($7, $8); gw = mb($9, $10); greg = $11 + 0
      }
      $NF == "IOSurface"  { id = mb($1, $2); ir = mb($7, $8) }
      /Malloc Small$/     { ms = mb($1, $2) }
      /phys_footprint_peak:/ { pk = mb($(NF-1), $NF) }
      END {
        if (!found) { printf "%s FOOTPRINT_FAILED\n", ts; exit }
        printf "%s SAMPLE %.1f %.1f %.1f %.1f %d %.1f %.1f %.1f %.1f\n", \
          ts, foot, gd, gr, gw, greg, id, ir, ms, pk
      }' >>"$SAMPLES" || true
  fi
  sleep 0.4
done

{
  echo "# StatsLite popover footprint measurement"
  echo "# date: $(date)"
  echo "# binary: $APP"
  echo "# pid: $APP_PID"
  echo "# cycles: $CYCLES  hold: ${HOLD}s  gap: 2s  tail: ${TAIL}s  interval: 0.4s"
  echo
  awk -v inv_tol_pct=20 '
    function fmt(x) { return sprintf("%.1f", x) }
    FNR == NR {
      if ($1 == "[measurement]" && $3 == "cycle") {
        if ($5 == "open") open_ts[$4] = $2 + 0
        else if ($5 == "close") close_ts[$4] = $2 + 0
      }
      next
    }
    $2 == "SAMPLE" {
      ts = $1 + 0; foot = $3 + 0; gd = $4 + 0; gr = $5 + 0; gw = $6 + 0
      greg = $7 + 0; pk = $11 + 0
      sum = gd + gr
      nsamples++
      if (foot > overall_peak) overall_peak = foot
      if (pk > run_peak) run_peak = pk
      if (greg > max_greg) max_greg = greg
      if (gr > max_gr) max_gr = gr
      if (sum > max_sum) max_sum = sum
      last_ts = ts; last_foot = foot; last_gd = gd; last_sum = sum
      for (k in open_ts) {
        # Open window: hook open marker to 1.5 s past the close
        # marker, which covers the close animation.
        if (ts >= open_ts[k] - 0.5 && ts <= close_ts[k] + 1.5) {
          if (foot > cyc_peak[k]) cyc_peak[k] = foot
          if (gd > cyc_gfx[k]) cyc_gfx[k] = gd
          if (sum > cyc_sum[k]) cyc_sum[k] = sum
          if (gd > max_gfx) max_gfx = gd
        }
        # Idle-after-close window: 1.0-1.9 s past the close marker,
        # before the next open at close + 2 s.
        if (ts >= close_ts[k] + 1.0 && ts <= close_ts[k] + 1.9) {
          cyc_idle_foot[k] = foot; cyc_idle_gd[k] = gd; cyc_idle_sum[k] = sum
          cyc_idle_ts[k] = ts
        }
        # Invariant window: settled open span (open + 1.0 s to close
        # + 1.5 s). Tracks whether gfx_dirty + gfx_reclaim stays
        # constant while Dirty/Reclaimable flip.
        if (ts >= open_ts[k] + 1.0 && ts <= close_ts[k] + 1.5) {
          if (cyc_inv_n[k] == 0 || sum < cyc_inv_min[k]) cyc_inv_min[k] = sum
          if (cyc_inv_n[k] == 0 || sum > cyc_inv_max[k]) cyc_inv_max[k] = sum
          cyc_inv_n[k]++
        }
      }
      next
    }
    $2 == "NO_PROCESS" { noprocs++ }
    $2 == "FOOTPRINT_FAILED" { failed++ }
    END {
      ncycles = 0
      for (k in open_ts) { split(k, p, "/"); ncycles = p[2] + 0 }
      if (nsamples == 0 || ncycles == 0) inv_all = 0; else inv_all = 1
      for (i = 1; i <= ncycles; i++) {
        key = i "/" ncycles
        spread = cyc_inv_max[key] - cyc_inv_min[key]
        pct = (cyc_inv_max[key] > 0) ? spread / cyc_inv_max[key] * 100 : 0
        stable = (cyc_inv_n[key] > 0 && pct <= inv_tol_pct) ? "yes" : "no"
        if (stable == "no") inv_all = 0
        printf "cycle %s  open_ts %.3f  close_ts %.3f  peak_footprint_mb %s  peak_gfx_dirty_mb %s  peak_gfx_dirty+reclaim_mb %s\n", \
          key, open_ts[key], close_ts[key], fmt(cyc_peak[key]), \
          fmt(cyc_gfx[key]), fmt(cyc_sum[key])
        printf "cycle %s  gfx_dirty+reclaim invariant: n %d  min %s  max %s  spread %s  spread_pct %.1f  stable %s\n", \
          key, cyc_inv_n[key] + 0, fmt(cyc_inv_min[key]), fmt(cyc_inv_max[key]), \
          fmt(spread), pct, stable
        printf "cycle %s  idle_after_close: ts %.3f  footprint_mb %s  gfx_dirty_mb %s  gfx_dirty+reclaim_mb %s\n", \
          key, cyc_idle_ts[key] + 0, fmt(cyc_idle_foot[key]), \
          fmt(cyc_idle_gd[key]), fmt(cyc_idle_sum[key])
      }
      printf "max_graphics_mb_across_opens %s\n", fmt(max_gfx)
      printf "max_gfx_reclaim_mb %s  max_gfx_regions %d  max_gfx_dirty+reclaim_mb %s\n", \
        fmt(max_gr), max_greg + 0, fmt(max_sum)
      printf "invariant_gfx_dirty_plus_reclaim_stable %s (stable if spread <= %d%% of per-cycle max, window open+1.0s..close+1.5s)\n", \
        (inv_all ? "yes" : "no"), inv_tol_pct
      printf "overall_peak_footprint_mb %s\n", fmt(overall_peak)
      printf "run_phys_footprint_peak_mb %s\n", fmt(run_peak)
      printf "final_idle_footprint_mb %s  final_idle_gfx_dirty_mb %s  idle_sample_ts %.3f\n", \
        fmt(last_foot), fmt(last_gd), last_ts
      printf "samples %d  no_process_ticks %d  footprint_failed_ticks %d\n", \
        nsamples, noprocs + 0, failed + 0
    }
  ' "$APPLOG" "$SAMPLES"
  echo
  echo "# --- app log (hook events with epoch timestamps) ---"
  cat "$APPLOG"
  echo
  echo "# --- raw samples: <epoch> SAMPLE <footprint_mb> <gfx_dirty_mb> <gfx_reclaim_mb> <gfx_wired_mb> <gfx_regions> <iosurface_dirty_mb> <iosurface_reclaim_mb> <malloc_small_mb> <phys_footprint_peak_mb> ---"
  cat "$SAMPLES"
} >"$OUTPUT"

echo "wrote $OUTPUT"
