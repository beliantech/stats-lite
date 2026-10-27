# Research: macOS Auto-Update (Sparkle 2)

Verification runs in the main repo on 2026-10-26. Sources: scout reconnaissance session
(`b94d8bd3…`), oracle design session (`8310fc39…`), and direct re-verification below.

## Re-verified facts (repo state 2026-10-26)

- Version has moved since the scout run: `project.pbxproj` now has
  `MARKETING_VERSION = 1.1.2`, `CURRENT_PROJECT_VERSION = 4` in all four configs
  (`pbxproj:334,345,358,369,381,388,401,408`). Latest tag `v1.1.2`. The first
  Sparkle-enabled release must use build ≥ 5.
- Source layout confirmed: `StatsLite/GitHubReleaseSource.swift`,
  `UpdateCheckService.swift` (`final class UpdateCheckService`, `UpdateCheckTypes.swift:121`
  `protocol UpdateReleaseSource: Sendable`), `UpdateCheckLaunchPolicy.swift` with
  `STATSLITE_FAKE_UPDATE_VERSION` (`fixtureVersionKey`, line 17) and `skipCheck` gated on
  the exact `--open-popover` argument (line 30), `UpdateBannerCardView.swift`
  (`updateVersion` + `releaseURL` + `onDismiss` props; header/body/action rows;
  `.metricCardStyle()`).
- CI confirmed: `.github/workflows/release-dmg.yml` — tag push `v*` plus
  `workflow_dispatch` (line 6); `codesign --verify --deep --strict` on the built app
  (line 61); tag == `CFBundleShortVersionString` gate (lines 66-78); DMG signed (97),
  `notarytool submit` (109), `gh release create "$GITHUB_REF_NAME" StatsLite.dmg`
  (149). `build-dmg.yml:35` uses `codesign --force --deep --sign -` (ad-hoc, artifact
  only).

## Facts taken from scout/oracle runs (path citations in those sessions)

- Pure Xcode project, `objectVersion = 77`, `PBXFileSystemSynchronizedRootGroup` for
  `StatsLite/` and `StatsLiteTests/` — new `.swift` files compile without pbxproj file
  references. Empty `packageProductDependencies` (`pbxproj:92`) — Sparkle is the first
  SPM dependency.
- Not sandboxed (`CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`, no entitlements file).
  `LSUIElement = YES`. Team ID `W92R66CF55`.
- Popover lifecycle: `StatusItemController.swift:269` nils
  `contentViewController` in `popoverDidClose` — update/download state must live in an
  app-lifetime service owned by `AppDelegate`.
- Constraints: 60 MB idle budget (`scripts/measure_popover_footprint.sh`), no
  animations in status item views (`AGENTS.md`), menu-bar VACs via
  `MenuBarRenderSnapshotTests`.

## Oracle verdict (design.md has the full reasoning)

Sparkle 2 (≥2.6.4) with gentle update reminders bridging the existing
`UpdateBannerCardView`; `GitHubReleaseSource` retired; `appcast.xml` signed with EdDSA
and attached to each GitHub Release; `SUFeedURL` =
`https://github.com/beliantech/stats-lite/releases/latest/download/appcast.xml`.

## Unverified priors (labeled per AGENTS.md)

- "DMG + Sparkle stays under ~4 MB" — unverified prior; not load-bearing for any task.
- GitHub repo secret `SPARKLE_ED_PRIVATE_KEY` does not exist yet — repo settings are
  outside the codebase; maintainer action, tracked as a rollout prerequisite.
