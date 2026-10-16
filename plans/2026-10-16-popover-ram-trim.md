# Plan: Trim Popover RAM Spike (Graphics Blur Surfaces)

**Risk class:** R1 (normal behavior change — UI rendering internals, no API/schema/auth change)
**Status:** CLOSED — reverted by user decision. No changes merged to main.

## Outcome (2026-10-16)

The fix hypothesis was **disproven by measurement**. FM1 and FM2 triggered at T2.

| Criterion | Target | Baseline (red) | Candidate | Verdict |
|---|---|---|---|---|
| I1 open peak < 100MB | <100 | 203/208/206 MB | 203/207/207 MB | FAIL — zero improvement |
| I2 graphics region < 50MB | <50 | 163 MB | 163 MB | FAIL (FM2) |
| I3 idle ≤ 50MB | ≤50 | 32 MB | 31 MB | PASS |
| I4 VAC-1..4 visuals | identical | — | light mode: base 176→70 gray, text contrast 5.8:1→1.9:1 | FAIL (FM1) |
| I5 per-core toggle | discrete | — | untouched, suite green | PASS |
| I6 tests | 0 fail | — | 195/195 | PASS |

**Root cause of the miss:** the 163MB graphics region is allocated by `NSPopover`'s own
`NSVisualEffectView` + WindowServer/Metal driver init — not by the SwiftUI
`.regularMaterial`. Candidate re-measurement on the fixed binary showed the identical
203MB peak and 163MB graphics dirty at open, collapsing to ~72MB *reclaimable* within
seconds. The spike is intrinsic to opening any popover on this hardware, transient, and
mostly returned to the system ~1.5s after open. **Not fixable by app code.**

Removing `.regularMaterial` bought zero memory and visibly broke light mode, so the user
ordered a full revert. Main never received any app-code change (only plan docs).

## Artifacts (kept for the record)

- `.pi/plans/2026-10-16-popover-ram-trim/footprint-baseline.txt` — red-phase run
- `.pi/plans/2026-10-16-popover-ram-trim/footprint-candidate.txt` — candidate run
- `.pi/plans/2026-10-16-popover-ram-trim/t2-verification.md` — full VAC/ISC verdicts
- Worktree commits (branch deleted, SHAs still readable in reflog):
  `bb16030` harness + hook · `54b1439` rendering fixes · `74449b9` verification captures

## Intent (original, for history)

Opening the StatsLite popover spikes process footprint from ~40MB idle to 182-233MB.
Measurement shows 80% of the spike is `Owned physical footprint (unmapped) (graphics)`
at ~167MB dirty. This plan tested the hypothesis that a redundant
`.background(.regularMaterial)` on top of NSPopover's native frame caused it. It did not.

## Final positions

- **Keep:** the measurement harness was also reverted per user decision; if future work
  needs it, recover from reflog SHA `bb16030`.
- **Architecture:** thin AppKit shell confirmed correct (two oracle sessions, macOS 26
  verified). No rewrite.
- **Memory:** the open-spike is transient/reclaimable; idle is healthy at 31-40MB with a
  clean teardown. No action needed.
- **Logged, out of scope:** AppKit launch warning `layoutSubtreeIfNeeded` re-entrancy
  fires on every launch — separate bug if ever pursued.

## Task list (final)

- [x] **T1a** — harness + hook + baseline run. red `bb16030` (peak 203/208/206 MB,
      graphics 163 MB → RED confirmed). green n/a · review PASS (plan r3)
- [x] **T1b** — 3 rendering fixes. red n/a · green `54b1439` (195 tests, 0 failures)
      · review n/a — superseded by T2 FAIL
- [x] **T2** — verification. green `74449b9` · verdict **FAIL (FM1+FM2)** · stopped, no fixes
- [x] **Revert** — branch `feat/2026-10-16-popover-ram-trim` and worktree removed;
      nothing merged to main (by design).
