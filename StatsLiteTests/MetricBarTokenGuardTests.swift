//
//  MetricBarTokenGuardTests.swift
//  StatsLiteTests
//
//  RED suite (plan 2026-10-27-memory-pressure-bar-thinner-subtle-track, T1):
//  source-token guards for the shared metric bar tokens. ISC-1 checks
//  the DesignTokens.swift definitions. ISC-2 checks that the gauge bar
//  and the composition bar both read the shared height token and that
//  no legacy height literal survives. ISC-3 checks the track token:
//  the gauge track and the composition bar Free segment share the
//  quaternaryLabelColor gray. FM2/ISC-5 checks the gauge fill clipping. ISC-6/FM3 checks
//  the accessibility-hidden retention on both bars.
//
//  The guards read production source the same way
//  ProcessDisclosureTests does: comments are cut, whitespace runs are
//  removed, and each check matches a squashed token, so no target
//  state can hide behind formatting.
//

import XCTest
@testable import StatsLite

final class MetricBarTokenGuardTests: XCTestCase {

    // MARK: - Source helpers (same pattern as ProcessDisclosureTests)

    /// URL of a production source file relative to this test file.
    private func sourceURL(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
            .standardizedFileURL
    }

    private func loadSource(
        _ relativePath: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let data = try Data(contentsOf: sourceURL(relativePath))
        return try XCTUnwrap(
            String(data: data, encoding: .utf8),
            "\(relativePath) is not valid UTF-8",
            file: file,
            line: line
        )
    }

    /// Normalizes source text for token comparison: cuts `//`
    /// comments line by line, then removes every whitespace run.
    /// A missing token therefore never hides behind formatting.
    private func squashed(_ source: String) -> String {
        let withoutComments = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let comment = line.range(of: "//") else { return line }
                return line[line.startIndex..<comment.lowerBound]
            }
            .joined()
        return withoutComments
            .split(whereSeparator: { $0.isWhitespace })
            .joined()
    }

    /// Number of non-overlapping occurrences of `token` in `source`.
    private func occurrences(of token: String, in source: String) -> Int {
        var count = 0
        var searchRange = source.startIndex..<source.endIndex
        while let found = source.range(of: token, range: searchRange) {
            count += 1
            searchRange = found.upperBound..<source.endIndex
        }
        return count
    }

    /// Extracts one computed-property scope from squashed source:
    /// the text after `start` up to `end`. Both tokens must exist,
    /// so a renamed scope fails loudly instead of silently matching
    /// the wrong region.
    private func scope(
        _ flat: String,
        after start: String,
        until end: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let startRange = try XCTUnwrap(
            flat.range(of: start),
            "scope start token missing from source: \(start)",
            file: file,
            line: line
        )
        let tail = flat[startRange.upperBound...]
        let endRange = try XCTUnwrap(
            tail.range(of: end),
            "scope end token missing from source: \(end)",
            file: file,
            line: line
        )
        return String(tail[tail.startIndex..<endRange.lowerBound])
    }

    /// The gaugeBar and compositionBar scopes of the memory card.
    private func memoryCardScopes(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> (gauge: String, composition: String) {
        let flat = squashed(try loadSource("StatsLite/MemoryPressureCardView.swift", file: file, line: line))
        let gauge = try scope(
            flat,
            after: "privatevargaugeBar:someView{",
            until: "privatevarcompositionBar",
            file: file,
            line: line
        )
        let composition = try scope(
            flat,
            after: "privatevarcompositionBar:someView{",
            until: "privatefuncsegment",
            file: file,
            line: line
        )
        return (gauge, composition)
    }

    // MARK: - ISC-1: the shared metric bar tokens exist

    func testDesignTokensDefineMetricBarHeightRadiusAndSubtleTrack() throws {
        let flat = squashed(try loadSource("StatsLite/DesignTokens.swift"))

        XCTAssertTrue(
            flat.contains("staticletmetricBarHeight:CGFloat=6"),
            "ISC-1: DesignTokens.swift must define static let metricBarHeight: CGFloat = 6"
        )
        XCTAssertTrue(
            flat.contains("staticletmetricBarCornerRadius:CGFloat=3"),
            "ISC-1: DesignTokens.swift must define static let metricBarCornerRadius: CGFloat = 3"
        )
        XCTAssertTrue(
            flat.contains("staticletmetricBarTrack=Color(nsColor:.quaternaryLabelColor)"),
            "ISC-1: DesignTokens.swift must define Color.metricBarTrack from quaternaryLabelColor, the composition bar Free segment gray"
        )
        XCTAssertFalse(
            flat.contains(".opacity(0.08)"),
            "ISC-1: the old separatorColor at 0.08 opacity track definition must be gone"
        )
    }

    // MARK: - ISC-2: both bars read the shared height token, legacy literals gone

    func testBothBarsUseTheMetricBarHeightTokenAndLegacyFrameLiteralsAreGone() throws {
        let flat = squashed(try loadSource("StatsLite/MemoryPressureCardView.swift"))
        let scopes = try memoryCardScopes()

        XCTAssertTrue(
            scopes.gauge.contains(".frame(height:.metricBarHeight)"),
            "ISC-2: the gaugeBar scope must set .frame(height: .metricBarHeight)"
        )
        XCTAssertTrue(
            scopes.composition.contains(".frame(height:.metricBarHeight)"),
            "ISC-2: the compositionBar scope must set .frame(height: .metricBarHeight)"
        )
        XCTAssertEqual(
            occurrences(of: ".frame(height:.metricBarHeight)", in: flat), 2,
            "ISC-2: exactly the two metric bars carry the shared height token"
        )
        XCTAssertFalse(
            flat.contains(".frame(height:8)"),
            "ISC-2: the legacy .frame(height: 8) gauge literal must be gone"
        )
        XCTAssertFalse(
            flat.contains(".frame(height:6)"),
            "ISC-2: the bare .frame(height: 6) composition literal must go through the token"
        )

        // Plan ISC-2: both bars also read the shared radius token and
        // no literal bar radius remains.
        XCTAssertTrue(
            scopes.gauge.contains("RoundedRectangle(cornerRadius:.metricBarCornerRadius"),
            "ISC-2: the gauge track and fill use the shared corner radius token"
        )
        XCTAssertTrue(
            scopes.composition.contains("RoundedRectangle(cornerRadius:.metricBarCornerRadius"),
            "ISC-2: the composition bar clip uses the shared corner radius token"
        )
        XCTAssertFalse(
            flat.contains("cornerRadius:3"),
            "ISC-2: no literal 3 pt bar radius remains in the memory card"
        )
        XCTAssertFalse(
            flat.contains("cornerRadius:4"),
            "ISC-2: no legacy 4 pt composition radius remains in the memory card"
        )
    }

    // MARK: - ISC-3: the gauge track uses the subtle token

    func testGaugeTrackUsesTheMetricBarTrackTokenAndTheProminentOpacityIsGone() throws {
        let flat = squashed(try loadSource("StatsLite/MemoryPressureCardView.swift"))
        let scopes = try memoryCardScopes()

        XCTAssertTrue(
            scopes.gauge.contains("style:.continuous).fill(Color.metricBarTrack)"),
            "ISC-3: the gauge track fill must be Color.metricBarTrack on the continuous rounded rectangle"
        )
        XCTAssertFalse(
            flat.contains(".opacity(0.2)"),
            "ISC-3: the prominent .opacity(0.2) separator wash must be gone from the memory card"
        )
        XCTAssertTrue(
            scopes.composition.contains(".fill(Color(nsColor:.quaternaryLabelColor))"),
            "ISC-3: the composition bar Free segment uses quaternaryLabelColor, the same gray as the gauge track token"
        )
        XCTAssertFalse(
            scopes.gauge.contains("separatorColor"),
            "ISC-3: the gauge track must not fall back to separatorColor"
        )
    }

    // MARK: - FM2 / ISC-5: the gauge fill stays clipped inside the pill

    func testGaugeBarClipsItsZStackToTheRoundedTrack() throws {
        let scopes = try memoryCardScopes()

        XCTAssertTrue(
            scopes.gauge.contains(".clipShape(RoundedRectangle"),
            "FM2/ISC-5: the gauge ZStack must clip to the rounded rectangle so a small fill never protrudes past the pill boundary"
        )
    }

    // MARK: - ISC-6 / FM3: accessibility retention on both bars

    func testBothBarsKeepTheAccessibilityHiddenMarkers() throws {
        let flat = squashed(try loadSource("StatsLite/MemoryPressureCardView.swift"))

        XCTAssertGreaterThanOrEqual(
            occurrences(of: ".accessibilityHidden(true)", in: flat), 2,
            "ISC-6/FM3: both the gauge bar and the composition bar keep .accessibilityHidden(true)"
        )
        XCTAssertTrue(
            flat.contains("gaugeBar.accessibilityHidden(true)"),
            "ISC-6/FM3: the gaugeBar call site in the body keeps .accessibilityHidden(true)"
        )
        XCTAssertTrue(
            flat.contains("compositionBar.accessibilityHidden(true)"),
            "ISC-6/FM3: the compositionBar call site in the body keeps .accessibilityHidden(true)"
        )
    }
}
