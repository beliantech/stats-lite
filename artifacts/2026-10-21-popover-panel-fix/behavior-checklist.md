# Pre-fix behavior baseline — NSPopover behaviors the NSPanel must reproduce

Scope: branch `fix/panel-popover-visual-baseline` at `24c4d6e` (content of `main`), wave 1 of
`.pi/plans/2026-10-21-popover-panel-fix.json`. The fix replaces the `NSPopover` container with an
app-owned panel (plan F2). Every row below defines current behavior that the panel must reproduce.

Status legend:

- `VERIFIED-IN-CODE` — confirmed by reading the cited source line on this branch.
- `NEEDS-LIVE-CHECK` — confirm on screen before merge (wave 3).

## Behavior checklist

| # | Behavior | Status | Evidence |
| --- | -------- | ------ | ---------- |
| 1 | Outside click closes the popover | `VERIFIED-IN-CODE` | `StatsLite/StatusItemController.swift:63` sets `popover.behavior = .transient`. `NSPopover` closes on any click outside its frame. Panel requirement: close on mousedown outside the panel bounds (plan wave 2 uses a local `NSEvent` monitor). |
| 2 | Esc closes the popover | `NEEDS-LIVE-CHECK` | No key handling exists in app code. `rg 'keyDown\|NSEvent\|performKeyEquivalent' StatsLite/*.swift` returns no hit, so Esc runs through the `NSPopover` built-in path only. Verify on screen, then reproduce with a local Esc monitor in wave 2. |
| 3 | Status-item click toggles the popover | `VERIFIED-IN-CODE` | `StatsLite/StatusItemController.swift:102-111` — `togglePopover` calls `popover.performClose(sender)` when `popover.isShown`, otherwise it calls `openPopover()`. A 0.25 s debounce drops clicks that arrive right after a close: the guard at `:103-104` reads `lastCloseTimestamp`, which `popoverDidClose` sets at `:173`. |
| 4 | Popover anchors below the status button | `VERIFIED-IN-CODE` (direction) | `StatsLite/StatusItemController.swift:128-132` — `popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)`. The popover attaches to the bottom edge of the status button, so its content sits below the menu bar. Exact pixel offset of the content rect from the button, including the arrow gap: `NEEDS-LIVE-CHECK` — read the open popover window bounds from `CGWindowList` (same pattern as plan F2 and attribution window 14141). The panel must place its content rect where the popover content rect sits today. |
| 5 | Opening the popover does not activate the app | `VERIFIED-IN-CODE` | The open path never calls `NSApplication.activate`. The only activate call in app code is the gear button inside the popover: `StatsLite/PopoverContentView.swift:94`. The app is an agent: `INFOPLIST_KEY_LSUIElement = YES` at `StatsLite.xcodeproj/project.pbxproj:339` and `:362`. Panel requirement: non-activating panel. Live probe with `NSWorkspace.frontmostApplication` before and after open: `NEEDS-LIVE-CHECK`. |
| 6 | Z-order: popover floats above other windows | `VERIFIED-IN-CODE` | The open popover window sits at CGWindow layer 101, the `popUpMenu` level — measured state recorded at `scripts/windowid.swift:6`. Panel requirement: `level = .popUpMenu`. Live check over other apps' windows: `NEEDS-LIVE-CHECK`. |
| 7 | Arrow and corner appearance | `VERIFIED-IN-CODE` (content) + `NEEDS-LIVE-CHECK` (pixels) | Content: fixed 280 pt width at `StatsLite/PopoverContentView.swift:74`, `.regularMaterial` background at `:76`. Arrow: no `hasArrow` call exists in `StatsLite/`, so `NSPopover` draws its default arrow. Corners: system-drawn rounded popover frame. Pixel appearance in dark and light mode needs the baseline PNGs — see "Baseline capture status" below. |
| 8 | Update banner renders above the metric cards | `VERIFIED-IN-CODE` | `StatsLite/PopoverContentView.swift:32-34` renders `UpdateBannerCardView` (`StatsLite/UpdateBannerCardView.swift:12`) when `updateChecker.availableUpdate` is set and the version is not dismissed. Dismiss persists per version at `:39`. The banner enters with `.transition(.opacity)`. Live render needs an available update: `NEEDS-LIVE-CHECK`. |
| 9 | Per-core disclosure interaction | `VERIFIED-IN-CODE` | `@State coresExpanded` at `StatsLite/PopoverContentView.swift:21` binds into `CPUCardView` at `:48`. The disclosure button toggles the state at `StatsLite/CPUCardView.swift:67-69`, the chevron flips between `chevron.right` and `chevron.down` at `:73`, and per-core rows render at `:54` while expanded. A 0.2 s ease-in-out animation runs at `PopoverContentView.swift:79`. State resets on every close: `popoverDidClose` sets `popover.contentViewController = nil` at `StatusItemController.swift:178`, which discards the view and its `@State`. The panel must reset disclosure state the same way, or record a deviation. |
| 10 | Network card samples on a fixed 1 s cadence | `VERIFIED-IN-CODE` | A second task ticks network every second at a cadence that `refreshInterval` never touches: `StatsLite/SystemMonitor.swift:8` (header), `:47-48` (capacity comment), `:163` (cadence comment). The card shows its loading state while `!monitor.isNetworkSampling` at `StatsLite/NetworkCardView.swift:46`. The popover footer caption `Updated every {refreshInterval}s` at `PopoverContentView.swift:126` describes the main pass only, not the network pass. |

## Extra parity behaviors (found while reading the same paths)

| Behavior | Status | Evidence |
| -------- | ------ | ---------- |
| Status button highlights while the popover is open, then clears | `VERIFIED-IN-CODE` | `button.isHighlighted = true` at `StatsLite/StatusItemController.swift:115`, cleared at `:174`. |
| Close releases the content controller | `VERIFIED-IN-CODE` | `popoverDidClose` sets `popover.contentViewController = nil` at `StatsLite/StatusItemController.swift:178`, so no popover view evaluates while closed. |
| Measurement hook events stay stable | `VERIFIED-IN-CODE` | `startMeasurementCycle` at `StatsLite/StatusItemController.swift:143` prints epoch-stamped `[measurement]` open/close lines to stderr. `scripts/measure_popover_footprint.sh` matches these events. The panel swap must emit the same events. |
| Transient-reopen race is guarded by the 0.25 s debounce | `VERIFIED-IN-CODE` | Rationale comment at `StatsLite/StatusItemController.swift:13-16`, guard at `:103-104`, timestamp set at `:173`. |

## Baseline capture status

Target directory: `artifacts/2026-10-21-popover-panel-fix/baseline/` (empty, no PNGs).

Command run once from the worktree root:

```text
scripts/capture_baseline.sh --out-dir artifacts/2026-10-21-popover-panel-fix/baseline
```

The release build succeeded (`** BUILD SUCCEEDED **`). The script then stopped at
`scripts/capture_baseline.sh:65` with exit code 1. Verbatim output:

```text
71:80: execution error: Not authorized to send Apple events to System Events. (-1743)
```

Failing command inside the script:

```text
osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode'
```

A second probe shows that window capture is blocked too:

```text
screencapture -x -o -l14015 /tmp/probe.png
could not create image from window   (exit 1, same for window 14162)
```

Full-display `screencapture -x` exits 0 but writes a black PNG with no window content.

Runbook for the user:

1. Open System Settings > Privacy & Security > Automation. Find the app that runs the script,
   for example Terminal or `herdr`. Turn on the switch for System Events.
2. Open System Settings > Privacy & Security > Screen Recording. Turn on the switch for the same
   app. Restart that app after the change.
3. Run `scripts/capture_baseline.sh --out-dir artifacts/2026-10-21-popover-panel-fix/baseline`
   from the worktree root. The script restores your appearance setting on exit and writes
   `dark.png` and `light.png` into the target directory.
4. Commit the two PNGs to this branch, or tell the planner to re-run wave 1 capture.
