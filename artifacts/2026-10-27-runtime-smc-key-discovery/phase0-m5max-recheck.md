# Phase 0 recheck — M5 Max delta-gap gate (existing logs, no new run)

Question: would the draft plan's H2 gate pass on the machine we already
measured? The draft H2 used an absolute cross-domain gap under GPU load.
This recheck recomputes both gate variants from the existing 2026-10-23 h1
logs. Source files, all in `artifacts/2026-10-23-temp-menu-bar-metric/`:
`h1-baseline.log`, `h1-cpu-load.log`, `h1-gpu-load.log` (10 ticks each,
296 keys, `index_errors=0`).

Method: per-key phase means, deltas from baseline. Two gate variants:

- Absolute gap (draft H2): `max(Tg) − max(CPU domain)` under GPU load.
- Delta gap (analyzer-style): per key, `(dGPU − dCPU)`; GPU-side if ≥ +5.0,
  CPU-side if ≤ −5.0. Bands are `AMBIGUITY_GAP = 5.0` from
  `tools/smc-probe/analyze_attribution.py:34`.

## Result — the draft gate fails, the delta-gap gate passes

Absolute gap under GPU load (draft H2):

- `max(Tg) = 48.7 °C` (`Tg6I`), `max(CPU domain) = 57.2 °C` (`TVD0`).
- Gap = **−8.5 °C**. The draft gate falsifies the design on our own data.
- The gate is discarded. Reason: absolute level tracks rail/voltage
  sensors, not load attribution.

Delta gap per key, family summary:

| family | n | GPU-side (≥ +5) | CPU-side (≤ −5) | median gap |
|---|---|---|---|---|
| `Tg`  | 84 | 29 | 0 | +4.5 |
| `Tp`  | 23 | 0  | 19 | −13.2 |
| `TVD` | 6  | 0  | 5  | −11.6 |
| `Tm`  | 40 | 0  | 2  | −0.3 |
| `TRD` | 17 | 6  | 0  | +4.0 |
| `TUD` | 17 | 5  | 0  | +3.3 |
| `Tf`  | 22 | 0  | 5  | −0.9 |

- `Tg` separates clean: 29 GPU-side, 0 CPU-side. `Tp` separates clean the
  other way: 19 CPU-side, 0 GPU-side. Round separation holds both ways
  (CPU round: `Tp00` +22.8 vs `Tg` max +4.8; GPU round: `Tg6I` +10.5 vs
  CPU domain max +6.5).
- `TVD` is a CPU-side family, hottest absolute sensor under both loads —
  including it in a `max()` would print rail temperature as CPU temp.
- `Tm` does not move (median −0.3). The oracle's `Tm → CPU` prefix claim is
  not supported by this data.
- `TRD`/`TUD` lean GPU-side but stay under the +5 median; they are neither
  domain's aggregate input until attributed.

## Two more measured facts that change the gates

1. **The 15 °C rise band cannot apply to the GPU round.** Max `dGPU` over
   all 296 keys = +10.5 (`Tg6I`); 0 keys reach +15 in the GPU round, while
   24 keys reach +15 in the CPU round. This is why
   `phase0-report.md:115-116` recorded "0 keys classified GPU-side": the
   band, not the sensors. GPU-round classification rests on the delta gap
   alone.
2. **Flat keys are measurable only under load.** 66 of 296 keys moved
   < 2 °C in *both* load rounds (`Tf06` sits at 73.7 every tick). A
   variance test run on an idle watch would also call real sensors flat,
   so the exclusion test is "flat in both load rounds", never idle.

Status: `unverified prior` becomes **measured** for the M5 Max only. The
same two rounds must run on the MacBook Air M2 before any code edit.
