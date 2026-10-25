#!/bin/bash
# Captures the top-right menu bar strip (status items) for the TEMP label
# visual VAC, in dark and light appearance. Records and restores the
# user's original appearance. Aborts if a StatsLite instance is already
# running so a parallel session's process is never killed.
#
# Note: `screencapture -R` fails with "could not create image from rect"
# on this host, so each capture takes a full screenshot and crops the
# strip with Python/PIL instead.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/artifacts/2026-10-24-temp-labels-cg/visual-vac"
APP="$ROOT/.derivedData/Build/Products/Release/StatsLite.app"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if pgrep -x StatsLite >/dev/null; then
  echo "error: a StatsLite instance is already running; refusing to touch it" >&2
  exit 3
fi

ORIG=$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')
restore_appearance() {
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $ORIG" >/dev/null 2>&1 || true
}

cleanup() {
  trap - EXIT
  [ -n "${APP_PID:-}" ] && kill "$APP_PID" 2>/dev/null || true
  restore_appearance
}
trap cleanup EXIT

STRIP_W_POINTS=520
STRIP_H_POINTS=48

capture_mode() {
  local mode="$1"
  local dark="$2"
  local full="$OUT_DIR/full-$mode.png"
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark" >/dev/null
  sleep 1.5
  "$APP/Contents/MacOS/StatsLite" >/dev/null 2>&1 &
  APP_PID=$!
  sleep 5   # let the status item register and render
  mkdir -p "$OUT_DIR"
  screencapture -x "$full"
  python3 - "$full" "$OUT_DIR/menubar-$mode.png" "$STRIP_W_POINTS" "$STRIP_H_POINTS" <<'PYEOF'
import sys
from PIL import Image
src, dst, w_pts, h_pts = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
im = Image.open(src)
scale = im.width / 1920.0   # logical UI width on this host
box = (im.width - int(w_pts * scale), 0, im.width, int(h_pts * scale))
im.crop(box).save(dst)
print(f"cropped {dst} {box[2]-box[0]}x{box[3]-box[1]} px from {im.width}x{im.height}")
PYEOF
  echo "captured $OUT_DIR/menubar-$mode.png (dark=$dark)"
  kill "$APP_PID" 2>/dev/null || true
  wait "$APP_PID" 2>/dev/null || true
  APP_PID=""
  sleep 1
}

capture_mode dark true
capture_mode light false
restore_appearance
echo "appearance restored to dark mode $ORIG on exit"
