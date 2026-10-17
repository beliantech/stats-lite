# Plan: launch-at-login-notfound-toggle

Date: 2026-10-17
Risk class: R1 (single state-mapping change in Settings; no visual change)

## Intent

A fresh StatsLite install cannot enable Launch at Login. The toggle is disabled
and shows "Login item service not found".

Root cause (one attribution measurement, 2026-10-17, macOS 27.0.1):

- For 7 days the unified log recorded `SMAppService MainAppService status: 3`
  (`.notFound`) on every StatsLite launch — never any other value.
- `StatsLite/LaunchAtLoginService.swift:82-83` maps `.notFound` to
  `.unavailable("Login item service not found")`.
- `StatsLite/SettingsView.swift:125-130` disables the toggle for `.unavailable`.
  The app never calls `register()`, so the state can never change: a self-lock.
- Probe measurement: a fresh probe app with a new bundle identifier reported
  status 3, then `register()` succeeded and moved status to 1 (`.enabled`);
  `unregister()` moved it to 0 (`.notRegistered`). Ad-hoc and
  Apple-Development-signed probes behaved the same, and the same probe cycle
  moved the real StatsLite app from status 3 to status 0.
  Conclusion: on this OS `.notFound` is an empty login-item record, not an
  error. Signing was not the cause (verified: ad-hoc probe registered fine).

Goal: `.notFound` becomes a registerable state. The toggle unlocks; the user's
explicit toggle click performs `register()`; failures surface as text; no retry
loop is introduced.

Oracle advisory (design review, 2026-10-17): map `.notFound` to
`.notRegistered` in one line; reject a separate unlocked state (no behavioral
difference); keep `register()` on explicit toggle only; keep the
`.requiresApproval` no-retry guarantees
(`plans/2026-10-13-stats-lite-menu-bar/ISC.md:16,40`,
`plans/2026-10-15-stats-lite-3metric.md:59,96`). Oracle notes on macOS 14/15
behavior of `.notFound` are unverified prior.

## Hypothesis and falsification signature

- H1: the disabled toggle is caused solely by the `.notFound` → `.unavailable`
  mapping. If H1, then editing only `map(.notFound)` moves
  `LaunchAtLoginService.state` for status 3 from `.unavailable` to
  `.notRegistered`, which moves `loginItemLocked` from `true` to `false`
  (`SettingsView.swift:127-130` already returns `false` for `.notRegistered`),
  and the red unit test flips to green with no other code change. If the test
  stays red after the map edit, H1 is dead and the plan stops.

## ISC

Binary checks. All must read "yes":

- [ ] ISC-1: `StatsLiteTests/LaunchAtLoginServiceTests.swift` exists and asserts
      `LaunchAtLoginService.map(.notFound) == .notRegistered`,
      `map(.notRegistered) == .notRegistered`, `map(.enabled) == .enabled`, and
      `map(.requiresApproval) == .approvalNeeded`. Red phase: the
      `.notFound` assertion fails; green phase: all pass.
- [ ] ISC-2: full test suite passes with zero failures
      (`xcodebuild test -scheme StatsLite -destination 'platform=macOS'`), and
      the Release build succeeds.
- [ ] ISC-3: `register()` and `unregister()` remain reachable only from the
      Settings toggle binding (`SettingsView.swift:111-124`); `refresh()`
      performs a status read only. No `register()` call exists in `init()`,
      `refresh()`, or any launch path (no retry loop).
- [ ] ISC-4: `.requiresApproval` still maps to `.approvalNeeded` (covered by
      ISC-1) and `.unavailable` still exists for `@unknown default`, so the
      Settings hint and lock logic in `SettingsView.swift:125-148` keep their
      current behavior for every other state.
- [ ] ISC-5: `map(_:)` access is `internal` (not `private`) so the test target
      can reach it via `@testable import StatsLite`; no other visibility or
      signature change.

Failure modes:

- FM1: on macOS 14/15, `.notFound` may mean a genuinely unresolvable bundle
      (unverified prior). Degradation: the failure happens at action time —
      the user clicks the toggle, `register()` throws, `errorMessage` shows the
      localized text, state changes only on the next `refresh()`. No retry.
- FM2: `StatsLiteTests/` may not auto-include new files (the app target uses
      `PBXFileSystemSynchronizedRootGroup`). Fix: verify the test compiles and
      runs in the red phase; add the file to the test target membership in
      `project.pbxproj` only if the run proves it necessary.
- FM3: `refresh()` inside the `register()`/`unregister()` catch blocks could
      mask `errorMessage`. Guard: the catch sets `errorMessage` and then
      refreshes state; ISC-1 plus an assertion on `errorMessage` retention in
      the test keep both.
- FM4: `map(_:)` becoming `internal` collides with another symbol. Unlikely;
      verify with a clean build (ISC-2).
- FM5: stale LaunchServices registrations (39 records, 26 dead paths) hide a
      different failure after the fix. Not in scope; if ISC checks pass and the
      runtime symptom persists, open a separate plan.

## Approach

1. Red: add `StatsLiteTests/LaunchAtLoginServiceTests.swift` with the four
   mapping assertions from ISC-1; change `private static func map` to
   `static func map` in `StatsLite/LaunchAtLoginService.swift` (access only).
   Run the suite; record the failing assertion as red.
2. Green: in `map(_:)`, return `.notRegistered` for `.notFound` (one line, with
   a comment that records the 2026-10-17 probe measurement). In `register()` and
   `unregister()`, call `refresh()` after `errorMessage` is set in the catch
   blocks so the state re-reads after a failed action. Run the suite; record
   green.
3. Verify ISC-1 through ISC-5, build Release, and commit.

No UI edits: `SettingsView` lock and hint logic already behave correctly for
`.notRegistered`. No refactors, no band-aids.

## Tasks

- [ ] **T1** (red) — worktree `worktrees/2026-10-17-launch-at-login-notfound-toggle`,
      branch `feat/2026-10-17-launch-at-login-notfound-toggle`. Add the test file,
      make `map(_:)` internal, run the suite, report the red SHA and the exact
      failing assertion.
- [ ] **T2** (green, same worktree) — apply the mapping change and the catch-block
      `refresh()`; run the full suite and a Release build; report the green SHA
      and the ISC checklist.

## Notation

Plan -> Phase (`## Approach`) -> Task (`T1`; `FM*` = failure modes) -> Receipts
(red SHA / green SHA / review verdict — verify each in git, record on the task
line). Planner merges to `main` after review GO.
