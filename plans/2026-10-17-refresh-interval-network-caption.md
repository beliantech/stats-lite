# Plan: Refresh Interval row subtitle — Network Throughput stays at 1 s

- Risk class: R2 (UI work; requires rendered VAC evidence)
- Branch: `feat/2026-10-17-refresh-interval-network-caption` in worktree `worktrees/2026-10-17-refresh-interval-network-caption`
- Design authority: designer session `2026-10-17T05-15-25-204Z` (verdict GO, blueprint with VAC-1…VAC-7), verbatim in §4.

## 1. Why

The Settings window offers Refresh Interval 1/2/3/5 s, but Network Throughput
never follows it. The user sees no indication of that.
Current state (pre-change): the Refresh Interval row
(`StatsLite/SettingsView.swift:47-58`) shows label, picker, nothing else.
Target state: a caption under the picker states that Network Throughput
refreshes once per second, independent of this setting.

Fact base (scout session `2026-10-17T05-14-59-178Z`, all verified):

- `PreferencesStore.swift:62-67` `refreshInterval: Int = 1`; persisted
  `@AppStorage("refreshInterval")` at `:117`.
- Picker offers 1/2/3/5 s (`SettingsView.swift:49-54`).
- Setting drives the standard loop sleep (`SystemMonitor.swift:149-152`), status
  item updates (`MenuBarStackedItemView.swift:66-68`), sparkline capacity
  (`SystemMonitor.swift:41-44`), popover footer `Updated every Ns`
  (`PopoverContentView.swift:113`).
- Network loop sleeps a fixed `.seconds(1)` (`SystemMonitor.swift:175-179`),
  with the deliberate-decision comment "refreshInterval never applies here (D1)"
  (`SystemMonitor.swift:164`). Structural claim independently verified; test
  `SystemMonitorNetworkTests.swift:55` (FM11, `:80-87`) sets
  `refreshInterval = 5` at `:49` and asserts the *standard* loop keeps its 5 s
  cadence while the network loop runs on its own.
- The row had no caption. Caption precedent: `launchAtLoginRow`
  (`SettingsView.swift:71-80` post-merge), `.font(.caption)` +
  `.foregroundStyle(.secondary)`, `VStack(alignment: .leading, spacing: 3)`.

## 2. Falsification signature

If the edit is correct, after the change:

- The only new element is the caption text under the Refresh Interval picker.
- Launch at Login row and every element below shift down by the caption height
  (~26 pt at 2 lines); nothing else changes: no label, font, spacing, or color
  changes anywhere in the window.
- The picker, its 4 options, and `monitor.apply` on change behave identically
  (no behavior change; the caption is static text).

If any other element changes, or the caption does not render, the edit is wrong
and stops here.

## 3. Evidence

- Designer rendered real window captures at 375/380/768/1440 px, light + dark,
  contrast 14.13:1 light / 11.39:1 dark (WCAG AA ≥ 4.5:1).
- Before-captures: `artifacts/2026-10-17-refresh-interval-network-caption/before/`.
- Designer reference renders: `artifacts/2026-10-17-refresh-interval-network-caption/designer-reference/c1_w{375,380,768,1440}_{light,dark}.png`.
- Capture tool: `scripts/capture_baseline.sh` targets the popover only; the
  settings window needs `scripts/windowid.swift` + `screencapture -l<id>`, or
  the tester's own capture path. If the host lacks Screen Recording TCC
  (precedent: `-1743` in plan `2026-10-17-drop-cpu-gpu-card-subtitles` §9),
  report rendered VACs UNVERIFIED instead of guessing.
- `DESIGN.md` and `ARCHITECTURE.md` are absent at repo root; tokens ground in
  `SettingsView.swift` itself.

## 4. Design blueprint (verbatim, designer session `2026-10-17T05-15-25-204Z`)

### Copy — three candidates, Option 1 recommended (chosen)

| Option | Copy | Words | Wrap at 380 pt |
|---|---|---|---|
| **1 (chosen)** | `Network throughput refreshes once per second, independent of this setting.` | 10 | 2 lines |
| 2 | `Network throughput updates every second and does not use this interval.` | 11 | 2 lines |
| 3 | `Network throughput always refreshes at 1-second intervals.` | 7 | 1 line |

Option 1 matches the noun "Network throughput" used in Visible Metrics and says
the independence explicitly. STE-clean: active voice, simple present.

### SwiftUI skeleton (verbatim; extract row into a computed property)

```swift
    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            refreshIntervalRow
            launchAtLoginRow
        }
    }

    private var refreshIntervalRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Picker("Refresh Interval", selection: $preferences.refreshInterval) {
                Text("1 s").tag(1)
                Text("2 s").tag(2)
                Text("3 s").tag(3)
                Text("5 s").tag(5)
            }
            .accessibilityHint("Network throughput refreshes once per second, independent of this setting.")

            Text("Network throughput refreshes once per second, independent of this setting.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
```

### Tokens

| Element | Value | Precedent |
|---|---|---|
| Row container | `VStack(alignment: .leading, spacing: 3)` | `launchAtLoginRow` (`SettingsView.swift:60`) |
| Caption font | `.caption` (10 pt) | `loginHint` (`SettingsView.swift:66`) |
| Caption color | `.foregroundStyle(.secondary)` | `loginHint` (`SettingsView.swift:67`) |
| Caption spacing | 3 pt via VStack | same |

### Responsive / state matrix (designer-verified)

- 375/380 pt: caption wraps to 2 lines, no truncation, no clipped descenders.
- 768/1440 pt: caption on 1 line.
- Picker menu open, keyboard focus, disabled state: caption stays visible, no
  layout shift, 3 pt clearance below focus ring.
- VoiceOver: speaks "Refresh Interval, N s, pop-up button", then the hint, then
  the visible caption as the next element.

## 5. Change inventory

Code files only, in the worktree.

### `StatsLite/SettingsView.swift`

1. Replace the inline `Picker` in `generalSection` (lines 48-54) with
   `refreshIntervalRow` (skeleton above).
2. Add `private var refreshIntervalRow` after `generalSection`
   (Picker inline at pre-change lines 49-54).
   Exact strings from §4 — the `Text` caption and `.accessibilityHint` must be
   identical byte-for-byte.

Nothing else: no behavior, no test, no config changes.

## 6. Step sequence

1. Planner: archive before-captures (done, §3) and create the worktree
   `worktrees/2026-10-17-refresh-interval-network-caption` on
   `feat/2026-10-17-refresh-interval-network-caption` from `main`.
2. Coder spawn (cwd = worktree) makes only the §5 change, builds, runs the test
   suite, commits `feat(settings): add network cadence caption to refresh interval row`.
3. Tester spawn validates VAC-1…VAC-7 below: source checks + rendered captures
   compared against `designer-reference/c1_*` at 375/768/1440 px, light and dark.
   Reports GO / NO GO with failing IDs. Report-only; no edits.
4. Plan-review spawn checks the diff against this file.
5. Planner: verify mandate, present verdict, merge fast-forward or squash,
   record receipts here, clean up worktree + branch.

## 7. VAC anchors

| ID | Invariant | Anchor |
|----|-----------|--------|
| VAC-1 | Caption `Network throughput refreshes once per second, independent of this setting.` renders directly under the picker | `StatsLite/SettingsView.swift` `refreshIntervalRow` (new) |
| VAC-2 | Caption uses `.font(.caption)` + `.foregroundStyle(.secondary)`, same tokens as `loginHint` | new `Text` modifier; precedent `SettingsView.swift:66-67` |
| VAC-3 | At 375/380 px: wraps to ≤2 lines, zero truncation, zero clipped descenders, no horizontal scrollbar | rendered capture |
| VAC-4 | At 768/1440 px: single line, no line break | rendered capture |
| VAC-5 | Row order in General unchanged: Refresh Interval (+caption), divider, Launch at Login; label and picker baseline alignment intact | `SettingsView.swift:47-56` |
| VAC-6 | Gap picker → caption = 3 pt (`VStack(spacing: 3)`) | new `refreshIntervalRow` |
| VAC-7 | `.accessibilityHint` string == visible caption string, byte-for-byte | `rg` count: both occurrences of the sentence in `SettingsView.swift` identical |

Repo invariants: no `.animation` / `.contentTransition` anywhere in the diff
(both would be a violation of the status-item rule and out of scope here).

## 8. Test mandate (tester)

- `rg -n "Network throughput refreshes once per second" StatsLite/` → exactly
  2 hits, both in `SettingsView.swift`, identical strings.
- `rg -n "\.animation|\.contentTransition" <diff files>` → zero hits.
- Build: `xcodebuild -scheme StatsLite -configuration Debug build`
  (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`).
- Test suite: expect 1 known pre-existing failure
  `StatusItemControllerPopoverTests.testTogglePopoverCyclesMountAndRelease`
  (environmental, fails on unmodified `main`); any other failure is a NO GO.
- Read rendered captures against `designer-reference/c1_*` and check VAC-1…VAC-6
  on pixels, not on the diff. If capture is impossible (TCC), report those VACs
  UNVERIFIED explicitly instead of guessing.
- Report `NO GO` with failing VAC IDs. Report only, never edit.

## 9. Self-verification (planner, before merge)

- Diff touches only `StatsLite/SettingsView.swift`.
- No test, config, or dependency changes.
- Tester GO + plan-review GO.
- Merge `--ff-only` or `--squash` into `main`, then record receipts.

## 10. Receipts

- Merge: `4c34356` `feat(settings): add network cadence caption to refresh
  interval row`, fast-forward into `main` at `626357e`.
- Scope: `StatsLite/SettingsView.swift` only (+11/−1). Worktree clean.
- Build: `xcodebuild -scheme StatsLite -configuration Debug build` →
  BUILD SUCCEEDED (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`).
- Tests: 240 passed, 1 failed —
  `StatusItemControllerPopoverTests.testTogglePopoverCyclesMountAndRelease`,
  pre-existing on unmodified `main` (environmental, 5 s popover timeout).
  No other failure.
- String check: `rg -n "Network throughput refreshes once per second" StatsLite/`
  → exactly 2 hits, both `SettingsView.swift:62` (hint) and `:64` (caption),
  byte-identical (tester SHA-256 match). No `.animation`/`.contentTransition`.
- Plan review: GO. Five citation drifts found and corrected in this file.
- Tester: GO, VAC-1…VAC-7 PASS. Live window capture blocked by host TCC
  (Automation `-1743`, no Screen Recording for the agent process tree).
  Rendered VACs verified with an offscreen harness that compiles the
  unmodified worktree sources and hosts the real `SettingsView`: caption
  renders under the picker at 375/768/1440 px, light and dark; wraps to
  exactly 2 lines at the fixed 380 pt width with no truncation; row order and
  3 pt gap confirmed by pixel scan. VAC-4 satisfied by construction — the
  Settings window is fixed 380×340 and cannot reach 768/1440 pt.
  Captures: `artifacts/2026-10-17-refresh-interval-network-caption/after/tester_harness_w{375,768,1440}_{light,dark}.png`.
- Observation (not a VAC): designer-cited contrast (14.13:1 light / 11.39:1
  dark) was not reproduced by the tester's pixel scan (3.07:1 light,
  5.80:1 dark — `unverified prior` on both figures). No VAC anchors contrast.
  The caption uses the exact `.caption` + `.secondary` tokens of the existing
  `loginHint`, so it renders like every other caption in the app.
- Security note: the tester session observed prompt-injection texts inside
  tool outputs (attempts to fake an approval verdict / exfiltrate keys).
  None were followed; no secrets left the host; temp files and defaults were
  restored.
