//
// Phase 0 AppleSMC temperature probe (measurement tool, not product code).
// Plan: plans/2026-10-23-temp-menu-bar-metric.md
//
// One file, no dependencies. Compile: swiftc -O -swift-version 5 -o probe main.swift
//
// Modes:
//   probe                      enumerate all SMC keys (name, type, decoded value)
//   probe --temps              print plausible temperature keys once
//   probe --watch [seconds]    timestamped table of plausible temp keys, 1 Hz
//   probe --latency [n]        time n open -> GetKeyInfo -> Read -> close cycles
//
// Route: IOServiceGetMatchingServices("AppleSMC") -> IOServiceOpen ->
// IOConnectCallStructMethod selector 2 (kSMCHandleYPCEvent) with an 80-byte
// SMCParamStruct. Command 9 = GetKeyInfo, command 5 = ReadKey,
// command 8 = key name by index. No root expected.
//
// Decoders: "flt " little-endian IEEE-754 (Apple Silicon), generic "sp.."/"fp.."
// fixed point big-endian (Intel style), "ui8 "/"ui16"/"ui32" for counters.
// Each decoded candidate carries the decoder label that matched.
//

import Foundation
import IOKit

// MARK: - Errors and helpers

struct ProbeError: Error {
    let message: String
}

func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func hexCode(_ kr: Int32) -> String {
    String(format: "0x%08x", UInt32(bitPattern: kr))
}

func fourCC(_ name: String) -> UInt32 {
    var value: UInt32 = 0
    for byte in Array(name.utf8.prefix(4)) {
        value = (value << 8) | UInt32(byte)
    }
    return value
}

func fourCCString(_ value: UInt32) -> String {
    let bytes: [UInt8] = [
        UInt8((value >> 24) & 0xff),
        UInt8((value >> 16) & 0xff),
        UInt8((value >> 8) & 0xff),
        UInt8(value & 0xff),
    ]
    guard let text = String(bytes: bytes, encoding: .isoLatin1) else {
        return String(format: "0x%08x", value)
    }
    return text
}

// MARK: - SMCParamStruct (80 bytes, classic Apple layout)

struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    // Explicit padding field: it keeps the field offsets identical to the
    // classic 80-byte C struct (result=40, status=41, data8=42, data32=44,
    // bytes=48). Verified below at startup with MemoryLayout offset checks.
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
               (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

enum SMCCommand: UInt8 {
    case readKey = 5
    case getKeyFromIndex = 8
    case getKeyInfo = 9
}

let smcSelector: UInt32 = 2 // kSMCHandleYPCEvent
let smcResultSuccess: UInt8 = 0
let smcResultKeyNotFound: UInt8 = 132

func verifyLayout() {
    var problems: [String] = []
    func expect<T>(_ label: String, _ actual: T, _ wanted: T) where T: Equatable & CustomStringConvertible {
        if actual != wanted {
            problems.append("\(label)=\(actual) want \(wanted)")
        }
    }
    expect("size", MemoryLayout<SMCParamStruct>.stride, 80)
    if let off = MemoryLayout<SMCParamStruct>.offset(of: \.key) { expect("key", off, 0) }
    if let off = MemoryLayout<SMCParamStruct>.offset(of: \.vers) { expect("vers", off, 4) }
    if let off = MemoryLayout<SMCParamStruct>.offset(of: \.pLimitData) { expect("pLimitData", off, 12) }
    if let off = MemoryLayout<SMCParamStruct>.offset(of: \.keyInfo) { expect("keyInfo", off, 28) }
    if let off = MemoryLayout<SMCParamStruct>.offset(of: \.result) { expect("result", off, 40) }
    if let off = MemoryLayout<SMCParamStruct>.offset(of: \.status) { expect("status", off, 41) }
    if let off = MemoryLayout<SMCParamStruct>.offset(of: \.data8) { expect("data8", off, 42) }
    if let off = MemoryLayout<SMCParamStruct>.offset(of: \.data32) { expect("data32", off, 44) }
    if let off = MemoryLayout<SMCParamStruct>.offset(of: \.bytes) { expect("bytes", off, 48) }
    if !problems.isEmpty {
        die("SMCParamStruct layout mismatch: \(problems.joined(separator: ", "))")
    }
}

// MARK: - AppleSMC client

final class AppleSMC {
    private let conn: io_connect_t
    private var isClosed = false

    init() throws {
        guard let matching = IOServiceMatching("AppleSMC") else {
            throw ProbeError(message: "IOServiceMatching(\"AppleSMC\") returned nil")
        }
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else {
            throw ProbeError(message: "IOServiceGetMatchingServices(AppleSMC) failed: kern_return=\(hexCode(kr))")
        }
        defer { IOObjectRelease(iterator) }
        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            throw ProbeError(message: "AppleSMC service not found in IOService matching (no device?)")
        }
        defer { IOObjectRelease(service) }
        var connect: io_connect_t = 0
        // owningTask must be mach_task_self_ (not 0): a null task comes back
        // as kIOReturnNotPrivileged (0xe00002c2), observed on this machine.
        let openKR = IOServiceOpen(service, mach_task_self_, 0, &connect)
        guard openKR == KERN_SUCCESS else {
            throw ProbeError(message: "IOServiceOpen(AppleSMC) failed: kern_return=\(hexCode(openKR))")
        }
        conn = connect
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        IOServiceClose(conn)
    }

    private func call(command: SMCCommand, key: UInt32, dataSize: UInt32, index: UInt32) throws -> SMCParamStruct {
        var input = SMCParamStruct()
        input.key = key
        input.keyInfo.dataSize = dataSize
        input.data8 = command.rawValue
        input.data32 = index
        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let kr = IOConnectCallStructMethod(
            conn, smcSelector,
            &input, MemoryLayout<SMCParamStruct>.stride,
            &output, &outputSize
        )
        guard kr == KERN_SUCCESS else {
            throw ProbeError(message: "IOConnectCallStructMethod(cmd=\(command.rawValue)) failed: kern_return=\(hexCode(kr))")
        }
        guard output.result == smcResultSuccess else {
            if output.result == smcResultKeyNotFound {
                throw ProbeError(message: "SMC key not found (result=\(smcResultKeyNotFound))")
            }
            throw ProbeError(message: "SMC command \(command.rawValue) failed: result=\(output.result) status=\(output.status)")
        }
        return output
    }

    func keyInfo(key: String) throws -> (size: UInt32, type: String) {
        let out = try call(command: .getKeyInfo, key: fourCC(key), dataSize: 0, index: 0)
        return (out.keyInfo.dataSize, fourCCString(out.keyInfo.dataType))
    }

    func read(key: String, size: UInt32) throws -> [UInt8] {
        guard size > 0, size <= 32 else {
            throw ProbeError(message: "read(\(key)): unsupported dataSize \(size)")
        }
        let out = try call(command: .readKey, key: fourCC(key), dataSize: size, index: 0)
        var data = [UInt8](repeating: 0, count: 32)
        withUnsafeBytes(of: out.bytes) { raw in
            for i in 0..<min(raw.count, data.count) {
                data[i] = raw[i]
            }
        }
        return Array(data.prefix(Int(size)))
    }

    func keyName(at index: UInt32) throws -> String {
        let out = try call(command: .getKeyFromIndex, key: 0, dataSize: 0, index: index)
        return fourCCString(out.key)
    }

    /// Returns nil when "#KEY" cannot be read; callers fall back to a
    /// consecutive-failure scan.
    func keyCount() -> UInt32? {
        guard let info = try? keyInfo(key: "#KEY"), info.size == 4,
              let bytes = try? read(key: "#KEY", size: 4) else {
            return nil
        }
        return (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
    }
}

// MARK: - Decoding

struct Decoded {
    let decoder: String
    let value: Double
}

/// Temperature-capable types for the plausibility filter: IEEE-754 "flt "
/// and signed/unsigned fixed-point "sp.."/"fp.." families.
func isTemperatureFamily(_ type: String) -> Bool {
    if type == "flt " { return true }
    let chars = Array(type)
    guard chars.count == 4 else { return false }
    let prefix = String(chars[0...1])
    guard prefix == "sp" || prefix == "fp" else { return false }
    return chars[2...3].allSatisfy { $0.isHexDigit }
}

/// "sp.."/"fp.." types also encode voltages, currents, fan targets, and
/// thresholds, all of which can sit inside the -20...130 range. SMC keys
/// that report temperatures carry the "T" name prefix (TC0P, Tp00, Tg01).
/// The prefix gate keeps the plausible set temperature-like.
func isTemperatureLikeName(_ name: String) -> Bool {
    name.hasPrefix("T")
}

func decode(type: String, bytes: [UInt8]) -> [Decoded] {
    var results: [Decoded] = []
    let chars = Array(type)

    if type == "flt ", bytes.count == 4 {
        let le = Float(bitPattern: (UInt32(bytes[0]) << 0) | (UInt32(bytes[1]) << 8)
            | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24))
        results.append(Decoded(decoder: "flt-le", value: Double(le)))
        let be = Float(bitPattern: (UInt32(bytes[3]) << 0) | (UInt32(bytes[2]) << 8)
            | (UInt32(bytes[1]) << 16) | (UInt32(bytes[0]) << 24))
        results.append(Decoded(decoder: "flt-be", value: Double(be)))
        return results
    }

    if chars.count == 4, bytes.count == 2,
       (type.hasPrefix("sp") || type.hasPrefix("fp")), isTemperatureFamily(type),
       let fracLow = type.dropFirst(2).first.flatMap({ Int(String($0), radix: 16) }),
       let fracHigh = type.dropFirst(3).first.flatMap({ Int(String($0), radix: 16) }) {
        let fracBits = fracLow * 16 + fracHigh
        let divisor = Double(1 << fracBits)
        let signed = type.hasPrefix("sp")
        let beRaw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
        let leRaw = (UInt16(bytes[1]) << 8) | UInt16(bytes[0])
        if signed {
            results.append(Decoded(decoder: "\(type)-be", value: Double(Int16(bitPattern: beRaw)) / divisor))
            results.append(Decoded(decoder: "\(type)-le", value: Double(Int16(bitPattern: leRaw)) / divisor))
        } else {
            results.append(Decoded(decoder: "\(type)-be", value: Double(beRaw) / divisor))
            results.append(Decoded(decoder: "\(type)-le", value: Double(leRaw) / divisor))
        }
        return results
    }

    if type == "ui8 ", bytes.count == 1 {
        results.append(Decoded(decoder: "ui8", value: Double(bytes[0])))
    } else if type == "ui16", bytes.count == 2 {
        results.append(Decoded(decoder: "ui16-be", value: Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))))
    } else if type == "ui32", bytes.count == 4 {
        results.append(Decoded(decoder: "ui32-be", value: Double((UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16)
            | (UInt32(bytes[2]) << 8) | UInt32(bytes[3]))))
    }
    return results
}

let plausibleMin = -20.0
let plausibleMax = 130.0

func isPlausibleTemperature(_ value: Double) -> Bool {
    value.isFinite && value >= plausibleMin && value <= plausibleMax
}

// MARK: - Key table

struct KeyRow {
    let name: String
    let type: String
    let size: UInt32
    let decoder: String?
    let value: Double?
    let plausibleTemp: Bool
    let readError: String?
}

func loadKeyTable(smc: AppleSMC) -> (rows: [KeyRow], indexErrors: Int) {
    var rows: [KeyRow] = []
    var indexErrors = 0

    var indices: [UInt32] = []
    if let count = smc.keyCount(), count > 0, count <= 16384 {
        indices = (0..<count).map { UInt32($0) }
    } else {
        // Fallback: scan until consecutive index-read failures.
        var missRun = 0
        var index: UInt32 = 0
        while missRun < 64, index < 16384 {
            if (try? smc.keyName(at: index)) != nil {
                indices.append(index)
                missRun = 0
            } else {
                missRun += 1
            }
            index += 1
        }
    }

    for index in indices {
        guard let name = try? smc.keyName(at: index) else {
            indexErrors += 1
            continue
        }
        guard let info = try? smc.keyInfo(key: name) else {
            rows.append(KeyRow(name: name, type: "?", size: 0, decoder: nil, value: nil,
                               plausibleTemp: false, readError: "GetKeyInfo failed"))
            continue
        }
        if info.size == 0 || info.size > 32 {
            rows.append(KeyRow(name: name, type: info.type, size: info.size, decoder: nil, value: nil,
                               plausibleTemp: false, readError: nil))
            continue
        }
        guard let bytes = try? smc.read(key: name, size: info.size) else {
            rows.append(KeyRow(name: name, type: info.type, size: info.size, decoder: nil, value: nil,
                               plausibleTemp: false, readError: "ReadKey failed"))
            continue
        }
        let candidates = decode(type: info.type, bytes: bytes)
        let plausible = candidates.first { isPlausibleTemperature($0.value) }
        let primary = plausible ?? candidates.first
        rows.append(KeyRow(name: name, type: info.type, size: info.size,
                           decoder: primary?.decoder, value: primary?.value,
                           plausibleTemp: isTemperatureFamily(info.type)
                               && isTemperatureLikeName(name)
                               && plausible != nil,
                           readError: nil))
    }
    return (rows, indexErrors)
}

func plausibleTempKeys(from rows: [KeyRow]) -> [KeyRow] {
    rows.filter(\.plausibleTemp)
}

// MARK: - Modes

/// Left-aligned fixed-width column. Do not use String(format: "%-6s") with
/// Swift Strings: %s expects a C string and segfaults on the bridged object.
func pad(_ text: String, _ width: Int) -> String {
    if text.count >= width { return text }
    return text + String(repeating: " ", count: width - text.count)
}

func printEnumerate(smc: AppleSMC) throws {
    print("# mode=enumerate")
    let (rows, indexErrors) = loadKeyTable(smc: smc)
    let temps = plausibleTempKeys(from: rows)
    print("# keys=\(rows.count) index_errors=\(indexErrors) plausible_temp_keys=\(temps.count)")
    print("# range=\(plausibleMin)...\(plausibleMax)C family=flt/sp../fp.. name-prefix=T")
    print([pad("KEY", 6), pad("TYPE", 6), pad("DECODER", 10), pad("VALUE", 10), "NOTE"].joined(separator: " "))
    for row in rows {
        let decoder = row.decoder ?? "-"
        let value: String = {
            if let v = row.value { return String(format: "%.4f", v) }
            return "-"
        }()
        var note = row.readError ?? "-"
        if row.plausibleTemp { note = "plausible-temp" }
        print([pad(row.name, 6), pad(row.type, 6), pad(decoder, 10), pad(value, 10), note].joined(separator: " "))
    }
}

func printTemps(smc: AppleSMC) throws {
    print("# mode=temps")
    let (rows, _) = loadKeyTable(smc: smc)
    let temps = plausibleTempKeys(from: rows)
    let stamp = ISO8601DateFormatter().string(from: Date())
    print("# keys=\(temps.count)")
    if temps.isEmpty {
        print("\(stamp)  no plausible temperature keys")
        return
    }
    var parts = [stamp]
    for row in temps {
        let value = row.value.map { String(format: "%.1f", $0) } ?? "--"
        parts.append("\(row.name)=\(value)")
    }
    print(parts.joined(separator: "  "))
}

func watch(smc: AppleSMC, seconds: Int) throws {
    print("# mode=watch duration=\(seconds)s interval=1s")
    let (rows, indexErrors) = loadKeyTable(smc: smc)
    let temps = plausibleTempKeys(from: rows)
    print("# index_errors=\(indexErrors) keys=\(temps.count)")
    print("# columns: " + temps.map(\.name).joined(separator: " "))
    fflush(stdout)
    if temps.isEmpty {
        print("# no plausible temperature keys; nothing to watch")
        fflush(stdout)
        return
    }

    let stampFormatter = ISO8601DateFormatter()
    var nextTick = Date()
    let end = Date().addingTimeInterval(Double(seconds))
    while nextTick < end {
        var parts = [stampFormatter.string(from: Date())]
        for row in temps {
            var printed = "--"
            if let bytes = try? smc.read(key: row.name, size: row.size) {
                let candidates = decode(type: row.type, bytes: bytes)
                if let hit = candidates.first(where: { isPlausibleTemperature($0.value) }) {
                    printed = String(format: "%.1f", hit.value)
                }
            }
            parts.append("\(row.name)=\(printed)")
        }
        print(parts.joined(separator: "  "))
        fflush(stdout)
        nextTick = nextTick.addingTimeInterval(1)
        if nextTick < Date() {
            nextTick = Date()
        }
        Thread.sleep(until: nextTick)
    }
}

func percentile(_ sortedSamples: [UInt64], _ p: Double) -> UInt64 {
    guard !sortedSamples.isEmpty else { return 0 }
    let rank = Int(ceil(p * Double(sortedSamples.count)))
    let index = min(max(rank - 1, 0), sortedSamples.count - 1)
    return sortedSamples[index]
}

func latency(smc: AppleSMC, count: Int) throws {
    let (rows, _) = loadKeyTable(smc: smc)
    let target = plausibleTempKeys(from: rows).first?.name ?? "#KEY"
    print("# mode=latency n=\(count) key=\(target)")

    var samples: [UInt64] = []
    var failures = 0
    var firstError = ""
    for _ in 0..<count {
        let start = DispatchTime.now().uptimeNanoseconds
        do {
            let cycle = try AppleSMC()
            let info = try cycle.keyInfo(key: target)
            _ = try cycle.read(key: target, size: info.size)
            cycle.close()
            let elapsed = DispatchTime.now().uptimeNanoseconds &- start
            samples.append(elapsed)
        } catch {
            failures += 1
            if firstError.isEmpty {
                firstError = String(describing: error)
            }
        }
    }

    print("# success=\(samples.count) errors=\(failures)")
    if let error = firstError.isEmpty ? nil : firstError {
        print("# first_error=\(error)")
    }
    fflush(stdout)
    guard !samples.isEmpty else {
        throw ProbeError(message: "all \(count) latency cycles failed; first error: \(firstError)")
    }

    let sorted = samples.sorted()
    let mean = samples.reduce(UInt64(0), +) / UInt64(samples.count)
    let p50 = percentile(sorted, 0.50)
    let p95 = percentile(sorted, 0.95)
    let p99 = percentile(sorted, 0.99)
    let maxSample = sorted[sorted.count - 1]
    let minSample = sorted[0]

    func report(_ label: String, _ ns: UInt64) {
        print("\(label)_us=\(ns / 1000) \(label)_ms=" + String(format: "%.3f", Double(ns) / 1_000_000.0))
    }
    report("p50", p50)
    report("p95", p95)
    report("p99", p99)
    report("max", maxSample)
    report("min", minSample)
    report("mean", mean)
    print("# verdict_h2: p99_ns=\(p99) (threshold priors: p99<5ms ride 1Hz loop, p99>~50ms own cadence; both unverified prior)")
}

// MARK: - CLI

let usage = """
usage: probe [--enumerate | --temps | --watch [seconds] | --latency [n] | --help]

  (no flag)    enumerate all SMC keys with decoded values
  --temps      print plausible temperature keys once
  --watch      timestamped plausible-temp table every second (default 10 s)
  --latency    time n open/GetKeyInfo/Read/close cycles (default 1000)
"""

let arguments = Array(CommandLine.arguments.dropFirst())
var mode = "enumerate"
var modeValue: Int? = nil
var index = 0
while index < arguments.count {
    let arg = arguments[index]
    switch arg {
    case "--enumerate":
        mode = "enumerate"
    case "--temps":
        mode = "temps"
    case "--watch":
        mode = "watch"
        if index + 1 < arguments.count, let value = Int(arguments[index + 1]), value > 0 {
            modeValue = value
            index += 1
        }
    case "--latency":
        mode = "latency"
        if index + 1 < arguments.count, let value = Int(arguments[index + 1]), value > 0 {
            modeValue = value
            index += 1
        }
    case "-h", "--help":
        print(usage)
        exit(0)
    default:
        FileHandle.standardError.write(Data("unknown argument: \(arg)\n\(usage)\n".utf8))
        exit(2)
    }
    index += 1
}

verifyLayout()

do {
    let smc = try AppleSMC()
    defer { smc.close() }
    switch mode {
    case "temps":
        try printTemps(smc: smc)
    case "watch":
        try watch(smc: smc, seconds: modeValue ?? 10)
    case "latency":
        try latency(smc: smc, count: modeValue ?? 1000)
    default:
        try printEnumerate(smc: smc)
    }
} catch let error as ProbeError {
    die(error.message)
} catch {
    die("unexpected error: \(error)")
}
