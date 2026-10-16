# Plan: Stacked Fixed-Width Menu Bar Label

**Plan name:** `2026-10-15-menubar-stacked-fixed-width`
**Status: COMPLETE — merged to main (fast-forward, f27eff3), Release build running (PID 13628).**
Gates: designer blueprint + addendum (2 oracle rounds, SAFE TO PLAN) → coder red b3cc9ac / green 656b2f5 → views 91789fe / controller f27eff3 → TEST GATE PASS (114 tests, 0 failures) → oracle final SAFE TO SHIP → vision gate PASS (real SwiftUI renders: 24pt, 38pt notched, single-metric; widths 114/38 exact).

## 1. Objective

Replace the single-line menu bar text (`CPU 14% · RAM ● 62% · GPU 28%`) with one stacked block per metric — category label on line 1, value on line 2 (user's screenshot format) — with widths pinned per block so the item width NEVER changes for the lifetime of the display. Widths reserve the widest possible content (`"100%"` at the value font), so every state from `0%` to `100%` and `--%` fits with no resize.

## 2. Non-Goals

- No changes to `PopoverContentView`, `SettingsView` layout beyond the removed labels toggle, `SystemMonitor`, or metric sampling. `PreferencesStore` only loses `showLabels`.
- Appendix B popover-height invariants VAC-B4…B6 stay binding (`.pi/plans/2026-10-15-stats-lite-3metric/appendix-b-fix-blueprint.md`).
- No changes to `MenuBarAccessibility.compositeLabel` logic or pressure-state tests.

## 3. Architecture (oracle-approved)

`MenuBarExtra` cannot render this format: it flattens the label closure into `NSStatusBarButton.title`, keeps only the first `Text`, and a `\n` attributed string is clipped in the 24 pt bar. Selected path:

- **AppKit**: `AppDelegate` (via `NSApplicationDelegateAdaptor`) owns a `StatusItemController` that manages one `NSStatusItem`, a `PassthroughHostingView` (`NSHostingView`, `hitTest → nil`) pinned inside the status button, and a `.transient` `NSPopover` hosting the unchanged `PopoverContentView`.
- **SwiftUI**: `MenuBarStackedItemView` = `HStack(spacing: 4)` of per-metric block views with pinned `.frame(width:)`, `.padding(.horizontal, 2)`. No hardcoded height; hosting view centers via `centerYAnchor` (notched displays have 32–38 pt bars).

### Layout constants (binding, oracle-verified to fit `"100%"`)

**User amendments after plan draft (binding):** no RAM pressure dot (value only, no decorative dots anywhere), percent values formatted `20%`, spacing tightened for a compact item, and **no `showLabels` option** — the category label is always visible; the "Show Category Labels" toggle is removed from Settings, `PreferencesStore.showLabels` is deleted, and the persisted-key guard tests are updated accordingly.

| Element | Constant |
|---|---|
| CPU block width | **34 pt** (value `100%` ≈ 27.4 pt → 6.6 pt clearance; 32 pt was verified to touch the boundary, so 34 is the floor) |
| RAM block width | **34 pt** (dot removed per user amendment — same widest content as CPU) |
| GPU block width | **34 pt** |
| Inter-block gap | **4 pt** (tightened from 6) |
| Outer padding | **2 pt** leading + 2 pt trailing (tightened from 4) |
| Total (3 metrics) | **114 pt**; any 2 metrics 76 pt; single metric 38 pt |
| Line 1 label | 8 pt SF Pro bold, `.secondary` — **always rendered** (no toggle) |
| Line 2 value | 10.5 pt medium `.monospacedDigit()`, `lineLimit(1)` |
| Value text | `MetricFormatters.percent` → `20%` style; nil → `--%` |
| Value tint | ≥95 % red, ≥80 % orange, else primary; nil → `--%` tertiary |
| RAM dot | **Removed** (user amendment). Pressure state still flows to the VoiceOver composite label |

### Oracle mandatory fixes (all baked into shipped code)

1. **Popover race** (BLOCKER): `.transient` popover closes on the button's own click before the action fires → debounce: `lastCloseTimestamp` 0.25 s via `ProcessInfo.processInfo.systemUptime`, checked before `isShown` in `togglePopover`.
2. **Highlight**: `button.isHighlighted = true` on show; cleared in `popoverDidClose(_:)`.
3. **Accessibility**: `hitTest = nil` hides SwiftUI a11y from VoiceOver → `button.setAccessibilityElement(true)`, `setAccessibilityTitle("Stats Lite")`, `setAccessibilityLabel(compositeLabel)` on the `NSStatusBarButton`.
4. **Height/constraints**: no `.frame(height: 24)`; `centerYAnchor` pin; trailing constraint priority **999** against `statusItem.length`.
5. **Idle animation**: `.contentTransition(.numericText())` + `.animation(...)` bound to `block.valueText`, never `snapshot.timestamp`.
6. **Observation wiring** (oracle warning): `updateItemLength()`/`updateAccessibility()` triggered from `MenuBarStackedItemView` `.onChange(of: preferences.enabledMetrics/refreshInterval/historyDuration)` and `.onChange(of: monitor.latestSnapshot)` via controller-set closures; `monitor.apply(preferences)` preserved.

## 4. Tasks

- [x] **T1** — block model + layout math + showLabels removal. red `b3cc9ac` · green `656b2f5` · review oracle SAFE TO SHIP
- [x] **T2** — tests (block builder, layout permutations, toggle-absence). red `b3cc9ac` · green `656b2f5` · TEST GATE PASS
- [x] **T3** — stacked SwiftUI views; old single-Text path retired. `91789fe` · vision gate PASS
- [x] **T4** — StatusItemController + PassthroughHostingView (debounce, highlight, a11y, constraints). `f27eff3` · oracle SAFE TO SHIP
- [x] **T5** — AppDelegate migration; MenuBarExtra removed. `f27eff3`
- [x] **T6** — observation wiring for length + accessibility updates. `f27eff3`
- [x] **T7** — build & unit tests: 114 tests, 0 failures.
- [x] **T8** — visual verification: real SwiftUI offscreen renders (24 pt, 38 pt notched, single-metric) confirmed stacked layout, exact widths, no dot, always-on labels. Live menu-bar screenshot blocked by missing screen-recording permission.
- [x] **T9** — oracle final review: SAFE TO SHIP (all OK; 4 deviations accepted).
- [x] **T10** — merged to main via fast-forward; Release build launched (PID 13628).

## 5. Test plan (executed)

- Unit: block builder (combinations, formatting, tints), layout length (7 permutations + all-off=4), accessibility composite label + pressure state (unchanged).
- Build: `xcodebuild test -scheme StatsLite -destination 'platform=macOS'` — 114/0.
- Visual: offscreen renders of the real `MenuBarStackedItemView` at pinned widths.

## 6. Rollback

Single merge is a fast-forward of 4 commits → `git revert f27eff3` restores prior behavior (revert covers the whole stacked feature series via its parent diff).

## 7. Commit series (on main)

1. `b3cc9ac` test(menubar): red tests for stacked block model and layout math
2. `656b2f5` feat(menubar): add block model and layout math, remove showLabels option
3. `91789fe` feat(menubar): stacked block views replace single-Text label
4. `f27eff3` feat(menubar): custom NSStatusItem with debounced popover

## 8. Risks / open items

- Live menu-bar interaction (click toggle, highlight, VoiceOver) verified by oracle code review only — user should glance at behavior on the running build.
- Known watcher item (harmless, per reviewer): `PopoverContentView` uses `@Environment(\.openSettings)` under `NSHostingController` — verify the Settings button in the popover opens the settings window.
