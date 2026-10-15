//
//  StatsLiteTests.swift
//  StatsLiteTests
//
//  Smoke test for the scaffold. It proves that the test bundle compiles,
//  links against the app target, and loads the StatsLite module.
//

import XCTest
@testable import StatsLite

final class StatsLiteTests: XCTestCase {
    func testAppModuleIsImportable() {
        XCTAssertEqual(String(describing: StatsLiteApp.self), "StatsLiteApp")
    }
}
