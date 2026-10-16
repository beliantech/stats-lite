# T2 verification report (popover RAM trim)

Date: 2026-10-16. Worktree: `worktrees/2026-10-16-popover-ram-trim`, branch at
`54b1439` (on top of `bb16030`). Verdict: **STOP. FM1 and FM2 triggered.** No fix
was attempted.

## I1 — per-cycle open peak footprint < 100 MB: FAIL

Candidate run (`scripts/measure_popover_footprint.sh --output
.pi/plans/2026-10-16-popover-ram-trim/footprint-candidate.txt`, release rebuild,
3 cycles, 5 s hold, 0.4 s sampler):

| Metric | Baseline | Candidate | Target |
| --- | --- | --- | --- |
| Cycle 1 open peak | 203.0 MB | 203.0 MB | < 100 MB |
| Cycle 2 open peak | 208.0 MB | 207.0 MB | < 100 MB |
| Cycle 3 open peak | 206.0 MB | 207.0 MB | < 100 MB |
| Run phys footprint peak | 208 MB | 208 MB | — |

The candidate numbers match the baseline within 1 MB. The change produced no
reduction. Data quality: 124 samples, 0 missing-process ticks, 0 footprint
failures. The changed screenshots confirm that the run used the T1b binary.

## I2 — graphics region dirty at open < 50 MB: FAIL

Max graphics-region dirty across opens: candidate **163.0 MB**, baseline
**163.0 MB**, target < 50 MB. Identical to baseline. **FM2 triggered**: the
graphics region stayed at 163 MB, so the blur-surface attribution was
incomplete. Raw samples show 163 MB at each open, for example epoch
1792126129.221 `SAMPLE 207 MB 163 MB 207 MB`.

## I3 — idle ≤ 50 MB within 30 s of final close: PASS

Final close at epoch 1792126141.254. Footprint fell to 38 MB by epoch
1792126142.749 (1.5 s after close) and to 34 MB by epoch 1792126147.270
(6 s after close). Final idle sample: 31.0 MB footprint, 1.2 MB graphics,
epoch 1792126182.993. All values are within target. Baseline was 32 MB.

## I4 / VAC-1..VAC-4 — visual acceptance: FAIL (VAC-1, VAC-3, VAC-4)

Screenshots: `artifacts/2026-10-16-popover-ram-trim/baseline/{light,dark}.png`
vs `candidate/{light,dark}.png`. Values are 0-255 gray levels sampled with
PIL. Backdrop-dependent material color can drift a few levels between runs, so
only large deltas are treated as defects.

- **VAC-1 light base background: FAIL.** The candidate base is much darker
  than baseline. Left base margin on row 250: baseline 176, candidate 70.
  Gap between cards: baseline 192, candidate 111. The baseline popover reads
  as a light, near-white panel with black title text. The candidate reads as
  a flat mid-gray panel with a muted gray title. The fill is uniform and the
  edge transition is clean, but the shade mismatch is obvious to a user.
- **VAC-2 dark base background: PASS.** Base samples: baseline 33-35,
  candidate 24-32. The two dark screenshots look the same side by side. No
  seam at the edge, no banding, uniform fill. The delta is at most 9 levels,
  which a user does not notice.
- **VAC-3 card fill legibility: FAIL (light).** Card fill versus base:
  baseline card 224 on base 176 (delta 48), candidate card 189 on base 70
  (delta 119). The relative contrast against the base more than doubled, so
  the cards pop against a darker field in a way they did not at baseline.
  Edges are crisp with no bleed in both modes. Dark mode is unchanged in
  practice: baseline card 58 on base 34, candidate card 54 on base 25.
- **VAC-4 sparkline and text legibility: FAIL (light).** Dark mode is
  unchanged: title 233 on base 34 at baseline, title 231 on base 24 in
  candidate, contrast about 13:1 in both. In light mode the title contrast
  drops from about 5.8:1 (glyph 53 on base 177) to about 1.9:1 (glyph 21 on
  base 70). Footer text sits on base 185 at baseline and base 103 in
  candidate. Sparkline marks are unchanged in both modes. The light-mode text
  sits on a much darker base and loses legibility.

**FM1 triggered**: removing `.regularMaterial` left the popover visually
wrong in light mode, with background shade and card-contrast changes.

**FM3 not triggered on available evidence**: the captures are static frames
taken while the popover is open, so a close-side flash cannot be ruled out by
these images. No close-side artifact was observed.

## I5 — per-core disclosure toggle: PASS (code and test evidence)

Limitation: no accessibility permission is available, so no programmatic or
manual click was performed. Evidence instead:

- `git show 54b1439` touches only `StatsLite/PopoverContentView.swift` and
  `StatsLite/StatusItemController.swift`.
- The diff removes three `.transition(.opacity)` lines, one
  `.background(.regularMaterial)` line, two `.animation(...)` lines, adds
  `popover.animates = false`, and updates header comments. The
  `coresExpanded: $coresExpanded` binding and the disclosure button code in
  the CPU card are not in the diff.
- Full test suite passes (see I6).

The toggle path is unchanged by the T1b diff.

## I6 — build, tests, lint: PASS

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test
  -project StatsLite.xcodeproj -scheme StatsLite -derivedDataPath .derivedData`
  → **TEST SUCCEEDED. 195 tests executed, 0 failures (0 unexpected).**
- Typecheck: the Release build and the test build both compile with 0 errors.
- Lint: no SwiftLint config and no `swiftlint` binary exist in this repo, so
  there is no lint step to run.

## Housekeeping

- Worktree git status: clean apart from the verification artifacts committed
  with this report.
- Commits present: `bb16030` (harness), `54b1439` (T1b rendering edits).
- The original StatsLite app at
  `/private/tmp/statslite-dd/Build/Products/Release/StatsLite.app` was killed
  by the harness (previous pid 98910) and relaunched at the end of this task
  (new pid 15406).

## Conclusion

STOP per plan Phase 3. I1, I2, I4 (VAC-1, VAC-3, VAC-4) fail. **FM2**
(graphics region stays ≥ 50 MB) and **FM1** (visual wrong after material
removal) both triggered. Report to the user before further changes.
