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
}
