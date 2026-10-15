//
//  EnabledMetricsGuardTests.swift
//  StatsLiteTests
//
//  Toggle set semantics. The monitor guard rejects an empty set because
//  at least one metric must stay enabled.
//

import XCTest
@testable import StatsLite

final class EnabledMetricsGuardTests: XCTestCase {

    func testEmptySetIsRejectedByMonitorGuard() {
        XCTAssertFalse(MonitorGuard.allowsSampling([]))
        XCTAssertFalse(MonitorGuard.allowsSampling(EnabledMetrics()))
    }

    func testEverySingleMetricIsAllowed() {
        XCTAssertTrue(MonitorGuard.allowsSampling([.cpu]))
        XCTAssertTrue(MonitorGuard.allowsSampling([.memory]))
        XCTAssertTrue(MonitorGuard.allowsSampling([.gpu]))
    }

    func testCombinedSetIsAllowed() {
        XCTAssertTrue(MonitorGuard.allowsSampling([.cpu, .memory]))
        XCTAssertTrue(MonitorGuard.allowsSampling([.cpu, .memory, .gpu]))
    }

    func testAllCoversEveryMetric() {
        XCTAssertTrue(EnabledMetrics.all.contains(.cpu))
        XCTAssertTrue(EnabledMetrics.all.contains(.memory))
        XCTAssertTrue(EnabledMetrics.all.contains(.gpu))
        XCTAssertEqual(EnabledMetrics.all, [.cpu, .memory, .gpu])
    }

    func testMembersAreIndependentOptions() {
        let memoryOnly: EnabledMetrics = [.memory]
        XCTAssertFalse(memoryOnly.contains(.cpu))
        XCTAssertFalse(memoryOnly.contains(.gpu))
        XCTAssertTrue(memoryOnly.contains(.memory))
    }
}
