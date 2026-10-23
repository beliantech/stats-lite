# Plan: TEMP menu-bar metric (two-row, CPU/GPU die sensors)

**Plan ID:** 2026-10-23-temp-menu-bar-metric
**Status:** IN PROGRESS — Phase 0 merged (`fa6b697`), baseline captured (`a458ed1`)

## Tasks

- [x] **T1** — Phase 0 SMC probe + H1/H2 measurement gate. green `fa6b697` (rebased `3b71025`/`9bef218`/`fa6b697`; H1 GO, H2 GO)
- [x] **T1b** — baseline dark/light screenshots before first code edit. green `a458ed1`
- [ ] **T2** — Phase 1+2: `TemperatureMetrics`, degrees formatter, `sampleTemperature()` on provider + SMC impl in `LiveSystemMetricsProvider`, fake conformance, contract tests. red ⏳ · green ⏳ · review ⏳
- [ ] **T3** — Phase 3: `EnabledMetrics.temperature`, `SystemSnapshot.temperature` (joined into `==`), `collectSnapshot` gating, `PreferencesStore.showTemperature` (enabledMetrics insert per F1 + network carve-out). red ⏳ · green ⏳ · review ⏳
- [ ] **T4** — Phase 4: `MenuBarBlockKind.temp`, two-row `MenuBarTempBlockView`, layout/width/accessibility/SettingsView toggle wiring (blueprint verbatim). red ⏳ · green ⏳ · review ⏳
- [ ] **T5** — Phase 5: 32-permutation guards, equality/gating/width tests + VAC verification (dark/light vs baseline). red ⏳ · green ⏳ · review ⏳

Note: GPU-side keys unproven (0 in band; Tg* +10.2..10.5°C directional) — GPU row uses `Tg08`/`Tg0O`+ family as candidates, `--°` fallback load-bearing, support statement in Phase 0 report.
**Risk class:** R1 (new data source + UI ordering edit + undocumented API usage)

## Goal

Add a TEMP metric to the menu bar, ordered **after GPU, before Network**, menu-bar only (no popover card). The block is **two stacked rows in the Network style** (user decision, superseding the earlier single-value/max design):

- Row 1: `CPU 84°`
- Row 2: `GPU 61°`

No tooltip anywhere (user decision). No headline max — both readings are shown, each on its own row. A subsystem with no readable sensor renders `--°` on its row; if neither subsystem is readable both rows show `--°` (GPU `--%` grammar — never hide per-tick, never show `0°` as a fake reading).

## Current state vs target state

| | Current | Target |
|---|---|---|
| Temperature data | None. Zero thermal code in repo (scout-verified) | `AppleSMC` key reads, ride the existing sampler loop |
| Menu order | CPU → MEM → GPU → NET (`MenuBarBlockModel.swift:94-173`) | CPU → MEM → GPU → **TEMP** → NET |
| TEMP view | n/a | Dedicated two-line block, patterned on `MenuBarNetworkBlockView` (`MenuBarStackedItemView.swift:146-199`) |
| Settings | Visible Metrics has 4 toggles (`SettingsView.swift:85-97`) | + Temperature toggle, network-style carve-out from last-one-enabled guard |
| Metric availability | all 4 always render when enabled | TEMP rows render `--°` when a subsystem is unreadable (pinned width/height, no resize) |

## Decisions already made (do not relitigate)

1. **Two stacked rows `CPU N°` / `GPU N°`, Network-style** (user, 2026-10-23). Supersedes the max-of-sensors headline and the earlier average-of-all-cores proposal. No single combined value is displayed.
2. **No tooltip** (user, 2026-10-23). The split lives in the two rows themselves and in the VoiceOver label. No `toolTip` wiring anywhere.
3. **Label format per row:** `CPU 84°` / `GPU 61°`, whole-degree rounding; `--°` placeholder per row. Width pinned (`tempBlockWidth`, network-`networkBlockWidth` style) so values never resize the item — never-resize invariant is hard. Exact pinned width set by measurement in Phase 5 (fit `CPU 100°` worst case).
4. **Sensor route = AppleSMC first** (oracle Q1): `IOServiceOpen` on `AppleSMC`, selector 2, 80-byte `SMCParamStruct`, commands 9/5. No root needed. `IOHIDEventSystemClient` (`AppleARMPMUTempSensor`) is the parked fallback behind the same seam — not built now (violates one-variable-per-experiment).
5. **Hide-on-no-sensors is rejected as per-tick behavior** (oracle correction 3): it violates the pinned-width invariant. Placeholder rows instead. A machine with zero sensors probed once at startup is sticky per session; the Settings toggle renders disabled in that case (an ON toggle showing nothing is a UX defect).
6. **Sampling rides `MetricSamplerActor.collectSnapshot`** — no third loop. Temperature is instantaneous (GPU shape at `MetricSamplerActor.swift:53-55`), no delta base.
7. **`FakeSystemMetricsProvider` gets an explicit conformance update** (oracle correction 2) — never a protocol-extension default (kills sample-counter contract tests at `SystemMetricsProviderContractTests`).
8. **Ordering: extend the existing duplication pattern, do not centralize.** Pin with 32-permutation guard tests. Central registry refactor parked with trigger (fifth metric or second order change).
9. **No `.animation`/`.contentTransition`** in the TEMP view (repo rule). Discrete jumps only.

## Phase 0 — Measurement gate (NO product code before this passes)

Evidence-before-hypothesis rule. Throwaway CLI probe (not committed as product code):

- **H1: AppleSMC exposes ≥1 die-temp key on target hardware.** Enumerate SMC keys, print name+value, then re-run under CPU load (`yes > /dev/null` P-cores, 30 s) and separately under GPU load (Metal). **Falsification: if no CPU-side key rises 15-25 °C under CPU load, the route or key table is dead → stop, evaluate HID route, re-plan.** One variable per round: CPU load round, then GPU load round. **If no GPU-side key moves under GPU load (reviewer F3): continue — the two-row design tolerates a missing GPU sensor via the `--°` row placeholder — but record it in the support statement and verify VAC-4's per-row fallback on hardware.**
- **H2: SMC read latency fits the sampling pass.** Time 1000 open/read/close cycles. **Falsification: if p99 > ~50 ms (`unverified prior`), temperature moves to its own slower cadence.** p99 < 5 ms → ride the standard loop, no further work.
- Probe doubles as per-generation key-table generator (M1-M4 key namespaces differ — cited: exelban/stats #1703/#2249/#1012) and classifies each key as CPU-side or GPU-side (attribution, one variable per round).
- Capture menu-bar baseline screenshot (`scripts/capture_baseline.sh`) before first code edit (repo rule).
- Deliver key tables: CPU candidate keys, GPU candidate keys, classified by load attribution.

## Phases (after Phase 0 GO)

1. **Pure types:** `TemperatureMetrics` (`cpuCelsius: Double?`, `gpuCelsius: Double?`, clamp at init like `GPUMetrics`) in MetricTypes.swift; `MetricFormatters` degrees formatter (`CPU 84°` composition or `degrees(_:) -> String`, nil → `--°`). Formatter unit tests.
2. **Provider:** `sampleTemperature() -> TemperatureMetrics?` added to `SystemMetricsProvider` (`:12`, nil-means-unread contract). `LiveSystemMetricsProvider` SMC section, defer-per-resource style like GPU's IOKit section (`:112-147`), reading candidate key lists from Phase 0, per-subsystem first-plausible-then-max of candidates. Open/read/close per sample (Sendable-safe; cache only on measured need). Same commit: `FakeSystemMetricsProvider` + contract-test rows (counter discipline).
3. **Plumbing:** `EnabledMetrics.temperature` (`1 << 3`; `.all` stays `[.cpu,.memory,.gpu]` — tests pin it). `SystemSnapshot.temperature: TemperatureMetrics?` defaulted `= nil`, **joined into hand-written `==`** (`MetricTypes.swift:214-221` — miss = frozen menu bar). `collectSnapshot` gating. `PreferencesStore.showTemperature` copying the `showNetwork` carve-out (`:27-51`: not in `activeMetricCount`, no last-one-enabled lock, `@AppStorage` next to `:113-119`). **Caution (reviewer F1): the `showNetwork` comment says "Outside enabledMetrics" — that part must NOT be copied.** `PreferencesStore.enabledMetrics` must insert `.temperature` when `showTemperature` is on, else the sampler never reads temperature and both rows are permanent `--°`.
4. **UI:** `MenuBarBlockKind.temp` + block between GPU and network in `MenuBarBlockBuilder.blocks` (`:145-158` insert point); dedicated two-line `MenuBarTempBlockView` modeled verbatim on `MenuBarNetworkBlockView` (`MenuBarStackedItemView.swift:146-199`), two rows `CPU 84°` / `GPU 61°`; extend `MenuBarLayout.length` (`:78-92`) + pinned `tempBlockWidth`; `StatusItemController` call sites `:69`/`:290` (reviewer F2 corrected the second site; re-verify with rg); `MenuBarAccessibility.compositeLabel` (`:15-55`) segment "Temperature: CPU 84 degrees, GPU 61 degrees"; SettingsView toggle `Toggle("Temperature", isOn: $preferences.showTemperature)` in network position (`:85-97`). **No tooltip, no popover card, no sparkline** (menu-bar only → `SparklineTimeAxisView` rule N/A).
5. **Tests + visual verification:** 32-permutation order/length guard tests (templates: `MenuBarBlockBuilderTests:348`, `:70`); snapshot-equality sensitivity (temp-only change ⇒ `==` false); sampler gating counter assertion; formatter cases (both present, CPU-only, GPU-only, neither, 3-digit, negative); width measurement with existing `NSString.size` harness in `MenuBarValueTypographyTests` for `CPU 100°` vs pinned width. Then verify against the VAC below, dark + light, compared to Phase 0 baseline.

## Design Blueprint (designer output — embed verbatim)

- **Part 1 — Inherited tokens:** blocks = text label + SF Symbol glyph (verified in live capture `/tmp/designer/menubar-id5.png`). Canonical tokens: `StatsLite/DesignTokens.swift`, `MenuBarStackedItemView.swift`, `GPUCardView.swift`. `DESIGN.md` absent at repo root. No `.animation`/`.contentTransition`.
- **Part 2 — TEMP spec:** two-line dedicated block in `MenuBarNetworkBlockView` style. Row format `CPU 84°` / `GPU 61°` (whole-degree, monospacedDigit, pinned typography tokens copied from the Network block). Icon: thermometer SF Symbol only if the Network block pattern has an icon; otherwise no icon — copy Network's exact row composition (planner note: Network's observed form is stacked colored arrows; TEMP rows are `CPU`/`GPU` prefixed text in tertiary/value colors per `DesignTokens.swift`). Per-row `--°` placeholder when that subsystem is unreadable, never `0°`, never hide the block per-tick.
- **Part 3 — Ordering:** between GPU and Network; wiring points cited above (scout lines supersede designer's unfinished markers).
- **Part 4 — Settings:** TEMP toggle matches GPU/Network rows exactly, same section, persists via PreferencesStore. Menu-bar only: NO popover card.
- **Part 5 — A11y/edge:** `MenuBarAccessibility.swift` label "Temperature: CPU 84 degrees, GPU 61 degrees" (missing subsystem: "unavailable"); 3-digit `CPU 100°` no clip; sensor flap flips a row to `--°` discretely; dark/light adapts. **No tooltip (user decision).**
- **Evidence:** `/tmp/designer/menubar-id5.png`, `/tmp/designer/menubar-zoom-right.png`.

### VAC (blocking — zero-tolerance policy applies)

- VAC-1: TEMP block appears between GPU and Network in the menu bar.
- VAC-2: TEMP block shows two rows: `CPU N°` on top, `GPU N°` below — single line each, no wrap.
- VAC-3: Each row shows that subsystem's own sensor value (no combined/max number anywhere).
- VAC-4: Unreadable subsystem shows `--°` on its row, never `0°`; block never disappears while enabled.
- VAC-5: No `.animation`/`.contentTransition` anywhere in the TEMP view.
- VAC-6: Row composition, font, size, weight, and spacing match the Network block style — verify per-row, side-by-side screenshot evidence against the Network block (reviewer F4, zero-tolerance policy).
- VAC-7: Values use monospacedDigit; digits do not jitter between ticks.
- VAC-8: Settings toggle matches GPU/Network rows; disabling removes the block immediately.
- VAC-9: `CPU 100°` (3-digit) does not clip, wrap, or shift neighbors (width pinned).
- VAC-10: Accessibility label present and reads both rows (and unavailable state).
- VAC-11: TEMP adds no popover card and no tooltip (menu-bar only).
- VAC-12: Dark and light menu-bar appearance both render correctly — capture both, per-row side-by-side evidence (reviewer F4).
- (375/768/1440 px widths: N/A — menu-bar-only item; checks apply to the menu bar and Settings window.)

## ISC — verification disciplines

| Discipline | What needs verification |
|---|---|
| **visual** | VAC-1..12 against dark + light menu bar; compare to Phase 0 baseline capture; row/typography parity with Network block side-by-side |
| **logic** | 32-permutation order/width guards; snapshot `==` sensitivity; sampler gating counters; both/CPU-only/GPU-only/neither row matrix; formatter edge cases (nil, negative, 3-digit, non-finite); width measurement `CPU 100°` ≤ pinned width |
| **data** | Phase 0 H1/H2 falsification results on real hardware; per-generation key tables with CPU/GPU attribution; no root required confirmed; per-row placeholder on read failure |
| **security** | Undocumented-but-not-private SMC selectors acceptable for this distribution (direct GitHub release, no App Store claim); no new entitlements; no force-unwraps; nil-contract preserved |
| **brief-conformance** | Order = after GPU, before Network ✓; menu-bar only, no card ✓; two rows CPU/GPU ✓ (user decision); no tooltip ✓ (user decision); conventional commits; VAC blocking |

**Known issues (parked):** central menu-order registry refactor (trigger: fifth metric or second order change); `IOHIDEventSystemClient` sensor route (trigger: Phase 0 H1 falsified or key-table coverage fails on a supported generation); cached SMC connection (trigger: measured p99 latency over budget).

**External dependencies / running tasks:** none in flight at plan write time.
