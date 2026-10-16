#!/bin/bash
#
# Measures StatsLite process footprint across automated popover cycles.
#
# Usage:
#   scripts/measure_popover_footprint.sh --output <file> \
#       [--binary <StatsLite.app>] [--cycles N] [--hold N] [--tail N]
#
# The script launches the release build with the --open-popover
# measurement hook, samples `footprint <pid>` every 0.4 s, and writes
# a summary plus the raw samples to <file>. The process is resolved by
# name (pgrep -x StatsLite) on every sample, so a stale pid can never
# be measured. The launched app is killed on exit.
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

cleanup() {
  trap - EXIT
  pkill -x StatsLite 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# Quit any running instance so the sampler can never attach to the
# user's menu bar app.
pkill -x StatsLite 2>/dev/null || true
for _ in $(seq 1 50); do
  if ! pgrep -x StatsLite >/dev/null; then break; fi
  sleep 0.1
done

"$APP/Contents/MacOS/StatsLite" \
  --open-popover --popover-cycles "$CYCLES" --popover-hold "$HOLD" \
  >"$APPLOG" 2>&1 &

sleep 0.5
if ! pgrep -x StatsLite >/dev/null; then
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
  pid=$(pgrep -x StatsLite | head -n 1) || true
  if [ -z "$pid" ]; then
    echo "$ts NO_PROCESS" >>"$SAMPLES"
  else
    footprint "$pid" 2>/dev/null | awk -v ts="$ts" '
      /Footprint:/ {
        for (i = 1; i <= NF; i++) if ($i == "Footprint:") foot = $(i+1) " " $(i+2)
      }
      /Owned physical footprint \(unmapped\) \(graphics\)/ { gfx = $1 " " $2 }
      /phys_footprint_peak:/       { pk = $(NF-1) " " $NF }
      END {
        if (foot == "") { printf "%s FOOTPRINT_FAILED\n", ts; exit }
        printf "%s SAMPLE %s %s %s\n", ts, foot, (gfx == "" ? "0 B" : gfx), (pk == "" ? "0 MB" : pk)
      }' >>"$SAMPLES" || true
  fi
  sleep 0.4
done

{
  echo "# StatsLite popover footprint measurement"
  echo "# date: $(date)"
  echo "# binary: $APP"
  echo "# cycles: $CYCLES  hold: ${HOLD}s  gap: 2s  tail: ${TAIL}s  interval: 0.4s"
  echo
  awk '
    function mb(v, u) {
      if (u == "MB") return v + 0
      if (u == "KB") return (v + 0) / 1024
      if (u == "GB") return (v + 0) * 1024
      if (u == "B")  return (v + 0) / 1048576
      return v + 0
    }
    function fmt(x) { return sprintf("%.1f", x) }
    FNR == NR {
      if ($1 == "[measurement]" && $3 == "cycle") {
        if ($5 == "open") open_ts[$4] = $2 + 0
        else if ($5 == "close") close_ts[$4] = $2 + 0
      }
      next
    }
    $2 == "SAMPLE" {
      ts = $1 + 0; foot = mb($3, $4); gfx = mb($5, $6); pk = mb($7, $8)
      nsamples++
      if (foot > overall_peak) overall_peak = foot
      if (pk > run_peak) run_peak = pk
      last_ts = ts; last_foot = foot; last_gfx = gfx; last_pk = pk
      for (k in open_ts) {
        # Open window: hook open marker to 1.5 s past the close
        # marker, which covers the close animation.
        if (ts >= open_ts[k] - 0.5 && ts <= close_ts[k] + 1.5) {
          if (foot > cyc_peak[k]) cyc_peak[k] = foot
          if (gfx > cyc_gfx[k]) cyc_gfx[k] = gfx
          if (gfx > max_gfx) max_gfx = gfx
        }
      }
      next
    }
    $2 == "NO_PROCESS" { noprocs++ }
    $2 == "FOOTPRINT_FAILED" { failed++ }
    END {
      ncycles = 0
      for (k in open_ts) { split(k, p, "/"); ncycles = p[2] + 0 }
      for (i = 1; i <= ncycles; i++) {
        key = i "/" ncycles
        printf "cycle %s  open_ts %.3f  close_ts %.3f  peak_footprint_mb %s  peak_graphics_mb %s\n", \
          key, open_ts[key], close_ts[key], fmt(cyc_peak[key]), fmt(cyc_gfx[key])
      }
      printf "max_graphics_mb_across_opens %s\n", fmt(max_gfx)
      printf "overall_peak_footprint_mb %s\n", fmt(overall_peak)
      printf "run_phys_footprint_peak_mb %s\n", fmt(run_peak)
      printf "final_idle_footprint_mb %s  final_idle_graphics_mb %s  idle_sample_ts %.3f\n", \
        fmt(last_foot), fmt(last_gfx), last_ts
      printf "samples %d  no_process_ticks %d  footprint_failed_ticks %d\n", \
        nsamples, noprocs + 0, failed + 0
    }
  ' "$APPLOG" "$SAMPLES"
  echo
  echo "# --- app log (hook events with epoch timestamps) ---"
  cat "$APPLOG"
  echo
  echo "# --- raw samples: <epoch> SAMPLE <footprint> <graphics-dirty> <phys-footprint-peak> ---"
  cat "$SAMPLES"
} >"$OUTPUT"

echo "wrote $OUTPUT"
