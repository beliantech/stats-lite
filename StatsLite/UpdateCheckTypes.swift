//
//  UpdateCheckTypes.swift
//  StatsLite
//
//  Pure update-check value types. Foundation only, no AppKit: the
//  policy stays testable without a view or a network. A semantic
//  version parses exactly three numeric components with at most one
//  leading "v" stripped. The GitHub payload decoder and the release
//  source protocol died with the GitHub poller retirement (T3b):
//  Sparkle owns release discovery and version comparison.
//

import Foundation

/// Semantic version of exactly three base-10 integer components, with
/// at most one leading "v" or "V" stripped before the split. No
/// whitespace trimming: " v1.2.3 " does not parse.
struct SemanticVersion: Comparable, Sendable, CustomStringConvertible {

    let major: Int
    let minor: Int
    let patch: Int

    init?(_ raw: String) {
        var text = Substring(raw)
        if text.first == "v" || text.first == "V" {
            text = text.dropFirst()
        }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2])
        else { return nil }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Normalized "major.minor.patch" with no "v" prefix.
    var description: String {
        "\(major).\(minor).\(patch)"
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

/// One discovered release, reduced to the version and the release
/// page (banner and fixture values).
struct ReleaseInfo: Sendable, Equatable {
    let version: SemanticVersion
    let releasePageURL: URL
}

/// Dismissal policy: stored and compared values normalize one
/// leading "v" before they meet.
enum UpdateCheckPolicy {

    /// Strips at most one leading "v" or "V".
    static func normalizeDismissed(_ raw: String) -> String {
        var text = Substring(raw)
        if text.first == "v" || text.first == "V" {
            text = text.dropFirst()
        }
        return String(text)
    }
}
