# Task 01 — Project Scaffold

## Objective

Empty, buildable Stats Lite app + test target. Nothing else.

## Read first

- `.pi/plans/2026-10-15-stats-lite-3metric.md` (ISC) — §Architecture/Packaging & build, AC-1, AC-2.

## Deliverables

1. Hand-written minimal `StatsLite.xcodeproj/project.pbxproj` using `PBXFileSystemSynchronizedRootGroup` for `StatsLite/` and `StatsLiteTests/`. No xcodegen, no SwiftPM app.
2. `StatsLite/` with minimal app entry (empty `MenuBarExtra` shell compiles), `StatsLiteTests/` with one trivial test.
3. Info.plist: `LSUIElement = YES` (never a Dock icon). Build settings: `SWIFT_VERSION = 6.0`, `MACOSX_DEPLOYMENT_TARGET = 14.0`, `CODE_SIGN_IDENTITY = "-"`.
4. `.gitignore` gains `.derivedData/` (keep existing entries).

## Verify (mandatory)

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS,arch=arm64' -derivedDataPath .derivedData CODE_SIGN_IDENTITY="-"` → 0 errors, 0 warnings from our code.
- Same env with `test` instead of `build` → tests pass.

## Report

- Conventional commits, ≤2. State the exact build/test commands run and their result.
