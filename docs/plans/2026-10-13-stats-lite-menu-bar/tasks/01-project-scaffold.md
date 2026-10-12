# Task 01 — Xcode Project Scaffold

## Objective
Create a buildable, testable Xcode project skeleton for Stats Lite (menu bar app, no UI content yet), plus git hygiene files.

## Context
Greenfield repo. Architecture is locked in the ISC (read `docs/plans/2026-10-13-stats-lite-menu-bar/ISC.md` in the main repo: `/Users/jonathan/beliantech/stats-lite/docs/plans/2026-10-13-stats-lite-menu-bar/ISC.md`).

## Steps
1. Create `StatsLite.xcodeproj/project.pbxproj` (objectVersion 77, Xcode 16+ format) with `PBXFileSystemSynchronizedRootGroup` for `StatsLite/` and `StatsLiteTests/` folders. No per-file entries.
2. Two targets:
   - `StatsLite` (macOS app, bundle id `com.beliantech.StatsLite`, deployment target 14.0, SWIFT_VERSION 6.0, ad-hoc code sign `CODE_SIGN_IDENTITY = "-"`, `GENERATE_INFOPLIST_FILE = NO` with own `StatsLite/Info.plist`).
   - `StatsLiteTests` (unit test bundle, host-less, depends on app target via `@testable import StatsLite`; TEST_HOST not required for pure-logic tests — link the app's sources via the synchronized group if needed so MetricMath is testable; prefer making the test bundle compile the app sources it needs).
3. `StatsLite/Info.plist`: `LSUIElement = YES`, `CFBundleName`, `CFBundleIdentifier` `$(PRODUCT_BUNDLE_IDENTIFIER)`, `CFBundleShortVersionString` 1.0.0, `CFBundleVersion` 1, `LSMinimumSystemVersion` `$(MACOSX_DEPLOYMENT_TARGET)`, `NSHumanReadableCopyright` empty.
4. `StatsLite/StatsLiteApp.swift`: minimal `@main App` with a `MenuBarExtra("Stats Lite") { Text("Stats Lite") } .menuBarExtraStyle(.window)` and a `Settings {}` scene placeholder (real views come in tasks 05/06).
5. `StatsLiteTests/SmokeTests.swift`: one trivial passing test so the test target is wired.
6. Root `.gitignore`: `.derivedData/`, `xcuserdata/`, `.DS_Store`, `build/`.
7. Create the shared scheme `StatsLite` (`.xcodeproj/xcshareddata/xcschemes/StatsLite.xcscheme`) so `-scheme StatsLite` works for both build and test, with the test target in the Test action.

## Verify (must pass before commit)
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project StatsLite.xcodeproj -scheme StatsLite \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath .derivedData \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project StatsLite.xcodeproj -scheme StatsLite \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath .derivedData \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO
```

## Commit
`feat(scaffold): add Xcode project with synchronized groups and smoke test`
