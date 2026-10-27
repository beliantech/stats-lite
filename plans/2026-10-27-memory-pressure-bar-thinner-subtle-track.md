Plan name: 2026-10-27-memory-pressure-bar-thinner-subtle-track
Risk class: R2 (UI work)

## Intent

The memory pressure gauge bar in the popover memory card is visually too thick, and its unfilled track is too prominent. Two changes:

1. Reduce the gauge bar height from 8 pt to 6 pt so it matches the Used memory composition bar.
2. Replace the unfilled track color with a subtle token that blends into the card background.

User revision after deploy: the track must use the SAME gray as the Used memory bar's Free/remainder segment (`Color(nsColor: .quaternaryLabelColor)`, `MemoryPressureCardView.swift:131`), not a near-invisible separator wash. `Color.metricBarTrack` is retargeted accordingly (task T5).

Verified current state:
- `StatsLite/MemoryPressureCardView.swift:108` — track is `Color(nsColor: .separatorColor).opacity(0.2)`.
- `StatsLite/MemoryPressureCardView.swift:114` — gauge frame height `8`.
- `StatsLite/MemoryPressureCardView.swift:133` — composition bar frame height `6`.
- `StatsLite/DesignTokens.swift` — no shared bar height or track tokens today.

## ISC (binary checks)

- ISC-1 — `StatsLite/DesignTokens.swift` defines `CGFloat.metricBarHeight = 6`, `CGFloat.metricBarCornerRadius = 3`, and `Color.metricBarTrack = Color(nsColor: .separatorColor).opacity(0.08)`.
- ISC-2 — `gaugeBar` and `compositionBar` both use `.metricBarHeight` and `.metricBarCornerRadius`. No literal `8` / `6` / `3` bar geometry remains in `MemoryPressureCardView.swift`.
- ISC-3 — The gauge track fill uses `Color.metricBarTrack`. No `.opacity(0.2)` track remains in the file.
- ISC-4 — FM1: no text regression — the title, badge, "Used" line, and breakdown line render on single lines, no wrapping or clipping.
- ISC-5 — FM2: the fill does not protrude outside the pill boundary at very small pressure (<5%) — the ZStack stays clipped to the rounded rectangle.
- ISC-6 — FM3: accessibility unchanged — both bars keep `.accessibilityHidden(true)`; the header summary string is untouched.
- ISC-7 — `xcodebuild test` passes, including `StatsLiteTests/MenuBarRenderSnapshotTests` with no baseline updates (suite renders menu bar items only, no popover views).
- VAC-1 — Gauge height parity: gauge renders at 6 pt, identical to composition bar. (375/768/1440-equivalent: popover width is fixed 280 pt, so verify at 1x and 2x display scale.)
- VAC-2 — Shared token binding: both bars read `CGFloat.metricBarHeight`.
- VAC-3 — Subtle track color: unfilled track uses `Color.metricBarTrack`.
- VAC-4 — Dark appearance: track reads as a quiet indentation, no milky ghost bar.
- VAC-5 — Light appearance: track reads without a heavy dark gray stripe.
- VAC-6 — Corner radius: 3 pt continuous on both bars, exact half-height pill.
- VAC-7 — Fill clipping integrity at small pressure.
- VAC-8 — Zero text wrapping regression.
- VAC-9 — VoiceOver: `.accessibilityHidden(true)` retained on both bars.
- VAC-10 — Snapshot test immunity: `MenuBarRenderSnapshotTests` passes unchanged.

## Design Blueprint (designer, verbatim)

### Executive Summary

This blueprint specifies the visual fix for the memory pressure gauge bar in the macOS popover panel.
The memory pressure gauge bar currently measures 8 pt in height.
It looks noticeably thicker than the 6 pt Used memory composition bar located in the same card.
Its unfilled track fill (`Color(nsColor: .separatorColor).opacity(0.2)`) renders as a prominent, chalky gray bar that distracts from the card data.

This blueprint establishes two design adjustments:
1. Reduce the memory pressure gauge bar frame height from 8 pt to 6 pt to match the Used memory composition bar.
2. Replace the unfilled track color with a new semantic design token, `Color.metricBarTrack` (`Color(nsColor: .separatorColor).opacity(0.08)`), which blends into the card background.

### 1. Visual Hierarchy & ASCII Wireframe

Visual evidence:
- Dark baseline: `artifacts/2026-10-26-popover-storage-shortcut/dark.png`
- Light baseline: `artifacts/2026-10-26-popover-storage-shortcut/light.png`

```
CURRENT STATE (Memory Card interior width = 240 pt)
| [icon] Memory Pressure                                          [Normal] |
| [====================                                                  ] | (8 pt gauge: state.levelColor)
| [....................--------------------------------------------------] | (Track: separatorColor * 0.2 -> PROMINENT)
| ~~~~~ Sparkline (38 pt) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |
| -1m                                                                  Now |
| Used: 70% (25.1 / 36.0 GB)                                               |
| [=========][====][==][-------------------------------------------------] | (6 pt composition bar)
| App: 20.2G · Wired: 4.1G · Comp: 0.9G                                    |
| > Top Processes                                                          |

TARGET STATE (Memory Card interior width = 240 pt)
| [icon] Memory Pressure                                          [Normal] |
| [====================                                                  ] | (6 pt gauge: state.levelColor)
| [                    ..................................................] | (Track: Color.metricBarTrack -> SUBTLE)
| ~~~~~ Sparkline (38 pt) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |
| -1m                                                                  Now |
| Used: 70% (25.1 / 36.0 GB)                                               |
| [=========][====][==][-------------------------------------------------] | (6 pt composition bar)
| App: 20.2G · Wired: 4.1G · Comp: 0.9G                                    |
| > Top Processes                                                          |
```

Layout bounds:
1. Popover panel width fixed at 280 pt (`PopoverContentView.swift:113`).
2. Popover horizontal padding 10 pt each side (`PopoverContentView.swift:107`). Outer card 260 pt.
3. Metric card internal padding 10 pt each side (`DesignTokens.swift:45`). Inner content 240 pt.
4. Vertical spacing `VStack(alignment: .leading, spacing: 4)` (`MemoryPressureCardView.swift:23`).
5. Gauge spans 100% of inner width (240 pt). Fill width is `240 * fraction` pt.

### 2. Template / Component Skeleton

2.1 Design tokens (`StatsLite/DesignTokens.swift`):

```swift
// MARK: - Metric Popover Bar Tokens

extension CGFloat {
    /// Standard height for metric popover bars (memory pressure gauge and used memory composition bar).
    static let metricBarHeight: CGFloat = 6

    /// Corner radius for standard 6 pt metric popover bars.
    static let metricBarCornerRadius: CGFloat = 3
}

extension Color {
    /// Subtle track color for metric gauges and progress bars in popover cards.
    /// Blends into the card background across both dark and light appearances.
    static let metricBarTrack = Color(nsColor: .separatorColor).opacity(0.08)
}
```

2.2 Memory pressure card (`StatsLite/MemoryPressureCardView.swift`):

```swift
    // MARK: - Pressure gauge (VAC-1): 6 pt bar, continuous 3 pt radius

    private var gaugeBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: .metricBarCornerRadius, style: .continuous)
                    .fill(Color.metricBarTrack)
                RoundedRectangle(cornerRadius: .metricBarCornerRadius, style: .continuous)
                    .fill(state.levelColor)
                    .frame(width: max(proxy.size.width * fraction, 0))
            }
            .clipShape(RoundedRectangle(cornerRadius: .metricBarCornerRadius, style: .continuous))
        }
        .frame(height: .metricBarHeight)
    }

    // MARK: - Composition bar (VAC-2): App blue, Wired purple,
    // Compressed orange, Free quaternary, 6 pt in a 3 pt container.

    private var compositionBar: some View {
        GeometryReader { proxy in
            let total = max(Double(memory?.totalBytes ?? 0), 1)
            let width = proxy.size.width
            HStack(spacing: 1) {
                segment(.blue, width: width * Double(memory?.appMemoryBytes ?? 0) / total)
                segment(.purple, width: width * Double(memory?.wiredBytes ?? 0) / total)
                segment(.orange, width: width * Double(memory?.compressedBytes ?? 0) / total)
                Rectangle()
                    .fill(Color(nsColor: .quaternaryLabelColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: .metricBarCornerRadius, style: .continuous))
        }
        .frame(height: .metricBarHeight)
    }
```

### 3. State & Appearance Matrix

| Pressure State | Level | Fill Color | Track Token |
| :--- | :--- | :--- | :--- |
| Normal (<60%) | 1 | `state.levelColor` (systemGreen) | `Color.metricBarTrack` |
| Warning (60–80%) | 2 | `state.levelColor` (systemYellow) | `Color.metricBarTrack` |
| Critical (>80%) | 4 | `state.levelColor` (systemRed) | `Color.metricBarTrack` |
| Unknown / Nil | 0 | `state.levelColor` (systemGray) | `Color.metricBarTrack` |

| Mode | Card Surface | Former Track (0.2) | New Track (0.08) | Result |
| :--- | :--- | :--- | :--- | :--- |
| Dark | `controlBackgroundColor` (0.65) over `.regularMaterial` | ~5.0% white wash | ~2.0% white wash | Recedes into card surface |
| Light | `controlBackgroundColor` (0.65) over `.regularMaterial` | ~3.0% black tint | ~1.2% black tint | Soft guide, no gray line |
| Increase Contrast | Elevated material | Dynamic separator elevation | Dynamic separator elevation | Track stays perceptible |

Display scaling: popover width fixed at 280 pt, card content 240 pt. Bar frame 6.0 pt and radius 3.0 pt at 1x and 2x — 6 or 12 physical pixels. No reflow.

### 4. Accessibility

- Gauge bar has `.accessibilityHidden(true)` (`MemoryPressureCardView.swift:44`).
- Composition bar has `.accessibilityHidden(true)` (`MemoryPressureCardView.swift:52`).
- Card header carries the single authoritative announcement string (`MemoryPressureCardView.swift:171`). Untouched.
- WCAG 2.2 SC 1.4.11: active fill uses system colors above 3.0:1 contrast; the empty track is an inactive decorative boundary with textual label and badge carrying state.
- WCAG 2.2 SC 2.5.8: the gauge is an output indicator, not a control. Header buttons keep 24x24 pt targets.

### 5. Component Impact, Risks, Test Impact

1. `DesignTokens.swift`: adds the three tokens above.
2. `MemoryPressureCardView.swift`: gauge height 8 → `.metricBarHeight`; track → `Color.metricBarTrack`; clip ZStack to rounded rect; composition bar switches to shared tokens.
3. Drift prevention: both bars read `CGFloat.metricBarHeight`, so heights cannot diverge again.
4. Spacing: card height contracts 2 pt. Popover uses `.fixedSize(horizontal: true, vertical: true)` and absorbs it with no clipping. Card `spacing: 4` unchanged; no horizontal shifts.
5. `StatsLiteTests/MenuBarRenderSnapshotTests.swift`: renders `MenuBarStackedItemView` via `MenuBarRenderHarness` only — zero popover views, no baseline updates.
6. `ProcessDisclosureTests.swift` and `SparklineTimeAxisGuardTests.swift`: pass unchanged.
7. Live popover baselines (`scripts/capture_baseline.sh`) will reflect the 6 pt bar and subtle track.
8. AGENTS.md rules apply: `popover.animates = false` stays; run popover tools with the display awake (wrap in `caffeinate`) because popover close is display-sleep-sensitive.

## Approach

- One coder implements the Blueprint in one worktree on branch `popover-metric-bar-height-track`.
- TDD: red phase writes source-token and geometry guard tests (repo precedent: `ProcessDisclosureTests` asserts source tokens), green phase implements.
- Verification: `xcodebuild test` on a single booted simulator-free macOS destination, plus light/dark baseline screenshots via `scripts/capture_baseline.sh` (display awake, caffeinate).
- Then reviewer `[code-review]`, merge `--ff-only` or `--squash` into `main`.

## Refactors

None beyond the Blueprint: both bars adopt the shared `metricBarHeight` token so the height duplication that caused this drift is removed.

## Tasks

- [x] **T1** — Red: failing tests for ISC-1/2/3 (token presence, shared usage, no legacy literals) and VAC-9 accessibility retention. red `bc6c291` · green — · review PASS (code review)
- [x] **T2** — Green: implement tokens + gauge/composition bar updates per Blueprint; refactor to shared tokens. red `bc6c291` · green `7350803` · review GO
- [x] **T3** — Verify: run full test suite (508 passed / 0 failed), capture dark/light baselines (artifacts/2026-10-27-memory-pressure-bar-thinner-subtle-track, commit `4e5c3df`), confirm VAC-1..VAC-10 all PASS. red — · green — · review PASS (tester verdict: PASS)
- [x] **T4** — Reviewer `[code-review]`, merge to main, update DESIGN.md with the shared metric-bar token rule. red — · green — · review GO · merged `4e5c3df` (ff-only)
- [ ] **T5** — Retarget `Color.metricBarTrack` to `Color(nsColor: .quaternaryLabelColor)` (same gray as the Used memory bar Free segment), update the guard test and DESIGN.md, re-verify, redeploy. red ⏳ · green ⏳ · review ⏳
