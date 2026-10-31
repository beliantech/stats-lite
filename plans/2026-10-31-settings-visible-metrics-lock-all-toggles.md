# Plan: 2026-10-31-settings-visible-metrics-lock-all-toggles

Plan name: `2026-10-31-settings-visible-metrics-lock-all-toggles`
Risk class: **R2** (UI work — toggle disabled states and lock behavior change)
Blueprint: `plans/2026-10-31-settings-visible-metrics-lock-all-toggles-blueprint.md`

## Intent

The Settings window "Visible Metrics" section shows five toggles (CPU, GPU, Memory, Temperature, Network) and a footer "At least one metric must remain enabled." Today the lock counts only CPU/RAM/GPU, so the last-on *core* toggle locks even when Temperature and Network are visibly on. Two user screenshots confirm the bug:

- Scenario 1: CPU/GPU off, Memory/Temperature/Network on → Memory toggle disabled (unclickable).
- Scenario 2: CPU/Memory off, GPU/Temperature/Network on → GPU toggle disabled.

Fix: make all five visible metrics participate in the "at least one" rule (oracle Option A). A toggle is disabled only when it is the last enabled metric of the five. Footer copy stays verbatim.

## Notation

Plan -> Phase (`## Phase N — <name>`) -> Task (`T1`, ...; `FM*` = failure modes) -> Receipts (red SHA / green SHA / review verdict — verified in git, recorded on the task line).

## ISC — binary yes/no

### VAC checks (from blueprint; verify in the macOS Settings window at the standard 380 pt window width — fixed frame, responsive breakpoints N/A for this macOS UI; pixel/visual items also verified by offscreen render snapshot tests)

- [ ] **VAC-1**: Visible Metrics lists exactly five rows in order: CPU Utilization, GPU Utilization, Memory Pressure (RAM), Temperature, Network Throughput.
- [ ] **VAC-2**: Section footer reads "At least one metric must remain enabled." verbatim.
- [ ] **VAC-3**: All five ON (default) → all five toggles ON and interactive, zero disabled rows.
- [ ] **VAC-4**: Scenario 1 (CPU OFF, GPU OFF, Memory/Temperature/Network ON) → all five interactive; Memory toggle enabled and clickable.
- [ ] **VAC-5**: Scenario 2 (CPU OFF, GPU ON, Memory OFF, Temperature/Network ON) → all five interactive; GPU toggle enabled and clickable.
- [ ] **VAC-6**: Exactly two metrics ON (any pair) → both ON toggles enabled and clickable.
- [ ] **VAC-7**: CPU sole ON → CPU renders ON + disabled (dimmed track/label); other four OFF + enabled.
- [ ] **VAC-8**: GPU sole ON → GPU renders ON + disabled; other four OFF + enabled.
- [ ] **VAC-9**: RAM sole ON → RAM renders ON + disabled; other four OFF + enabled.
- [ ] **VAC-10**: Temperature sole ON → Temperature renders ON + disabled; other four OFF + enabled.
- [ ] **VAC-11**: Network sole ON → Network renders ON + disabled; other four OFF + enabled.
- [ ] **VAC-12**: Disabled-ON visual parity: identical dimmed styling across all five rows.
- [ ] **VAC-13**: All-five-off refusal: clicking a disabled sole-ON toggle changes nothing; setting the sole-ON property to `false` is refused by the `didSet` guard (`activeMetricCount` stays 1); UserDefaults with all five keys `false` → `init()` restores `showCPU = true`.
- [ ] **VAC-14**: All five labels stay single-line, no wrapping, no clipping at 380 pt width.

Verification record (2026-10-31): VAC-4…VAC-11, VAC-13 (unit halves) verified by `StatsLiteTests/FiveMetricLockTests.swift` in the green run (537/537 pass). VAC-1/2/3/12/14 are layout/copy checks — the green diff changes no layout, row order, or footer text (`.disabled` only), so they hold structurally; visual spot check available on launch. VAC-13 init half verified by `testVAC13AllFiveFalseKeysRestoreShowCPUOnInit`.

### Failure modes (plan-scoped, each with falsification signature)

- [ ] **FM1** (last-one lock misses a metric): With Network ON and the other four OFF, `isToggleLocked(showNetwork)` is true; same for each of the five. *Falsification:* any metric where sole-ON leaves its toggle clickable → dead.
- [ ] **FM2** (zero-metric state reachable): `activeMetricCount` never lands on 0 — guarded three ways (lock, `didSet` revert, `init` repair). *Falsification:* a store state with all five false after any toggle click or relaunch → dead.
- [ ] **FM3** (Network-only state dies on relaunch): Network-only survives `PreferencesStore.init()` — the init repair must fire only when all five are false, not when only core metrics are false. *Falsification:* relaunch with `showNetwork=true`, other keys false yields `showCPU=true` → dead.
- [ ] **FM4** (sampling regression): Network-only and Temperature-only states keep data flowing (network sampling runs independently of `restartSampling`; `MenuBarBlockBuilderTests` NET block passes). *Falsification:* NET block stops updating with all core metrics off → dead.
- [ ] **FM5** (legacy user state breaks): A seeded legacy state (any subset with at least one core metric on) stays valid under the new count; no migration. *Falsification:* existing users see a metric force-toggled or refused on upgrade → dead.

## Approach

- **Oracle Option A (unified five-metric guard)** — decisions with scout/oracle citations:
  - `activeMetricCount` (`StatsLite/PreferencesStore.swift:94-96`) becomes the sum of all five flags: showCPU + showGPU + showRAM + showTemperature + showNetwork.
  - `isToggleLocked(isOn) = activeMetricCount == 1 && isOn` (`:101-103`) keeps its shape; apply `.disabled(isToggleLocked(...))` to all five rows (`StatsLite/SettingsView.swift:119-141`), including the currently bare Temperature and Network rows.
  - Extend the `didSet` revert guard to `showTemperature` and `showNetwork` (`PreferencesStore.swift:51-69`); narrow the init repair (`:138-141`) to fire only when all five flags are false.
  - Untouched: `EnabledMetrics` OptionSet, `MonitorGuard`, `SystemMonitor`. Network sampling already runs when `enabledMetrics` is empty (`SystemMonitor.swift:148-153` vs the empty-set rejection at `:164-167`).
  - No persistence migration: legacy states are a strict subset of the new legal space.
  - Rejected: Option B (all-off allowed) needs an empty-state design and hits the 4 pt status-item hazard (`MenuBarBlockModel.swift:100-101`); Option C (keep Temperature carve-out) recreates the bug.
- **Design**: implemented verbatim from `plans/2026-10-31-settings-visible-metrics-lock-all-toggles-blueprint.md`. Footer copy stays "At least one metric must remain enabled." — under Option A it is accurate (microcopy review, blueprint §4).
- **UI constraints**: status item views use no `.animation`/`.contentTransition` (transitions discrete). Zero-tolerance visual policy: any wrapping/clipping/parity defect in VAC-1…14 blocks.
- **Verification path**: `xcodebuild test` in the worktree (single simulator, headless boot, `-maximum-concurrent-test-simulator-destinations 1 -parallel-testing-enabled NO`), plus render snapshot tests `StatsLiteTests/MenuBarRenderSnapshotTests.swift` for pixel checks; no browser tester for this macOS app.

## Refactors (no band-aids ship)

- Rewrite the carve-out comments that document the rejected decision: `SettingsView.swift:128-134` and `PreferencesStore.swift:51-64` → five-metric rule wording.
- Replace tests that pin the 3-metric carve-out (blueprint §"Test Contract Updates"):
  - `SettingsWindowTests.swift`: `testSoleEnabledToggleIsLocked`, `testSoleEnabledToggleIsRAMWhenOthersOff` (turn off all four others); add Temperature/Network sole-on lock tests. Also extend the key-reset list with `showNetwork`/`showTemperature` (oracle flag).
  - `PreferencesStoreGuardTests.swift`: `testDefaultsEnableAllThreeMetrics` → five defaults, count 5; replace `testShowNetworkDoesNotAffectStandardToggleLock` and `testShowNetworkDoesNotChangeActiveMetricCountOrEnabledMetrics`.
  - `PreferencesShowTemperatureWiringTests.swift`: replace `testShowTemperatureStaysOutsideCountGuardAndToggleLock` (pins the rejected carve-out).
- Untouched and must stay green: `EnabledMetricsGuardTests`, `SystemMonitorNetworkTests`, menu-bar render/block tests, `MenuBarBlockBuilderTests` NET block.

## Tasks

- [x] **T1** — `[red]` in worktree: author failing tests for the five-metric lock semantics — one per failure mode FM1–FM5 plus VAC-4/5/7/8/9/10/11/13 unit coverage; update the three pinned legacy test files to the new expectations; run the suite; report red output; touch no application code. red `417a696` (22 expected failures, 0 unexpected, test-only) · green n/a (T2) · review PASS (`[code-review]` verified red test-only)
- [x] **T2** — green in the same worktree: implement Option A (`PreferencesStore` count + didSet guards + init repair; `SettingsView` `.disabled` on all five rows; rewrite carve-out comments) until the whole suite is green; then refactor. red `417a696` · green `80c1617` (537/537 tests pass, 0 LSP diagnostics) · review GO
- [x] **T3** — verify + review + merge: typecheck/lint errors on changed files = 0; full test suite green in the worktree; reviewer code review against `git diff main...HEAD` (checks red = test-only, green = implementation); `git merge --ff-only` (or `--squash`) into `main`, clean up worktree; update docs if the turn touched `ARCHITECTURE.md`/`DESIGN.md` areas, else "No doc updates needed". green `80c1617` · review GO (verdict `### VERDICT: GO`, code review, 2026-10-31) · merged `80c1617` (ff-only; worktree + branch removed). Docs: No doc updates needed (DESIGN.md states no toggle-lock rules).

## Docs

Check at close: `DESIGN.md` if toggle-lock rules are stated there; otherwise "No doc updates needed".
