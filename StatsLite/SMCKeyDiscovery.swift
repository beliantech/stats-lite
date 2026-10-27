//
//  SMCKeyDiscovery.swift
//  StatsLite
//
//  Runtime SMC temperature key discovery (plan
//  2026-10-27-runtime-smc-key-discovery). The machine's own SMC key
//  table is enumerated once per launch, filtered by exact prefix
//  domain, and cached in memory. No per-machine or per-generation key
//  list lives in production code. The seam splits into: the
//  enumerator (`#KEY`/index scan), the domain resolver
//  (`domain(forPrefix:)`), and the sampler (reads cached table keys
//  only).
//

import Foundation
import IOKit

// MARK: - Seam

/// One enumerated SMC key's identity and GetKeyInfo result.
struct SMCKeyDescriptor {
    let name: String
    let type: String
    let size: UInt32
}

/// Enumeration and read seam over the AppleSMC user client.
/// `keyCount`/`keyName`/`keyInfo` belong to the launch-time table
/// build; `readFloat` belongs to per-sample reads. `readFloat`
/// decodes only: plausibility (finite, -20...130 °C) is the
/// discovery filter's job, never the reader's.
protocol SMCKeyEnumerating: Sendable {
    /// The `#KEY` key count. nil when `#KEY` is unreadable.
    func keyCount() -> UInt32?
    /// The key name at one enumeration index. nil when the read fails.
    func keyName(at index: UInt32) -> String?
    /// Type and size for one key. nil when the read fails.
    func keyInfo(name: String) -> (type: String, size: UInt32)?
    /// One decoded `flt ` value with no plausibility applied.
    /// nil when the read fails.
    func readFloat(name: String) -> Double?
}

/// The temperature domain a key prefix attributes to.
enum TemperatureDomain: Sendable {
    case cpu
    case gpu
}

/// The one attribution seam: exact, case-sensitive, two-character
/// prefixes only. "Tg" is the GPU family, "Tp" the CPU family, and
/// everything else ("TG", "tp", "TVD", "Tm", "T", "") stays
/// unattributed.
func domain(forPrefix prefix: String) -> TemperatureDomain? {
    switch prefix {
    case "Tg":
        return .gpu
    case "Tp":
        return .cpu
    default:
        return nil
    }
}

// MARK: - Cached key table

/// The cached key table, built once per launch. It keeps only keys of
/// type `flt ` and size 4 (the only family the read path decodes),
/// grouped by the two-character prefix through `domain(forPrefix:)`.
struct TemperatureKeyTable: Sendable {
    let cpuKeys: [String]
    let gpuKeys: [String]

    init(enumerator: SMCKeyEnumerating) {
        var cpu: [String] = []
        var gpu: [String] = []
        for name in Self.enumeratedNames(using: enumerator) {
            // The prefix check costs nothing; keyInfo is an SMC call,
            // so unattributed families never reach it.
            guard let temperatureDomain = domain(forPrefix: String(name.prefix(2)))
            else { continue }
            guard let info = enumerator.keyInfo(name: name) else { continue }
            let descriptor = SMCKeyDescriptor(name: name, type: info.type, size: info.size)
            guard descriptor.type == "flt ", descriptor.size == 4 else { continue }
            switch temperatureDomain {
            case .cpu:
                cpu.append(descriptor.name)
            case .gpu:
                gpu.append(descriptor.name)
            }
        }
        cpuKeys = cpu
        gpuKeys = gpu
    }

    /// Every key name the machine exposes. The `#KEY` count path when
    /// `#KEY` is readable; otherwise the consecutive-failure index
    /// scan (pattern: `tools/smc-probe/main.swift` `loadKeyTable`).
    private static func enumeratedNames(using enumerator: SMCKeyEnumerating) -> [String] {
        if let count = enumerator.keyCount(), count > 0, count <= 16384 {
            var names: [String] = []
            names.reserveCapacity(Int(count))
            for index in 0..<count {
                if let name = enumerator.keyName(at: index) {
                    names.append(name)
                }
            }
            return names
        }

        // Fallback: scan indices until 64 consecutive name-read
        // failures. The scan stops at 16384 to bound a broken driver.
        var names: [String] = []
        var missRun = 0
        var index: UInt32 = 0
        while missRun < 64, index < 16384 {
            if let name = enumerator.keyName(at: index) {
                names.append(name)
                missRun = 0
            } else {
                missRun += 1
            }
            index += 1
        }
        return names
    }
}

// MARK: - Per-launch discovery

/// The per-launch discovery state. The key table is enumerated
/// exactly once, here at init; `sample()` then reads only the cached
/// table keys through `readFloat` (FM4: enumeration never runs on the
/// sampler's hot path).
final class TemperatureKeyDiscovery: @unchecked Sendable {
    /// The cached table built at init, exposed so FM4 can prove
    /// enumeration stays off the sample path.
    let keyTable: TemperatureKeyTable

    private let enumerator: SMCKeyEnumerating
    /// Guards the trailing series. The lock makes the
    /// `@unchecked Sendable` claim honest: every mutable field is
    /// reachable only while the lock is held.
    private let lock = NSLock()
    /// Trailing 60-tick series of plausible readings per cached key.
    private var series: [String: [Double]] = [:]
    private static let seriesWindow = 60
    /// A key counts as moved once its own series spans at least this
    /// many °C inside the trailing window (FM3 movement filter).
    private static let movementThreshold: Double = 2

    init(enumerator: SMCKeyEnumerating) {
        self.enumerator = enumerator
        self.keyTable = TemperatureKeyTable(enumerator: enumerator)
    }

    /// One sampler tick: read every cached key once, drop implausible
    /// readings, then aggregate per domain. Before any key in a
    /// domain has moved at least 2 °C within its trailing 60 ticks,
    /// the domain max covers every prefix+plausibility key, so a
    /// working machine never renders blank by construction. Once one
    /// key in the domain has moved, only moved keys feed the max.
    /// Returns nil when neither domain has a plausible reading this
    /// tick (nil contract: the caller renders `--°`).
    func sample() -> TemperatureMetrics? {
        lock.lock()
        defer { lock.unlock() }

        var cpuReadings: [String: Double] = [:]
        var gpuReadings: [String: Double] = [:]

        for name in keyTable.cpuKeys {
            guard let value = plausibleReading(name) else { continue }
            cpuReadings[name] = value
            appendToSeries(value, for: name)
        }
        for name in keyTable.gpuKeys {
            guard let value = plausibleReading(name) else { continue }
            gpuReadings[name] = value
            appendToSeries(value, for: name)
        }

        let cpu = aggregate(keys: keyTable.cpuKeys, readings: cpuReadings)
        let gpu = aggregate(keys: keyTable.gpuKeys, readings: gpuReadings)
        guard cpu != nil || gpu != nil else { return nil }
        return TemperatureMetrics(cpuCelsius: cpu, gpuCelsius: gpu)
    }

    /// One decoded reading inside the -20...130 °C band. A non-finite
    /// or out-of-band decode drops for this tick; it never reaches
    /// the aggregate or the series.
    private func plausibleReading(_ name: String) -> Double? {
        guard let value = enumerator.readFloat(name: name),
              value.isFinite,
              (-20...130).contains(value)
        else { return nil }
        return value
    }

    /// The domain max for one tick, applying the movement filter.
    private func aggregate(keys: [String], readings: [String: Double]) -> Double? {
        guard !readings.isEmpty else { return nil }
        let filterActive = keys.contains { hasMoved($0) }
        var hottest: Double?
        for name in keys {
            guard let value = readings[name] else { continue }
            if filterActive && !hasMoved(name) { continue }
            hottest = hottest.map { max($0, value) } ?? value
        }
        return hottest
    }

    /// True once this key's own series spans at least 2 °C inside the
    /// trailing window. A single reading cannot move, so the first
    /// tick never activates the filter.
    private func hasMoved(_ name: String) -> Bool {
        guard let values = series[name],
              values.count >= 2,
              let lowest = values.min(),
              let highest = values.max()
        else { return false }
        return highest - lowest >= Self.movementThreshold
    }

    private func appendToSeries(_ value: Double, for name: String) {
        var values = series[name] ?? []
        values.append(value)
        if values.count > Self.seriesWindow {
            values.removeFirst(values.count - Self.seriesWindow)
        }
        series[name] = values
    }
}

// MARK: - Live enumerator

/// The live `SMCKeyEnumerating` over the AppleSMC user client. The
/// connection opens lazily and stays cached, so enumeration and
/// per-sample reads never pay an open/close cycle (FM4; plan T5
/// measures the cost). A transport failure closes the stale
/// connection, reopens it, and retries the call once: that is the
/// only recovery path, so a connection invalidated for example by
/// sleep cannot poison later samples. An SMC-level failure (nonzero
/// result byte) is the firmware's answer to that key: nil, no
/// reopen.
final class AppleSMCKeyEnumerator: SMCKeyEnumerating, @unchecked Sendable {
    private let lock = NSLock()
    private var connection: io_connect_t?

    deinit {
        if let connection {
            IOServiceClose(connection)
        }
    }

    func keyCount() -> UInt32? {
        let key = Self.fourCC("#KEY")
        guard
            let info = call(command: .getKeyInfo, key: key),
            info.keyInfo.dataSize == 4,
            let output = call(command: .readKey, key: key, dataSize: 4)
        else { return nil }
        // The count is a big-endian UInt32, same as the probe reads it.
        var count: UInt32 = 0
        withUnsafeBytes(of: output.bytes) { bytes in
            guard bytes.count >= 4 else { return }
            count = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16)
                | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
        }
        return count
    }

    func keyName(at index: UInt32) -> String? {
        guard let output = call(command: .getKeyFromIndex, key: 0, index: index)
        else { return nil }
        return Self.fourCCString(output.key)
    }

    func keyInfo(name: String) -> (type: String, size: UInt32)? {
        guard let output = call(command: .getKeyInfo, key: Self.fourCC(name))
        else { return nil }
        return (Self.fourCCString(output.keyInfo.dataType), output.keyInfo.dataSize)
    }

    func readFloat(name: String) -> Double? {
        // Type and size are re-checked per read: a wrong type or size
        // is a read failure, not plausibility. The range filter stays
        // in the discovery layer, so this reader can hand back a raw
        // out-of-range decode and the filter drops it.
        let key = Self.fourCC(name)
        guard
            let info = call(command: .getKeyInfo, key: key),
            info.keyInfo.dataSize == 4,
            info.keyInfo.dataType == Self.fourCC("flt "),
            let output = call(command: .readKey, key: key, dataSize: 4)
        else { return nil }
        var raw: UInt32 = 0
        withUnsafeBytes(of: output.bytes) { bytes in
            guard bytes.count >= 4 else { return }
            raw = UInt32(bytes[0])
                | (UInt32(bytes[1]) << 8)
                | (UInt32(bytes[2]) << 16)
                | (UInt32(bytes[3]) << 24)
        }
        return Double(Float(bitPattern: raw))
    }

    // MARK: SMC plumbing

    private enum CallOutcome {
        case success(SMCParamStruct)
        case smcFailure
        case transportFailure
    }

    /// One SMC command on the cached connection. A transport failure
    /// closes the stale connection, reopens it, and retries once.
    private func call(
        command: SMCCommand,
        key: UInt32,
        dataSize: UInt32 = 0,
        index: UInt32 = 0
    ) -> SMCParamStruct? {
        lock.lock()
        defer { lock.unlock() }

        if let existing = connection {
            switch Self.perform(
                existing, command: command, key: key, dataSize: dataSize, index: index
            ) {
            case .success(let output):
                return output
            case .smcFailure:
                return nil
            case .transportFailure:
                IOServiceClose(existing)
                connection = nil
            }
        }
        guard let reopened = openLocked() else { return nil }
        switch Self.perform(
            reopened, command: command, key: key, dataSize: dataSize, index: index
        ) {
        case .success(let output):
            return output
        case .smcFailure, .transportFailure:
            return nil
        }
    }

    private static func perform(
        _ connection: io_connect_t,
        command: SMCCommand,
        key: UInt32,
        dataSize: UInt32,
        index: UInt32
    ) -> CallOutcome {
        var input = SMCParamStruct()
        input.key = key
        input.keyInfo.dataSize = dataSize
        input.data8 = command.rawValue
        input.data32 = index

        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let result = IOConnectCallStructMethod(
            connection,
            smcSelector,
            &input,
            MemoryLayout<SMCParamStruct>.stride,
            &output,
            &outputSize
        )
        guard result == KERN_SUCCESS else { return .transportFailure }
        guard output.result == 0 else { return .smcFailure }
        return .success(output)
    }

    /// Opens and caches the AppleSMC user-client connection. nil when
    /// the service is missing or the open fails. Callers hold `lock`.
    private func openLocked() -> io_connect_t? {
        var iterator: io_iterator_t = 0
        // IOServiceGetMatchingServices consumes the matching
        // dictionary: never release it.
        let lookup = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC"),
            &iterator
        )
        guard lookup == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var opened: io_connect_t = 0
        // The owning task must be mach_task_self_, never 0: a null
        // task comes back as kIOReturnNotPrivileged (0xe00002c2),
        // measured in Phase 0.
        guard IOServiceOpen(service, mach_task_self_, 0, &opened) == KERN_SUCCESS
        else { return nil }
        connection = opened
        return opened
    }

    /// Four-character SMC key as a big-endian UInt32 ("Tp00" ->
    /// 0x54703030).
    private static func fourCC(_ name: String) -> UInt32 {
        var value: UInt32 = 0
        for byte in Array(name.utf8.prefix(4)) {
            value = (value << 8) | UInt32(byte)
        }
        return value
    }

    private static func fourCCString(_ value: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff),
        ]
        guard let text = String(bytes: bytes, encoding: .isoLatin1) else {
            return String(format: "%08x", value)
        }
        return text
    }
}

// MARK: - SMC user-client plumbing (plan 2026-10-23-temp-menu-bar-metric)

/// SMC user-client commands used by enumeration and the temperature
/// read (Phase 0 probe, `tools/smc-probe/main.swift`).
private enum SMCCommand: UInt8 {
    case readKey = 5
    case getKeyFromIndex = 8
    case getKeyInfo = 9
}

private let smcSelector: UInt32 = 2 // kSMCHandleYPCEvent

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

/// The 80-byte SMC parameter block, byte-for-byte the layout the
/// Phase 0 probe verified on this machine: size 80, key at 0,
/// keyInfo at 28, result at 40, status at 41, data8 at 42, data32 at
/// 44, bytes at 48. The explicit `padding: UInt16` field holds those
/// offsets against the classic C struct.
private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}
