# GitHub Actions: build a .dmg artifact

Plan name: 2026-10-17-github-actions-dmg-build

Risk class: R0 (single workflow YAML file, no app code, no behavior change)

## Intent

Add a GitHub Actions workflow that builds StatsLite.app and packages it into a
`StatsLite.dmg`, then uploads the .dmg as a workflow artifact. No release, no
publishing. The .dmg must be ad-hoc signed so it runs on Apple Silicon and Intel
Macs.

## Facts (verified)

- Remote: `git@github.com:beliantech/stats-lite-macos.git`, push access via SSH key.
- Shared scheme `StatsLite` exists at `StatsLite.xcodeproj/xcshareddata/xcschemes/StatsLite.xcscheme`.
- Deployment target 14.0, no `DEVELOPMENT_TEAM`, `CODE_SIGN_IDENTITY = "-"` (ad-hoc).
- No `.github/workflows` directory exists yet.
- Token env var is `GITHUB_PERSONAL_API_TOKEN` (not `GITHUB_PERSONAL_ACCESS_TOKEN`).
  No `gh` CLI installed. GitHub API calls use `curl` with this token.
- Local `xcodebuild` is unavailable (active developer dir is CommandLineTools), so
  CI itself is the build verification.

## ISC

- [ ] I1. Workflow file `.github/workflows/build-dmg.yml` exists and is valid YAML.
- [ ] I2. Workflow triggers on `pull_request` to main, `push` to main, and `workflow_dispatch`.
- [ ] I3. A pull request run on the feature branch completes with conclusion `success`.
- [ ] I4. The run produces an artifact named `StatsLite-dmg` that contains a valid `StatsLite.dmg` (non-zero size, `hdiutil imageinfo` passes on the downloaded file).
- [ ] I5. The .app inside the dmg is ad-hoc signed (`codesign -dv` reports `Signature=adhoc`).
- [ ] I6. No release is created and no tag is pushed.

Failure modes:

- FM1. `xcodebuild` fails on the runner (scheme missing, signing error, build error).
  Falsification: the run log shows the `xcodebuild` step exit non-zero. Fix the
  build step flags, do not weaken the workflow (no skip of the build step).
- FM2. Ad-hoc codesign step fails or produces no signature.
  Falsification: downloaded dmg fails I5. Fix the codesign invocation.
- FM3. Token cannot create a pull request (missing `repo`/`pull_requests` scope).
  Falsification: API returns 403. Report to the user instead of guessing scopes.

## Approach

Workflow `build-dmg.yml`:

1. Trigger on `pull_request` (main), `push` (main), `workflow_dispatch`.
2. One job on `macos-latest` (arm64, macOS 14+ SDK satisfies target 14.0).
3. Steps: checkout, `xcodebuild build` Release with `CODE_SIGNING_ALLOWED=NO`,
   ad-hoc `codesign --force --deep --sign -` on the .app, build a dmg staging
   folder (app + `/Applications` symlink), `hdiutil create -format UDZO`,
   `actions/upload-artifact@v4` with the .dmg.
4. No tests in this workflow (out of scope; can be added later).
5. No release step, no `softprops/action-gh-release`, no tags.

## Tasks

- [ ] **T1** — Write `.github/workflows/build-dmg.yml` and commit on branch `ci/github-actions-dmg-build`. red n/a (R0) · green ⏳ · review ⏳
- [ ] **T2** — Push branch, open PR to main via GitHub API, watch the `pull_request` run until conclusion. green ⏳
- [ ] **T3** — Reviewer `[code-review]` on the workflow diff. review ⏳
- [ ] **T4** — Merge to main with `--ff-only` (or squash), push main, close PR, clean up. merged ⏳

## Verification note

The CI run is the build verification (local xcodebuild unavailable). I4 and I5
verify the downloaded artifact directly. If the token lacks scopes, stop and
report to the user (FM3).
