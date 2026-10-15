//
//  HistoryBuffer.swift
//  StatsLite
//
//  Capped ring buffer for sparkline data. Every append trims by age
//  and by count, so a buffer never grows past its capacity.
//

import Foundation

/// One sparkline sample: the value and the time it was taken.
struct HistoryPoint: Sendable, Equatable {
    var value: Double
    var timestamp: Date
}

/// Sparkline history for one metric. Points stay oldest first. The age
/// window is measured against the timestamp of the newest append.
/// `values` is stored and stays in lockstep with `points` inside
/// `append`, so reading it never allocates.
struct HistoryBuffer: Sendable {
    private(set) var points: [HistoryPoint] = []

    /// Point values in oldest-first order. Mutated in lockstep with
    /// `points` inside `append`.
    private(set) var values: [Double] = []

    var isEmpty: Bool { points.isEmpty }

    /// Appends one point, then drops points older than `maxAge` seconds
    /// and keeps at most `capacity` points. A capacity below 1 keeps 1
    /// point, so the buffer always holds the newest sample. Producers
    /// append nondecreasing timestamps and eviction only trims the
    /// front, so `points` stays sorted oldest first and the
    /// prefix-while age scan stops at the first live point.
    mutating func append(
        _ value: Double,
        at timestamp: Date,
        maxAge: TimeInterval,
        capacity: Int
    ) {
        points.append(HistoryPoint(value: value, timestamp: timestamp))
        values.append(value)

        let expiredCount = points.prefix(while: {
            timestamp.timeIntervalSince($0.timestamp) > maxAge
        }).count
        if expiredCount > 0 {
            points.removeFirst(expiredCount)
            values.removeFirst(expiredCount)
        }

        let overflow = points.count - Swift.max(capacity, 1)
        if overflow > 0 {
            points.removeFirst(overflow)
            values.removeFirst(overflow)
        }
    }
}
