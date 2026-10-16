# Plan: StatsLite Logo SVG (Arc & Twin Bars)

[Pre-Approved: Parent Plan none] — user approved concept + scope in chat on 2026-10-16.

## Intent

StatsLite has no vector logo. The user wants a simple two-color-max SVG logo:
one gauge arc and two equalizer bars, all strokes the same width. Deliver three
SVG asset files: full-color dark, full-color light, and a monochrome
`currentColor` template for the macOS menu bar.

## Risk class

R0 — adds static SVG asset files only. No code, behavior, schema, or UI change.
Plan-review skipped per R0 rule. Reviewer check happens at task close.

## ISC

- ISC-1: `assets/StatsLiteLogoDark.svg` exists, is well-formed XML, and matches
  the approved source (`/tmp/designer/statslite_v3_dark.svg`) exactly.
- ISC-2: `assets/StatsLiteLogoLight.svg` exists, is well-formed XML, and matches
  the approved source (`/tmp/designer/statslite_v3_light.svg`) exactly.
- ISC-3: `assets/StatsLiteLogoTemplate.svg` exists, is well-formed XML, and
  matches the approved source (`/tmp/designer/statslite_v3_template.svg`)
  exactly. It contains no hard-coded color values; all strokes use
  `currentColor`.
- ISC-4: All three files use `viewBox="0 0 512 512"` and `stroke-width="44"` on
  the arc and both bars (VAC-1, VAC-2).
- ISC-5: Each file has `role="img"` and a `<title>` element (VAC-10).
- ISC-6: Renders at 512 px, 32 px, and 16 px of each variant stay legible: the
  arc and both bars remain distinct with no merging (VAC-8, VAC-9). Verified on
  light and dark backgrounds.
- ISC-7: No app source file is modified; only the three new asset files land on
  the branch.

## Approach

- Designer-approved geometry (Concept 1 "Arc & Twin Bars", equalized strokes):
  - Arc: `M 124.47 387.53 A 186 186 0 1 1 387.53 387.53`, stroke 44, round caps.
  - Left bar: `line x1=216 y1=258 x2=216 y2=334`, stroke 44, round caps, base color.
  - Right bar: `line x1=296 y1=192 x2=296 y2=334`, stroke 44, round caps, accent blue.
- Colors: dark variant `#FFFFFF` / accent `#0A84FF` on `#1C1C1E` canvas;
  light variant `#1D1D1F` / accent `#007AFF` on `#FFFFFF` canvas; template
  variant pure `currentColor`.
- Coder writes the three files verbatim. No geometry reinterpretation.

## Refactors

None. New files only.

## Tasks

- [x] **T1** — coder writes the three SVG files in a worktree, verifies
  well-formedness and renders. red n/a (skip-red, static asset) · green 108494f ·
  review GO (ISC-1..ISC-7, VAC-1..VAC-10 all pass; byte-identical to approved
  sources)

## Verification plan

- Automated: `xmllint --noout` well-formedness on all three files; `diff`
  against the approved sources; grep for `stroke-width="44"`, `viewBox`, and
  `currentColor` invariants.
- Visual: render at 512/32/16 px on light and dark; reviewer checks VAC-1..VAC-10
  on the renders.
- Test: none (no app code touched).

## Rollback

`git revert` the merge commit or delete the three asset files. No state, no
migrations.

## Out of scope

Wiring the logo into the app (app icon sets, popover header, About window).
Separate task if requested later.

## Open questions

None.
