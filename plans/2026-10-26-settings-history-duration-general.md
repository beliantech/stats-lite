# Plan: 2026-10-26-settings-history-duration-general

**Risk class: R2** (UI work — Settings window).

## Intent

Move the **History Duration** picker from the `Display Options` section into the `General` section of Settings, as the **2nd row** (between Refresh Interval and Launch at Login). `Display Options` currently contains only this one control, so the section disappears entirely.

No behavior change: the picker keeps its control type, its five options, and the `historyDuration` preference key. This is a view-placement move only.

## Context (designer reconnaissance, 2026-10-26, cited)

- Settings scene: SwiftUI `Settings` scene (`StatsLite/StatsLiteApp.swift:18-24`) → `SettingsView` (`StatsLite/SettingsView.swift:13-43`). Single `Form { ... }.formStyle(.grouped)` in a `VStack(spacing: 0)` pinned to `.frame(width: 380, height: 340)` (`StatsLite/SettingsView.swift:17, 33`), version footer beneath (`:24-30`).
- Sections in order: `generalSection` (`:47-52`), `visibleMetricsSection` (`:76-97`), `displayOptionsSection` (`:101-112`).
- History Duration lives in `displayOptionsSection` (`:101-103`): `Picker("History Duration", selection: $preferences.historyDuration)` with tags 30/60/120/180/300 → labels `30 s`, `1 min`, `2 min`, `3 min`, `5 min` (`:104`).
- Current General rows: Row 1 `refreshIntervalRow` (`:49, 54-66`, picker + caption), Row 2 `launchAtLoginRow` (`:50, 68-79`, toggle + conditional hint caption).
- Persistence: `PreferencesStore.historyDuration` (`StatsLite/PreferencesStore.swift:51-57`), `@AppStorage("historyDuration")` (`:94`), default `60`. Change propagation: `SettingsView.body` `.onChange(of: preferences.historyDuration) { monitor.apply(preferences) }` (`:38`). Zero migration needed.
- Offscreen render pass (designer): removing the orphaned `Display Options` section cuts form content height from 516.5 pt to 461.5 pt, reducing vertical scroll.
- Test blast radius: `StatsLiteTests/RemoveCoresBreakdownTests.swift:125,139` mention History Duration and need a comment/string refresh; `SettingsWindowTests.swift` has no section-order assertions today; `MenuBarTempBlockTests.swift:549` asserts only within Visible Metrics (unaffected).
- Test command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS,arch=arm64' -derivedDataPath .derivedData CODE_SIGN_IDENTITY="-"`
- Build command: same line with `xcodebuild build`.
- Xcode project uses filesystem-synchronized groups (`objectVersion = 77`); no pbxproj edits needed for test-file changes.

## Approach (decisions)

**D1 — Move the row, keep the picker.** Extract the History Duration picker into a `historyDurationRow` view and place it in `generalSection` between `refreshIntervalRow` and `launchAtLoginRow`. Control stays a SwiftUI `Picker` (discrete values map to fixed `HistoryBuffer` sizes; a slider would allow arbitrary values). Pop-up style matches the Refresh Interval picker above it.

**D2 — Delete `displayOptionsSection` entirely.** It holds only History Duration. An empty grouped-form section leaves an orphaned header and empty card, so both the `Form` reference and the section declaration go.

**D3 — No persistence change.** Key, type, default, and the `.onChange(of: preferences.historyDuration)` wiring stay as they are. The picker binding is unchanged, so the move cannot reset a stored value.

**D4 — Update stale test text, add an order test.** `RemoveCoresBreakdownTests.swift:125,139` comments/strings refreshed for the new location. Add an automated assertion in `SettingsWindowTests` that `History Duration` sits second in General and `Display Options` no longer exists.

## Design Blueprint (designer, 2026-10-26 — condensed verbatim)

### Part 1 — Wireframe

```
+-------------------------------------------------------+
|  Stats Lite Settings                         380 pt   |
|  General                                              |
|  | Refresh Interval                          1 s ^ |  | Row 1 + caption
|  | History Duration                        1 min ^ |  | Row 2 (TARGET)
|  | Launch at Login                           ( O ) |  | Row 3 + hint
|  Visible Metrics (5 toggle rows + footer)            |
|              Stats Lite v1.0 (Build 1)                |
+-------------------------------------------------------+
```

### Part 2 — Target state

General rows, exact order:
1. `refreshIntervalRow` — Picker `1 s`/`2 s`/`3 s`/`5 s` + caption "Network throughput always refreshes at 1-second intervals."
2. `historyDurationRow` — Picker `30 s`/`1 min`/`2 min`/`3 min`/`5 min`, no caption.
3. `launchAtLoginRow` — Toggle + conditional login hint caption.

Section order: General (3 rows), Visible Metrics (5 rows + footer). `Display Options` removed.

### Part 3 — Component skeleton

```swift
private var generalSection: some View {
    Section("General") {
        refreshIntervalRow
        historyDurationRow
        launchAtLoginRow
    }
}

private var historyDurationRow: some View {
    Picker("History Duration", selection: $preferences.historyDuration) {
        Text("30 s").tag(30)
        Text("1 min").tag(60)
        Text("2 min").tag(120)
        Text("3 min").tag(180)
        Text("5 min").tag(300)
    }
}
```

Files to edit:
1. `StatsLite/SettingsView.swift` — add `historyDurationRow` to General between the two existing rows; remove `displayOptionsSection` from the `Form` and delete its declaration; move the picker out of Display Options (no duplicate).
2. `StatsLiteTests/RemoveCoresBreakdownTests.swift` — refresh the line 125 comment and line 139 failure string for the new location.
3. `StatsLiteTests/SettingsWindowTests.swift` — add a test: General row order is Refresh Interval < History Duration < Launch at Login, and no `Display Options` section / no duplicate `History Duration` label.

### Part 4 — State & persistence

Key `"historyDuration"`, `Int` seconds, default 60, unchanged. Zero migration. `.onChange(of: preferences.historyDuration) { monitor.apply(preferences) }` (`SettingsView.swift:38`) retained.

### Part 5 — Risks

- Grouped-form keyboard navigation follows visual order; clustering the two timing controls improves flow.
- Fixed 380x340 frame: less content height means less scrolling, no clipping.
- Existing suite impact limited to the two test-file text updates above.

### Visual Acceptance Checklist (designer, 2026-10-26)

- **VAC-1**: General is the first section header of the form.
- **VAC-2**: General row 1 = Refresh Interval picker + caption.
- **VAC-3**: General row 2 = History Duration picker.
- **VAC-4**: General row 3 = Launch at Login toggle.
- **VAC-5**: The History Duration menu shows exactly `30 s`, `1 min`, `2 min`, `3 min`, `5 min` in order.
- **VAC-6**: No duplicate History Duration control anywhere in the window.
- **VAC-7**: No `Display Options` section header or container.
- **VAC-8**: Left labels of all three General rows share identical left alignment at 380 pt and narrow 320 pt.
- **VAC-9**: Right controls of all three General rows share identical right alignment at 380 pt and narrow 320 pt.
- **VAC-10**: `History Duration` label renders without truncation or wrapping at 380 pt.
- **VAC-11**: A new duration selection persists across app restart.
- **VAC-12**: `SettingsWindowTests` asserts the order Refresh Interval < History Duration < Launch at Login < Visible Metrics and the absence of Display Options.

## ISC (binary yes/no)

Evidence rule: macOS Settings window. VAC items verify through offscreen render screenshots (dark and light, 380 pt and 320 pt widths) or the unit test that proves the layout — say which per item. Any "no" is blocking.

### Functional

- [ ] **F1**: History Duration renders as the 2nd row of General (VAC-3).
- [ ] **F2**: Launch at Login shifts to row 3 with its toggle and conditional hint intact (VAC-4).
- [ ] **F3**: `Display Options` is gone; no orphaned header, no empty card (VAC-7).
- [ ] **F4**: No duplicate History Duration control remains (VAC-6).
- [ ] **F5**: Picker options unchanged: `30 s`, `1 min`, `2 min`, `3 min`, `5 min` (VAC-5).
- [ ] **F6**: Changing the duration still calls `monitor.apply(preferences)` — sparkline window follows the new duration without restart.
- [ ] **F7**: A stored non-default duration (e.g. 300) survives the move and still renders as the selected item on launch; no migration code exists (VAC-11).
- [ ] **F8**: Full test suite green, including the new order test in `SettingsWindowTests` and the refreshed `RemoveCoresBreakdownTests` strings (VAC-12).

### Failure modes (oracle, 2026-10-26)

- [ ] **FM1**: The `Form` references no removed section symbol; build has zero errors and no new warnings.
- [ ] **FM2**: Grouped form renders no empty section header/card where Display Options was.
- [ ] **FM3**: Window height stays 340 pt; nothing clips at default and narrow widths.
- [ ] **FM4**: Refresh Interval caption and login hint caption still render directly under their rows (not detached or orphaned by the reorder).
- [ ] **FM5**: `MenuBarTempBlockTests.swift:549` (Visible Metrics order) still passes; Visible Metrics rows and footer unchanged.

### VAC

- [ ] **VAC-1** … [ ] **VAC-12**: every item from the blueprint checklist answers yes, with the named evidence.

## Task list

| Task | Goal | Agent | Depends on |
|---|---|---|---|
| T1 | Red + green: move History Duration row to General row 2, remove Display Options section, refresh stale test text, add Settings order test | coder | - |
| T2 | Verify: full suite, build, offscreen Settings renders (dark/light, 380/320 pt) vs VAC + ISC | tester | T1 |

One worktree hosts T1 → T2, then squash-merge to `main`.

- Branch: `feat/2026-10-26-settings-history-duration-general`
- Worktree: `/Users/jonathan/beliantech/stats-lite-macos/worktrees/2026-10-26-settings-history-duration-general`

### T1 — Move the row (TDD)

**Red cycle first.** Test files only: add the General-order / no-Display-Options / no-duplicate assertion to `StatsLiteTests/SettingsWindowTests.swift`; update the History Duration location strings in `StatsLiteTests/RemoveCoresBreakdownTests.swift` (line 125 comment, line 139 failure string) to expect the new location. Run the test command; the order test must fail (red) against the current layout. Touch no application code in the red spawn.

**Green scope** (`StatsLite/SettingsView.swift` only): add `historyDurationRow` per the blueprint skeleton; insert it into `generalSection` between `refreshIntervalRow` and `launchAtLoginRow`; remove `displayOptionsSection` from the `Form` and delete the section declaration and the inline picker it contained. Do not touch `PreferencesStore`, the `.onChange` wiring, `visibleMetricsSection`, the window frame, or the version footer.

Green = red tests pass + all pre-existing suites pass + build clean (zero errors, no new warnings).

### T2 — Verification (tester)

Worktree: `/Users/jonathan/beliantech/stats-lite-macos/worktrees/2026-10-26-settings-history-duration-general`.

1. Full test command → all suites green, including `SettingsWindowTests`, `RemoveCoresBreakdownTests`, `MenuBarTempBlockTests`.
2. Build command → zero errors, no new warnings.
3. Offscreen-render or launch the Settings window; capture dark and light appearance at 380 pt and 320 pt widths.
4. Report per-item pass/fail for F1–F8, FM1–FM5, VAC-1–VAC-12 with screenshot or test-name evidence. Any "no" is BLOCKING; state the concrete deviation.
5. F6/F7 evidence: set a non-default duration, relaunch, confirm selection persisted and sparkline axis updates within one refresh cycle.

## Verification (overall)

- Test suite green, build clean, every ISC item yes with evidence.
- Diff review: only `StatsLite/SettingsView.swift`, `StatsLiteTests/SettingsWindowTests.swift`, `StatsLiteTests/RemoveCoresBreakdownTests.swift` change. No edits to `PreferencesStore`, `SystemMonitor`, `HistoryBuffer`, or Visible Metrics rows.

## Git safety protocol

- All code changes happen in the worktree on branch `feat/2026-10-26-settings-history-duration-general`, created before the T1 spawn: `git worktree add -B feat/2026-10-26-settings-history-duration-general <dir> main`.
- Coder commits per task: `test(settings): red tests for General section row order`, `refactor(settings): move History Duration into General section`.
- Merge into `main` only after T2 passes and the reviewer GO: `git merge --ff-only feat/2026-10-26-settings-history-duration-general` (or `--squash`). Never `--no-ff`.
- Cleanup: `git worktree remove --force <dir>`, `git worktree prune`, `git branch -d feat/2026-10-26-settings-history-duration-general`.
- Never touch `main` directly; stage files from inside the worktree only.

## Open questions

None. The user's instruction fixed the destination (General, 2nd row); the designer blueprint fixed the resulting row order and the removal of the emptied Display Options section.
