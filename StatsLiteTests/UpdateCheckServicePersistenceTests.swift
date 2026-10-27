//
//  UpdateCheckServicePersistenceTests.swift
//  StatsLiteTests
//
//  Dismiss round-trip on the coordinator seam (plan 2026-10-20
//  in-app-update-check, T1; rewritten for T3b after the GitHub
//  poller retirement). The banner is published through
//  publishAvailableUpdate instead of a release source, so no test
//  in this file reaches the network or a fake source. The key
//  strings mirror UpdateCheckService's constants; literals avoid a
//  main-actor-isolated global initializer. setUp and tearDown reset
//  the shared keys around every test.
//

import Foundation
import XCTest
@testable import StatsLite

/// UserDefaults keys owned by these tests, plus the reset helper. The
/// helper is a free function so the nonisolated setUp/tearDown
/// overrides can call it without an actor-isolation warning.
private let serviceKeys = [
    "updateCheckDismissedVersion",
]

private func clearServiceKeys() {
    for key in serviceKeys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

@MainActor
final class UpdateCheckServicePersistenceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearServiceKeys()
    }

    override func tearDown() {
        clearServiceKeys()
        super.tearDown()
    }

    private let notesURL = URL(
        string: "https://example.com/releases/9.9.9"
    )!

    // MARK: - Dismiss round-trip

    @MainActor
    func testDismissRoundTripPersistsNormalizedVersion() {
        let service = UpdateCheckService()
        service.publishAvailableUpdate(
            displayVersion: "v9.9.9",
            releaseNotesURL: notesURL
        )
        XCTAssertEqual(
            service.availableUpdate?.version,
            SemanticVersion("9.9.9")
        )

        service.dismiss(version: "v9.9.9")

        XCTAssertNil(service.availableUpdate, "dismiss clears the prompted update")
        XCTAssertTrue(service.isDismissed(version: "9.9.9"))
        XCTAssertTrue(service.isDismissed(version: "v9.9.9"))
        XCTAssertEqual(
            UserDefaults.standard.string(
                forKey: UpdateCheckService.dismissedVersionKey
            ),
            "9.9.9",
            "the stored key is the normalized description with no v prefix"
        )
    }

    @MainActor
    func testIsDismissedIsFalseWhenNoVersionWasDismissed() {
        let service = UpdateCheckService()
        XCTAssertFalse(service.isDismissed(version: "1.2.3"))
    }

    /// VAC-15: the dismissal outlives the service instance. A fresh
    /// coordinator over the same UserDefaults keeps the version
    /// hidden, so a relaunch or a popover reopen stays suppressed.
    @MainActor
    func testDismissPersistsAcrossServiceInstances() {
        let first = UpdateCheckService()
        first.publishAvailableUpdate(
            displayVersion: "9.9.9",
            releaseNotesURL: notesURL
        )
        first.dismiss(version: "9.9.9")

        let second = UpdateCheckService()
        XCTAssertTrue(
            second.isDismissed(version: "9.9.9"),
            "the stored dismissal must survive a new service instance"
        )
        second.publishAvailableUpdate(
            displayVersion: "9.9.9",
            releaseNotesURL: notesURL
        )
        XCTAssertNil(
            second.availableUpdate,
            "a dismissed version must not republish through a new instance"
        )
    }
}
