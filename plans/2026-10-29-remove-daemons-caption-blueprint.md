# Design Blueprint — Remove the "System daemons not included" caption

Plan date: 2026-10-29. Scope: remove the helper-gap caption from the Top Processes
card. The caption is factually wrong — user-session daemons such as WindowManager,
corespotlightd, and sharingd appear in the list. No replacement text.

## Visual evidence (verified captures)

Captured from the Release binary with the harness hooks
`--open-popover --popover-cycles 1 --popover-hold 45 --expand-processes cpu|memory
--capture-appearance dark`, window resolved by owner PID, display awake
(`CGDisplayIsAsleep(0) == 0`):

- `tmp/designer-2026-10-29-caption/v2-cpu-expanded-dark.png` — CPU card expanded.
  The caption sits on one line, 9 pt tertiary, one 8 pt gap below the fifth row,
  above the card's 10 pt bottom padding.
- `tmp/designer-2026-10-29-caption/v2-memory-expanded-dark.png` — Memory card
  expanded. No caption. The last row is followed directly by the card's 10 pt
  bottom padding. This is the exact bottom geometry the CPU card must match after
  removal.

The popover is fixed at 280 pt width (`StatsLite/PopoverContentView.swift:129`) with
free height and has no responsive breakpoints. All VAC items verify at that fixed
width in dark and light appearance. Mobile/tablet/desktop viewports do not apply.
Menu bar pixels are untouched by this change.

## 1. What is removed

| Item | Location |
| --- | --- |
| Caption flag declaration + doc comment | `StatsLite/TopProcessesView.swift:26-28` (`var showsHelperGapCaption: Bool = false`) |
| Caption constant + doc comment | `StatsLite/TopProcessesView.swift:35-38` (`static let helperGapCaption = "System daemons not included"`) |
| Caption render block incl. 8 pt top padding | `StatsLite/TopProcessesView.swift:58-64` (`if showsHelperGapCaption { ... .padding(.top, 8) }`, padding at `:63`) |
| CPU-only wiring | `StatsLite/CPUCardView.swift:65` (`showsHelperGapCaption: true`) |

No other app code reads `showsHelperGapCaption` or the caption string. The Memory
card never passed the flag (`StatsLite/MemoryPressureCardView.swift:77-83`), so its
call site needs no edit when the parameter disappears. The `plans/` and
`artifacts/` documents that mention the caption are historical records. Do not
edit them.

## 2. Resulting layout of the Top Processes card

- The section is `VStack(alignment: .leading, spacing: 0)`
  (`StatsLite/TopProcessesView.swift:40`). No spacing is reserved for the caption
  outside the removed block. Deleting `:58-64` reclaims the whole caption band
  (8 pt padding + one 9 pt text line) with no orphaned gap.
- After removal the fifth row's bottom edge meets the card's 10 pt padding from
  `MetricCardStyle` (`StatsLite/DesignTokens.swift:120-135`,
  `.padding(10)`, radius 8 continuous, 0.5 pt separator stroke). This equals the
  expanded Memory card's bottom geometry today — see the memory capture above.
- The CPU card shrinks by the caption band when expanded. Cards below move up via
  the shared stack `VStack(spacing: 6)` (`StatsLite/PopoverContentView.swift:79`,
  container padding at `:119-121`). Nothing else shifts. The card does not look
  truncated: its bottom padding matches every sibling card.
- Collapsed state, loading line, and empty line are structurally unchanged. The
  `.transition(.opacity)` on the section (`StatsLite/CPUCardView.swift:68`) is
  unaffected.

## 3. Other affected views

None. `rg` shows the only consumers are `TopProcessesView.swift` and
`CPUCardView.swift:65`, plus tests. `GPUCardView` and `NetworkCardView` carry no
Top Processes section. The disclosure button
(`StatsLite/TopProcessesView.swift:177-247`) never rendered the caption.

## 4. Test impact (`StatsLiteTests/ProcessDisclosureTests.swift`)

- `testHelperGapCaptionTokensPlaceItInTheExpandedCPUSectionOnly` (`:429-486`):
  rework. Keep the gauge-basis asserts (`:470-471`, `:485-486`). Flip the caption
  asserts (`:433-443`, `:445-461`, `:464-469`) to negative source guards:
  no `System daemons`, no `helperGapCaption`, no `showsHelperGapCaption` anywhere
  in `StatsLite/`. Keep the Memory-card negative asserts (`:472-484`) as-is.
- `testHelperGapCaptionRendersInAllThreeExpandedSectionStates` (`:489-539`):
  replace. It constructs `showsHelperGapCaption: true` at `:500`, `:512`, `:523`
  and fails to compile after the parameter is removed. Rewrite with the
  parameter-free init and assert the populated, loading, and empty states render
  no caption while the loading and empty placeholder lines still render.
- `testCollapsedDisclosureButtonCarriesNoHelperGapCaption` (`:541-551`): delete.
  It is caption-specific and the negative source guard covers the invariant.
- `SystemMonitorProcessSamplingTests.swift:364` uses `placeholderText` only. No
  change. `MenuBarRenderSnapshotTests.swift` covers menu bar blocks only and has
  no popover coverage. No new render test is required for this change; the
  popover VAC items verify through the capture harness above, per AGENTS.md.

## 5. Numbered Visual Acceptance Checklist (VAC-R)

Verify each item by rendering the popover with the capture harness. Run with the
display awake. Do not close the popover tool while `CGDisplayIsAsleep == 1`.

- VAC-R1 — Expanded CPU card, populated state, dark and light: the string
  `System daemons not included` appears nowhere in the popover. Evidence baseline:
  `tmp/designer-2026-10-29-caption/v2-cpu-expanded-dark.png`.
- VAC-R2 — Expanded CPU card, populated state: the fifth row's bottom edge is
  followed directly by the card padding band. The 8 pt caption gap is gone and no
  empty band remains in the card. The bottom band matches the expanded Memory
  card's bottom band. Evidence baseline:
  `tmp/designer-2026-10-29-caption/v2-memory-expanded-dark.png`.
- VAC-R3 — Expanded CPU card: the five rows keep uniform vertical rhythm and stay
  anchored to the disclosure button above. Row heights and gauges are unchanged.
- VAC-R4 — Expanded CPU card, loading state (`Sampling top processes…`) and empty
  state (`No process data available`): the placeholder line renders with no
  caption below it and the card bottom band equals VAC-R2.
- VAC-R5 — Collapsed CPU disclosure: chevron, label, and cue dot are unchanged.
  No caption text leaks into the collapsed card.
- VAC-R6 — Memory card, expanded and collapsed: unchanged. No caption in any
  state. RAM-fraction gauges unchanged.
- VAC-R7 — Cards below the CPU card (Memory, GPU, Network) keep 6 pt stack gaps
  and correct order. The popover footer stays visible. No clipped card borders.
- VAC-R8 — Source guard test: `StatsLite/` contains no `System daemons not
  included`, no `helperGapCaption`, and no `showsHelperGapCaption`. The test
  suite compiles and passes.

These items supersede the caption acceptance criteria U4 in
`plans/2026-10-24-activity-monitor-parity-top-processes.md`. That plan's other
acceptance criteria stay in force.
