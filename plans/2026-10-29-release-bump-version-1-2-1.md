# Plan: 2026-10-29-release-bump-version-1-2-1

Plan name: `2026-10-29-release-bump-version-1-2-1`
Risk class: **R0** (mechanical version-number edit, single file, no behavior change)

## Intent

The `v1.2.1` release run (run id `40856645579`) failed at the
"Check tag matches app version" step:

```text
tag=1.2.1 app=1.2.0
##[error]version mismatch tag=1.2.1 app=1.2.0
```

`StatsLite.xcodeproj/project.pbxproj` was never bumped after `a594f8e`
(`chore: bump version to 1.2.0 (build 5)`). Bump the marketing version to
1.2.1 and the build number to 6 so the tag gate passes and the Sparkle
gate (`APPBUILD > published appcast build 5`) passes.

## ISC

- [x] `MARKETING_VERSION = 1.2.1` in all 4 build configurations of `StatsLite.xcodeproj/project.pbxproj` (2 app + 2 test).
- [x] `CURRENT_PROJECT_VERSION = 6` in all 4 build configurations.
- [x] No other file changes (only `StatsLite.xcodeproj/project.pbxproj`, 8 lines each way).
- [x] Change is committed on `main` via ff-only merge from a worktree branch (`88056d2`).
- [ ] Release run for `v1.2.1` (after the tag is re-pointed and pushed) passes "Check tag matches app version" and completes green.

No failure modes: the task changes no code path. FM1 (gate still fails) is
covered by the last check above and would be re-opened as `T2`.

## Approach

- R0: `[no-red]` coder task, no plan-review, no oracle (mechanical edit).
- One worktree on branch `chore/2026-10-29-release-bump-version-1-2-1`.
- After merge: delete local tag `v1.2.1`, re-tag at the new `main` commit,
  push `main` and force-push the tag (user-run; `git push` is blocked in
  this session), then watch run id of the new Release DMG run.

## Refactors

None. Version literals in `project.pbxproj` are the source of truth for
`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`; no band-aid introduced.

## Tasks

- [x] **T1** — bump `MARKETING_VERSION` to 1.2.1 and `CURRENT_PROJECT_VERSION` to 6 in all 4 configurations. red n/a (R0) · green `88056d2` · review GO (commit `88056d2` merged to main, ff-only)
