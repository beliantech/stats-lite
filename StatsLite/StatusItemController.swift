//
//  StatusItemController.swift
//  StatsLite
//
//  Custom NSStatusItem replaces MenuBarExtra, which flattens its
//  label into the status button title and cannot render the stacked
//  block layout. The button hosts a hitTest-nil NSHostingView with
//  MenuBarStackedItemView. The hosting view pins with frame-based
//  layout, not constraints: sizingOptions = [] and an autoresizing
//  mask of [.width, .height] track button.bounds, so a
//  statusItem.length change on a metric toggle resizes the view
//  with no clipping and no per-tick constraint churn. Clicks toggle a transient
//  NSPopover with the unchanged PopoverContentView. A 0.25 s
//  debounce on popoverDidClose stops the transient-reopen race: the
//  popover closes on the button's own click before the action fires,
//  so isShown alone would read false and reopen instantly.
//

import AppKit
import SwiftUI

/// Hosting view that lets clicks fall through to the status button.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {

    private let monitor: SystemMonitor
    private let preferences: PreferencesStore
    private let statusItem: NSStatusItem

    /// Internal so popover lifecycle tests can inspect the mount.
    let popover: NSPopover

    /// systemUptime of the last popover close. togglePopover()
    /// ignores clicks inside the debounce window.
    private var lastCloseTimestamp: TimeInterval = 0

    /// Internal so layout tests can inspect the hosting view.
    var button: NSStatusBarButton? { statusItem.button }

    init(monitor: SystemMonitor, preferences: PreferencesStore) {
        self.monitor = monitor
        self.preferences = preferences
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: MenuBarLayout.length(
                showCPU: preferences.showCPU,
                showRAM: preferences.showRAM,
                showGPU: preferences.showGPU,
                showNetwork: preferences.showNetwork
            )
        )

        let popover = NSPopover()
        popover.behavior = .transient
        self.popover = popover

        super.init()

        popover.delegate = self

        guard let button else { return }
        let rootView = MenuBarStackedItemView(
            monitor: monitor,
            preferences: preferences,
            onPreferencesChange: { [weak self] in
                self?.updateItemLength()
                self?.updateAccessibility()
            },
            onSnapshotChange: { [weak self] in
                self?.updateAccessibility()
            }
        )
        let hostingView = PassthroughHostingView(rootView: rootView)
        // Frame-based layout only. sizingOptions = [] keeps the
        // hosting view from resizing to its intrinsic content; the
        // autoresizing mask follows button.bounds, so a
        // statusItem.length change resizes the view with no clipping
        // and no per-tick constraint churn (AC-11).
        hostingView.sizingOptions = []
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = button.bounds
        button.addSubview(hostingView)

        button.target = self
        button.action = #selector(togglePopover(_:))

        updateAccessibility()
    }

    // MARK: - Popover toggle

    @objc private func togglePopover(_ sender: Any?) {
        if ProcessInfo.processInfo.systemUptime - lastCloseTimestamp < 0.25 {
            return
        }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        guard let button else { return }
        button.isHighlighted = true
        // Mount only when about to show and no controller is held.
        // Keeps the hosting controller out of init so no popover
        // view evaluates while the popover stays closed.
        if popover.contentViewController == nil {
            popover.contentViewController = NSHostingController(
                rootView: PopoverContentView(
                    monitor: monitor,
                    preferences: preferences
                )
            )
        }
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
    }

    func popoverDidClose(_ notification: Notification) {
        lastCloseTimestamp = ProcessInfo.processInfo.systemUptime
        button?.isHighlighted = false
        // Release the controller so no popover view evaluates while
        // closed. @State in PopoverContentView (coresExpanded) resets
        // on close by design.
        popover.contentViewController = nil
    }

    // MARK: - Observation targets (plan Task 6)

    /// Resizes the status item to the enabled-metrics permutation.
    /// The stacked view calls this when preferences change.
    func updateItemLength() {
        statusItem.length = MenuBarLayout.length(
            showCPU: preferences.showCPU,
            showRAM: preferences.showRAM,
            showGPU: preferences.showGPU,
            showNetwork: preferences.showNetwork
        )
    }

    /// Re-arms the VoiceOver label on the button. The hosting view
    /// is hitTest-nil, so the SwiftUI side is hidden from VoiceOver.
    /// The stacked view calls this when preferences or the snapshot
    /// change. Same value paths and pressure derivation the old
    /// MenuBarItemView used.
    func updateAccessibility() {
        button?.setAccessibilityElement(true)
        button?.setAccessibilityTitle("Stats Lite")
        button?.setAccessibilityLabel(compositeLabel)
    }

    /// "Stats Lite: CPU 14 percent, Memory Pressure Normal at 25
    /// percent, GPU 28 percent, Network Download 720 KB/s, Upload 10
    /// KB/s" from the latest snapshot and network pass.
    private var compositeLabel: String {
        let snapshot = monitor.latestSnapshot
        let pressure = snapshot?.memoryPressure
        let pressureState = (pressure?.state ?? .unknown)
            .displayState(pressure: pressure?.pressurePercentage ?? 0)
        return MenuBarAccessibility.compositeLabel(
            showCPU: preferences.showCPU,
            showRAM: preferences.showRAM,
            showGPU: preferences.showGPU,
            showNetwork: preferences.showNetwork,
            cpuPercent: snapshot?.cpu?.totalUsage,
            pressurePercent: pressure?.pressurePercentage,
            pressure: pressureState,
            gpuPercent: snapshot?.gpu?.deviceUtilization,
            downloadRate: monitor.latestNetwork?.downloadBytesPerSecond,
            uploadRate: monitor.latestNetwork?.uploadBytesPerSecond
        )
    }
}
