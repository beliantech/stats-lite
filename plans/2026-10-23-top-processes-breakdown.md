# Plan: Top Processes Breakdown (CPU / Memory disclosure in the popover)

Date: 2026-10-23
Status: approved-review (GO 2026-10-23)
Branch (planned): `feat/2026-10-23-top-processes-breakdown`

## 1. Background & Goal

Motivation (user story): "I see high CPU/GPU/MEM use and I want to see the top 5-6
processes going on." When a metric spikes, the user needs the responsible processes
inside the existing menu-bar popover, without opening Activity Monitor.

Goal: add a `Top Processes` disclosure to the CPU and Memory metric cards. Expanding it
shows the top 5 processes by instantaneous CPU % (or by memory footprint). The GPU card
shows a graceful "unavailable" state because macOS restricts per-process GPU attribution
for unprivileged apps.

Scope:
- In scope: per-process sampling subsystem (libproc), lazy start/stop tied to disclosure
  state, disclosure rows in CPU/Memory/GPU cards, accordion policy, tests, VAC evidence.
- Out of scope: per-process sparklines (banned — RAM contracts), per-process GPU metrics,
  a Settings toggle for the section (v1 keeps it always visible, collapsed), menu-bar
  (status item) changes.

## 2. Requirements

User-facing behavior:
- R1. Each of the CPU, Memory, GPU cards shows a collapsed `> Top Processes` disclosure
  row in the established `> Cores Breakdown (18 Cores)` style (`StatsLite/CPUCardView.swift:66-83`).
- R2. Expanding shows up to 5 rows, sorted descending: process name + PID, a proportional
  capsule gauge, and a right-aligned monospaced value (`84.2%` for CPU, `6.8 GB` for
  Memory). Fewer rows render when fewer scannable processes exist — no blank slots.
- R2b. Empty state: if a scan returns zero processes (or fails), show the static line
  `No process data available` (9.5 pt tertiary). No usage threshold gates the list — it
  always shows the top N own-UID processes, however small their share.
- R3. Sampling runs only while a section is expanded. Collapsed or closed popover =
  zero process-sampling overhead and zero per-PID state. The disclosure state drives the
  sampler: `PopoverContentView.onChange(of: expandedProcessCategory)` calls
  `monitor.startProcessSampling(category:)` on expand and `monitor.stopProcessSampling()`
  on collapse-to-nil.
- R4. Accordion: only one card's process list can be expanded at a time
  (`@State expandedProcessCategory` in `PopoverContentView`).
- R5. CPU first-expand shows a static "Sampling top processes…" line (no spinner), then
  the first list within ~250 ms; steady state ticks at `PreferencesStore.refreshInterval`
  (1/2/3/5 s).
- R6. Memory first-expand renders on tick 0 (no delta needed).
- R7. GPU disclosure expands to the dashed unavailable container:
  "Per-process GPU metrics unavailable".
- R8. Expansion state resets on popover close (existing `@State` reset semantics,
  `StatsLite/StatusItemController.swift:261-269`).

Technical requirements (paths from the scout recon; verbatim citations in §5):
- T1. `SystemMetricsProvider` (`StatsLite/SystemMetricsProvider.swift:12`): two new
  methods, nil-on-failure contract preserved:
  `func sampleProcesses() -> [RawProcessSample]?` — one full scan returns, per PID:
  `pid`, `cpuTicks` (`ri_user_time + ri_system_time`), `startAbstime`
  (`ri_proc_start_abstime`), `physFootprint` (`ri_phys_footprint`); and
  `func resolveProcessName(pid: Int32) -> String?`. `RawProcessSample` is a new Sendable
  value type in `StatsLite/MetricTypes.swift`. One scan serves both CPU and Memory
  rankings. `LiveSystemMetricsProvider`
  (`StatsLite/LiveSystemMetricsProvider.swift:15`) implements them with
  `proc_listallpids` + `proc_pid_rusage(RUSAGE_INFO_V2)`. Reject `sysctl(KERN_PROC_ALL)`
  (CPU/RSS fields zeroed in XNU) and `proc_pidinfo(PROC_PIDTASKINFO)` (O(thread) walk
  under `task_lock`).
- T2. `MetricSamplerActor` (`StatsLite/MetricSamplerActor.swift:13`) owns per-PID CPU
  delta anchors `[Int32: ProcessTickAnchor]` (Mach ticks + `ri_proc_start_abstime` for
  PID-reuse rejection + per-anchor measurement `instant` for Δt), beside `previousCPUTicks` (`:16`).
- T3. Publish process results OUTSIDE `SystemSnapshot`: add published properties
  `topCPUProcesses: [ProcessMetricItem]`, `topMemoryProcesses: [ProcessMetricItem]`,
  `isSamplingProcesses: Bool`, `activeProcessCategory: ProcessCategory?` on
  `SystemMonitor` (mirroring `latestNetwork`, `StatsLite/SystemMonitor.swift:27`). Never
  put process data on `SystemSnapshot` (`StatsLite/MetricTypes.swift:203`): the menu bar
  item observes `latestSnapshot` (`.onChange`, `StatsLite/MenuBarStackedItemView.swift:30-40`),
  so per-tick process updates would cause menu-bar redraw churn (status-item transitions
  stay discrete — project rule) and the standard loop would erase the list on its next
  `collectSnapshot`.
- T4. `SystemMonitor` (`StatsLite/SystemMonitor.swift:18`): new lazy `processSamplingTask`
  mirroring `startNetworkSampling()`/`stopNetworkSampling()` (`:168`/`:222`). Starting or
  stopping it must NOT restart the standard loop (`standardLoopGeneration` isolation, see
  `StatsLiteTests/SystemMonitorNetworkTests.swift`).
- T5. Lifecycle: start on disclosure expand, stop on collapse-to-nil while the popover
  stays open (collapse must stop the sampler and clear the anchor base — R3). Teardown on
  every close path: `StatusItemController.popoverDidClose` (`:261-269` — fires for
  outside-click and Escape dismissals too, which call `performClose` directly and bypass
  `togglePopover`) and `PopoverContentView.onDisappear`. Stop clears the published lists
  and the sampler delta base (`clearProcessBase`, mirroring `SystemMonitor.swift:229`).
- T6. Attribution rules: skip `pid <= 0`, skip `proc_pid_rusage != 0` (EPERM for other
  users' processes — expected for root/WindowServer/kernel_task), skip zombies
  (`ri_proc_exit_abstime != 0`), CPU fraction = Mach-tick delta × timebase ÷
  (elapsed ns × activeProcessorCount), clamped to 0...1. Memory ranks by
  `ri_phys_footprint` (Activity Monitor "Memory" semantics; matches the card's `Used`
  total), fallback `ri_resident_size`. Memory gauge fraction =
  `phys_footprint / ProcessInfo.processInfo.physicalMemory` (denominator is total
  physical RAM, matching the card's Used-percentage framing).
- T7. Name resolution only for Top-8 candidates via `proc_pidpath` (fallback
  `proc_name`) until 5 names resolve; zero `String` allocation in the full-scan loop;
  no `NSWorkspace`/`NSRunningApplication`.
- T8. No `.animation`/`.contentTransition` in status-item views (project rule). Popover
  views use `withAnimation(.easeInOut(duration: 0.2))` + `.transition(.opacity)`,
  matching `PopoverContentView.swift:77-79`.

## 3. Oracle ISC (2026-10-23, sampling architecture)

Attribution measurements were not required (no live bug); this is architecture. Oracle
verdicts with confidence:
- API choice: `proc_listallpids` + `proc_pid_rusage(RUSAGE_INFO_V2)` — O(1) task-ledger
  read per PID; ~0.3–1.2 ms/tick over 400–700 PIDs (`unverified prior` until measured
  with `scripts/measure_popover_footprint.sh`). Confidence: high.
- Permission model: XNU `proc_security_policy` enforces same-UID on `proc_pid_rusage`;
  unprivileged apps see only own-UID processes. CPU percentages will NOT sum to the card's
  CPU Total (system processes are invisible). This is expected, not a defect.
- Bootstrap: CPU needs two samples; anchor at t=0, one 250 ms warm-up sleep, first
  publish at +250 ms, then `refreshInterval`. Memory publishes at tick 0.
- Memory cost: confirmed ban on per-process `HistoryBuffer`. Hold only the anchor dict
  (~16 B/entry, ~8 KB for 300 PIDs, `unverified prior`); rebuild each tick; wipe on stop.
- Popover memory gate (`plans/2026-10-21-popover-panel-fix.json`): sustained footprint
  ≤ 40 MB while open. `ProgressView()` is banned in the popover — a 60 Hz spinner
  re-locks volatile Metal driver buffers and can trip the gate.
- Blueprint defects found by oracle (all folded into the blueprint amendments in §4):
  1. VAC-4's collapsed "Top Processes · Xcode 84%" cue contradicts lazy sampling →
     collapsed cue keeps only the 4 pt warning/critical dot, no process name.
  2. `ProgressView()` → static loading text (same as "Waiting for first sample",
     `StatsLite/CPUCardView.swift:35`).
  3. Cards apply `.accessibilityElement(children: .ignore)` to the whole card
     (`CPUCardView.swift:59`, `MemoryPressureCardView.swift:56`, `GPUCardView.swift:46`)
     → move it to the header/chart sub-container; outer card uses `.contain` so the
     disclosure and rows are reachable by VoiceOver/keyboard.
  4. Text clipping: GPU unavailable copy drops `.lineLimit(1)` (allow wrap,
     `.fixedSize(horizontal: false, vertical: true)`); value column widens 38 → 44 pt
     (name column 146 → 140 pt) so `12.4 GB` never clips.
  5. Missing `.transition(.opacity)` on expanded sections +
     `.animation(.easeInOut(duration: 0.2), value: expandedProcessCategory)`.
  6. Explicit `stopProcessSampling()` at all teardown points (see T5), not just `@State`
     deallocation — `popoverDidClose` can be delayed by display sleep.

## 4. Design Blueprint (designer, 2026-10-22 — verbatim, with oracle amendments marked [AMD-n])

The designer read `artifacts/2026-10-21-popover-panel-fix/fixed/{dark,light}.png`,
`docs/screenshot.png`, and the card sources. Verified geometry: popover width fixed at
280 pt (`PopoverContentView.swift:74`), card outer margin 10 pt, card inner padding 10 pt
(`DesignTokens.swift:44-59` `MetricCardStyle`), usable content width 240 pt, card spacing
6 pt (`PopoverContentView.swift:28`). Note: the repo has no `DESIGN.md`; tokens live in
`DesignTokens.swift` and inline per-card fonts.

### 4.1 Architectural decisions

Entry point: inline per-card expandable disclosure. Rejected alternatives:
- Auto-expand on threshold → layout thrashing around the 80% boundary, misclicks.
- Secondary detail popover → focus fights with the status item (non-activating app).
- Dedicated bottom card → separates symptom from cause; permanent height cost.
Accordion policy: expanding one card's list collapses the others (popover height budget).
Coverage: CPU (by %) and Memory (by footprint) full; GPU degrades to the unavailable
container (macOS restricts per-process Metal stats to system tools).
Row layout: no per-process sparklines; a 44×5 pt proportional capsule gauge instead
(token grounded in the existing core rows, `CPUCardView.swift:94`). 5 rows × 18 pt = 90 pt.
Trigger: disclosure always visible, collapsed; sampling lazy (R3). Transient lifecycle:
expansion `@State` resets on popover close (`StatusItemController.swift:266`).
Space budget: 280 pt fixed width; 240 pt content split 140 pt name+PID / 88 pt gauge+value
[AMD-4: was 146/88 with a 38 pt value frame]. Total popover height with all cards and one
expanded list stays under 640 pt.

### 4.2 Wireframes (240 pt content width)

CPU card, expanded:

```text
+-------------------------------------------------------------------+
|  [#] CPU Total                                              92.4% |
|  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~/\~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |
|  -1m                                                          Now |
|  > Cores Breakdown (18 Cores)                                     |
|  v Top Processes                                                  |
|  +-------------------------------------------------------------+  |
|  | Xcode (4821)                 [========  ]             84.2% |  |
|  | Docker Desktop (1842)        [==        ]             14.5% |  |
|  | Slack Helper (3410)          [=         ]              6.8% |  |
|  | StatsLite (59201)            [          ]              1.2% |  |
|  | Terminal (1204)              [          ]              0.8% |  |
|  +-------------------------------------------------------------+  |
+-------------------------------------------------------------------+
```

Memory card, expanded:

```text
|  v Top Processes                                                  |
|  | Docker Desktop (1842)        [========= ]            6.8 GB |  |
|  | Xcode (4821)                 [======    ]            4.2 GB |  |
|  | Slack Helper (3410)          [===       ]            2.1 GB |  |
|  | Safari (653)                 [==        ]            1.4 GB |  |
|  | Finder (412)                 [=         ]            780 MB |  |
```

Example rows use user-UID processes only: `proc_pid_rusage` returns EPERM for other
users' processes (root, WindowServer, kernel_task), so they can never appear in a list.

GPU card, expanded (unavailable state):

```text
|  v Top Processes                                                  |
|  +-------------------------------------------------------------+  |
|  | [!] Per-process GPU metrics unavailable                     |  |
|  +-------------------------------------------------------------+  |
```

### 4.3 Component skeleton (shapes, not final code)

- `ProcessMetricItem` (in `StatsLite/MetricTypes.swift`): `pid: Int32`, `name: String`,
  `fraction: Double` (0...1), `valueLabel: String`; `id = pid`.
- `TopProcessesSectionView(processes:tintColor:isLoading:)` — new
  `StatsLite/TopProcessesView.swift`. Rows: HStack(spacing 6), height 18 pt; name
  10 pt regular `.primary`, `.lineLimit(1)`, `.truncationMode(.tail)`; PID 8.5 pt
  monospaced `.tertiaryLabelColor`; gauge 44×5 pt capsule,
  `separatorColor.opacity(0.3)` track + tinted fill (min fill 2 pt); value 9.5 pt
  monospacedDigit `.secondary`, right-aligned in a fixed 44 pt frame [AMD-4].
  Loading placeholder: static text only [AMD-2]:
  `Text("Sampling top processes…")` 9.5 pt `.tertiary`, 22 pt frame.
  Empty placeholder: `Text("No process data available")` 9.5 pt `.tertiary` (R2b).
- `TopProcessesDisclosureButton(isExpanded:usageState:)` where `usageState` is
  `enum ProcessCueState { case normal, warning, critical }` — a boolean cannot encode
  the three dot colors. Mirrors the CPU card disclosure (`CPUCardView.swift:66-83`):
  9 pt semibold chevron, 10 pt medium
  `Top Processes` label, `.secondary`, `.buttonStyle(.plain)`, full-width
  `.contentShape(Rectangle())`, toggle inside
  `withAnimation(.easeInOut(duration: 0.2))`. Collapsed high-use cue: 4 pt
  `.systemOrange`/`.systemRed` dot only — no process name [AMD-1].
- `GPUUnavailableProcessesView` — dashed 4 pt rounded rect, 0.6 pt stroke,
  `separatorColor.opacity(0.6)`, dash `[4,4]`, `exclamationmark.triangle` 10 pt, copy
  `Per-process GPU metrics unavailable` (allowed to wrap) [AMD-4].

### 4.4 State / responsive / dark-light matrices

State matrix (heights include the 16 pt disclosure header):

| State | Header | Content | Gauge tint | Height |
|---|---|---|---|---|
| Collapsed (normal) | `> Top Processes` | none | — | 16 pt |
| Collapsed (warning/critical) | `> Top Processes` + 4 pt amber/red dot | none | — | 16 pt |
| Expanded (normal) | `v Top Processes` | 5 rows | card tint | 110 pt |
| Expanded (warning) | `v Top Processes` | 5 rows | `.systemOrange` | 110 pt |
| Expanded (critical) | `v Top Processes` | 5 rows | `.systemRed` | 110 pt |
| Loading (CPU bootstrap) | `v Top Processes` | static text [AMD-2] | — | 38 pt |
| Empty / no data | `v Top Processes` | `No process data available` | — | 34 pt |
| GPU unavailable | `v Top Processes` | dashed container | — | 68 pt |
| Hover | subtle highlight | — | — | 16 pt |
| Keyboard focus | system focus ring | — | — | 16 pt |

Responsive invariants (popover is fixed-width; no responsive breakpoints exist):

| Viewport | Popover width | Content width | Name col | Gauge+value | Wrap |
|---|---|---|---|---|---|
| 375 pt | 280 pt | 240 pt | 140 pt | 88 pt | none; tail truncation only |
| 768 pt | 280 pt | 240 pt | 140 pt | 88 pt | none |
| 1440 pt | 280 pt | 240 pt | 140 pt | 88 pt | none |

Dark/light matrix: all colors are dynamic AppKit/SwiftUI semantic tokens
(`.primary`, `.secondary`, `.tertiaryLabelColor`, `separatorColor`, `systemOrange`,
`systemRed`) resolved per appearance; contrast targets WCAG 2.2 AA (≥ 4.5:1 text,
≥ 3:1 non-text). Verify in both appearances via screenshot evidence — do not assert
contrast from code.

### 4.5 Accessibility & interaction contracts

- Disclosure: role button/disclosure; label `Top processes for CPU Total` (or Memory);
  value `Expanded`/Collapsed; hint `Double-click to expand or collapse the top five
  active processes.`
- Rows: `.accessibilityElement(children: .ignore)` per row with label
  `"\(name), Process ID \(pid), \(valueLabel)"` (e.g. `Xcode, Process ID 4821, 84.2%`).
- Gauge: `.accessibilityHidden(true)` (value text is authoritative).
- Cards: fix the `.children: .ignore` blackout — sub-container keeps it, outer card uses
  `.children: .contain` [AMD-3].
- Keyboard: Tab reaches the disclosure; Space/Return toggles; Escape closes the popover.
- Animation: `withAnimation(.easeInOut(duration: 0.2))` + `.transition(.opacity)` on
  expanded sections + `.animation(.easeInOut(duration: 0.2), value: expandedProcessCategory)`
  [AMD-5]. Never on the status item.

### 4.6 Integration appendix (scout-verified, corrected)

- CPU disclosure slots after the `showCoreBreakdown` gate (`CPUCardView.swift:50-52`) or
  after `coreGrid` (`:54-56`); new `@Binding` beside `coresExpanded` (`:15`).
- Memory: no existing disclosure; row goes at the end of `body`
  (`MemoryPressureCardView.swift:~62`); new binding required.
- GPU: no existing disclosure; row at end of `body` (`GPUCardView.swift:~52` available
  branch); new binding required.
- `PopoverContentView`: declare `@State expandedProcessCategory: ProcessCategory?` beside
  `coresExpanded` (`:21`); pass bindings at card sites (`:45-49`, `:53`, `:57`); add
  animation line at `:77-79`.
- `SystemMonitor.apply(_:)` (`:94`) is the per-appear hook precedent; network loop
  start/stop (`:168`/`:222`, delta-base clear at `:229`) is the lifecycle model.
- Tests: extend `StatsLiteTests/FakeSystemMetricsProvider.swift:12` with settable process
  fixtures + counters; harness pattern `SystemMonitorNetworkTests.swift:40-47`; live
  contract test pattern `SystemMetricsProviderContractTests.swift`.
- Evidence: `scripts/capture_baseline.sh` (dark/light), `scripts/measure_popover_footprint.sh`
  (footprint; wrap in `caffeinate` — no display-sleep guard, known parked issue).

## 5. Quality Gates

G1. TDD red → green. UI task with a logic core:
- RED first (commit or artifact) for: `MetricSamplerActor` process-delta logic (PID reuse
  rejection, zombie skip, counter rollback), `SystemMonitor` start/stop lifecycle (loop
  isolation: `standardLoopGeneration` unchanged), disclosure accordion state, and the
  GPU-unavailable branch. Red evidence = failing test output.
- Visual red evidence = pre-edit baseline screenshots from `scripts/capture_baseline.sh`
  (dark + light), captured before the first code edit.
- Functional (non-screenshot) red evidence — automated XCTests under G1/G5:
  - FT-1 Accordion: expanding card B's list collapses card A's.
  - FT-2 Lifecycle: collapse-while-open stops the sampler and clears the anchor base;
    every close path (popoverDidClose — including outside-click and Escape — and
    onDisappear) stops it; fake-provider read counters assert zero process reads while
    collapsed or closed.
  - FT-3 Accessibility: with the card on `.children: .contain`, the disclosure button and
    process rows are present in the accessibility tree with the specified labels.
  - FT-4 Loading state (VAC-13): verified against a mock provider fixture that holds the
    first CPU sample, not by racing live 250 ms timing.
G2. Reviewer GO (per subagent `reviewer`, branch `feature/2026-10-23-top-processes-breakdown`).
G3. Screenshot diff: post-edit dark + light screenshots vs baseline; every
   screenshot-checkable VAC (1–9, 12, 13) checked; zero tolerance for
   wrapping/clipping/misalignment. VAC-10/11 are not screenshot-verifiable — they live
   as FT-1/FT-2 under G1/G5.
G4. Memory gate: `scripts/measure_popover_footprint.sh` under `caffeinate`;
   settled open footprint ≤ 40 MB sustained, ≤ 2.3 MB graphics dirty; 40 s tail ≤ 40 MB.
   Compare against `artifacts/2026-10-21-popover-panel-fix.json` baselines.
G5. `xcodebuild test` green (StatsLiteTests), including existing popover determinism tests
   (`testTogglePopoverCyclesMountAndRelease` keeps `popover.animates = false`).
G6. Plan file marked `status: done` only after squash/ff merge to `main`; merge commit
   SHA recorded in the plan.
G7. Screenshot diff is a manual A/B (no diff tool exists — `scripts/` holds only
   `capture_baseline.sh`, `measure_popover_footprint.sh`, `windowid.swift`). Compare
   baseline vs post-edit images side by side, light and dark, and tick every VAC.

## 6. Numbered VAC (11 screenshot-verifiable items; VAC-10/11 → FT-1/FT-2)

- VAC-1 Popover width stays exactly 280.0 pt in all viewports; the section never widens it.
- VAC-2 Card inner content width measures exactly 240.0 pt.
- VAC-3 Disclosure: 9 pt semibold chevron (`chevron.right` collapsed / `chevron.down`
  expanded) + 10 pt medium `Top Processes`; icon flip causes zero vertical displacement.
- VAC-4 High-use cue: when the parent metric is warning/critical and the section is
  collapsed, a 4.0 pt amber/red dot shows trailing the label. [AMD-1: no process name or
  value while collapsed — lazy sampling contract.]
- VAC-5 Every process row renders on a single 18.0 pt line; overlong names end with a
  tail ellipsis; text never wraps.
- VAC-6 Values render at 9.5 pt monospacedDigit, right-aligned in a fixed 44.0 pt frame;
   decimal/percent edges align across all 5 rows; `12.4 GB` and `920 MB` never clip. [AMD-4]
- VAC-7 Gauge measures exactly 44.0 × 5.0 pt, continuous capsule geometry.
- VAC-8 At most 5 rows; fewer active processes render fewer rows, no blank slots.
- VAC-9 GPU unavailable: 4 pt rounded rect, 0.6 pt `[4,4]` dashed `separatorColor` border,
  `exclamationmark.triangle`, copy `Per-process GPU metrics unavailable`; no crash, no
  empty space, wrap allowed, no clipping. [AMD-4]
(Functional, not screenshot-verifiable — automated tests under G1/G5:
- FT-1 Accordion: expanding one card's list collapses any other open list.
- FT-2 Lifecycle: collapse-while-open and every close path stop the sampler, clear the
  published lists and the per-PID anchor base; fake-provider counters assert zero process
  reads while collapsed or closed. [AMD-6: explicit stop calls at popoverDidClose /
  onDisappear / onChange.])
- VAC-12 Dark and light mode: all process text/gauges use dynamic semantic tokens;
  screenshot evidence in both appearances; no hard-coded colors.
- VAC-13 (added) Loading state shows static `Sampling top processes…` text — no spinner,
  no animation — for the CPU first-sample window. [AMD-2]

## 7. Execution Plan

Worktree: `worktrees/2026-10-23-top-processes-breakdown` on branch
`feat/2026-10-23-top-processes-breakdown`. Tasks run sequentially (one
subagent active at a time), TDD red→green inside each task.

- T-A: RED tests — `ProcessMetricItem`, `ProcessTickAnchor`, sampler delta logic
  (fake provider fixtures: PID reuse, zombie, EPERM, counter rollback), monitor
  start/stop loop isolation, accordion state, GPU-unavailable branch. Capture baseline
  dark/light screenshots (G1).
- T-B: sampler core — `SystemMetricsProvider` methods, `LiveSystemMetricsProvider`
  libproc implementation (T1/T6/T7), `MetricSamplerActor` deltas (T2), snapshot member
  (T3). Make T-A unit tests green.
- T-C: monitor lifecycle — lazy `processSamplingTask`, 250 ms CPU warm-up, memory tick 0,
  stop/clear at teardown points (T4/T5). Make lifecycle tests green.
- T-D: UI — `TopProcessesView.swift` + disclosure buttons in all three cards,
  accordion state in `PopoverContentView`, GPU unavailable view, accessibility fixes
  [AMD-3], animation wiring [AMD-5]. Green VAC-1..VAC-9, VAC-12, VAC-13.
- T-E: verification — full test run, footprint measurement under `caffeinate`, post-edit
  dark/light screenshots, VAC evidence table. Then reviewer GO, then squash/ff merge to
  `main`, SHA recorded here.

Dependencies: A → B → C → D → E. A alone touches tests only; B/C touch model layer; D
touches views; E is read-only + merge.

## 8. Verification Checklist

- [ ] RED commit/artifact exists before any non-test code (G1).
- [ ] Baseline screenshots captured before first edit (G1).
- [ ] FT-1 accordion + FT-2 lifecycle/zero-sampling + FT-3 a11y + FT-4 loading tests
      green (G1/G5).
- [ ] `xcodebuild test` green (G5).
- [ ] Footprint ≤ 40 MB open / ≤ 40 MB tail under `caffeinate` (G4).
- [ ] Dark + light post-edit screenshots vs baseline; VAC-1..9, 12, 13 evidence table (G3).
- [ ] Collapsed/closed = zero sampling: fake-provider counters prove 0 calls (FT-2).
- [ ] Reviewer GO (G2).
- [ ] Merged to `main` ff/squash; SHA recorded; plan `status: done` (G6).

## 9. Follow-ups (parked, do not block)

- `DESIGN.md` and `ARCHITECTURE.md` are referenced by the root `AGENTS.md` but absent
  from the repo; create them as a separate docs task.
- `scripts/measure_popover_footprint.sh` display-sleep guard (`caffeinate` wrap or
  `CGDisplayIsAsleep` check) — existing parked issue in project `AGENTS.md`.
- Optional `showTopProcesses` preference in `PreferencesStore` (beside `showCoreBreakdown`,
  `StatsLite/PreferencesStore.swift:80`) if users report the row as noise.
- Metric card disabled in Settings while its process list is expanded: reset expansion
  and stop the sampler (cover with a test in T-C if cheap).
- If macOS ever exposes per-process GPU stats to unprivileged apps, replace the
  unavailable container with real data.
