import Foundation
import IOKit

nonisolated struct GPUStatistics: Sendable {
    let frequencyMHz: Double?
    let powerWatts: Double?
    let usagePercent: Double?
    let videoMemoryUsedBytes: UInt64?
    let videoMemoryTotalBytes: UInt64?
}

nonisolated enum GPUStatisticsReader {
    static func read(device: GPUDevice) -> GPUStatistics? {
        guard let matching = IOServiceMatching("IOAccelerator") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var frequencies = Set<Double>()
        var powers = Set<Double>()
        var memoryUsage = Set<UInt64>()
        var usageValues = Set<Double>()
        while true {
            let accelerator = IOIteratorNext(iterator)
            if accelerator == 0 { break }
            defer { IOObjectRelease(accelerator) }
            guard belongsToGPU(accelerator, registryID: device.registryID),
                  let statistics = IORegistryEntryCreateCFProperty(accelerator, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] else { continue }
            if let frequency = positive(statistics["Core Clock(MHz)"]) { frequencies.insert(frequency) }
            if let power = positive(statistics["Total Power(W)"]) { powers.insert(power) }
            if let used = nonnegativeInteger(statistics["inUseVidMemoryBytes"]) { memoryUsage.insert(used) }
            if let usage = (statistics["Device Utilization %"] as? NSNumber)?.doubleValue,
               usage.isFinite, (0...100).contains(usage) { usageValues.insert(usage) }
        }
        return GPUStatistics(
            frequencyMHz: frequencies.count == 1 ? frequencies.first : nil,
            powerWatts: powers.count == 1 ? powers.first : nil,
            usagePercent: usageValues.count == 1 ? usageValues.first : nil,
            videoMemoryUsedBytes: memoryUsage.count == 1 ? memoryUsage.first : nil,
            videoMemoryTotalBytes: videoMemoryTotal(registryID: device.registryID)
        )
    }

    private static func videoMemoryTotal(registryID: UInt64) -> UInt64? {
        guard let matching = IORegistryEntryIDMatching(registryID) else { return nil }
        let device = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard device != 0 else { return nil }
        defer { IOObjectRelease(device) }
        let property = IORegistryEntryCreateCFProperty(device, "VRAM,totalMB" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        guard let megabytes = nonnegativeInteger(property), megabytes > 0,
              megabytes <= UInt64(Int64.max) / 1_048_576 else { return nil }
        return megabytes * 1_048_576
    }

    private static func nonnegativeInteger(_ value: Any?) -> UInt64? {
        guard let number = value as? NSNumber, number.int64Value >= 0,
              number.doubleValue == Double(number.int64Value) else { return nil }
        return UInt64(number.int64Value)
    }

    private static func belongsToGPU(_ accelerator: io_registry_entry_t, registryID: UInt64) -> Bool {
        IOObjectRetain(accelerator)
        var entry = accelerator
        defer { IOObjectRelease(entry) }
        while entry != 0 {
            var currentID: UInt64 = 0
            if IORegistryEntryGetRegistryEntryID(entry, &currentID) == KERN_SUCCESS && currentID == registryID { return true }
            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent) == KERN_SUCCESS else { return false }
            IOObjectRelease(entry)
            entry = parent
        }
        return false
    }

    private static func positive(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let result = number.doubleValue
        return result.isFinite && result > 0 ? result : nil
    }
}
