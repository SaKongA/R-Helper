import CoreGraphics
import Foundation
import IOKit

nonisolated struct GPUDevice: Sendable {
    let model: String
    let registryID: UInt64
}

nonisolated enum GPUModelReader {
    static func read() -> GPUDevice? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        let status = displays.withUnsafeMutableBufferPointer {
            CGGetOnlineDisplayList(UInt32($0.count), $0.baseAddress, &count)
        }
        guard status == .success else { return nil }
        let internalDisplays = displays.prefix(Int(count)).filter { CGDisplayIsBuiltin($0) != 0 }
        guard internalDisplays.count == 1, let display = internalDisplays.first,
              let matching = IOServiceMatching("AppleBacklightDisplay") else { return nil }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var matches: [GPUDevice] = []
        while true {
            let entry = IOIteratorNext(iterator)
            if entry == 0 { break }
            defer { IOObjectRelease(entry) }
            guard number(entry, key: "DisplayVendorID") == CGDisplayVendorNumber(display),
                  number(entry, key: "DisplayProductID") == CGDisplayModelNumber(display) else { continue }
            let serial = CGDisplaySerialNumber(display)
            if serial != 0 && number(entry, key: "DisplaySerialNumber") != serial { continue }
            guard let device = parentGPU(entry) else { continue }
            matches.append(device)
        }
        return matches.count == 1 ? matches[0] : nil
    }

    private static func number(_ entry: io_registry_entry_t, key: String) -> UInt32? {
        (IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber)?.uint32Value
    }

    private static func parentGPU(_ display: io_registry_entry_t) -> GPUDevice? {
        IOObjectRetain(display)
        var entry = display
        defer { IOObjectRelease(entry) }
        while entry != 0 {
            if IOObjectConformsTo(entry, "IOPCIDevice") != 0,
               let data = IORegistryEntryCreateCFProperty(entry, "class-code" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Data,
               data.count >= 4 {
                let code = data.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
                if (code >> 16) & 0xff == 0x03 {
                    guard let value = IORegistryEntryCreateCFProperty(entry, "model" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else { return nil }
                    let name: String?
                    if let data = value as? Data { name = String(data: data.prefix { $0 != 0 }, encoding: .utf8) }
                    else { name = value as? String }
                    guard let model = name?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty else { return nil }
                    var registryID: UInt64 = 0
                    guard IORegistryEntryGetRegistryEntryID(entry, &registryID) == KERN_SUCCESS else { return nil }
                    return GPUDevice(model: model, registryID: registryID)
                }
            }
            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent) == KERN_SUCCESS else { return nil }
            IOObjectRelease(entry)
            entry = parent
        }
        return nil
    }
}
