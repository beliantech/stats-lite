//
//  UpdateCheckPolicyTests.swift
//  StatsLiteTests
//
//  Dismissal normalization (plan 2026-10-20-in-app-update-check,
//  ISC I1; rewritten for T3b). The promptState state-table tests
//  were deleted with the GitHub poller retirement: Sparkle now owns
//  the version comparison, and no caller left maps latest/current
//  to a prompt. normalizeDismissed still backs dismiss()/isDismissed()
//  on the coordinator seam. No network, no UserDefaults, no view.
//

import Foundation
import XCTest
@testable import StatsLite

final class UpdateCheckPolicyTests: XCTestCase {

    // MARK: - Dismissal comparison ignores a leading "v" on either side

    func testNormalizeStripsOneLeadingLowercaseV() {
        XCTAssertEqual(UpdateCheckPolicy.normalizeDismissed("v1.2.0"), "1.2.0")
    }

    func testNormalizeStripsOneLeadingUppercaseV() {
        XCTAssertEqual(UpdateCheckPolicy.normalizeDismissed("V1.2.0"), "1.2.0")
    }

    func testNormalizeLeavesBareVersionUnchanged() {
        XCTAssertEqual(UpdateCheckPolicy.normalizeDismissed("1.2.0"), "1.2.0")
    }

    func testNormalizeStripsOnlyOneLeadingV() {
        XCTAssertEqual(
            UpdateCheckPolicy.normalizeDismissed("vv1.2.0"),
            "v1.2.0",
            "at most one leading v is stripped"
        )
    }

    /// Stored "v1.1.0" must match a dismissed version written as
    /// "1.1.0": both sides normalize before the comparison.
    func testNormalizedStoredAndDismissedVersionsMatch() {
        XCTAssertEqual(
            UpdateCheckPolicy.normalizeDismissed("v1.1.0"),
            UpdateCheckPolicy.normalizeDismissed("1.1.0")
        )
    }

    func testNormalizedVersionsStayDistinctWhenTheyDiffer() {
        XCTAssertNotEqual(
            UpdateCheckPolicy.normalizeDismissed("v1.1.0"),
            UpdateCheckPolicy.normalizeDismissed("1.2.0")
        )
    }
}
