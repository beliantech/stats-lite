Plan name: 2026-10-27-runtime-smc-key-discovery

# Runtime SMC Key Discovery

**Risk class:** R1 (sampling internals change, no UI/layout change, no API/schema/auth/deps)

## Intent

CPU and GPU temperature keys are discovered at runtime on any Apple Silicon
Mac. No per-machine or per-generation key list survives in production code.
Today `sampleTemperature()` reads two hardcoded lists
(`StatsLite/LiveSystemMetricsProvider.swift:214-237`); the GPU list was
measured on one machine (this M5 Max Mac Studio) and a MacBook Air M2
renders the GPU placeholder forever, because those keys do not exist there.

## ISC

- [ ] **FM1** — A machine where attribution fails shows `--°` on the
      affected row, never a wrong number and never `0°`.
- [ ] **FM2** — `#KEY` unreadable does not kill discovery: the
      consecutive-failure index scan (pattern in `tools/smc-probe/main.swift:225`)
      recovers enumeration, or both rows fall back to `--°`.
- [ ] **FM3** — Aggregation consumes only keys that pass three explicit
      filters, each unit-tested: (a) prefix filter — exact, case-sensitive
      `Tg*` for GPU, `Tp*` for CPU, nothing else; (b) plausibility filter —
      `flt ` size 4, finite, −20…130 °C; (c) movement filter — a key joins
      the aggregate once its own sampled series has moved ≥ 2 °C within the
      trailing 60 ticks; if no key in a domain has moved yet, the domain
      aggregates all prefix+plausibility keys so a working machine never
      renders blank by construction. Production runs no load rounds; the
      movement filter works on the app's own samples.
- [ ] **FM4** — Enumeration cost never runs on the sampler's hot path:
      the key table is built once per launch; per-sample work stays
      read-only over the cached table.
- [ ] **FM5** — No hardcoded temperature key list remains in
      `StatsLite/` (test asserts the literal `Tg6I` set is gone).
- [ ] **VAC-1** — Menu-bar TEMP block renders byte-identical to the
      committed snapshots (`StatsLiteTests/MenuBarRenderSnapshotTests.swift`)
      in dark and light, when both rows have values.
- [ ] **VAC-2** — CPU-only fixture renders live C row + `--°` G row with
      tertiary tint (`StatsLiteTests/MenuBarTempBlockTests.swift:386`).
- [ ] **FM6** — The merged build still reports CPU and GPU temperature on
      the M5 Max Mac Studio (regression check; today's behavior preserved).

## Approach

### Decisions already made (do not relitigate)

1. **Discovery = runtime enumeration.** Read the key table once per launch
   (`#KEY`, fallback index scan), keep keys of type `flt ` size 4 only —
   the app is Apple Silicon-only and its decoder accepts nothing else
   (`LiveSystemMetricsProvider` read path); Intel fixed-point families
   (`sp..`/`fp..`) are out of scope, not "kept for safety". Group by
   two-character prefix, attribute via one `domain(forPrefix:)` seam.
   Evidence: `artifacts/2026-10-27-runtime-smc-key-discovery/phase0-m5max-recheck.md`.
2. **Attribution = per-key delta gap**, `(dGPU − dCPU) ≥ +5 °C` GPU-side,
   `≤ −5 °C` CPU-side (`AMBIGUITY_GAP`, `tools/smc-probe/analyze_attribution.py:34`).
   Not an absolute cross-domain level: that variant measures rail sensors
   and is falsified on M5 Max data (gap −8.5 °C, recheck artifact).
3. **The 15 °C rise band applies to the CPU round only.** Measured max GPU
   round rise = +10.5 °C across all 296 keys (recheck artifact).
4. **Aggregate inputs are `Tg*` (GPU) and `Tp*` (CPU)** — the two families
   that separate clean, 29/0 and 19/0. `TVD*` stays out of the CPU
   aggregate (hottest rail, not CPU). `Tm*`/`TRD*`/`TUD*` stay out until a
   machine's measurement attributes them.
5. **Exclusion has two separate forms, never mixed:** Phase 0 *gates* use
   "flat in both load rounds (< 2 °C)" on probe data (66/296 keys on M5
   Max, recheck artifact) — load rounds are a measurement tool, not
   production code. *Production* uses the FM3 movement filter over the
   app's own samples, which needs no load and no per-machine list.
6. **No persisted cache.** One in-memory table per launch; enumeration cost
   is measured in T5 before any threshold exists.
7. **Rejected:** IOHID/PMU descriptions (no CPU/GPU labels on Apple
   Silicon, private SPI), `powermetrics` (root-only). The app must stay
   unsandboxed — `codesign -d --entitlements -` shows none today; verify
   again in T4.
8. **Nil contract unchanged:** `TemperatureMetrics` member nil →
   `MetricFormatters.swift:51` returns `--°`.

### Refactors

- `LiveSystemMetricsProvider` splits into: enumerator (`#KEY`/index scan),
  domain resolver (`domain(forPrefix:)`), sampler (reads cached table).
  The hardcoded lists are deleted, not shadowed.
- The probe's enumeration helpers move to a target shared with the app or
  are re-implemented behind the enumerator seam — one implementation, no
  drift copy.

## Evidence

Phase 0 gates (falsification signatures). M5 Max: **done** (recheck
artifact, this session, existing logs). MacBook Air M2: **blocked on
access**.

- **H1 existence** — falsification signature: on the Air, run
  `./probe --enumerate`; count keys matching prefix `Tg`, type `flt `, size
  4, finite decode. Stop rule: count = 0 → enumeration design is dead on
  base Apple Silicon; stop before T3, ship nothing, record the support
  statement (CPU row keeps working via `Tp*` only if the CPU round also
  passes). M5 Max: 84 `Tg` keys ✓. Air: ⏳.
- **H2 attribution** — two single-variable rounds (`gpuload`, then CPU
  load), settle between, 10 ticks each: ≥ 1 `Tg*` key `≥ +5` and **0**
  `Tg*` `≤ −5`; ≥ 1 `Tp*` key `≤ −5` and **0** `Tp*` `≥ +5`. M5 Max:
  29/0 and 19/0 ✓. Air: ⏳. **If H2 dies on the Air: stop, fall back to
  CPU-only temperature, GPU row keeps `--°` (10-23 precedent), and record a
  support statement. No code edit happens after a dead gate.**
- **H3 exclusion** — falsification signature: from the two Air rounds,
  the flat set = keys moving < 2 °C in *both* rounds; then verify the set
  is non-empty and disjoint from the H2-passing keys (a key that both
  passes H2 and sits flat is contradictory data). Stop rule: set empty, or
  overlap non-empty → the movement criterion is dead for that machine;
  drop the movement filter for it, aggregate with prefix + plausibility
  only, and record the rail-key-in-`max()` risk in the artifact. M5 Max:
  66 flat keys, disjoint from the 29 H2-passing `Tg` keys ✓. Air: ⏳.

Phase 0 commands and log contract: `swiftc tools/smc-probe/main.swift -o probe`,
then `./probe --watch` runs named `h1-baseline.log`, `h1-cpu-load.log`,
`h1-cool.log`, `h1-gpu-load.log`, `h1-gpu-cool.log` (fixed filenames —
`tools/smc-probe/analyze_attribution.py:219-227` hardcodes them), one
variable per round. The delta-gap gate is computed from those logs with the
recheck script; the analyzer's per-key report is evidence, not the gate.

## Plan of attack

- [x] **T1** — M5 Max delta-gap recheck from existing h1 logs. done
      (evidence: `artifacts/2026-10-27-runtime-smc-key-discovery/phase0-m5max-recheck.md`)
- [ ] **T2** — Phase 0 on the MacBook Air M2: five rounds, analyzer +
      delta-gap gate, report to `artifacts/2026-10-27-runtime-smc-key-discovery/phase0-report.md`.
      Gate stop applies. ⏳ *blocked: no route to the Air yet*
- [ ] **T3** — red: one failing test per `FM1`–`FM5` + `FM6`; fixtures for
      the M5 Max key set (296 keys, from h1 logs), the Air key set (from
      T2), and unreadable-`#KEY` (index-scan fallback). red ⏳ · green ⏳ · review ⏳
- [ ] **T4** — green: enumerator + `domain(forPrefix:)` + cached table;
      delete hardcoded lists; verify `codesign` entitlements unchanged.
      red ⏳ · green ⏳ · review ⏳
- [ ] **T5** — measure enumeration cost and per-sample cost on both
      machines; record numbers in the artifact dir. Add a budget assertion
      only if a threshold is proven by measurement. red ⏳ · green ⏳ · review ⏳
- [ ] **T6** — VAC pass: snapshot tests + nil-row logic tests green
      (`MenuBarRenderSnapshotTests.swift`, `MenuBarTempBlockTests.swift`).
      red ⏳ · green ⏳ · review ⏳
- [ ] **T7** — plan compliance review → reviewer GO → squash-merge to
      `main`; record merge SHA here. review ⏳
- [ ] **T8** — field verification: merged build on the Air shows a live GPU
      row under load; M5 Max regression (FM6) rechecked. ⏳

## Dependencies

- **Route to the MacBook Air M2** (SSH target, or the user runs T2's probe
  commands and pastes the logs). Blocking for T2 → T7.
- M5 Max available for T5/T6 (this machine).
- `gpuload` built on the Air (`swiftc tools/smc-probe/gpuload.swift -o gpuload`).

## References

- `plans/2026-10-23-temp-menu-bar-metric.md:61` — predicted per-generation
  tables; shipped one static list.
- `artifacts/2026-10-23-temp-menu-bar-metric/phase0-report.md:22`,
  `:115-116` — why 0 keys classified GPU-side (band, not sensors).
- `tools/smc-probe/main.swift:225-244` — `#KEY` + index-scan enumeration.
- exelban/stats#1012, btop#1653 — community `Tg` sets for M1/M2 (prior only).

## Status

- [x] T1 — M5 Max recheck (gate fixed with measured data)
- [ ] T2 — Air Phase 0 (blocked on access)
- [ ] T3 — red · [ ] T4 — green · [ ] T5 — latency · [ ] T6 — VACs
- [ ] T7 — review + merge · [ ] T8 — field verification
- Status 2026-10-27: advisor review applied — absolute-gap H2 replaced by
  the delta-gap gate (falsified on our own logs), cache cut, H3 restated
  under load, conventions fixed. User approval 2026-10-27.
- Status 2026-10-27: plan-review NO GO (4 findings) — fixed: FM3 rewritten
  as three unit-testable production filters (prefix/plausibility/
  movement), explicit falsification signature + stop rule added to H1 and
  H3, T1 checkbox reconciled, speculative Intel `sp../fp..` types removed
  from the enumeration filter. Re-review requested.
- Status 2026-10-27: plan-review **GO** (re-review, all 4 findings verified
  resolved). Plan committed; T2 is the only open blocker.
