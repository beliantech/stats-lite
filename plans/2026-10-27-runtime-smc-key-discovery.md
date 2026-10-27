Plan name: 2026-10-27-runtime-smc-key-discovery

# Runtime SMC Key Discovery

**Risk class:** R1 (sampling internals change, no UI/layout change, no API/schema/auth/deps)

## Intent

CPU and GPU temperature keys are discovered at runtime on any Apple Silicon
Mac. No per-machine or per-generation key list survives in production code.
Today `sampleTemperature()` reads two hardcoded lists
(`StatsLite/LiveSystemMetricsProvider.swift:214-237`); the GPU list was
measured on one machine (this M5 Max Mac Studio) and a MacBook Air M2
renders the GPU placeholder forever. Hypothesis: the Air's SMC exposes no
key in our list — an `unverified prior` (community reports say M2 exposes
other `Tg*` keys), never measured on that machine. The fix does not depend
on the hypothesis: enumeration queries whatever the machine has, and a
machine with no GPU sensor key keeps the `--°` row by design (FM1).

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

Pre-code gates run on the only machine with access, the M5 Max: **all
three measured and passing** (recheck artifact, this session, existing
logs). The MacBook Air M2 round is **deferred to T8** — user directive
2026-10-27: no access to that machine. What is measured: M5 Max
attribution (H1–H3 passing, recheck artifact) and the nil → `--°`
contract (unit-tested, FM1). What stays open: attribution correctness on
the Air. Until T8 measures it, the Air GPU row may display a value whose
domain is an `unverified prior` — that residual risk is accepted under
the user directive 2026-10-27, not claimed away. Air root cause and Air
attribution remain `unverified prior` until T8.

- **H1 existence** — falsification signature: `./probe --enumerate`;
  count keys matching prefix `Tg`, type `flt `, size 4, finite decode.
  M5 Max: 84 `Tg` keys ✓. Stop rule (T8, Air): count = 0 → no GPU
  enumeration on that machine; GPU row keeps `--°` (FM1), record a
  support statement, no code change required — the mechanism is proven
  correct by returning nil.
- **H2 attribution** — two single-variable rounds (`gpuload`, then CPU
  load), settle between, 10 ticks each: ≥ 1 `Tg*` key `≥ +5` and **0**
  `Tg*` `≤ −5`; ≥ 1 `Tp*` key `≤ −5` and **0** `Tp*` `≥ +5`. M5 Max:
  29/0 and 19/0 ✓. If H2 dies on the Air at T8: the shipped GPU row on
  that machine shows an attribution-unverified value (it does **not**
  self-revert to `--°` — `--°` only covers absence, H1). Remediation is a
  follow-up plan opened at that time (a new plan file, not this one),
  never an in-place post-merge
  edit; the support statement and raw rounds go in the artifact.
- **H3 exclusion** — falsification signature: from the two Air rounds,
  the flat set = keys moving < 2 °C in *both* rounds; then verify the set
  is non-empty and disjoint from the H2-passing keys (a key that both
  passes H2 and sits flat is contradictory data). Stop rule: set empty, or
  overlap non-empty → the movement criterion is unvalidated for that
  machine; remediation is a follow-up plan (new plan file — same rule as
  H2, no in-place post-merge edit), and the rail-key-in-`max()` risk goes
  in the artifact. M5 Max: 66 flat keys, disjoint from the 29 H2-passing `Tg`
  keys ✓. Air rounds run at T8 with this rule.

Phase 0 commands and log contract: `swiftc tools/smc-probe/main.swift -o probe`,
then `./probe --watch` runs named `h1-baseline.log`, `h1-cpu-load.log`,
`h1-cool.log`, `h1-gpu-load.log`, `h1-gpu-cool.log` (fixed filenames —
`tools/smc-probe/analyze_attribution.py:219-227` hardcodes them), one
variable per round. The delta-gap gate is computed from those logs with the
recheck script; the analyzer's per-key report is evidence, not the gate.

## Plan of attack

- [x] **T1** — M5 Max delta-gap recheck from existing h1 logs. done
      (evidence: `artifacts/2026-10-27-runtime-smc-key-discovery/phase0-m5max-recheck.md`)
- *(T2 removed 2026-10-27 — Air rounds live in T8; no other task
  renumbered.)*
- [x] **T3** — red: one failing test per `FM1`–`FM5` + `FM6`; fixtures for
      the M5 Max key set (296 keys, from h1 logs), a second-generation
      key set built from the M1/M2 community prior (marked "prior fixture,
      not evidence"), and unreadable-`#KEY` (index-scan fallback).
      red `60b3111` · green ⏳ · review ⏳
      (12 tests, `StatsLiteTests/RuntimeSMCKeyDiscoveryTests.swift`; red =
      seam-API compile failure, same practice as 2026-10-23 T2 red
      `667b04a`; FM6 cited to existing contract tests; red output:
      `artifacts/2026-10-27-runtime-smc-key-discovery/red-t3.txt`)
- [ ] **T4** — green: enumerator + `domain(forPrefix:)` + cached table;
      delete hardcoded lists; verify `codesign` entitlements unchanged.
      red ⏳ · green ⏳ · review ⏳
- [ ] **T5** — measure enumeration cost and per-sample cost on this
      machine (Air numbers deferred with T8); record in the artifact dir.
      Add a budget assertion only if a threshold is proven by measurement. red ⏳ · green ⏳ · review ⏳
- [ ] **T6** — VAC pass: snapshot tests + nil-row logic tests green
      (`MenuBarRenderSnapshotTests.swift`, `MenuBarTempBlockTests.swift`).
      red ⏳ · green ⏳ · review ⏳
- [ ] **T7** — plan compliance review → reviewer GO → squash-merge to
      `main`; record merge SHA here. review ⏳
- [ ] **T8** — field verification, deferred until the Air is reachable:
      run the five-round bundle (commands in Evidence), apply H1/H2/H3 with
      the stop rules above, write
      `artifacts/2026-10-27-runtime-smc-key-discovery/phase0-report.md`;
      plus M5 Max regression (FM6) rechecked after merge. ⏳
      *blocked: no access to the Air (user, 2026-10-27)*

## Dependencies

- **MacBook Air M2 access: not available** (user, 2026-10-27). Nothing
  before T8 blocks on it; T8 stays open until access exists.
- M5 Max available for T4/T5/T6 (this machine).

## References

- `plans/2026-10-23-temp-menu-bar-metric.md:61` — predicted per-generation
  tables; shipped one static list.
- `artifacts/2026-10-23-temp-menu-bar-metric/phase0-report.md:22`,
  `:115-116` — why 0 keys classified GPU-side (band, not sensors).
- `tools/smc-probe/main.swift:225-244` — `#KEY` + index-scan enumeration.
- exelban/stats#1012, btop#1653 — community `Tg` sets for M1/M2 (prior only).

## Status

- [x] T1 — M5 Max recheck (gate fixed with measured data)
- (T2 removed — Air rounds folded into T8 by user directive)
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
  resolved). Plan committed as `6cb3413`.
- Status 2026-10-27: **gate amendment** (user directive: no Air access,
  "no hardcoding keys"): pre-code gates are M5 Max only (measured, passing);
  the Air falsification round moved to T8 as a post-merge field check with
  the no-regression argument recorded under Evidence. Risk class unchanged
  (R1). Re-review requested for the gate change.
- Status 2026-10-27: gate-amendment review NO GO (3 findings) — fixed:
  the no-regression paragraph now states measured vs open and marks the
  Air residual risk accepted-by-directive instead of claiming it away;
  H2/H3 stop rules now say attribution-unverified display + follow-up plan
  (no post-merge `--°` self-revert claim, no in-place edits); T2 removed
  from the task list with the removal noted. Re-review requested.
- Status 2026-10-27: gate-amendment review round 2 **GO** (all 4 findings
  verified resolved, negative checks passed). Amendment committed as
  `612b276`.
- Status 2026-10-27: **T3 red complete** — commit `60b3111`, 12 failing
  tests over the seam API, no application code touched. VAC baseline in
  worktree re-run green (15/15 snapshots, 9/9 temp-block). T4 next.
