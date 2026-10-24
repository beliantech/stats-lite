# VAC evidence — plan 2026-10-24-activity-monitor-parity-top-processes (Phase 1, M1)

Scope: R1 + R2 + R3. Six VAC items, dark and light, captured via the
`--expand-processes cpu` launch hook plus a harness-only fixture for the
≥100% row. Captures live in this directory. The window grows from 1274 px
(collapsed) to 1500 px (expanded CPU) to absorb the caption; the footer,
`Updated every …s`, and version label stay inside the window and unclipped.

## Method

- Release build: `xcodebuild build -configuration Release`. Full unit suite
  green before capture: 414 tests, 0 failures, TEST SUCCEEDED.
- Display-awake guard: every capture ran under `caffeinate -dis` with the
  in-script `CGDisplayIsAsleep` check. An asleep display stalls popover
  close (AGENTS.md), which invalidates captures.
- Pixel geometry: python3 + Pillow 11.3.0 over the PNGs at 2x capture
  scale (612 px wide for the 280 pt popover window, 2x Retina). Footer band
  measured by an adaptive-luminance scan of the opaque card region.

## VAC table

| VAC | Verdict | Evidence | Notes |
| --- | --- | --- | --- |
| VAC-1 (caption expanded-only) | PASS | `vac2-*-cpu-fixture.png`, `vac3-*-cpu-expanded.png`: caption `System daemons not included` on one line below the last CPU row, both modes. `vac1-*-collapsed-cpu.png`: collapsed `› Top Processes` button with no caption, both modes. `vac1-*-memory.png`: expanded Memory list with rows and no caption, both modes. | Caption gated behind `showsHelperGapCaption`, true only on the CPU card. Collapsed-button and Memory negative captures are the falsifiers. |
| VAC-2 (≥100% row, no clip) | PASS | `vac2-dark-cpu-fixture.png`, `vac2-light-cpu-fixture.png`: fixture row `191.8%` right-aligned in the 44 pt column, full digit string rendered, no clipping. Sub-100 rows (`26.2%`, `21.5%`, `7.4%`, `6.6%`) show one decimal. | Fixture injects fraction 1.918 through the production `processPercentTenth` label path (`STATSLITE_VAC2_FAKE_CPU_FRACTION`, harness-only, inert in production). |
| VAC-3 (real titles, single line) | PASS | `vac3-*-cpu-expanded.png`, `vac2-*-cpu-fixture.png`: live titles `avconferenced`, `VTEncoderXPCServ…` (tail-truncated in the 140 pt column), each row a single 18 pt line, zero wrap. | Title chain (R2) resolves live names; `pi`/`node` case is covered by the live V2 evidence file. |
| VAC-4 (gauge strip) | PASS | `vac2-*-cpu-fixture.png`: top row gauge filled edge-to-edge (max-normalized), lower rows proportionally shorter with the 2 pt minimum. Memory gauges (`vac1-*-memory.png`) keep byte/RAM-proportional fills, unchanged from baseline. | All-zero pass is not captured live; covered by U3 unit test (track-only, no NaN). |
| VAC-5 (container height, footer) | PASS | Pixel scan: expanded captures 1500 px tall, footer text band at y=1341..1473, 26 px bottom margin — footer, `Updated every 5s`, and `v1.0.1 (1)` fully visible, never clipped. Collapsed 1274 px. | Window grows to absorb the caption's ~11 pt line + 8 pt gap; footer stays inside. |
| VAC-6 (VoiceOver) | PASS (test-backed) | Caption is plain readable `Text`, no `.accessibilityHidden`; pinned by the U4 caption-accessibility source-token test. Row labels `name, Process ID N, value` kept by the existing `ProcessDisclosureTests` contract; gauges stay `.accessibilityHidden(true)`. | No runtime VoiceOver session captured; the source-token + view-string tests are the primary evidence per the existing pattern. |

## Live parity evidence (V1–V3)

- V1: `v1-statslite-popover.png` (popover, CPU expanded, live rows) and
  `v1-side-by-side.png` (Activity Monitor, All Processes) captured under
  `caffeinate` with the display awake. Per-core scale (R1) is confirmed by
  the U1 unit table and the fixture capture showing `191.8%`; a same-digit
  live match to AM's instantaneous column is not achievable in one
  screenshot pair because AM averages over its own sampling window (plan §7).
- V2: R2 title chain verified by the argv[0]-first parser tests (U2) plus
  live capture titles resolving through `KERN_PROCARGS2`.
- V3: `backupd`/`kernel_task` are absent from our list (unprivileged scan
  reads 0 of ~218 root processes) while the caption `System daemons not
  included` is visible in every expanded CPU capture — the expected
  Phase-1 outcome confirming R3.

## Deviations

- D1: the two original "collapsed" capture calls seeded the CPU section
  expanded via `--expand-processes cpu`, which does not prove the
  collapsed-state falsifier. Fixed the harness to launch without the hook
  and recaptured a true collapsed state (`vac1-*-collapsed-cpu.png`). No
  verdict was relabeled.
