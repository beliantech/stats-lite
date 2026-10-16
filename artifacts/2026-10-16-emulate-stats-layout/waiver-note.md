# Waiver Note — Screenshot Checks Skipped

Plan: `2026-10-16-emulate-stats-layout`
Date: 2026-10-16

## Waiver

User authority (carried over from plan `2026-10-16-menu-bar-regular-weight`): all menu bar
strip captures and screenshot-based visual checks are SKIPPED for this change.

## Reason

This session has no macOS Screen Recording permission. Rect and cross-process window
captures fail with `could not create image from display` and exit 1. Only captures of the
app's own windows succeed.

## Probe receipts

- Plan `2026-10-16-menu-bar-regular-weight`: probe exit 1 (commit `8b0ce41`).
- Plan `2026-10-16-menu-bar-label-network-regular`: probe exit 1 (waiver-note.md, same dir family).
- Designer session probes for this round: exit 1, `could not create image from display`.
- Fresh probe for this plan (2026-10-16, before the first code edit):
  `screencapture -x /tmp/waiver_probe_emulate_stats.png` -> exit 1, no file.
  The waiver basis holds. The probe did not falsify the waiver.

## Scope

- SKIPPED: all screenshot and strip captures (dark, light, menu bar strips).
- Binding: every test-based IC in the plan (labels 7 pt regular, values 11 pt regular mono,
  both VStack spacings 0, clearance guard at the relaxed 2.5 pt threshold, network fonts
  9 pt regular unchanged, zero animation, suite green).
- Waived: visual ICs (stroke blend against the system clock, appearance-level render checks).
  The ledger records them as `waived (user authority, 2026-10-16)`.
- User override recorded: category labels adopt 7 pt despite the earlier non-Retina
  legibility finding. VoiceOver access covers the non-visual path.
- The zero-tolerance visual policy stays active for any defect the user reports by eye.
