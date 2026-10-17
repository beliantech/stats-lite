# Default Refresh Interval 1s on First Launch

## Why

On first launch the app refreshes every 2 seconds. The user wants 1 second.

## Current state → Target state

| Aspect | Current | Target |
|---|---|---|
| First-launch default | 2 s | 1 s |
| `PreferencesStore.swift:63` | `var refreshInterval: Int = 2` | `= 1` |
| `PreferencesStore.swift:117` | `@AppStorage("refreshInterval") ... = 2` | `= 1` |
| `SystemMonitor.swift:34` | `var refreshInterval: TimeInterval = 2.0` | `= 1.0` |
| `PreferencesStoreGuardTests.swift:55` | assert default `2` | assert `1` |
| Settings picker (`SettingsView.swift:49`) | offers 1/2/3/5 s | unchanged |
| Network sample loop (`SystemMonitor.swift:48,164`) | fixed 1.0 s | unchanged |

No `register(defaults:)` exists. The first-launch value is the `@AppStorage`
property-initializer fallback, seeded into the observable state in
`PreferencesStore.init()`. `AppDelegate` copies it into the monitor with
`monitor.apply(preferences)`.

## Changes

Single commit on `feat/2026-10-17-default-refresh-interval-1s`, worktree
`worktrees/2026-10-17-default-refresh-interval-1s`. Four one-line edits in
three files.

## Receipts

- Red: guard test only, 1 failed assertion (`testDefaultsEnableAllThreeMetrics`),
  11 executed.
- Green: full suite, 241 tests, 240 passed. The 1 failure
  (`StatusItemControllerPopoverTests.testTogglePopoverCyclesMountAndRelease`,
  popover close 5 s timeout) fails the same way on unmodified `cb0ccba` in the
  same environment. Pre-existing and environmental, not caused by this change.
- Plan review: GO (all cited sites verified, no missed default site).
- Code review: GO (diff, test receipts, and negative checks verified).

## Notes

- Users who upgraded but never opened Settings also move 2 s → 1 s, because the
  key was never written.
- `plans/2026-10-16-auto-interval-history.md` later removes the
  `refreshInterval` key entirely. Sequence this change before that plan.

## Merge

Fast-forward into `main`. Merge commit: `963b6c6`
(`feat(prefs): default refresh interval to 1s on first launch`).
