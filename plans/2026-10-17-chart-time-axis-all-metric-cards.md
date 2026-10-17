# Plan: 2026-10-17-chart-time-axis-all-metric-cards

Plan name: `2026-10-17-chart-time-axis-all-metric-cards`
Date: 2026-10-17
Risk class: **R2** (UI work, zero-tolerance visual policy applies)
Approval: user approved in chat ("ok", 2026-10-17) after the Design Blueprint was presented.
Status: **Active** — reviewer plan-review verdict `### VERDICT: GO` (2026-10-17, re-review
after fixing three findings: baseline task gap, `isFinite` guard, macOS test destination).
Worktree: `worktrees/2026-10-17-chart-time-axis-all-metric-cards` (branch `feat/2026-10-17-chart-time-axis-all-metric-cards`)

## Intent

Today only the Network card shows a time axis (`NetworkCardView.swift:94-102`); the CPU,
Memory Pressure, and GPU sparklines render with no time context at all. If Network
sampling is disabled, the popover shows no time markers anywhere.

We add one shared `SparklineTimeAxisView` under every sparkline and replace the Network
card's ad-hoc axis row with it. Hover labels were evaluated by the designer and rejected:
the popover is `.transient` (`StatusItemController.swift:57`), samples are 0.8–4 pt wide
in a 240 pt plot, current values already live in card headers, and hover-only data fails
WCAG 2.2.

Duration labels use human units (`-30s`, `-1m`, `-2m`, `-3m`, `-5m`), never raw
`-120s` / `-300s`.

## Design Blueprint (verbatim, from designer 2026-10-17)

### Part 1: Visual Hierarchy & ASCII Wireframe

Visual evidence references:
- Popover dark appearance: `artifacts/2026-10-16-add-network-usage-chart/after/dark.png`
- Popover light appearance: `artifacts/2026-10-16-add-network-usage-chart/after/light.png`
- Network card baseline axis: `artifacts/2026-10-16-add-network-usage-chart/after/crops/dark_networkcard.png`

```text
+-------------------------------------------------------------+
| StatsLite (Icon + Title)                      [Gear] [Power]| Header (28 pt)
+-------------------------------------------------------------+
| ----------------------------------------------------------- | Divider
|                                                             |
| +-[ CPU Card: MetricCardStyle ]---------------------------+ |
| | [CPU] CPU Total                                   12.4% | | Header row (16 pt)
| | Across 18 cores                                         | | Subtitle (10 pt tertiary)
| | [~~~~~~~~~~~~ Sparkline Canvas (38 pt) ~~~~~~~~~~~~~~~] | | SparklineView (38 pt)
| | -1m                                                 Now | | SparklineTimeAxisView (12 pt)
| | > Cores Breakdown (18 Cores)                            | | Disclosure button (14 pt)
| +---------------------------------------------------------+ |
|                                                             |
| +-[ Memory Pressure Card: MetricCardStyle ]---------------+ |
| | [RAM] Memory Pressure                          [Normal] | | Header row + Badge (16 pt)
| | [================ Pressure Gauge Bar =================] | | Gauge (8 pt)
| | [~~~~~~~~~~~~ Sparkline Canvas (38 pt) ~~~~~~~~~~~~~~~] | | SparklineView (38 pt)
| | -1m                                                 Now | | SparklineTimeAxisView (12 pt)
| | Used: 54% (19.4 / 36.0 GB)                              | | Used line (11 pt mono)
| | [App | Wired | Comp | Free ] Composition Bar (6 pt)     | | Composition (6 pt)
| | App: 15.7G · Wired: 3.2G · Comp: 0.6G                   | | Breakdown (10 pt tertiary)
| +---------------------------------------------------------+ |
|                                                             |
| +-[ GPU Card: MetricCardStyle ]---------------------------+ |
| | [GPU] GPU Usage                                    4.2% | | Header row (16 pt)
| | Integrated Graphics                                     | | Subtitle (10 pt tertiary)
| | [~~~~~~~~~~~~ Sparkline Canvas (38 pt) ~~~~~~~~~~~~~~~] | | SparklineView (38 pt)
| | -1m                                                 Now | | SparklineTimeAxisView (12 pt)
| +---------------------------------------------------------+ |
|                                                             |
| +-[ Network Usage Card: MetricCardStyle ]-----------------+ |
| | [Net] Network Usage                              8 KB/s | | Header row (16 pt)
| | ● Up: 1 KB/s   ● Down: 7 KB/s              Peak: 7 KB/s | | Legend row (14 pt)
| | [~~~~~~~~ Mirrored Canvas: Up / Down (56 pt) ~~~~~~~~~] | | NetworkSparklineView (56 pt)
| | -1m                                                 Now | | SparklineTimeAxisView (12 pt)
| +---------------------------------------------------------+ |
|                                                             |
| ----------------------------------------------------------- | Divider
| Updated every 5s                             macOS Native   | Footer (22 pt)
+-------------------------------------------------------------+
```

### Vertical Budget Analysis

1. Window width stays fixed at 280 pt (`PopoverContentView.swift:56`).
2. Card horizontal padding stays 10 pt on popover, 10 pt inside card (`DesignTokens.swift:43`). Plot inner width stays exactly 240 pt.
3. Adding the 12 pt time axis row with 4 pt top spacing adds 16 pt to CPU, Memory, and GPU cards.
4. Total popover height expands by 48 pt (from 586 pt to 634 pt with all four cards active).
5. 634 pt fits within standard macOS displays (800 pt to 900 pt usable vertical space) with over 200 pt of margin.

### Part 2: Template / Component Skeleton

All tokens ground in existing repository constants (`DesignTokens.swift:42-57`, `MetricFormatters.swift:10-53`, and `NetworkCardView.swift:94-102`).

#### 1. Duration Formatter Extension (`MetricFormatters.swift`)

```swift
extension MetricFormatters {
    /// Formats history window duration into a compact sparkline axis anchor.
    /// Seconds under 60 render with 's' (for example: "-30s").
    /// Durations of 60 seconds or more render with 'm' (for example: "-1m", "-2m", "-5m").
    static func historyDurationAxis(_ seconds: TimeInterval) -> String {
        // Deviation from Blueprint (reviewer finding 2026-10-17): guard non-finite
        // input. Int(NaN) / Int(infinity) traps at runtime. No visual change for
        // the five valid durations.
        let totalSeconds = seconds.isFinite ? max(Int(seconds), 0) : 0
        if totalSeconds < 60 {
            return "-\(totalSeconds)s"
        }
        let minutes = totalSeconds / 60
        return "-\(minutes)m"
    }
}
```

#### 2. Canonical Reusable Axis Component (`SparklineTimeAxisView.swift`)

```swift
import SwiftUI

/// Shared time axis row for all sparklines and metric graphs.
/// Renders the start duration on the leading edge and "Now" on the trailing edge.
struct SparklineTimeAxisView: View, Equatable {
    let duration: TimeInterval

    var body: some View {
        HStack {
            Text(MetricFormatters.historyDurationAxis(duration))
            Spacer()
            Text("Now")
        }
        .font(.system(size: 9, weight: .regular).monospacedDigit())
        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
        .accessibilityHidden(true)
    }
}
```

#### 3. Integration in Card Views

- **`CPUCardView.swift`**: insert `SparklineTimeAxisView(duration: monitor.historyDuration).equatable()` immediately below `SparklineView` (lines 36-41), above `disclosure`.
- **`MemoryPressureCardView.swift`**: insert below `SparklineView` (lines 39-44), above the `usedLine` text.
- **`GPUCardView.swift`**: insert below `SparklineView` (lines 32-37) inside the `gpu != nil` branch only; the `else` branch gets no axis.
- **`NetworkCardView.swift`**: replace the ad-hoc `axisRow` (lines 66, 94-102) with `SparklineTimeAxisView`; no axis in loading placeholder or sampling-off states.

### Part 3: State & Duration Matrix

| Metric Card | State Condition | Chart Presence | Time Axis Visibility |
| --- | --- | --- | --- |
| CPU Total | Active sampling | Visible (38 pt) | Visible |
| CPU Total | Waiting for first sample | Visible (38 pt) | Visible |
| Memory Pressure | Normal / Warning / Critical | Visible (38 pt) | Visible |
| GPU Usage | Available (`gpu != nil`) | Visible (38 pt) | Visible |
| GPU Usage | Unavailable (`gpu == nil`) | Hidden | **Hidden** (dashed container, no axis) |
| Network Usage | Active sampling | Visible (56 pt) | Visible |
| Network Usage | Waiting for first sample | Hidden | **Hidden** (placeholder rect) |
| Network Usage | Sampling off | Hidden | **Hidden** (dashed container) |

| Duration setting | Leading token | Trailing token |
| --- | --- | --- |
| `30` | `-30s` | `Now` |
| `60` (default) | `-1m` | `Now` |
| `120` | `-2m` | `Now` |
| `180` | `-3m` | `Now` |
| `300` | `-5m` | `Now` |

### Part 4: Accessibility & Interaction Contracts

1. `SparklineTimeAxisView` declares `.accessibilityHidden(true)`; card containers keep `.accessibilityElement(children: .ignore)`. VoiceOver reads only the card composite summary.
2. Typography: 9 pt system font, `.monospacedDigit()`, `.tertiary` foreground, leading token at plot X=0, trailing `Now` at plot X=240.
3. No hover tracking, no cursor scrubbing, no `.animation`, no `.contentTransition` (AGENTS.md status item rule). `.equatable()` prevents redraws when the duration does not change.

### Part 5: Numbered Visual Acceptance Checklist (VAC)

| Check ID | Scope | Component | Visual Acceptance Invariant |
| --- | --- | --- | --- |
| VAC-1 | Popover, dark + light | `CPUCardView` | Axis row renders directly below `SparklineView`, above `disclosure`. |
| VAC-2 | Popover, dark + light | `MemoryPressureCardView` | Axis row renders directly below `SparklineView`, above `usedLine`. |
| VAC-3 | Popover, dark + light | `GPUCardView` (available) | Axis row renders directly below `SparklineView` when `gpu != nil`. |
| VAC-4 | Popover, dark + light | `GPUCardView` (unavailable) | No axis row. Dashed container only. |
| VAC-5 | Popover, dark + light | `NetworkCardView` (active) | Axis row renders directly below `NetworkSparklineView` via `SparklineTimeAxisView`. |
| VAC-6 | Popover, dark + light | `NetworkCardView` (loading / off) | No axis row in either state. |
| VAC-7 | All states | `SparklineTimeAxisView` | Leading token and `Now` on one line. No wrap, no vertical truncation. |
| VAC-8 | All states, dark + light | `SparklineTimeAxisView` | 9 pt, tertiary foreground in both appearances. |
| VAC-9 | All states | `SparklineTimeAxisView` | Duration 60 → `-1m`; 120 → `-2m`; 30 → `-30s`. Raw labels like `-120s` / `-300s` never appear. |
| VAC-10 | All states | Card containers | Leading label left-aligns with chart canvas left edge; `Now` right-aligns with canvas right edge. |
| VAC-11 | Popover window | Popover | All four cards and footer fit. Nothing clips at the bottom boundary. |
| VAC-12 | VoiceOver | All cards | Axis row is skipped in the accessibility tree; no duplicate announcements. |

Scope note: the popover is a fixed 280 pt-wide macOS window, so the web 375/768/1440
width sweep does not apply. Verification runs at dark and light appearance for every
state in the matrix above.

## ISC

Binary checks:

- [ ] ISC-1 (FM1) A shared `SparklineTimeAxisView` exists and is used by all four cards; no card renders its own ad-hoc axis row. Falsification: `rg "SparklineTimeAxisView"` shows one definition and four use sites; the old Network `axisRow` helper is deleted.
- [ ] ISC-2 (FM2) Formatter maps every history duration setting: 30 → `-30s`, 60 → `-1m`, 120 → `-2m`, 180 → `-3m`, 300 → `-5m`. Falsification: unit tests fail when raw-second formatting is restored.
- [ ] ISC-3 (FM3) Axis appears only where the chart appears: absent in GPU-unavailable, Network-loading, and Network-off states. Falsification: screenshots of those states show no axis row.
- [ ] ISC-4 (FM4) No visual defect: no text wrap, truncation, misalignment, or border clipping on any axis row (zero-tolerance visual policy). Falsification: VAC-7 / VAC-10 screenshots fail.
- [ ] ISC-5 (FM5) Popover height fits: all four cards plus footer render without clipping the bottom boundary. Falsification: VAC-11 screenshot fails.
- [ ] ISC-6 All VAC-1 … VAC-12 pass, dark and light, verified by `tester` with screenshots.
- [ ] ISC-7 Pre-edit baseline exists before the first code edit. The automated
  `scripts/capture_baseline.sh` run failed with an Apple Events TCC denial
  (`Not authorized to send Apple events to System Events`, exit 1), so the baseline
  is the existing pre-change dark/light build artifacts:
  `artifacts/2026-10-16-add-network-usage-chart/after/dark.png` and `.../light.png`
  (no chart code changed since that build). The tester's `after/` screenshots are
  compared against these.
- [ ] ISC-8 Zero `.animation`, `.contentTransition`, hover tracking, or scrubbing code introduced; sparklines stay `.accessibilityHidden(true)` and the new row is `.accessibilityHidden(true)`.
- [ ] ISC-9 macOS test run passes: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -configuration Debug -derivedDataPath .derivedData test -destination 'platform=macOS' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1`; 0 type errors on changed files. (StatsLite is a macOS app; no simulator destination.)

Evidence rule: no root cause or numeric estimate ships without a measurement (project
AGENTS.md). This plan has no root-cause hypothesis; each ISC check is observed directly
from screenshots, `rg`, or test output.

## Approach

- R2 UI work; designer Blueprint above is authoritative and must be implemented verbatim.
- TDD: `red` phase owns the formatter contract only (pure logic). The view integration
  follows the Blueprint directly, so the view work runs under `[skip-red]` inside the
  green task.
- Refactors (no band-aids ship): delete the Network card's ad-hoc `axisRow` in the same
  commit that adds the shared component; no duplicated `HStack` styling.
- `MetricFormatters` gets the formatting extension (single home for label formatting).

## Tasks

- [ ] **T1** — `[red]` write failing unit tests for `MetricFormatters.historyDurationAxis` covering all five durations (30/60/120/180/300), the `<60s` branch, the negative clamp, and the NaN/infinite guard; run the suite, report red output, touch no app code. red `1c772e2` · green — · review —

  Red evidence (T1, 2026-10-17): `StatsLiteTests/MetricFormatterHistoryDurationAxisTests.swift`,
  4 test methods / 10 assertions. Suite run exit 65, `** TEST FAILED **`, 10× `Type
  'MetricFormatters' has no member 'historyDurationAxis'`, build fails before execution
  (xcresult totalTestCount 0). Compile-failure red is the intended red for a new API.
- [ ] **T2** — `[skip-red]` green: implement `historyDurationAxis`, add `SparklineTimeAxisView` (Blueprint Part 2), integrate into CPU / Memory / GPU / Network cards, delete the Network `axisRow`, run tests to green. red `T1` · green `071e1b7` · review ⏳
- [x] **T3** — self-verify: 0 type errors on changed files; the macOS `xcodebuild test` command from ISC-9 passes. record ✓

  T2 green evidence (2026-10-17): `** TEST SUCCEEDED **`, 233 tests / 0 failures; red suite
  4/4 methods (10/10 assertions) with zero test-file edits. Binary checks: 1 definition
  + 4 use sites of `SparklineTimeAxisView`; `rg axisRow` clean; no animation/transition/
  hover code added. `SystemMonitor.historyDuration` (SystemMonitor.swift:38) confirmed as
  the plan's history-window duration (Settings values 30/60/120/180/300). Project uses
  `PBXFileSystemSynchronizedRootGroup`, so the new file joins the target with no pbxproj
  edit; successful compile of all four use sites confirms membership. SourceKit LSP
  "Cannot find in scope" findings are phantom (identical errors on untouched files,
  standalone parse without project settings); xcodebuild is authoritative.
  Open item: the plan's Docs section presupposes a `DESIGN.md` that does not exist in
  this repo (no such file in history); the axis rule will land in the repo `AGENTS.md`
  instead, as a planner-owned MD change after merge.
- [x] **T4** — `tester` VAC run: verdict `OVERALL: INCOMPLETE` (2026-10-17); dark-capture step TCC-blocked (Apple Events -1743, same denial that killed the baseline script). Verdict `INCOMPLETE` → user directed "skip tester" after the report; remaining gap waived by user.

  Tester evidence: light-appearance captures `after/light.png`, `after/light_t8.png`,
  `after/light_network_loading.png` (+ `after/probe_light.log`) show VAC-1,2,3,5,6,7,9,10,11
  Met; VAC-4 and VAC-12 code-verified (rg/diff); VAC-8 Met in light, dark capture Blocked.
  Window grew exactly +45 pt for 3 axis rows vs the 2026-10-16 baseline; no visual defect
  found. Environment restored (prefs: historyDuration=120, showNetwork=1, refreshInterval=5,
  appearance auto; all test StatsLite instances killed). verdict ✗ · screenshots in
  `worktrees/2026-10-17-chart-time-axis-all-metric-cards/artifacts/2026-10-17-chart-time-axis-all-metric-cards/after/`
- [ ] **T5** — `reviewer` code review against `git diff main...HEAD`; on GO, merge `--ff-only` or `--squash` to main. verdict ⏳ · merge ⏳

Notation: Plan → Phase → Task (`T*`) → Receipts (red SHA / green SHA / review verdict).

## Docs

- `DESIGN.md`: add one rule row — every metric-card sparkline carries a shared
  `SparklineTimeAxisView` (`-30s/-1m/…` … `Now`, 9 pt tertiary monospaced digit,
  accessibility-hidden).
- `ARCHITECTURE.md`: note only if component placement rules are documented there.
