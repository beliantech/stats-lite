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
