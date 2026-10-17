# Plan: register-app-icon-in-bundle

Date: 2026-10-17
Risk class: R1 (build configuration + bundled resource; no app behavior change)

## Intent

The StatsLite app ships with the generic system app icon. The logo artwork exists
in the repository as SVG, but no icon is registered in the app bundle.

Facts from the repository:

- `assets/StatsLiteLogoDark.svg`, `assets/StatsLiteLogoLight.svg`, and
  `assets/StatsLiteLogoTemplate.svg` exist at the repository root (`assets/`).
- There is no `Assets.xcassets` directory and no `.icns` file anywhere in the repo.
- `StatsLite.xcodeproj/project.pbxproj` has no `ASSETCATALOG_COMPILER_APPICON_NAME`,
  no `CFBundleIconFile`, and no `INFOPLIST_KEY_CFBundleIconName` entry.
  The Info.plist is generated (`GENERATE_INFOPLIST_FILE = YES`) and sets only
  `INFOPLIST_KEY_LSUIElement = YES`.
- The project uses `PBXFileSystemSynchronizedRootGroup`, so any file placed under
  `StatsLite/` is added to the app target automatically. No manual pbxproj file
  listing is required.

Goal: register the dark logo variant as the app icon, so the built `StatsLite.app`
bundle contains the icon and reports it in its Info.plist.

## ISC

Binary checks. All must read "yes" on the built product:

- [x] ISC-1: `StatsLite/Assets.xcassets/Contents.json`,
      `StatsLite/Assets.xcassets/AppIcon.appiconset/Contents.json`, and
      `StatsLite/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` exist in the
      repository; the PNG is generated from `assets/StatsLiteLogoDark.svg` at
      exactly 1024x1024.
- [x] ISC-2: the built `StatsLite.app/Contents/Resources/Assets.car` exists and
      contains the `AppIcon` image set (`assetutil --info` on the file lists
      `AppIcon`).
- [x] ISC-3: `plutil -extract CFBundleIconName raw StatsLite.app/Contents/Info.plist`
      prints `AppIcon`.
- [x] ISC-4: the app builds clean from a fresh build with zero errors
      (`xcodebuild build`), and `git diff` on `project.pbxproj` touches only
      build-setting lines.

Failure modes:

- FM1: the SVG-to-PNG converter (`rsvg-convert`) is not installed on the machine.
  Fallback chain: `qlmanage -t -s 1024`, then `sips` on an intermediate PDF via
  `cupsfilter`. The red phase records which converter produced the PNG.
- FM2: the rendered PNG is not exactly 1024x1024 (some converters pad or crop).
  Fix: check with `sips -g pixelWidth -g pixelHeight` and re-render or crop before
  committing. actool rejects an icon PNG with the wrong dimensions.
- FM3: `CFBundleIconName` is absent from the generated Info.plist. Fix: add
  `INFOPLIST_KEY_CFBundleIconName = AppIcon` to the app target build settings.
- FM4: `ASSETCATALOG_COMPILER_APPICON_NAME` is unset, so actool does not compile
  the icon set. Fix: set it to `AppIcon` in both the Debug and Release
  configurations of the app target.

## Approach

1. Create the asset catalog structure:
   - `StatsLite/Assets.xcassets/Contents.json` with the standard catalog info
     (`{"info": {"author": "xcode", "version": 1}}`).
   - `StatsLite/Assets.xcassets/AppIcon.appiconset/` with its `Contents.json`.
2. Generate the icon PNG:
   - Render `assets/StatsLiteLogoDark.svg` to a 1024x1024 PNG with the converter
     available on the machine (record which one in the commit message). Verify
     the dimensions with `sips -g pixelWidth -g pixelHeight`.
   - Commit the PNG as `AppIcon-1024.png` inside the appiconset. PNGs in an
     appiconset are the source form actool compiles; no `iconutil` step and no
     committed `.icns` (actool writes the `.icns` into `Assets.car`).
3. The appiconset `Contents.json` uses the Xcode single-size macOS icon entry:
   one 1024x1024 `platform: mac` slot with `filename: AppIcon-1024.png` and
   `idiom: universal`.
4. Edit `StatsLite.xcodeproj/project.pbxproj`: set
   `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;` in the app target's Debug and
   Release configurations. Set `INFOPLIST_KEY_CFBundleIconName = AppIcon;` in the
   same two configurations.
5. Build and run the ISC checks against the built product.

Decisions:

- Variant: `StatsLiteLogoDark.svg` (dark background, colored accent bar). It reads
  well in the Dock and the Finder sidebar. The template variant stays untouched
  for the status item.
- The `assets/` SVGs stay where they are. They are the source artwork, not bundle
  resources.
- No squircle mask is added. The raw square artwork is the existing design
  decision; a redesign would be separate work.

## Refactors

None. No band-aids are introduced or left behind.

## Tasks

- [ ] **T1** — Create `StatsLite/Assets.xcassets` (root `Contents.json` +
      `AppIcon.appiconset`), render `AppIcon-1024.png` from
      `assets/StatsLiteLogoDark.svg` at 1024x1024, and set
      `ASSETCATALOG_COMPILER_APPICON_NAME` plus `INFOPLIST_KEY_CFBundleIconName`
      to `AppIcon` in the app target's Debug and Release configurations. Build
      and verify ISC-1 through ISC-4. red 810dc0c · green 810dc0c (fresh rebuild,
      all ISC yes) · review GO (2026-10-17; both deviations verified: actool slot
      `idiom mac / 512x512 / 2x` for the 1024 PNG because Xcode 27 actool rejects
      a `mac` platform single-size entry; machine-local `DEVELOPMENT_DIR` build
      override, nothing repo-committed). Merged 27b98c2 (rebased onto main,
      fast-forward).

## Notation

Plan -> Phase (`## Approach`) -> Task (`T1`; `FM*` = failure modes) -> Receipts
(red SHA / green SHA / review verdict — verify each in git, record on the task line).
