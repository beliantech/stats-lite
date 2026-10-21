# Plan: Network dot contrast and size

Task: `feat/2026-10-20-network-dot-contrast-size`
Worktree: `/Users/jonathan/beliantech/stats-lite-macos/worktrees/2026-10-20-network-dot-contrast-size`

## Problem

The status item download dot uses `systemBlue`. On a mid-tone steel-blue
menu bar it measures 1.39:1 contrast (1.13:1 against the selection pill),
below the WCAG 2.2 SC 1.4.11 minimum of 3.0:1. It fails because it shares
the blue hue of the wallpaper. The 6 pt dots also outweigh the 9 pt rate
text: 6 / 11 = 54.5% of row height.

## Design decision (designer blueprint, 2026-10-20)

- Download dot: adaptive token. Dark mode `systemCyan` (#3CD3FE, 8.52:1 on
  dark bar, 2.09:1 on steel-blue bar). Light mode `systemBlue` (#0088FF,
  3.52:1 on white).
- Upload dot: keep `systemRed` (5.24:1 dark, 3.57:1 light). No change.
- Dot size: 6 pt -> 5 pt. Matches the MEM ratio (4/7 = 0.57 ~ 5/9 = 0.56),
  lands on a whole 10 px on 2x Retina, and lifts worst-case clearance for
  `999 MB/s` from 1.89 pt to 2.89 pt. 4 pt rejected: loses color
  discriminability at 60-80 cm.
- Popover legend dots follow the same tokens for parity.

## Changes

1. `StatsLite/DesignTokens.swift`: add `Color.networkUpload`
   (`systemRed`), `Color.networkDownload` (adaptive cyan/blue), and
   `networkDotSize: CGFloat = 5`.
2. `StatsLite/MenuBarStackedItemView.swift:150-151,165-166`: use the new
   tokens. Update the doc comments that name 6 pt and `systemBlue`.
3. `StatsLite/NetworkCardView.swift:102-103,111-112`: use the same tokens.
4. `StatsLite/MenuBarBlockModel.swift:57`: comment says 6 pt dot with
   1.09 pt clearance. Update to 5 pt / 2.89 pt.
5. `StatsLiteTests/MenuBarValueTypographyTests.swift:432-446`: change
   `6.0` to `5.0` in the clearance formula, the failure message, and the
   expected value `1.8916` -> `2.8916`.

## Verification

- `xcodebuild test` on the worktree passes.
- Visual: `scripts/capture_baseline.sh` before the edit, `scripts/verify_ui_layout.sh`
  after. No `.animation` / `.contentTransition` in status item views.

## Out of scope

- No `networkBlockWidth` change (50 pt stays).
- No change to CPU/MEM/GPU dot sizes.
