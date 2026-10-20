# Update check cadence: 6 hours to 24 hours

Plan name: 2026-10-21-update-check-24-hour-cadence

Risk class: R0 (one interval constant in one file; no behavior beyond the
period; no API/schema/UI change)

## Intent

Relax the background update-check cadence from 6 hours to 24 hours. The 300 s
launch floor and all other semantics stay unchanged.

## Facts (verified)

- Cadence lives in `StatsLite/UpdateCheckService.swift` (merged `ab8100a`),
  written as the sleep interval in the `ContinuousClock` loop.
- No test pins the cadence value; floor tests use epoch gaps against the
  300 s floor, unaffected by the loop period.

## ISC

- [ ] I1. The loop interval constant reads 24 h, single source of truth (named
  constant, not a duplicated literal).
- [ ] I2. Full suite green (292/292).
- [ ] I3. Reviewer GO; ff-only merge to local main.

## Tasks

- [ ] **T1** — `[coder]` [no-red] in worktree `worktrees/update-cadence`,
  branch `feat/update-cadence`: change interval to 24 h; if the value is an
  inline literal, lift it to one named constant. Full suite green.
  green ⏳ · review ⏳
- [ ] **T2** — reviewer `[code-review]`; merge ff-only; cleanup. merged ⏳
