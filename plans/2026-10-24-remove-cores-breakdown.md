# Plan: Remove Cores Breakdown entirely (popover + Settings)

- Branch: `feature/remove-cores-breakdown` (worktree at `<repo>/worktrees/remove-cores-breakdown`)
- Owner: one coder spawn, reviewer gate before merge
- Design authority: `designer-cores-removal` blueprint (5 parts, VAC-1..VAC-11), grounded in `DESIGN.md` and live captures at `/tmp/designer/{dark,light}.png`

## Goal

Delete the Cores Breakdown feature from the popover CPU card and delete its toggle from Settings. No replacement UI fills the gap; the card just gets shorter.

## Evidence attribution

No root cause to name: this is a requested deletion, not a bug fix. All attribution comes from the scout report (`scout-cores-refs`) with `file:line` citations below. Shared code ownership measured: the aggregate CPU value is a sum of per-core counters, so the sampler's per-core loop stays.

## Functional scope

IN:
- Remove Cores Breakdown disclosure + per-core grid from the CPU card.
- Remove `Show Per-Core CPU Breakdown` toggle from Settings > Display Options.
- Remove `showCoreBreakdown` preference plumbing (`PreferencesStore`, `@AppStorage`, init seed).
- Remove `coresExpanded` state, binding, and animation from `PopoverContentView`.
- Update tests that assert on the key/toggle; update README mentions.
- Keep the orphaned `showCoreBreakdown` UserDefaults key in place (no migration code; UserDefaults ignores unregistered keys — designer Part 5.1).

OUT:
- Per-core sampling (`LiveSystemMetricsProvider.swift:19-64`) and `CPUTicks`/`CPUMetrics` data model (`MetricTypes.swift:31-66`) — required for the aggregate sum.
- `CPUTicks.aggregate`, `CPUMetrics.totalUsage`, `MetricMath.computePercentages` — feed menu bar, headline, sparkline, Top Processes cue.
- GPU card, Top Processes, temperature, network — unrelated.
- pbxproj edits — project uses file-system-synchronized groups.

## Files

| File:line | Change |
| --- | --- |
| `StatsLite/CPUCardView.swift:15,16,19,53-60,88-140,175-180` | Drop `preferences` param, `coresExpanded` binding, `coreCount`, `disclosure`, `coreGrid`, `coreRow`, `coreColor`. Card body: header → sparkline → time axis → Top Processes button (4 pt gap). |
| `StatsLite/PopoverContentView.swift:19,21,60-61,97,131,134` | Drop `@State coresExpanded`, `preferences:`/`coresExpanded:` args to `CPUCardView`, `.animation(... value: coresExpanded)` modifier, and the `StatusItemController` comment reference (`StatusItemController.swift:281`). |
| `StatsLite/SettingsView.swift:112` | Delete `Toggle("Show Per-Core CPU Breakdown", ...)`. Display Options keeps only History Duration picker. |
| `StatsLite/PreferencesStore.swift:92-97,133,146` | Delete `showCoreBreakdown` property, `@AppStorage("showCoreBreakdown")`, init seed line. |
| `StatsLiteTests/SettingsWindowTests.swift:22,119` | Remove key from reset list; remove introspection string assertion. |
| `StatsLiteTests/PreferencesStoreGuardTests.swift:23,57` | Remove key from list + assertion. |
| `StatsLiteTests/PreferencesShowTemperatureWiringTests.swift:28` | Remove key from list. |
| `README.md:16,18,20,25,30,48` | Remove per-core breakdown mentions (line 16 already stale). |

Not touched: `MetricSamplerActor.computeCPU` (`MetricSamplerActor.swift:374-396`), `SystemMetricsProviderContractTests.swift:159-219`, `CPUTicksTests`, `MetricTypesTests.swift:51-53` — data model unchanged.

## Structured tests

`StatsLiteTests/` (run after each change):

- `RemoveCoresBreakdownTests.swift` (new):
  - `testSettingsWindowNoLongerContainsCoreBreakdownToggle` — introspection over `SettingsView` body; asserts no "Show Per-Core CPU Breakdown" row.
  - `testPreferencesStoreHasNoShowCoreBreakdownProperty` — mirror-style introspection; asserts `showCoreBreakdown` selector absent from `PreferencesStore`.
  - `testCPUCardBodyHasNoCoreGridElements` — introspection over `CPUCardView` body; asserts no `coreGrid`/`coreCount`/`disclosure` identifiers and no "Cores Breakdown" string.
  - `testPopoverContentViewHasNoCoresExpandedState` — introspection over `PopoverContentView`; asserts `coresExpanded` absent.
- Update existing: `SettingsWindowTests.swift`, `PreferencesStoreGuardTests.swift`, `PreferencesShowTemperatureWiringTests.swift` per table above.
- Regression guard (must stay green, unchanged): `MetricSamplerActorTests.swift:200-238` (per-core ticks), `SystemMetricsProviderContractTests.swift:159-219`.

Run: `xcodebuild test -scheme StatsLite -destination 'platform=macOS'` (or the repo's test script if one exists — coder verifies).

## VAC (from blueprint)

- VAC-1/2: no `Cores Breakdown (N Cores)` row, no `Core N` grid anywhere in popover (collapsed + expanded).
- VAC-3: Top Processes button sits directly under `SparklineTimeAxisView`, 4 pt gap, no dead space.
- VAC-4: collapsed CPU card ≈112 pt (was ~132 pt).
- VAC-5: Top Processes accordion still animates 200 ms without clipping the sparkline.
- VAC-6: popover stays 280 pt wide; total height ~20 pt shorter than `/tmp/designer/dark.png` baseline.
- VAC-7/8: Settings Display Options contains only History Duration picker; no core toggle.
- VAC-9: Settings window still 380×340.
- VAC-10: legacy installs with orphan `showCoreBreakdown` key launch clean.
- VAC-11: dark + light parity.
- AGENTS rule: all `SparklineTimeAxisView` axes retained; no `.animation`/`.contentTransition` added (status item views). Baselines: `scripts/capture_baseline.sh` (dark/light) before first edit, `scripts/measure_popover_footprint.sh` if a footprint round is needed — not required for a pure deletion.

## Constraints

- One coder spawn on `feature/remove-cores-breakdown` in the worktree; TDD: write `RemoveCoresBreakdownTests.swift` first, watch it fail, then delete code.
- Conventional commit: `feat!: remove Cores Breakdown and its Settings toggle` (breaking removal — decide `!` vs `feat` at commit time; user-facing feature removal).
- Merge to `main` is fast-forward only, after reviewer GO; report the merge SHA.
- No deploy.
