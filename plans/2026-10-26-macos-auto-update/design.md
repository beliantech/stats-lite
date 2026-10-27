# Design: In-App Auto-Update for Stats Lite (Sparkle 2)

## Goal

Users install updates from inside the app. No trip to GitHub. First update path ships in
v1.2.0; every release after v1.2.0 updates in-app.

## Current state

- Custom poller ships today: `UpdateCheckService` + `GitHubReleaseSource` poll
  `api.github.com .../releases/latest` at launch (300s floor) and every 24h.
  `UpdateBannerCardView` in the popover shows a dismissible banner. The button opens the
  GitHub release page in a browser. No download, no install.
- Release CI: `.github/workflows/release-dmg.yml` on `v*` tags — Developer ID sign,
  hardened runtime, DMG, notarize, staple, `spctl`, `gh release create StatsLite.dmg`.
- Versioning lives only in `project.pbxproj`: `MARKETING_VERSION=1.1.0`,
  `CURRENT_PROJECT_VERSION=2`. Info.plist is generated.
- Pure Xcode project, no SPM dependencies today. Bundle ID `com.beliantech.statslite`.
  Not sandboxed. `LSUIElement = YES` (status-item-only app).

## Decision: Sparkle 2 + gentle-reminder bridge

| Option | Verdict |
| --- | --- |
| A. Sparkle 2, gentle reminders drive the existing banner | **Chosen** |
| B. Extend custom checker (DIY download + swap + relaunch) | Rejected: 800+ LOC of security-critical install code, no deltas, hand-rolled signature checks |
| C. Hybrid (custom poller for banner + Sparkle on click) | Rejected: dual state, redundant "checking" modal, GitHub API rate limits |

Why A:

- Sparkle 2 verifies EdDSA signature + Developer ID code signature, handles App
  Translocation, quarantine, read-only volumes, privilege elevation, and atomic bundle
  replacement.
- `SPUStandardUserDriverDelegate.supportsGentleScheduledUpdateReminders` fits a
  status-item app: no focus-stealing background modals. Discovery surfaces in
  `UpdateBannerCardView`; the click hands off to Sparkle's install UI.
- Hosting: static `appcast.xml` as a GitHub Release asset. Stable URL:
  `https://github.com/beliantech/stats-lite/releases/latest/download/appcast.xml`
  (same `releases/latest/download/` pattern already verified for the DMG).
- ~150 LOC of adapter code. Low maintenance.

Rejected B/C explicitly: DIY install code is a security liability; dual-poller splits
state between `CFBundleShortVersionString` (GitHub) and `CFBundleVersion` (Sparkle).

## Design

### 1. SPM dependency (first in repo)

- Add `XCRemoteSwiftPackageReference` for
  `https://github.com/sparkle-project/Sparkle`, `upToNextMajorVersion` from `2.6.4`.
- Link `Sparkle` to the `StatsLite` target only. Add an `Embed Frameworks` copy phase
  (`dstSubfolderSpec = 10`, `CodeSignOnCopy`, `RemoveHeadersOnCopy`).
- `StatsLiteTests` needs no link: it uses `TEST_HOST`/`BUNDLE_LOADER` against the app
  and already has `@executable_path/../Frameworks` runpaths.

### 2. Info.plist keys (`Config/Sparkle-Info.plist`, merged via `INFOPLIST_FILE`)

```text
SUFeedURL = "https://github.com/beliantech/stats-lite/releases/latest/download/appcast.xml"
SUPublicEDKey = "<base64 Ed25519 public key>"
SUEnableAutomaticChecks = true
SUScheduledCheckInterval = 86400
SUAutomaticallyUpdate = false
```

Deviation from the original design (measured in T2): Xcode 27 only injects
spec-declared `INFOPLIST_KEY_*` settings into the generated Info.plist; custom
`INFOPLIST_KEY_SU*` settings resolve in build settings but never reach the plist.
Fix: a partial `Config/Sparkle-Info.plist` referenced by `INFOPLIST_FILE` alongside
`GENERATE_INFOPLIST_FILE = YES` — keys merge natively.

Policy: check daily, never install silently. The user clicks to install. Matches the
24h cadence of the old poller.

### 3. App code

- Retire `GitHubReleaseSource.swift`. Repurpose `UpdateCheckService` as the `@MainActor`
  `@Observable` coordinator over `SPUUpdater` + `SPUStandardUserDriverDelegate`.
- Gentle reminders: `supportsGentleScheduledUpdateReminders = true`; return `false` from
  the "handle showing scheduled update" delegate call when not in immediate focus. Set
  `availableUpdate` from `standardUserDriverWillHandleShowingUpdate` so the banner shows
  `displayVersionString`.
- Banner button changes from open-browser to `installUpdate()`: activate the app
  (`NSApplication.shared.activate(ignoringOtherApps: true)`), close the popover, call
  `updater.checkForUpdates()` so Sparkle's install window takes key focus.
- Add `SettingsView` row: "Check for Updates…"
  → `checkForUpdatesInteractively()`.
- State lives in an app-lifetime service owned by `AppDelegate`, never in
  `PopoverContentView` (the popover's `contentViewController` is destroyed on close at
  `StatusItemController.swift:269`).
- Test seams preserved:
  - `UpdateCheckLaunchPolicy.skipCheck(...)` → construct
    `SPUStandardUpdaterController(startingUpdater: false, ...)`. No network/XPC during
    `scripts/measure_popover_footprint.sh` runs.
  - `STATSLITE_FAKE_UPDATE_VERSION` → seed `availableUpdate` from the fixture, no live
    Sparkle. `scripts/capture_baseline.sh` screenshots stay deterministic.
  - Protocol seam (e.g. `SparkleUpdaterControlling`) for unit-test spies; no live
    network in tests.

### 4. Keys and CI (`.github/workflows/release-dmg.yml`, `build-dmg.yml`)

- One-time: run Sparkle `generate_keys`; private key → repo secret
  `SPARKLE_ED_PRIVATE_KEY`; public key → `INFOPLIST_KEY_SUPublicEDKey`.
- **Inside-out signing** after `xcodebuild build` (before notarization), never
  `codesign --deep`:
  1. `Sparkle.framework/Versions/B/XPCServices/Installer.xpc`
  2. `.../Downloader.xpc` (with `--preserve-metadata=entitlements`)
  3. `Autoupdate`, `Updater.app`
  4. `Sparkle.framework`
  5. `StatsLite.app`
  Each with `--force --sign "Developer ID Application" --options runtime --timestamp`.
  The app is non-sandboxed and omits `SUEnableInstallerLauncherService`, so Sparkle
  spawns `Autoupdate` directly — no launchd services, no TCC background-item prompts.
- `build-dmg.yml` (ad-hoc CI): replace `codesign --deep` with the same inside-out
  topology so PR CI matches release CI.
- Appcast generation per tag: `sign_update` (private key piped via stdin,
  `--ed-key-file -`) over the signed, notarized `StatsLite.dmg`. Hand-write the
  single-item `appcast.xml` (version = `CFBundleVersion`, shortVersion =
  `CFBundleShortVersionString`, enclosure = tag asset URL). Validate with `xmllint`.
  Attach both `StatsLite.dmg` and `appcast.xml` in `gh release create`.
- New CI gates:
  1. `CFBundleVersion` strictly greater than `<sparkle:version>` in the currently
     published `appcast.xml` (the tag==short-version check alone misses a forgotten
     `CURRENT_PROJECT_VERSION` bump — Sparkle would then see no update).
  2. Post-publish: `curl -fsSLI .../releases/latest/download/appcast.xml` must be HTTP
     200.

## Rollout

- **v1.1.0 → v1.2.0 (one-time manual)**: existing users' old poller sees `v1.2.0` via
  the GitHub API and shows the old banner → one final manual DMG drag-replace.
- **v1.2.0 onward**: in-app update, no browser. No delta updates at this app size; full
  DMG only. `SUAutomaticallyUpdate = NO`.
- **Recovery**: every release still ships a standalone notarized `StatsLite.dmg`
  (downgrade = manual drag-replace). To pull a bad release: mark it pre-release →
  `releases/latest/download/appcast.xml` redirects back to the previous good version;
  users who already updated get a forward hotfix tag.
- **App Store**: not applicable today (GitHub-only distribution, README). If a store
  target ever appears, gate Sparkle with `#if !APP_STORE` (Guideline 2.5.2).

## Verification

1. Unit: spy `SparkleUpdaterControlling`; assert gentle-reminder delegate behavior,
   banner suppression after dismiss-for-version, `startingUpdater: false` under
   `--open-popover`, fixture seeding under `STATSLITE_FAKE_UPDATE_VERSION`.
2. Local end-to-end: test Ed25519 keypair in `/tmp`; build A
   (v1.1.0/build 2, `SUFeedURL=http://127.0.0.1:8765/appcast.xml`), build B
   (v1.2.0/build 3) packed to DMG and signed; serve with `python3 -m http.server`;
   banner shows v1.2.0 → click Install → app relaunches as v1.2.0 (build 3).
3. Notarization: `workflow_dispatch` dry run of `release-dmg.yml` (tag/release steps
   are already gated on `refs/tags/`); inspect `notarytool` log;
   `codesign --verify --deep --strict` passes on Sparkle nested binaries; `spctl -a -vv
   -t install` passes on the DMG.
4. Visual/footprint: all menu-bar and popover VACs pass
   (`MenuBarRenderSnapshotTests`); `scripts/measure_popover_footprint.sh` stays inside
   the 60 MB budget vs. the pre-Sparkle baseline.

## Risks (ranked)

1. **Notarization rejects nested Sparkle binaries** (missing Team ID / hardened
   runtime inside `Sparkle.framework`) → inside-out signing + workflow_dispatch dry run.
2. **Forgotten `CURRENT_PROJECT_VERSION` bump** → CI gate on `<sparkle:version>`.
3. **Swift 6 strict concurrency on `SPUStandardUserDriverDelegate`** → `@MainActor`
   conformance; if needed, `nonisolated` methods with `MainActor.assumeIsolated`
   (Sparkle guarantees main-thread callbacks).
4. **Popover closes when Sparkle's window takes focus** → activate app + close popover
   before handing off; progress state lives in the app-lifetime service.
5. **App Translocation / run-from-DMG** → Sparkle 2 detects read-only volumes and
   prompts the user to move the app to `/Applications`.
6. **Repo secret missing** → `SPARKLE_ED_PRIVATE_KEY` must exist before the first
   post-integration tag (repo settings are outside the codebase; verify manually).

## Open item for the user

- Button copy: `"Install Update"` vs `"Update Now"` on `UpdateBannerCardView`, and
  whether a secondary release-notes link stays alongside Sparkle's own window
  (designer/T2 decides).
