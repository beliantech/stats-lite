//
//  StatusItemControllerPopoverTests.swift
//  StatsLiteTests
//
//  Popover lifecycle (plan Phase 1): init must not build the
//  hosting controller, the first open mounts it, a close releases
//  it, and a later open mounts a fresh one. The re-entrancy guard
//  must survive a rapid open/close pair without a crash.
//

import AppKit
import XCTest
@testable import StatsLite

@MainActor
final class StatusItemControllerPopoverTests: XCTestCase {

    /// Drives the status button's private @objc action the same way
    /// AppKit does when the button is clicked.
    private func toggle(_ controller: StatusItemController) {
        controller.perform(Selector(("togglePopover:")), with: nil)
    }

    /// Runs the run loop for a fixed interval.
    private func spinRunLoop(for seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    /// Polls until the popover is onscreen.
    private func waitUntilShown(
        _ popover: NSPopover,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let shown = expectation(
            for: NSPredicate(format: "isShown == true"),
            evaluatedWith: popover
        )
        wait(for: [shown], timeout: 5)
        XCTAssertTrue(popover.isShown, file: file, line: line)
    }

    /// Polls until the popover drops its content controller, which
    /// only happens from popoverDidClose(_:).
    private func waitUntilContentReleased(
        _ popover: NSPopover,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let released = expectation(
            for: NSPredicate(format: "contentViewController == nil"),
            evaluatedWith: popover
        )
        wait(for: [released], timeout: 5)
        XCTAssertNil(popover.contentViewController, file: file, line: line)
    }

    /// Clicks once and confirms the popover is onscreen. The first
    /// show in the test host can race the status bar scene
    /// connection, so one retry click is allowed.
    private func open(
        _ controller: StatusItemController,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let popover = controller.popover
        toggle(controller)
        spinRunLoop(for: 0.2)
        if !popover.isShown {
            toggle(controller)
        }
        waitUntilShown(popover, file: file, line: line)
    }

    func testInitDoesNotMountPopoverContent() {
        let controller = StatusItemController(
            monitor: SystemMonitor(),
            preferences: PreferencesStore()
        )
        XCTAssertNil(
            controller.popover.contentViewController,
            "init must not create the hosting controller"
        )
    }

    func testTogglePopoverCyclesMountAndRelease() {
        let controller = StatusItemController(
            monitor: SystemMonitor(),
            preferences: PreferencesStore()
        )
        let popover = controller.popover
        // Close teardown must not depend on the display link: with the
        // display asleep, animated teardown never completes.
        popover.animates = false
        XCTAssertNil(popover.contentViewController)

        // Warm-up: let the test host connect the status bar scene
        // before the first show.
        let warm = expectation(description: "warm-up")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { warm.fulfill() }
        wait(for: [warm], timeout: 3)

        // First open mounts the hosting controller lazily.
        open(controller)
        let first = popover.contentViewController
        XCTAssertNotNil(first, "first open must mount the hosting controller")

        // Second click right after the open requests a close.
        toggle(controller)
        waitUntilContentReleased(popover)

        // Past the 0.25 s guard a reopen mounts a fresh controller.
        Thread.sleep(forTimeInterval: 0.35)
        open(controller)
        let second = popover.contentViewController
        XCTAssertNotNil(second, "reopen must remount the hosting controller")
        XCTAssertFalse(
            second === first,
            "each open cycle gets a fresh hosting controller"
        )

        toggle(controller)
        waitUntilContentReleased(popover)
    }
}
