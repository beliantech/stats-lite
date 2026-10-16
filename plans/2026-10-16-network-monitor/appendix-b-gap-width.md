# Appendix B — Design Fix Blueprint: Narrowing Network Block Dot-to-Text Gap (designer, 2026-10-16, verbatim)

## Executive Summary and Root Cause Analysis

### User Defect Report
> *"Can we somehow narrow the gap between dots and words? I know it is to leave space for the worst case but in the worst case just truncate the decimals to accommodate narrower space."*

### Root Cause Diagnosis
1. **Unnecessary Width Reservation**: `MenuBarLayout.networkBlockWidth` (`StatsLite/MenuBarBlockModel.swift:46`) was pinned to `58 pt`, sized to fit `99.9 MB/s` with arbitrary padding.
2. **SwiftUI Implicit `HStack` Spacing Defect**: in `StatsLite/MenuBarStackedItemView.swift:149-169` the row is `HStack(alignment: .center, spacing: 3)` with `Circle()`, `Spacer(minLength: 2)`, `Text()`. `HStack(spacing: 3)` inserts 3 pt between child 1–2 and another 3 pt between child 2–3, so the minimum gap was `3 + 2 + 3 = 8 pt`.
3. **Compound Gap on Low / Typical Traffic**: at 58 pt the gap for `10 KB/s` (text 35.06 pt) is 16.94 pt and for `0 KB/s` (29.08 pt) is 22.92 pt — dots look disconnected from their values.
4. **Current Ellipsis Bug on Production**: `6 pt (dot) + 8 pt (gap) + 45.92 pt (99.9 MB/s) = 59.92 pt > 58 pt`, so `99.9 MB/s` already clips to `99.9 M...` (visual proof `/tmp/test_999mb.png`).

## Visual Evidence Pass

- Layout matrix & gap comparison: `/tmp/matrix_comparison.png` (58, 52, 51, 50 pt and adjacent layout across 5 rate pairs).
- Current truncation defect: `/tmp/test_999mb.png`.
- Worst-case 50 pt clearance: `/tmp/render_w50_s0_m1_999_MB_s.png`.
- Shortest string 50 pt gap: `/tmp/render_w50_s0_m1_10_KB_s.png` (8.94 pt gap).
- 51 pt clearance: `/tmp/render_w51_s0_m2_999_MB_s.png` (2.09 pt), 52 pt: `/tmp/render_w52_s0_m2_999_MB_s.png` (3.09 pt).

## 1. Text Width Measurements & Minimum Safe Pinned Block Width

Font token `.system(size: 9, weight: .medium).monospacedDigit()`:
monospaced digits **5.9729 pt**, `.` **3.0065 pt**, space **2.6209 pt**, `/` **3.0075 pt**,
`" KB/s"` **23.1114 pt**, `" MB/s"` **24.9898 pt**, `" GB/s"` **23.7808 pt**.

| Candidate String | Text Width (pt) | 1x ceil px | 2x ceil px | Status under Truncation |
|---|---|---|---|---|
| `0 KB/s` | 29.0843 | 30 | 59 | Low-traffic idle |
| `10 KB/s` | 35.0572 | 36 | 71 | Typical upload |
| `720 KB/s` | 41.0301 | 42 | 83 | Reference download |
| `999 KB/s` | 41.0301 | 42 | 83 | Maximum KB string |
| `1.0 MB/s` | 39.9420 | 40 | 80 | Minimum MB string |
| `9.9 MB/s` | 39.9420 | 40 | 80 | Maximum 1-decimal MB |
| `10 MB/s` | 36.9356 | 37 | 74 | Truncated from `10.0 MB/s` |
| `95 MB/s` | 36.9356 | 37 | 74 | Truncated from `94.9 MB/s` |
| `99.9 MB/s` | 45.9150 | 46 | 92 | **Former worst case (now truncated)** |
| `100 MB/s` | 42.9085 | 43 | 86 | Truncated from `99.9 MB/s` |
| `119 MB/s` | 42.9085 | 43 | 86 | Integer MB |
| `999 MB/s` | 42.9085 | 43 | 86 | **New absolute worst case** |
| `1.0 GB/s` | 38.7330 | 39 | 78 | Minimum GB string |
| `1.2 GB/s` | 38.7330 | 39 | 78 | Reference gigabit string |
| `10 GB/s` | 35.7266 | 36 | 72 | Truncated from `10.0 GB/s` |
| `-- KB/s` | 32.0194 | 33 | 65 | Unavailable fallback |

### Safe Pinned Block Width Analysis

Widest string after truncation: `999 MB/s` = **42.9085 pt**; dot 6.0 pt → combined 48.9085 pt.

- **Absolute Minimum Safe Width: 50.0 pt** — clearance 1.09 pt for `999 MB/s`, fits `Spacer(minLength: 1)`, 8 pt narrower than 58 pt, keeps totals even (168 / 54 / 92).
- Standard `Spacer(minLength: 2)`: 51.0 pt (clearance 2.09 pt).
- Conservative 3 pt HStack spacing: 52.0 pt (clearance 3.09 pt).

**Design Decision**: select **50.0 pt** as the canonical pinned width (`MenuBarLayout.networkBlockWidth = 50`). Maximum requested gap reduction, even layout constants, `999 MB/s` fits without clipping.

## 2. Revised Row Layout & Alignment Strategy

**Layout Decision: Trailing-Pinned (Spacer survives). Rate text must NOT move adjacent to the dot.**

Justification: (1) reference image parity — rightmost glyphs of both lines share one trailing boundary and the units stack; (2) adjacent layout causes trailing-edge jitter — in `/tmp/matrix_comparison.png` `10 KB/s` ends 6.0 pt left of `720 KB/s` and jumps every 1 s tick; (3) a single container trailing modifier would break leading dot alignment (VAC-3); (4) the user explicitly asked for space reservation to be recovered via decimal truncation.

Exact row configuration:
- Outer: `VStack(alignment: .leading, spacing: 1)` with `.frame(width: block.width)` (`50 pt`).
- Row: `HStack(alignment: .center, spacing: 0)` — removes the duplicate implicit 3 pt gaps.
- Dot: `Circle().frame(width: 6, height: 6)`.
- Flexible spacer: `Spacer(minLength: 1)`.
- Text: `Text(...).font(.system(size: 9, weight: .medium).monospacedDigit().lineLimit(1)`.

Dot-to-text gap for the shortest string `10 KB/s` (35.0572 pt): 58 pt → 16.94 pt; **50 pt → 8.94 pt** (−8 pt, −47.2%). `0 KB/s`: 22.92 → 14.92 pt. `720 KB/s`: 10.97 → 2.97 pt.

## 3. Revised `networkRate` Truncation Rules

Decimals are dropped once values enter double digits (≥ 9.95 in each unit).

| Condition | Output examples | Width (pt) | Clearance in 50 pt |
|---|---|---|---|
| Missing / non-finite / negative | `-- KB/s` | 32.02 | 11.98 |
| `0 ≤ rate`, `kb.rounded() < 1000` | `0 KB/s`, `10 KB/s`, `720 KB/s`, `999 KB/s` | ≤ 41.03 | ≥ 2.97 |
| `mb < 9.95` | `1.0 MB/s`, `1.6 MB/s`, `9.9 MB/s` | 39.94 | 4.06 |
| `mb ≥ 9.95`, `mb.rounded() < 1000` | `10 MB/s`, `95 MB/s`, `100 MB/s`, `119 MB/s`, `999 MB/s` | ≤ 42.91 | ≥ 1.09 |
| `gb < 9.95` | `1.0 GB/s`, `1.2 GB/s`, `9.9 GB/s` | 38.73 | 5.27 |
| `gb ≥ 9.95` | `10 GB/s`, `99 GB/s`, `100 GB/s` | ≤ 41.70 | ≥ 2.30 |

Rounding edge-case protection: `999.5 KB/s` → `1.0 MB/s` (never `1000 KB/s`, 47.00 pt); `9.95 MB/s` → `10 MB/s` (never `10.0 MB/s`, 45.92 pt); `999.5 MB/s` → `1.0 GB/s` (never `1000 MB/s`, 48.88 pt); `9.95 GB/s` → `10 GB/s` (never `10.0 GB/s`).

```swift
static func networkRate(_ bytesPerSecond: Double?) -> String {
    guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond >= 0 else {
        return "-- KB/s"
    }
    let kb = bytesPerSecond / 1024.0
    if kb.rounded() < 1000.0 {
        return "\(Int(kb.rounded())) KB/s"
    }
    let mb = kb / 1024.0
    if mb < 9.95 {
        return String(format: "%.1f MB/s", mb)
    }
    if mb.rounded() < 1000.0 {
        return "\(Int(mb.rounded())) MB/s"
    }
    let gb = mb / 1024.0
    if gb < 9.95 {
        return String(format: "%.1f GB/s", gb)
    }
    return "\(Int(gb.rounded())) GB/s"
}
```

## 4. The 5-Part Design Blueprint

### Part 1 — Visual Hierarchy & ASCII Wireframe

```
+-----------------------------------------------------------------------+
| macOS Menu Bar (Height: 24 pt)                                        |
|                                                                       |
| [CPU Block] [MEM Block] [GPU Block]   [Network Block]                 |
|   (34 pt)     (34 pt)     (34 pt)         (50 pt)                     |
|    gap:4       gap:4       gap:4                                      |
|                                                                       |
|                                      +------------------------------+ |
|                               Row 1: | (R)   Spacer(min:1) 720 KB/s | |
|                                      |                              | |
|                               Row 2: | (B)   Spacer(min:1)  10 KB/s | |
|                                      +------------------------------+ |
|                                       <---------- 50 pt ----------->  |
+-----------------------------------------------------------------------+

Spatial Invariants:
- Leading edge: both dots align at x = 0 pt.
- Trailing edge: both rate strings align at x = 50 pt.
- Gap behavior: 999 MB/s → 1.09 pt; 720 KB/s → 2.97 pt; 10 KB/s → 8.94 pt; -- KB/s → 11.98 pt.
```

(The wireframe's row labels follow round 0 roles; appendix A governs which rate sits on which row.)

### Part 2 — Component Skeleton

```swift
struct MenuBarNetworkBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .center, spacing: 0) {
                Circle().fill(Color(nsColor: .systemRed)).frame(width: 6, height: 6)
                Spacer(minLength: 1)
                Text(block.valueText)
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
            }
            HStack(alignment: .center, spacing: 0) {
                Circle().fill(Color(nsColor: .systemBlue)).frame(width: 6, height: 6)
                Spacer(minLength: 1)
                Text(block.secondaryValueText ?? "-- KB/s")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(secondaryValueColor)
                    .lineLimit(1)
            }
        }
        .frame(width: block.width)
    }
    // valueColor / secondaryValueColor unchanged from round 0
}

enum MenuBarLayout {
    static let blockWidth: CGFloat = 34
    static let networkBlockWidth: CGFloat = 50
    static let gap: CGFloat = 4
    static let padding: CGFloat = 2
    // length(showCPU:showRAM:showGPU:showNetwork:) arithmetic unchanged
}
```

### Part 3 — Complete State & Responsive Matrix

| UI State | Top Dot | Top Text | Bottom Dot | Bottom Text | Width | Gap top / bottom |
|---|---|---|---|---|---|---|
| Active traffic (typical) | Red 6 pt | `.primary` e.g. `720 KB/s` | Blue 6 pt | `.primary` e.g. `10 KB/s` | 50 pt | 2.97 / 8.94 |
| Idle | Red | `0 KB/s` | Blue | `0 KB/s` | 50 pt | 14.92 / 14.92 |
| Sub-10 MB/s | Red | `1.6 MB/s` | Blue | `22 KB/s` | 50 pt | 4.06 / 8.94 |
| Double-digit MB/s (truncated) | Red | `95 MB/s` | Blue | `10 KB/s` | 50 pt | 7.06 / 8.94 |
| Gigabit (truncated) | Red | `1.2 GB/s` | Blue | `10 MB/s` | 50 pt | 5.27 / 7.06 |
| Worst case | Red | `999 MB/s` | Blue | `0 KB/s` | 50 pt | 1.09 / 14.92 |
| Unavailable | Red | `.tertiaryLabelColor` `-- KB/s` | Blue | same | 50 pt | 11.98 / 11.98 |
| Popover open / highlight | unchanged | selection contrast | unchanged | selection contrast | 50 pt | identical |

### Part 4 — Accessibility & Interaction

- Contrast: text ≥ 4.5:1, dots > 4.2:1.
- VoiceOver: unchanged by this appendix — **appendix A governs the label**.
- Zero content transition: no `.animation` / `.contentTransition` (`AGENTS.md`).

### Part 5 — Visual Acceptance Delta Checklist

- **VAC-B1 (replaces VAC-2)**: block pins to exactly `50 pt`; no width change across `0 KB/s`, `10 KB/s`, `720 KB/s`, `1.6 MB/s`, `95 MB/s`, `100 MB/s`, `999 MB/s`, `1.2 GB/s`, `-- KB/s`.
- **VAC-B2 (replaces VAC-6)**: both rows trailing-pinned via `Spacer(minLength: 1)` inside `HStack(spacing: 0)`; rightmost glyphs align with 0 pt delta; text never sits adjacent to the dot.
- **VAC-B3 (replaces VAC-7)**: thresholds per §3; no produced string exceeds 42.91 pt.
- **VAC-B4 (replaces VAC-11)**: all four = `2*2 + 3*34 + 50 + 3*4 = 168`; network only = `2*2 + 50 = 54`; CPU + network = `2*2 + 34 + 50 + 4 = 92`; network off = `114` unchanged.
- **VAC-B5 (replaces FM9)**: item width strictly constant across all rate updates; no ellipsis.

## 6. Layout Totals & Required Test Updates

| Configuration | Before (58 pt) | After (50 pt) | Delta |
|---|---|---|---|
| All 4 metrics | 176 pt | **168 pt** | −8 |
| Network only | 62 pt | **54 pt** | −8 |
| CPU + Network | 100 pt | **92 pt** | −8 |
| Network off (CPU+RAM+GPU) | 114 pt | **114 pt** | unchanged |

Tests to update:
1. `StatsLiteTests/MenuBarLayoutTests.swift:78-80` `networkBlockWidth == 50`; `:82-93` total `168`; `:95-105` network-only `54`; `:107-118` CPU+network `92`; 114 case unchanged.
2. `StatsLiteTests/MenuBarBlockBuilderTests.swift:351` and `:367` width `58` → `50`.
3. `StatsLiteTests/MetricFormatterTests.swift` — `testNetworkRateFormatsMBRange`: `94.9 MB/s` now expects `95 MB/s`; add boundaries `9.94 → 9.9 MB/s`, `9.95 → 10 MB/s`, `99.9 → 100 MB/s`, `999.4 → 999 MB/s`, `999.5 → 1.0 GB/s`, `9.95 GB/s → 10 GB/s`.

## 7. What Does NOT Change

1. Dot geometry 6.0 pt; 2. dot colors (roles per appendix A); 3. typography 9 pt medium monospacedDigit; 4. tint rules (`.primary` active, `tertiaryLabelColor` missing); 5. two-row `VStack(spacing: 1)` structure; 6. zero-animation contract; 7. VoiceOver strings (appendix A governs); 8. 1 s cadence and sampler architecture; 9. CPU/RAM/GPU blocks (34 pt, gap 4, padding 2, network-off total 114 pt).
