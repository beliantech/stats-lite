# Wave 1 step0 report: popover memory attribution measurement

Date: 2026-10-21 (Asia/Kuala_Lumpur). Branch: `fix/measure-footprint-harness`.
Plan: `.pi/plans/2026-10-20-popover-memory-attribution.json`, Wave 1.
No Swift source changed. `scripts/capture_baseline.sh` untouched.

## 1. Harness changes (`scripts/measure_popover_footprint.sh`)

- PID safety. The script captures `APP_PID=$!` right after launch. Every
  sample runs `footprint -w "$APP_PID"`. Cleanup runs
  `kill "$APP_PID"`. Liveness checks use `kill -0 "$APP_PID"`. No pgrep
  resolves the sampled pid.
- Wide sampling. Each sample parses `footprint -w` and logs: footprint
  total, graphics Dirty, Reclaimable, Wired, region count, IOSurface
  Dirty and Reclaimable, Malloc Small Dirty, phys_footprint_peak.
- Summary additions. Per-cycle open peaks for footprint and gfx Dirty,
  per-cycle gfx Dirty + Reclaimable invariant check, per-cycle
  idle-after-close values, max gfx regions, max gfx Reclaimable, and a
  run-level invariant verdict. The invariant is "stable" when the spread
  of (gfx_dirty + gfx_reclaim) is at most 20 percent of the per-cycle
  maximum inside the settled window open + 1.0 s to close + 1.5 s.
- Preserved. Flags `--output`, `--binary`, `--cycles`, `--hold`,
  `--tail`. Hook wiring `--open-popover`, `--popover-cycles`,
  `--popover-hold`. Epoch-stamped `[measurement]` event matching.

## 2. Real `footprint -w` column layout (this machine)

Table header, verbatim:

```text
  Dirty  (Swapped)      Clean  Reclaimable    (Wired)    Regions    Category
```text

Example category row, verbatim:

```text
1920 KB     1824 KB        0 B          0 B      64 KB         22    Owned physical footprint (unmapped) (graphics)
```text

awk field map: `$1/$2` Dirty, `$3/$4` Swapped, `$5/$6` Clean,
`$7/$8` Reclaimable, `$9/$10` Wired, `$11` Regions, `$12+` Category.
Every value is a `<number> <unit>` pair. Units seen: B, KB, MB. The
footprint total comes from the process header line
`StatsLite [pid]: 64-bit    Footprint: 42 MB (16384 bytes per page)`.
The peak comes from the Auxiliary data block
`phys_footprint_peak: 316 MB`.

Parser traps found and handled:

- `Malloc Small` spans two whitespace tokens. Match on
  `/Malloc Small$/`, not `$NF`.
- `Owned physical footprint (unmapped)` (no graphics suffix) is a
  separate category. The parser must match the `(graphics)` suffix.
- The `-v` region table uses different columns: `VRT DRT SWP CLN RCL
  WIRE` in pages.

## 3. Baseline run: spike reproduced

Command, run from the worktree:

```text
scripts/measure_popover_footprint.sh \
  --output /Users/jonathan/beliantech/stats-lite-macos/artifacts/2026-10-20-popover-memory-attribution/step0-baseline.txt \
  --cycles 3 --hold 15
```text

Release build via the script's own xcodebuild path. 202 samples, 0
failed ticks, 0 process misses. Full summary block, verbatim:

```text
cycle 1/3  open_ts 1792533467.065  close_ts 1792533482.311  peak_footprint_mb 326.0  peak_gfx_dirty_mb 279.0  peak_gfx_dirty+reclaim_mb 279.0
cycle 1/3  gfx_dirty+reclaim invariant: n 34  min 210.0  max 279.0  spread 69.0  spread_pct 24.7  stable no
cycle 1/3  idle_after_close: ts 1792533483.816  footprint_mb 201.0  gfx_dirty_mb 162.0  gfx_dirty+reclaim_mb 234.0
cycle 2/3  open_ts 1792533484.316  close_ts 1792533499.414  peak_footprint_mb 305.0  peak_gfx_dirty_mb 266.0  peak_gfx_dirty+reclaim_mb 266.0
cycle 2/3  gfx_dirty+reclaim invariant: n 35  min 170.0  max 266.0  spread 96.0  spread_pct 36.1  stable no
cycle 2/3  idle_after_close: ts 1792533500.883  footprint_mb 188.0  gfx_dirty_mb 146.0  gfx_dirty+reclaim_mb 202.0
cycle 3/3  open_ts 1792533501.460  close_ts 1792533516.467  peak_footprint_mb 292.0  peak_gfx_dirty_mb 250.0  peak_gfx_dirty+reclaim_mb 250.0
cycle 3/3  gfx_dirty+reclaim invariant: n 34  min 194.0  max 250.0  spread 56.0  spread_pct 22.4  stable no
cycle 3/3  idle_after_close: ts 1792533518.361  footprint_mb 185.0  gfx_dirty_mb 146.0  gfx_dirty+reclaim_mb 250.0
max_graphics_mb_across_opens 279.0
max_gfx_reclaim_mb 200.0  max_gfx_regions 61  max_gfx_dirty+reclaim_mb 279.0
invariant_gfx_dirty_plus_reclaim_stable no (stable if spread <= 20% of per-cycle max, window open+1.0s..close+1.5s)
overall_peak_footprint_mb 326.0
run_phys_footprint_peak_mb 326.0
final_idle_footprint_mb 185.0  final_idle_gfx_dirty_mb 146.0  idle_sample_ts 1792533557.695
samples 202  no_process_ticks 0  footprint_failed_ticks 0
```text

Measured vs expected:

| Metric | Expected (plan prior) | Measured |
| --- | --- | --- |
| open-peak gfx Dirty | ~163-250 MB | 279 / 266 / 250 MB (cycles 1-3) |
| open-peak footprint | 200-300+ MB | 326 / 305 / 292 MB |
| 8 MiB region count | 20-31 chunks | 61 at cycle 1 peak, settles at 53 |
| Malloc Small Dirty | flat ~23 MB | 17 -> 18 MB, flat |
| RenderBox IOSurface | ~2.80 MB | 2.9-6.2 MB Dirty at open |
| pre-open graphics | ~640 KB | 0.0 MB at 0 regions |

The spike reproduces. Cycle 1 exceeds the plan's prior: 279 MB equals
35 chunks of 8.0 MiB at peak.

## 4. gfx_dirty + gfx_reclaim invariant: no at the 20 percent threshold

The harness verdict is "stable no" for all three cycles (spread 24.7,
36.1, 22.4 percent). The raw samples explain why:

- The Dirty to Reclaimable flip itself is exact at constant region
  count. Cycle 3 quotes:
  `1792533507.341 SAMPLE 289.0 250.0 0.0 249.0 53 ...` (Dirty 250,
  Reclaim 0), then `1792533508.267 SAMPLE 185.0 146.0 104.0 145.0 53 ...`
  (Dirty 146, Reclaim 104, and 146 + 104 = 250).
- Between re-locks the Reclaimable side drains in ~16 MB steps while
  Dirty stays flat: 104 -> 88 -> 72 -> 56 -> 48. The sum falls
  250 -> 202 between flips, so the sum is not constant across the hold.
- The plateau itself shrinks cycle over cycle: 279 MB at 61 regions,
  then 266, then 250 at 53 regions.
- One whole-pool flip occurs:
  `1792533549.847 SAMPLE 44.0 1.8 200.0 0.1 48 ...` shows footprint 44 MB
  with 200 MB Reclaimable for a single sample.
- The full re-lock period is ~5.0 s. Spike timestamps 522.5, 527.1,
  532.2, 537.1, 542.5 are 4.6-5.4 s apart. This is slower than the 1 s
  app tick.

New fact for Wave 2 and 3. After the first popover open, the ~5 s
re-lock continues while the popover is closed. All spikes at 522-542 s
fall after the close at 516.467 s. 41 s after the last close the
footprint is still 185 MB with 146 MB graphics Dirty. The plan's
"closed popover: graphics 640 KB" prior holds only before the first
open or after a long idle.

## 5. H6 WindowServer snapshot: blocked, no root in this session

Intended command: `sudo footprint -v --unmapped -w <pid>` at open + 0.5 s
and open + 2.5 s during a
`--open-popover --popover-cycles 1 --popover-hold 20` run.

What failed, verbatim:

- `sudo: a terminal is required to read the password; either use ssh's -t option or configure an askpass helper`
- `sudo: a password is required` (sudo exit 1)
- Without root the tool refuses:
  `footprint: Must run as root.` (footprint exit 77)

The failure records are saved in place in
`artifacts/2026-10-20-popover-memory-attribution/step0-unmapped-open-a.txt`
and `.../step0-unmapped-open-b.txt`. No sudo bypass was attempted.

Run commands for the user (from the main repo root):

```text
APP=/Users/jonathan/beliantech/stats-lite-macos/worktrees/measure-footprint-harness/.derivedData/Build/Products/Release/StatsLite.app
"$APP/Contents/MacOS/StatsLite" --open-popover --popover-cycles 1 --popover-hold 20 &
PID=$!
# Watch stderr for "[measurement] <epoch> cycle 1/1 open", then:
sudo footprint -v --unmapped -w "$PID" > artifacts/2026-10-20-popover-memory-attribution/step0-unmapped-open-a.txt   # at open+0.5s
sudo footprint -v --unmapped -w "$PID" > artifacts/2026-10-20-popover-memory-attribution/step0-unmapped-open-b.txt   # at open+2.5s
kill "$PID"
```text

These overwrite the failure stubs. That is intended.

Partial substitute, no root needed. Own-process regions are readable
without root, so an unprivileged `footprint -v -w` was captured at
open + 2.5 s into
`artifacts/2026-10-20-popover-memory-attribution/step0-v-open-own.txt`.
What it proves:

- 31 unmapped regions of exactly 512 pages (8.0 MiB) carry the category
  `Owned physical footprint (unmapped) (graphics)`. 20 are Dirty and
  Wired. 11 are fully Reclaimable. Quotes:

```text
        unmapped -         unmapped [b0be0f28e1282dab]     512     512       0       0       0     512   Owned physical footprint (unmapped) (graphics)
        unmapped -         unmapped [9100ba160b9c21e1]     512       0       0       0     512       0   Owned physical footprint (unmapped) (graphics)
```text

- Two RenderBox IOSurfaces are mapped at open:

```text
       119768000 -        119a34000 [ebcb8c49fcb0f59d]     179     179       0       0       0       0   IOSurface SID: 0x1d1  596x1200 (l10r)  'RenderBox'
       118de4000 -        119088000 [4ed522657e8b4a7b]     169       0       0       0     169       0   IOSurface SID: 0x1d0  596x1134 (l10r)  'RenderBox'
```text

The 596x1200 surface is 179 pages, that is 2.80 MB Dirty, the surface
the plan cites. The 596x1134 surface is 169 pages, 2.70 MB Reclaimable.

What stays unanswered: whether WindowServer or any other userspace
process maps the same 512-page chunks. The `--unmapped` cross-process
search needs root. H6 stays open until the user runs the sudo commands
above.

## 6. Deviations from the plan

- Pre-launch instance quit. The Wave 1 exit criterion says the harness
  "never pkills by name". The Wave 1 task note says the script quitting
  the running StatsLite instance is expected behavior for now. The
  script keeps one pre-launch `pkill -x StatsLite` and removes all
  name-based logic from sampling and cleanup. Flagged for the planner.
- H6 snapshots. Root was unavailable, so the snapshots did not run.
  The stubs and the runbook in section 5 are the deliverable for this
  step.
- Third artifact. `step0-v-open-own.txt` carries the unprivileged `-v`
  capture used for the region-state and RenderBox quotes.
- Re-lock cadence. Measured at ~5.0 s, not 1 s. Reported as fact. No
  code touched.
- Fail-fast validation. A `--cycles bogus` run aborted at arithmetic
  time after the app had already launched. The script now validates
  `--cycles`, `--hold`, `--tail` as digit-only before any launch or
  build. Negative path verified:
  `error: --cycles must be a non-negative integer (got: bogus)` with
  exit 2 and no app process created.
- Foreign instance observed. The user's Xcode-launched Debug instance
  (pid 92491, started 05:14) survived the pre-launch `pkill` (probably
  suspended by Xcode with SIGTERM pending). The old pgrep-based sampler
  would have measured this wrong process. The exact-PID sampler was
  immune: every baseline sample carried `# pid: 5645`.
- Artifact placement. The `.txt` artifacts live at the main repo root
  in `artifacts/2026-10-20-popover-memory-attribution/` as untracked
  files. This `.md` is committed in the worktree at the same relative
  path, so it lands at the main repo root when the branch merges.

## 7. Files

- `scripts/measure_popover_footprint.sh` (modified, committed)
- `artifacts/2026-10-20-popover-memory-attribution/step0-report.md`
  (this file, committed in the worktree)
- `artifacts/2026-10-20-popover-memory-attribution/step0-baseline.txt`
  (main repo root, untracked artifact)
- `artifacts/2026-10-20-popover-memory-attribution/step0-unmapped-open-a.txt`
  (main repo root, untracked, sudo failure stub)
- `artifacts/2026-10-20-popover-memory-attribution/step0-unmapped-open-b.txt`
  (main repo root, untracked, sudo failure stub)
- `artifacts/2026-10-20-popover-memory-attribution/step0-v-open-own.txt`
  (main repo root, untracked)

## 8. H6 verdict addendum (user-run sudo snapshots, 2026-10-21)

The user ran the section 5 runbook. Snapshots (overwrote the stubs):
`step0-unmapped-open-a.txt` (open+1 s, footprint 204 MB) and
`step0-unmapped-open-b.txt` (open+3 s, footprint 185 MB).

H6 is FALSIFIED: the 8 MiB chunks are not WindowServer-shared surfaces.

- Snapshot a: `Shared with WindowServer [859]:` contains exactly one
  region, 8192 KB, category `CoreAnimation (graphics)`, TOTAL 8192 KB.
  Nothing else is shared.
- The `Owned physical footprint (unmapped) (graphics)` chunks total
  154 MB / 51 regions (a) and 146 MB / 40 regions (b). Every one of the
  512-page object-ids was checked across the whole file: each appears
  exactly once, in StatsLite's own table. No other process maps them.
- Snapshot b has no `Shared with WindowServer` section at all.

Conclusion: the 146-154 MB charge is private kernel/GPU-driver memory
wired to StatsLite's own task ledger. WindowServer shares only 8 MB
(CoreAnimation). App-side remedies can reach the full target.
