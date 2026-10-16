# Waiver Note — Screenshot Checks Skipped

Plan: `2026-10-16-menu-bar-label-network-regular`
Date: 2026-10-16

## Waiver

User authority (carried over from plan `2026-10-16-menu-bar-regular-weight`): all menu bar
strip captures and screenshot-based visual checks are SKIPPED for this change.

## Reason

This session has no macOS Screen Recording permission. Rect and cross-process window
captures fail with `could not create image from display` / `could not create image from rect`
and exit 1. Only captures of the app's own windows succeed.

## Probe (2026-10-16, before the first code edit)

Command: `screencapture -x /tmp/waiver_probe_label_network.png`
Result: exit 1, no file written, stderr `could not create image from display`.
The waiver basis holds. The probe did not falsify the waiver.

## Scope

- SKIPPED: all screenshot and strip captures (dark, light, menu bar strips).
- Binding: every test-based IC in the plan (labels 8 pt regular, network 9 pt regular,
  values 10.5 pt regular retained, clearance guards, zero animation, suite green).
- Waived: visual ICs (stroke blend against the system clock, appearance-level render
  checks). The ledger records them as `waived (user authority, 2026-10-16)`.
- The zero-tolerance visual policy stays active for any defect the user reports by eye.
