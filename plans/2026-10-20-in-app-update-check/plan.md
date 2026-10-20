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

- [x] I1 (TDD red/green). Test table: `v1.2.3`, `1.2.3` parse and compare
  correct (`1.10.0 > 1.9.0`); `1.2`, `1.2.3.4`, `""`, `abc` → nil (silent
  no-op). `promptState`: newer+not-dismissed → prompt; equal/older → none;
  newer+dismissed → none. Red test file fails before implementation, passes
  after; fake `UpdateReleaseSource` used — no real network in unit tests.
  Evidence: red `094f77f` (exit 65, missing-symbol errors, 0 passing) → green
  `69fdfe0` (31 new tests green).
- [x] I2. Decode fixture test for the 3-key payload (`tag_name`, `html_url`,
  `name`) green. Evidence: `UpdateCheckSourceTests` (10 assertions) green.
- [x] I3. Full existing suite (244 tests at plan time) plus new tests green.
  Evidence: 292/292 on merged main `ab8100a` (2026-10-21). One attribution
  event: a run while the display was idle failed
  `StatusItemControllerPopoverTests.testTogglePopoverCyclesMountAndRelease`
  (5 timing assertions); content-identical code passed with the display active
  (`UserIsActive 1` → 5.99 s green). Cause = idle-display animation stall, not
  the merge.
- [x] I4 (design gate, blocking). VAC-1..11 in the blueprint all PASS against
  before/after dark+light captures from `scripts/capture_baseline.sh`, reviewed
  by the designer before merge. Zero visual defects.
  Captures run ONLY in the user's interactive terminal (verified 2026-10-20:
  agent sessions lack Automation + Screen Recording TCC — osascript -1743,
  screencapture denied). Banner-visible captures use the T2b fixture:
  `STATSLITE_FAKE_UPDATE_VERSION=1.1.0 scripts/capture_baseline.sh`.
  Evidence: gate round 2 PASS (2026-10-21), pixel parity dark/light 0.0 pt
  drift on every measured invariant.
- [x] I5. Status item untouched: VAC-3 — status item hierarchy/width identical
  in idle/checking/update states. Evidence: gate PASS; only an optional
  `updateChecker` param threads through `StatusItemController`.
- [x] I6. Silent-failure invariant VAC-4: no spinner, no alert, no badge on
  failure or while checking. Evidence: gate PASS (no ProgressView/alert in
  hierarchy; nil-source path returns silently, code-verified).
- [x] I7. Restart persistence VAC-10: unit round-trip of the dismissed key.
  Evidence: `UpdateCheckServicePersistenceTests` (dismiss round trip, negative
  path) green. Manual quit/relaunch covered by the same state path.
- [x] I8. Harness purity + footprint. Evidence: measure script on merged main
  run twice — `run_phys_footprint_peak_mb 326.0` both runs; pre-feature build
  (`dbc835e`) same harness — `run_phys_footprint_peak_mb 326.0`. Delta 0 MB,
  within noise; fixture is inert without the env var (unit-pinned).
- [x] I9. No release/tag/CI change in this plan; `release-dmg.yml` and
  `build-dmg.yml` diffs empty. Evidence: `git diff dbc835e ab8100a -- .github/`
  = 0 lines.

Falsification: any failing I1-I9 kills the corresponding claim and the plan
stops until it is fixed. One variable per verification round.

## Tasks

- [x] **T1** — `[coder]` in worktree `worktrees/update-check-core`, branch
  `feat/update-check-core`. Red first (I1/I2 tests), then implementation.
  red **094f77f** (3 test files, +303, exit 65, missing-symbol compile errors =
  expected Swift TDD red, 0 tests passing) · green **69fdfe0** (31 new tests
  green; full suite 278/278 yellow gate)
- [x] **T2** — `[coder]` in worktree `worktrees/update-banner-ui`, branch
  `feat/update-banner-ui` (stacked on T1). `StatsLite/UpdateBannerCardView.swift`
  + integration per blueprint. [skip-red: visual acceptance is screenshot-based,
  not unit-testable in this repo — recorded justification]
  green **5aeaeb1** (2 files, suite 278/278, zero VAC-number deviations, status
  item untouched)
- [x] **T2b** — `[coder red/green]` fixture `STATSLITE_FAKE_UPDATE_VERSION`:
  `UpdateCheckLaunchPolicy.skipCheck`/`fixtureRelease`, service `environment:`
  seam, fixture bypasses the harness skip. Red first: policy table + fixture
  parse + 0-fetch fixture service test.
  red **3546c10** (11 tests, errors confined to new file) · green **a020e63**
  (suite 289/289)
- [x] **T2c** — `[coder red/green]` design-gate fix: fixture bypasses the 300 s
  launch floor; production throttle pinned by two guard tests.
  red **4b6f20f** (fixture test fails as expected; floor pins pass)
  · green **ab8100a** (suite 292/292, single-hunk condition change)
- [x] **T3** — `[designer]` design gate.
  **FAIL round 1** (2026-10-21): dark.png PASS zero drift; light.png missing
  banner — root cause 300 s launch floor blocks the second capture pass;
  remediation = T2c, then re-capture + re-gate.
  **PASS round 2** (2026-10-21): VAC-1..11 all PASS, pixel evidence both
  appearances, zero geometry drift, contrast AA verified.
- [x] **T4** — reviewer `[code-review]` on both branches' combined diff vs
  main. review **GO** (2026-10-21, formal verdict with grounded evidence:
  harness-skip wiring line, red-commit assertion counts).
- [x] **T5** — Merge ff-only: T1 then T2 to local main; I8 footprint
  verification on merged main. merged **ab8100a** (2026-10-21, linear chain,
  both branches fast-forwarded after a rebase onto the doc commits that
  landed on main during development).
  SHA mapping (rebase before merge): 62b0b70→094f77f, 1d8b516→69fdfe0,
  bae13f4→5aeaeb1, b5c55a3→3546c10, 933891b→a020e63, da17093→4b6f20f,
  76d6f3d→ab8100a.

## Out of scope (YAGNI)

Sparkle, settings pane, "Check for updates" menu item, ETag caching, retry
ladder, pre-release channels, delta download, API token, build-number compare,
`launchd`, DESIGN.md authoring, any CI workflow change.
