# Visual VAC verdict — TEMP menu-bar block (T5b)

Date: 2026-10-23 · Host: Apple M5 Max, macOS 27.0.1 · Build: main release (`xcodebuild`, TEST SUCCEEDED 390/0)
Evidence: `visual-vac/menubar-dark-final.png`, `visual-vac/menubar-light-final.png` (gray-composited window captures, window id 5), toggle experiment `/tmp/relaunch-off.png` → `/tmp/relaunch-on.png` (see transcript below).

## Verdict: PASS — all 12 VAC items met

| VAC | Result | Evidence |
|---|---|---|
| VAC-1 order | PASS | Both captures: CPU, MEM, GPU, **CPU nn°/GPU nn° two-row block**, NET, then system items — TEMP between GPU and Network. |
| VAC-2 two rows | PASS | Row 1 `CPU 47°`, row 2 `GPU 34°`, single line each, no wrap. |
| VAC-3 per-subsystem | PASS | CPU row tracks CPU sensor, GPU row tracks GPU sensor (46/34, 47/34, 73/39 across captures — values move independently). No combined number anywhere. |
| VAC-4 placeholder | PASS (code) | Live sensors were readable in every capture; `--°` per-row fallback pinned by FM-T4-5 unit tests (nil matrix), never `0°`. Block never hidden while enabled. |
| VAC-5 no animation | PASS | FM-T4-8 static source scan (comment-stripped) — no `.animation`/`.contentTransition` in temp view path. |
| VAC-6 style parity | PASS | 9 pt regular monospacedDigit rows match Network block composition exactly; labels 8 pt `.secondary` like other blocks. Side-by-side: identical glyph metrics. |
| VAC-7 monospacedDigit | PASS | Digit columns align across ticks (46→47, 34→34 captures show no x-shift in value runs). |
| VAC-8 toggle | PASS | Relaunch experiment with `defaults write showTemperature false`: item loses exactly the 54 pt slot (cluster shifts +108 px @2x) and the two temp rows; `true` restores them. Settings row presence pinned by FM-T4-7. |
| VAC-9 3-digit fit | PASS (code) | Live max seen 73°; `tempBlockWidth` = 50 pt ≥ measured worst case "GPU 130°" 44.19 pt (FM-T5-3, NSString harness). |
| VAC-10 a11y | PASS (code) | `setAccessibilityLabel(compositeLabel)` wired at StatusItemController.swift:308; Temperature segment pinned by FM-T4-6. |
| VAC-11 no card/tooltip | PASS | FM-T4-9 popover source scan; no tooltip set anywhere. |
| VAC-12 dark/light | PASS | Both appearance states captured after confirmed repaint (`get dark mode` read around each capture); block renders identically correct in both. |

## Notes / capture methodology

- Full-screen `screencapture` excludes the menu bar overlay on this host; window id 5 ("Menubar", Window Server) is the working path (same as designer evidence `menubar-id5.png`).
- Window captures are transparent-background RGBA: naive RGB flattening hides white glyphs and produced a false "blank block" reading mid-session. Alpha analysis (320 alpha px in the TEMP slot) and gray-composite rendering are the correct methods.
- `defaults write` does not propagate to the running app (AppStorage reads at launch for external writes); the toggle check used kill → write → relaunch.
- Appearance switches require ~3 s + a hover reveal before the menu bar repaints; each verified capture was taken after a confirming `get dark mode`.
- A StatsLite release instance remains running (launched for VAC). Quit it from the menu bar or `pkill -x StatsLite`.
