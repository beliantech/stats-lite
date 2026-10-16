# Task 06 — Settings Window + Launch-at-Login

## Objective
Implement the mini settings page (Settings scene), wire every control to live behavior, and finish launch-at-login.

## Context — READ FIRST
**Your first action**: read the Design Blueprint in the main repo at `/Users/jonathan/beliantech/stats-lite/docs/plans/2026-10-13-stats-lite-menu-bar/notes.md` — section 1 (settings wireframe), section 2 (`SettingsView` skeleton), section 5 (VAC-12, VAC-13). Also read the ISC and task 04's `PreferencesStore`/`LaunchAtLoginService` contracts.

## Deliverables
1. `StatsLite/Views/SettingsView.swift` per blueprint: `.formStyle(.grouped)`, fixed 380×340 pt, `.windowResizability(.contentSize)`:
   - General: Refresh Interval picker (1/2/5 s), Launch at Login toggle.
   - Menu Bar Display: Display Format picker (Both/CPU Only/RAM Only), RAM Unit picker (GB/Percentage), Show Category Labels toggle.
   - Popover Options: Show Per-Core CPU Breakdown toggle, History Duration picker (30/60 s).
   - Footer row: "Stats Lite" + version from `CFBundleShortVersionString`/`CFBundleVersion` (read from Bundle, not hardcoded).
2. Wire `Settings` scene in `StatsLiteApp` with the shared `PreferencesStore` + `SystemMonitor`.
3. Live behavior: interval change restarts sampling immediately; format/unit/label changes update the menu bar label immediately; history-duration change trims history; per-core toggle expands/collapses disclosure default state.
4. Launch-at-login: toggle reflects `LaunchAtLoginService.status`; on `.requiresApproval` show inline hint text ("Allow in System Settings → General → Login Items") and keep toggle consistent; errors surface inline (no silent failure, no retry loop).
5. Settings window opens focused even though the app is LSUIElement (already handled via activate-before-openSettings in task 05 — verify).

## Visual verification (required)
Build and run; open settings from the popover gear. Screenshot the settings window. Verify VAC-12 (380×340, grouped form) and VAC-13 (legible in light + dark appearance — toggle appearance or use `osascript` to switch). Click every control and confirm live effect on the menu bar label/popover. Report VAC-12/13 as Met/Not-met with evidence.

## Verify
- `xcodebuild build` clean; `xcodebuild test` green.
- All settings controls verified live.
- All 13 VAC rows from the ISC now Met.
- **Footprint (ISC AC-10/11)**: final RSS measurement after 60 s idle with default settings (report number); `xcodebuild -configuration Release` build and `du -sk` of `StatsLite.app` under 50 MB (report number).

## Commit(s) (max 2)
`feat(settings): add settings window with live preferences and launch-at-login`
