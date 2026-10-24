//
//  MetricProcessSamplerTests.swift
//  StatsLiteTests
//
//  RED suite (plan 2026-10-23-top-processes-breakdown, T-A / G1):
//  MetricSamplerActor process-delta logic. CPU % from Mach-tick deltas
//  across two samples, PID-reuse rejection via startAbstime mismatch,
//  zombie skip (ri_proc_exit_abstime != 0), counter-rollback guard,
//  EPERM-vanished PIDs dropped, memory ranking by phys footprint over
//  total RAM, name-resolution cap (T7), failed-scan base retention,
//  and clearProcessBase (T5).
//
//  Every test fails against the RED stubs: sampleProcesses returns nil.
//

import Foundation
import XCTest
@testable import StatsLite

final class MetricProcessSamplerTests: XCTestCase {

    // MARK: - Helpers

    /// One raw sample with plan-T1 fields.
    private func raw(
        pid: Int32,
        ticks: UInt64,
        startAbstime: UInt64 = 1_000,
        exitAbstime: UInt64 = 0,
        footprint: UInt64 = 0,
        resident: UInt64 = 0
    ) -> RawProcessSample {
        RawProcessSample(
            pid: pid,
            cpuTicks: ticks,
            startAbstime: startAbstime,
            exitAbstime: exitAbstime,
            physFootprint: footprint,
            residentSize: resident
        )
    }

    /// Mach timebase nanoseconds per tick on this machine (T6 formula
    /// inputs come from the same system the sampler reads).
    private var nsPerTick: Double {
        var timebase = mach_timebase_info()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom)
    }

    private var totalRAM: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    /// Tick delta that reports `fraction` after exactly 1 s under
    /// the R1 percent-of-one-core basis (delta x timebase / elapsed
    /// ns, no core divisor — plan 2026-10-24 R1).
    private func ticks(forFraction fraction: Double, elapsedSeconds: Double = 1) -> UInt64 {
        UInt64((fraction * elapsedSeconds * 1e9) / nsPerTick)
    }

    private func makeSampler(
        _ samples: [RawProcessSample]...
    ) -> (MetricSamplerActor, FakeSystemMetricsProvider) {
        let provider = FakeSystemMetricsProvider()
        provider.processSamples = samples.first ?? []
        return (MetricSamplerActor(provider: provider), provider)
    }

    /// D1 contract (Appendix D item 2): a pass drops any candidate
    /// whose name never resolves. Fixture tests that expect published
    /// rows install names for their PIDs, in the same `Proc<pid>`
    /// shape the P11 union tests use. No assertion is relaxed.
    private func name(_ pids: Int32..., on provider: FakeSystemMetricsProvider) {
        for pid in pids {
            provider.processNames[pid] = "Proc\(pid)"
        }
    }

    // MARK: - P1: CPU % from Mach-tick deltas across two samples

    func testCPUPercentFromTickDeltaAcrossTwoSamples() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now
        let base: UInt64 = 10_000
        let delta = ticks(forFraction: 0.5)
        name(42, on: provider)

        provider.processSamples = [raw(pid: 42, ticks: base)]
        let first = await sampler.sampleProcesses(now: t0)
        let anchor = try XCTUnwrap(first, "P1: a good scan must produce a result")
        XCTAssertTrue(
            anchor.topCPU.isEmpty,
            "P1: the first scan anchors the CPU delta base and ranks memory only (R5)"
        )
        XCTAssertEqual(anchor.topMemory.count, 1, "P1: memory ranks on the first scan (R6)")

        provider.processSamples = [raw(pid: 42, ticks: base + delta)]
        let second = await sampler.sampleProcesses(now: t0.advanced(by: .seconds(1)))
        let item = try XCTUnwrap(
            second?.topCPU.first,
            "P1: the second scan publishes the CPU ranking"
        )
        XCTAssertEqual(item.pid, 42)
        XCTAssertEqual(item.fraction, 0.5, accuracy: 1e-6, "P1: delta x timebase / (1 s x cores)")
        XCTAssertEqual(item.valueLabel, "50.0%", "P1: CPU rows label as one-decimal percent")
    }

    // MARK: - P2: CPU fraction is percent-of-one-core (basis change,
    // plan 2026-10-24 R1)
    //
    // The original P2 asserted the old T6 contract: delta x timebase
    // / (elapsed ns x cores), clamped 0...1 — "full capacity". R1
    // removes the core-count divisor so rows match Activity Monitor
    // (percent-of-one-core, ≥100% allowed). The same 4 core-seconds
    // now report 4.0 → "400.0%". The P2 marker and test name are
    // kept; only the basis changed.

    func testCPUPercentClampsToFullCapacity() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now
        let base: UInt64 = 500
        name(7, on: provider)

        provider.processSamples = [raw(pid: 7, ticks: base)]
        _ = await sampler.sampleProcesses(now: t0)

        // Four core-seconds of work in one elapsed second: the R1
        // basis reports 4.0 (400.0%), never a full-capacity 1.0.
        provider.processSamples = [raw(pid: 7, ticks: base + self.ticks(forFraction: 4))]
        let second = await sampler.sampleProcesses(now: t0.advanced(by: .seconds(1)))
        let item = try XCTUnwrap(second?.topCPU.first, "P2: the second scan publishes")
        XCTAssertEqual(item.fraction, 4.0, accuracy: 1e-6, "P2: 4 core-seconds over 1 s report 4.0 (R1)")
        XCTAssertEqual(item.valueLabel, "400.0%", "P2: process rows label via processPercentTenth")

        // The display clamp sits at 9.999: 15 core-seconds label as
        // "999.9%", never wider (R1).
        provider.processSamples = [raw(pid: 7, ticks: base + self.ticks(forFraction: 15))]
        let third = await sampler.sampleProcesses(now: t0.advanced(by: .seconds(2)))
        let clamped = try XCTUnwrap(third?.topCPU.first, "P2: the third scan publishes")
        XCTAssertEqual(clamped.fraction, 9.999, accuracy: 1e-9, "P2: the fraction clamps at 9.999")
        XCTAssertEqual(clamped.valueLabel, "999.9%", "P2: the clamp labels as 999.9%")
    }

    // MARK: - P3: PID reuse rejected via startAbstime mismatch

    func testPIDReuseWithNewStartStampReanchorsInsteadOfDelta() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now

        // Scan 1 anchors pid 42 as the process that started at 1000.
        name(42, on: provider)
        provider.processSamples = [raw(pid: 42, ticks: 5_000, startAbstime: 1_000)]
        _ = await sampler.sampleProcesses(now: t0)

        // Scan 2: same PID, new start stamp, huge tick counter. A raw
        // delta against the stale anchor would report a spike; the
        // mismatch must force a fresh anchor and a zero this pass.
        provider.processSamples = [raw(pid: 42, ticks: 900_000, startAbstime: 2_000)]
        let reused = await sampler.sampleProcesses(now: t0.advanced(by: .seconds(1)))
        let reusedItem = try XCTUnwrap(
            reused?.topCPU.first,
            "P3: the recycled PID still appears in the list (R2, no threshold)"
        )
        XCTAssertEqual(
            reusedItem.fraction, 0.0, accuracy: 1e-12,
            "P3: a startAbstime mismatch re-anchors and reports 0, never a stale delta"
        )

        // Scan 3: the fresh anchor now yields a real delta.
        let delta = ticks(forFraction: 0.25)
        provider.processSamples = [raw(pid: 42, ticks: 900_000 + delta, startAbstime: 2_000)]
        let after = await sampler.sampleProcesses(now: t0.advanced(by: .seconds(2)))
        let item = try XCTUnwrap(after?.topCPU.first, "P3: the fresh anchor publishes")
        XCTAssertEqual(item.fraction, 0.25, accuracy: 1e-6, "P3: delta from the fresh anchor")
    }

    // MARK: - P4: zombie skip (ri_proc_exit_abstime != 0)

    func testZombieProcessesNeverEnterEitherRanking() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now
        let zombieFootprint = UInt64(3) * 1_073_741_824
        name(3, on: provider)

        let zombie = raw(
            pid: 99,
            ticks: 400_000,
            exitAbstime: 77, // != 0: the process exited (T6)
            footprint: zombieFootprint,
            resident: zombieFootprint
        )
        let live = raw(pid: 3, ticks: 1_000, footprint: 104_857_600, resident: 104_857_600)

        provider.processSamples = [zombie, live]
        let first = await sampler.sampleProcesses(now: t0)
        let anchor = try XCTUnwrap(first, "P4: a good scan must produce a result")
        XCTAssertEqual(
            anchor.topMemory.map(\.pid), [3],
            "P4: the zombie is skipped even with a 3 GB footprint"
        )

        let delta = ticks(forFraction: 0.1)
        provider.processSamples = [
            raw(pid: 99, ticks: 400_000 + delta, exitAbstime: 77, footprint: zombieFootprint),
            raw(pid: 3, ticks: 1_000 + delta, footprint: 104_857_600),
        ]
        let second = await sampler.sampleProcesses(now: t0.advanced(by: .seconds(1)))
        let result = try XCTUnwrap(second, "P4: a good scan must produce a result")
        XCTAssertEqual(
            result.topCPU.map(\.pid), [3],
            "P4: the zombie never enters the CPU ranking"
        )
        XCTAssertEqual(
            result.topMemory.map(\.pid), [3],
            "P4: the zombie never enters the memory ranking"
        )
    }

    // MARK: - P5: counter rollback re-anchors, no wrapped delta

    func testTickCounterRollbackReportsZeroAndReanchors() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now

        name(7, on: provider)
        provider.processSamples = [raw(pid: 7, ticks: 5_000, startAbstime: 99)]
        _ = await sampler.sampleProcesses(now: t0)

        // Rollback: the tick counter fell below the anchor with an
        // unchanged start stamp. A raw UInt64 subtraction would wrap.
        provider.processSamples = [raw(pid: 7, ticks: 100, startAbstime: 99)]
        let rollback = await sampler.sampleProcesses(now: t0.advanced(by: .seconds(1)))
        let rolled = try XCTUnwrap(rollback?.topCPU.first, "P5: the rollback scan still publishes")
        XCTAssertEqual(
            rolled.fraction, 0.0, accuracy: 1e-12,
            "P5: a rollback reports 0 and re-anchors, never a wrapped delta"
        )

        // The next scan measures from the re-anchor (100).
        let delta = ticks(forFraction: 0.5)
        provider.processSamples = [raw(pid: 7, ticks: 100 + delta, startAbstime: 99)]
        let after = await sampler.sampleProcesses(now: t0.advanced(by: .seconds(2)))
        let item = try XCTUnwrap(after?.topCPU.first, "P5: the re-anchored scan publishes")
        XCTAssertEqual(item.fraction, 0.5, accuracy: 1e-6, "P5: delta measured from the re-anchor")
    }

    // MARK: - P6: EPERM-vanished PIDs drop out, pid <= 0 skipped

    func testPIDVanishingFromScanDropsOutAndStaleEntriesNeverAppear() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now

        name(10, 20, on: provider)
        provider.processSamples = [
            raw(pid: 10, ticks: 1_000, footprint: 524_288_000),
            raw(pid: 20, ticks: 1_000, footprint: 1_048_576_000),
        ]
        _ = await sampler.sampleProcesses(now: t0)

        // pid 20's rusage read now fails with EPERM (or the process
        // exited): it disappears from the scan result and must drop
        // out of both rankings without an anchor leak.
        provider.processSamples = [
            raw(pid: 10, ticks: 1_000 + ticks(forFraction: 0.2), footprint: 524_288_000),
        ]
        let second = await sampler.sampleProcesses(now: t0.advanced(by: .seconds(1)))
        let result = try XCTUnwrap(second, "P6: a good scan must produce a result")
        XCTAssertEqual(result.topMemory.map(\.pid), [10], "P6: the vanished PID drops from memory")
        XCTAssertEqual(result.topCPU.map(\.pid), [10], "P6: the vanished PID drops from CPU")
    }

    func testNonPositivePIDsAreSkipped() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now

        name(5, on: provider)
        provider.processSamples = [
            raw(pid: 0, ticks: 1_000, footprint: 1_048_576_000),
            raw(pid: -1, ticks: 1_000, footprint: 1_048_576_000),
            raw(pid: 5, ticks: 1_000, footprint: 2_097_152_000),
        ]
        let first = await sampler.sampleProcesses(now: t0)
        let anchor = try XCTUnwrap(first, "P6: a good scan must produce a result")
        XCTAssertEqual(
            anchor.topMemory.map(\.pid), [5],
            "P6: pid <= 0 rows are skipped (T6 attribution rule)"
        )
    }

    // MARK: - P7: memory ranking by footprint, labels, RAM fraction

    func testMemoryRanksByPhysFootprintWithLabelsAndRAMFraction() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now
        let gib = UInt64(1_073_741_824)
        let mib = UInt64(1_048_576)

        let fixtures: [(Int32, UInt64)] = [
            (11, UInt64(6.8 * Double(gib))), // "6.8 GB"
            (12, 3 * gib),                   // "3.0 GB"
            (13, 780 * mib),                 // "780 MB"
            (14, 100 * mib),
            (15, 50 * mib),
            (16, 10 * mib),                  // 6th row: cut by the top-5 cap (VAC-8)
        ]
        provider.processSamples = fixtures.map {
            raw(pid: $0.0, ticks: 1_000, footprint: $0.1, resident: $0.1)
        }
        name(11, 12, 13, 14, 15, 16, on: provider)

        let first = await sampler.sampleProcesses(now: t0)
        let result = try XCTUnwrap(first, "P7: memory ranks on the first scan (R6)")
        XCTAssertEqual(result.topMemory.count, 5, "P7: at most 5 rows (VAC-8)")
        XCTAssertEqual(
            result.topMemory.map(\.pid), [11, 12, 13, 14, 15],
            "P7: descending by phys footprint, no blank slots"
        )

        let top = result.topMemory[0]
        XCTAssertEqual(top.valueLabel, "6.8 GB", "P7: GB label with one decimal")
        XCTAssertEqual(top.fraction, Double(6.8 * Double(gib)) / Double(totalRAM),
                       accuracy: 1e-6, "P7: fraction = footprint / total RAM (T6)")

        let small = result.topMemory[2]
        XCTAssertEqual(small.valueLabel, "780 MB", "P7: sub-GB footprints label as integer MB")
    }

    // MARK: - P8: memory falls back to resident size when footprint is 0

    func testMemoryFallsBackToResidentSizeWhenFootprintZero() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now
        let mib = UInt64(1_048_576)

        name(4, 6, on: provider)
        provider.processSamples = [
            raw(pid: 4, ticks: 900, footprint: 0, resident: 512 * mib),
            raw(pid: 6, ticks: 900, footprint: 0, resident: 128 * mib),
        ]
        let first = await sampler.sampleProcesses(now: t0)
        let result = try XCTUnwrap(first, "P8: a good scan must produce a result")
        let top = try XCTUnwrap(result.topMemory.first, "P8: the scan still ranks")
        XCTAssertEqual(top.pid, 4, "P8: ranking uses resident size when footprint is 0")
        XCTAssertEqual(top.valueLabel, "512 MB", "P8: fallback values label from resident size")
        XCTAssertEqual(top.fraction, Double(512 * mib) / Double(totalRAM), accuracy: 1e-6)
    }

    // MARK: - P9: failed scan returns nil and keeps the delta base

    func testFailedScanReturnsNilAndKeepsAnchor() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now
        let base: UInt64 = 2_000

        name(8, on: provider)
        provider.processSamples = [raw(pid: 8, ticks: base, footprint: 10 * 1_048_576)]
        _ = await sampler.sampleProcesses(now: t0)
        let readsAfterAnchor = provider.processSampleCount

        provider.processSamples = nil // the scan fails (T1 contract)
        let failed = await sampler.sampleProcesses(now: t0.advanced(by: .seconds(1)))
        XCTAssertNil(failed, "P9: a failed scan returns nil")
        XCTAssertEqual(provider.processSampleCount, readsAfterAnchor + 1)

        // The anchor from scan 1 survives the failed pass: the delta
        // spans 2 s, not 1 s.
        let delta = ticks(forFraction: 0.5, elapsedSeconds: 2)
        provider.processSamples = [raw(pid: 8, ticks: base + delta, footprint: 10 * 1_048_576)]
        let recovered = await sampler.sampleProcesses(now: t0.advanced(by: .seconds(2)))
        let item = try XCTUnwrap(
            recovered?.topCPU.first,
            "P9: the next good scan still has its predecessor"
        )
        XCTAssertEqual(
            item.fraction, 0.5, accuracy: 1e-6,
            "P9: the anchor spans the failed pass, no re-anchor drift"
        )
    }

    // MARK: - P10: clearProcessBase drops the delta base (T5)

    func testClearProcessBaseForcesAFreshAnchor() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now
        let base: UInt64 = 3_000

        name(8, on: provider)
        provider.processSamples = [raw(pid: 8, ticks: base, footprint: 10 * 1_048_576)]
        _ = await sampler.sampleProcesses(now: t0)

        await sampler.clearProcessBase()

        // Jumped ticks after a stop: with a stale base this would
        // publish a gap delta; a cleared base anchors again and keeps
        // the CPU list empty for one pass.
        provider.processSamples = [
            raw(pid: 8, ticks: base + ticks(forFraction: 1), footprint: 10 * 1_048_576),
        ]
        let after = await sampler.sampleProcesses(now: t0.advanced(by: .seconds(1)))
        let result = try XCTUnwrap(after, "P10: a good scan must produce a result")
        XCTAssertTrue(
            result.topCPU.isEmpty,
            "P10: clearProcessBase makes the next pass anchor instead of rating the gap (T5)"
        )
        XCTAssertEqual(result.topMemory.count, 1, "P10: memory still ranks on the anchor pass")
    }

    // MARK: - P11: union-of-both-lists name resolution (D1, Appendix D item 1/2)

    /// Twelve candidates whose tick deltas tie: CPU ranks by ascending
    /// PID (1...5) while footprints rank memory by descending PID
    /// (12...8). The two top-5 lists are disjoint, so the pre-fix
    /// `lookups < 8, resolved < 5` budget stops after the CPU five and
    /// the memory rows ship the `Process NNNNN` fallback — exactly the
    /// production starvation (§10 attribution, H1). Red against that
    /// code; green only when one pass resolves the union of both lists
    /// within 10 distinct lookups.
    private func unionFixtures() -> [RawProcessSample] {
        var fixtures: [RawProcessSample] = []
        for pid in Int32(1)...Int32(12) {
            fixtures.append(raw(pid: pid, ticks: 1_000, footprint: UInt64(pid) * 10 * 1_048_576))
        }
        return fixtures
    }

    /// Anchoring pass plus warm-up pass over `fixtures`, returning the
    /// warm-up result and the lookup delta of that pass. The first
    /// pass anchors the CPU base (R5); only the second publishes CPU
    /// rows.
    private func warmUpPass(
        fixtures: [RawProcessSample],
        sampler: MetricSamplerActor,
        provider: FakeSystemMetricsProvider,
        t0: ContinuousClock.Instant
    ) async throws -> (result: ProcessSampleResult, lookupsThisPass: Int) {
        provider.processSamples = fixtures
        _ = await sampler.sampleProcesses(now: t0)
        let lookupsAfterAnchor = provider.processNameLookupCount

        let delta = ticks(forFraction: 0.3)
        provider.processSamples = fixtures.map {
            RawProcessSample(
                pid: $0.pid,
                cpuTicks: $0.cpuTicks + delta,
                startAbstime: $0.startAbstime,
                exitAbstime: 0,
                physFootprint: $0.physFootprint,
                residentSize: $0.residentSize
            )
        }
        let second = await sampler.sampleProcesses(now: t0.advanced(by: .seconds(1)))
        let result = try XCTUnwrap(second, "P11: the warm-up scan publishes")
        return (result, provider.processNameLookupCount - lookupsAfterAnchor)
    }

    func testBothListsShipResolvedNamesWithinTenLookupsPerPass() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now
        let fixtures = unionFixtures()
        for pid in Int32(1)...Int32(12) {
            provider.processNames[pid] = "Proc\(pid)"
        }

        let (result, lookupsThisPass) = try await warmUpPass(
            fixtures: fixtures,
            sampler: sampler,
            provider: provider,
            t0: t0
        )

        XCTAssertLessThanOrEqual(
            lookupsThisPass, 10,
            "P11: one pass resolves at most the 10 distinct union candidates (Appendix D item 1)"
        )
        XCTAssertEqual(result.topCPU.count, 5, "P11: the CPU ranking fills 5 rows")
        XCTAssertEqual(result.topMemory.count, 5, "P11: the memory ranking fills 5 rows")
        for item in result.topCPU + result.topMemory {
            XCTAssertEqual(
                item.name, "Proc\(item.pid)",
                "P11: every row of BOTH lists ships its resolved name — the memory list must not starve (H1)"
            )
            XCTAssertFalse(
                item.name.hasPrefix("Process "),
                "P11: the Process NNNNN fallback never reaches a published row (VAC-B1)"
            )
        }
    }

    func testUnnamedCandidateDropsFromThatPassList() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now
        let fixtures = unionFixtures()
        // pid 12 tops the memory ranking but has no resolved name.
        for pid in Int32(1)...Int32(11) {
            provider.processNames[pid] = "Proc\(pid)"
        }

        let (result, _) = try await warmUpPass(
            fixtures: fixtures,
            sampler: sampler,
            provider: provider,
            t0: t0
        )

        XCTAssertEqual(
            result.topMemory.map(\.pid), [11, 10, 9, 8],
            "P11: the unnamed candidate drops from the pass, the rest shift up, no blank slot (Appendix D item 2)"
        )
        XCTAssertFalse(
            (result.topCPU + result.topMemory).contains { $0.name.hasPrefix("Process ") },
            "P11: a dropped row beats a Process NNNNN row (VAC-B1)"
        )
        for item in result.topCPU + result.topMemory {
            XCTAssertEqual(item.name, "Proc\(item.pid)")
        }
    }

    func testAllNameFailuresYieldEmptyLists() async throws {
        let (sampler, provider) = makeSampler()
        let t0 = ContinuousClock().now
        // No name table: every lookup fails.

        let (result, _) = try await warmUpPass(
            fixtures: unionFixtures(),
            sampler: sampler,
            provider: provider,
            t0: t0
        )

        XCTAssertTrue(
            result.topCPU.isEmpty,
            "P11: all-name-fail yields an empty CPU list — the section shows the R2b empty line, never fallback rows"
        )
        XCTAssertTrue(
            result.topMemory.isEmpty,
            "P11: all-name-fail yields an empty memory list"
        )
    }
}
