//
//  PreferencesStore.swift
//  StatsLite
//
//  Persisted Settings state. Observable stored properties drive SwiftUI,
//  @AppStorage properties hold the UserDefaults keys. The last-one-
//  enabled guard re-enables a toggle that would leave zero metrics on,
//  and init repairs a corrupted all-false state.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class PreferencesStore {

    /// True while init seeds the observable state from storage. The
    /// @Observable macro routes init assignments through the computed
    /// setter, so didSet fires during seeding. The flag keeps the guard
    /// and the storage write out of that phase.
    @ObservationIgnored private var isSeeding = true

    // MARK: - Visible metrics (last-one-enabled guard)

    var showCPU: Bool = true {
        didSet {
            guard !isSeeding else { return }
            if !showCPU && activeMetricCount == 0 { showCPU = true }
            showCPUStorage = showCPU
        }
    }

    var showRAM: Bool = true {
        didSet {
            guard !isSeeding else { return }
            if !showRAM && activeMetricCount == 0 { showRAM = true }
            showRAMStorage = showRAM
        }
    }

    var showGPU: Bool = true {
        didSet {
            guard !isSeeding else { return }
            if !showGPU && activeMetricCount == 0 { showGPU = true }
            showGPUStorage = showGPU
        }
    }

    /// Network block visibility (D3). Outside `enabledMetrics`: no
    /// guard and no lock, so it never changes `activeMetricCount`.
    var showNetwork: Bool = true {
        didSet {
            guard !isSeeding else { return }
            showNetworkStorage = showNetwork
        }
    }

    /// Temperature row visibility. Ships ON when the key is absent,
    /// mirroring the `showNetwork` default (F2).
    var showTemperature: Bool = true

    // MARK: - Sampling and history

    /// Refresh interval in seconds. The picker offers 1, 2, 3, and 5.
    var refreshInterval: Int = 1 {
        didSet {
            guard !isSeeding else { return }
            refreshIntervalStorage = refreshInterval
        }
    }

    /// Sparkline window in seconds. The picker offers 30, 60, 120, 180, and 300.
    var historyDuration: Int = 60 {
        didSet {
            guard !isSeeding else { return }
            historyDurationStorage = historyDuration
        }
    }

    // MARK: - Display options

    var showCoreBreakdown: Bool = true {
        didSet {
            guard !isSeeding else { return }
            showCoreBreakdownStorage = showCoreBreakdown
        }
    }

    // MARK: - Derived state

    /// Number of visible metrics. The guard uses this value; the
    /// Settings UI disables the sole ON toggle at 1.
    var activeMetricCount: Int {
        (showCPU ? 1 : 0) + (showRAM ? 1 : 0) + (showGPU ? 1 : 0)
    }

    /// True when `isOn` reports the state of the only enabled metric
    /// toggle. The Settings UI renders that toggle disabled in the
    /// ON position (VAC-24).
    func isToggleLocked(_ isOn: Bool) -> Bool {
        activeMetricCount == 1 && isOn
    }

    /// Toggle set handed to the sampler.
    var enabledMetrics: EnabledMetrics {
        var enabled: EnabledMetrics = []
        if showCPU { enabled.insert(.cpu) }
        if showRAM { enabled.insert(.memory) }
        if showGPU { enabled.insert(.gpu) }
        if showTemperature { enabled.insert(.temperature) }
        return enabled
    }

    // MARK: - Persistence

    @ObservationIgnored @AppStorage("showCPU") private var showCPUStorage: Bool = true
    @ObservationIgnored @AppStorage("showRAM") private var showRAMStorage: Bool = true
    @ObservationIgnored @AppStorage("showGPU") private var showGPUStorage: Bool = true
    @ObservationIgnored @AppStorage("showNetwork") private var showNetworkStorage: Bool = true
    @ObservationIgnored @AppStorage("refreshInterval") private var refreshIntervalStorage: Int = 1
    @ObservationIgnored @AppStorage("historyDuration") private var historyDurationStorage: Int = 60
    @ObservationIgnored @AppStorage("showCoreBreakdown") private var showCoreBreakdownStorage: Bool = true

    /// Seeds the observable state from UserDefaults while `isSeeding`
    /// suppresses the didSet bodies. When all three keys are false,
    /// the repair after seeding turns showCPU back on.
    init() {
        showCPU = showCPUStorage
        showRAM = showRAMStorage
        showGPU = showGPUStorage
        showNetwork = showNetworkStorage
        refreshInterval = refreshIntervalStorage
        historyDuration = historyDurationStorage
        showCoreBreakdown = showCoreBreakdownStorage
        isSeeding = false

        if activeMetricCount == 0 {
            showCPU = true
            showCPUStorage = true
        }
    }
}
