//
//  RuntimeSMCKeyDiscoveryTests.swift
//  StatsLiteTests
//
//  RED suite (plan 2026-10-27-runtime-smc-key-discovery, T3): runtime
//  SMC key discovery. One binary test per failure mode, FM1-FM5. The
//  seam API in the contract below does not exist yet — the build
//  failure is the red (same practice as the 2026-10-23 T2 red,
//  commit 667b04a). Do not weaken these tests in green.
//
//  FM6 (M5 Max regression, live CPU+GPU rows) is not duplicated here:
//  SystemMetricsProviderContractTests.
//  testLiveProviderReadsTemperatureOnThisMachine pins the live CPU
//  read on this machine, and MenuBarTempBlockTests.
//  testTempRowsRenderPerSubsystemDegreesWithRowPlaceholders pins the
//  row matrix. Both must stay green after T4.
//
//  Contract the green implementation (T4) must match:
//
//  - `struct SMCKeyDescriptor { name: String, type: String,
//    size: UInt32 }` — one enumerated SMC key's identity and
//    GetKeyInfo result.
//
//  - `protocol SMCKeyEnumerating: Sendable` — the enumeration/read
//    seam over the AppleSMC user client:
//      - `func keyCount() -> UInt32?` — the `#KEY` key count. nil
//        when `#KEY` is unreadable.
//      - `func keyName(at index: UInt32) -> String?` — the key name
//        at one enumeration index. nil when the read fails.
//      - `func keyInfo(name: String) -> (type: String, size: UInt32)?`
//        — type and size for one key. nil when the read fails.
//      - `func readFloat(name: String) -> Double?` — one decoded
//        `flt ` value. nil when the read fails. Plausibility
//        (finite, −20...130 °C) is NOT the reader's job: the
//        discovery filter applies it, so a fixture can feed a raw
//        out-of-range decode and the filter must drop it.
//
//  - `enum TemperatureDomain { case cpu, case gpu }` plus the one
//    attribution seam `func domain(forPrefix prefix: String) ->
//    TemperatureDomain?`: exact, case-sensitive, two-character
//    prefixes only — "Tg" → .gpu, "Tp" → .cpu, everything else nil
//    ("TG", "tp", "TVD", "Tm", "T", "" → nil).
//
//  - `struct TemperatureKeyTable { let cpuKeys: [String];
//    let gpuKeys: [String]; init(enumerator: SMCKeyEnumerating) }` —
//    the cached table, built once per launch. init enumerates via
//    keyCount/keyName; when `#KEY` is unreadable it falls back to
//    the consecutive-failure index scan (pattern:
//    tools/smc-probe/main.swift:325). It keeps only keys with type
//    "flt " and size 4, grouped by the two-character prefix through
//    `domain(forPrefix:)`.
//
//  - `final class TemperatureKeyDiscovery` — the per-launch
//    discovery state:
//      - `let keyTable: TemperatureKeyTable` — the cached table
//        built at init; exposed so FM4 can prove enumeration stays
//        off the sample path.
//      - `init(enumerator: SMCKeyEnumerating)` — enumeration runs
//        exactly once, here.
//      - `func sample() -> TemperatureMetrics?` — one sampler tick.
//        Reads only the cached table keys via readFloat, applies
//        the plausibility filter per reading (finite, −20...130),
//        keeps a trailing 60-tick series per key, and aggregates
//        per domain: once any key in a domain has moved ≥ 2 °C
//        within its trailing 60 ticks, only moved keys feed the
//        domain max; until then every prefix+plausibility key feeds
//        it, so a working machine never renders blank by
//        construction. Returns nil when neither domain has a
//        plausible reading this tick (nil contract).
//

import Foundation
import XCTest
@testable import StatsLite

// MARK: - Fixtures

/// One fixture key. Defaults model the Apple Silicon `flt ` family:
/// type "flt ", size 4, unless a plausibility test overrides them.
struct FakeSMCKey: Equatable {
    var name: String
    var type: String = "flt "
    var size: UInt32 = 4
    var value: Double

    init(name: String, type: String = "flt ", size: UInt32 = 4, value: Double) {
        self.name = name
        self.type = type
        self.size = size
        self.value = value
    }
}

/// Fixture enumerator over a fixed key list. Call counters separate
/// enumeration (keyCount/keyName/keyInfo) from per-sample reads
/// (readFloat), so FM4 can prove enumeration never runs per sample.
final class FakeSMCKeyEnumerator: SMCKeyEnumerating, @unchecked Sendable {
    private(set) var keys: [FakeSMCKey]
    /// nil simulates an unreadable `#KEY`.
    var keyCountResult: UInt32?
    /// false simulates an unreadable index scan (every keyName fails).
    var indexNamesReadable: Bool

    private(set) var keyCountCalls = 0
    private(set) var keyNameCalls = 0
    private(set) var keyInfoCalls = 0
    private(set) var readFloatCalls = 0

    /// Every call that belongs to enumeration, the launch-time cost.
    var enumerationCallCount: Int {
        keyCountCalls + keyNameCalls + keyInfoCalls
    }

    init(
        keys: [FakeSMCKey],
        keyCountReadable: Bool = true,
        indexNamesReadable: Bool = true
    ) {
        self.keys = keys
        self.keyCountResult = keyCountReadable ? UInt32(keys.count) : nil
        self.indexNamesReadable = indexNamesReadable
    }

    func keyCount() -> UInt32? {
        keyCountCalls += 1
        return keyCountResult
    }

    func keyName(at index: UInt32) -> String? {
        keyNameCalls += 1
        guard indexNamesReadable, index < keys.count else { return nil }
        return keys[Int(index)].name
    }

    func keyInfo(name: String) -> (type: String, size: UInt32)? {
        keyInfoCalls += 1
        guard let key = keys.first(where: { $0.name == name }) else { return nil }
        return (key.type, key.size)
    }

    func readFloat(name: String) -> Double? {
        readFloatCalls += 1
        return keys.first(where: { $0.name == name })?.value
    }

    /// FM3b fixture hook: change one key's decoded value between
    /// ticks (movement filter tests).
    func setValue(_ value: Double, for name: String) {
        guard let index = keys.firstIndex(where: { $0.name == name }) else { return }
        keys[index].value = value
    }
}

enum SMCKeysFixtures {
    /// M5 Max Mac Studio representative key set, derived from the
    /// h1-baseline.log tick-1 readings
    /// (artifacts/2026-10-23-temp-menu-bar-metric/h1-baseline.log).
    /// TRUNCATION NOTE: the full measured set is 296 keys (the
    /// `# columns:` line of that log); this fixture keeps 17 keys
    /// across the Tg, Tp, TVD, Tm, TRD, TUD, Tf, and Tz families —
    /// enough for every filter and attribution path these tests pin.
    static let m5MaxSubset: [FakeSMCKey] = [
        FakeSMCKey(name: "Tg6I", value: 38.4),
        FakeSMCKey(name: "Tg76", value: 38.4),
        FakeSMCKey(name: "Tg5R", value: 38.3),
        FakeSMCKey(name: "Tg4e", value: 38.3),
        FakeSMCKey(name: "Tg4h", value: 38.3),
        FakeSMCKey(name: "Tg0U", value: 38.1),
        FakeSMCKey(name: "Tg1x", value: 39.3),
        FakeSMCKey(name: "Tp00", value: 40.5),
        FakeSMCKey(name: "Tp0C", value: 39.9),
        FakeSMCKey(name: "Tp0X", value: 39.5),
        FakeSMCKey(name: "Tp0u", value: 39.2),
        FakeSMCKey(name: "TVD0", value: 50.8),
        FakeSMCKey(name: "TVDC", value: 48.8),
        FakeSMCKey(name: "Tm0y", value: 39.0),
        FakeSMCKey(name: "TRD0", value: 36.8),
        FakeSMCKey(name: "TUD0", value: 36.5),
        FakeSMCKey(name: "Tf06", value: 73.7),
        FakeSMCKey(name: "Tz11", value: 0.0),
    ]

    /// The M5 Max subset with every Tg key removed: a machine whose
    /// GPU attribution fails (FM1).
    static var m5MaxNoGPU: [FakeSMCKey] {
        m5MaxSubset.filter { !$0.name.hasPrefix("Tg") }
    }

    /// Second-generation `Tg` set from the M1/M2 community prior
    /// (exelban/stats#1012). PRIOR FIXTURE, NOT EVIDENCE: these key
    /// names were never measured on any machine this repo can
    /// reach; they exist so discovery is testable against a key set
    /// that no hardcoded list could cover.
    static let secondGenerationPrior: [FakeSMCKey] = [
        FakeSMCKey(name: "Tg0U", value: 41.5),
        FakeSMCKey(name: "Tg0X", value: 41.6),
        FakeSMCKey(name: "Tg0d", value: 41.4),
        FakeSMCKey(name: "Tg0g", value: 41.7),
        FakeSMCKey(name: "Tg0j", value: 41.3),
        FakeSMCKey(name: "Tg1Y", value: 41.8),
        FakeSMCKey(name: "Tg1c", value: 41.2),
        FakeSMCKey(name: "Tg1g", value: 41.9),
    ]
}

// MARK: - Tests

final class RuntimeSMCKeyDiscoveryTests: XCTestCase {

    // MARK: FM1 — nil member renders "--°", never "0°"

    /// A machine where GPU attribution fails keeps the GPU row nil
    /// and the CPU row live. The placeholder is "--°", never a fake
    /// 0° reading.
    func testMachineWithoutGPUKeysKeepsGPURowPlaceholder() {
        let discovery = TemperatureKeyDiscovery(
            enumerator: FakeSMCKeyEnumerator(keys: SMCKeysFixtures.m5MaxNoGPU)
        )

        let metrics = discovery.sample()

        XCTAssertEqual(
            metrics?.cpuCelsius,
            40.5,
            "the CPU row reads the hottest plausible Tp key"
        )
        XCTAssertNil(
            metrics?.gpuCelsius,
            "a failed GPU attribution must stay nil, never 0"
        )
        XCTAssertEqual(
            MetricFormatters.degrees(metrics?.gpuCelsius),
            "--°",
            "a nil GPU member renders '--°'"
        )
        XCTAssertFalse(
            MetricFormatters.degrees(metrics?.gpuCelsius).contains("0°"),
            "never a fake 0° reading on the GPU row"
        )
    }

    // MARK: FM2 — unreadable `#KEY` falls back to the index scan

    /// When `#KEY` is unreadable, the consecutive-failure index scan
    /// recovers enumeration and the table matches the `#KEY` path.
    func testUnreadableKeyCountFallsBackToIndexScan() {
        let keys = SMCKeysFixtures.m5MaxSubset
        let viaKeyCount = TemperatureKeyDiscovery(
            enumerator: FakeSMCKeyEnumerator(keys: keys, keyCountReadable: true)
        )
        let viaIndexScan = TemperatureKeyDiscovery(
            enumerator: FakeSMCKeyEnumerator(keys: keys, keyCountReadable: false)
        )

        XCTAssertEqual(
            viaIndexScan.keyTable.cpuKeys,
            viaKeyCount.keyTable.cpuKeys,
            "the index-scan fallback must recover the same CPU keys as the #KEY path"
        )
        XCTAssertEqual(
            viaIndexScan.keyTable.gpuKeys,
            viaKeyCount.keyTable.gpuKeys,
            "the index-scan fallback must recover the same GPU keys as the #KEY path"
        )
        XCTAssertFalse(viaKeyCount.keyTable.gpuKeys.isEmpty, "sanity: the fixture has Tg keys")
    }

    /// When `#KEY` is unreadable AND the index scan fails, the table
    /// is empty, the sample returns nil, and both rows render the
    /// placeholder.
    func testEnumerationTotalFailureRendersBothRowsPlaceholder() {
        let discovery = TemperatureKeyDiscovery(
            enumerator: FakeSMCKeyEnumerator(
                keys: SMCKeysFixtures.m5MaxSubset,
                keyCountReadable: false,
                indexNamesReadable: false
            )
        )

        XCTAssertTrue(discovery.keyTable.cpuKeys.isEmpty, "no keys survived enumeration")
        XCTAssertTrue(discovery.keyTable.gpuKeys.isEmpty, "no keys survived enumeration")

        let metrics = discovery.sample()
        XCTAssertNil(metrics, "no plausible reading at all returns nil")
        XCTAssertEqual(
            MetricFormatters.degrees(Double?.none),
            "--°",
            "a nil sample renders '--°' on the CPU row"
        )
        XCTAssertEqual(
            MetricFormatters.degrees(Double?.none),
            "--°",
            "a nil sample renders '--°' on the GPU row"
        )
    }

    // MARK: FM3(a) — prefix filter, exact and case-sensitive

    /// `domain(forPrefix:)` attributes the exact two-character
    /// prefixes only. Case matters; rail and other families stay
    /// unattributed.
    func testDomainResolverIsExactAndCaseSensitive() {
        XCTAssertEqual(domain(forPrefix: "Tg"), .gpu)
        XCTAssertEqual(domain(forPrefix: "Tp"), .cpu)
        XCTAssertNil(domain(forPrefix: "TG"), "uppercase G is not the GPU family")
        XCTAssertNil(domain(forPrefix: "tp"), "lowercase p is not the CPU family")
        XCTAssertNil(domain(forPrefix: "TVD"), "rail keys stay out of both domains")
        XCTAssertNil(domain(forPrefix: "Tm"), "unattributed family")
        XCTAssertNil(domain(forPrefix: "T"), "a one-character prefix attributes nothing")
        XCTAssertNil(domain(forPrefix: ""), "an empty prefix attributes nothing")
        XCTAssertNil(domain(forPrefix: "Tgx"), "the prefix is exactly two characters")
    }

    /// The cached table keeps only exact-case Tg/Tp keys. TVD, Tm,
    /// TRD, TUD, Tf, Tz, and wrong-case lookalikes never enter.
    func testPrefixFilterKeepsOnlyTgAndTpKeys() {
        var keys = SMCKeysFixtures.m5MaxSubset
        keys.append(FakeSMCKey(name: "TG01", value: 90.0))
        keys.append(FakeSMCKey(name: "tp01", value: 90.0))
        let discovery = TemperatureKeyDiscovery(
            enumerator: FakeSMCKeyEnumerator(keys: keys)
        )

        XCTAssertEqual(
            Set(discovery.keyTable.gpuKeys),
            ["Tg6I", "Tg76", "Tg5R", "Tg4e", "Tg4h", "Tg0U", "Tg1x"],
            "only exact-case Tg keys join the GPU table"
        )
        XCTAssertEqual(
            Set(discovery.keyTable.cpuKeys),
            ["Tp00", "Tp0C", "Tp0X", "Tp0u"],
            "only exact-case Tp keys join the CPU table"
        )
        XCTAssertFalse(discovery.keyTable.cpuKeys.contains("TVD0"))
        XCTAssertFalse(discovery.keyTable.cpuKeys.contains("Tm0y"))
        XCTAssertFalse(discovery.keyTable.gpuKeys.contains("TG01"))
        XCTAssertFalse(discovery.keyTable.cpuKeys.contains("tp01"))
    }

    /// The discovery path is not hardcoded to the M5 Max key set: a
    /// second-generation machine whose SMC exposes only the
    /// community-prior Tg set still produces a GPU row.
    func testSecondGenerationPriorKeySetProducesGPUReading() {
        let discovery = TemperatureKeyDiscovery(
            enumerator: FakeSMCKeyEnumerator(keys: SMCKeysFixtures.secondGenerationPrior)
        )

        XCTAssertEqual(
            Set(discovery.keyTable.gpuKeys),
            ["Tg0U", "Tg0X", "Tg0d", "Tg0g", "Tg0j", "Tg1Y", "Tg1c", "Tg1g"],
            "enumeration finds every prior-fixture Tg key, including Tg1g"
        )
        XCTAssertEqual(
            discovery.sample()?.gpuCelsius,
            41.9,
            "the GPU row reads the hottest prior-fixture key (Tg1g)"
        )
        XCTAssertTrue(
            discovery.keyTable.cpuKeys.isEmpty,
            "the prior fixture exposes no Tp keys, so the CPU table is empty"
        )
    }

    // MARK: FM3(b) — plausibility filter

    /// Only `flt ` keys of size 4 survive the table build. Wrong
    /// types and sizes drop, including the Intel fixed-point
    /// families the decoder never accepts.
    func testPlausibilityFilterKeepsOnlyFltSizeFourKeys() {
        let keys = [
            FakeSMCKey(name: "Tg01", value: 40.0),
            FakeSMCKey(name: "Tg02", type: "ui16", size: 2, value: 40.0),
            FakeSMCKey(name: "Tg03", type: "sp78", size: 2, value: 40.0),
            FakeSMCKey(name: "Tg04", type: "flt ", size: 2, value: 40.0),
            FakeSMCKey(name: "Tp01", value: 50.0),
        ]
        let discovery = TemperatureKeyDiscovery(
            enumerator: FakeSMCKeyEnumerator(keys: keys)
        )

        XCTAssertEqual(discovery.keyTable.gpuKeys, ["Tg01"], "only flt /4 Tg keys survive")
        XCTAssertEqual(discovery.keyTable.cpuKeys, ["Tp01"], "only flt /4 Tp keys survive")
    }

    /// Per-reading plausibility: non-finite and out-of-range
    /// decodes drop for that tick. Boundary values −20 and 130 stay.
    func testImplausibleReadingsNeverReachTheAggregate() {
        let enumerator = FakeSMCKeyEnumerator(keys: [
            FakeSMCKey(name: "Tg01", value: .nan),
            FakeSMCKey(name: "Tg02", value: 200.0),
            FakeSMCKey(name: "Tg03", value: 130.0),
            FakeSMCKey(name: "Tp01", value: -40.0),
            FakeSMCKey(name: "Tp02", value: -20.0),
        ])
        let discovery = TemperatureKeyDiscovery(enumerator: enumerator)

        let metrics = discovery.sample()

        XCTAssertEqual(
            metrics?.gpuCelsius,
            130.0,
            "the in-range boundary reading survives; NaN and 200 drop"
        )
        XCTAssertEqual(
            metrics?.cpuCelsius,
            -20.0,
            "the in-range boundary reading survives; -40 drops"
        )
    }

    // MARK: FM3(c) — movement filter

    /// Until any key in the domain has moved ≥ 2 °C within the
    /// trailing 60 ticks, the domain aggregates every
    /// prefix+plausibility key. Once one key moves, only moved keys
    /// feed the max — the flat hot key must drop out.
    func testMovementFilterDropsFlatKeysOnceAnyKeyMoves() {
        let enumerator = FakeSMCKeyEnumerator(keys: [
            FakeSMCKey(name: "TgHot", value: 55.0),
            FakeSMCKey(name: "TgRise", value: 40.0),
        ])
        let discovery = TemperatureKeyDiscovery(enumerator: enumerator)

        XCTAssertEqual(
            discovery.sample()?.gpuCelsius,
            55.0,
            "no movement yet: the domain aggregates all plausible keys"
        )

        enumerator.setValue(43.0, for: "TgRise")
        XCTAssertEqual(
            discovery.sample()?.gpuCelsius,
            43.0,
            "a 3 °C move activates the filter: only moved keys feed the max"
        )
    }

    /// A move below 2 °C does not activate the filter.
    func testMovementBelowTwoDegreesKeepsFullAggregate() {
        let enumerator = FakeSMCKeyEnumerator(keys: [
            FakeSMCKey(name: "TgHot", value: 55.0),
            FakeSMCKey(name: "TgRise", value: 40.0),
        ])
        let discovery = TemperatureKeyDiscovery(enumerator: enumerator)

        enumerator.setValue(41.9, for: "TgRise")
        XCTAssertEqual(
            discovery.sample()?.gpuCelsius,
            55.0,
            "a 1.9 °C move stays below the 2 °C threshold: all keys still aggregate"
        )
    }

    // MARK: FM4 — enumeration runs once per launch, never per sample

    /// The key table is built once at init. Per-sample work is
    /// read-only over the cached table: enumeration call counts do
    /// not grow across samples, and every sample reads exactly the
    /// cached keys through readFloat.
    func testEnumerationRunsOncePerLaunchNotPerSample() {
        let enumerator = FakeSMCKeyEnumerator(keys: SMCKeysFixtures.m5MaxSubset)
        let discovery = TemperatureKeyDiscovery(enumerator: enumerator)

        let enumerationCallsAfterInit = enumerator.enumerationCallCount
        XCTAssertGreaterThan(
            enumerationCallsAfterInit,
            0,
            "sanity: init enumerated the key table"
        )
        let cachedKeyCount =
            discovery.keyTable.cpuKeys.count + discovery.keyTable.gpuKeys.count
        XCTAssertGreaterThan(cachedKeyCount, 0, "sanity: the cached table has keys")
        let readCallsAfterInit = enumerator.readFloatCalls

        for _ in 0..<5 {
            _ = discovery.sample()
        }

        XCTAssertEqual(
            enumerator.enumerationCallCount,
            enumerationCallsAfterInit,
            "the enumerator must never run per sample (FM4)"
        )
        XCTAssertEqual(
            enumerator.readFloatCalls - readCallsAfterInit,
            5 * cachedKeyCount,
            "each sample reads exactly the cached table keys, nothing else"
        )
    }

    // MARK: FM5 — no hardcoded temperature key list survives

    /// The literal `Tg6I`-style candidate list is gone from
    /// production sources. The scan is comment-stripped so prose may
    /// still cite the measured keys; a surviving anchor token keeps
    /// the check from passing vacuously.
    func testNoHardcodedTemperatureKeyListSurvivesInProductionSources() throws {
        let statsLiteDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("StatsLite")
        let sources = try FileManager.default
            .contentsOfDirectory(at: statsLiteDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThan(sources.count, 10, "sanity: the source scan found the app sources")

        var providerFound = false
        for source in sources {
            let raw = try XCTUnwrap(
                String(data: Data(contentsOf: source), encoding: .utf8),
                "\(source.lastPathComponent) is not valid UTF-8"
            )
            let stripped = raw
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line -> String in
                    guard let cut = line.range(of: "//") else { return String(line) }
                    return String(line[line.startIndex..<cut.lowerBound])
                }
                .joined(separator: "\n")

            XCTAssertFalse(
                stripped.contains("\"Tg6I\""),
                "\(source.lastPathComponent) must not keep the hardcoded Tg6I candidate literal"
            )
            XCTAssertFalse(
                stripped.contains("\"Tg76\""),
                "\(source.lastPathComponent) must not keep the hardcoded Tg76 candidate literal"
            )
            XCTAssertFalse(
                stripped.contains("cpuTemperatureKeys"),
                "\(source.lastPathComponent) must not keep the hardcoded CPU key list"
            )
            XCTAssertFalse(
                stripped.contains("gpuTemperatureKeys"),
                "\(source.lastPathComponent) must not keep the hardcoded GPU key list"
            )
            if source.lastPathComponent == "LiveSystemMetricsProvider.swift" {
                providerFound = true
                XCTAssertTrue(
                    stripped.contains("sampleTemperature"),
                    "sanity anchor: the provider still exposes sampleTemperature"
                )
            }
        }
        XCTAssertTrue(providerFound, "sanity: LiveSystemMetricsProvider.swift was scanned")
    }
}
