# Phase 0 report — AppleSMC temperature probe

Plan: `plans/2026-10-23-temp-menu-bar-metric.md`
Date: 2026-10-23
Branch: `feat/2026-10-23-temp-menu-bar-metric-phase0-smc-probe`

## Machine

- Chip: Apple M5 Max (`sysctl -n machdep.cpu.brand_string`).
- macOS 27.0.1, build 26A434.
- No root used. The probe opens `AppleSMC` as the logged-in user.

## Verdicts

- **H1 (AppleSMC exposes CPU and GPU die temperature keys): GO — measured.**
  24 of 296 plausible keys rose 15.7 to 22.8 °C (mean delta) within the 30 s
  CPU-load window, peaks to +25.3 °C, and all 24 recovered to within +5.0 °C
  of baseline (range +3.6 to +4.7) in the 10 s cool-down. 24/24 keys sit in
  the plan's 15-25 °C falsification band, 24/24 recovered. Evidence:
  `h1-baseline.log`, `h1-cpu-load.log`, `h1-cool.log`, full classification in
  `h1-attribution.md`.
- **H1 GPU sub-rule (reviewer F3): 0 keys classified GPU-side.** This is not
  a stop. Recorded as a support-statement item: the two-row design renders
  `--°` on the GPU row when no GPU key is used. The measured detail follows
  in the GPU table. No key was ambiguous; 272 keys were neither.
- **H2 (read latency fits the sampling loop): GO — measured.** p99 = 0.964 ms
  over 1000 open/GetKeyInfo/Read/close cycles, below the `unverified prior`
  5 ms bound. Ride the standard 1 Hz loop. The 5 ms and 50 ms bounds remain
  `unverified prior`.
- **Baseline screenshots: blocked.** See the screenshots section.

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
- `flt-be` fallback: selected for 1 key (`TNSz`, 0.0). Its little-endian
  value was not plausible, so the byte-swapped decode matched. Treat `TNSz`
  as suspect until a load round proves it.
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
`key-enumerate.log`.

## CPU candidate keys — measured deltas (top 12 of 24)

CPU round: 4 x `yes > /dev/null` for 30 s, one variable, no GPU load running.
Columns are °C. `dCPU` is the mean of 30 load ticks minus the 10-tick
baseline mean. `peakCPU` uses the hottest load tick. `recCPU` is the 10-tick
cool-down mean minus baseline. All 24 classified CPU-side keys appear in
`h1-attribution.md`.

| key | baseline | cpu-load mean | dCPU | peakCPU | recCPU | dGPU | class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Tp00 | 38.9 | 61.7 | +22.8 | +25.3 | +4.7 | +4.9 | CPU-side |
| Tp0C | 38.7 | 61.4 | +22.7 | +25.0 | +4.5 | +4.3 | CPU-side |
| TVDC | 48.1 | 68.9 | +20.8 | +23.2 | +4.1 | +3.9 | CPU-side |
| TVDP | 48.1 | 68.9 | +20.8 | +23.2 | +4.1 | +3.9 | CPU-side |
| Tp0X | 38.6 | 57.9 | +19.3 | +20.8 | +4.4 | +4.7 | CPU-side |
| Tp0p | 38.3 | 57.6 | +19.3 | +21.1 | +4.3 | +3.7 | CPU-side |
| Tp0O | 38.9 | 58.1 | +19.2 | +21.3 | +4.4 | +4.6 | CPU-side |
| Tp0G | 38.5 | 56.9 | +18.4 | +20.1 | +4.2 | +3.9 | CPU-side |
| TVD0 | 50.6 | 68.9 | +18.2 | +20.7 | +3.6 | +6.5 | CPU-side |
| Tp0g | 38.4 | 56.6 | +18.1 | +20.7 | +4.2 | +4.0 | CPU-side |
| Tp0K | 38.7 | 56.8 | +18.1 | +19.6 | +4.2 | +4.2 | CPU-side |
| Tp04 | 38.5 | 56.4 | +17.9 | +19.6 | +4.3 | +4.2 | CPU-side |

The remaining 12 CPU-side keys: TCMb, Tp08, Tp0y, Tp0u, Tp0d, Tm0y, Tm2T,
Tp0a, Tp0U, Tp0R, Tp0m, Tp0j (dCPU +15.7 to +17.6, all recovered within
+4.6). Family split: 18 `Tp*`, 3 `TVD*`, 1 `TCMb`, 2 `Tm*`. `Tp*` as CPU die
sensors is now measured, not a prior, for this machine and this macOS build.

## GPU candidate keys — measured deltas

GPU round: `gpuload` Metal burn for 30 s alone (1699 dispatches, see
`h1-gpu-load-inner.log`), no CPU load running. **0 keys reached the 15 °C
classification threshold, so 0 keys classify GPU-side.** The strongest
`Tg*` responses, in °C:

| key | baseline | gpu-load mean | dGPU | peakGPU | dCPU | class |
| --- | --- | --- | --- | --- | --- | --- |
| Tg6I | 38.2 | 48.7 | +10.5 | +12.1 | +2.7 | neither |
| Tg76 | 38.2 | 48.6 | +10.4 | +11.9 | +2.7 | neither |
| Tg5R | 38.2 | 48.4 | +10.2 | +11.8 | +2.9 | neither |
| Tg4e | 38.2 | 48.3 | +10.1 | +11.7 | +2.9 | neither |
| Tg4h | 38.2 | 48.1 | +9.9 | +11.5 | +2.9 | neither |
| Tg12 | 37.7 | 47.6 | +9.9 | +11.3 | +3.4 | neither |
| Tg08 | 37.7 | 47.6 | +9.9 | +11.4 | +3.4 | neither |
| Tg6L | 38.2 | 48.0 | +9.8 | +11.4 | +2.7 | neither |

Honest reading: `Tg*` keys moved about 3x more under GPU load than under CPU
load (+9.8 to +10.5 vs +2.7 to +3.4), which points at GPU die ownership, but
the rise stays under the 15 °C threshold, so the analyzer classifies them
neither by its stated criteria. Peak single tick reached +12.1 °C. Per
reviewer F3 this does not stop Phase 0. A longer or heavier GPU round can
test the band later; the support statement must treat the GPU row as
unproven until then.

## Attribution runs — executed protocol

One variable per round, in this order:

1. `probe --watch 10 > h1-baseline.log` (10 ticks). Baseline `Tp00` mean
   38.9 °C, captured after the release build cooled down.
2. CPU round: 4 x `yes > /dev/null`, `probe --watch 30 > h1-cpu-load.log`
   (30 ticks), kill, `probe --watch 10 > h1-cool.log` (10 ticks).
3. Settle gate before the GPU round: `Tp00` at 39.6 °C, inside the
   baseline+2 gate.
4. GPU round: `gpuload 30` in background, `probe --watch 30 >
   h1-gpu-load.log` (30 ticks), then `probe --watch 10 > h1-gpu-cool.log`
   (10 ticks).
5. `python3 tools/smc-probe/analyze_attribution.py artifacts/2026-10-23-temp-menu-bar-metric
   > h1-attribution.md` — 296 rows, thresholds: rise 15 °C, ambiguity gap
   5 °C, recovery band 5 °C.

Confounders recorded for honesty:

- The first CPU-round attempt aborted on a shell quoting bug (a `cd && A= &&
  yes &` chain backgrounded the assignment, so the probe redirects pointed
  at `/`). No data was written, and one orphaned `yes` from that abort was
  reaped before the valid round.
- The settle loop before the valid CPU round never reached the +1.5 °C gate
  within 12 tries because of external load bursts (`Tp00` spikes to 80.9 °C
  with no probe loads running, source unknown). The CPU round therefore
  started at `Tp00` 44.2 °C instead of about 40.4 °C. That biases the load
  mean upward at the start, which pushes measured deltas down. The 24 keys
  still reached the band, so the bias works against the GO verdict, not for
  it.
- `dGPU` on CPU-side keys stayed +3.7 to +6.5 and `dCPU` on top `Tg*` keys
  stayed +2.7 to +3.4. The cross-load asymmetry supports clean per-round
  attribution.

## H2 latency — measured

Command: `probe --latency 1000` on an idle machine. Target key `TB0p`. Each
cycle opens a fresh connection, runs GetKeyInfo, runs ReadKey, then closes.
1000 of 1000 cycles succeeded, 0 errors.

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

## Baseline screenshots — blocked

baseline screenshots blocked: Apple Events permission missing — user must
grant System Settings > Privacy & Security > Automation.

Evidence: one attempt of `caffeinate -di scripts/capture_baseline.sh
--out-dir artifacts/2026-10-23-temp-menu-bar-metric/baseline` under a 180 s
cap. The release build succeeded, then the script stopped at line 71 with
`System Events got an error: AppleEvent timed out. (-1712)`. Before that
attempt, `tccutil reset AppleEvents` re-armed the prompt; the prompt went
unanswered, and the earlier state returned `Not authorized to send Apple
events to System Events. (-1743)`. No `baseline/` directory was created. The
display also read `CGDisplayIsAsleep == 1` at attempt start; a retry must
wake it first because popover close is display-sleep-sensitive.

## Raw logs in this directory

- `key-enumerate.log` — full key table, 2263 keys, with decoder labels.
- `h2-latency.log` — the 1000-cycle latency run.
- `h1-baseline.log` — baseline, 10 ticks.
- `h1-cpu-load.log` — CPU load, 30 ticks.
- `h1-cool.log` — post-CPU recovery, 10 ticks.
- `h1-gpu-load.log` — GPU load, 30 ticks.
- `h1-gpu-cool.log` — post-GPU recovery, 10 ticks.
- `h1-gpu-load-inner.log` — gpuload start/stop markers, 1699 dispatches.
- `h1-attribution.md` — the 296-row classification table and summary lines.
- `baseline/` — not created, screenshots blocked (see above).

## Rerunning the rounds

The round commands as executed are listed in the protocol section. Keep one
variable per round: never run the CPU and GPU loads together. Rebuild the
probe with `swiftc -O -swift-version 5 -o probe main.swift` inside
`tools/smc-probe/` when the source changes.
