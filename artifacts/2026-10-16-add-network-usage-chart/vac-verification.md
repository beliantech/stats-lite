# Network Usage card — VAC verification (task 1, plan 2026-10-16-add-network-usage-chart)

Date: 2026-10-16. Branch: `feat/2026-10-16-add-network-usage-chart`.
Verified against `tasks/2026-10-16-add-network-usage-chart/PLAN.md` (VAC-1..VAC-14),
dark and light mode, on the release build.

## Evidence files

- `baseline/dark.png`, `baseline/light.png` — pre-edit baseline (popover 306x453).
- `after/dark.png`, `after/light.png` — popover with the network card (306x586).
- `after/crops/dark_networkcard_4x.png`, `after/crops/light_networkcard_4x.png` — 4x zoom of the card.
- `after/states/loading_dark_2.png`, `after/states/loading_light_2.png` — loading state, live capture.
- `after/states/unavailable_dark.png`, `after/states/unavailable_light.png` — unavailable state,
  offscreen render (the state is unreachable live: the popover starts the loop in `onAppear`
  before first paint).
- `after/states/absent_dark.png` — `showNetwork = false`: no network card.
- `footprint-before.txt`, `footprint-after.txt` — popover footprint, 3 cycles each.

## Ledger

| VAC | Verdict | Evidence |
| --- | --- | --- |
| VAC-1 card below GPU when on, absent otherwise | pass | `after/dark.png`, `after/light.png`, `after/states/absent_dark.png` |
| VAC-2 MetricCardStyle container | pass | both `after` captures; shared `.metricCardStyle()` (DesignTokens.swift:59) |
| VAC-3 header single line, rate right | pass | both `after` captures + 4x crops |
| VAC-4 legend Up/Down/Peak one line, no wrap at 280 pt | pass | both 4x crops |
| VAC-5 chart 56 pt tall, 240 pt wide, no side labels | pass | `.frame(height: 56)` in NetworkSparklineView; full-width trace at inner right edge in `dark_networkcard_4x.png`; row layout measured from captures |
| VAC-6 baseline Y = 28, 0.5 pt separator @ 0.35 | pass | faint mid-chart rule in `light_networkcard_4x.png`; exact values in NetworkSparklineView.swift canvas code |
| VAC-7 upload above in systemRed, download below in systemBlue | pass | both 4x crops (red above rule, blue below, blue reaches bottom at domain peak); `NetworkSparklineViewTests.testUploadStaysInUpperHalf`, `testDownloadStaysInLowerHalf`, `testMirroredPairsAreSymmetricAcrossBaseline` |
| VAC-8 zero = flat line on baseline, no deflection | pass | `testZeroValuesSitExactlyOnTheBaseline`, `testNegativeValueClampsToBaselineNotBeyond` (live capture had non-zero traffic) |
| VAC-9 strokes 1.5 pt round, gradients 0.22 → 0.04 | pass | NetworkSparklineView.swift `StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)` and gradient colors; stroke visible in 4x crops |
| VAC-10 axis `-<historyDuration>s` / `Now`, 9 pt tertiary | pass | both `after` captures (`-120s` / `Now`), no overlap |
| VAC-11 loading: `-- KB/s`, waiting text, 38 pt placeholder | pass | `after/states/loading_dark_2.png`, `after/states/loading_light_2.png` |
| VAC-12 unavailable: dashed container, icon, footnote | pass | `after/states/unavailable_dark.png`, `after/states/unavailable_light.png` |
| VAC-13 composite VoiceOver label, canvas hidden | pass | NetworkCardView.swift `.accessibilityElement(children: .ignore)` + `.accessibilityLabel(summary)` with `Network usage: Upload …, Download …, Combined …, Peak …` / `Network usage unavailable`; NetworkSparklineView.swift `.accessibilityHidden(true)` |
| VAC-14 no clipping of the taller card, 240 pt alignment kept | pass | window grew 453 → 586 pt with the footer and all four cards fully visible in both `after` captures |

All 14 items: **pass**.

## Footprint (3 cycles, 5 s hold, 0.4 s sampler)

| Metric | Before | After |
| --- | --- | --- |
| Cycle peak footprint | 204 / 207 / 208 MB | 204 / 192 / 192 MB |
| Max graphics region across opens | 163.0 MB | 164.0 MB |
| Overall peak footprint | 208.0 MB | 204.0 MB |
| Idle footprint after 40 s tail | 32.0 MB | 33.0 MB |
| Sample failures | 0 | 0 |

The extra card does not move the footprint outside run-to-run noise.
