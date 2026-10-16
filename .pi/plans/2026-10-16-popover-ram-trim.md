# Plan: Trim Popover RAM Spike (Graphics Blur Surfaces)

**Risk class:** R1 (normal behavior change — UI rendering internals, no API/schema/auth change)
**Status:** Awaiting approval → plan-review

## Intent

Opening the StatsLite popover spikes process footprint from ~40MB idle to 182-233MB.
Measurement proves 80% of the spike is one region: `Owned physical footprint (unmapped)
(graphics)` at ~167MB dirty. The cause is a redundant SwiftUI `.background(.regularMaterial)`
backdrop blur stacked on top of `NSPopover`'s own native vibrant frame, amplified by
transition animations during popover mount. This plan removes the redundant blur and the
animation churn so the peak drops below 100MB with zero visual change.

Oracle verdicts (2 sessions, 2026-10-16): `.regularMaterial` removal is the primary fix
(-70 to -120MB); `popover.animates = false` secondary (-10 to -25MB); card
transitions/animations housekeeping (-5 to -10MB). Architecture stays: thin AppKit shell
retained (verified against macOS 26 docs — `MenuBarExtra` cannot do stacked labels,
dynamic length, LSUIElement settings, or close-teardown on any macOS). The memory fix is
independent of deployment target.

## ISC (binary)

- [ ] **I1** Peak `footprint <pid>` while popover is open is < 100MB (release build, A/B
      sampler at 0.4s, popover driven by the harness cycling hook — open 5s / close / ×3;
      peak measured across all cycles). Baseline today: 182-233MB.
- [ ] **I2** Region `Owned physical footprint (unmapped) (graphics)` at peak is < 50MB.
      Baseline today: 167MB.
- [ ] **I3** After the final cycle closes the popover, idle footprint returns to ≤ 50MB
      within 30s (measured from the same sampler run).
- [ ] **I4** Visual acceptance via numbered VAC items, each checked against baseline vs
      candidate screenshots (light + dark):
  - **VAC-1** Popover base background in **light** mode matches baseline: no visible seam
    at popover edge, no banding, content region uniformly filled.
  - **VAC-2** Popover base background in **dark** mode matches baseline: same as VAC-1.
  - **VAC-3** Card fill legibility: CPU/RAM/GPU card backgrounds show the same relative
    contrast against the popover base as baseline; card border/fill edges crisp, no bleed.
  - **VAC-4** Sparkline and text legibility unchanged vs baseline in both modes.
- [ ] **I5** CPU card **per-core disclosure toggle** (the only toggle inside the popover)
      expands/collapses the core grid; card content updates stay **discrete** (no
      animation) per the repo rule "status item views: no `.animation`/`.contentTransition`".
- [ ] **I6** Typecheck + lint on changed files = 0 errors; existing tests pass.

Failure modes:
- **FM1** Removing `.regularMaterial` leaves the popover visually wrong (background too
  opaque/transparent, card contrast loss) → visual check I4 fails → restore a cheaper
  background (flat `Color(nsColor: .windowBackgroundColor)`-style fill) and re-verify.
- **FM2** Graphics region stays ≥ 50MB after fix → attribution was incomplete; re-run
  `footprint -v --unmapped` + `vmmap` while open, report to user before further changes.
- **FM3** Popover opens without animation but a close-side artifact appears (flash/flicker)
  → I4 fails → reassess `animates = false` (revert only that line, keep material removal).

## Approach

Phase 1 — attribution + baseline capture (no behavior change yet):
- Relaunch release build, open popover, run `footprint -v --unmapped <pid>` and
  `vmmap -pages -submap <pid> | rg -i IOSurface` to pin the surface ownership record.
- Capture **baseline screenshots** (pre-change, mandatory before any edit):
  - Popover opened via the harness cycling hook (T1a: open 5s / close 2s / 3 cycles),
    dark mode on, light mode on.
  - Window id resolved by `scripts/windowid.swift` (CGWindowListCopyWindowInfo), captured
    with `screencapture -x -o -l<windowid>`.
  - Saved to `artifacts/2026-10-16-popover-ram-trim/baseline/{dark,light}.png`.
  - Appearance switched via `osascript -e 'tell app "System Events" to tell appearance
    preferences to set dark mode to true|false'`; switch back to the user's original
    value (captured at script start) on exit, even on failure (trap).

Phase 2 — fixes, one worktree, single task:
- **T1** (coder): three edits — TDD order matters, see below:
  1. `StatsLite/PopoverContentView.swift:55` — delete `.background(.regularMaterial)`.
  2. `StatsLite/PopoverContentView.swift:56-57` — delete the two `.animation(...)` modifiers
     and the three `.transition(.opacity)` on cards.
  3. `StatsLite/StatusItemController.swift` — `popover.animates = false` at init.
  (The `--open-popover` hook ships in T1a, before these edits.)
- TDD posture: this is a rendering/measurement change with no existing unit-test surface
  for GPU allocation; behavior is verified by the footprint harness (I1-I3) and visual
  check (I4). Red phase = write the A/B measurement script first as the failing harness
  (records peak > 100MB on current code = documented red), green = fixes bring it under.
  Marker: `[red]` for T1a (harness), no marker for T1b (implementation).

Phase 3 — verification:
- Rebuild release. Run `scripts/measure_popover_footprint.sh --candidate`:
  launches the app with `--open-popover`, samples footprint at 0.4s (name-resolved pid),
  records peak + graphics-region max, writes `.pi/plans/2026-10-16-popover-ram-trim/
  footprint-candidate.txt` (baseline run wrote `footprint-baseline.txt`). Check I1-I3.
- Capture candidate screenshots to `artifacts/2026-10-16-popover-ram-trim/candidate/
  {dark,light}.png` with the same harness path; diff VAC-1..VAC-4 against baseline.
- Toggle check (I5): programmatic click on the CPU per-core disclosure via the harness
  (or manual user confirmation, recorded as a receipt with user sign-off in session log).
- Tests/lint (I6).
- If FM2 triggers: stop, report measurements to user.

Phase 4 — review, merge, done.

## Refactors

None required. No band-aids touched. Existing design decisions respected:
`HistoryBuffer` double-storage (commit `ee56bed`) untouched; teardown-on-close path kept;
deployment target unchanged (14.0) — the fix works on any macOS.

Note (out of scope, logged): AppKit launch warning
`layoutSubtreeIfNeeded called on a view which is already being laid out` fires on every
launch — separate bug, not part of this plan.

## Notation

Plan → Phase → Task (`T1a`, `T1b`, `T2`) → Receipts (red SHA / green SHA / review verdict).

## Task list

- [ ] **T1a** — Measurement harness **+ debug hook, built and baseline-run before any
      rendering edit**:
  1. Debug hook (accessibility permission unavailable; osascript clicks fail with -1719):
     `--open-popover` launch argument drives a **cycle**: open popover ~1s after launch,
     hold 5s, close (goes through `popoverDidClose`, releasing the controller), wait 2s,
     repeat for **3 cycles**. `--popover-cycles N` (default 3) and `--popover-hold Ns`
     override. Inert without the flag. Documented in a code comment as measurement support.
  2. `scripts/measure_popover_footprint.sh` (launches app with the hook, name-resolved
     0.4s sampler, writes sample log to
     `.pi/plans/2026-10-16-popover-ram-trim/footprint-{baseline,candidate}.txt`; extracts
     per-cycle open peak and post-close idle return).
  3. `scripts/windowid.swift` (CGWindowID resolver) + screenshot capture
     (`artifacts/2026-10-16-popover-ram-trim/{baseline,candidate}/{dark,light}.png`).
  4. Dark/light switching with trap-guarded restore of the user's original appearance.
  5. **Baseline run executes in this task with the hook built in, before any rendering
     edit** (captures baseline screenshots + footprint-baseline.txt; red phase = baseline
     peak > 100MB recorded).
      red ⏳ · green ⏳ · review ⏳
- [ ] **T1b** — Implement the 3 rendering fixes (material, animations, animates=false).
      red n/a · green ⏳ · review ⏳
- [ ] **T2** — Verification: rebuild, candidate harness run, VAC-1..VAC-4 visual diff,
      I5 toggle check, tests/lint. red n/a · green ⏳ · review ⏳
