import Darwin
import Foundation

nonisolated struct CPUInfo: Sendable {
    let model: String?
    let vendor: String?
    let family: UInt64?
    let modelNumber: UInt64?
    let stepping: UInt64?
    let physicalCores: UInt64?
    let logicalCores: UInt64?
    let l1InstructionCache: UInt64?
    let l1DataCache: UInt64?
    let l2Cache: UInt64?
    let l3Cache: UInt64?
}

nonisolated enum CPUInfoReader {
    static func read() -> CPUInfo {
        CPUInfo(
            model: string("machdep.cpu.brand_string"),
            vendor: string("machdep.cpu.vendor"),
            family: number("machdep.cpu.family"),
            modelNumber: number("machdep.cpu.model"),
            stepping: number("machdep.cpu.stepping"),
            physicalCores: number("hw.physicalcpu"),
            logicalCores: number("hw.logicalcpu"),
            l1InstructionCache: number("hw.l1icachesize"),
            l1DataCache: number("hw.l1dcachesize"),
            l2Cache: number("hw.l2cachesize"),
            l3Cache: number("hw.l3cachesize")
        )
    }

    private static func string(_ key: String) -> String? {
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 1, size <= 4096 else { return nil }
        var bytes = [CChar](repeating: 0, count: size + 1)
        guard sysctlbyname(key, &bytes, &size, nil, 0) == 0 else { return nil }
        let value = String(cString: bytes).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func number(_ key: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname(key, &value, &size, nil, 0) == 0, size == 4 || size == 8 else { return nil }
        return value
    }
}
