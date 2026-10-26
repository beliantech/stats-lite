# ISC — Menu Bar GPU/MEM Positional Swap

Risk class: R2. Every item is if/then/measurement/bound/kill/owner.

## ISC-1 — Builder block order

- **If** the production swap in `MenuBarBlockBuilder.blocks` lands, **then** `blocks()` with all metrics enabled returns kinds `[.cpu, .gpu, .ram]` and labels `["CPU", "GPU", "MEM"]`; every toggle subset and the 5-block temp/network sequence follow `CPU → GPU → MEM → TEMP → NET`.
- **Measurement:** `MenuBarBlockBuilderTests.swift:54-55`, `:81-82`, `:250` (read `result[1]`), `:349`, `:432`; `MenuBarTempBlockTests.swift:199-200`, `:219-221`; `MenuBarTempVerificationTests.swift:223-224` canonical append.
- **Bound:** exact array equality — no tolerance.
- **Kill condition:** any array still contains `.ram` before `.gpu` → the append move is incomplete; stop, do not touch test expectations again.
- **Owner:** coder (green phase).

## ISC-2 — Rendered visual order

- **If** the builder order lands, **then** the offscreen composition renders CPU ink left of GPU left of MEM, and the three x-origins stay frozen (0.0 px spread) across value sweeps.
- **Measurement:** `MenuBarRenderSnapshotTests.swift` freeze test (`:705-709`, `:744-751`) and composition test (`:1189-1202`).
- **Bound:** strict x order `cpuX < gpuX < memX`; position spread 0.0 px at 2×.
- **Kill condition:** builder returns `[cpu, gpu, ram]` but the render still shows MEM second → H is dead, the view orders independently; stop and re-scout (plan.md Falsification).
- **Owner:** coder.

## ISC-3 — VoiceOver order parity (WCAG 1.3.2)

- **If** the `MenuBarAccessibility.compositeLabel` parts move, **then** the label speaks CPU phrase, then GPU phrase, then Memory Pressure phrase.
- **Measurement:** `MenuBarAccessibilityTests.swift:31`, `:47`, `:64`, `:80`, `:160-161`, `:180-181`, `:238` — exact string equality.
- **Bound:** exact string; single-metric labels (`:94-125`, `:200`, `:219`) unchanged.
- **Kill condition:** visual order swaps but these strings do not → accessibility swap not applied; label diverges from screen (WCAG failure). Owner: coder.

## ISC-4 — Ink-gap bands on the new boundaries

- **If** the order swap lands with unchanged 27 pt frames, **then** the new boundaries measure (2×, both appearances): CPU→GPU 2-digit ∈ [8, 12] px; GPU→MEM 2-digit ∈ [8, 12] px; `|gap(CPU→GPU) − gap(GPU→MEM)| ≤ 1` px; cold fixture CPU→GPU ∈ [17, 20] px, GPU→MEM ∈ [11, 14] px; single-digit GPU at CPU→GPU ∈ [23, 27] px.
- **Measurement:** `MenuBarRenderSnapshotTests.swift` `testStandardBlockGapsAreUniformAndMinimal`, `testExtremeValuesKeepBlockGapsOpen`, `testSingleDigitGpuValueKeepsMemToGpuGapInTwentyThreeToTwentySevenPixels`, `testStackedItemCompositionFillsSlotEdgeToEdge`.
- **Bound:** bands as above. All values are `unverified prior` from the fixed-width geometry (plan.md corrections 1–2) until a measured run confirms them.
- **Kill condition / empirical correction:** if the order is correct (ISC-1, ISC-2 green) but one band fails, rerun that single test with the display awake, record the measured px in the task ledger, adjust only that constant within ±2 px of the prediction. Beyond ±2 px → stop and re-derive the geometry; never chase the number. Two corrections max per constant, then escalate to the planner.
- **Owner:** coder (red predicts, green confirms).

## ISC-5 — Downstream blocks unchanged

- **If** only GPU and MEM swap, **then** the MEM→TEMP inter-block gap still measures 21 ± 1 px and TEMP↔NET is untouched.
- **Measurement:** `MenuBarRenderSnapshotTests.swift` `testInterBlockInkGapsMeasureTwentyOnePixels` (second pair becomes `adjacent(mem, temp)`, `:516-557`), constant `interBlockGap = 21` (`:47`).
- **Bound:** 21 ± 1 px at 2×.
- **Kill condition:** this gap moves → something outside the two-file scope changed temp/network geometry; stop and re-scout.
- **Owner:** coder.

## ISC-6 — Length and slot contract

- **If** the swap is order-only, **then** `MenuBarLayout.length(showCPU: true, showRAM: true, showGPU: true) == 93` pt and the 3-metric composition keeps `leftVoid ≤ 1 px`, `rightVoid ≤ 1 px` at 2×.
- **Measurement:** existing `MenuBarLayoutTests` plus the composition test (`slotVoidCeiling = 1`, `MenuBarRenderSnapshotTests.swift:112`).
- **Bound:** 93.0 pt exact; voids ≤ 1 px each.
- **Kill condition:** length changes → `MenuBarLayout` math was touched; that is a non-goal, revert it.
- **Owner:** coder.

## ISC-7 — No animation regressions

- **If** the diff stays order-only, **then** no `.animation` / `.contentTransition` appears on the status item path and the sparkline axis view is absent from the diff.
- **Measurement:** existing `MenuBarRedrawChurnTests`; `git diff main...HEAD` contains no `.animation(` and no `SparklineTimeAxisView` hunk.
- **Bound:** zero matches.
- **Kill condition:** a match appears → scope creep; revert.
- **Owner:** reviewer (checked at code review).
