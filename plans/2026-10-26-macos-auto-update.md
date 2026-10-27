# Plan: 2026-10-26-macos-auto-update

## Context / goal

Stats Lite ships on GitHub Releases with a custom update *notification* only: the
popover banner's button opens the GitHub release page in a browser. Users download and
drag-replace the DMG themselves. Goal: in-app auto-update — check, download, verify,
install, relaunch — with no GitHub visit, using Sparkle 2 driven through the existing
`UpdateBannerCardView` (gentle reminders, no focus-stealing windows in a status-item
app).

Design doc: `plans/2026-10-26-macos-auto-update/design.md` (approved by user).
Research: `plans/2026-10-26-macos-auto-update/research.md`.

Repo state at plan time: `MARKETING_VERSION = 1.1.2`, `CURRENT_PROJECT_VERSION = 4`,
latest tag `v1.1.2`. First Sparkle release = next tag with build ≥ 5.

## ISC (binary checks — all must be YES at close)

1. ISC-1 Build: `StatsLite.xcodeproj` resolves Sparkle ≥2.6.4 from SPM; `xcodebuild
   build` and `xcodebuild test` pass on the Release config; `Sparkle.framework` is
   embedded with `CodeSignOnCopy`.
2. ISC-2 Info.plist: built app's Info.plist contains `SUFeedURL`
   (`…/releases/latest/download/appcast.xml`), `SUPublicEDKey`,
   `SUEnableAutomaticChecks=YES`, `SUScheduledCheckInterval=86400`,
   `SUAutomaticallyUpdate=NO`.
3. ISC-3 Gentle reminders: with an available update and the app not focused, no Sparkle
   window takes key focus; `UpdateBannerCardView` shows the new version in the popover.
   Falsification: unit test drives the delegate with `immediateFocus=false` →
   "should show" returns false and `availableUpdate` is set.
4. ISC-4 Install handoff: clicking the banner button closes the popover, activates the
   app, and Sparkle's install UI takes key focus (no crash, no orphaned window).
5. ISC-5 Harness purity: `--open-popover` without `STATSLITE_FAKE_UPDATE_VERSION` →
   `startingUpdater:false` (zero Sparkle network/XPC; footprint script output within
   the 60 MB budget and within noise of the pre-Sparkle baseline).
   `STATSLITE_FAKE_UPDATE_VERSION=9.9.9` renders the banner deterministically
   (screenshot baseline unchanged in geometry).
6. ISC-6 Local end-to-end update: with a test Ed25519 keypair and a local
   `http://127.0.0.1` feed, an installed build A (v1.1.3 / build 5) detects build B
   (v1.1.4 / build 6), downloads the DMG, verifies EdDSA + code signature, replaces the
   bundle, relaunches as v1.1.4 (build 6).
7. ISC-7 CI signing: `release-dmg.yml` signs Sparkle nested binaries inside-out
   (`Installer.xpc`, `Downloader.xpc` with `--preserve-metadata=entitlements`,
   `Autoupdate`, `Updater.app`, `Sparkle.framework`, then the app) before notarization;
   `workflow_dispatch` dry run passes `notarytool` and `spctl -a -vv -t install`; the
   notarization log shows no Sparkle-related failures. `build-dmg.yml` uses the same
   inside-out topology (no `--deep`).
8. ISC-8 Appcast: the tag workflow generates `appcast.xml` (`sign_update` with the
   private key on stdin), validates it with `xmllint`, and attaches it to
   `gh release create`; the `latest/download/appcast.xml` URL returns HTTP 200
   post-publish.
9. ISC-9 Version gate: the tag workflow fails when `CFBundleVersion` is not strictly
   greater than the `<sparkle:version>` in the currently published appcast (falsified by
   a CI-log run with a deliberately stale build number).
10. ISC-10 Retired poller: `GitHubReleaseSource.swift` deleted; no `api.github.com`
    polling remains in app code; all unit tests updated and green.

### Failure modes (each has a kill condition)

- FM1 (notarization): nested Sparkle binaries lack Team ID/hardened-runtime signature →
  `notarytool` Invalid. Kill: ISC-7 dry run must pass before any real tag.
- FM2 (frozen build number): developer bumps only `MARKETING_VERSION` → Sparkle sees no
  update. Kill: ISC-9 gate exists and is tested.
- FM3 (Swift 6 concurrency): `SPUStandardUserDriverDelegate` conformance errors under
  strict concurrency. Kill: fix with `@MainActor` + `nonisolated`/`assumeIsolated`
  pattern; if Sparkle's API can't satisfy Swift 6 isolation cleanly, stop and report —
  do not weaken `SWIFT_VERSION`.
- FM4 (focus/popover): popover close destroys content mid-download → progress UI
  orphaned or Sparkle window hidden behind a non-activating app. Kill: state lives in
  the app-lifetime service; handoff activates the app first (ISC-4).
- FM5 (feed drift): repo rename or a release published without `appcast.xml` breaks
  every installed client. Kill: post-publish HTTP 200 check (ISC-8) fails the release
  loudly.
- FM6 (key loss / missing secret): first tag fails signing. Kill: workflow fails fast
  with a clear error when `SPARKLE_ED_PRIVATE_KEY` is unset; maintainer checklist item.
- FM7 (live updater in the test host): XCTest launches the app host, which constructs
  and starts the real `SPUStandardUpdaterController`; with a placeholder/invalid
  `SUPublicEDKey` the main thread deadlocks in `startUpdater` (stack-verified:
  `SPUStandardUpdaterController startUpdater_block_invoke → mach_msg2_trap`) and the
  whole suite hangs. Kill: under XCTest the launch policy must yield
  `startingUpdater: false`; falsified by the full suite completing without hang.
  Root cause of the T3a session timeouts (all were stuck inside `xcodebuild test`).

Stop rules: if ISC-6 cannot pass locally on a non-sandboxed debug build, stop and
report. If notarization rejects Sparkle twice, stop and report — do not strip notarization.

## Task breakdown (worktrees, TDD red/green)

- [x] **T1 — Designer blueprint** [designer]. Done 2026-10-27:
  `plans/2026-10-26-macos-auto-update/blueprint.md` — "Install Update" primary button
  (in-flight disabled state), release notes delegated to Sparkle's standard window,
  "Software Update" row 4 in General below Launch at Login, VAC-1..15.
- [x] **T2 — SPM + build config** [coder] (`project.pbxproj` only). Done 2026-10-27.
  Red `f1e88d8`, green `5d300ce` (branch `sparkle-build-config`). Sparkle 2.10.1
  resolved; 461/461 tests green; `CURRENT_PROJECT_VERSION = 5`.
  **Measured deviation:** Xcode 27 does not inject custom `INFOPLIST_KEY_SU*` into the
  generated Info.plist — keys live in `Config/Sparkle-Info.plist` via `INFOPLIST_FILE`
  alongside `GENERATE_INFOPLIST_FILE = YES` (design.md updated). ISC-1/ISC-2 green.
- [x] **T4 — CI: inside-out signing, appcast, gates** [coder]
  (`release-dmg.yml`, `build-dmg.yml`). Done 2026-10-27: `9277365` (workflows),
  `ad9c84c` (README), branch `sparkle-ci`. Inside-out signing step; build-number gate
  (equal/lower FAIL, higher PASS, 404 notice, curl error FAIL); appcast generation with
  key on stdin (unset-secret FAIL proven); both assets on `gh release create`; feed
  HTTP 200 check; build-dmg.yml no longer uses `--deep`. All logic proven in /tmp
  harness. **Open assumption:** `sign_update` path
  `build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update` — confirm on first
  `workflow_dispatch` dry run (FM1 check, ISC-7/ISC-8).
- [x] **T3 — Sparkle coordinator + UI wiring** [coder]. Done 2026-10-27, branch
  `sparkle-updater`, 7 commits: isolation fix `463b08e`, red `b1adfde`, green
  `a211ae1` `ec29842` `4bbbf6f` `7a9b8e6` `fd123b3`. Full suite **488 tests / 0
  failures / ~68s**; MenuBarRenderSnapshotTests 15/15; `rg api.github.com StatsLite/`
  empty (ISC-10); harness seams green (ISC-5). Blueprint copy verbatim (VAC coverage
  in T3b report; VAC-14 + banner pixel/contrast = live checks for T6). One flag for
  designer: optional trailing `Checking…` text omitted (blueprint marks it optional).
  **Open risks:** `isChecking` reset depends on Sparkle finish callback (cover in T5);
  popover close stall on asleep display = known parked limitation.
  T3a groundwork: implementation `1bfa323`, FM7 red `9b39673`/green `0dd9f11`,
  `.gitignore` `11a538f`, red receipt `fe19948`. FM7 (new failure mode): the test host
  started the LIVE updater with the placeholder EdDSA key → main thread deadlocked in
  `SPUStandardUpdaterController startUpdater` (mach_msg2_trap) → suite hung; every
  prior T3a timeout was this hang, not slow reading. Fix: XCTest markers in env →
  `startingUpdater: false`. Falsification: suite completes with zero `[Sparkle]` log
  lines. The 2 flagged UserDefaults-isolation failures were resolved by `463b08e`.
- [~] **T5 — Local end-to-end update proof** [coder]. **Verdict 2026-10-27: PARTIAL**
  (full report /tmp/isc6-verdict.md; git status clean, nothing committed). **PASS:**
  (a) banner discovery of 1.1.4 (screenshots + syslog), (b) DMG download (200 in
  /tmp/sparkle-feed-server.log, size matches enclosure), (c) EdDSA + code-signature
  validation ("EdDSA signature is correct", SecTrust/resource validation, codesign
  --deep --strict exit 0), (d) bundle swap to 1.1.4/6 (mtime-pinned to the Autoupdate
  install second), (e) fresh launch runs as 1.1.4/6. **(f) runtime proof — now DONE
  2026-10-28 by T6 on the unlocked screen:** up-to-date banner suppression screenshot
  (/tmp/t6-state*.png, installed 1.1.4 == feed 1.1.4) and isChecking reset PROVEN at
  runtime (/tmp/t6-f2-poll.txt: button enabled=false 3s→13s+ during check;
  /tmp/t6-f2-cycle2.txt: "1s enabled=true" after the result alert OK) — the T3b-flagged
  risk is closed. **ATS: no product change** —
  NSAllowsLocalNetworking not needed; production is https anyway.
  **Finding 1 (ties to T4 falsification):** install logged "Skipping atomic rename/swap
  and gatekeeper scan because Autoupdate is not signed with same identity as the new
  update" — in local/dev builds SPM CodeSignOnCopy leaves Autoupdate/Updater.app/
  Downloader.xpc ad-hoc while the app is Apple Development. T4's CI inside-out signing
  should make all identities Developer ID → atomic path covered. **Falsification:** on
  the first workflow_dispatch dry run, assert `codesign -dv` on Autoupdate/Updater.app/
  Downloader.xpc shows "Developer ID Application" (not adhoc); and a production-identity
  install must NOT log the Skipping line. **Finding 2:** stale-bookmark error logged,
  install continued — confirm absent in production. **Finding 3:** no auto-relaunch
  observed — correct by policy (SUAutomaticallyUpdate=false; "Install and Relaunch" is
  the user step), not a defect. Live leftovers: StatsLite 1.1.4 test app + feed server
  :8765 running; kill both when done (`pkill -f StatsLiteTestApp`, kill pid 22407).
- [x] **T6 — Visual + footprint gate** [tester]. **PASS 2026-10-28** (report
  /tmp/t6-report.md). Footprint (ISC-5): menu-bar-only idle **36.0 MB** (36-43 steady)
  vs 60 MB ceiling — PASS; popover open peaks 206-211 MB (transient graphics backing
  store, not the menu-bar metric); no leak across 3 cycles/130 samples. f1+f2
  live-verified (see T5 entry). VAC-1..15: none BLOCKED; VAC-2/3/4/12/13/14/15
  live, VAC-1/5/6/7/8/9 from T5 screenshots (banner not re-captured — feed was
  up-to-date), VAC-10/11 offscreen/unit. Zero visual defects.
  Hygiene: test app + feed server killed, git clean.
  Parked observations: footprint script display-sleep guard (pre-existing),
  gfx-reclaim-during-open read as reclaim-not-leak, live banner re-capture optional.
- [~] **T7 — Review + merge** [reviewer]. Review 2026-10-28: REQUESTED-CHANGES with 2
  claims; planner verified both directly. **Claim 1 (indented heredoc corrupting
  appcast.xml) DISPROVEN** — PyYAML parse shows delimiter `cat > appcast.xml <<EOF`,
  terminator `EOF` at column 0 (YAML strips block indentation), xmllint runs after;
  T4's harness already executed this end-to-end validly. **Claim 2 (no gate against
  placeholder SUPublicEDKey at release) CONFIRMED BLOCKING** — nothing checks the key;
  shipping REPLACE_WITH_SPARKLE_PUBLIC_KEY would fatal-error the updater for all users
  (T5's FM7 failure mode at production scale). Fix in flight on `sparkle-ci` (key
  gate in release-dmg.yml, three-way verified: placeholder fail / empty fail /
  base64 pass). After fix: user sign-off → merge. Note: reviewer session produced its
  verdict in 7s (far under scope); planner re-verified its claims rather than trusting
  the verdict — only 1 of 2 findings was real.

Rollout prerequisites (user, outside repo — not blocking merge): generate Ed25519
keypair, add `SPARKLE_ED_PRIVATE_KEY` secret, back up the private key. First Sparkle
release note must tell v1.1.2 users this is their one final manual DMG swap.
