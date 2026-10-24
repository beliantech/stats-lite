# Design Addendum: Menu Bar Temperature (TEMP) Subsystem Labels (`C` / `G`)

This design addendum specifies the visual and architectural changes to shorten the menu bar temperature block subsystem labels from `CPU` and `GPU` to single letters `C` and `G`.

This document extends the merged design blueprint `plans/2026-10-23-temp-menu-bar-label-parity.md` (merge commit `0fd0930`). All tokens, fonts (8 pt regular secondary labels, 9 pt regular monospaced-digit values), baseline alignments, vertical row layouts, and 50 pt container widths remain identical to that blueprint.

---

## Visual Baseline Evidence

- Baseline screenshots cited:
  - `artifacts/2026-10-23-temp-menu-bar-metric/visual-vac/menubar-dark-final.png`
  - `artifacts/2026-10-23-temp-menu-bar-metric/visual-vac/menubar-light-final.png`
- Current visual state: Line 1 renders `CPU` plus degree value (`CPU 47°` in dark mode, `CPU 89°` in light mode). Line 2 renders `GPU` plus degree value (`GPU 34°` in dark mode, `GPU 41°` in light mode). Labels render in 8 pt regular `.secondary` color. Values render in 9 pt regular monospaced digits.
- Target visual state: Line 1 renders `C` plus degree value (for example `C 47°`). Line 2 renders `G` plus degree value (for example `G 34°`).

---

## 1. Exact Model and View Edits

### 1.1 Model Edits (`StatsLite/MenuBarBlockModel.swift`)

Update the temperature block instantiation in `MenuBarBlockBuilder.blocks`:
- At `StatsLite/MenuBarBlockModel.swift:193`, change `label: "CPU"` to `label: "C"`.
- At `StatsLite/MenuBarBlockModel.swift:200`, change `secondaryLabel: "GPU"` to `secondaryLabel: "G"`.
- Accompanying documentation comments in `StatsLite/MenuBarBlockModel.swift`:
  - At `StatsLite/MenuBarBlockModel.swift:46`, update doc comment `label holds "CPU", secondaryLabel holds "GPU"` to `label holds "C", secondaryLabel holds "G"`.
  - At `StatsLite/MenuBarBlockModel.swift:66-70`, update `tempBlockWidth` doc comment to reference `G 130°` (30.10 pt) instead of `GPU 130°` (41.48 pt).
  - At `StatsLite/MenuBarBlockModel.swift:176-178`, update comment `label holds "CPU" and secondaryLabel holds "GPU"` to `label holds "C" and secondaryLabel holds "G"`.

### 1.2 View Edits (`StatsLite/MenuBarStackedItemView.swift`)

Update `MenuBarTempBlockView`:
- At `StatsLite/MenuBarStackedItemView.swift:228`, line 1 renders `Text(block.label)`. This line consumes `block.label` directly. No change is required here.
- At `StatsLite/MenuBarStackedItemView.swift:239`, update the defensive fallback string:
  ```swift
  Text(block.secondaryLabel ?? "G")
  ```
  Change `?? "GPU"` to `?? "G"`.
- At `StatsLite/MenuBarStackedItemView.swift:208-212`, update doc comments from `label "CPU"` and `label "GPU"` to `label "C"` and `label "G"`.

---

## 2. VoiceOver and Accessibility Contract

### Decision
The composite VoiceOver label in `StatsLite/MenuBarAccessibility.swift:49-58` must **remain verbose** (`CPU` and `GPU`). It must **not** shorten to `C` and `G`.

### Technical and Usability Justification
1. **Phonetic Clarity**: In English speech synthesis, the spoken letters "C" and "G" sound almost identical (`see` versus `jee`). At fast VoiceOver speech rates, blind users cannot distinguish them reliably. In contrast, "CPU" and "GPU" are distinct, standard spoken acronyms.
2. **Semantic Ambiguity**: The letter "C" collides directly with the Celsius temperature scale. A phrase like "Temperature: C 84 degrees" sounds like "Celsius 84 degrees", hiding the processor context completely.
3. **Accessibility Principle**: Menu bar visual abbreviations exist only to conserve horizontal pixel width on the display. Audio speech synthesis has no pixel width constraints. Under WCAG 2.2 and Apple Human Interface Guidelines, accessibility labels must expand visual abbreviations into unambiguous words.

The announcement format remains unchanged:
```
"Temperature: CPU <value> degrees, GPU <value> degrees"
```

---

## 3. Layout Width and Clearance Verification

### Recommendation
Keep `MenuBarLayout.tempBlockWidth` unchanged at **50.0 pt** (YAGNI).

### AppKit Typography Measurements
Measured with `NSFont.systemFont(ofSize: 8, weight: .regular)` and `NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)`:
- Label `C` (8 pt regular): `5.93 pt` (was `CPU` at `17.32 pt`, delta -11.39 pt)
- Label `G` (8 pt regular): `6.18 pt` (was `GPU` at `17.56 pt`, delta -11.39 pt)
- Inter-item gap: `2.00 pt`
- Value `84°` / `61°` (9 pt regular monospaced digits): `16.08 pt`
- Value `--°` (placeholder): `13.24 pt`
- Value `130°` (clamp maximum reading): `21.92 pt`

### Row Widths and Clearance within 50 pt Block Width
- Typical Line 1 (`C 84°`): `5.93 + 2.00 + 16.08 = 24.01 pt`. Clearance: `25.99 pt`.
- Typical Line 2 (`G 61°`): `6.18 + 2.00 + 16.08 = 24.26 pt`. Clearance: `25.74 pt`.
- Placeholder Line (`G --°`): `6.18 + 2.00 + 13.24 = 21.42 pt`. Clearance: `28.58 pt`.
- Worst-case Clamp Max (`G 130°`): `6.18 + 2.00 + 21.92 = 30.10 pt`. Clearance: `19.90 pt`.

### Clearance Assessment
- The project minimum clearance rule requires at least 2.50 pt (`StatsLite/MenuBarBlockModel.swift:58-60`).
- The worst-case row (`G 130°`) provides 19.90 pt clearance, which exceeds the 2.50 pt minimum by 17.40 pt.
- Keeping 50.0 pt maintains visual width parity with `MenuBarLayout.networkBlockWidth` (`50.0 pt` at `StatsLite/MenuBarBlockModel.swift:65`). Both two-row blocks share an identical fixed slot width.
- Keeping 50.0 pt avoids churn across layout calculation tests (`StatsLiteTests/MenuBarLayoutTests.swift`).

---

## 4. `DESIGN.md` Rule Statement Update

Update `DESIGN.md` at the repository root.

### Current Text (`DESIGN.md:1-4`)
```markdown
# Design

- Menu bar metric labels must use 8 pt regular text with secondary foreground style.
- This rule covers the CPU, MEM, and GPU labels and the two-row TEMP labels CPU and GPU.
```

### Proposed Target Replacement
Replace the second bullet with this one-liner:
```markdown
- This rule covers the CPU, MEM, and GPU labels and the two-row TEMP labels C and G.
```

---

## 5. Test Assertion Migration Checklist

Update the following test assertions:

### 5.1 `StatsLiteTests/MenuBarTempBlockTests.swift`
- `StatsLiteTests/MenuBarTempBlockTests.swift:363`: change `both.label == "CPU"` to `"C"`.
- `StatsLiteTests/MenuBarTempBlockTests.swift:368`: change `both.secondaryLabel == "GPU"` to `"G"`.
- `StatsLiteTests/MenuBarTempBlockTests.swift:436`: change `neither.label == "CPU"` to `"C"`.
- `StatsLiteTests/MenuBarTempBlockTests.swift:441`: change `neither.secondaryLabel == "GPU"` to `"G"`.
- `StatsLiteTests/MenuBarTempBlockTests.swift:314-325`: in `testTempBlockWidthFitsCPU100DegreesAndNeverVariesWithValue`, update the `worstCase` calculation string from `"CPU"` to `"C"` or `"G"`.
- Lines 469, 513, 535 (`testCompositeLabelCarriesTemperatureSegmentIncludingUnavailableRows`): do not change. Keep the verbose composite-string assertions.

### 5.2 `StatsLiteTests/MenuBarTempVerificationTests.swift`
- `StatsLiteTests/MenuBarTempVerificationTests.swift:315`: change `block.secondaryLabel == "GPU"` to `"G"`.
- `StatsLiteTests/MenuBarTempVerificationTests.swift:344`: update failure-message citation from `"GPU"` to `"G"`.
- `StatsLiteTests/MenuBarTempVerificationTests.swift:578`: change `built.first?.label == "CPU"` to `"C"`.
- `StatsLiteTests/MenuBarTempVerificationTests.swift:583`: change `built.first?.secondaryLabel == "GPU"` to `"G"`.

### 5.3 `StatsLiteTests/MenuBarValueTypographyTests.swift`
- `StatsLiteTests/MenuBarValueTypographyTests.swift:593`: change `label: "CPU"` to `label: "C"`.
- `StatsLiteTests/MenuBarValueTypographyTests.swift:601`: change `secondaryLabel: "GPU"` to `secondaryLabel: "G"`.

---

## 6. Numbered Visual Acceptance Checklist (VAC Addendum)

- **VAC-11 (Single Letter Subsystem Labels)**: Line 1 of `MenuBarTempBlockView` displays `C`, line 2 displays `G`, both with `.font(.system(size: 8, weight: .regular))` (replaces VAC-1).
- **VAC-12 (Secondary Style Across Appearances)**: Labels `C` and `G` display with `.foregroundStyle(.secondary)` in dark and light appearance, matching standard category label styling (replaces VAC-2).
- **VAC-13 (Label Persistence When Unavailable)**: If one or both sensors are unavailable (`--°`), labels `C` and `G` remain visible in 8 pt regular secondary text (reaffirms VAC-5).
- **VAC-14 (Worst-Case Clearance within Fixed Block Width)**: Block width stays fixed at 50 pt; clamp-maximum rows (`C 130°` / `G 130°`) keep at least 19.0 pt clearance with zero wrapping or clipping (replaces VAC-8).
- **VAC-15 (VoiceOver Speech Expansion Invariant)**: VoiceOver announcement stays `"Temperature: CPU <X> degrees, GPU <Y> degrees"` (or `"unavailable"`) and must not contract to single letters (reaffirms VAC-9).
