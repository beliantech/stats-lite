# Plan: Drop "Across N cores" and "Integrated Graphics" card subtitles

- Risk class: R2 (UI work; requires rendered VAC evidence)
- Branch: `task/drop-card-subtitles` in worktree `worktrees/drop-card-subtitles`
- Design authority: blueprint session `2026-10-17T03-54-02-134Z` (verdict GO, VAC-1…VAC-13)

## 1. Why

The user asked to remove two popover subtitles.
Current state: the CPU card shows `Across 18 cores` under the header
(`StatsLite/CPUCardView.swift:35`); the GPU card shows `Integrated Graphics`
(`StatsLite/GPUCardView.swift:31`).
Target state: neither string renders. Both cards show the header row, then the
sparkline, then the time axis. The state placeholders `Waiting for first sample`
and `Unavailable` stay, because they carry data-state meaning.

## 2. Falsification signature

If the only visual delta is the two subtitle rows, then after the edit:

- `Across` and `Integrated Graphics` are absent from the rendered popover in
  dark and light appearances.
- The CPU sparkline top edge sits 4 pt below the header row (was 4 pt below the
  subtitle).
- No other card, label, footer, or axis element moves or changes.

If any other element changes, the edit is wrong and stops here.

## 3. Evidence (measured or cited, no estimates)

- Strings and locations: `rg` over the repo, cited above.
- Popover width is fixed at 280 pt (`StatsLite/PopoverContentView.swift:56`),
  so there are no responsive width targets.
- `metricCardStyle()` applies 10 pt padding, no fixed card height
  (`StatsLite/DesignTokens.swift:59`). Card height derives from the VStack.
- Visual references before the edit: `artifacts/2026-10-17-chart-time-axis-all-metric-cards/after/{light,dark}.png`.
- Verification tool: `scripts/capture_baseline.sh` (switches appearance, opens
  the popover via the `--open-popover` hook, captures with `screencapture -l<id>`,
  restores appearance on exit).

## 4. Change inventory

Code files only (worktree). No test, config, or dependency changes.

### `StatsLite/CPUCardView.swift`

1. Lines 34-36, the always-present subtitle. Replace:
   ```swift
   Text(cpu == nil ? "Waiting for first sample" : "Across \(coreCount) cores")
       .font(.system(size: 10))
       .foregroundStyle(.tertiary)
   ```
   with:
   ```swift
   if cpu == nil {
       Text("Waiting for first sample")
           .font(.system(size: 10))
           .foregroundStyle(.tertiary)
   }
   ```
2. `cpuSummary` line 137: `"CPU usage is \(percent) percent across \(cpu.perCore.count) cores."`
   → `"CPU usage is \(percent) percent."`
   (The `guard let cpu` branch, line 135, is unchanged.)

### `StatsLite/GPUCardView.swift`

1. Lines 30-31: delete the two lines
   `Text("Integrated Graphics")` and `.font(.system(size: 10))`
   and the following `.foregroundStyle(.tertiary)` from inside the
   `if gpu != nil` branch. The branch body starts at `SparklineView(`.
   The `else` branch keeps `Text("Unavailable")`, `dashedContainer`, and the
   footnote untouched.
2. `summary` line 97: `"GPU usage is \(percent) percent on Integrated Graphics."`
   → `"GPU usage is \(percent) percent."`
   (The `guard let gpu` branch, lines 93-95, is unchanged.)

Not touched: file header comments in both files mention the subtitle as part of
the base blueprint. Update those comment lines to match, nothing else.

## 5. Step sequence

1. Planner: capture the baseline before any code edit:
   ```
   scripts/capture_baseline.sh --out-dir artifacts/2026-10-17-drop-cpu-gpu-card-subtitles/before
   ```
2. Coder spawn from the worktree makes only the four changes above (plus the two
   file header comments), commits with `git worktree` branch and conventional
   message `feat(popover): drop CPU/GPU card subtitles`.
3. Coder: rebuild and capture after-screenshots:
   ```
   scripts/capture_baseline.sh --out-dir artifacts/2026-10-17-drop-cpu-gpu-card-subtitles/after
   ```
4. Tester spawn validates VAC-1…VAC-13 below against the before/after sets
   (dark + light), reads the PNGs, and reports GO or NO GO with the failing IDs.
5. Plan-review spawn checks the diff against this file.
6. Planner: verify the test mandate, then present the verdict to the user.

## 6. VAC anchors (file:line for each invariant)

| ID | Invariant | Anchor |
|----|-----------|--------|
| VAC-1 | `Across` and `coreCount` subtitle absent from active CPU card | `StatsLite/CPUCardView.swift:35` removed |
| VAC-2 | CPU sparkline top edge 4 pt below header row (spacing 4 in the VStack) | `StatsLite/CPUCardView.swift:17` `VStack(spacing: 4)` |
| VAC-3 | `SparklineTimeAxisView` renders directly below the CPU sparkline | `StatsLite/CPUCardView.swift:48` |
| VAC-4 | Cores Breakdown disclosure still renders when `preferences.showCoreBreakdown` is true | `StatsLite/CPUCardView.swift:51-53` |
| VAC-5 | `cpu == nil`: `Waiting for first sample` renders, 10 pt tertiary | `StatsLite/CPUCardView.swift:34-37` (new) |
| VAC-6 | `Integrated Graphics` absent from available GPU card | `StatsLite/GPUCardView.swift:31` removed |
| VAC-7 | GPU sparkline top edge 4 pt below header row | `StatsLite/GPUCardView.swift:18` `VStack(spacing: 4)` |
| VAC-8 | `SparklineTimeAxisView` renders directly below the GPU sparkline | `StatsLite/GPUCardView.swift:38` |
| VAC-9 | `gpu == nil`: `Unavailable`, dashed container, footnote all render; no sparkline, no axis | `StatsLite/GPUCardView.swift:40-49` |
| VAC-10 | `metricCardStyle` still 10 pt padding, no clipping or border distortion | `StatsLite/DesignTokens.swift:59` |
| VAC-11 | Popover shrinks ~34 pt; all cards and footer fit with no clipping | captured full-window PNG |
| VAC-12 | VoiceOver label: `CPU usage is N percent.` and `GPU usage is N percent.` | `StatsLite/CPUCardView.swift:137`, `StatsLite/GPUCardView.swift:97` |
| VAC-13 | No `.animation` or `.contentTransition` added anywhere | repo rule, `rg` check |

## 7. Test mandate

No rendered-text unit target exists for these strings; screenshots are the
acceptance evidence. The tester must:
- Run `rg -n "Across .* cores|Integrated Graphics" StatsLite/` and expect zero
  hits in rendered `Text` (the GPU accessibility fallback string and file
  comments must not contain it either).
- Read all four PNGs (before/after × dark/light) and check VAC-1…VAC-11 against
  pixels, not against the diff.
- Report `NO GO` with failing VAC IDs if any invariant fails.
If a defect is found: report only, do not edit. The planner returns the defect
to the coder with the exact expectation, then re-runs the tester.
If the tester cannot exercise this flow (for example the capture script fails),
say so explicitly instead of guessing.

## 8. Self-verification (planner, before merge)

- Diff touches only the two Swift files listed.
- `git diff main` shows no test, config, or dependency changes.
- Test mandate is satisfied by the tester's GO report.
- Merge is fast-forward or squash into `main`.
