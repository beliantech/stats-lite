# Plan: drop gauge icon, show bundle version in popover footer

Date: 2026-10-17
Risk class: R2 (user-visible UI change; visual acceptance checklist required)

## Intent

The user wants two popover edits in StatsLite:

1. Remove the top-left `gauge.with.needle` icon from the popover header.
2. Replace the footer-right text `macOS Native` with a version label formatted
   `v1.0.0 (1)`.

Facts from the repository:

- The header icon and the footer text live in `StatsLite/PopoverContentView.swift`:
  `header` (lines 73-109) starts its `HStack` with
  `Image(systemName: "gauge.with.needle")`; `footer` (lines 113-127) ends with
  `Text("macOS Native")`.
- `StatsLite.xcodeproj/project.pbxproj` sets `MARKETING_VERSION = 1.0.0` and
  `CURRENT_PROJECT_VERSION = 1` (lines 333/342 and in each configuration). The
  label must read `CFBundleShortVersionString` and `CFBundleVersion` from
  `Bundle.main`. A hard-coded `"v1.0.0 (1)"` in the view would be a band-aid that
  rots at the next version bump.
- No `DESIGN.md` exists at the repository root (designer verified 2026-10-17).
- The Design Blueprint (5 parts, VAC-1..VAC-10, verbatim code templates) is
  archived at `plans/2026-10-17-popover-drop-gauge-version-footer/blueprint.md`.
  The coder applies its templates verbatim.

Goal: the popover header leads with the plain `StatsLite` title, and the footer
right shows the live bundle version as `v1.0.0 (1)` in both appearances.

## ISC

- [ ] ISC-1: `rg 'gauge.with.needle' StatsLite/PopoverContentView.swift` prints
      no hits; the first subview of the header `HStack` is `Text("StatsLite")`.
- [ ] ISC-2: `rg '"macOS Native"' StatsLite/` prints no hits (whole repo, all
      sources).
- [ ] ISC-3: `rg -F 'v1.0.0' StatsLite/PopoverContentView.swift` prints no hits —
      the view contains no version literal; the string comes from
      `PopoverContentView.versionLabel(bundle:)` via `CFBundleShortVersionString`
      + `CFBundleVersion`.
- [ ] ISC-4: unit tests pass: `versionLabel(version:build:)` returns
      `v1.0.0 (1)` for inputs `1.0.0` / `1` and `v1.0.0 (9999)` for build `9999`;
      the bundle-sourced `versionLabel()` matches
      `^v[0-9][0-9.]* \([0-9]+\)$`. Full `xcodebuild test` suite green.
- [ ] ISC-5: built product reports the values that make the label read
      `v1.0.0 (1)`: `plutil -extract CFBundleShortVersionString raw
      .derivedData/Build/Products/Release/StatsLite.app/Contents/Info.plist`
      prints `1.0.0`, and `plutil -extract CFBundleVersion raw
      .derivedData/Build/Products/Release/StatsLite.app/Contents/Info.plist`
      prints `1`.
- [ ] ISC-6: dark and light screenshots of the open popover captured with
      `scripts/capture_baseline.sh --out-dir artifacts/2026-10-17-popover-drop-gauge-version-footer/after`
      pass every VAC item: no icon left of the title, title at the 12 pt leading inset and
      vertically centered with the gear/quit buttons (28 pt header), footer right
      reads `v1.0.0 (1)` in tertiary 10 pt, no wrap/truncation/clip at 280 pt,
      light and dark parity.

Failure modes:

- FM1: the unit-test bundle may lack `CFBundleShortVersionString` /
      `CFBundleVersion` keys, so the build-9999 case never exercises them.
      Fix (already in blueprint Part 6): the pure seam
      `versionLabel(version:build:)` covers it directly — the test calls
      `versionLabel(version: "1.0.0", build: "9999")` and asserts equality with
      `"v1.0.0 (9999)"`. The regex check stays on the bundle-sourced label.
- FM2: removing the icon shifts the title and risks vertical misalignment with
      the 24x24 buttons. Check VAC-4 in the captured screenshots; the header is
      a plain `HStack` default alignment, so the centering must hold — if it does
      not, fix alignment explicitly and record it in the commit.
- FM3: long version strings (e.g. build `99999`) crowd the refresh label.
      Blueprint measured ≥ 100 pt spacer clearance at build 9999; `.lineLimit(1)`
      guards both labels. If the screenshot shows an ellipsis, stop and report.
- FM4: `artifacts/` output lands under the worktree; commit only the plan
      artifacts dir if small, otherwise leave untracked (match prior plans'
      behavior for `artifacts/`).

## Approach

1. Archive: designer blueprint already written to
   `plans/2026-10-17-popover-drop-gauge-version-footer/blueprint.md`.
2. Red phase (coder, commit 1): add unit tests for `versionLabel` — regex match,
   build-9999 case, no-literal check — against a stub that fails (FM1 fallback
   applies). Commit as red.
3. Green phase (coder, commit 2): apply blueprint Part 6 Edit 1 verbatim —
   header without the gauge icon, footer with `Text(Self.versionLabel())`,
   `.lineLimit(1)` on both footer labels, `.accessibilityLabel` for the version,
   and the four static helpers (pure `versionLabel(version:build:)` /
   `versionAccessibilityLabel(version:build:)` seams plus their
   `bundle:` wrappers). Commit as green.
4. Verify: `xcodebuild test` (full suite), `xcodebuild build`, ISC-1..ISC-5
   greps/plist checks, then `scripts/capture_baseline.sh --out-dir
   artifacts/2026-10-17-popover-drop-gauge-version-footer/after` in the worktree
   for ISC-6 (dark + light).
5. Review: plan-review verdict on this file, then code review on the diff with
   VAC screenshots attached.

Decisions:

- Version source: `Bundle.main` via `object(forInfoDictionaryKey:)` with
  `"1.0.0"` / `"1"` nil-fallbacks (blueprint Part 6). Never a literal in the
  view body.
- The blueprint adds `.lineLimit(1)` to the refresh label too; accept it — it
  hardens VAC-9 and changes no current rendering.
- The status item (menu bar) is out of scope; it keeps its own gauge branding.
  Only the popover header loses the icon.
- No `.animation` / `.contentTransition` anywhere in the change (repo rule).

Refactors:

None. No band-aids introduced or left behind.

## Tasks

- [ ] **T1** — Red-green implementation in worktree
      `worktrees/2026-10-17-popover-drop-gauge-version-footer`, branch
      `feat/2026-10-17-popover-drop-gauge-version-footer`. Red: tests for
      `versionLabel(version:build:)` and the bundle-sourced regex (ISC-4) against
      a failing stub, commit 1. Green: blueprint Part 6 Edit 1 verbatim (header
      icon removal + footer version label + four helpers), commit 2. Run full `xcodebuild test` + build, ISC-1..ISC-5, and
      `scripts/capture_baseline.sh --out-dir artifacts/2026-10-17-popover-drop-gauge-version-footer/after`
      for dark/light screenshots (ISC-6). red ⏳ · green ⏳ · review ⏳

## Notation

Plan -> Phase (`## Approach`) -> Task (`T1`; `FM*` = failure modes) -> Receipts
(red SHA / green SHA / review verdict — verify each in git, record on the task
line).
