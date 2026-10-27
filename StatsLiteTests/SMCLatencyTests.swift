//
//  SMCLatencyTests.swift
//  StatsLiteTests
//
//  T5 latency measurement (plan 2026-10-27-runtime-smc-key-discovery):
//  wall time of one full discovery pass (index/table build through
//  the live AppleSMCKeyEnumerator) and wall time of `sample()` over
//  the cached table, on this machine. The printed `T5LAT` lines are
//  the raw evidence recorded in
//  artifacts/2026-10-27-runtime-smc-key-discovery/t5-latency.md.
//
//  Method: DispatchTime wall clock around each operation (same clock
//  as tools/smc-probe/main.swift), nearest-rank percentiles, Debug
//  test build — the suite's configuration, so the numbers bound the
//  shipped build from above. Key counts are reported, not asserted to
//  exact values: the suite must stay runnable on other machines (T8
//  field check on the Air). A budget assertion lives here only if the
//  measured numbers establish a defensible threshold; the decision
//  and its basis are recorded in the artifact.
//

import Dispatch
import Foundation
import XCTest
@testable import StatsLite

// MARK: - Counting enumerator

/// Live enumerator wrapper that counts seam calls, so one sample's
/// SMC traffic is evidence rather than an estimate.
private final class CountingSMCEnumerator: SMCKeyEnumerating, @unchecked Sendable {
    private let base = AppleSMCKeyEnumerator()
    private let lock = NSLock()
    private(set) var keyCountCalls = 0
    private(set) var keyNameCalls = 0
    private(set) var keyInfoCalls = 0
    private(set) var readFloatCalls = 0

    func keyCount() -> UInt32? {
        lock.lock()
        defer { lock.unlock() }
        keyCountCalls += 1
        return base.keyCount()
    }

    func keyName(at index: UInt32) -> String? {
        lock.lock()
        defer { lock.unlock() }
        keyNameCalls += 1
        return base.keyName(at: index)
    }

    func keyInfo(name: String) -> (type: String, size: UInt32)? {
        lock.lock()
        defer { lock.unlock() }
        keyInfoCalls += 1
        return base.keyInfo(name: name)
    }

    func readFloat(name: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        readFloatCalls += 1
        return base.readFloat(name: name)
    }

    /// Zero every counter. Call between the warm-up and the counted
    /// operation.
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        keyCountCalls = 0
        keyNameCalls = 0
        keyInfoCalls = 0
        readFloatCalls = 0
    }
}

// MARK: - Measurement

final class SMCLatencyTests: XCTestCase {

    // MARK: Harness

    /// Wall-clock nanoseconds for one operation.
    private func timedNanos(_ body: () -> Void) -> UInt64 {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        return DispatchTime.now().uptimeNanoseconds &- start
    }

    /// Nearest-rank percentile over sorted nanosecond samples (the
    /// helper pattern from tools/smc-probe/main.swift).
    private func percentile(_ sorted: [UInt64], _ p: Double) -> UInt64 {
        guard !sorted.isEmpty else { return 0 }
        let rank = Int(ceil(p * Double(sorted.count)))
        let index = min(max(rank - 1, 0), sorted.count - 1)
        return sorted[index]
    }

    /// One machine-readable report line plus its human-readable
    /// counterpart, both flushed so a captured xcodebuild log carries
    /// the numbers even if the run dies later.
    private func report(_ label: String, _ samples: [UInt64], extra: String = "") {
        guard !samples.isEmpty else { return }
        let sorted = samples.sorted()
        let lowest = sorted[0]
        let highest = sorted[sorted.count - 1]
        let mean = samples.reduce(0, +) / UInt64(samples.count)
        func us(_ value: UInt64) -> String { String(value / 1000) }
        let suffix = extra.isEmpty ? "" : " " + extra
        let line =
            "T5LAT \(label) runs=\(samples.count)" +
            " min_us=\(us(lowest)) p50_us=\(us(percentile(sorted, 0.50)))" +
            " p99_us=\(us(percentile(sorted, 0.99))) max_us=\(us(highest))" +
            " mean_us=\(us(mean))\(suffix)"
        print(line)
        print(
            "T5STAT \(label): min=\(us(lowest)) µs  p50=\(us(percentile(sorted, 0.50))) µs" +
            "  p99=\(us(percentile(sorted, 0.99))) µs  max=\(us(highest)) µs" +
            "  mean=\(us(mean)) µs  n=\(samples.count)\(suffix)"
        )
        fflush(stdout)
    }

    // MARK: Enumeration cost (plan T5, FM4)

    /// One full discovery pass per run: lazy connection open plus the
    /// `#KEY` index scan and the table build, through the live
    /// `AppleSMCKeyEnumerator`. 100 fresh runs (plan asks for at
    /// least 30) build and drop their own enumerator, connection
    /// close excluded (it happens after the timing window, at scope
    /// end). 100 warm runs reuse one connection, so the fresh-warm
    /// gap isolates the open cost.
    func testMeasureEnumerationCost() {
        let runs = 100
        var fresh: [UInt64] = []
        var cpu = 0
        var gpu = 0
        var smcCount = 0

        for _ in 0..<runs {
            let enumerator = AppleSMCKeyEnumerator()
            var built: TemperatureKeyDiscovery?
            let elapsed = timedNanos {
                built = TemperatureKeyDiscovery(enumerator: enumerator)
            }
            fresh.append(elapsed)
            if let discovery = built {
                cpu = discovery.keyTable.cpuKeys.count
                gpu = discovery.keyTable.gpuKeys.count
                smcCount = Int(enumerator.keyCount() ?? 0)
            }
            // Drop the discovery outside the timing window so the
            // connection close never lands inside a sample.
            built = nil
        }
        report(
            "enumeration_fresh",
            fresh,
            extra: "cpu_keys=\(cpu) gpu_keys=\(gpu) smc_key_count=\(smcCount)"
        )

        let shared = AppleSMCKeyEnumerator()
        _ = TemperatureKeyDiscovery(enumerator: shared) // warm the connection
        var warm: [UInt64] = []
        for _ in 0..<runs {
            warm.append(timedNanos { _ = TemperatureKeyDiscovery(enumerator: shared) })
        }
        report("enumeration_warm", warm)

        XCTAssertGreaterThan(
            cpu + gpu,
            0,
            "sanity: this machine exposes at least one temperature key"
        )
    }

    // MARK: Per-sample cost (plan T5, FM4)

    /// `sample()` over the cached table: 10 warm-up ticks, then 300
    /// timed ticks (plan asks for at least 200). A second discovery
    /// behind the counting wrapper reports the SMC calls one tick
    /// performs and proves, on live hardware, that enumeration stays
    /// off the sample path.
    func testMeasurePerSampleCost() {
        let enumerator = AppleSMCKeyEnumerator()
        let discovery = TemperatureKeyDiscovery(enumerator: enumerator)
        let cached =
            discovery.keyTable.cpuKeys.count + discovery.keyTable.gpuKeys.count
        XCTAssertGreaterThan(
            cached, 0, "sanity: the cached table has keys on this machine"
        )

        for _ in 0..<10 {
            _ = discovery.sample()
        }

        var samples: [UInt64] = []
        for _ in 0..<300 {
            samples.append(timedNanos { _ = discovery.sample() })
        }
        report(
            "sample",
            samples,
            extra:
                "cpu_keys=\(discovery.keyTable.cpuKeys.count)" +
                " gpu_keys=\(discovery.keyTable.gpuKeys.count)" +
                " cached_keys=\(cached)"
        )

        // Budget (plan T5): the per-sample p99 must stay under
        // 100 ms. Basis: four measured runs on this M5 Max put the
        // p99 at 20.5, 21.1, 23.7, and 23.9 ms (artifact
        // t5-latency.md), so the threshold carries a 4.2x margin
        // over the worst run; it also caps one temperature sample
        // at 10% of the fastest sampler tick the app offers (1 s,
        // SystemMonitor.swift:50, PreferencesStore.swift:74-75).
        // The margin absorbs the observed 24% load-driven spread
        // and any slower machine the suite has not measured yet
        // (T8).
        let sortedSamples = samples.sorted()
        let sampleP99 = percentile(sortedSamples, 0.99)
        XCTAssertLessThan(
            sampleP99,
            100_000_000, // 100 ms in nanoseconds
            "per-sample p99 must stay under 100 ms (budget: 10% of the 1 s tick; measured 21 ms, artifact t5-latency.md)"
        )

        // Counted tick: exact SMC traffic of one sample.
        let counting = CountingSMCEnumerator()
        let counted = TemperatureKeyDiscovery(enumerator: counting)
        _ = counted.sample()
        let initKeyCountCalls = counting.keyCountCalls
        let initKeyNameCalls = counting.keyNameCalls
        let initKeyInfoCalls = counting.keyInfoCalls
        let countedCached =
            counted.keyTable.cpuKeys.count + counted.keyTable.gpuKeys.count
        counting.reset()
        _ = counted.sample()

        // One readFloat is one GetKeyInfo plus one ReadKey on the wire
        // (AppleSMCKeyEnumerator.readFloat), so readFloatCalls equals
        // the ReadKey count of the tick.
        let tick = "T5LAT sample_calls cached_keys=\(countedCached)" +
            " readkey_per_sample=\(counting.readFloatCalls)" +
            " getkeyinfo_per_sample=\(counting.readFloatCalls)" +
            " enum_keycount=\(counting.keyCountCalls)" +
            " enum_keyname=\(counting.keyNameCalls)" +
            " enum_keyinfo=\(counting.keyInfoCalls)"
        print(tick)
        print(
            "T5STAT sample_calls: cached_keys=\(countedCached)" +
            " readkey/tick=\(counting.readFloatCalls)" +
            " getkeyinfo/tick=\(counting.readFloatCalls)" +
            " (plus 2 per-key calls inside each readFloat: 2×\(counting.readFloatCalls) SMC calls total)" +
            " enum_calls/tick=\(counting.keyCountCalls + counting.keyNameCalls + counting.keyInfoCalls)" +
            " | build: keycount=\(initKeyCountCalls) keyname=\(initKeyNameCalls)" +
            " keyinfo=\(initKeyInfoCalls)"
        )
        fflush(stdout)

        XCTAssertEqual(
            counting.readFloatCalls,
            countedCached,
            "one sample reads exactly the cached table keys (FM4)"
        )
        XCTAssertEqual(
            counting.keyCountCalls + counting.keyNameCalls + counting.keyInfoCalls,
            0,
            "no enumeration call runs during a sample, live (FM4)"
        )
    }
}
