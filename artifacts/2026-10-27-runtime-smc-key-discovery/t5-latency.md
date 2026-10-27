# T5 — SMC key discovery latency (M5 Max Mac Studio)

Date: 2026-10-27. Machine: Apple M5 Max, macOS 27.0.1. Branch
`feat/2026-10-27-runtime-smc-key-discovery`, measurement commit on top
of T4 green `851f65e`.

## Method

Harness: `StatsLiteTests/SMCLatencyTests.swift`, an XCTest that runs
against the live `AppleSMCKeyEnumerator` on this machine. No production
code changed. The test times each operation with
`DispatchTime.now().uptimeNanoseconds` (the same clock
`tools/smc-probe/main.swift` uses) and reports nearest-rank
percentiles.

Command (four independent runs, all four recorded below):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project StatsLite.xcodeproj -scheme StatsLite \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .derivedData CODE_SIGN_IDENTITY=- \
  -only-testing:StatsLiteTests/SMCLatencyTests
```

The build is Debug (`-Onone`), the suite's configuration. Debug numbers
bound the shipped Release build from above for the Swift bookkeeping.
The SMC calls are kernel round trips, unaffected by optimization level.

Conditions: load average 3.5–11 during the runs (xcodebuild and
desktop use). Run 3 hit a unit bug in the budget threshold (0.1 ms
instead of 100 ms, see Budget below); its latency data is valid and is
included.

## Reference numbers

1. **Probe single-key cycle**: `artifacts/2026-10-23-temp-menu-bar-metric/h2-latency.log`
   — one `open → GetKeyInfo → Read → close` cycle, n=1000, key `TB0p`:
   p50 0.315 ms, **p99 0.964 ms**, mean 0.336 ms. This pays an
   `IOServiceOpen` and `IOServiceClose` on every cycle. The app's
   enumerator opens once and caches the connection, so the app's
   per-key cost must be lower than this reference.
2. **Sampler interval**: the standard loop sleeps `refreshInterval`
   between passes — `StatsLite/SystemMonitor.swift:50`
   (`var refreshInterval: TimeInterval = 1.0`, default 1 s), sleep at
   `SystemMonitor.swift:181-183`, preference picker offers 1, 2, 3, 5 s
   (`StatsLite/PreferencesStore.swift:74-75`). The temperature read
   runs inside one pass at `StatsLite/MetricSamplerActor.swift:68`.
   The fastest possible tick is **1000 ms**.

## Results — enumeration (one full discovery pass)

n=100 fresh runs per attempt (a fresh `AppleSMCKeyEnumerator` per run,
so the lazy connection open is inside the timing window; connection
close is outside it) and n=100 warm runs (one shared connection, pure
index/table build). Plan T5 asked for ≥30.

| run | fresh min | fresh p50 | fresh p99 | fresh max | warm p50 | warm p99 |
|-----|-----------|-----------|-----------|-----------|----------|----------|
| 1 | 6.35 ms | 6.83 ms | 10.38 ms | 11.08 ms | 6.69 ms | 8.40 ms |
| 2 | 6.19 ms | 6.60 ms | 7.41 ms | 7.51 ms | 6.66 ms | 7.00 ms |
| 3 | 6.55 ms | 6.88 ms | 7.61 ms | 7.68 ms | 6.65 ms | 7.31 ms |
| 4 | 5.99 ms | 6.26 ms | 7.45 ms | 9.48 ms | 6.57 ms | 7.31 ms |

Raw lines (`T5STAT`, µs converted to ms):

```text
run1 enum_fresh: min=6349 p50=6829 p99=10384 max=11080 mean=6995 n=100
run1 enum_warm:  min=6174 p50=6689 p99=8397  max=8783  mean=6846 n=100
run2 enum_fresh: min=6189 p50=6600 p99=7413  max=7506  mean=6651 n=100
run2 enum_warm:  min=6394 p50=6662 p99=6995  max=7026  mean=6663 n=100
run3 enum_fresh: min=6549 p50=6875 p99=7610  max=7675  mean=6919 n=100
run3 enum_warm:  min=6382 p50=6651 p99=7310  max=7356  mean=6679 n=100
run4 enum_fresh: min=5986 p50=6260 p99=7453  max=9475  mean=6372 n=100
run4 enum_warm:  min=6006 p50=6567 p99=7313  max=7361  mean=6599 n=100
```

**Enumeration p50 ≈ 6.3–6.9 ms, p99 ≈ 7.4–10.4 ms (fresh, includes
connection open).** The warm/cold gap is under 1 ms: connection open is
cheap; the 2263 `getKeyFromIndex` calls dominate.

## Results — per-sample cost (`sample()` over the cached table)

n=300 timed samples after 10 warm-up ticks, one discovery instance
(re plan T5: ≥200).

| run | min | p50 | p99 | max | mean |
|-----|-----|-----|-----|-----|------|
| 1 | 10.53 ms | 17.76 ms | 20.49 ms | 22.31 ms | 17.80 ms |
| 2 | 11.61 ms | 17.98 ms | 21.07 ms | 22.56 ms | 17.90 ms |
| 3 | 14.15 ms | 22.44 ms | 23.68 ms | 26.84 ms | 22.01 ms |
| 4 | 13.46 ms | 22.46 ms | 23.87 ms | 26.44 ms | 22.19 ms |

**Sample p50 ≈ 17.8–22.5 ms, p99 ≈ 20.5–23.9 ms.** Runs 3–4 sit ~24%
above runs 1–2; the machine load rose between the runs. The spread is
recorded rather than smoothed.

Raw lines:

```text
run1 sample: min=10529 p50=17764 p99=20493 max=22309 mean=17800 n=300
run2 sample: min=11607 p50=17984 p99=21071 max=22560 mean=17896 n=300
run3 sample: min=14145 p50=22435 p99=23683 max=26842 mean=22005 n=300
run4 sample: min=13463 p50=22458 p99=23872 max=26444 mean=22194 n=300
```

### SMC calls one sample performs

Counted with a counting wrapper enumerator, one tick after warm-up
(same result in every run):

```text
cached_keys=107  readkey/tick=107  getkeyinfo/tick=107
enum_calls/tick=0   (keyCount + keyName + keyInfo = 0)
```

One `sample()` performs **214 SMC calls: 107 `ReadKey` + 107
`GetKeyInfo`** — one `readFloat` per cached key, and `readFloat` does
GetKeyInfo-then-ReadKey (`StatsLite/SMCKeyDiscovery.swift`,
`AppleSMCKeyEnumerator.readFloat`). Enumeration calls per tick are
zero, so FM4 holds on live hardware, not only on the fake enumerator.

Build side, for the record: `keyCount` ×1, `keyName` ×2263,
`keyInfo` ×107 (only prefix-matching names reach `keyInfo`).

### Key counts (this machine)

| count | value | source |
|-------|-------|--------|
| Full SMC key table (`#KEY`) | 2263 | live enumerator |
| CPU keys (`Tp*`, `flt `/4) | 23 | live table build |
| GPU keys (`Tg*`, `flt `/4) | 84 | live table build |
| Cached keys read per sample | 107 | 23 + 84 |

The plan's "296 keys" fixture count is the probe's *temperature-plausible*
set (T-prefix + temperature type family), printed by `watch` mode as
`keys=296` (`tools/smc-probe/main.swift:434`). It is not the full key
table. The full table is 2263. No conflict.

## Cross-check against the references

- **vs the probe cycle (h2, p99 0.964 ms per key with open/close):**
  the app reads 107 keys in p99 20.5–23.9 ms, that is ~0.19–0.22 ms per
  key over a cached connection, ~4.5× cheaper per key than the
  open/close cycle. The cache decision (plan Decision 6) shows its
  value here.
- **vs the 1000 ms tick:** sample p99 23.9 ms is **2.4%** of the
  fastest tick the app offers. Even the worst observed sample (26.8 ms)
  is 2.7%. The sampler sleeps the remainder; no cadence pressure.

## Budget assertion

**Added.** `SMCLatencyTests.testMeasurePerSampleCost` asserts the
per-sample p99 < 100 ms.

Basis:

- Measured p99 across four runs: 20.5, 21.1, 23.7, 23.9 ms. The
  threshold is a **4.2× margin** over the worst measured p99, wide
  enough to absorb the observed load-driven 24% run-to-run spread.
- The threshold is also 10% of the fastest sampler tick (1000 ms), so
  a regression that reaches it is a regression that matters: the
  temperature read would consume a tenth of the whole pass.
- Negative check: run 3 used a wrong constant (100_000 ns = 0.1 ms)
  and the assertion failed with `23683334 is not less than 100000`.
  The assertion is live, not vacuous.

No enumeration-time budget was added. Enumeration runs once per launch
(FM4 call-count assertions pin that), and a wall-time bound on it would
measure machine speed, not our code. The FM4 zero-calls-per-tick
assertion is the guard that matters.

## Verdict

- **Enumeration is safe off the hot path (FM4):** one pass costs
  p50 ≈ 6.9 ms / p99 ≈ 10.4 ms worst case, runs exactly once per
  launch, and performs zero enumeration calls during any sample
  (asserted live). A one-time ~10 ms first-sample cost against a
  1000 ms tick is negligible.
- **Per-sample cost is within budget:** p99 ≈ 23.9 ms worst observed =
  2.4% of the fastest 1000 ms tick, ~4.5× cheaper per key than the
  probe's open/close reference. The 100 ms budget assertion (4.2×
  measured margin) now guards it.
