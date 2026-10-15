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

    // MARK: - AC-8: values stays in lockstep with points

    func testValuesMatchPointsAfterInitialFill() {
        var buffer = HistoryBuffer()
        let start = Date()

        for index in 0..<5 {
            buffer.append(
                Double(index) / 10,
                at: start.addingTimeInterval(Double(index)),
                maxAge: 1000,
                capacity: 30
            )
        }

        XCTAssertEqual(buffer.values, buffer.points.map(\.value))
        XCTAssertEqual(buffer.values, [0, 0.1, 0.2, 0.3, 0.4])
    }

    func testValuesMatchPointsAfterMultiPointAgeEviction() {
        var buffer = HistoryBuffer()
        let start = Date()

        // Ages 0, 3, 6, 9 against a 10 s window.
        for index in 0..<4 {
            buffer.append(
                Double(index),
                at: start.addingTimeInterval(Double(index) * 3),
                maxAge: 10,
                capacity: 100
            )
        }

        // Age 19 expires the three oldest points in one call.
        buffer.append(99, at: start.addingTimeInterval(19), maxAge: 10, capacity: 100)

        XCTAssertEqual(buffer.values, buffer.points.map(\.value))
        XCTAssertEqual(buffer.values, [3, 99])
        XCTAssertEqual(
            buffer.points.map(\.timestamp),
            [start.addingTimeInterval(9), start.addingTimeInterval(19)]
        )
    }

    func testValuesMatchPointsAfterCapacityTruncation() {
        var buffer = HistoryBuffer()
        let now = Date()

        for index in 0..<8 {
            buffer.append(
                Double(index),
                at: now.addingTimeInterval(Double(index)),
                maxAge: 10_000,
                capacity: 3
            )
        }

        XCTAssertEqual(buffer.values, buffer.points.map(\.value))
        XCTAssertEqual(buffer.values, [5, 6, 7])
    }

    func testValuesMatchPointsWhenAgeAndCapacityTrimOnOneAppend() {
        var buffer = HistoryBuffer()
        let start = Date()

        // One append triggers both trims: the age scan drops the
        // oldest point, then the overflow cap drops the next-oldest.
        buffer.append(0, at: start.addingTimeInterval(89), maxAge: 10, capacity: 100)
        buffer.append(1, at: start.addingTimeInterval(95), maxAge: 10, capacity: 100)
        buffer.append(2, at: start.addingTimeInterval(98), maxAge: 10, capacity: 100)
        buffer.append(99, at: start.addingTimeInterval(100), maxAge: 10, capacity: 2)

        XCTAssertEqual(buffer.values, buffer.points.map(\.value))
        XCTAssertEqual(buffer.values, [2, 99])
    }

    // MARK: - AC-8: zero-allocation steady-state append

    func testSteadyStateAppendPerformsZeroHeapAllocations() {
        let ticks = 10_000
        let capacity = 60
        let maxAge: TimeInterval = 10_000
        let start = Date()

        // Fill past capacity so every later append trims only the
        // front and reuses the existing array storage.
        var buffer = HistoryBuffer()
        for index in 0..<(capacity * 2) {
            buffer.append(
                Double(index),
                at: start.addingTimeInterval(Double(index)),
                maxAge: maxAge,
                capacity: capacity
            )
        }
        XCTAssertEqual(buffer.values.count, capacity)

        let work = {
            for index in 0..<ticks {
                buffer.append(
                    Double(index),
                    at: start.addingTimeInterval(Double(capacity * 2 + index)),
                    maxAge: maxAge,
                    capacity: capacity
                )
            }
        }
        work() // uncounted warm pass

        // Floor replica: the same steady-state operations on two raw
        // arrays. Unoptimized debug builds box generic stdlib call
        // arguments on every call, so a per-call allocation floor
        // exists that no implementation can avoid. The raw-array
        // replica measures that floor.
        var floorPoints: [HistoryPoint] = []
        var floorValues: [Double] = []
        for index in 0..<(capacity * 2) {
            floorPoints.append(
                HistoryPoint(value: Double(index), timestamp: start.addingTimeInterval(Double(index)))
            )
            floorValues.append(Double(index))
        }
        let floorWork = {
            for index in 0..<ticks {
                let timestamp = start.addingTimeInterval(Double(capacity * 2 + index))
                floorPoints.append(HistoryPoint(value: Double(index), timestamp: timestamp))
                floorValues.append(Double(index))
                let expiredCount = floorPoints.prefix(while: {
                    timestamp.timeIntervalSince($0.timestamp) > maxAge
                }).count
                if expiredCount > 0 {
                    floorPoints.removeFirst(expiredCount)
                    floorValues.removeFirst(expiredCount)
                }
                let overflow = floorPoints.count - capacity
                if overflow > 0 {
                    floorPoints.removeFirst(overflow)
                    floorValues.removeFirst(overflow)
                }
            }
        }
        floorWork() // uncounted warm pass

        // Naive replica: recomputes values with `.map` on every
        // append. That is the pattern this test guards against, and
        // it must allocate at least one array per call in every
        // build configuration.
        var naivePoints: [HistoryPoint] = []
        var naiveValues: [Double] = []
        for index in 0..<(capacity * 2) {
            naivePoints.append(
                HistoryPoint(value: Double(index), timestamp: start.addingTimeInterval(Double(index)))
            )
            naiveValues = naivePoints.map(\.value)
        }
        let naiveWork = {
            for index in 0..<ticks {
                naivePoints.append(
                    HistoryPoint(
                        value: Double(index),
                        timestamp: start.addingTimeInterval(Double(capacity * 2 + index))
                    )
                )
                naiveValues = naivePoints.map(\.value)
                let overflow = naivePoints.count - capacity
                if overflow > 0 {
                    naivePoints.removeFirst(overflow)
                    naiveValues = naivePoints.map(\.value)
                }
            }
        }
        naiveWork() // uncounted warm pass

        // Positive control: the probe must count deliberate heap
        // allocations, so a silent hook failure cannot pass the test.
        MallocEventProbe.start()
        let churn = (0..<100).map { _ in [Double](repeating: 0.5, count: 60) }
        let controlAllocations = MallocEventProbe.allocations
        MallocEventProbe.stop()
        XCTAssertEqual(churn.count, 100)
        XCTAssertGreaterThanOrEqual(
            controlAllocations,
            100,
            "malloc probe did not count allocations; the hook is broken"
        )

        MallocEventProbe.start()
        floorWork()
        MallocEventProbe.stop()
        let floorAllocations = MallocEventProbe.allocations

        MallocEventProbe.start()
        work()
        MallocEventProbe.stop()
        let actualAllocations = MallocEventProbe.allocations

        MallocEventProbe.start()
        naiveWork()
        MallocEventProbe.stop()
        let naiveAllocations = MallocEventProbe.allocations

        XCTAssertEqual(
            actualAllocations,
            floorAllocations,
            "steady-state append allocated \(actualAllocations) times over \(ticks) calls; the raw-array floor is \(floorAllocations)"
        )
        XCTAssertGreaterThanOrEqual(
            naiveAllocations,
            floorAllocations + ticks,
            "the map-recompute control must allocate at least once per call; the test cannot discriminate"
        )
        XCTAssertEqual(buffer.values.count, capacity)
    }
}

// MARK: - Malloc event probe

/// Signature of the libmalloc `malloc_logger` hook. libmalloc calls it
/// from every malloc/free path with an event code in the first slot.
private typealias MallocLoggerFn = @convention(c) (UInt32, UInt64, UInt64, UInt64, UInt64, UInt64) -> Void

/// Counts heap allocation and deallocation events on the calling
/// thread. Event code 10 is an allocation and 12 is a deallocation;
/// verified with a live probe against libmalloc on macOS 27. The
/// probe installs only for the measured window and restores the
/// previous hook.
private enum MallocEventProbe {
    nonisolated(unsafe) static var allocations = 0
    nonisolated(unsafe) static var deallocations = 0
    nonisolated(unsafe) private static var watchedThread: UInt64 = 0
    nonisolated(unsafe) private static var saved: MallocLoggerFn?
    nonisolated(unsafe) private static var installed = false

    private static let logger: MallocLoggerFn = { type, _, _, _, _, _ in
        var threadID: UInt64 = 0
        pthread_threadid_np(nil, &threadID)
        guard threadID == watchedThread else { return }
        switch type {
        case 10: allocations += 1
        case 12: deallocations += 1
        default: break
        }
    }

    /// Starts counting on the calling thread. Make sure that the
    /// `malloc_logger` symbol exists before you rely on the counts.
    static func start() {
        allocations = 0
        deallocations = 0
        var threadID: UInt64 = 0
        pthread_threadid_np(nil, &threadID)
        watchedThread = threadID

        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "malloc_logger") else {
            XCTFail("malloc_logger symbol unavailable; allocation counts are not measured")
            return
        }
        let slot = symbol.assumingMemoryBound(to: Optional<MallocLoggerFn>.self)
        saved = slot.pointee
        slot.pointee = logger
        installed = true
    }

    /// Restores the previous hook and freezes the counters.
    static func stop() {
        guard installed,
              let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "malloc_logger") else {
            return
        }
        symbol.assumingMemoryBound(to: Optional<MallocLoggerFn>.self).pointee = saved
        saved = nil
        installed = false
    }
}
