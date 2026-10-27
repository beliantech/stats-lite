//
//  LiveSystemMetricsProvider.swift
//  StatsLite
//
//  Real sampler: Mach host stats for CPU and RAM, IOKit for GPU,
//  AppleSMC for temperature, sysctl for memory pressure. Every
//  acquired resource has a matching `defer` cleanup registered in the
//  same scope where the resource is acquired (the cached SMC
//  connection closes in its enumerator's deinit). No force-unwraps:
//  every failed read returns `nil` or falls back to the unknown
//  pressure state.
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

    /// CPU and GPU die temperatures from runtime key discovery (plan
    /// 2026-10-27-runtime-smc-key-discovery). The key table is
    /// enumerated from this machine's own SMC exactly once per
    /// process, on the first sample; later samples read only the
    /// cached table keys (FM4). The filters live in
    /// `TemperatureKeyDiscovery`: exact prefix domains, `flt `/4 type
    /// checks at enumeration, per-reading plausibility, and the
    /// trailing-60-tick movement filter. Returns nil when no domain
    /// has a plausible reading this tick. A present value can still
    /// carry nil subsystems: nil `cpuCelsius` or `gpuCelsius` keeps
    /// that row on the `--°` placeholder (nil contract, no
    /// force-unwraps).
    func sampleTemperature() -> TemperatureMetrics? {
        Self.temperatureDiscovery.sample()
    }

    /// The per-launch discovery state. A `static let` runs the
    /// enumeration once per process on first use, never per sample
    /// (FM4). Every copy of this provider struct shares it.
    private static let temperatureDiscovery = TemperatureKeyDiscovery(
        enumerator: AppleSMCKeyEnumerator()
    )

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

    /// Display name for one PID (R2, title chain): `KERN_PROCARGS2`
    /// argv[0] basename first — the name the user launched, for
    /// example `pi` where proc_pidpath reports `node` — then
    /// `proc_pidpath` basename, then `proc_name`. Returns nil when
    /// every source fails; the sampler then drops the row (D1). No
    /// NSWorkspace or NSRunningApplication: both spin up per-call
    /// machinery that a top-10-per-tick lookup does not need.
    func resolveProcessName(pid: Int32) -> String? {
        guard pid > 0 else { return nil }
        return Self.resolvedProcessName(
            argv0: { self.argv0FromProcArgs(pid: pid) },
            path: { self.executablePath(pid: pid) },
            procName: { self.procName(pid: pid) }
        )
    }

    // MARK: - R2 title chain

    /// The R2 title chain in order, first success wins. Sources are
    /// closures so the ordering tests drive each step without live
    /// syscalls (U2), and a later source never runs after an earlier
    /// one succeeded. A path-shaped candidate keeps only its
    /// basename.
    static func resolvedProcessName(
        argv0: () -> String?,
        path: () -> String?,
        procName: () -> String?
    ) -> String? {
        // argv[0] basename first (R2, V2): the name the user
        // launched, for example `pi` where proc_pidpath reports the
        // interpreter `node`.
        if let name = argv0(), let base = basenameCandidate(name) { return base }
        if let name = path(), let base = basenameCandidate(name) { return base }
        if let name = procName(), let base = basenameCandidate(name) { return base }
        return nil
    }

    /// One candidate's display form: non-empty after basename.
    private static func basenameCandidate(_ candidate: String) -> String? {
        guard !candidate.isEmpty else { return nil }
        let base = candidate.split(separator: "/").last.map(String.init) ?? candidate
        return base.isEmpty ? nil : base
    }

    /// The executable's absolute path via `proc_pidpath` (R2 chain
    /// step 2). The pre-zeroed buffer makes cString reads terminate
    /// even when the call writes no NUL.
    private func executablePath(pid: Int32) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        let pathLength = pathBuffer.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return 0 }
            return proc_pidpath(pid, base, UInt32(buffer.count))
        }
        guard pathLength > 0 else { return nil }
        return pathBuffer.withUnsafeBufferPointer { buffer -> String? in
            guard let base = buffer.baseAddress else { return nil }
            return String(cString: base)
        }
    }

    /// The short process name via `proc_name` (R2 chain step 3).
    private func procName(pid: Int32) -> String? {
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

    // MARK: - R2: KERN_PROCARGS2 argv[0]

    /// argv[0] for one PID via `KERN_PROCARGS2` (R2 chain step 1):
    /// the executable name the user launched. EINVAL for other-user
    /// and uninspectable PIDs is an expected miss for an
    /// unprivileged read — the chain continues silently, never
    /// logged as an error. The buffer grows once to 8192 on ENOMEM.
    private func argv0FromProcArgs(pid: Int32) -> String? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        var rc = buffer.withUnsafeMutableBufferPointer { base -> Int32 in
            guard let first = base.baseAddress else { return -1 }
            return sysctl(&mib, u_int(mib.count), first, &size, nil, 0)
        }
        if rc != 0 && errno == ENOMEM {
            size = 8192
            buffer = [UInt8](repeating: 0, count: size)
            rc = buffer.withUnsafeMutableBufferPointer { base -> Int32 in
                guard let first = base.baseAddress else { return -1 }
                return sysctl(&mib, u_int(mib.count), first, &size, nil, 0)
            }
        }
        guard rc == 0, size >= 4 else { return nil }
        return Self.argv0(fromProcArgs: Array(buffer.prefix(Int(size))))
    }

    /// Parses argv[0] out of a KERN_PROCARGS2 buffer (R2): int32
    /// argc, exec_path NUL-terminated, zero or more NUL padding
    /// bytes, then argc NUL-terminated strings, the first being
    /// argv[0].
    ///
    /// argv[0] is the first non-NUL byte after exec_path and its
    /// padding run, read to its own terminating NUL. A real process
    /// always has a non-empty argv[0], so this never confuses the
    /// padding with argv[0]. Only argv[0] is read; later strings can
    /// be truncated. Returns nil on a malformed or exhausted buffer,
    /// never an empty name.
    static func argv0(fromProcArgs bytes: [UInt8]) -> String? {
        guard bytes.count > 4 else { return nil }
        var index = 4
        // exec_path: skip to its terminating NUL.
        while index < bytes.count, bytes[index] != 0 { index += 1 }
        guard index < bytes.count else { return nil }
        // Zero or more NUL padding bytes: skip the whole run to the
        // first non-NUL byte, the start of argv[0].
        while index < bytes.count, bytes[index] == 0 { index += 1 }
        guard index < bytes.count else { return nil }
        // argv[0]: the first NUL-terminated string after the padding.
        let start = index
        while index < bytes.count, bytes[index] != 0 { index += 1 }
        guard index < bytes.count, index > start else { return nil }
        return String(decoding: bytes[start..<index], as: UTF8.self)
    }
}
