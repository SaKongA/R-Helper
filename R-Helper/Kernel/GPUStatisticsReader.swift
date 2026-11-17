import Foundation
import IOKit

nonisolated struct GPUStatistics: Sendable {
    let frequencyMHz: Double?
    let powerWatts: Double?
}

nonisolated enum GPUStatisticsReader {
    static func read(device: GPUDevice) -> GPUStatistics? {
        guard let matching = IOServiceMatching("IOAccelerator") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var frequencies = Set<Double>()
        var powers = Set<Double>()
        while true {
            let accelerator = IOIteratorNext(iterator)
            if accelerator == 0 { break }
            defer { IOObjectRelease(accelerator) }
            guard belongsToGPU(accelerator, registryID: device.registryID),
                  let statistics = IORegistryEntryCreateCFProperty(accelerator, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] else { continue }
            if let frequency = positive(statistics["Core Clock(MHz)"]) { frequencies.insert(frequency) }
            if let power = positive(statistics["Total Power(W)"]) { powers.insert(power) }
        }
        return GPUStatistics(frequencyMHz: frequencies.count == 1 ? frequencies.first : nil, powerWatts: powers.count == 1 ? powers.first : nil)
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
