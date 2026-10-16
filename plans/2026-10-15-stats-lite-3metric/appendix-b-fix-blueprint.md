# Appendix B: Design Fix Blueprint — Stats Lite Menu Bar App

This blueprint fixes two visual defects observed in the live macOS menu bar app.
It extends `.pi/plans/2026-10-13-stats-lite-menu-bar/design-extension-gpu-pressure-toggles.md` and base `notes.md`.
The repository contains no root `DESIGN.md`. Design tokens originate from `design-extension-gpu-pressure-toggles.md` and `StatsLite/DesignTokens.swift`.

---

## 1. Visual Defect Triage & Root-Cause Hypotheses

### Defect 1: Menu Bar Item Shows Only Literal "CPU" Text (Major)

#### Observed State
- The status item renders as a compact 47 pt pill showing only the string `"CPU"`.
- Metric numbers, RAM pressure dot, and GPU slot do not appear.
- All three metric toggles are confirmed ON (`showCPU = 1`, `showRAM = 1`, `showGPU = 1`).

#### Rank-Ordered Root-Cause Hypotheses

1. **SwiftUI `MenuBarExtra` label view extraction (Primary Cause)**
   - *Location*: `StatsLite/StatsLiteApp.swift:23-25` and `StatsLite/MenuBarItemView.swift:66-96`.
   - *Mechanism*: macOS `MenuBarExtra(content:label:)` wraps an AppKit `NSStatusBarButton`. SwiftUI inspects the `label` closure. When the closure provides an `HStack` with multiple nested subviews, SwiftUI extracts only the first discrete `Text` element. It assigns that string to `NSStatusBarButton.title`. In `MenuBarItemView.swift:101`, `categoryLabel("CPU")` produces `Text("CPU")`. SwiftUI takes `"CPU"`, discards all sibling views (`valueText`, `ramSlot`, `gpuSlot`, `Circle()`), and sizes the button to fit only `"CPU"`.

2. **Status item width clamping with `.fixedSize()` (Secondary Cause)**
   - *Location*: `StatsLite/MenuBarItemView.swift:87`.
   - *Mechanism*: `NSStatusBarButton` does not host arbitrary custom multi-view hierarchies without an explicit size contract. `.fixedSize()` inside the AppKit status bar container collapses when child layout passes run after the parent window attaches.

3. **Delayed first sample tick on `MenuBarItemView` appear (Tertiary Cause)**
   - *Location*: `StatsLite/MenuBarItemView.swift:89`.
   - *Mechanism*: If `MenuBarExtra` does not trigger `.onAppear` on label views, `monitor.apply(preferences)` does not run until the popover opens. If `snapshot` is `nil`, unformatted or empty text can cause layout collapses.

---

### Defect 2: Popover Clips GPU Card Bottom and Hides Footer (Minor)

#### Observed State
- The popover window terminates at the bottom edge of the GPU card sparkline.
- The GPU card bottom margin and the entire footer (`Updated every 2s … macOS Native`) are clipped.

#### Rank-Ordered Root-Cause Hypotheses

1. **Undersized fixed target height in `targetHeight` (Primary Cause)**
   - *Location*: `StatsLite/PopoverContentView.swift:130-137`.
   - *Mechanism*: `targetHeight` hardcodes 390 pt for 3 cards. The actual intrinsic height of the 3-card stack exceeds 414 pt:
     - Header: 28 pt
     - Header divider and padding: 6 pt
     - CPU card: ~110 pt
     - Card stack spacing (2 × 6 pt): 12 pt
     - Memory Pressure card (with 8 pt gauge bar, sparkline, breakdown): ~150 pt
     - GPU card: ~74 pt
     - Footer divider and padding: 6 pt
     - Footer: 28 pt
     - Total content height: ~414 pt.
     `MenuBarExtraWindow` clamps to `minHeight: targetHeight` (390 pt) without allowing natural content expansion.

2. **Unconstrained `Spacer(minLength: 0)` in vertical stack (Secondary Cause)**
   - *Location*: `StatsLite/PopoverContentView.swift:45`.
   - *Mechanism*: `Spacer(minLength: 0)` collapses to zero. Because the window frame has a hard height bound, the content pushes past the bottom window edge.

---

## 2. Target Visual State

### Target Menu Bar Rendering (COMB-1)
- **All 3 metrics enabled, labels ON**:
  Single-line text string with exact width ~200 pt:
  ```
  CPU 14%  ·  RAM ● 62%  ·  GPU 28%
  ```
- **All 3 metrics enabled, labels OFF**:
  Single-line text string with exact width ~129 pt:
  ```
  14%  ·  ● 62%  ·  28%
  ```
- **GPU unavailable state**:
  ```
  CPU 14%  ·  RAM ● 62%  ·  GPU --%
  ```

### Target Popover Rendering (VAC-22)
- Fixed width: **280 pt**.
- Vertical structure (top to bottom):
  1. Header (28 pt): `[gauge] Stats Lite` + gear button + power button.
  2. 1 pt Divider.
  3. CPU Card (if `showCPU`).
  4. Memory Pressure Card (if `showRAM`): capsule badge, 8 pt gauge bar, sparkline, occupancy text, composition bar, breakdown text.
  5. GPU Card (if `showGPU`): title, value, subtitle, 38 pt sparkline (or dashed box).
  6. 1 pt Divider.
  7. Footer (22 pt): `Updated every 2s` (leading) and `macOS Native` (trailing).
- The popover window must size to fit its content naturally. The footer must remain fully visible with 8 pt bottom padding.

---

## 3. Implementation Fix Specification

### Fix for Defect 1 (Menu Bar Item)
The coder must implement one of these two architectural paths:

- **Path A (Pure SwiftUI String Composition — Recommended)**:
  Construct the menu bar content as a single unified `Text` view using string interpolation and formatted `AttributedString` runs.
  ```swift
  Text(menuBarAttributedText)
      .lineLimit(1)
  ```
  This prevents `MenuBarExtra` from dropping subviews. It renders reliably across all macOS versions. Use a unicode bullet `●` (U+25CF) tinted with the pressure color for the RAM dot.

- **Path B (NSStatusItem Custom Hosting View)**:
  If custom SwiftUI drawing (for example a vector `Circle`) is strictly required in the status bar, wrap `MenuBarItemView` in an `NSHostingView` attached to the `NSStatusItem.button`. Set `statusItem.length = NSVariableStatusItemLength`.

### Fix for Defect 2 (Popover Dynamic Height)
1. In `StatsLite/PopoverContentView.swift`:
   - Remove the hardcoded `minHeight: targetHeight` frame restriction.
   - Set `.frame(width: 280)` on the root `VStack`.
   - Remove `Spacer(minLength: 0)` between the card stack and the footer divider. Use explicit spacing (`spacing: 8`).
   - Add `.fixedSize(horizontal: true, vertical: true)` to make sure that the popover window sizes to the content.
2. Update the dynamic target height calculation to accommodate real card dimensions:
   - 3 cards collapsed: minimum 420 pt (was 390 pt).
   - 3 cards expanded (+ per-core grid): minimum 500 pt (was 470 pt).
   - 2 cards collapsed: minimum 320 pt (was 300 pt).
   - 1 card collapsed: minimum 220 pt (was 210 pt).

---

## 4. Delta Acceptance Checklist (Appendix B)

| ID | Viewport / Area | Exact Invariant | Met |
| --- | --- | --- | --- |
| **VAC-B1** | Menu Bar (Desktop) | When all three metrics are enabled, the menu bar displays CPU %, RAM dot with used %, and GPU % on a single line. No metric slot is omitted. | |
| **VAC-B2** | Menu Bar (Desktop) | When labels are enabled, width matches COMB-1 (~200 pt). When labels are disabled, width matches COMB-1 (~129 pt). | |
| **VAC-B3** | Menu Bar (Desktop) | RAM indicator renders the pressure dot and the numerical used percentage. | |
| **VAC-B4** | Popover (Desktop) | The popover footer (`Updated every 2s … macOS Native`) is completely visible with 8 pt bottom margin. | |
| **VAC-B5** | Popover (Desktop) | The GPU card renders with full padding and border; the sparkline does not touch the window bottom edge. | |
| **VAC-B6** | Popover (Desktop) | Popover height expands when cores are expanded, without clipping content. | |

*Note*: `VAC-B1` through `VAC-B3` supersede `VAC-14` and `VAC-15`. `VAC-B4` through `VAC-B6` supersede `VAC-22`.

---

## 5. Visual Regression Checks & Verification Procedure

Run these checks to verify the fix:

1. **Menu Bar Combination Verification**:
   - Check all 7 toggle combinations in Settings (`defaults write com.beliantech.statslite ...`).
   - Capture a screenshot of the menu bar using `screencapture -x -R <x,y,w,h> /tmp/mb_check.png`.
   - Make sure that the menu bar item text does not truncate and renders the correct separator dots (`·`).

2. **Popover Content Bounds Verification**:
   - Open the popover with 3 cards enabled.
   - Capture the popover window using `screencapture -x -w /tmp/popover_3cards.png`.
   - Inspect the screenshot. Make sure that the footer text and bottom border are fully visible.
   - Expand the CPU per-core breakdown. Capture `/tmp/popover_expanded.png`. Confirm that the window expands and no card clips.

3. **Unavailable State Verification**:
   - Verify GPU unavailable display (`--%` in menu bar, dashed container in popover) when GPU metrics are nil.

---

## 6. Design-Spec Ambiguities for the Coder

1. **Attributed String vs NSHostingView for Menu Bar Label**:
   SwiftUI `MenuBarExtra` flattens multi-view hierarchies into an `NSStatusBarButton` title. The coder must decide between:
   - Formatted `AttributedString` inside `Text`: simpler, zero AppKit bridging, native performance.
   - `NSStatusItem.button.subviews` hosting: permits native vector shapes, but requires custom lifecycle management.
   The recommended choice is `AttributedString`.

2. **Fixed vs Variable Status Item Width**:
   Use `NSVariableStatusItemLength` or unconstrained width with `.lineLimit(1)`. Do not set a hardcoded frame width on the menu bar item view. Let `.monospacedDigit()` prevent number jitter.
