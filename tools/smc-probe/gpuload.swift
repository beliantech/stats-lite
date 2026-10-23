//
// Phase 0 GPU load generator for the AppleSMC attribution rounds.
// Plan: plans/2026-10-23-temp-menu-bar-metric.md
//
// Runs a Metal compute burn kernel for N seconds. One load source per
// attribution round: never run together with the CPU load.
//
// Build: swiftc -O -swift-version 5 -o gpuload gpuload.swift
// Run:   ./gpuload [seconds]     (default 30)
//

import Foundation
import Metal

func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

let duration: Double = {
    guard CommandLine.arguments.count > 1 else { return 30 }
    guard let value = Double(CommandLine.arguments[1]), value > 0 else {
        die("usage: gpuload [seconds]")
    }
    return value
}()

guard let device = MTLCreateSystemDefaultDevice() else {
    die("MTLCreateSystemDefaultDevice returned nil (no Metal device)")
}
guard let queue = device.makeCommandQueue() else {
    die("makeCommandQueue failed")
}

let source = """
#include <metal_stdlib>
using namespace metal;
kernel void burn(device uint *out [[buffer(0)]], uint id [[thread_position_in_grid]]) {
    uint x = id * 2654435761u + 1u;
    for (uint i = 0u; i < 1000000u; i++) {
        x = x * 1664525u + 1013904223u;
    }
    out[id] = x;
}
"""

let library: MTLLibrary
let built: MTLLibrary
do {
    built = try device.makeLibrary(source: source, options: nil)
} catch {
    die("makeLibrary(source:) failed: \(error)")
}
library = built

guard let function = library.makeFunction(name: "burn") else {
    die("makeFunction(name: \"burn\") returned nil")
}

let pipeline: MTLComputePipelineState
do {
    pipeline = try device.makeComputePipelineState(function: function)
} catch {
    die("makeComputePipelineState failed: \(error)")
}

let threadsPerGrid = 16384
guard let buffer = device.makeBuffer(length: threadsPerGrid * MemoryLayout<UInt32>.size,
                                     options: .storageModeShared) else {
    die("makeBuffer failed")
}

print("# gpuload device=\(device.name) threads=\(threadsPerGrid) seconds=\(duration)")
fflush(stdout)

let start = Date()
let deadline = start.addingTimeInterval(duration)
var dispatches = 0
while Date() < deadline {
    guard let commandBuffer = queue.makeCommandBuffer() else {
        die("makeCommandBuffer failed at dispatch \(dispatches)")
    }
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
        die("makeComputeCommandEncoder failed at dispatch \(dispatches)")
    }
    encoder.setComputePipelineState(pipeline)
    encoder.setBuffer(buffer, offset: 0, index: 0)
    encoder.dispatchThreadgroups(
        MTLSize(width: threadsPerGrid / 64, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1)
    )
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    dispatches += 1
}

let elapsed = Date().timeIntervalSince(start)
print("# gpuload done dispatches=\(dispatches) elapsed_s=" + String(format: "%.1f", elapsed))
