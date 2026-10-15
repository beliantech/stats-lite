# Task 06 — Settings Window

## Objective

Settings scene: three metric toggles with guard, display options, launch-at-login, version label.

## Read first

- **Extension blueprint** §1 Settings wireframe, §3 toggle states, §4 interaction rules, VAC-23/VAC-24.
- Base blueprint `notes.md` settings section (grouped form styling) — minus dropped controls.
- ISC §Architecture: Settings persistence & guard; UI note on `openSettings`.

## Deliverables

1. `Settings` scene, `.formStyle(.grouped)`, 380×340 pt:
   - **General**: Refresh Interval picker (1/2/5 s), Launch at Login toggle.
   - **Visible Metrics**: three toggles (CPU Utilization, Memory Pressure (RAM), GPU Utilization); when `activeMetricCount == 1` the sole ON toggle `.disabled(true)`; footer `At least one metric must remain enabled.`
   - **Display Options**: Show Category Labels, Show Per-Core CPU Breakdown, History Duration picker (30/60 s).
   - Footer: `Stats Lite v<version> (Build <n>)` from bundle info.
2. Toggles bind to `PreferencesStore`; every control changes behavior live (task 04 restart path); no display-format picker, no RAM-unit control.
3. Launch-at-login shows real `SMAppService.mainApp.status`; `.requiresApproval` renders as a hint state, no retry loop.

## Verify

- AC-7 end-to-end: toggle → menu bar slot/card appears/disappears immediately; last-one lock; interval/history changes observable live.
- Screenshot Settings in Light + Dark; mark VAC-23, VAC-24 and shared VAC-12.

## Report

- Conventional commits, ≤2.
