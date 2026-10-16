# ISC: Reduce StatsLite View-Layer Weight (No Append-Only Bitmaps)

Date: 2026-10-15
Author: planner
Status: Approved by user (decisions: vector redraw kept; fixed-step full-width geometry, empty start). Revision 2 approved: menu bar redraw-churn fix (Phase 5).

## Title
Make the StatsLite view layer lightweight: stop hidden view evaluation, stop false invalidations, stop per-tick heap allocations. Keep chart visuals pixel-identical.

## Background
Post-menubar-rework (commits 656b2f5 → f27eff3) the app measures ~7.6% idle CPU (projection: <0.03%) and RSS reads ~200MB+ (AC-10 target: <50MB physical footprint). Two prior investigations (oracle-adjudicated) found:

1. The chart draw itself is not heavy. Stroking the 30–60 point sparkline path in `Canvas` costs ~50µs (StatsLite/SparklineView.swift:22).
2. The heaviness comes from lifecycle and invalidation defects:
   - `StatusItemController.swift:51-55` creates the popover `NSHostingController` at init and holds it for the app's life. Three sparklines plus three card views evaluate every 2s tick while the popover is closed.
   - `SystemSnapshot.timestamp` (MetricTypes.swift:190) guarantees snapshot inequality every tick, so `.onChange(of: monitor.latestSnapshot)` (MenuBarStackedItemView.swift:49) fires unconditionally and rebuilds accessibility labels every 2s.
   - `HistoryBuffer.values` (HistoryBuffer.swift:23) is a computed `points.map(\.value)`. Three heap `[Double]` arrays are allocated every tick.
3. An append-only bitmap chart (the originally requested mechanism) was evaluated and rejected by oracle: `HistoryBuffer` trims the oldest point on every tick in steady state, and a bitmap cannot un-draw it. Append-only therefore degrades to a full redraw every tick, plus Retina blit blur, stale colors on dark/light and tint changes, and ~440KB retained bitmap per chart.

## Scope
In: `StatusItemController.swift`, `MetricTypes.swift`, `HistoryBuffer.swift`, `SparklineView.swift`, popover card call sites, tests.
Out: visual redesign, sampling-pipeline changes, Settings window, new features.

## Objectives
1. Zero view evaluation and zero draw calls while the popover is closed.
2. No view invalidation on a tick where enabled metrics are unchanged.
3. Zero heap allocation per tick from the history buffer path.
4. Pixel-identical chart output vs the current implementation.

## Deliverables (4 phases, one commit each)
- Phase 1 — Popover lifecycle: do not set `contentViewController` in `StatusItemController.init`; mount `NSHostingController(rootView: PopoverContentView(...))` lazily in `togglePopover(_:)`; set `contentViewController = nil` in `popoverDidClose(_:)`. Documented consequence: `@State private var coresExpanded` (PopoverContentView.swift:20) resets to `false` on every close. This is accepted as transient popover state, not a regression.
- Phase 2 — Snapshot equality: custom `Equatable` on `SystemSnapshot` that compares `enabled`, `cpu`, `memory`, `memoryPressure`, `gpu` and excludes `timestamp`.
- Phase 3 — Zero-allocation history + equatable sparkline: maintain a stored `[Double]` values array inside `HistoryBuffer`, mutated in lockstep with `points` inside `append` (drop the computed `map`). Exact algorithm: (1) append `HistoryPoint(value:timestamp:)` to `points` and `value` to `values`; (2) `expiredCount = points.prefix(while: { timestamp.timeIntervalSince($0.timestamp) > maxAge }).count`; (3) if `expiredCount > 0`, `removeFirst(expiredCount)` on both arrays; (4) `overflow = points.count - Swift.max(capacity, 1)`; if `overflow > 0`, `removeFirst(overflow)` on both arrays; (5) `.map` inside `append` is forbidden. Make `SparklineView: Equatable` (compare values + tint) and apply `.equatable()` at call sites.
- Phase 4 — Sparkline geometry per the Design Blueprint (Appendix A), with capacity bound to user preferences: add `var sparklineCapacity: Int { Swift.max(Int(historyDuration) / Swift.max(refreshInterval, 1), 2) }` to `SystemMonitor` (effective sample count after age trimming, mirroring SystemMonitor.swift:115-116); pass `capacity: monitor.sparklineCapacity` at all three card call sites (CPUCardView.swift:39, MemoryPressureCardView.swift:43, GPUCardView.swift:34). Geometry: fixed step `dx = plotWidth / (capacity − 1)`, right-anchored newest point, empty canvas at N = 0, single dot at N = 1, no warm-up stretch. The Part 2 skeleton's hardcoded `capacity: Int = 30` default is replaced by the passed preference-derived value; full-buffer geometry (N = capacity) is mathematically identical to the current implementation at default settings.
- Phase 5 (revision 2, approved) — Menu bar redraw-churn fix. Verification of Phases 1-4 failed AC-1 (idle CPU 2.9-3.8% vs <0.1%) and AC-6 (footprint 208MB vs <50MB). Oracle-adjudicated root cause (99% confidence, evidence: .pi/plans/2026-10-15-stats-lite-view-weight-verification/ac6-allocation-calltree.txt — 55,456 of 55,530 layer draws are `RBInterpolatedDisplayListContents`): `.contentTransition(.numericText())` (MenuBarStackedItemView.swift:43) and `.animation(.easeInOut(duration: 0.2), value: block.valueText)` (line 80) keep RenderBox re-rasterizing glyphs at AppKit's ~4.9ms UpdateCycle quantum (~205 redraws/s), amplified by the unsettled hosting-view layout (StatusItemController.swift:72-80, no height constraint, default sizingOptions). Fix: (1) delete both modifiers — digits update discretely, no roll animation (user-approved consequence); static geometry byte-identical; (2) stabilize PassthroughHostingView: `sizingOptions = []` and frame-based layout (`translatesAutoresizingMaskIntoConstraints = true`, `autoresizingMask = [.width, .height]`, frame = button.bounds) so it follows statusItem.length changes on metric toggles without clipping; (3) enforce no `.animation`/`.contentTransition` on the status item path (code comment + AGENTS.md rule). Re-measure AC-1 and AC-6 after.

## Success Criteria (measurable)
- AC-1: With the popover closed 5 minutes, Instruments (Time Profiler) shows `SparklineView.body` never executes and main-thread CPU < 0.1%.
- AC-2: On a tick where all enabled metric values are unchanged, `.onChange(of: monitor.latestSnapshot)` does not fire (unit test on `==` plus runtime counter assert).
- AC-3: `HistoryBuffer.append` performs no heap allocation per call (MallocStackLogging spot check or allocation-count test).
- AC-4: Visual equivalence at full buffer: inject one fixed full-capacity synthetic series at default settings, `screencapture` the popover cards before and after the change; pixel diff = 0 (full-buffer geometry is identical by construction).
- AC-5: Visual verification ledger — each of VAC-1 through VAC-11 (Appendix A Part 5) is an independent binary check with its own screenshot evidence at light and dark appearance, at 240/375/768 pt widths. All 11 must be individually marked pass in the verification report; a bundled verdict is not acceptable.
- AC-6: AC-10 protocol still passes: `footprint <pid>` under 50MB after launch, one popover open/close, 60s idle.
- AC-7: `SystemSnapshot` equality unit tests: two snapshots differing only in `timestamp` compare equal; any change to `enabled`, `cpu`, `memory`, `memoryPressure`, or `gpu` produces inequality.
- AC-8: `HistoryBuffer` synchronization unit tests: `values` matches `points.map(\.value)` after initial fill, after multi-point age eviction, and after capacity truncation; steady-state `append` performs zero heap allocations (allocation-count test).
- AC-9: `SparklineView` geometry unit tests: N = 0 yields an empty path; N = 1 yields a dot at `x = width − 1.5` with no full-width stroke; `2 ≤ N < C` yields a right-anchored line spanning `(N−1)×dx` with empty left margin; `N ≥ C` spans the full active width; values below 0 and above `domainMax` clamp; `Equatable` is true for equal values+tint and false otherwise.
- AC-10: Preference coverage: for every combination of `historyDuration` (30s, 60s) and `refreshInterval` (1s, 2s, 5s), the sparkline reaches 100% active card width in steady state (no permanently empty right/left region) and displays the full effective history window (no silent truncation to 30 samples).
- AC-11 (revision 2): Redraw churn eliminated: with the app idle and popover closed, `RBInterpolatedDisplayListContents renderInContext:` is never called (lldb breakpoint or malloc trace count = 0 over ≥60s), and process CPU averages < 0.1% over ≥5 minutes. Status item content still updates on the 2s tick.
- AC-12 (revision 2): AC-1 and AC-6 re-measured after Phase 5: idle CPU < 0.1% (AC-1) and physical footprint < 50MB dirty after 15 minutes idle with one popover open/close cycle (AC-6). Both are blocking for plan completion.

## Assumptions
- The user accepts vector `Canvas` redraw per tick over append-only bitmaps, because steady-state cost is ~50µs and it is the only approach that survives rolling-window trim, Retina scaling, and dark/light changes without stale pixels.
- Lazy popover mount does not add visible latency on reopen (verify in AC-1; if it does, warm the hosting view offscreen on first open only).
- Tearing down the popover on close releases transient popover `@State`, including `coresExpanded` (PopoverContentView.swift:20). This reset-on-close behavior is accepted.

## Constraints
- Zero-tolerance visual policy: chart output must be pixel-identical (AC-4 is blocking).
- All code changes via worktree on a non-base branch; merge to main fast-forward or squash; conventional commits.
- Each phase is an independent commit so rollback is a single revert.

## Dependencies
None external. Uses existing test targets in StatsLiteTests.

## Risks & Mitigations
- Popover reopen latency: measure in AC-1; fallback is an offscreen warm-up on first toggle.
- `.equatable()` masking a real update (e.g. tint change on pressure level): include tint and full values array in the comparison.
- Accessibility label staleness when only `timestamp` changes: labels derive from metric values, not timestamps; verify with an accessibility assertion.
- Warm-up visual change is intentional and user-directed: during the first `capacity` samples the line grows leftward from the right edge instead of stretching full width. The single-sample flat line is replaced by a dot (blueprint Part 1, Right-Anchored model).

## Rollback
Revert the single phase commit that regresses. No data migrations.

## Out of Scope
- Pausing the 2s sampling timer when the popover is closed (menu bar metrics must stay live per AC requirements).
- Replacing `Canvas` with Metal or Core Animation layer trees (evaluated, rejected: more overhead).

## Open Questions
None. Resolved 2026-10-15:
1. Append-only bitmap charts: rejected; vector Canvas redraw kept (user approval).
2. Geometry: fixed step, full width from the first sample, right-anchored, chart empty before the first sample (user decision; Design Blueprint in Appendix A).

## Final Go/No-Go Decision
GO from user ("ok" with decisions 1 and 2 above).


---

# Appendix A: Design Blueprint (verbatim, from designer)

# Design Blueprint: Sparkline Fixed Step and Warm-up Alignment

This blueprint specifies the geometry, lifecycle, and visual invariants for `SparklineView.swift` in StatsLite.
The repository contains no root `DESIGN.md`. Design tokens and container contracts originate from `StatsLite/DesignTokens.swift` and parent card views.

---

## Part 1: Intent, Scope, and Directional Rationale

### Intent
This specification corrects the warm-up stretching defect in `SparklineView.swift`.
In the current implementation, the view calculates horizontal spacing with `denominator = Double(max(values.count - 1, 1))`.
This formula stretches whatever points exist across the entire width of the card.
When only two samples exist, the chart places them at 0% and 100% width.
When the third sample arrives, the second sample jumps from 100% to 50% width.
Every tick shifts existing points leftward by variable percentages.
When only one sample exists, the current code renders a flat horizontal line across the entire card.
This behavior misleads the user about history duration.

### Scope
This change applies to three metric cards in the popover:
1. `CPUCardView.swift`: CPU sparkline using `monitor.cpuHistory.values` with blue tint or orange alert tint.
2. `MemoryPressureCardView.swift`: Memory pressure sparkline using `monitor.memoryPressureHistory.values` with system pressure level tint.
3. `GPUCardView.swift`: GPU sparkline using `monitor.gpuHistory.values` with teal tint.

This change does not apply to `MenuBarStackedItemView.swift`.
`MenuBarStackedItemView.swift` renders category labels and percentage values only.
It contains no sparkline view.

### Chosen Warm-Up Model: Right-Anchored (Line Grows Leftward from Right Edge)

We evaluated two models for the warm-up state:
- **Model A (Right-Anchored)**: New points enter at the right edge. The line grows leftward into the past.
- **Model B (Left-Anchored)**: Points start at the left edge. The line grows rightward into the future until full.

We choose **Model A (Right-Anchored)**.
We select Model A for these four reasons:
1. **Temporal Axis Invariance**: In a rolling history sparkline, the horizontal axis represents relative time $\Delta t \le 0$. The right edge ($x = \text{size.width} - \text{inset}$) represents the present moment ($t = 0$, "Now"). Anchoring the newest sample at the right edge gives the user one fixed location for current system status.
2. **Zero Mode-Switch**: In Model B, the newest sample moves rightward across the card during warm-up. When the buffer reaches capacity, this movement halts abruptly and the entire waveform starts scrolling leftward. This change in motion breaks visual consistency. In Model A, the interaction remains identical on every tick: the latest sample arrives at the right edge, and existing points step leftward by one fixed step $dx$.
3. **Card Header Alignment**: In each popover card, the current numeric metric value aligns to the right edge. When the newest sample anchors at the right edge, the latest visual data point sits directly below the numeric readout.
4. **macOS Platform Consistency**: macOS Activity Monitor and standard macOS performance monitors anchor current time at the right edge and scroll historical data leftward.

---

## Part 2: Visual Specification, Exact Geometry Rules, and Component Skeleton

### Visual Hierarchy and Wireframes

#### State A: Empty Buffer ($N = 0$)
Evidence: `/tmp/designer/card_target_empty_light.png`
```
+-------------------------------------------------------------+
| [icon] CPU Total                                      --%   |
| Waiting for first sample                                    |
|                                                             |
|                                                             |
|                     (38 pt blank space)                     |
|                                                             |
+-------------------------------------------------------------+
```

#### State B: Single Sample ($N = 1$)
Evidence: `/tmp/designer/card_target_1pt_light.png`
```
+-------------------------------------------------------------+
| [icon] CPU Total                                    30.0%   |
| Across 8 cores                                              |
|                                                             |
|                                                           * |  <- 1.5 pt dot at right edge
|                                                             |
+-------------------------------------------------------------+
```

#### State C: Warm-up State ($N = 5$, Capacity = 30)
Evidence: `/tmp/designer/card_target_5pts_light.png`
```
+-------------------------------------------------------------+
| [icon] CPU Total                                    44.2%   |
| Across 8 cores                                              |
|                                                    _.-*     |  <- Stroke connects 5 points
|                                                   /:::|     |  <- Area fill closed below line
|      (25 steps transparent whitespace)            |:::|     |  <- Left region remains empty
+-------------------------------------------------------------+
```

#### State D: Full Buffer State ($N = 30$, Capacity = 30)
Evidence: `/tmp/designer/card_target_30pts_light.png`
```
+-------------------------------------------------------------+
| [icon] CPU Total                                    65.1%   |
| Across 8 cores                                              |
|   .-''''-.                                           _.-*   |  <- Stroke spans full width
|  /::::::::\_________________________________________/:::|   |  <- Area fill spans full width
| /:::::::::::::::::::::::::::::::::::::::::::::::::::::::|   |
+-------------------------------------------------------------+
```

### Exact Geometry Rules
- Container bounds: Width expands to fill parent. Height is fixed at 38 pt (`SparklineView.swift:65`).
- Boundary inset: $1.5\text{ pt}$ on all four edges (`SparklineView.swift:24`).
- Active plot width: $\text{plotWidth} = \text{size.width} - (2 \times \text{inset})$.
- Active plot height: $\text{plotHeight} = \text{size.height} - (2 \times \text{inset}) = 38.0 - 3.0 = 35.0\text{ pt}$.
- Capacity parameter: `capacity: Int = 30` (defaults to 30 samples).
- Fixed horizontal step: $dx = \text{plotWidth} / \max(\text{capacity} - 1, 1)$.
- In a standard 280 pt popover card with 20 pt total horizontal inset, content width is 240 pt. $\text{plotWidth} = 240 - 3 = 237\text{ pt}$. For $\text{capacity} = 30$, $dx = 237 / 29 \approx 8.1724\text{ pt}$.
- If $N > \text{capacity}$, slice the input array to the newest `capacity` points.
- Let $N$ be the sample count of the rendering slice.
- Point coordinate formula for sample $i \in [0, N-1]$ with value $v_i$:
  - $x_i = (\text{size.width} - \text{inset}) - \text{CGFloat}(N - 1 - i) \times dx$.
  - $\text{fraction}_i = \min(\max(v_i, 0), \max(\text{domainMax}, 0.0001)) / \max(\text{domainMax}, 0.0001)$.
  - $y_i = \text{inset} + (1 - \text{CGFloat}(\text{fraction}_i)) \times \text{plotHeight}$.
- Stroke specification:
  - Color: `tintColor`.
  - Line width: 1.5 pt.
  - Line cap: `.round`.
  - Line join: `.round`.
  - If $N = 1$: the path calls `line.move(to: p0)` and `line.addLine(to: p0)`. The canvas strokes a single circular dot with diameter 1.5 pt at $(\text{size.width} - \text{inset}, y_0)$.
  - If $N \ge 2$: the path connects $(x_0, y_0)$ through $(x_{N-1}, y_{N-1})$.
- Gradient area fill specification:
  - If $N < 2$: Area fill does not draw.
  - If $N \ge 2$: Area polygon begins at $(x_0, y_0)$, connects through $(x_{N-1}, y_{N-1})$, drops vertically to $(x_{N-1}, \text{size.height})$, extends left to $(x_0, \text{size.height})$, and closes back to $(x_0, y_0)$.
  - Gradient colors: Linear gradient from `tintColor.opacity(0.25)` at top $(y = 0)$ to `tintColor.opacity(0.02)` at bottom $(y = \text{size.height})$.
  - Bounding: Area fill stays strictly beneath the line segment. It never enters the left whitespace region.

### Component Skeleton (Verbatim SwiftUI Implementation)
The coder subagent can copy this implementation verbatim:

```swift
//
//  SparklineView.swift
//  StatsLite
//
//  38 pt sparkline drawn with Canvas and Path only. No Charts import,
//  no axes, no tick labels.
//

import SwiftUI

struct SparklineView: View, Equatable {
    /// Point values, oldest first. Each value is a fraction in 0...1.
    let values: [Double]

    /// Line and gradient tint.
    let tintColor: Color

    /// Fixed vertical domain. 1.0 covers the 0...1 metric range.
    var domainMax: Double = 1.0

    /// Sample capacity representing the full horizontal chart window.
    /// Defines the fixed horizontal step: (width - 2 * inset) / (capacity - 1).
    var capacity: Int = 30

    var body: some View {
        Canvas { context, size in
            guard size.width > 2, size.height > 2 else { return }
            guard !values.isEmpty else { return }

            let inset: CGFloat = 1.5
            let plotWidth = size.width - inset * 2
            let plotHeight = size.height - inset * 2
            let denominator = Double(max(capacity - 1, 1))
            let dx = plotWidth / CGFloat(denominator)

            // Clamp rendering slice to at most capacity points.
            let renderValues = values.count > capacity ? Array(values.suffix(capacity)) : values
            let count = renderValues.count

            func point(at index: Int, value: Double) -> CGPoint {
                let x = (size.width - inset) - CGFloat(count - 1 - index) * dx
                let fraction = min(max(value, 0), max(domainMax, 0.0001)) / max(domainMax, 0.0001)
                let y = inset + (1 - CGFloat(fraction)) * plotHeight
                return CGPoint(x: x, y: min(max(y, inset), size.height - inset))
            }

            var line = Path()
            if count == 1 {
                let pt = point(at: 0, value: renderValues[0])
                line.move(to: pt)
                line.addLine(to: pt)
            } else {
                for (index, value) in renderValues.enumerated() {
                    let next = point(at: index, value: value)
                    if index == 0 {
                        line.move(to: next)
                    } else {
                        line.addLine(to: next)
                    }
                }
            }

            // Area fill below the line: tint 0.25 at the top to 0.02
            // at the bottom. Fill bounds clamp strictly to the line span.
            if count > 1 {
                var area = line
                let rightPt = point(at: count - 1, value: renderValues[count - 1])
                let leftPt = point(at: 0, value: renderValues[0])
                area.addLine(to: CGPoint(x: rightPt.x, y: size.height))
                area.addLine(to: CGPoint(x: leftPt.x, y: size.height))
                area.closeSubpath()

                context.fill(
                    area,
                    with: .linearGradient(
                        Gradient(colors: [tintColor.opacity(0.25), tintColor.opacity(0.02)]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }

            context.stroke(
                line,
                with: .color(tintColor),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 38)
        .accessibilityHidden(true)
    }
}
```

---

## Part 3: Layout and Spacing Rules (Cited from Existing Code)

Every design token and container rule comes directly from existing repository code:
- Card padding: 10 pt (`DesignTokens.swift:45`).
- Card corner radius: 8 pt continuous (`DesignTokens.swift:46, 50`).
- Card container fill: `Color(nsColor: .controlBackgroundColor).opacity(0.65)` (`DesignTokens.swift:47`).
- Card border stroke: `Color(nsColor: .separatorColor).opacity(0.5)`, lineWidth 0.5 pt (`DesignTokens.swift:51`).
- Card internal vertical spacing: `VStack(alignment: .leading, spacing: 4)` (`CPUCardView.swift:21`, `MemoryPressureCardView.swift:29`, `GPUCardView.swift:20`).
- Header icon size and weight: `.system(size: 11, weight: .semibold)` (`CPUCardView.swift:24`, `MemoryPressureCardView.swift:32`, `GPUCardView.swift:23`).
- Header title font: `.system(size: 11, weight: .semibold)` (`CPUCardView.swift:27`, `MemoryPressureCardView.swift:35`, `GPUCardView.swift:26`).
- Header numeric value font: `.system(size: 12, weight: .bold, design: .rounded).monospacedDigit()` (`CPUCardView.swift:30`, `GPUCardView.swift:54`).
- Sparkline height: 38 pt fixed (`SparklineView.swift:65`).
- Sparkline inset: 1.5 pt (`SparklineView.swift:24`).
- Sparkline stroke line width: 1.5 pt (`SparklineView.swift:61`).
- Sparkline stroke styling: `lineCap: .round, lineJoin: .round` (`SparklineView.swift:61`).
- Gradient top opacity: `0.25` (`SparklineView.swift:50`).
- Gradient bottom opacity: `0.02` (`SparklineView.swift:50`).
- Sparkline accessibility: `.accessibilityHidden(true)` (`SparklineView.swift:66`).
- Popover panel width: 280 pt fixed (`PopoverContentView.swift:51`).
- Popover inner padding: 10 pt horizontal (`PopoverContentView.swift:38`).
- Sparkline width in popover: $280 - (2 \times 10) - (2 \times 10) = 240\text{ pt}$. Active width between insets: $237\text{ pt}$.

---

## Part 4: State-to-Visual Matrix

| State | Sample Count $N$ | Visual Behavior | Stroke Geometry | Fill Geometry | Evidence Image |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Empty** | $N = 0$ | Transparent 38 pt canvas. Card height stays stable. | None | None | `/tmp/designer/card_target_empty_light.png`<br>`/tmp/designer/card_target_empty_dark.png` |
| **First Sample** | $N = 1$ | Single 1.5 pt dot at right edge. No full-width flat line. | Dot at $(\text{width} - 1.5, y_0)$ | None | `/tmp/designer/card_target_1pt_light.png`<br>`/tmp/designer/card_target_1pt_dark.png` |
| **Early Warm-up** | $2 \le N \le C/2$ | Line spans $(N-1) \times dx$ at right edge. Left area is empty. | Stroke from $x_0$ to $x_{N-1}$ | Fill closed under line to bottom edge | `/tmp/designer/card_target_5pts_light.png`<br>`/tmp/designer/card_target_5pts_dark.png` |
| **Full Capacity** | $N = C$ | Line spans full active width from $x = 1.5$ to $x = \text{width} - 1.5$. | Stroke from inset to width - inset | Fill spans full width | `/tmp/designer/card_target_30pts_light.png`<br>`/tmp/designer/card_target_30pts_dark.png` |
| **Trim Tick (Rolling)** | $N = C$ | Curve steps left by exactly $dx$. Distance between points stays rigid. | Rigid translation leftward by $dx$ | Fill shifts with curve | `/tmp/designer/rolling_tickA.png`<br>`/tmp/designer/rolling_tickB.png` |
| **Responsive Resize** | Any | Step $dx$ scales linearly with width. Line stays right-anchored. | Proportional scaling across viewports | Fill scales with line | `/tmp/designer/spark_240_light.png`<br>`/tmp/designer/spark_375_light.png`<br>`/tmp/designer/spark_768_light.png` |
| **Appearance Switch** | Any | Stroke and gradient adapt cleanly between light and dark themes. | Crisp contrast against container | No clipping or edge halo | `/tmp/designer/spark_240_dark.png`<br>`/tmp/designer/spark_375_dark.png`<br>`/tmp/designer/spark_768_dark.png` |

---

## Part 5: Numbered Visual Acceptance Checklist (VAC)

| ID | Scope and Viewport | Exact Visual Invariant | Pass Criterion (Yes / No) |
| :--- | :--- | :--- | :--- |
| **VAC-1** | Sparkline (All widths, Light & Dark) | When $N = 0$, the sparkline canvas renders zero stroke and zero fill while preserving its 38 pt height. | Pending verification |
| **VAC-2** | Sparkline (All widths, Light & Dark) | When $N = 1$, the chart renders no horizontal flat line across the card width. | Pending verification |
| **VAC-3** | Sparkline (All widths, Light & Dark) | When $N = 1$, the chart renders a single discrete dot anchored at $x = \text{width} - 1.5\text{ pt}$. | Pending verification |
| **VAC-4** | Sparkline (240 pt Popover, Light & Dark) | During warm-up ($2 \le N < C$), the newest point always anchors at $x = \text{width} - 1.5\text{ pt}$. | Pending verification |
| **VAC-5** | Sparkline (All widths, Light & Dark) | During warm-up ($2 \le N < C$), the horizontal distance between adjacent points equals $dx = \text{plotWidth} / (C - 1)$. | Pending verification |
| **VAC-6** | Sparkline (All widths, Light & Dark) | During warm-up ($2 \le N < C$), the area fill closes directly beneath the line segment and leaves the left region empty. | Pending verification |
| **VAC-7** | Sparkline (All widths, Light & Dark) | When $N = C$, the line stroke begins at $x = 1.5\text{ pt}$ and terminates at $x = \text{width} - 1.5\text{ pt}$. | Pending verification |
| **VAC-8** | Sparkline (All widths, Light & Dark) | On each steady-state tick, existing sample points translate leftward by exactly one step $dx$ without point stretching. | Pending verification |
| **VAC-9** | Sparkline (240 pt, 375 pt, 768 pt) | When the sparkline width scales, the horizontal step scales proportionally without clipping or line breaks. | Pending verification |
| **VAC-10** | Sparkline (All widths, Light & Dark) | In both light and dark appearance modes, stroke and gradient render with native macOS colors and zero stale pixels. | Pending verification |
| **VAC-11** | Popover Cards (Accessibility) | The canvas element carries `.accessibilityHidden(true)`, and parent cards provide complete spoken metric summaries. | Pending verification |

---

### Summary of Accomplishments
1. Inspected repository configuration, confirmed no root `DESIGN.md` exists, and grounded all design tokens in `StatsLite/DesignTokens.swift` and parent card views.
2. Formulated and resolved the growth-direction choice: selected the Right-Anchored model with four concrete rationales (temporal axis invariance, zero mode-switch, card header numeric alignment, macOS platform conventions).
3. Derived the exact geometry rules and coordinate mapping formulas, eliminating warm-up stretching and eliminating single-point flat line artifacts.
4. Rendered and inspected visual evidence across multiple sample counts ($N = 0, 1, 5, 15, 30$), multiple viewports (240 pt, 375 pt, 768 pt), and both macOS appearance modes (Light and Dark) in `/tmp/designer/`.
5. Formulated the complete 5-Part Design Blueprint and discrete acceptance checklist (VAC-1 through VAC-11) conforming to Simplified Technical English. Cleaned up all temporary files outside repository without modifying project source code.