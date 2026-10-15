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
struct HistoryBuffer: Sendable {
    private(set) var points: [HistoryPoint] = []

    /// Point values in oldest-first order.
    var values: [Double] { points.map(\.value) }

    var isEmpty: Bool { points.isEmpty }

    /// Appends one point, then drops points older than `maxAge` seconds
    /// and keeps at most `capacity` points. A capacity below 1 keeps 1
    /// point, so the buffer always holds the newest sample.
    mutating func append(
        _ value: Double,
        at timestamp: Date,
        maxAge: TimeInterval,
        capacity: Int
    ) {
        points.append(HistoryPoint(value: value, timestamp: timestamp))
        points.removeAll { timestamp.timeIntervalSince($0.timestamp) > maxAge }

        let limit = Swift.max(capacity, 1)
        if points.count > limit {
            points.removeFirst(points.count - limit)
        }
    }
}
