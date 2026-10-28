# Plan: 2026-10-27-memory-pressure-badge-contrast

Plan name: `2026-10-27-memory-pressure-badge-contrast`
Risk class: **R2** (UI work — visual fidelity to the Design Blueprint is a blocking requirement).

## Intent

The Memory Pressure status pill in the menu-bar popover renders unreadable text: yellow "Warning" text on a pale yellow capsule measures 1.41:1 contrast in light appearance. All four pill states (`Normal`, `Warning`, `Critical`, `Unknown`) fall below the WCAG 2.2 AA 4.5:1 minimum in light appearance. The fix introduces adaptive badge tokens in `DesignTokens.swift` and applies them in `MemoryPressureCardView.swift` so every state passes AA in both light and dark appearances. Scope is strictly the status pill badge — menu bar dot, sparkline tint, and gauge bar keep using `state.levelColor`.

## ISC (binary yes/no)

- **VAC-1**: Warning pill in light appearance uses text `#844400` on warm amber fill, contrast >= 4.5:1 (nominal 6.40:1).
- **VAC-2**: Warning pill in dark appearance uses `systemYellow` on dark amber fill, contrast >= 4.5:1 (nominal 6.58:1).
- **VAC-3**: Normal pill in light appearance uses `#106C2A` on pale green fill, contrast >= 4.5:1 (nominal 5.38:1).
- **VAC-4**: Normal pill in dark appearance uses `systemGreen` on dark forest fill, contrast >= 4.5:1 (nominal 5.46:1).
- **VAC-5**: Critical pill in light appearance uses `#A8171C` on soft red fill, contrast >= 4.5:1 (nominal 5.42:1).
- **VAC-6**: Critical pill in dark appearance uses `#FF8080` on dark crimson fill, contrast >= 4.5:1 (nominal 4.98:1).
- **VAC-7**: Unknown pill passes >= 4.5:1 in both appearances (`#45454A` light, `#B8B8BD` dark).
- **VAC-8**: Badge geometry unchanged: 10 pt semibold, 6 pt horizontal / 2 pt vertical padding, `Capsule()` fill, 0.5 pt stroke.
- **VAC-9**: No `.animation()` or `.contentTransition()` in the badge or token code.
- **VAC-10**: `state.levelColor` still drives menu bar dot, sparkline tint, and gauge bar fill.

Verification: VAC-1..VAC-7 verified by computed contrast ratios (unit test over the token colors composited against the card surface) plus rendered screenshots in light and dark appearance. VAC-8..VAC-10 verified by code review. All items verified at 375/768/1440-equivalent popover width — the popover is a fixed 280 pt panel, so a single rendered check per appearance covers layout (no responsive breakpoints apply; noted as N/A rather than skipped).

## Approach

Copy of the 5-part Design Blueprint (verbatim):

### Design Blueprint: Memory Pressure Status Pill Contrast Fix

#### Executive Summary

The user reported a contrast defect in the light appearance of the macOS menu-bar popover in Stats Lite. In the **Memory Pressure** card header, the status pill for the `Warning` state rendered yellow text on a pale yellow translucent capsule. In light appearance, standard `NSColor.systemYellow` text against a pale yellow background achieves a contrast ratio of only **1.41:1**. This violates the WCAG 2.2 AA minimum threshold of **4.5:1** and makes the word "Warning" illegible.

Inspection of the sibling states revealed that all four status pill states (`Normal`, `Warning`, `Critical`, and `Unknown`) fell below the 4.5:1 threshold in light appearance when rendered with raw system colors.

This blueprint establishes adaptive tokens in `DesignTokens.swift` and updates `MemoryPressureCardView.swift`. The fix raises contrast ratios across all states and appearances above 4.5:1. The fix preserves the existing capsule badge geometry, palette style, and discrete transition rules.

#### 1. Visual Hierarchy & ASCII Wireframe

The status pill sits at the trailing edge of the Memory Pressure card header row. The header row aligns the card icon and metric title on the leading edge and places the status pill on the trailing edge.

##### Component Layout Hierarchy

```
Popover Container (280 pt fixed width, .regularMaterial)
└── MetricCardStyle Container (10 pt padding, ~260 pt inner width)
    └── Header Row (HStack, spacing: 6 pt, height: ~18 pt)
        ├── [memorychip] Icon (11 pt semibold, .secondary)
        ├── "Memory Pressure" Title (11 pt semibold, .secondary)
        ├── Spacer()
        └── Status Pill Badge (Capsule, height: ~16 pt)
            └── Text(state.displayName) (10 pt semibold)
                ├── Padding (horizontal: 6 pt, vertical: 2 pt)
                ├── Background (Capsule fill: state.badgeBackgroundColor)
                └── Border (Capsule stroke: state.badgeBorderColor, lineWidth: 0.5 pt)
```

##### ASCII Wireframe: Light Appearance (Aqua)

Defect State (yellow on pale yellow, CR 1.41:1 FAIL):

```
+---------------------------------------------------------------+
| [icon] Memory Pressure                              ( Warning )|  <-- Text washed out
|                                                     ~~~~~~~~~  |      CR: 1.41:1 (FAIL)
| [====================                                         ]|
| -1m                                                        Now|
| Used: 85% (30.4 / 36.0 GB)                                    |
| [Blue  |Purple |Orange          |Gray Track                  ]|
| App: 8.3G · Wired: 6.5G · Comp: 15.6G                         |
| > Top Processes                                               |
+---------------------------------------------------------------+
```

Target State (deep amber on light warm amber, CR 6.40:1 PASS):

```
+---------------------------------------------------------------+
| [icon] Memory Pressure                              [ Warning ]|  <-- High-contrast amber
|                                                     =========  |      CR: 6.40:1 (PASS)
| [====================                                         ]|
| -1m                                                        Now|
| Used: 85% (30.4 / 36.0 GB)                                    |
| [Blue  |Purple |Orange          |Gray Track                  ]|
| App: 8.3G · Wired: 6.5G · Comp: 15.6G                         |
| > Top Processes                                               |
+---------------------------------------------------------------+
```

##### ASCII Wireframe: All Sibling States (Light vs Dark)

```
State      Light Appearance (Aqua)               Dark Appearance (Dark Aqua)
---------------------------------------------------------------------------------------
Normal     [ Normal ]   Forest text #106C2A      [ Normal ]   Vibrant green systemGreen
                        Pale green bg #D8EEDE                 Dark forest bg #29412F
                        CR: 5.38:1 (PASS)                     CR: 5.46:1 (PASS)

Warning    [ Warning ]  Deep amber text #844400  [ Warning ]  Vibrant yellow systemYellow
                        Warm amber bg #F7EEC9                 Dark amber bg #4F4721
                        CR: 6.40:1 (PASS)                     CR: 6.58:1 (PASS)

Critical   [ Critical ] Deep crimson text #A8171C[ Critical ] Bright coral text #FF8080
                        Soft red bg #F7D3D4                   Dark crimson bg #4F2D2D
                        CR: 5.42:1 (PASS)                     CR: 4.98:1 (PASS)

Unknown    [ Unknown ]  Charcoal text #45454A    [ Unknown ]  Silver gray text #B8B8BD
                        Soft gray bg #E6E6E6                  Dark gray bg #39393A
                        CR: 7.61:1 (PASS)                     CR: 5.86:1 (PASS)
```

#### 2. Template / Component Skeleton

Code citations:

- Pill badge implementation: `StatsLite/MemoryPressureCardView.swift:93-100`
- State definitions and tokens: `StatsLite/DesignTokens.swift:14-25`
- Pressure state model: `StatsLite/MetricTypes.swift:88-108`

Target tokens in `StatsLite/DesignTokens.swift` (add to the `MemoryPressureState` extension):

```swift
extension MemoryPressureState {

    /// Foreground text color for the status pill badge.
    /// Meets WCAG 2.2 AA (>= 4.5:1) against `badgeBackgroundColor`
    /// across both light and dark appearances.
    var badgeTextColor: Color {
        switch self {
        case .normal:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? .systemGreen
                    : NSColor(srgbRed: 16/255.0, green: 108/255.0, blue: 42/255.0, alpha: 1.0)
            })
        case .warning:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? .systemYellow
                    : NSColor(srgbRed: 132/255.0, green: 68/255.0, blue: 0/255.0, alpha: 1.0)
            })
        case .critical:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(srgbRed: 255/255.0, green: 128/255.0, blue: 128/255.0, alpha: 1.0)
                    : NSColor(srgbRed: 168/255.0, green: 23/255.0, blue: 28/255.0, alpha: 1.0)
            })
        case .unknown:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(srgbRed: 184/255.0, green: 184/255.0, blue: 189/255.0, alpha: 1.0)
                    : NSColor(srgbRed: 69/255.0, green: 69/255.0, blue: 74/255.0, alpha: 1.0)
            })
        }
    }

    /// Background fill color for the status pill capsule.
    var badgeBackgroundColor: Color {
        switch self {
        case .warning, .critical:
            return levelColor.opacity(0.18)
        case .normal, .unknown:
            return levelColor.opacity(0.15)
        }
    }

    /// Border stroke color for the status pill capsule.
    var badgeBorderColor: Color {
        switch self {
        case .warning:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor.systemYellow.withAlphaComponent(0.35)
                    : NSColor(srgbRed: 132/255.0, green: 68/255.0, blue: 0/255.0, alpha: 0.30)
            })
        case .normal:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor.systemGreen.withAlphaComponent(0.35)
                    : NSColor(srgbRed: 16/255.0, green: 108/255.0, blue: 42/255.0, alpha: 0.25)
            })
        case .critical:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(srgbRed: 255/255.0, green: 128/255.0, blue: 128/255.0, alpha: 0.35)
                    : NSColor(srgbRed: 168/255.0, green: 23/255.0, blue: 28/255.0, alpha: 0.25)
            })
        case .unknown:
            return levelColor.opacity(0.30)
        }
    }
}
```

Target view in `StatsLite/MemoryPressureCardView.swift` (replace lines 93-100):

```swift
    // MARK: - Badge (VAC-20)

    private var badge: some View {
        Text(state.displayName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(state.badgeTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(state.badgeBackgroundColor))
            .overlay(Capsule().stroke(state.badgeBorderColor, lineWidth: 0.5))
    }
```

#### 3. Complete State & Responsive Matrix

| State | Appearance | Text RGB Hex | Text Lum | Pill Fill Token | Composite Bg Lum | Stroke Token | Contrast Ratio | WCAG AA |
| :--- | :--- | :--- | ---: | :--- | ---: | :--- | ---: | :--- |
| Normal | Light | `#106C2A` | 0.106 | `levelColor.opacity(0.15)` | 0.811 | `#106C2A` (25%) | **5.38:1** | PASS |
| Normal | Dark | `systemGreen` | 0.469 | `levelColor.opacity(0.15)` | 0.045 | `systemGreen` (35%) | **5.46:1** | PASS |
| Warning | Light | `#844400` | 0.091 | `levelColor.opacity(0.18)` | 0.849 | `#844400` (30%) | **6.40:1** | PASS (defect fix) |
| Warning | Dark | `systemYellow` | 0.694 | `levelColor.opacity(0.18)` | 0.063 | `systemYellow` (35%) | **6.58:1** | PASS |
| Critical | Light | `#A8171C` | 0.076 | `levelColor.opacity(0.18)` | 0.711 | `#A8171C` (25%) | **5.42:1** | PASS |
| Critical | Dark | `#FF8080` | 0.383 | `levelColor.opacity(0.18)` | 0.037 | `#FF8080` (35%) | **4.98:1** | PASS |
| Unknown | Light | `#45454A` | 0.061 | `levelColor.opacity(0.15)` | 0.788 | `systemGray` (30%) | **7.61:1** | PASS |
| Unknown | Dark | `#B8B8BD` | 0.468 | `levelColor.opacity(0.15)` | 0.041 | `systemGray` (30%) | **5.86:1** | PASS |

Responsive behavior: panel width fixed at 280 pt (`PopoverContentView.swift:131`); card content 260 pt; badge is content-driven (~16 pt height); `Spacer()` absorbs label width differences so no layout shift occurs on state change.

#### 4. Accessibility (WCAG 2.2) & Interaction Contracts

- SC 1.4.3 Contrast (AA): all eight state/appearance pairs >= 4.5:1 (4.98:1 - 7.61:1).
- SC 1.4.1 Use of Color (A): every state renders an explicit text label; color is reinforcement only.
- SC 1.4.11 Non-text Contrast (AA): capsule stroke visible at >= 3:1 against the card surface.
- Discrete transitions only: no `.animation` or `.contentTransition` (per `AGENTS.md`).
- Screen reader: the header groups icon, title, and badge into one accessibility element (`MemoryPressureCardView.swift:41-42`) with `.accessibilityLabel(summary)`; the summary already speaks the state.

#### 5. Numbered Visual Acceptance Checklist (VAC)

- VAC-1: Warning pill light appearance, `#844400` text, contrast >= 4.5:1 (nominal 6.40:1).
- VAC-2: Warning pill dark appearance, `systemYellow` text, contrast >= 4.5:1 (nominal 6.58:1).
- VAC-3: Normal pill light appearance, `#106C2A` text, contrast >= 4.5:1 (nominal 5.38:1).
- VAC-4: Normal pill dark appearance, `systemGreen` text, contrast >= 4.5:1 (nominal 5.46:1).
- VAC-5: Critical pill light appearance, `#A8171C` text, contrast >= 4.5:1 (nominal 5.42:1).
- VAC-6: Critical pill dark appearance, `#FF8080` text, contrast >= 4.5:1 (nominal 4.98:1).
- VAC-7: Unknown pill >= 4.5:1 in both appearances.
- VAC-8: Badge geometry: 10 pt semibold, 6/2 pt padding, `Capsule()` fill, 0.5 pt stroke.
- VAC-9: No animated transitions in badge or token code.
- VAC-10: `state.levelColor` still drives menu bar dot, sparkline, gauge fill.

## Refactors

None required. The change replaces raw system colors on the badge with named tokens; no band-aids exist in the touched code. Verify at implementation time that no other call sites render pill text with raw system colors.

## Red-phase findings (T1, applied)

- Contrast is measured in gamma-space compositing (Core Graphics model). All 8 pairs clear 4.5:1 under that model. Do not switch to linear-light compositing in green.
- The plan's nominal matrix ratios are approximations, not pins (dark warning computes 7.47 vs plan 6.58; dark critical 5.58 vs 4.98). Tests pin the hex/alpha values and the 4.5:1 floor, not the nominal ratios.
- **Dropped claim**: plan §4 SC 1.4.11 (stroke >= 3:1) is not achievable with the blueprint border tokens (measured 1.15-2.25:1). No numeric VAC existed for it; the claim is removed rather than asserted.
- Render/snapshot geometry test skipped: no existing popover card render test exists; VAC-8 geometry is pinned by a source-token guard test instead. T2 screenshots remain the visual reality check.
- Red is a compile failure, so guard-test runtime reds are unobservable until green; green must re-run the full suite and confirm every guard method passes.

## Notation

```
Plan -> Phase -> Task (T*) -> Receipts (red SHA / green SHA / review verdict)
```

## Tasks

- [x] **T1** — Add `badgeTextColor` / `badgeBackgroundColor` / `badgeBorderColor` tokens to `DesignTokens.swift` and apply them in `MemoryPressureCardView.swift` badge, with a contrast unit test covering all 8 state/appearance pairs. red `bd6702d` · green `ed5e83d` · review GO · squash-merged to main `e40050c`
- [x] **T2** — Verify VAC-1..VAC-10: run the test suite (522 passed at green), render light/dark screenshots of the Memory Pressure card, present to user. green `e40050c` verified on main: 522/0 tests, light.png 4.64:1, dark.png 6.00:1, VAC-1..VAC-10 all Met · review n/a (verification task)
