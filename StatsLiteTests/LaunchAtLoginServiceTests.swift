//
//  LaunchAtLoginServiceTests.swift
//  StatsLiteTests
//
//  Covers the `SMAppService.Status` to `LaunchAtLoginService.State` mapping.
//  `.notFound` means an empty login-item record on this OS (2026-10-17 probe
//  measurement in the plan), so it must map to `.notRegistered` and never
//  lock the Settings toggle.
//

import XCTest
@testable import StatsLite

@MainActor
final class LaunchAtLoginServiceTests: XCTestCase {

    func testNotFoundMapsToNotRegistered() {
        XCTAssertEqual(LaunchAtLoginService.map(.notFound), .notRegistered)
    }

    func testNotRegisteredMapsToNotRegistered() {
        XCTAssertEqual(LaunchAtLoginService.map(.notRegistered), .notRegistered)
    }

    func testEnabledMapsToEnabled() {
        XCTAssertEqual(LaunchAtLoginService.map(.enabled), .enabled)
    }

    func testRequiresApprovalMapsToApprovalNeeded() {
        XCTAssertEqual(LaunchAtLoginService.map(.requiresApproval), .approvalNeeded)
    }
}
