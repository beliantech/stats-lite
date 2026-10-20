# Tier 1 in-app update check

Plan name: 2026-10-20-in-app-update-check

Risk class: R1 (new app behavior: first HTTP call in the codebase, new UI card,
new persistence; follows the designer's blueprint and the oracle's design)

## Intent

On launch and every ~6 hours, query
`https://api.github.com/repos/beliantech/stats-lite-macos/releases/latest`,
compare `tag_name` to `CFBundleShortVersionString`, and show a one-time banner
card in the popover when a newer version exists. "View Release" and "Dismiss"
both persist the dismissed version; the banner never returns for that version.
All failure paths are silent. No settings UI, no Sparkle, no auto-download.

## Research inputs (attached)

- Design blueprint + VAC-1..11:
  `plans/2026-10-20-in-app-update-check/blueprint.md`
  (designer, 2026-10-20; surface = in-popover banner card; exact copy, tokens,
  state matrix, WCAG contracts).
- Oracle advisory (2026-10-20, session `2026-10-20T08-36-02-696Z`): integration
  design, GO with corrections. Key facts it established:
  - No `URLSession`/JSON code exists anywhere in `StatsLite/` — this is the
    first HTTP primitive; smallest surface, house conventions
    (`StatsLite/SystemMetricsProvider.swift:5-7`: nil means failure, never
    throws).
  - House loop pattern: one `Task` + `ContinuousClock.sleep`, no Timer/Combine
    (`StatsLite/SystemMonitor.swift:129-158`, header rule `:5-11`).
  - Service pattern: `@MainActor @Observable final class` owned by
    `AppDelegate` (`StatsLite/StatsLiteApp.swift:36-48`, mirrors
    `StatsLite/LaunchAtLoginService.swift:14-16`).
  - Popover content dies on close
    (`StatsLite/StatusItemController.swift:107-118, 165-171`) — dismissed state
    must live in app-lifetime service, not view.
  - Both targets are file-system-synchronized groups
    (`StatsLite.xcodeproj/project.pbxproj:24-33`) — new files need no pbxproj
    edit.
  - No entitlements/sandbox today — no network entitlement needed; hardened
    runtime does not block `URLSession`.
  - Pre-release handling: zero code. `/releases/latest` excludes pre-releases,
    and CI (`release-dmg.yml:71-75`) rejects tags that do not equal the app
    version.
  - `--open-popover` measurement guard must skip the check
    (`StatsLite/StatsLiteApp.swift:55-57`).

## Reconciled design decisions (designer vs oracle)

- Service naming/API per oracle: `SemanticVersion`, `ReleaseInfo`,
  `UpdateReleaseSource` protocol + `URLSession` impl, pure
  `promptState(latest:current:dismissedVersion:)`. Designer's appendix code was
  illustrative; oracle's strict parse wins (parse table below is normative).
- Start point per oracle: end of `applicationDidFinishLaunching`, skipped when
  `--open-popover` present; launch check only if `now - lastCheck >= 300 s`.
- UI, copy, tokens, states per blueprint (banner card, "Update Available" /
  "StatsLite vX.Y.Z is available." / "View Release" / "Dismiss").
- "View Release" writes the dismissed key too (both sources agree).
- Two `UserDefaults.standard` keys: `updateCheckDismissedVersion` (String),
  `updateCheckLastCheckEpoch` (Double).

## ISC

- [ ] I1 (TDD red/green). Test table: `v1.2.3`, `1.2.3` parse and compare
  correct (`1.10.0 > 1.9.0`); `1.2`, `1.2.3.4`, `""`, `abc` → nil (silent
  no-op). `promptState`: newer+not-dismissed → prompt; equal/older → none;
  newer+dismissed → none. Red test file fails before implementation, passes
  after; fake `UpdateReleaseSource` used — no real network in unit tests.
- [ ] I2. Decode fixture test for the 3-key payload (`tag_name`, `html_url`,
  `name`) green.
- [ ] I3. Full existing suite (244 tests at plan time) plus new tests green in
  CI (build-dmg workflow runs the build; local `xcodebuild test` where
  possible).
- [ ] I4 (design gate, blocking). VAC-1..11 in the blueprint all PASS against
  before/after dark+light captures from `scripts/capture_baseline.sh`, reviewed
  by the designer before merge. Zero visual defects (text wrapping, clipping,
  spacing, width drift from the 280 pt frame are blocking).
  Captures run ONLY in the user's interactive terminal (verified 2026-10-20:
  agent sessions lack Automation + Screen Recording TCC — osascript -1743,
  screencapture denied). Banner-visible captures use the T2b fixture:
  `STATSLITE_FAKE_UPDATE_VERSION=1.1.0 scripts/capture_baseline.sh`.
- [ ] I5. Status item untouched: VAC-3 — status item hierarchy/width identical
  in idle/checking/update states.
- [ ] I6. Silent-failure invariant VAC-4: no spinner, no alert, no badge on
  failure or while checking.
- [ ] I7. Restart persistence VAC-10: unit round-trip of the dismissed key +
  manual quit/relaunch with same newer tag shows no banner.
- [ ] I8. Harness purity: `scripts/measure_popover_footprint.sh` on a build
  with a pending update produces identical `[measurement]` stderr lines (no
  banner, no alert) and resident-size delta within harness noise versus main.
- [ ] I9. No release/tag/CI change in this plan; `release-dmg.yml` and
  `build-dmg.yml` diffs empty.

Falsification: any failing I1-I9 kills the corresponding claim and the plan
stops until it is fixed. One variable per verification round.

## Tasks

- [ ] **T1** — `[coder]` in worktree `worktrees/update-check-core`, branch
  `feat/update-check-core` (spawn cwd = worktree). Red first: failing tests for
  I1/I2 in `StatsLiteTests/UpdateCheckVersionTests.swift`,
  `UpdateCheckPolicyTests.swift`, `UpdateCheckSourceTests.swift`. Green:
  `StatsLite/UpdateCheckTypes.swift`, source protocol + URLSession impl,
  `StatsLite/UpdateCheckService.swift` (Task loop, 6 h cadence, 300 s launch
  floor, UserDefaults keys, AppDelegate wiring with `--open-popover` guard).
  red **62b0b70** (3 test files, +303, exit 65, missing-symbol compile errors =
  expected Swift TDD red, 0 tests passing) · green **1d8b516** (31 new tests
  green; full suite 278/278 yellow gate) — merge blocked until T3/T4/T5.
- [x] **T2** — `[coder]` in worktree `worktrees/update-banner-ui`, branch
  `feat/update-banner-ui` (spawn cwd = worktree), after T1 GO. Implement
  `StatsLite/UpdateBannerCardView.swift` + integration at
  `PopoverContentView.swift:30` strictly per blueprint (tokens, copy, a11y
  labels). [skip-red: visual acceptance is screenshot-based, not unit-testable
  in this repo (no view-testing dependency; adding one is out of scope)] —
  acceptance = design gate I4 + full suite green. Captures via
  `scripts/capture_baseline.sh` before/after in both appearances.
  green **bae13f4** (2 files, suite 278/278, zero VAC-number deviations, status
  item untouched) · design gate ⏳ (blocked on T2b + user-run captures)
- [ ] **T2b** — `[coder red/green]` in worktree `update-banner-ui` (stacked).
  Verification enabler for I4: env fixture `STATSLITE_FAKE_UPDATE_VERSION`.
  Pure `UpdateCheckLaunchPolicy.skipCheck(arguments:environment:)` — skip iff
  `--open-popover` present AND fixture env absent (fixture overrides the
  harness skip; the measure script never sets it, so I8/F5 hold). Pure
  `fixtureRelease(environment:)` — parse env value via `SemanticVersion`, nil
  if absent/garbage, else `ReleaseInfo` with the releases page URL; fed
  through `promptState` like a fetched latest. No `#if DEBUG` (captures build
  Release); inert without the env var. Red first: policy table + fixture parse
  + service honors fixture with a counting fake source (0 fetch calls).
  red **b5c55a3** (11 tests, errors confined to new file, 3 missing symbols
  named) · green **933891b** (suite 289/289) · review deferred to T4
- [ ] **T2c** — `[coder red/green]` in worktree `update-banner-ui` (stacked).
  Design-gate fix (T3 FAIL round 1): the 300 s launch floor must not suppress
  the check when `STATSLITE_FAKE_UPDATE_VERSION` is set — fixture semantics
  override the floor exactly as they override the harness skip (production
  relaunch-storm protection stays for the real path). Red first: service test
  with fixture env + fresh `updateCheckLastCheckEpoch` (< 300 s gap) → check
  still runs, `availableUpdate` set, source 0 calls; and without fixture the
  floor still skips (guard the production behavior). green required before
  re-capture. red **da17093** (fixture test fails as expected; floor pins pass)
  · green **76d6f3d** (suite 292/292, single-hunk condition change)
- [ ] **T3** — `[designer]` design gate: verdict on I4/I5/I6 against captures,
  VAC by VAC. review **FAIL round 1** (2026-10-21): dark.png PASS zero drift;
  light.png missing banner — root cause 300 s launch floor blocks the second
  capture pass; remediation = T2c, then re-capture + re-gate.
  round 2 **PASS** (2026-10-21): VAC-1..11 all PASS, pixel evidence both
  appearances, zero geometry drift, contrast AA verified.
- [ ] **T4** — reviewer `[code-review]` on both branches' combined diff vs
  main. review ⏳
- [ ] **T5** — Merge ff-only: T1 then T2 to local main; I8 footprint
  verification on merged main. merged ⏳

## Out of scope (YAGNI)

Sparkle, settings pane, "Check for updates" menu item, ETag caching, retry
ladder, pre-release channels, delta download, API token, build-number compare,
`launchd`, DESIGN.md authoring, any CI workflow change.

