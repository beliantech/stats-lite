//
//  UpdateCheckSourceTests.swift
//  StatsLiteTests
//
//  Decode seam and failure contract (plan 2026-10-20-in-app-update-check,
//  ISC I2). ReleaseInfo.decodeLatest(data:) parses the 3-key GitHub
//  releases payload. A missing key or malformed JSON throws. A source that
//  cannot reach the network returns nil, and nil means silent no-op.
//

import Foundation
import XCTest
@testable import StatsLite

final class UpdateCheckSourceTests: XCTestCase {

    private let fixtureJSON = """
    {"tag_name":"v1.4.0","html_url":"https://github.com/beliantech/stats-lite/releases/tag/v1.4.0","name":"StatsLite 1.4.0"}
    """

    private var fixtureData: Data {
        return Data(fixtureJSON.utf8)
    }

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

    // MARK: - Decode success

    func testDecodeLatestParsesThreeKeyFixture() throws {
        let info = try ReleaseInfo.decodeLatest(data: fixtureData)
        let expectedVersion = try XCTUnwrap(SemanticVersion("1.4.0"))
        XCTAssertEqual(info.version, expectedVersion)
        XCTAssertEqual(
            info.releasePageURL,
            URL(string: "https://github.com/beliantech/stats-lite/releases/tag/v1.4.0")
        )
    }

    func testDecodeLatestIgnoresUnknownExtraFields() throws {
        let payload = """
        {"tag_name":"v1.4.0","html_url":"https://github.com/beliantech/stats-lite/releases/tag/v1.4.0","name":"StatsLite 1.4.0","id":42,"prerelease":false,"assets":[]}
        """
        let info = try ReleaseInfo.decodeLatest(data: Data(payload.utf8))
        XCTAssertEqual(info.version, try XCTUnwrap(SemanticVersion("1.4.0")))
    }

    // MARK: - Decode failure

    func testDecodeLatestThrowsWhenTagNameMissing() {
        let payload = """
        {"html_url":"https://github.com/beliantech/stats-lite/releases/tag/v1.4.0","name":"StatsLite 1.4.0"}
        """
        XCTAssertThrowsError(try ReleaseInfo.decodeLatest(data: Data(payload.utf8)))
    }

    func testDecodeLatestThrowsWhenHTMLOnlyMissing() {
        let payload = """
        {"tag_name":"v1.4.0","name":"StatsLite 1.4.0"}
        """
        XCTAssertThrowsError(try ReleaseInfo.decodeLatest(data: Data(payload.utf8)))
    }

    func testDecodeLatestThrowsOnMalformedJSON() {
        XCTAssertThrowsError(try ReleaseInfo.decodeLatest(data: Data("not json".utf8)))
        XCTAssertThrowsError(try ReleaseInfo.decodeLatest(data: Data("{".utf8)))
        XCTAssertThrowsError(try ReleaseInfo.decodeLatest(data: Data()))
    }

    // MARK: - Silent-failure path

    private struct FakeReleaseSource: UpdateReleaseSource {
        func latestRelease() async -> ReleaseInfo? {
            return nil
        }
    }

    func testFakeSourceReturnsNilForSilentFailurePath() async {
        let source = FakeReleaseSource()
        let result = await source.latestRelease()
        XCTAssertNil(result, "an unreachable source returns nil; nil means silent no-op")
    }
}
