# Add Network Usage Chart (mirrored dual-series card)

## Task ledger

- [x] Task 1 — implement mirrored network usage card (data + views + registration + tests)
  - Plan approved: 2026-10-16
  - Branch: `feat/2026-10-16-add-network-usage-chart` (commits `a52bf82`, `ed005f9`, `3429828`, `e31ece1`)
  - Review: GO (evidence-backed, 2026-10-16)
  - Merged: squash → `main` at `1cb9e7e`
  - Receipts: `artifacts/2026-10-16-add-network-usage-chart/` (VAC ledger, baseline/after
    screenshots, footprint before/after). Full suite 218/218 green; footprint neutral.

## Goal

Add a Network Usage card to the popover: a **mirrored** dual-series chart — upload filled
area above a central baseline (`systemRed`), download below it (`systemBlue`) — with a
standard card header (`Network Usage` + combined rate) and a legend row (`● Up` / `● Down` /
`Peak:`). Per the client's reference image, but with rates in the legend row instead of
overlaid on the chart (designer decision, option c).

## Design spec (from designer, approved decisions)

- Card container: existing `MetricCardStyle` — 260 pt wide, 10 pt padding, 8 pt continuous
  radius (`DesignTokens.swift:42-57`). Inner content width 240 pt.
- `VStack(alignment: .leading, spacing: 4)`:
  1. **Header row** (~16 pt): SF Symbol `"network"` + `"Network Usage"` (11 pt semibold,
     secondary) left; combined rate `MetricFormatters.networkRate(totalRate)` (12 pt bold
     rounded monospacedDigit, primary) right.
  2. **Legend row** (~14 pt): 6 pt `systemRed` dot + `Up: <rate>` (10 pt medium
     monospacedDigit, secondary); 6 pt `systemBlue` dot + `Down: <rate>`; spacer;
     `Peak: <rate>` (9.5 pt, tertiary). Must not wrap or clip at 280 pt popover width.
  3. **Mirrored chart** (56 pt tall, 240 pt wide, full width — no side labels):
     - Central baseline at Y = 28 pt: 0.5 pt stroke, `separatorColor` @ 0.35 opacity.
     - Upload above baseline (Y 0...28): fill gradient `systemRed` 0.22 (top) → 0.04
       (baseline); stroke `systemRed` 1.5 pt round cap/join.
     - Download below baseline (Y 28...56): fill gradient `systemBlue` 0.04 (baseline) →
       0.22 (bottom); stroke `systemBlue` 1.5 pt round cap/join.
     - Shared `domainMax = max(peakRate, 10 * 1024)` (10 KB/s floor); `peakRate` =
       max of upload/download history peaks.
     - Zero rate renders a flat 1.5 pt line on the baseline, no negative deflection.
  4. **Time axis row** (~12 pt): `-\(Int(monitor.historyDuration))s` left, `Now` right,
     9 pt tertiary.
- States: `latestNetwork == nil` + sampling → header `-- KB/s` (tertiary),
  "Waiting for first sample", 38 pt placeholder rect. Sampling off / unavailable → dashed
  38 pt container with `exclamationmark.triangle` + footnote (mirror `GPUCardView.swift:54-72`).
- Accessibility: canvas `.accessibilityHidden(true)`; card
  `.accessibilityElement(children: .ignore)` with composite label
  `"Network usage: Upload X, Download Y, Combined Z, Peak P"` / `"Network usage unavailable"`.
- Colors reuse the menu-bar convention: upload `systemRed`, download `systemBlue`
  (`MenuBarStackedItemView.swift:150,162`).
- **No `.animation` / `.contentTransition` anywhere in this card** (global AGENTS.md rule).

## VAC (visual acceptance — zero-tolerance on wrap/clip; check dark AND light mode)

- VAC-1: Card renders below `GPUCardView` when `preferences.showNetwork == true`; absent otherwise.
- VAC-2: `MetricCardStyle` container: 8 pt radius, 10 pt padding, 0.65 fill, 0.5 pt border.
- VAC-3: Header: network symbol + title left, combined rate right, single line.
- VAC-4: Legend row: red `Up`, blue `Down`, `Peak:` on one line, no wrap/clip at 280 pt.
- VAC-5: Chart canvas exactly 56 pt tall, 240 pt wide (full inner width, no side labels).
- VAC-6: Baseline at Y = 28 pt, 0.5 pt, `separatorColor` @ 0.35.
- VAC-7: Upload strictly above baseline in `systemRed`; download strictly below in `systemBlue`.
- VAC-8: Zero rate = flat line on baseline, no deflection.
- VAC-9: Strokes 1.5 pt round; fill gradients 0.22 → 0.04.
- VAC-10: Axis row `-<historyDuration>s` / `Now`, 9 pt tertiary, no overlap.
- VAC-11: Loading state: `-- KB/s` + "Waiting for first sample" + placeholder rect.
- VAC-12: Unavailable state: dashed container, warning icon, footnote.
- VAC-13: VoiceOver announces the composite label; canvas hidden from accessibility.
- VAC-14: Popover does not clip the taller card; other cards' 240 pt alignment preserved.

## Steps

### 0. Baseline capture (repo requirement — before any code edit)

Run `scripts/capture_baseline.sh --out-dir <artifacts>/baseline` (dark + light VAC
screenshots of the current popover). These are the "before" reference for VAC-14.

### 1. Data layer — history buffers + per-second append

Files: `StatsLite/SystemMonitor.swift`

- Add two buffers next to `SystemMonitor.swift:49-51`:
  `private(set) var networkUploadHistory = HistoryBuffer()` and
  `private(set) var networkDownloadHistory = HistoryBuffer()`.
- Append inside `startNetworkSampling()` right after the `latestNetwork` assignment
  (`SystemMonitor.swift:179`), one point per 1 s network tick, only when both rates are
  non-nil (nil passes are normal — `MetricSamplerActor.swift:74-120` — and simply skip the
  tick; the buffer keeps the last real sample, no gaps drawn).
- Trim with `maxAge: historyDuration`, `capacity: max(Int(historyDuration), 16)`
  (per-second density, so capacity == seconds; follows the `recordHistory` trim pattern
  at `SystemMonitor.swift:207`).
- Expose the per-second view capacity for the card, e.g.
  `var networkSparklineCapacity: Int { max(Int(historyDuration), 16) }`.
- `stopNetworkSampling()` (`SystemMonitor.swift:187`): clear both buffers alongside the
  existing rate/base clearing, matching the off-state contract in
  `SystemMonitorNetworkTests`.
- Note: `historyDuration` already drives the axis label and the trim; no new preference.

### 2. New mirrored chart view

File (new): `StatsLite/NetworkSparklineView.swift`

- `struct NetworkSparklineView: View, Equatable` — inputs: `downloadValues`, `uploadValues`
  (bytes/s, oldest first), `domainMax`, `capacity`.
- Geometry in a `static func mirroredPlotPoints(values:capacity:size:domainMax:halfHeight:)`
  so tests verify math without rendering (same pattern as
  `SparklineView.plotPoints`, `SparklineView.swift:93`). Upload maps into the upper half
  (Y = halfHeight → 0), download into the lower half (Y = halfHeight → halfHeight*2).
- Draw in `Canvas`: baseline rule, then each series as area fill (gradient) + 1.5 pt
  round stroke, per the spec above. Clamp values to `domainMax`; zero ⇒ baseline.
- `.frame(height: 56)`, `.accessibilityHidden(true)`.
- Keep the `Equatable` contract tight (values, domainMax, capacity) so `.equatable()`
  skips redundant redraws like the existing cards.

### 3. New card view

File (new): `StatsLite/NetworkCardView.swift`

- Mirror `GPUCardView.swift` structure: `let monitor: SystemMonitor`, computed
  `uploadRate`/`downloadRate` from `monitor.latestNetwork`, `totalRate`, `peakRate`
  (10 KB/s floor), body per the Design spec (header / legend / chart / axis rows +
  loading & unavailable states).
- Chart:
  `NetworkSparklineView(downloadValues:monitor.networkDownloadHistory.values,
  uploadValues:monitor.networkUploadHistory.values, domainMax:…,
  capacity:monitor.networkSparklineCapacity).equatable()`
- Accessibility composite label per spec.

### 4. Registration

File: `StatsLite/PopoverContentView.swift`

- Add `if preferences.showNetwork { NetworkCardView(monitor: monitor)
  .transition(.opacity) }` after the GPU block (`PopoverContentView.swift:45`).
- Check the container animation keyed on `activeMetricCount`
  (`PopoverContentView.swift:60`): `PreferencesStore.isToggleLocked`/`activeMetricCount`
  count only the three standard metrics (`PreferencesStore.swift:91-101`) — do **not**
  change that semantics; network must stay outside the last-one-enabled guard
  (`PreferencesStore.swift:51-53`). If the show/hide animation looks unkeyed for network,
  key the animation additionally on `preferences.showNetwork` — no behavior change to the
  other three.
- Settings toggle `showNetwork` already exists (`SettingsView.swift:86`); no Settings
  change needed. Menu-bar block already exists; untouched.

### 5. Tests

- `StatsLiteTests/SparklineViewTests.swift` pattern → new `NetworkSparklineViewTests`:
  mirrored geometry (upload never below baseline, download never above), zero-value →
  baseline, clamping to domainMax, `Equatable`.
- `SystemMonitorNetworkTests` pattern → buffers append once per network tick, skip nil
  passes, clear on `stopNetworkSampling()`, respect capacity/age trim.

### 6. Build, verify, measure

- Build + run the test suite (`xcodebuild test`, scheme per repo convention).
- Visual verification: run `scripts/capture_baseline.sh --out-dir <artifacts>/after`
  (dark + light), then inspect with `read` and verify every VAC item. Fix any wrap,
  clip, or misalignment before finishing — blocking per global policy.
- Popover height grows by one card (56 pt chart + ~46 pt rows ≈ +110 pt). Run
  `scripts/measure_popover_footprint.sh` (repo requirement for popover-impacting
  changes) and record before/after numbers in the completion report.

## Notes / gotchas (from scout recon)

- No view registry exists — the card list is hand-written (`PopoverContentView.swift:31-47`);
  we add exactly one block.
- Popover content is destroyed on close (`StatusItemController.swift:166-172`) — all
  history must live on `SystemMonitor`, never in `@State`.
- `showNetwork` must stay out of `EnabledMetrics` (`MetricTypes.swift:186-189`).
- Network cadence (1 s) differs from `refreshInterval` — intended, per client's dense
  reference image; the axis label still reflects `historyDuration`.
- Commit: conventional message, e.g. `feat(network): add mirrored network usage card to popover`.
