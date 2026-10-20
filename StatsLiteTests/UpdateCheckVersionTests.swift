//
//  UpdateCheckVersionTests.swift
//  StatsLiteTests
//
//  Parse and compare table for SemanticVersion (plan
//  2026-10-20-in-app-update-check, ISC I1). Parse rule: strip at most one
//  leading "v" or "V", split on ".", require exactly three components, and
//  parse each component as a base-10 Int. No whitespace trimming.
//

import XCTest
@testable import StatsLite

final class UpdateCheckVersionTests: XCTestCase {

    // MARK: - Parse acceptance

    func testParsesPlainVersion() {
        XCTAssertNotNil(SemanticVersion("1.2.3"))
    }

    func testParsesLowercaseVPrefixedVersion() {
        XCTAssertNotNil(SemanticVersion("v1.2.3"))
    }

    func testParsesUppercaseVPrefixedVersion() {
        XCTAssertNotNil(SemanticVersion("V1.2.3"))
    }

    func testVPrefixedAndPlainParseToEqualVersions() {
        XCTAssertEqual(SemanticVersion("v1.2.3"), SemanticVersion("1.2.3"))
    }

    // MARK: - Parse rejection

    func testRejectsTwoComponentVersion() {
        XCTAssertNil(SemanticVersion("1.2"))
    }

    func testRejectsFourComponentVersion() {
        XCTAssertNil(SemanticVersion("1.2.3.4"))
    }

    func testRejectsEmptyString() {
        XCTAssertNil(SemanticVersion(""))
    }

    func testRejectsNonNumericString() {
        XCTAssertNil(SemanticVersion("abc"))
    }

    func testRejectsVPrefixedFourComponentVersion() {
        XCTAssertNil(SemanticVersion("v1.2.3.4"))
    }

    func testRejectsNonNumericPatchComponent() {
        XCTAssertNil(SemanticVersion("1.2.x"))
    }

    func testRejectsSurroundingWhitespace() {
        XCTAssertNil(SemanticVersion(" v1.2.3 "))
    }

    func testRejectsSecondLeadingV() {
        XCTAssertNil(SemanticVersion("vv1.2.3"))
    }

    // MARK: - Ordering

    func testMinorTenIsGreaterThanMinorNine() throws {
        let newer = try XCTUnwrap(SemanticVersion("1.10.0"))
        let older = try XCTUnwrap(SemanticVersion("1.9.0"))
        XCTAssertGreaterThan(newer, older)
    }

    func testMajorTwoIsGreaterThanMajorOne() throws {
        let newer = try XCTUnwrap(SemanticVersion("2.0.0"))
        let older = try XCTUnwrap(SemanticVersion("1.99.99"))
        XCTAssertGreaterThan(newer, older)
    }

    func testPatchOneIsGreaterThanPatchZero() throws {
        let newer = try XCTUnwrap(SemanticVersion("1.0.1"))
        let older = try XCTUnwrap(SemanticVersion("1.0.0"))
        XCTAssertGreaterThan(newer, older)
    }

    func testEqualVersionsAreNotGreater() throws {
        let left = try XCTUnwrap(SemanticVersion("1.4.0"))
        let right = try XCTUnwrap(SemanticVersion("v1.4.0"))
        XCTAssertFalse(left > right, "equal versions must not compare greater")
        XCTAssertFalse(right > left, "equal versions must not compare greater")
        XCTAssertEqual(left, right)
    }
}
