# AGENTS

- Project design rules live in `DESIGN.md` at the repo root. Check it before UI work.
- Status item views must not use `.animation` or `.contentTransition`. Transitions stay discrete.
- Every metric-card sparkline carries the shared `SparklineTimeAxisView` axis: human duration label (`-30s`/`-1m`/`-2m`/`-3m`/`-5m`, never raw `-120s`) … `Now`, 9 pt monospaced-digit tertiary, `.accessibilityHidden(true)`. No axis when the chart itself is absent (GPU unavailable, Network loading/off).

## Evidence before hypothesis

- A plan must not name a root cause until one attribution measurement proves ownership
  (for example `sudo footprint -v --unmapped <pid>` while the symptom is active).
- Every hypothesis carries a falsification signature in the ISC: if H, then changing X
  moves metric M from A to B. If M does not move, H is dead and the plan stops.
- One variable per experiment. Never batch fixes in the same measurement round.
- Oracle output is a prior, not a finding. Mark numeric estimates `unverified prior`
  unless they carry a citation or a measurement.
- For popover memory work, use `scripts/measure_popover_footprint.sh` (footprint sampler
  with the `--open-popover` cycle hook) and `scripts/capture_baseline.sh` (dark/light
  VAC screenshots). Capture the baseline before the first code edit.
- Popover close is display-sleep-sensitive: when `CGDisplayIsAsleep == 1`, the animated
  close never completes and `popoverDidClose` never fires. Run any tool that closes the
  popover (footprint cycles, tests) with the display awake — verify `CGDisplayIsAsleep`
  or wrap the run in `caffeinate`.
- `StatusItemControllerPopoverTests.testTogglePopoverCyclesMountAndRelease` sets
  `popover.animates = false` (merge d8d98bb) to stay deterministic while the display
  sleeps. Do not remove that line; it is not dead code.
- Outside-click dismissal runs through the lifecycle-scoped `NSEvent` monitors in
  `StatusItemController` (installed on show, removed in `popoverDidClose`/`deinit`):
  `.transient` never sees outside clicks in this non-activating app. Keep the monitors.
- A controller with a shown or just-closed popover does not deallocate on release
  (A/B-proven, plan 2026-10-21-popover-outside-click-dismissal-monitor). Popover lifecycle
  tests must not assert dealloc-while-open.

## Known issues (parked)

- `scripts/measure_popover_footprint.sh` has no display-sleep guard. An asleep display
  stalls popover close, and later cycles sample a stale open popover — the memory numbers
  are invalid. Fix parked: add a `CGDisplayIsAsleep` startup check or wrap the run in
  `caffeinate`.
- `[StatusBar] disconnected scene` is a known latent AppKit warning
  (plans/2026-10-16-network-monitor.md). It is never the display-sleep root cause; do not
  lump the two together.
