# Plan: Offscreen Render Tests for Menu Bar Visual VACs

Plan name: `2026-10-24-menu-bar-offscreen-render-tests`

Risk: **R1** (test-target + docs only; no production behavior change)

## Intent

Menu bar visual VACs (ink centroids, gaps, alignment) currently need a
live screen capture, which needs the screen unlocked and the display
awake. Lock, display sleep, and parallel-session captures block them.

Build an offscreen render harness: draw the real menu bar block views
into a bitmap in-process, then measure the pixels of that bitmap. Migrate
the pixel VACs from plan `2026-10-24-temp-optical-alignment-and-gap` into
it, and record the convention in `AGENTS.md`.

## ISC (binary)

- [ ] **ISC-1** New test file renders `MenuBarTempBlockView`,
      `MenuBarNetworkBlockView`, and `MenuBarBlockView` (CPU fixture)
      offscreen at 2× scale into bitmaps, and asserts each bitmap
      contains ink (non-blank).
- [ ] **ISC-2** VAC-16/17 reproduced in the render: |cy(C) − cy(red dot)|
      ≤ 0.30 px and |cy(G) − cy(cyan dot)| ≤ 0.30 px (sub-pixel,
      intensity-weighted centroids).
- [ ] **ISC-3** VAC-22/23 reproduced: TEMP value right ink → red dot left
      ink = 21 ±1 px; GPU value right ink → C label left ink = 21 ±1 px.
- [ ] **ISC-4** VAC-18 reproduced: top ink edge of CPU, MEM, GPU, and C
      equal within ±0.4 px.
- [ ] **ISC-5** Both appearances verified: the same assertions pass with
      a forced `.darkAqua` and `.aqua` appearance on the hosting view,
      and a luminance probe proves the forced appearance took effect
      (value-text luminance differs ≥ 40 between the two renders).
- [ ] **ISC-6** Layout uses production constants only
      (`MenuBarLayout.rowHeight`, `tempBlockWidth = 36`, `gap = 4`) —
      no re-declared magic numbers in the test beyond measurement
      thresholds.
- [ ] **ISC-7** Full suite green (xcodebuild, caffeinate-wrapped).
- [ ] **ISC-8** `AGENTS.md` records the convention: pixel VACs verify
      through the offscreen render tests; screen captures are
      end-to-end spot checks only (they need an unlocked screen).

### Failure modes

```text
FM1  Rendered bitmap is blank or near-blank (view needs a host
     environment, scale factor, or fixed size it never got) → ISC-1 fails.
     Fix: assert minimum ink pixel count before any measurement.
FM2  Measurements drift with display scale or machine → pin render
     scale to 2× explicitly and measure in bitmap pixels; thresholds stay
     in the ISC values above.
FM3  Forced appearance silently ignored → ISC-5 luminance probe
     fails the suite instead of letting dark/light renders be identical.
FM4  Test accidentally verifies re-declared numbers instead of
     production layout → ISC-6: read widths/heights/gap from
     MenuBarLayout.
```

## Approach

- Test-target only: `StatsLiteTests/` (new render-harness helper or
  file), plus `AGENTS.md`. Zero changes under `StatsLite/`.
- Harness: `NSHostingView` sized to the view's fitting size, drawn into
  an `NSBitmapImageRep` (2×), fixed opaque background for stable
  contrast; measure with intensity-weighted centroids/edges.
- Fixtures build real `MenuBarBlock` values (CPU/MEM/GPU rows, TEMP
  `C 45°`/`G 32°`, NET rates with dots) through the production builder.
- Coder runs red first (failing measurement tests), then green.

## Refactors

- None required. No band-aids in the touched area.

## Tasks

- [ ] **T1** — offscreen render harness + migrated pixel VAC assertions
      (ISC-1..ISC-6) + AGENTS.md rule (ISC-8). red ⏳ · green ⏳ · review ⏳ ·
      merge ⏳
