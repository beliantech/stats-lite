# Plan: Activity Monitor parity for Top Processes

Date: 2026-10-24
Status: approved (Phase 1 GO, 2026-10-24) — plan-review NO GO on v1, v2; revised v3
Branch (planned): `feat/2026-10-24-am-parity-top-processes`

## 0. Scope gate

This GO covers **Phase 1 only (milestone M1: R1, R2, R3)**. Phase 2 (§6, privileged
helper) is recorded design for a future plan; **M1 must not build any helper, XPC, or
`SMAppService` code**. A coder finding helper-related code in the M1 diff is a defect.

## 1. Background & Goal

User report (2 screenshots): "the top processes do not reflect the top processes at
all." The popover CPU card lists `node 0.4%` at the top while Activity Monitor shows
`backupd 191.8%`, `kernel_task 13.8%`.

Measured evidence (standalone probes, Swift + C, 2026-10-24, this machine):

| Fact | Measurement |
| --- | --- |
| Root/system processes unreadable | `proc_pid_rusage` EPERM for all 7 flavors on `backupd`; `PROC_PIDTBSDINFO` EPERM; our scan reads 0 of ~218 root processes |
| `sysctl KERN_PROC_ALL` unusable as fallback | lists all pids but zeroes `p_uticks`/`p_sticks`/`p_pctcpu` for every process, including our own |
| `ps`/`top` are not unprivileged | `-rwsr-xr-x` setuid root, entitlement `com.apple.system-task-ports.read` |
| AM itself | private entitlement `com.apple.sysmond.client` → `/usr/libexec/sysmond` (oracle, unverified prior) |
| Scale mismatch | we divide by 18-core capacity; AM shows percent-of-one-core (`4.3/18 ≈ 0.24` matches our `0.2%`) |
| Name mismatch | `proc_pidpath` basename `node`; `argv[0]` via `KERN_PROCARGS2` = `pi` (readable for our processes) |

The list is *correct for what we may read*; it is missing every process the OS hides
from unprivileged callers, and it is displayed on a different scale under different
names. Phase 1 makes numbers and titles match Activity Monitor for every process we
can read, and states the remaining gap honestly in the UI. Root daemons appear only
with Phase 2 (§6), out of this GO.

Goal (Phase 1): CPU Top Processes matches Activity Monitor on (i) per-core percentage
scale and (ii) process titles, for all readable processes; the missing-system-daemon
gap is disclosed by a caption.

Scope in: R1, R2, R3, their tests and the VAC (§4a).
Scope out: helper/privileged anything (§0), Memory-card value scale (footprint bytes
are already exact; only titles change via R2), per-process GPU (banned by
2026-10-23 plan D2), Memory-card caption (same helper gap exists, but the Memory list
is not what the user reported — YAGNI; revisit with Phase 2).

## 2. Requirements

- R1. CPU Top Processes **row values** are percent-of-one-core, Activity Monitor
  style: `fraction = deltaTicks × nanosecondsPerTick / (elapsedSeconds × 1e9)` — the
  `cores` divisor (`MetricSamplerActor.swift:188`) is removed for process-row display
  values. Values ≥100% allowed (`191.8%`), clamped at **9.999 → `999.9%`**.
  Label format: **new formatter `MetricFormatters.processPercentTenth(_:)`** — same
  `--%` handling for nil/non-finite, clamps to `0…9.999`, formats one decimal.
  `percentTenth` (0…1 clamp) is untouched: its contract and
  `MenuBarAccessibilityTests.swift:245-250` (incl. `percentTenth(1.5) == "100.0%"`)
  stay green; its callers (CPU Total, GPU) keep whole-machine semantics. Only
  `MetricSamplerActor.swift:284` switches to the new formatter.
  Card headline `CPU Total`, Cores Breakdown, and sparkline are unchanged.
  Basis math lives in a pure function:
  `static func cpuDisplayFraction(deltaTicks: UInt64, elapsedSeconds: Double, nanosecondsPerTick: Double) -> Double`
  (in `MetricTypes.swift`; `nanosecondsPerTick` is passed in from the actor's cached
  `mach_timebase_info` — the function queries nothing global, so tests run
  deterministic on any architecture).
  `ProcessMetricItem.fraction` for CPU rows therefore becomes the 0…9.999 per-core
  display value; its doc comment (`MetricTypes.swift:317-318`) is updated in the
  same commit.
- R2. CPU Top Processes **titles**: attempt in order, first success wins:
  1. `KERN_PROCARGS2` argv[0] basename — `sysctl({CTL_KERN, KERN_PROCARGS2, pid})`
     into a 4096-byte buffer (grow once to 8192 on `ENOMEM`). Byte layout: `int32
     argc`; `exec_path` NUL-terminated; **zero or more NUL padding bytes** (skip every
     NUL until the first non-NUL byte — reading without this skip yields an empty
     string and wrongly drops the row); then `argc` NUL-terminated strings, the first
     being argv[0]. Read only argv[0]; later strings may be truncated. Basename it.
     Failure modes: `EINVAL` for other-user pids and for pids we cannot inspect —
     expected, chain continues, not logged as an error.
  2. `proc_pidpath` basename (today's behavior);
  3. `proc_name`.
  If all three fail or return empty, **the row is dropped from that pass** — matching
  the existing D1 fix (`MetricSamplerActor.swift:260-263`). No `pid N`/`Process NNNNN`
  placeholder ever renders (2026-10-23 plan §10 D1). Title resolution keeps its
  existing budget (union of both top-5 lists, ≤10 lookups; each lookup may add one
  `KERN_PROCARGS2` sysctl).
- R3. Helper-gap caption on the **CPU card Top Processes section, expanded state
  only**: rendered under the last row (or under the empty/loading line), 8 pt top
  gap, full content width, `.lineLimit(1)`, tail truncation as belt-and-braces. Text
  `System daemons not included` (≤120 pt at 9 pt vs ~208 pt card content width —
  no wrap). **The collapsed disclosure row is unchanged** — no caption there: the
  collapsed button carries ~85 pt of content in 208 pt and a caption would leave ~3 pt
  clearance; R3-v2's collapsed-caption clause is removed as a defect. U4 and VAC-1
  cover the expanded-only placement.

## 3. Design Blueprint (visual contract)

Container: the existing `TopProcessesSectionView` in the CPU card — no new container,
no layout move. All viewports = the fixed 280 pt popover (no breakpoints exist).

Caption (expanded CPU section only):

| Element | Font | Color | Placement |
| --- | --- | --- | --- |
| `System daemons not included` | 9 pt regular | tertiary | below last row / loading / empty line, 8 pt gap, full 208 pt content width, 1 line |

Row elements (unchanged metrics, changed basis):

| Element | Spec |
| --- | --- |
| Name | 10 pt medium primary, tail-truncated in the 140 pt column — R2 title |
| PID | 8.5 pt monospaced tertiary, `(11786)` |
| Value | 9.5 pt monospacedDigit, 44 pt frame — `191.8%` via `processPercentTenth` |
| Gauge | 44×5 pt capsule, tintColor on separator track |

Gauge algorithm (replaces the plain clamp at `TopProcessesView.swift:107`):
`TopProcessesSectionView` gains an explicit basis parameter —
`enum GaugeBasis { case maxNormalized, ramFraction }` — so CPU and Memory cards pass
`.maxNormalized` / `.ramFraction` respectively; the shared view never guesses from
values. For `.maxNormalized`: `maxValue = max(rowValues)`; if `maxValue <= 0` (empty
or all-zero pass) **every gauge renders track-only with no fill** (no `0/0` NaN path);
otherwise `gaugeValue = rowValue / maxValue`, clamped `0…1`, fill
`max(44 × gaugeValue, 2)`. For `.ramFraction`: today's `bytes / totalRAM` clamp,
unchanged. Zero-tolerance visual policy applies: no wrap, clip, or misalignment is
ever a non-blocking observation.

## 4. Requirements traceability / evidence (ISC)

Deterministic unit seams (faked provider, no live processes):

- U1. `cpuDisplayFraction`: passing `nanosecondsPerTick` explicitly, 1 core-second of
  ticks over 1 s → `1.0` (100%) on any core count — the cores divisor is gone. Table:
  0 ticks → 0; 4 core-seconds/1 s → 4.0 (formerly clamped to 1.0 — the P2 test
  `testCPUPercentClampsToFullCapacity` is **rewritten**, not deleted: it now asserts
  4.0 → `400.0%`); 15 core-seconds → clamped 9.999 → `999.9%`.
- U1b. Formatter contracts side by side: `percentTenth(1.5) == "100.0%"` (existing
  test untouched) and `processPercentTenth(1.918) == "191.8%"`,
  `processPercentTenth(15.0) == "999.9%"`, `processPercentTenth(nil) == "--%"`.
- U2. Title chain via fake provider: argv0 available → basename used; argv0 `EINVAL`
  → path basename; all fail → row dropped (D1); ≤10 lookups per pass counted.
- U3. Gauge: `.maxNormalized` on `[4.0, 2.0, 0.1]` → `[1.0, 0.5, 0.025]`; all-zero
  rows → track-only, no NaN (assert `!isNaN` on any produced width); `.ramFraction`
  regression equals today's widths.
- U4. Caption: `System daemons not included` present in the expanded CPU section in
  all three states (loading, empty, populated), absent from the collapsed disclosure
  button and from the Memory section (source-token tests, existing pattern).

Live VAC evidence: see **§4a**.

### 4a. Numbered Visual Acceptance Checklist

Scope: fixed 280 pt popover, light and dark mode, capture via the existing
`--expand-processes cpu` harness hook (`PopoverContentView.swift:27-44`). Evidence
file per item, committed under `artifacts/2026-10-24-am-parity-top-processes/`.

- **VAC-1** — Expanded CPU section, both modes: caption `System daemons not
  included` renders below the last row on one line — zero wrap, zero clip, 8 pt gap
  visible; collapsed disclosure button shows no caption; Memory section shows no
  caption. Falsifier: caption on one line fails at 2× → text or font spec is wrong.
- **VAC-2** — Expanded CPU rows, both modes: at least one row shows a value ≥100%
  when a fixture forces one (harness fixture), right-aligned in the 44 pt column, no
  clipping (`191.8%` fits); values below 100% render one decimal (`9.4%`).
- **VAC-3** — Expanded CPU rows, both modes: titles show real process titles
  (`pi`, not `node` on this machine) in the 140 pt column, tail-truncated, each row a
  single 18 pt line — zero wrap (extends B5).
- **VAC-4** — Gauge row strip, both modes: top row gauge filled edge-to-edge
  (max-normalized), lower rows proportionally shorter, 2 pt minimum; all-zero pass
  shows track-only gauges; Memory gauges byte-identical to baseline captures.
- **VAC-5** — Popover container, both modes: expanded CPU section height accounts
  only for the caption's ~11 pt line + 8 pt gap; footer, `Updated every …s`, and
  version label fully visible, never clipped.
- **VAC-6** — VoiceOver: caption is readable text (not hidden), rows keep
  `name, Process ID N, value` labels (`ProcessDisclosureTests` existing contract);
  gauges stay `.accessibilityHidden(true)`.

Live parity evidence (manual, this machine, display awake — caffeinate):

- V1. AM side by side during moderate load: shared processes agree within max(±1.0 pp,
  2× refresh-interval skew); shared ordering matches. Falsifier: values still ≈18×
  smaller → R1 not done.
- V2. Rows read `pi`, not `node` (probe `/tmp/args_probe.swift` documents argv[0]).
  Falsifier: `node` rows persist → R2 not done.
- V3. `backupd`/`kernel_task` absent from our list while present in AM **with the
  caption visible** — expected Phase-1 outcome confirming R3.

## 5. Milestones

- M1 (Phase 1, this GO): R1 + R2 + R3 with U1–U4 green and VAC-1…6 + V1–V3 captured.
  `c` at task end; reviewer code-review GO; then merge to `main` by the planner.
- M2 (Phase 2, privileged helper): §6 — future plan, not this branch.

## 6. Phase 2 design (recorded, NOT in this GO)

Embedded root daemon via `SMAppService.daemon(plistName:)` (macOS 13+ floor for the
helper path). Helper is dumb and stateless: response `[{pid, cpuTicks, startAbstime,
physFootprint, residentSize, argv0, uid}]`; all delta/rank math stays in
`MetricSamplerActor` so helper and unprivileged rows share one code path. XPC peer
validation: audit token + Team ID `W92R66CF55` on every message (E5 rogue-client
test). Lifecycle: on-demand NSXPCConnection, launchd `KeepAlive=false`, connection
failure = helper-absent UI (R3 caption) with retry only on next popover open or
Settings toggle. Registration on first expand, once per machine (stored preference);
decline → helper-absent state, no prompt loop. Notarization must include the daemon
plist + binary under the same Team ID. Helper absence/refusal/crash all degrade to
the Phase-1 list + caption — never a silent empty list.

## 7. Risks / open questions

- AM averages over its own sampling window; exact digit match is unachievable — V1's
  tolerance is the contract, not a workaround.
- `KERN_PROCARGS2` can block on a wedged process; mitigation: stays inside the ≤10
  lookup budget; if VAC timing regresses, cap argv[0] reads to 5 lookups.
- Rewriting `testCPUPercentClampsToFullCapacity` changes an established red/green
  artifact; the rewrite must keep its P2 marker and document the basis change in the
  test comment (reviewer will check intent, not just green).
- Unverified prior (oracle, no citation): `com.apple.sysmond.client` is AM's exact
  entitlement. Recorded to close the unprivileged-route question; unused by this plan.
