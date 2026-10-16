#!/bin/bash
#
# Captures baseline screenshots of the open StatsLite popover.
#
# Usage:
#   scripts/capture_baseline.sh [--binary <StatsLite.app>] \
#       [--out-dir <dir>] [--hold 20]
#
# For each appearance mode (dark, then light) the script switches the
# system appearance, launches the release build with the
# --open-popover hook and a long hold, waits for the popover window id
# via scripts/windowid.swift, and captures the window with
# `screencapture -x -o -l<id>`. The user's original appearance is
# restored when the script exits, even on failure. The launched app is
# killed on exit.
#
# Without --binary, the script builds the worktree release config into
# <worktree>/.derivedData when the app is missing or older than the
# newest Swift source file.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/artifacts/2026-10-16-popover-ram-trim/baseline"
BINARY=""
HOLD=20

while [ $# -gt 0 ]; do
  case "$1" in
    --binary) BINARY="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --hold) HOLD="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

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

ORIGINAL_APPEARANCE=$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')
case "$ORIGINAL_APPEARANCE" in
  true|false) ;;
  *) echo "error: unexpected appearance value: $ORIGINAL_APPEARANCE" >&2; exit 1 ;;
esac

cleanup() {
  trap - EXIT
  pkill -x StatsLite 2>/dev/null || true
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $ORIGINAL_APPEARANCE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

set_appearance() {
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $1" >/dev/null
  sleep 1
}

capture_mode() {
  local mode="$1" dark="$2"
  set_appearance "$dark"
  "$APP/Contents/MacOS/StatsLite" \
    --open-popover --popover-cycles 1 --popover-hold "$HOLD" >/dev/null 2>&1 &
  # Wait up to ~15 s for the popover window. The hook opens ~1 s
  # after launch and holds for <hold> s.
  local id="" attempt
  for attempt in $(seq 1 30); do
    id=$(swift "$ROOT/scripts/windowid.swift" 2>/dev/null) || id=""
    if [ -n "$id" ]; then break; fi
    sleep 0.5
  done
  if [ -z "$id" ]; then
    echo "error: no StatsLite popover window appeared for $mode" >&2
    return 1
  fi
  # Let the material render and settle before the capture.
  sleep 1.5
  screencapture -x -o -l"$id" "$OUT_DIR/$mode.png"
  echo "captured $OUT_DIR/$mode.png (window id $id, dark mode $dark)"
  pkill -x StatsLite 2>/dev/null || true
  sleep 1
}

mkdir -p "$OUT_DIR"
capture_mode dark true
capture_mode light false
echo "appearance restores to dark mode $ORIGINAL_APPEARANCE on exit"
