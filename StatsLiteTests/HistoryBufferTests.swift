//
//  HistoryBufferTests.swift
//  StatsLiteTests
//
//  Sparkline ring buffer: the age window and the sample-count cap
//  bound memory for every append.
//

import XCTest
@testable import StatsLite

final class HistoryBufferTests: XCTestCase {

    func testAppendKeepsAtMostCapacityPoints() {
        var buffer = HistoryBuffer()
        let start = Date()

        for index in 0..<20 {
            buffer.append(
                Double(index),
                at: start.addingTimeInterval(Double(index)),
                maxAge: 10_000,
                capacity: 5
            )
        }

        XCTAssertEqual(buffer.points.count, 5)
        XCTAssertEqual(buffer.values, [15, 16, 17, 18, 19])
    }

    func testAppendDropsPointsOlderThanMaxAge() {
        var buffer = HistoryBuffer()
        let newest = Date()

        buffer.append(1, at: newest.addingTimeInterval(-100), maxAge: 30, capacity: 100)
        buffer.append(2, at: newest.addingTimeInterval(-10), maxAge: 30, capacity: 100)
        buffer.append(3, at: newest, maxAge: 30, capacity: 100)

        XCTAssertEqual(buffer.values, [2, 3])
    }

    func testCapacityFloorIsOne() {
        var buffer = HistoryBuffer()
        let now = Date()

        for index in 0..<10 {
            buffer.append(Double(index), at: now, maxAge: 1000, capacity: 0)
        }

        XCTAssertEqual(buffer.points.count, 1)
        XCTAssertEqual(buffer.values, [9])
    }

    func testPointsCarryTimestampsOldestFirst() {
        var buffer = HistoryBuffer()
        let now = Date()

        buffer.append(1, at: now, maxAge: 1000, capacity: 10)
        buffer.append(2, at: now.addingTimeInterval(1), maxAge: 1000, capacity: 10)

        XCTAssertEqual(buffer.points.count, 2)
        XCTAssertEqual(buffer.points[0].value, 1)
        XCTAssertEqual(buffer.points[0].timestamp, now)
        XCTAssertEqual(buffer.points[1].value, 2)
        XCTAssertEqual(buffer.points[1].timestamp, now.addingTimeInterval(1))
    }

    func testEmptyBufferHasNoValues() {
        let buffer = HistoryBuffer()
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.values, [])
    }
}
