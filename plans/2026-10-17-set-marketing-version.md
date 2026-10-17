# Set app version to 1.0.0 (build 1)

Plan name: 2026-10-17-set-marketing-version

Risk class: R0 (4 value swaps in project.pbxproj, no behavior change)

## Intent

Set the marketing version to `1.0.0` so `CFBundleShortVersionString` matches the
`v1.0.0` tag format planned for releases. Build number stays `1`
(`CURRENT_PROJECT_VERSION = 1`, already set in all four configs).

## ISC

- [x] I1. All four `MARKETING_VERSION` entries in `StatsLite.xcodeproj/project.pbxproj` read `1.0.0` (app Debug/Release, tests Debug/Release).
- [x] I2. `CURRENT_PROJECT_VERSION` remains `1` in all four configs.
- [x] I3. `plutil -lint` passes on `project.pbxproj`.
- [ ] I4. CI `Build DMG` run on main after merge concludes `success` (build unaffected). pending: awaiting user `git push` of local main

## Tasks

- [x] **T1** — Worktree `version-bump`, swap `MARKETING_VERSION = 1.0;` to `1.0.0` (4x), lint, commit `d4ca49e`. red n/a (R0) · green: diff 4/4 lines, plutil OK · review —
- [x] **T2** — Reviewer `[code-review]`. review **GO** (2026-10-17)
- [x] **T3** — Merge `--ff-only` to local main; user pushes to origin. merged `d4ca49e` (2026-10-17); worktree and branch removed
