//
//  M5MaxFullKeyTableTests.swift
//  StatsLiteTests
//
//  T4 strengthening (plan 2026-10-27-runtime-smc-key-discovery): the
//  full measured M5 Max key set builds the expected table. The
//  fixture parses artifacts/2026-10-23-temp-menu-bar-metric/
//  h1-baseline.log at test time — the log header lists all 296 keys
//  and tick 1 carries one reading per key — so no hardcoded key list
//  enters the test either. The log records names and values, not
//  SMC types: the fixture models every logged key as the Apple
//  Silicon `flt ` family (type "flt ", size 4), which is the premise
//  the count assertion checks.
//

import XCTest
@testable import StatsLite

final class M5MaxFullKeyTableTests: XCTestCase {

    /// The h1 baseline header lists 296 keys: 23 `Tp*` keys land in
    /// the CPU table, 84 `Tg*` keys in the GPU table, and the other
    /// families (TVD, Tm, TRD, TUD, Tf, Tz, ...) stay unattributed.
    func testFullM5MaxKeySetBuilds23CpuAnd84GpuKeys() throws {
        let keys = try h1BaselineFixture()

        XCTAssertEqual(
            keys.count,
            296,
            "sanity: the h1-baseline.log header lists the full measured key set"
        )

        let discovery = TemperatureKeyDiscovery(
            enumerator: FakeSMCKeyEnumerator(keys: keys)
        )

        XCTAssertEqual(
            discovery.keyTable.cpuKeys.count,
            23,
            "the Tp family on this machine is 23 keys (h1-baseline.log header)"
        )
        XCTAssertEqual(
            discovery.keyTable.gpuKeys.count,
            84,
            "the Tg family on this machine is 84 keys (plan H1, measured)"
        )
        XCTAssertTrue(
            discovery.keyTable.cpuKeys.allSatisfy { $0.hasPrefix("Tp") },
            "the CPU table holds only exact Tp keys"
        )
        XCTAssertTrue(
            discovery.keyTable.gpuKeys.allSatisfy { $0.hasPrefix("Tg") },
            "the GPU table holds only exact Tg keys"
        )
    }

    /// Parses the h1-baseline.log header (`# columns:` line) into one
    /// fixture key per column, taking tick 1 values where the log
    /// has them.
    private func h1BaselineFixture() throws -> [FakeSMCKey] {
        let logURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("artifacts/2026-10-23-temp-menu-bar-metric/h1-baseline.log")
        let text = try String(contentsOf: logURL, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)

        let columnsLine = try XCTUnwrap(
            lines.first { $0.hasPrefix("# columns: ") },
            "h1-baseline.log must carry the # columns: header"
        )
        let names = columnsLine
            .dropFirst("# columns: ".count)
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)

        // Tick 1: the first non-comment line, entries as Name=value.
        let firstTick = try XCTUnwrap(
            lines.first { !$0.hasPrefix("#") && $0.contains("=") },
            "h1-baseline.log must carry at least one tick line"
        )
        var values: [String: Double] = [:]
        for entry in firstTick.split(separator: " ", omittingEmptySubsequences: true) {
            guard let eq = entry.firstIndex(of: "=") else { continue }
            let name = String(entry[entry.startIndex..<eq])
            let raw = String(entry[entry.index(after: eq)...])
            if let value = Double(raw) {
                values[name] = value
            }
        }

        return names.map { name in
            FakeSMCKey(name: name, value: values[name] ?? 0.0)
        }
    }
}
