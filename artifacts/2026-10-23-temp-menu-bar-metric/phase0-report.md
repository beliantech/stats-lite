# Phase 0 report — AppleSMC temperature probe

Plan: `plans/2026-10-23-temp-menu-bar-metric.md`
Date: 2026-10-23
Branch: `feat/2026-10-23-temp-menu-bar-metric-phase0-smc-probe`

## Machine

- Chip: Apple M5 Max (`sysctl -n machdep.cpu.brand_string`).
- macOS 27.0.1, build 26A434.
- No root used. The probe opens `AppleSMC` as the logged-in user.

## Verdicts

- **H1 (CPU die key exists on AppleSMC): INCONCLUSIVE — Phase 0 gate did NOT pass.** The probe route works and reads plausible live die temperatures. The controlled CPU-load and GPU-load attribution rounds did not complete before the session time budget expired. No GO for any product-code task. No falsification either: no controlled load round ran, so no key failed the 15-25 C rise test.
- **H2 (read latency fits the sampling loop): GO.** Measured p99 = 0.964 ms over 1000 open/GetKeyInfo/Read/close cycles, below the `unverified prior` threshold of 5 ms from the plan. The standard 1 Hz loop can carry temperature reads. The 5 ms and 50 ms thresholds remain `unverified prior`.

## Probe mechanism — confirmed working

Route: `IOServiceGetMatchingServices("AppleSMC")` then `IOServiceOpen` then
`IOConnectCallStructMethod` selector 2 with an 80-byte `SMCParamStruct`.
Command 9 (GetKeyInfo), command 5 (ReadKey), command 8 (key name by index).

Two findings from live runs:

1. `IOServiceOpen` fails with `kIOReturnNotPrivileged` (0xe00002c2) when the
   owning-task argument is 0. It succeeds when the argument is
   `mach_task_self_`. Both beltex/SMCKit and exelban/stats pass
   `mach_task_self_`. The probe comment in `AppleSMC.init()` records this.
2. The `SMCParamStruct` layout verifies at startup: size 80 bytes, offsets
   key=0, vers=4, pLimitData=12, keyInfo=28, result=40, status=41, data8=42,
   data32=44, bytes=48. An explicit `padding: UInt16` field keeps these
   offsets. The probe exits nonzero if any offset moves.

Enumeration reads the `#KEY` count (2263 on this machine) and then every key
by index. The run in `key-enumerate.log` finished with 2263 keys, 0 index
errors, and 0 failed GetKeyInfo calls.

## Plausibility filter

A key joins the watch set when all three hold: its type is a temperature
family (`flt `, or `sp..`/`fp..` fixed point), its value is finite and inside
-20 to 130, and its name starts with `T` (the SMC temperature prefix). The
`sp..`/`fp..` families also encode voltages, currents, fan targets, and
thresholds, all of which can sit inside the range, so the `T` prefix gate
keeps the set temperature-like. 296 keys pass on this machine.

## Decoders that worked

- `flt-le` (little-endian IEEE-754 float): matched 295 of the 296 plausible
  temp keys. All scalars on this Apple Silicon SMC are type `flt `.
- `flt-be` fallback: selected for 1 key (`TNSz`, 0.0). Its little-endian value
  was not plausible, so the byte-swapped decode matched. Treat `TNSz` as
  suspect until a load round proves it.
- `sp78`/`fpe2` style fixed point (Intel machines): implemented with
  big-endian primary and little-endian fallback and labeled per key. This
  machine exposes no `sp78` or `fpe2` keys, so those decoders stayed unused.
  One `fp1f` key exists (`CLKS`); it is not a temperature.
- `ui8`/`ui16`/`ui32` decode for counters such as `#KEY`.

## Plausible temperature key census (296 keys)

By name prefix: `Tg` 84, `Tm` 40, `Tp` 23, `Tf` 22, `TP` 20, `TU` 18,
`TR` 18, `Ts` 13, `TN` 11, `Ta` 10, `Tz` 9, `TV` 9, `TS` 5, `TH` 5, `TB` 3,
`TM` 2, `TC` 2, `TW` 1, `TI` 1.

Full list with types, decoder labels, and values:
`artifacts/2026-10-23-temp-menu-bar-metric/key-enumerate.log`.

## CPU candidate keys

The controlled CPU-load round did not run, so no key carries a measured load
delta. The columns below are uncontrolled single-run `--temps` sanity
samples taken at 07:36-07:46 local time with no load generator running.
Meanings are `unverified prior` (SMC naming convention), never measured here.

| key family | count | meaning (unverified prior) | observed samples, C | delta |
| --- | --- | --- | --- | --- |
| `Tp00` | 1 | CPU P-cluster die sensor candidate | 45.7, 47.8, 41.8, 57.4*, 42.1 | not measured |
| `Tp0C` | 1 | CPU die sensor candidate | 47.7, 45.3, 41.7, 55.3*, 41.3 | not measured |
| `Tp*` all | 23 | CPU die candidates | 40.2 to 47.8 idle range | not measured |
| `Tm*` | 40 | memory/SoC-area candidates | 38.4 to 44.6 idle range | not measured |

*The 57.4/55.3 pair is one uncontrolled spike. An unidentified background
activity heated `Tp00` from about 42 to 57.4 and it fell back within 30 s.
The cause is unknown. This is not controlled-load evidence and it does not
count toward the H1 falsification signature in either direction.

## GPU candidate keys

No GPU-load round ran. No key carries a measured GPU delta.

| key family | count | meaning (unverified prior) | observed samples, C | delta |
| --- | --- | --- | --- | --- |
| `Tg08` | 1 | GPU die sensor candidate | 39.5, 39.1, 38.0, 39.0, 37.9 | not measured |
| `Tg0O` | 1 | GPU die sensor candidate | 39.5, 39.1, 38.0, 39.0, 37.9 | not measured |
| `Tg*` all | 84 | GPU die candidates | 38.0 to 41.1 idle range | not measured |

Per reviewer F3: a missing GPU-side key is not a stop condition. The two-row
design renders `--°` on the GPU row. This report records GPU attribution as
unmeasured, not absent.

Other flat keys worth noting for later rounds: `Tf06` and `Tf16` read a
constant 73.7 and 75.7 across every sample, idle or not. `TCMb` reads about
50 to 52 and `TVD0` about 52 to 55. These are probably not die sensors. Their
meaning is `unverified prior`.

## H2 latency — measured

Command: `tools/smc-probe/probe --latency 1000` on an idle machine after the
sanity runs. Target key `TB0p`. Each cycle opens a fresh connection, runs
GetKeyInfo, runs ReadKey, then closes. 1000 of 1000 cycles succeeded, 0
errors.

| metric | value |
| --- | --- |
| min | 165 us (0.166 ms) |
| p50 | 315 us (0.315 ms) |
| p95 | 358 us (0.358 ms) |
| p99 | 964 us (0.964 ms) |
| max | 1060 us (1.060 ms) |
| mean | 336 us (0.336 ms) |

p99 = 0.964 ms sits below the 5 ms `unverified prior` bound, so the plan's
standard 1 Hz sampler loop can carry the reads with no dedicated cadence and
no cached connection.

## Attribution runs — NOT measured

The following deliverables did not run before the session time budget
expired. Each is listed here as not measured:

- `h1-baseline.log` (baseline `--watch 10`): not captured.
- `h1-cpu-load.log` (4 x `yes > /dev/null` plus `--watch 30`, then recovery
  `--watch 10`): not captured.
- `h1-gpu-load.log` (Metal `gpuload 30` plus `--watch 30`, then recovery):
  not captured. The `gpuload` tool built and smoke-ran for 4 s on the Apple
  M5 Max GPU (226 dispatches), so the tool itself works.
- Baseline dark/light VAC screenshots (`scripts/capture_baseline.sh` under
  `caffeinate`): not captured.

## How to finish Phase 0

From the worktree root. Wait for idle temperatures to stabilize between
rounds. One variable per round: never run the CPU and GPU loads together.

```bash
tools/smc-probe/probe --watch 10 > artifacts/2026-10-23-temp-menu-bar-metric/h1-baseline.log
{ echo "# phase=load";   tools/smc-probe/probe --watch 30; } > artifacts/2026-10-23-temp-menu-bar-metric/h1-cpu-load.log
#   (with 4 x yes > /dev/null running in the background, then kill them)
{ echo "# phase=recovery"; tools/smc-probe/probe --watch 10; } >> artifacts/2026-10-23-temp-menu-bar-metric/h1-cpu-load.log
#   wait for cool-down, then the same pair with tools/smc-probe/gpuload 30
python3 tools/smc-probe/analyze_attribution.py artifacts/2026-10-23-temp-menu-bar-metric
caffeinate -di scripts/capture_baseline.sh --out-dir artifacts/2026-10-23-temp-menu-bar-metric/baseline
```

The analyzer prints the per-key delta table, the CPU-side and GPU-side
candidate lists, and the H1 GO/NO GO line from the 15-25 C band rule.

## Raw logs in this directory

- `key-enumerate.log` — full key table, 2263 keys, with decoder labels.
- `h2-latency.log` — the 1000-cycle latency run.
- `h1-baseline.log`, `h1-cpu-load.log`, `h1-gpu-load.log` — absent, not
  measured.
- `baseline/` — absent, not captured.
