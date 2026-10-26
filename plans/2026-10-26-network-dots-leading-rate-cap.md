# Plan: Menu Bar Network Dots Back to Leading, Tighter Gap, 2-Digit Rate Cap

Plan name: `2026-10-26-network-dots-leading-rate-cap`
Date: 2026-10-26
Risk class: **R2** (UI work — menu bar layout + shared formatter change; verified through offscreen render tests per AGENTS.md).

## User request (verbatim)

> 1. revert the recent change that swapped the network red/blue dots to the right
> 2. reduce the gap between the dots and the values, KB/s or MB/s is always flush right, but at most 2 digits, e.g. no more 400KB/s, it becomes 0.4MB/s

## Intent

Commit `ec087f0` moved each menu-bar network row from `Circle → Spacer → Text` to
`Text → Spacer → Circle`. The user wants the dots back on the leading (left) edge.
With the dots leading, the pinned network block width shrinks from 50 pt to 47 pt so
the dot-to-text gap tightens by 3 pt, and the rate formatter switches units at 100 so
no rate shows more than two mantissa digits (400 KB/s renders `0.4 MB/s`). Rate text
stays flush right in both rows. The formatter is shared with the popover network card,
which adopts the same 2-digit format (one source of truth — intended).

## Design Blueprint (designer, 2026-10-26 — verbatim)

# Design Blueprint: Revert Menu Bar Network Dots to Leading, Tighten Gap, and Cap Rate Mantissa at 2 Digits

## Overview & Scope Confirmation

This blueprint restores the menu bar network monitor block (`MenuBarNetworkBlockView`) to its canonical leading-dot geometry while solving the visual whitespace issue reported by the user.

1. **Revert dot position**: Each network row reverts from trailing (`Text → Spacer → Circle`) back to leading (`Circle → Spacer → Text`).
2. **Right-aligned values**: Rate text remains right-aligned (flush right) inside the block. The `Spacer(minLength: 1)` pushes the text to the trailing edge.
3. **Reduced dot-to-text gap**: The pinned block width `MenuBarLayout.networkBlockWidth` decreases from `50.0 pt` to **`47.0 pt`**. Under the new rate mantissa cap, the widest possible string shrinks from `42.11 pt` ("999 MB/s") to `39.11 pt` ("0.4 MB/s" or "9.9 MB/s"). At `47.0 pt`, total clearance is `2.89 pt`, which satisfies the repository rule of `≥ 2.5 pt` clearance. The dot-to-text gap shrinks by `3.0 pt` (6 bitmap pixels at 2x) across all traffic conditions.
4. **Cap rate mantissa at 2 digits**: `MetricFormatters.networkRate` transitions to the next unit whenever the rounded value reaches 100. Values from 100 KB/s to 999 KB/s render as fractional MB/s (for example, 400 KB/s renders as `"0.4 MB/s"`). Values from 100 MB/s to 999 MB/s render as fractional GB/s (for example, 400 MB/s renders as `"0.4 GB/s"`). Integer rates only render while the rounded value stays under 100.
5. **Shared popover parity**: `MetricFormatters.networkRate` is the single source of truth for both the menu bar and the popover `NetworkCardView`. The popover card automatically adopts the 2-digit rate format.

---

## 1. Visual Hierarchy & ASCII Wireframe

### Menu Bar Stack: TEMP Block Adjacent to Network Block (47 pt Pinned Width)

```
+-----------------------------------------------------------------------------------------------+
|  CPU     GPU     MEM      [C   84°]  (gap 4 pt)  [ (red)       0.4 MB/s ]                     |
|  14%     32%     45%      [G   61°]  (21 px ink) [ (cyan/blue) 1.2 MB/s ]                     |
+-----------------------------------------------------------------------------------------------+
|<-- 27 pt -><- 27 -><- 27 -><-- 36 pt -->          <------- 47.0 pt ------->|
```

### Detailed Row Anatomy (`MenuBarNetworkBlockView`, 47 pt x 22 pt)

```
0.0 pt                                                                     47.0 pt
+-------------------------------------------------------------------------------+
| (●) Upload Dot [5 pt]  <--------- Spacer --------->  [ 0.4 MB/s ] (flush right)
|   Circle(Color.networkUpload)                          9 pt regular mono digit|
+-------------------------------------------------------------------------------+ Line 1 (11 pt)
| (●) Download Dot [5 pt] <-------- Spacer --------->  [ 1.2 MB/s ] (flush right)
|   Circle(Color.networkDownload)                        9 pt regular mono digit|
+-------------------------------------------------------------------------------+ Line 2 (11 pt)
|<-- 5.0 pt -->|         |<-- min 2.89 pt clearance ->|<------ max 39.11 pt ---->|
```

### Visual Evidence Reference Captures

Visual captures were generated offscreen at 2x Retina scale using the repository render pipeline and inspected directly:
- **Baseline Trailing Dots (Pre-Revert)**: `/tmp/designer/current_trailing_w50_dark.png` (shows dots on the right at 50 pt).
- **Leading Dots at Old 50 pt Width**: `/tmp/designer/revert_w50_dark.png` (shows wide whitespace between leading dots and values).
- **Leading Dots at New 47 pt Width (Target)**: `/tmp/designer/revert_w47_dark.png` (shows tight, balanced gap with leading dots and "0.4 MB/s").
- **Light Mode Target (`aqua`)**: `/tmp/designer/revert_w47_light.png` (shows dark text and systemBlue adaptive download dot).
- **Low Traffic State**: `/tmp/designer/net_low_traffic_dark.png` (shows "0 KB/s" / "10 KB/s" with dots leading).
- **High Traffic State**: `/tmp/designer/net_high_traffic_dark.png` (shows widest "9.9 MB/s" / "99 MB/s" with comfortable 6 px gutter).
- **Missing / Unavailable State**: `/tmp/designer/net_missing_dark.png` (shows "-- KB/s" placeholder with tertiary styling).
- **TEMP + NET Pair Adjacency**: `/tmp/designer/temp_net_pair_dark.png` and `/tmp/designer/temp_net_pair_light.png` (shows the restored 21 px ink gap and optical vertical alignment between TEMP labels and network dots).

---

## 2. Template / Component Skeleton

### A. View Component: `StatsLite/MenuBarStackedItemView.swift`

```swift
/// Dedicated two-line network speed monitor block:
/// line 1 carries a 5 pt red indicator dot (Color.networkUpload) and
/// the upload rate.
/// line 2 carries a 5 pt adaptive indicator dot
/// (Color.networkDownload: systemCyan in dark mode, systemBlue in
/// light) and the download rate.
/// Width pins to block.width (47 pt), so rate string changes never
/// resize the item. Transitions stay discrete: no
/// .animation and no .contentTransition modifiers.
struct MenuBarNetworkBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Line 1: Upload rate
            HStack(alignment: .center, spacing: 0) {
                Circle()
                    .fill(Color.networkUpload)
                    .frame(width: CGFloat.networkDotSize, height: CGFloat.networkDotSize)

                Spacer(minLength: 1)

                Text(block.valueText)
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
            }
            .frame(height: MenuBarLayout.rowHeight)

            // Line 2: Download rate
            HStack(alignment: .center, spacing: 0) {
                Circle()
                    .fill(Color.networkDownload)
                    .frame(width: CGFloat.networkDotSize, height: CGFloat.networkDotSize)

                Spacer(minLength: 1)

                Text(block.secondaryValueText ?? "-- KB/s")
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(secondaryValueColor)
                    .lineLimit(1)
            }
            .frame(height: MenuBarLayout.rowHeight)
        }
        .frame(width: block.width)
    }

    private var valueColor: Color {
        switch block.valueTint {
        case .primary, .warning, .critical:
            Color.primary
        case .tertiary:
            Color(nsColor: .tertiaryLabelColor)
        }
    }

    private var secondaryValueColor: Color {
        switch block.secondaryValueTint ?? block.valueTint {
        case .primary, .warning, .critical:
            Color.primary
        case .tertiary:
            Color(nsColor: .tertiaryLabelColor)
        }
    }
}
```

### B. Shared Layout Constant: `StatsLite/MenuBarBlockModel.swift`

```swift
enum MenuBarLayout {
    // ...
    /// Pinned width of the two-line network block. Fits the widest
    /// rate string "0.4 MB/s" or "9.9 MB/s" (39.11 pt) plus the 5 pt dot
    /// with 2.89 pt clearance, satisfying the >= 2.5 pt rule.
    static let networkBlockWidth: CGFloat = 47
    // ...
}
```

### C. Rate Formatter: `StatsLite/MetricFormatters.swift`

```swift
    /// Formats a transfer rate in bytes per second:
    /// integer KB/s while the rounded value stays under 100 KB/s;
    /// one-decimal MB/s below 9.95 MB/s; integer MB/s while the
    /// rounded value stays under 100 MB/s; one-decimal GB/s below
    /// 9.95 GB/s; integer GB/s while the rounded value stays under 100 GB/s;
    /// clamps at 99 GB/s. Decimals drop once values reach double digits,
    /// and rates transition to the next unit at 100, so no output mantissa
    /// exceeds two digits (e.g. 400 KB/s becomes "0.4 MB/s"). Returns
    /// "-- KB/s" for a missing, negative, or non-finite value.
    static func networkRate(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond >= 0 else {
            return "-- KB/s"
        }
        let kb = bytesPerSecond / 1024.0
        if kb.rounded() < 100.0 {
            return "\(Int(kb.rounded())) KB/s"
        }
        let mb = kb / 1024.0
        if mb < 9.95 {
            return String(format: "%.1f MB/s", mb)
        }
        if mb.rounded() < 100.0 {
            return "\(Int(mb.rounded())) MB/s"
        }
        let gb = mb / 1024.0
        if gb < 9.95 {
            return String(format: "%.1f GB/s", gb)
        }
        if gb.rounded() < 100.0 {
            return "\(Int(gb.rounded())) GB/s"
        }
        return "99 GB/s"
    }
```

---

## 3. Complete State & Responsive Matrix

### Rate String Widths & Clearance Budget (Pinned Frame: 47.0 pt, Dot: 5.0 pt)

All text widths measured with `NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)`:

| Traffic Range | Formatter Output | Text Width | Dot Size | Available Clearance (`47.0 - 5.0 - text`) | Clearance Rule (`≥ 2.5 pt`) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Zero / Idle | `"0 KB/s"` | `28.50 pt` | `5.0 pt` | `13.50 pt` (27 px at 2x) | Pass |
| Missing / Error | `"-- KB/s"` | `31.49 pt` | `5.0 pt` | `10.51 pt` (21 px at 2x) | Pass |
| Double-digit KB/s | `"99 KB/s"` | `34.33 pt` | `5.0 pt` | `7.67 pt` (15 px at 2x) | Pass |
| Fractional MB/s (Low) | `"0.1 MB/s"` | `39.11 pt` | `5.0 pt` | **`2.89 pt`** (6 px at 2x) | **Pass (Floor)** |
| 400 KB/s Example | `"0.4 MB/s"` | `39.11 pt` | `5.0 pt` | **`2.89 pt`** (6 px at 2x) | **Pass (Floor)** |
| Fractional MB/s (High) | `"9.9 MB/s"` | `39.11 pt` | `5.0 pt` | **`2.89 pt`** (6 px at 2x) | **Pass (Floor)** |
| Double-digit MB/s | `"10 MB/s"` | `36.27 pt` | `5.0 pt` | `5.73 pt` (11 px at 2x) | Pass |
| Double-digit MB/s | `"99 MB/s"` | `36.27 pt` | `5.0 pt` | `5.73 pt` (11 px at 2x) | Pass |
| Fractional GB/s | `"0.4 GB/s"` | `37.96 pt` | `5.0 pt` | `4.04 pt` (8 px at 2x) | Pass |
| Fractional GB/s | `"9.9 GB/s"` | `37.96 pt` | `5.0 pt` | `4.04 pt` (8 px at 2x) | Pass |
| Double-digit GB/s | `"10 GB/s"` | `35.13 pt` | `5.0 pt` | `6.87 pt` (14 px at 2x) | Pass |
| Clamped Ceiling | `"99 GB/s"` | `35.13 pt` | `5.0 pt` | `6.87 pt` (14 px at 2x) | Pass |

### State & Appearance Matrix

| State | Line 1 (Upload) | Line 2 (Download) | Appearance | Dot Color | Value Color |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Normal Traffic (Dark)** | Dot + Rate (e.g. `"0.4 MB/s"`) | Dot + Rate (e.g. `"1.2 MB/s"`) | `darkAqua` | Line 1: `Color.networkUpload` (`.systemRed`)<br>Line 2: `Color.networkDownload` (`.systemCyan`) | `.primary` (white text) |
| **Normal Traffic (Light)** | Dot + Rate (e.g. `"0.4 MB/s"`) | Dot + Rate (e.g. `"1.2 MB/s"`) | `aqua` | Line 1: `Color.networkUpload` (`.systemRed`)<br>Line 2: `Color.networkDownload` (`.systemBlue`) | `.primary` (black text) |
| **Idle / Zero Traffic** | Dot + `"0 KB/s"` | Dot + `"0 KB/s"` | Both | Standard dot tokens | `.primary` |
| **Unavailable / Nil** | Dot + `"-- KB/s"` | Dot + `"-- KB/s"` | Both | Standard dot tokens | `Color(nsColor: .tertiaryLabelColor)` |
| **Rate Spike (≥ 100 GB/s)** | Dot + `"99 GB/s"` | Dot + `"99 GB/s"` | Both | Standard dot tokens | `.primary` |

---

## 4. Accessibility (WCAG 2.2) & Interaction Contracts

### WCAG 2.2 Compliance
1. **Color Contrast (SC 1.4.3 & SC 1.4.11)**:
   - Line 1 upload dot: `NSColor.systemRed` on dark and light backgrounds provides `>= 3.0:1` graphical object contrast.
   - Line 2 download dot: Uses dynamic adaptive color `Color.networkDownload`:
     - Under `darkAqua`: `NSColor.systemCyan` (perceptual distance from 50% gray: `27.4`).
     - Under `aqua`: `NSColor.systemBlue` (perceptual distance from 50% gray: `11.8`).
   - Rate text: 9 pt monospaced regular with `.primary` adaptive contrast (`>= 7:1` on default menu bar surfaces).
   - Missing placeholder text: Uses `tertiaryLabelColor` with `lineLimit(1)`.
2. **Discrete Transitions (SC 2.3.3)**:
   - Status item views must not use `.animation` or `.contentTransition`. Value updates change instantly on every 1-second sample to prevent glyph re-rasterization jitter.
3. **VoiceOver Contract (`MenuBarAccessibility.swift`)**:
   - VoiceOver reads the status item using the single accessibility string:
     `"Network Upload <uploadRate>, Download <downloadRate>"` (for example: `"Network Upload 0.4 MB/s, Download 1.2 MB/s"`).
   - If rates are unavailable, reads `"Network unavailable"`.
   - The menu bar view hierarchy carries `.accessibilityHidden(true)` so the status button exposes only the consolidated parent label.

---

## 5. Numbered Visual Acceptance Checklist (VAC)

### Part A: View Hierarchy & Token Invariants

- [ ] **VAC-R1 (Leading Dot Sequence Invariant)**: In `StatsLite/MenuBarStackedItemView.swift`, each row of `MenuBarNetworkBlockView` sequences `Circle(...)` before `Text(...)` inside its `HStack(alignment: .center, spacing: 0)`. The `Circle` precedes the `Spacer(minLength: 1)`, and the `Spacer` precedes the `Text`.
- [ ] **VAC-R2 (Dot Dimensions)**: Indicator dots must maintain a pinned frame of `width: CGFloat.networkDotSize, height: CGFloat.networkDotSize` (`5.0 pt x 5.0 pt`) on both lines.
- [ ] **VAC-R3 (Row Height Invariant)**: Both lines must maintain a pinned row frame height of `MenuBarLayout.rowHeight` (`11.0 pt`), yielding an overall block height of `22.0 pt`.
- [ ] **VAC-R4 (Zero Animation Invariant)**: `MenuBarNetworkBlockView` and its subviews must not attach `.animation` or `.contentTransition` modifiers.

### Part B: Layout Math & Pinned Width Invariants

- [ ] **VAC-R5 (Network Block Width Pinned to 47 pt)**: `MenuBarLayout.networkBlockWidth` must equal `47.0 pt`.
- [ ] **VAC-R6 (Widest String Clearance Invariant)**: For the maximum text width under the new formatter (`"0.4 MB/s"` or `"9.9 MB/s"`, measuring `39.1113 pt` at 9 pt regular monospacedDigit), total horizontal clearance inside the 47.0 pt block with the 5.0 pt dot must be at least `2.88 pt` (asserted as `47.0 - 5.0 - textWidth >= 2.5 pt`), satisfying the repository clearance rule.
- [ ] **VAC-R7 (Menu Bar Total Length Invariants)**: `MenuBarLayout.length(...)` calculations must return the following exact values:
  - All five metrics enabled (CPU + MEM + GPU + TEMP + NET): `184.0 pt` (was 187.0 pt).
  - All four metrics enabled (CPU + MEM + GPU + NET): `144.0 pt` (was 147.0 pt).
  - Network only enabled: `51.0 pt` (was 54.0 pt).
  - CPU + Network enabled: `82.0 pt` (was 85.0 pt).
  - Standard three metrics (CPU + MEM + GPU, Network disabled): `93.0 pt` (unchanged).

### Part C: Rate Formatter Invariants (`MetricFormatters.networkRate`)

- [ ] **VAC-R8 (Mantissa 2-Digit Cap Regular Expression)**: Every formatted rate string from 0 B/s to 20 GB/s, including missing values and boundary transitions, must match the regular expression `^(--|\d{1,2}|\d\.\d) (KB|MB|GB)/s$`. No output mantissa can exceed two digits.
- [ ] **VAC-R9 (KB to MB Boundary Transitions)**:
  - `99.4 * 1024` B/s formats as `"99 KB/s"`.
  - `99.5 * 1024` B/s formats as `"0.1 MB/s"`.
  - `400 * 1024` B/s formats as `"0.4 MB/s"`.
  - `999 * 1024` B/s formats as `"1.0 MB/s"`.
- [ ] **VAC-R10 (MB to GB Boundary Transitions)**:
  - `9.94 * 1048576` B/s formats as `"9.9 MB/s"`.
  - `9.95 * 1048576` B/s formats as `"10 MB/s"`.
  - `99.4 * 1048576` B/s formats as `"99 MB/s"`.
  - `99.5 * 1048576` B/s formats as `"0.1 GB/s"`.
  - `400 * 1048576` B/s formats as `"0.4 GB/s"`.
- [ ] **VAC-R11 (GB Ceiling Clamp)**: Rates at or above `99.5 * 1073741824` B/s format as `"99 GB/s"`. Missing, negative, or non-finite values format as `"-- KB/s"`.

### Part D: Offscreen Bitmap Render Invariants (`MenuBarRenderSnapshotTests`, 2x Retina Scale)

- [ ] **VAC-R12 (Network Block Bitmap Width)**: In offscreen 2x bitmap renders under `darkAqua` and `aqua`, `MenuBarNetworkBlockView` must render exactly `94 px` wide (`47.0 pt x 2`).
- [ ] **VAC-R13 (Leading Dot Positioning)**: In both lines (Line 1 `0..<22 px`, Line 2 `22..<44 px`), indicator dot ink must start at `x <= 1 px` (leftmost ink) and end at `x <= 10 px` (rightmost ink). Both dots must share the leading column within `1 px` (`abs(dotLeftLine1 - dotLeftLine2) <= 1`).
- [ ] **VAC-R14 (Flush-Right Value Text)**: In both lines, for any rate string, the rightmost text ink must reach `x >= 91 px` (within 3 px of the 94 px frame boundary).
- [ ] **VAC-R15 (Dot-to-Text Gutter Clearance)**: For the widest rate string (`"9.9 MB/s"`), the empty span between the dot's right ink and the rate text's left ink must measure at least `5 px` (measured: `6 px` at 2x scale, equal to `3.0 pt`).
- [ ] **VAC-R16 (TEMP-to-NET Inter-Block Ink Gap Restored to 21 px)**: In the adjacent render of `MenuBarTempBlockView` and `MenuBarNetworkBlockView`, the empty span from the rightmost TEMP value ink on Line 1 to the leftmost red dot ink on Line 1 must measure `21 ± 1 px` at 2x scale under both `darkAqua` and `aqua` appearances (restoring the pre-move shared `interBlockGap = 21.0`).
- [ ] **VAC-R17 (TEMP Label and Network Dot Centroid Alignment)**: Intensity-weighted sub-pixel centroids must align within `0.30 px` at 2x scale under both forced appearances:
  - `|cy(C label) - cy(red dot)| <= 0.30 px`.
  - `|cy(G label) - cy(cyan/blue dot)| <= 0.30 px`.

---

## Notes on Ambiguities & Resolved Tradeoffs

1. **Space before unit token**: The user requested `"0.4MB/s"`, but current tokens across the repository use `"0.4 MB/s"` with a standard space (matching `-- KB/s`, `100%`, `9.9 GB`, etc.). The blueprint retains the single space to keep typography consistent.
2. **Pinned width 47 pt**: `47.0 pt` was selected over `46.0 pt` because `46.0 pt` produces only `1.89 pt` clearance for the widest string, violating the repository's `≥ 2.5 pt` clearance rule. `47.0 pt` provides `2.89 pt` clearance, perfectly satisfying the rule while shrinking the dot-to-text gap by `3.0 pt` (6 bitmap pixels at 2x).
3. **Shared formatter impact**: Updating `MetricFormatters.networkRate` affects both the menu bar status item and the popover `NetworkCardView`. This is intentional: both surfaces now display concise rates with at most two mantissa digits.


## ISC — binary checks

Failure modes for this plan: `FM1` wrong unit-switch boundary (99.5 KB/s or
99.5 MB/s rounds the wrong way, so a 3-digit or premature value renders);
`FM2` 47 pt frame clips the widest string (clearance < 2.5 pt → truncation);
`FM3` dots not truly leading or text not flush right (spacer/frame misuse);
`FM4` TEMP↔NET ink gap drifts off 21 ± 1 px (stale `tempNetInkGap` leak or
block-gap edit); `FM5` menu-bar length totals or VoiceOver strings miss the
47 pt / new-format change.

- [ ] **ISC-1** (VAC-R1, FM3): both `MenuBarNetworkBlockView` rows sequence
  `Circle → Spacer(minLength: 1) → Text` in source; dots 5 pt; rows 11 pt; no
  `.animation` / `.contentTransition` anywhere in the view (VAC-R2, R3, R4).
- [ ] **ISC-2** (VAC-R8..R11, FM1): `MetricFormatters.networkRate` output matches
  `^(--|\d{1,2}|\d\.\d) (KB|MB|GB)/s$` across the full 0…20 GB/s sweep;
  boundaries: `99.4*1024 → "99 KB/s"`, `99.5*1024 → "0.1 MB/s"`,
  `400*1024 → "0.4 MB/s"`, `999*1024 → "1.0 MB/s"`, `99.4 MiB → "99 MB/s"`,
  `99.5 MiB → "0.1 GB/s"`, `400 MiB → "0.4 GB/s"`, `≥ 99.5 GiB → "99 GB/s"`
  (clamp), missing/negative/non-finite → `"-- KB/s"`.
- [ ] **ISC-3** (VAC-R5..R7, FM2/FM5): `networkBlockWidth == 47`; widest-string
  clearance `47 − 5 − textWidth ≥ 2.5 pt` at 9 pt regular monospacedDigit;
  `MenuBarLayout.length` totals: all-five `184`, CPU+MEM+GPU+NET `144`,
  network-only `51`, CPU+NET `82`, three-metric-no-network `93` (unchanged).
- [ ] **ISC-4** (VAC-R12..R15, FM2/FM3): offscreen 2x renders under `darkAqua`
  and `aqua`: network block bitmap exactly 94 px wide; both dots' ink starts at
  `x ≤ 1 px`; both dots share one column within 1 px; rightmost rate-text ink
  reaches `x ≥ 91 px` (flush right) on both lines; dot-to-text gutter for the
  widest rate measures at least 5 px.
- [ ] **ISC-5** (VAC-R16/R17, FM4): TEMP↔NET inter-block ink gap back to
  `21 ± 1 px` under both appearances (`tempNetInkGap` constant removed); TEMP
  label ↔ network dot centroids align within 0.30 px.
- [ ] **ISC-6** (FM5): updated expectation strings are applied everywhere the old
  format was asserted (`MenuBarBlockBuilderTests`, `MenuBarAccessibilityTests`,
  `MetricFormatterTests`); `git diff --name-only` touches only
  `StatsLite/MenuBarStackedItemView.swift`, `StatsLite/MenuBarBlockModel.swift`,
  `StatsLite/MetricFormatters.swift`, and test files; popover
  `NetworkCardView.swift` itself is untouched (it inherits the new strings).
- [ ] **ISC-7**: two consecutive full-suite runs exit 0 under `caffeinate`
  (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer caffeinate -i
  xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -destination
  'platform=macOS' test`); after-capture via `scripts/capture_menubar.sh`
  exists in `artifacts/` (TCC note per repo precedent; offscreen render tests
  remain the gate).

## Approach & decisions

1. **Manual targeted revert, not `git revert ec087f0`.** The commit mixed the view
   reorder with render-test retargets; the new plan rewrites those tests to
   leading-dot geometry at 47 pt anyway. The coder restores the pre-move row
   sequence and doc comments (reference: `git show ec087f0~1:StatsLite/MenuBarStackedItemView.swift`)
   and applies the 47 pt width and 2-digit formatter on top.
2. **Width 47 pt, not 46 pt.** 46 pt leaves 1.89 pt clearance for the widest
   string (violates the repo's ≥ 2.5 pt rule); 47 pt leaves 2.89 pt.
3. **Keep the space in `0.4 MB/s`.** The user typed "0.4MB/s" but the repo's
   typography uses a space before every unit (`-- KB/s`, `9.9 GB`); no token change.
4. **Shared formatter parity is intended.** `MetricFormatters.networkRate` feeds
   the menu bar, the popover `NetworkCardView`, and the VoiceOver string. All
   three surfaces show the 2-digit format; only test expectations change, not
   `NetworkCardView.swift` code.
5. **Ordering: formatter first (T2/T3), then geometry (T4–T6).** The formatter
   green shortens the widest production string, which the 47 pt width budget is
   designed around.

## Notation

Plan → Phase → Task (`T1`…`T7`; `FM*` = failure modes) → Receipts
(red SHA / green SHA / review verdict — verified in git, recorded on the task line).
`red` = test-only commit that fails on current production. `green` =
implementation commit that makes it pass. Worktree:
`worktrees/2026-10-26-network-dots-leading-rate-cap`, branch
`feat/2026-10-26-network-dots-leading-rate-cap`.

## Tasks

- [ ] **T1** — display awake; `scripts/capture_menubar.sh` → `artifacts/2026-10-26-network-dots-leading-rate-cap/before/`; create worktree `git worktree add -B feat/2026-10-26-network-dots-leading-rate-cap worktrees/2026-10-26-network-dots-leading-rate-cap main` (skip-red, mechanical).
- [ ] **T2** — red (formatter): test-only edits — rewrite `MetricFormatterTests`
  network-rate expectations to the 2-digit rule (ISC-2 boundaries + regex
  `\d{1,2}` sweep); update `MenuBarBlockBuilderTests.swift:370`
  (`"720 KB/s"` → `"0.7 MB/s"`) and `MenuBarAccessibilityTests.swift:162,221`
  VoiceOver strings. Expected red set: the touched rate tests fail on current
  production ("720 KB/s", "999 KB/s", "100 MB/s", "119 MB/s" still produced).
  No production file in the diff.
- [ ] **T3** — green (formatter): `StatsLite/MetricFormatters.swift` only —
  `networkRate` switches unit at 100 and clamps at `"99 GB/s"` (blueprint §2.C).
  Doc comment updated. Failing test: T2's red set.
- [ ] **T4** — red (geometry): test-only edits —
  `MenuBarValueTypographyTests.testNetworkRowsSequenceTextBeforeDot` inverted to
  Circle-before-Text (rename accordingly); `testNetworkBlockClearanceForWidestRateStringMeetsSpacerMinimum`
  retargeted to 47 pt / widest `"9.9 MB/s"` (39.1113 pt, clearance 2.8887);
  `MenuBarRenderSnapshotTests.testNetworkDotsPinTrailingAndTextLeads` replaced by
  a leading-dot test asserting VAC-R12..R15 (94 px frame, leading dots, flush
  right text, ≥ 5 px gutter); centroid test dot queries restored to the leading
  band (pre-`ec087f0` `networkColumns` form); `tempNetInkGap` constant removed
  and the TEMP↔NET leg reverts to `interBlockGap` (ISC-5); `MenuBarLayoutTests`
  pinned-width + totals tests retargeted to 47/184/144/51/82 (names updated);
  `MenuBarBlockBuilderTests.swift:355,382` width expectations 50 → 47.
  Expected red set: exactly these tests, failing on current production.
- [ ] **T5** — green (view revert): `StatsLite/MenuBarStackedItemView.swift`
  only — both network rows back to `Circle → Spacer(minLength: 1) → Text`;
  file header and view doc comments restored to leading-dot wording with the
  47 pt mention. No other modifier changes. Failing test: T4's leading-dot set
  (the 94 px / totals legs stay red until T6 — allowed residual, recorded).
- [ ] **T6** — green (width): `StatsLite/MenuBarBlockModel.swift` only —
  `networkBlockWidth` 50 → 47 with the updated clearance comment. Failing test:
  T4's width/total/clearance set. Stop if the widest-string clearance test
  measures < 2.5 pt (FM2) — do not widen the tolerance; re-measure and report.
- [ ] **T7** — verification (planner): two consecutive full-suite runs exit 0;
  ISC-6 scope check + `rg '\.animation\(|\.contentTransition\('` over the diff
  empty; after-capture; conventional commits per task; reviewer code review
  against `git diff main...HEAD`; `--ff-only`/`--squash` merge; record merge
  SHA; update this ledger.

## Ledger

(receipts: commands, exit codes, measured values, SHAs)
