# Tester report — T3 dark capture + final VAC report

Plan: `menu-bar-label-text-size-increase` · Branch `feat/2026-10-21-menu-bar-label-text-size-increase` (red 154e17c → green 693548d)
Date: 2026-10-21 · Toolkit: `screencapture -x` + ImageMagick pixel measurement + prior suite/static evidence

## Result table

| Item | Scope | Result | Evidence |
| :--- | :--- | :--- | :--- |
| VAC-1 (labels "CPU"/"GPU"/"MEM" at 8 pt regular secondary) | light | PASS | Pixel measurement on `artifacts/2026-10-21-menu-bar-label-text-size-increase/light-status-item.png` (370x48 px, 2x retina → 1 pt = 2 px). `magick -connected-components 8` on the ink mask: label glyph boxes are 12 px tall (≈5.5–6 pt cap height), consistent with 8 pt regular SF. Label ink spans: CPU x=30..62 px, MEM x=120..156 px, GPU x=201..233 px. The 12 pt value row is a separate row at y=24..42 px (18 px glyphs), so the 8 pt label row is distinct and unchanged. |
| VAC-1 | dark | PASS | Superseded capture at 08:24 (see "Final dark capture" below): `dark-menubar.png` (3840x64) and `dark-status-item.png` (700x60 from x=2440) show the live StatsLite item on the dark bar — white labels "CPU/MEM/GPU" with green/red/cyan pressure dots, clock present (rebuild settled). `magick -threshold 50% -connected-components 8` on the status-item crop: label-row glyph boxes (y=12..26 px) are 12–13 px tall (2x retina ≈ 6 pt cap height = 8 pt regular SF), matching the light measurement (12 px); 7 pt would measure ≈10 px. Value row is a separate row at y=30..48 px (14–19 px glyphs). |
| VAC-2 (one line inside the 39 pt block, no ellipsis, no clipping, ≥2.5 pt clearance per side) | light | PASS | Component data on `light-status-item.png`: each label sits in a single row (y=7..19 px, height ≤12 px), no second line, no ellipsis dots. Visual check of the same image shows "CPU", "MEM", "GPU" complete and unclipped. Clearance support from the green suite: `testLabelRowClearanceForMemRowAtEightPointRegularMeetsThreeAndAHalfPoints` passes with MEM total clearance 13.6406 pt, CPU 21.6836 pt, GPU 21.4375 pt — all far above 2.5 pt per side at 8 pt. |
| VAC-2 | dark | PASS | Same final capture: each label sits in one row (y=12..26 px), no second line, no ellipsis dots (all label glyphs ≥ 8 px wide, no dot triples), no clipping — the network block reads complete "2.0 MB/s / 23 KB/s" at the crop edge. Clearance is font-driven and identical across appearances; suite values apply: MEM 13.6406 pt, CPU 21.6836 pt, GPU 21.4375 pt — all ≥ 2.5 pt per side. |
| VAC-3 (zero `.animation`/`.contentTransition` on the status-item path) | static | PASS | Prior tester evidence: `rg` pattern `^\s*[^/].*\.animation` plus `\.contentTransition\(` over `MenuBarStackedItemView.swift`, `StatusItemController.swift`, `MenuBarAccessibility.swift`, `MenuBarBlockModel.swift` → no hits. Only comment lines mention the tokens. Carried forward, not re-run. |
| VAC-4 (scope exclusion: sparkline axis 9 pt, popover labels 11 pt semibold, values 12 pt unchanged) | static + suite | PASS | Prior tester evidence: `StatsLite/SparklineTimeAxisView.swift:25` → `.system(size: 9, weight: .regular).monospacedDigit()`. `MemoryPressureCardView.swift:31,34` / `NetworkCardView.swift:84,87` → `size: 11, weight: .semibold`. `MenuBarStackedItemView.swift:118` value → `size: 12, weight: .regular).monospacedDigit()`. Diff 154e17c..693548d touches only `MenuBarStackedItemView.swift` and `MenuBarValueTypographyTests.swift`. Carried forward, not re-run. |
| ISC-6 (MenuBarValueTypographyTests asserts 8 pt, passes, not weakened) | test run | PASS | Prior tester evidence: `xcodebuild test -only-testing:StatsLiteTests/MenuBarValueTypographyTests` → `Executed 14 tests, with 0 failures`. Diff is the source flip (`size: 7` → `size: 8`) plus fixture re-encode of expected widths. No assertion deleted or loosened. Carried forward, not re-run per task instruction. |

## Appearance flip record

```text
$ defaults write -g AppleInterfaceStyle Dark && killall SystemUIServer   # then wait + screencapture -x
$ defaults delete -g AppleInterfaceStyle && killall SystemUIServer
$ defaults read -g AppleInterfaceStyle
Error: Could not find key 'AppleInterfaceStyle' in domain 'kCFPreferencesAnyApplication'.
```

The restore ran from a shell `trap`, so it executed on both attempts. The key is confirmed gone. The Mac is left in light appearance.

Two capture attempts were made:

1. `screencapture -x -R<rect>` → `could not create image from rect`. Full-screen `screencapture -x` works, so `-R` is unavailable in this session.
2. Full-screen `screencapture -x` after `caffeinate -u`. The first full-screen shot was pure black (display asleep, mean=0 sd=0). After `caffeinate -u` the capture has real content, but the StatsLite status item is not on the captured menu bar. The app was launched from this worktree's Release binary (`.derivedData/Build/Products/Release/StatsLite.app`) and confirmed running before the flip. A second StatsLite instance from the parallel `panel-visual-baseline` worktree was also running; neither item appears in the capture. The clock is also missing from the captured menu bar, which points to a menu-bar rebuild in progress after `killall SystemUIServer` rather than a rendering defect in the app.

## Final dark capture (08:24, planner-run probe)

The earlier dark captures were taken during the menu-bar rebuild and missed the item. The final capture uses the same flip recipe with a settle-and-probe loop: `defaults write -g AppleInterfaceStyle Dark` + `killall SystemUIServer`, wait 15 s, launch the worktree Release app, wait 10 s, then full-screen `screencapture -x` after `caffeinate -u`. The probe shows the live item on the dark bar (white label text, colored dots, clock present). Capture saved as `dark-menubar.png` / `dark-status-item.png`; appearance restored afterward (`AppleInterfaceStyle` key absent = light, verified), app instance killed.

## Verdict

`### VERDICT: PASS`

VAC-1 and VAC-2 PASS in both appearances (light: pixel measurement on `light-status-item.png`; dark: pixel measurement on `dark-status-item.png`). VAC-3, VAC-4 PASS (static, prior evidence). ISC-6 PASS (suite). No visual defect found: no wrap, no ellipsis, no clipping, clearances ≥ 2.5 pt per side in both appearances.

## Artifacts

- `artifacts/2026-10-21-menu-bar-label-text-size-increase/dark-menubar.png` — dark menu bar, 3840x64 px, with the live StatsLite status item (final capture, 08:24)
- `artifacts/2026-10-21-menu-bar-label-text-size-increase/dark-status-item.png` — 700x60 crop of the status-item region from the final dark capture
- Light captures reused from the prior tester: `light-menubar.png`, `light-status-item.png`, `light-cpu-block.png`, `light-gpu-block.png`, `light-mem-block.png`
- This report file
