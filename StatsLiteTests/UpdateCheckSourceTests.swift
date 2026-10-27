//
//  UpdateCheckSourceTests.swift
//  StatsLiteTests
//
//  ReleaseInfo value shape. The GitHub payload decode tests and the
//  fake release source were deleted with the GitHub poller
//  retirement (T3b): decodeLatest had no caller left, and the
//  coordinator seam in SparkleUpdateCoordinatorTests now owns every
//  release-source behavior assertion. No network.
//

import Foundation
import XCTest
@testable import StatsLite

final class UpdateCheckSourceTests: XCTestCase {

    private func assertSendable<T: Sendable>(_: T.Type) {}

    // MARK: - ReleaseInfo shape

    func testReleaseInfoIsSendable() {
        assertSendable(ReleaseInfo.self)
    }

    func testReleaseInfoEquatableComparesEqualValues() throws {
        let version = try XCTUnwrap(SemanticVersion("1.4.0"))
        let url = try XCTUnwrap(
            URL(string: "https://github.com/beliantech/stats-lite/releases/tag/v1.4.0")
        )
        let left = ReleaseInfo(version: version, releasePageURL: url)
        let right = ReleaseInfo(version: version, releasePageURL: url)
        XCTAssertEqual(left, right)
    }

    func testReleaseInfoEquatableDetectsDifferentVersions() throws {
        let url = try XCTUnwrap(
            URL(string: "https://github.com/beliantech/stats-lite/releases/tag/v1.4.0")
        )
        let left = ReleaseInfo(
            version: try XCTUnwrap(SemanticVersion("1.4.0")),
            releasePageURL: url
        )
        let right = ReleaseInfo(
            version: try XCTUnwrap(SemanticVersion("1.4.1")),
            releasePageURL: url
        )
        XCTAssertNotEqual(left, right)
    }
}
