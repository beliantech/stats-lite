# Task 05 — Menu Bar Label + Popover UI

## Objective
Build the full visual layer: menu bar label, popover with CPU/RAM metric cards (sparklines, segmented bar, per-core grid), header and footer — pixel-faithful to the Design Blueprint.

## Context — READ FIRST
**Your first action**: read the Design Blueprint in the main repo at `/Users/jonathan/beliantech/stats-lite/docs/plans/2026-10-13-stats-lite-menu-bar/notes.md` — sections 1 (wireframes), 2 (component skeletons), 3 (state/appearance matrix), 4 (accessibility contracts), 5 (VAC). Follow the blueprint's exact sizes, fonts, colors, and spacing. Where the blueprint and your judgment conflict, the blueprint wins. Also read the ISC (`/Users/jonathan/beliantech/stats-lite/docs/plans/2026-10-13-stats-lite-menu-bar/ISC.md`).

Dependencies already exist from tasks 02–04: `SystemMonitor` (@Observable, snapshot + histories + severities), `PreferencesStore`, `MetricFormatters` (menuBarString), `DisplayFormat`/`RAMUnit` enums.

## Deliverables (all under `StatsLite/Views/` + app entry)
1. `MenuBarLabelView`: per blueprint section 2. Monospaced digits, `.contentTransition(.numericText())`, `.lineLimit(1)`, `.fixedSize()`. Driven by `PreferencesStore` (format/unit/labels). Severity tint (orange ≥80, red ≥95) per state matrix. Accessible label per blueprint section 4.
2. `PopoverContentView`: 280 pt wide, `.regularMaterial`, header (gauge icon, title, gear button → activate + `openSettings()`, power button → terminate, ≥24×24 pt hit targets with hover pill), divider, CPU card, RAM card, divider, footer ("Updated every Ns" + "macOS Native"). `.onAppear/.onDisappear` set `isPopoverVisible`.
3. `MetricCardView`: reusable card per blueprint (title/icon/color/valueText, 8 pt continuous radius, 0.5 pt border, controlBackgroundColor 0.65 fill).
4. `CPUCard`: total %, "User: X% · System: Y%" subtitle (store user/system split in snapshot from task 02's CPUMetrics if needed — extend `CPUMetrics` with userPercent/systemPercent in this task if absent), 38 pt sparkline (blue, amber when sustained >80%), disclosure row "Cores Breakdown (N Cores)" with chevron; expanded grid of per-core bars (2-column grid, bar + %), 200 ms animation, fits 280 pt.
5. `RAMCard`: "RAM Used  6.2 / 16.0 GB" (unit-aware), 8 pt segmented bar (App blue / Wired purple / Compressed orange / Free quaternary, 4 pt clip), 38 pt sparkline, breakdown line App/Wired/Compressed values.
6. `SparklineChartView` + `SegmentedBarView` + `CoreUsageBarView` per blueprint skeletons (SwiftUI Charts, hidden axes, y domain 0...1 or 0...100 as appropriate).
7. Wire `StatsLiteApp`: `MenuBarExtra` label = `MenuBarLabelView`, `.menuBarExtraStyle(.window)`; `monitor.start(intervalSeconds: prefs.refreshInterval)` on launch; restart on interval change. `Settings` scene left as placeholder (task 06).
8. History duration and sparkline windowing respect `PreferencesStore.historyDuration`.

## Visual verification (required)
Build and run the app on this Mac (`open .derivedData/Build/Products/Debug/StatsLite.app` after an `xcodebuild build`). Capture screenshots of the open popover (use `screencapture -l <windowid>` or ScreenCaptureKit; a menu-bar-only popover can be captured with `screencapture -x` after focusing). Verify every VAC row VAC-1..VAC-11, VAC-13 against the blueprint. Report each VAC as Met/Not-met with evidence. Fix any visual defects (wrapping, jitter, overflow) before committing — visual defects are blocking.

## Verify
- `xcodebuild build` clean (no new warnings).
- `xcodebuild test` still green.
- VAC-1..11, 13 checked off in your report.

## Commit(s) (max 2)
`feat(ui): add menu bar label, popover metric cards, and sparkline views`
