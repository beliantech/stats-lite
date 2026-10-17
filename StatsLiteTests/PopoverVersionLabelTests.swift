//
//  PopoverVersionLabelTests.swift
//  StatsLiteTests
//
//  Popover footer version label (plan 2026-10-17-popover-drop-gauge-version-footer).
//  The pure seam covers formatting without a bundle; the bundle-sourced
//  label must match the required pattern.
//

import XCTest
@testable import StatsLite

final class PopoverVersionLabelTests: XCTestCase {

    func testPureVersionLabelFormatsBuild1() {
        let label = PopoverContentView.versionLabel(version: "1.0.0", build: "1")
        XCTAssertEqual(label, "v1.0.0 (1)")
    }

    func testPureVersionLabelFormatsBuild9999() {
        let label = PopoverContentView.versionLabel(version: "1.0.0", build: "9999")
        XCTAssertEqual(label, "v1.0.0 (9999)")
    }

    func testPureVersionAccessibilityLabel() {
        let label = PopoverContentView.versionAccessibilityLabel(version: "1.0.0", build: "1")
        XCTAssertEqual(label, "Version 1.0.0, build 1")
    }

    func testBundleSourcedVersionLabelMatchesPattern() {
        let label = PopoverContentView.versionLabel()
        let pattern = #"^v[0-9][0-9.]* \([0-9]+\)$"#
        XCTAssertNotNil(
            label.range(of: pattern, options: .regularExpression),
            "Version label must match 'v<version> (<build>)', got: \(label)"
        )
    }
}
