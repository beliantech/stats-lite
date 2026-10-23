//
//  LiveSystemMetricsProvider.swift
//  StatsLite
//
//  Real sampler: Mach host stats for CPU and RAM, IOKit for GPU,
//  sysctl for memory pressure. Every acquired resource has a matching
//  `defer` cleanup registered in the same scope where the resource is
//  acquired. No force-unwraps: every failed read returns `nil` or falls
//  back to the unknown pressure state.
//

import Foundation
import IOKit

struct LiveSystemMetricsProvider: SystemMetricsProvider {

    // MARK: - CPU (host_processor_info)

    func sampleCPUTicks() -> CPUTicks? {
        // mach_host_self() returns a send right. Release it after the call.
        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, hostPort) }

        var coreCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            hostPort,
            PROCESSOR_CPU_LOAD_INFO,
            &coreCount,
            &info,
            &infoCount
        )
        guard result == KERN_SUCCESS, let info else { return nil }

        // The kernel allocated `info`. Release the exact byte size the
        // kernel reported: count of integer_t entries times their stride.
        defer {
            vm_deallocate(
                mach_task_self_,
                UInt(bitPattern: OpaquePointer(info)),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        let stateStride = Int(CPU_STATE_MAX)
        var cores: [CoreTickSample] = []
        cores.reserveCapacity(Int(coreCount))
        for coreIndex in 0..<Int(coreCount) {
            let base = coreIndex * stateStride
            guard base + stateStride <= Int(infoCount) else { break }
            cores.append(
                CoreTickSample(
                    user: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)])),
                    system: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)])),
                    idle: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])),
                    nice: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
                )
            )
        }
        guard !cores.isEmpty else { return nil }
        return CPUTicks(perCore: cores)
    }

    // MARK: - RAM (host_statistics64)

    func sampleMemory() -> MemoryMetrics? {
        // mach_host_self() returns a send right. Release it after the call.
        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, hostPort) }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { statsPointer in
            statsPointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                infoPointer in
                host_statistics64(hostPort, HOST_VM_INFO64, infoPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        // Kernel page size, read at runtime through the Mach API. The page
        // size is never hardcoded. A direct read of the vm_kernel_page_size
        // global is a Swift 6 concurrency error in the current SDK, and
        // host_page_size returns the same kernel value.
        var kernelPageSize: vm_size_t = 0
        guard host_page_size(hostPort, &kernelPageSize) == KERN_SUCCESS else { return nil }
        let pageSize = UInt64(kernelPageSize)

        // Activity Monitor formula.
        let internalPages = UInt64(stats.internal_page_count)
        let purgeablePages = UInt64(stats.purgeable_count)
        let appBytes = (internalPages - min(purgeablePages, internalPages)) * pageSize
        let wiredBytes = UInt64(stats.wire_count) * pageSize
        let compressedBytes = UInt64(stats.compressor_page_count) * pageSize

        return MemoryMetrics(
            usedBytes: appBytes + wiredBytes + compressedBytes,
            totalBytes: ProcessInfo.processInfo.physicalMemory,
            appMemoryBytes: appBytes,
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes
        )
    }

    // MARK: - GPU (IOKit)

    func sampleGPU() -> GPUMetrics? {
        // IOServiceGetMatchingServices consumes the matching dictionary.
        // Never release it, and never pass a copied registry properties
        // dictionary: read the single PerformanceStatistics key only.
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOAccelerator"),
            &iterator
        )
        guard result == KERN_SUCCESS else { return nil }

        // Release the iterator after the loop, whatever path leaves it.
        defer { IOObjectRelease(iterator) }

        var statistics: [[String: Any]] = []
        while true {
            // IOIteratorNext returns a +1 object reference per iteration.
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }

            // Release this service reference at the end of this iteration.
            defer { IOObjectRelease(service) }

            // Create rule: the property call hands back +1, so
            // takeRetainedValue() consumes it. No CFRelease anywhere.
            guard
                let property = IORegistryEntryCreateCFProperty(
                    service,
                    "PerformanceStatistics" as CFString,
                    kCFAllocatorDefault,
                    0
                ),
                let report = property.takeRetainedValue() as? [String: Any]
            else { continue }

            statistics.append(report)
        }

        // nil when no device reports utilization (VM, unsupported hardware).
        return SystemMetricsParsing.gpuMetrics(fromStatistics: statistics)
    }

    // MARK: - Temperature (AppleSMC)

    /// CPU and GPU die temperatures from the AppleSMC user client
    /// (plan 2026-10-23-temp-menu-bar-metric, Phase 2). The route is
    /// the Phase 0 measured mechanism: IOServiceGetMatchingServices
    /// ("AppleSMC") -> IOServiceOpen(mach_task_self_) ->
    /// IOConnectCallStructMethod selector 2 (kSMCHandleYPCEvent) with
    /// an 80-byte SMCParamStruct. Command 9 reads the key info,
    /// command 5 reads the key bytes, and type "flt " decodes as a
    /// little-endian IEEE-754 float. No root is needed (Phase 0 H1,
    /// measured on this machine).
    ///
    /// Open, read, and close happen per sample: Phase 0 H2 measured
    /// p99 = 0.964 ms over 1000 such cycles, well inside the 1 Hz
    /// sampler pass (H2 verdict: ride the standard loop).
    ///
    /// Each row is the max across its Phase 0 candidate keys whose
    /// decode is finite and inside -20...130 °C. A missing key, a
    /// failed call, a wrong type or size, or an implausible decode
    /// drops that key only. Returns nil when the whole read fails:
    /// no service, open failure, or no plausible key at all. A
    /// subsystem with no plausible candidate stays nil inside the
    /// returned value (nil-contract header, no force-unwraps).
    func sampleTemperature() -> TemperatureMetrics? {
        var iterator: io_iterator_t = 0
        let lookup = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC"),
            &iterator
        )
        guard lookup == KERN_SUCCESS else { return nil }
        // Release the iterator after the read, whatever path leaves it.
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        // Release this service reference when the function leaves.
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        // The owning task must be mach_task_self_, never 0: a null
        // task comes back as kIOReturnNotPrivileged (0xe00002c2),
        // measured in Phase 0.
        let open = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard open == KERN_SUCCESS else { return nil }
        // Close the user-client connection when the function leaves.
        defer { IOServiceClose(connection) }

        let cpu = Self.maxPlausibleTemperature(
            connection: connection,
            keys: Self.cpuTemperatureKeys
        )
        // GPU row: unverified prior. Phase 0 measured the Tg* family
        // rising +10.2 to +10.5 °C under GPU load, about 3x its
        // cross-load response, which points at GPU die ownership,
        // but no key reached the 15 °C classification band, so 0
        // keys classify GPU-side. These candidates are the strongest
        // measured Tg responders (h1-attribution.md). An unreadable
        // GPU row keeps the "--°" fallback load-bearing.
        let gpu = Self.maxPlausibleTemperature(
            connection: connection,
            keys: Self.gpuTemperatureKeys
        )

        guard cpu != nil || gpu != nil else { return nil }
        return TemperatureMetrics(cpuCelsius: cpu, gpuCelsius: gpu)
    }

    /// The 24 CPU-side keys Phase 0 H1 measured rising 15.7 to 22.8 °C
    /// under CPU load and recovering in the cool-down
    /// (artifacts/2026-10-23-temp-menu-bar-metric/h1-attribution.md).
    private static let cpuTemperatureKeys: [String] = [
        "Tp00", "Tp0C", "TVDC", "TVDP", "Tp0X", "Tp0p", "Tp0O", "Tp0G",
        "TVD0", "Tp0g", "Tp0K", "Tp04", "TCMb", "Tp08", "Tp0y", "Tp0u",
        "Tp0d", "Tm0y", "Tm2T", "Tp0a", "Tp0U", "Tp0R", "Tp0m", "Tp0j",
    ]

    /// GPU-row candidates: the eight strongest measured Tg* responders
    /// from the Phase 0 GPU round (see sampleTemperature's
    /// unverified-prior note).
    private static let gpuTemperatureKeys: [String] = [
        "Tg6I", "Tg76", "Tg5R", "Tg4e", "Tg4h", "Tg12", "Tg08", "Tg6L",
    ]

    /// Highest plausible reading across the candidate keys. nil when
    /// no candidate decodes to a plausible temperature.
    private static func maxPlausibleTemperature(
        connection: io_connect_t,
        keys: [String]
    ) -> Double? {
        var hottest: Double?
        for name in keys {
            guard let value = readSMCTemperature(connection: connection, key: name)
            else { continue }
            hottest = hottest.map { max($0, value) } ?? value
        }
        return hottest
    }

    /// One SMC key read: GetKeyInfo (command 9) then ReadKey
    /// (command 5), type "flt " decoded little-endian. nil when the
    /// call fails, the key is missing (SMC result 132), the type or
    /// size is unexpected, or the decode is not a plausible
    /// temperature. Missing keys are the normal case across the
    /// candidate lists, so a miss is a quiet nil, never a trap.
    private static func readSMCTemperature(
        connection: io_connect_t,
        key: String
    ) -> Double? {
        let fourCCKey = Self.fourCC(key)
        guard
            let info = smcCall(
                connection: connection,
                command: .getKeyInfo,
                key: fourCCKey,
                dataSize: 0
            ),
            info.keyInfo.dataSize == 4,
            info.keyInfo.dataType == Self.fourCC("flt "),
            let output = smcCall(
                connection: connection,
                command: .readKey,
                key: fourCCKey,
                dataSize: 4
            )
        else { return nil }

        var raw: UInt32 = 0
        withUnsafeBytes(of: output.bytes) { bytes in
            guard bytes.count >= 4 else { return }
            raw = UInt32(bytes[0])
                | (UInt32(bytes[1]) << 8)
                | (UInt32(bytes[2]) << 16)
                | (UInt32(bytes[3]) << 24)
        }
        let value = Double(Float(bitPattern: raw))
        guard value.isFinite, (-20...130).contains(value) else { return nil }
        return value
    }

    /// One SMC user-client call: an 80-byte in/out SMCParamStruct on
    /// selector 2. nil when the kern_return fails or the SMC result
    /// byte is not success (132 = key not found is the common miss).
    private static func smcCall(
        connection: io_connect_t,
        command: SMCCommand,
        key: UInt32,
        dataSize: UInt32
    ) -> SMCParamStruct? {
        var input = SMCParamStruct()
        input.key = key
        input.keyInfo.dataSize = dataSize
        input.data8 = command.rawValue

        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let result = IOConnectCallStructMethod(
            connection,
            2,
            &input,
            MemoryLayout<SMCParamStruct>.stride,
            &output,
            &outputSize
        )
        guard result == KERN_SUCCESS, output.result == 0 else { return nil }
        return output
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

    // MARK: - Memory pressure (sysctl)

    func sampleMemoryPressure() -> MemoryPressureMetrics {
        var rawLevel: Int32 = 0
        var rawLevelSize = MemoryLayout<Int32>.size
        let levelResult = sysctlbyname(
            "kern.memorystatus_vm_pressure_level",
            &rawLevel,
            &rawLevelSize,
            nil,
            0
        )
        let levelRead =
            levelResult == 0 && rawLevelSize == MemoryLayout<Int32>.size ? rawLevel : nil

        var availability: Int32 = 0
        var availabilitySize = MemoryLayout<Int32>.size
        let availabilityResult = sysctlbyname(
            "kern.memorystatus_level",
            &availability,
            &availabilitySize,
            nil,
            0
        )
        let availabilityRead =
            availabilityResult == 0 && availabilitySize == MemoryLayout<Int32>.size
            ? availability : nil

        return SystemMetricsParsing.pressureMetrics(
            rawLevel: levelRead,
            availabilityLevel: availabilityRead
        )
    }

    // MARK: - Network (getifaddrs)

    /// Walks getifaddrs and sums the non-loopback interface byte
    /// counters. Only AF_LINK rows carry an if_data record, so other
    /// address families are skipped. The loopback exclusion and the
    /// sum run in the pure SystemMetricsParsing rule. Returns nil
    /// when the walk fails or when no usable row exists.
    func sampleNetworkBytes() -> NetworkBytes? {
        var listStart: UnsafeMutablePointer<ifaddrs>?
        // freeifaddrs releases the whole list, including rows this
        // walk skips, whatever path leaves the function.
        guard getifaddrs(&listStart) == 0, let first = listStart else { return nil }
        defer { freeifaddrs(listStart) }

        var rows: [NetworkInterfaceRow] = []
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = current {
            let row = entry.pointee
            current = row.ifa_next

            // ifa_addr can be NULL on a detached interface, and only
            // AF_LINK rows carry if_data byte counters.
            guard let address = row.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  let data = row.ifa_data
            else { continue }

            let stats = data.assumingMemoryBound(to: if_data.self)
            rows.append(
                NetworkInterfaceRow(
                    isLoopback: row.ifa_flags & UInt32(IFF_LOOPBACK) != 0,
                    bytesIn: Int64(stats.pointee.ifi_ibytes),
                    bytesOut: Int64(stats.pointee.ifi_obytes)
                )
            )
        }

        return SystemMetricsParsing.networkBytes(from: rows)
    }

    // MARK: - Process scan (plan 2026-10-23, T1/T6/T7)

    /// One full process scan: `proc_listallpids` in two phases, then
    /// `proc_pid_rusage(RUSAGE_INFO_V2)` per PID (T1). Phase 1 asks
    /// for the current PID count; phase 2 over-allocates with headroom
    /// so processes started between the calls still fit. The loop
    /// allocates no `String`: names resolve later, only for the
    /// top candidates (T7). Skips `pid <= 0`, failed rusage reads
    /// (EPERM for other users' processes, ESRCH for exited ones), and
    /// zombies (`ri_proc_exit_abstime != 0`) (T6). Returns `nil` when
    /// a phase fails (nil-on-failure contract, T1).
    func sampleProcesses() -> [RawProcessSample]? {
        // Phase 1: with a nil buffer the call returns the PID count
        // the list needs right now.
        let required = proc_listallpids(nil, 0)
        guard required > 0 else { return nil }

        // Phase 2: headroom absorbs processes that start between the
        // two calls, so the second call never truncates in practice.
        let capacity = Int(required) + 32
        var pids = [Int32](repeating: 0, count: capacity)
        let written = pids.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return -1 }
            let byteCount = Int32(buffer.count * MemoryLayout<Int32>.size)
            return proc_listallpids(base, byteCount)
        }
        guard written > 0 else { return nil }

        var samples: [RawProcessSample] = []
        samples.reserveCapacity(min(Int(written), capacity))
        for index in 0..<min(Int(written), capacity) {
            let pid = pids[index]
            guard pid > 0 else { continue }

            var info = rusage_info_v2()
            // proc_pid_rusage takes `rusage_info_t *` (a `void **`);
            // the address it writes through is the struct itself.
            let rc = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
                proc_pid_rusage(
                    pid,
                    RUSAGE_INFO_V2,
                    UnsafeMutableRawPointer(pointer)
                        .assumingMemoryBound(to: rusage_info_t?.self)
                )
            }
            // EPERM (root, WindowServer, kernel_task) and ESRCH are
            // expected for an unprivileged scan; drop the PID (T6).
            guard rc == 0 else { continue }
            // A non-zero exit stamp marks a zombie; drop it (T6).
            guard info.ri_proc_exit_abstime == 0 else { continue }

            samples.append(
                RawProcessSample(
                    pid: pid,
                    // &+ matches the plan's `+` for every realistic
                    // value and keeps the no-crash contract on wrap.
                    cpuTicks: info.ri_user_time &+ info.ri_system_time,
                    startAbstime: info.ri_proc_start_abstime,
                    exitAbstime: info.ri_proc_exit_abstime,
                    physFootprint: info.ri_phys_footprint,
                    residentSize: info.ri_resident_size
                )
            )
        }
        return samples
    }

    /// Display name for one PID (T7): `proc_pidpath` first, basename
    /// only; `proc_name` as the fallback. Returns `nil` when the PID
    /// is gone or both reads fail. No NSWorkspace or
    /// NSRunningApplication: both spin up per-call machinery that a
    /// top-8-per-tick lookup does not need.
    func resolveProcessName(pid: Int32) -> String? {
        guard pid > 0 else { return nil }

        // proc_pidpath: the executable's absolute path; keep the
        // basename only. The pre-zeroed buffer makes cString reads
        // terminate even when the call writes no NUL.
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        let pathLength = pathBuffer.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return 0 }
            return proc_pidpath(pid, base, UInt32(buffer.count))
        }
        if pathLength > 0 {
            let path = pathBuffer.withUnsafeBufferPointer { buffer -> String? in
                guard let base = buffer.baseAddress else { return nil }
                return String(cString: base)
            }
            if let name = path?.split(separator: "/").last.map(String.init),
               !name.isEmpty {
                return name
            }
        }

        // Fallback: proc_name's short process name.
        var nameBuffer = [CChar](repeating: 0, count: 128)
        let nameLength = nameBuffer.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return 0 }
            return proc_name(pid, base, UInt32(buffer.count))
        }
        guard nameLength > 0 else { return nil }
        return nameBuffer.withUnsafeBufferPointer { buffer -> String? in
            guard let base = buffer.baseAddress else { return nil }
            let name = String(cString: base)
            return name.isEmpty ? nil : name
        }
    }
}

// MARK: - SMC user-client plumbing (plan 2026-10-23-temp-menu-bar-metric)

/// SMC user-client commands used by the temperature read: GetKeyInfo
/// and ReadKey (Phase 0 probe, `tools/smc-probe/main.swift`).
private enum SMCCommand: UInt8 {
    case readKey = 5
    case getKeyInfo = 9
}

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
