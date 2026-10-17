Plan name: 2026-10-17-app-icon-use-light-logo
Risk class: R1 (user-facing visual change, one asset file)

## Intent

Replace the bundle app icon
`StatsLite/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` with a
**light-mode icon that looks like a real macOS app icon** (user request, two
parts: use the light variant, polish it).

The current icon is a flat render of `assets/StatsLiteLogoLight.svg`: flat
white background, mark edge-to-edge, no depth.

The designer produced the authoritative blueprint:
- Spec + verbatim SVG: `plans/2026-10-17-app-icon-light/design.md`
- Definitive render: `plans/2026-10-17-app-icon-light/render.png`

The design keeps the brand mark (gauge arc, dark base bar, blue `#007AFF`
peak bar) on a light background, scales the mark inside the macOS safe zone,
and adds a porcelain gradient plate plus a three-tier drop shadow for depth.

## ISC

- [ ] I1. The appiconset PNG is byte-identical to a 1024x1024 rsvg-convert
      render of the SVG spec in `plans/2026-10-17-app-icon-light/design.md`.
- [ ] I2. Visual match to `plans/2026-10-17-app-icon-light/render.png`
      (compare pixel-by-pixel: render was produced by the same command; any
      difference beyond JPEG-free PNG determinism is a fail).
- [ ] I3. `Contents.json` unchanged; asset catalog compiles with no AppIcon
      warnings; app builds.
- [ ] I4. PNG is 1024x1024, RGB, no alpha, full-bleed, no baked rounding;
      pixel samples: corner ≈ `#FFFFFF`-ish porcelain, blue bar mid ≈
      `#007AFF`, arc dark `#0D0D0E`-range.
- [ ] I5. The icon source SVG is committed next to the asset so the PNG is
      reproducible (`assets/AppIconLight.svg`).

Failure modes:
- FM1. PNG rendered at 512 then upscaled (blurry) — must render at 1024.
- FM2. Cairo/librsvg zero-width gradient bbox on stroked paths (missing
      gradients) — spec uses `userSpaceOnUse`, verifier checks gradients
      render (arc is not flat black).
- FM3. `feDropShadow` not supported by the renderer — shadow absent; visual
      diff against render.png catches it.
- FM4. Wrong variant (dark logo) or asset-catalog compile error.

## Approach

1. Worktree `worktrees/app-icon-light-logo`, branch `app-icon-light-logo`.
2. Copy the blueprint SVG to `assets/AppIconLight.svg`, render with
   `rsvg-convert -w 1024 -h 1024` into the appiconset (overwrite PNG).
3. Verify I1–I4 (hash comparison against designer render, `sips` checks,
   pixel samples via `magick`), build the app once (I3).
4. Commit, reviewer GO, squash-merge to main, clean up worktree.

## Refactors

None. No band-aids involved.

## Tasks

- [x] **T1** — render blueprint SVG to `AppIcon-1024.png`, commit source SVG,
      verify I1–I5. red n/a (`[skip-red]` — asset swap, no code logic) ·
      green PASS · review GO

## Merge receipt

Branch `app-icon-light-logo` squashed into `main` as `19c78bb`
("feat(app-icon): light-mode polished bundle icon").
Planner docs commit: `6ea5446`. Deviation (FM3/librsvg single-feDropShadow)
recorded in `plans/2026-10-17-app-icon-light/design.md`.
