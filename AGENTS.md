- Status item views must not use `.animation` or `.contentTransition`. Transitions stay discrete.

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
