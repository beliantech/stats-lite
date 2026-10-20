# Release workflow: notarized dmg on tag push

Plan name: 2026-10-20-release-workflow-notarized-dmg

Risk class: R1 (new CI pipeline that creates GitHub Releases; no app code change,
no pbxproj change)

## Intent

Add `.github/workflows/release-dmg.yml`: on a `v*` tag push, build StatsLite,
sign with Developer ID + hardened runtime, notarize and staple the dmg, create a
GitHub Release with the dmg attached. A manual `workflow_dispatch` runs the full
pipeline but stops before the release step — that is the test path, honoring
"no release yet". The existing ad-hoc `build-dmg.yml` stays untouched.

## Facts (verified)

- Secrets present in repo: `DEV_ID_CERT_P12` (re-uploaded 2026-10-20T07:26),
  `DEV_ID_CERT_PASSWORD`, `NOTARY_KEY_P8`, `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`.
- Team: Belian Tech PLT, id `W92R66CF55` (from pbxproj `DEVELOPMENT_TEAM`).
- `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 1` (merged `d4ca49e`).
- pbxproj sets `"CODE_SIGN_IDENTITY[sdk=macosx*]" = "Apple Development"` — CI must
  override it (FM3).
- CI identity lookup: `CODE_SIGN_IDENTITY="Developer ID Application"` matches the
  cert by prefix.

## ISC

- [ ] I1. Workflow file exists, valid YAML, actions pinned to SHAs,
  `permissions: contents: write` (release step needs it), line lengths <= 80.
- [ ] I2. A `workflow_dispatch` run on main completes `success`: Developer ID
  signature (`Authority=Developer ID Application`, `flags=0x10000(runtime)`),
  notarization status `Accepted`, staple OK, `spctl -a -vv -t install` reports
  `source=Notarized Developer ID`.
- [ ] I3. The dispatch run creates no release and no tag.
- [ ] I4. Artifact `StatsLite-notarized-dmg` downloads and passes the same
  checks on the local Mac (spctl + codesign on the mounted app).
- [ ] I5. Version guard present: on tag runs the workflow fails unless the tag
  (minus `v`) equals the built app's `CFBundleShortVersionString`. Verified by
  review; exercised at the first real tag.
- [ ] I6 (deferred, user decision). First `v1.0.0` tag push creates Release
  `v1.0.0` with `StatsLite.dmg` attached. Plan stays open until then.
- [ ] I7. `build-dmg.yml` byte-identical (`git diff` empty).

Failure modes:

- FM1. Keychain: codesign cannot access the imported private key (partition
  list). Falsification: sign step fails with chain/access error. Fix the
  `set-key-partition-list`/search-list steps, never drop signing.
- FM2. Notary returns `Invalid` (hardened runtime missing, artifact modified
  after submit). Falsification: `jq -r .status` != Accepted. Fix signing order;
  never touch the dmg between submit and staple.
- FM3. pbxproj sdk-specific `Apple Development` identity wins over CI. Falsification:
  CI log `codesign -dv` shows `Apple Development`. Fix build-setting overrides.
- FM4. Dispatch accidentally creates a release. Falsification: I3 fails. Fix the
  `startsWith(github.ref, 'refs/tags/')` condition.

## Approach

Workflow `release-dmg.yml`:

1. Triggers: `push: tags: ['v*']`, `workflow_dispatch`. Concurrency per ref.
2. One job, `macos-latest` runner.
3. Steps: checkout (SHA-pinned, `persist-credentials: false`) → decode `.p12`
   from secret → throwaway keychain (`build.keychain-db`, unlock, import with
   `-T /usr/bin/codesign`, `set-key-partition-list`, prepend to search list) →
   `xcodebuild build` Release with `CODE_SIGN_STYLE=Manual`,
   `CODE_SIGN_IDENTITY=Developer ID Application`, `DEVELOPMENT_TEAM=W92R66CF55`,
   `ENABLE_HARDENED_RUNTIME=YES` (CLI overrides only — pbxproj untouched) →
   version guard (tag runs only) → stage dmg (app + /Applications symlink) →
   `hdiutil create UDZO` → `notarytool submit --wait --output-format json`,
   fail unless `status == Accepted` → `stapler staple` → `spctl` verify →
   upload artifact → `gh release create` guarded to tag refs
   (`GH_TOKEN: ${{ github.token }}`, `--verify-tag`).
4. No pbxproj change: hardened runtime is a CI build-setting override, so local
   debug builds keep their current behavior.
5. `build-dmg.yml` unchanged.

## Tasks

- [ ] **T1** — Write `.github/workflows/release-dmg.yml` on branch
  `ci/release-workflow-notarized-dmg`, commit with this plan. red n/a · green
  [skip-red: pipeline config, not executable locally — the dispatch run (T3) is
  the test] · review ⏳
- [ ] **T2** — Reviewer `[code-review]` against ISC/FMs. review ⏳
- [ ] **T3** — Merge ff-only to local main; user pushes; dispatch run; verify
  I2/I3/I4 locally. green ⏳
- [ ] **T4** — Close plan after user's first real tag (I6) or explicit deferral.
  merged ⏳
