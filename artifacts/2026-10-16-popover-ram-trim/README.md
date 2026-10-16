# Popover RAM trim artifacts

## baseline/

Baseline captures taken before any rendering edit (T1a, 2026-10-16,
release build of the worktree).

- `dark.png`, `light.png`: open StatsLite popover in dark and light
  appearance. Produced by `scripts/capture_baseline.sh`.
- Footprint log: `.pi/plans/2026-10-16-popover-ram-trim/footprint-baseline.txt`.
  Produced by `scripts/measure_popover_footprint.sh`.

Baseline numbers (3 cycles, 5 s hold, 0.4 s sampler):

- Open peak footprint per cycle: 203.0 / 208.0 / 206.0 MB.
- Graphics region dirty max across opens: 163.0 MB.
- Idle footprint 40 s after the last close: 32.0 MB.

Red-phase targets: open peak < 100 MB, graphics region < 50 MB.
