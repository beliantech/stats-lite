//
//  UpdateCheckTypes.swift
//  StatsLite
//
//  Pure update-check value types. Foundation only, no AppKit: the
//  policy stays testable without a view or a network. A semantic
//  version parses exactly three numeric components with at most one
//  leading "v" stripped. A release source returns nil on any failure;
//  nil means silent no-op.
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

/// One GitHub release, reduced to the version and the release page.
struct ReleaseInfo: Sendable, Equatable {
    let version: SemanticVersion
    let releasePageURL: URL

    /// Decode errors the decoder cannot report itself: the payload is
    /// well-formed JSON, but a value fails the update-check contract.
    enum DecodeError: Error, Equatable {
        case invalidTagName(String)
        case invalidReleasePageURL(String)
    }

    /// Decodes the three-key latest-release payload. A missing key or
    /// malformed JSON throws `DecodingError`. An unparsable tag or URL
    /// throws `DecodeError`. Unknown fields are ignored.
    static func decodeLatest(data: Data) throws -> ReleaseInfo {
        struct Payload: Decodable {
            let tag_name: String
            let html_url: String
            let name: String
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let version = SemanticVersion(payload.tag_name) else {
            throw DecodeError.invalidTagName(payload.tag_name)
        }
        guard let url = URL(string: payload.html_url) else {
            throw DecodeError.invalidReleasePageURL(payload.html_url)
        }
        return ReleaseInfo(version: version, releasePageURL: url)
    }
}

/// Result of one prompt decision. `prompt` carries the release to
/// show.
enum UpdatePromptState: Equatable {
    case none
    case prompt(ReleaseInfo)
}

/// Pure prompt policy: prompt when the latest release is newer than
/// the installed version and the user did not dismiss that version.
enum UpdateCheckPolicy {

    /// Maps latest, current, and the stored dismissed version to a
    /// prompt state. The dismissed comparison strips one leading "v"
    /// from the stored value. A nil, equal, or older latest maps to
    /// `.none`.
    static func promptState(
        latest: ReleaseInfo,
        current: SemanticVersion,
        dismissedVersion: String?
    ) -> UpdatePromptState {
        guard latest.version > current else { return .none }
        if let dismissedVersion,
           normalizeDismissed(dismissedVersion) == latest.version.description {
            return .none
        }
        return .prompt(latest)
    }

    /// Strips at most one leading "v" or "V".
    static func normalizeDismissed(_ raw: String) -> String {
        var text = Substring(raw)
        if text.first == "v" || text.first == "V" {
            text = text.dropFirst()
        }
        return String(text)
    }
}

/// One release source. `latestRelease()` returns nil on any failure.
/// Callers treat nil as a silent no-op.
protocol UpdateReleaseSource: Sendable {
    func latestRelease() async -> ReleaseInfo?
}
