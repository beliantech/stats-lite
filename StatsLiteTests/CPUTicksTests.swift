//
//  CPUTicksTests.swift
//  StatsLiteTests
//
//  One CPU sample holds per-core tick entries and their aggregate sum.
//

import XCTest
@testable import StatsLite

final class CPUTicksTests: XCTestCase {

    func testAggregatesCoresIntoOneSample() {
        let ticks = CPUTicks(perCore: [
            CoreTickSample(user: 10, system: 5, idle: 80, nice: 5),
            CoreTickSample(user: 20, system: 10, idle: 60, nice: 10),
        ])
        XCTAssertEqual(ticks.perCore.count, 2)
        XCTAssertEqual(
            ticks.aggregate,
            CoreTickSample(user: 30, system: 15, idle: 140, nice: 15)
        )
    }

    func testEmptyCoreListGivesZeroAggregate() {
        let ticks = CPUTicks(perCore: [])
        XCTAssertTrue(ticks.perCore.isEmpty)
        XCTAssertEqual(
            ticks.aggregate,
            CoreTickSample(user: 0, system: 0, idle: 0, nice: 0)
        )
    }

    func testAggregateTotalAndBusyMatchSumOfCores() {
        let coreA = CoreTickSample(user: 1, system: 2, idle: 3, nice: 4)
        let coreB = CoreTickSample(user: 10, system: 20, idle: 30, nice: 40)
        let ticks = CPUTicks(perCore: [coreA, coreB])
        XCTAssertEqual(ticks.aggregate.total, coreA.total + coreB.total)
        XCTAssertEqual(ticks.aggregate.busy, coreA.busy + coreB.busy)
    }
}
