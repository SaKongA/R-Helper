import Foundation
import IOKit.hid

nonisolated final class KeyboardController {
    private let kernel: AsusACPIController

    init(client: AsusACPIClient) { kernel = AsusACPIController(client: client) }

    // 切换 Fn 锁并读取实际状态
    func toggleFnLock() throws -> Bool {
        let current = try kernel.call(AsusACPIOpKeyboardReadFnLock).values.0
        guard current <= 1 else { throw AsusACPIClientError.incompatibleProtocol }
        _ = try kernel.call(AsusACPIOpKeyboardSetFnLock, arguments: [current == 0 ? 1 : 0])
        let actual = try kernel.call(AsusACPIOpKeyboardReadFnLock).values.0
        guard actual <= 1 else { throw AsusACPIClientError.incompatibleProtocol }
        return actual == 1
    }

    // 设置键盘背光亮度档位
    func setBacklightBrightness(_ brightness: UInt32) throws {
        guard brightness <= 3 else { throw AsusACPIClientError.incompatibleProtocol }
        if try setHIDBacklightBrightness(UInt8(brightness)) { return }
        _ = try kernel.call(AsusACPIOpKeyboardSetBrightness, arguments: [brightness])
    }

    private func setHIDBacklightBrightness(_ brightness: UInt8) throws -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Int] = [
            kIOHIDVendorIDKey: 0x0B05,
            kIOHIDProductIDKey: 0x19B6,
            kIOHIDPrimaryUsagePageKey: 0xFF31,
            kIOHIDPrimaryUsageKey: 0x76
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        let status = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard status == kIOReturnSuccess else { throw AsusACPIClientError.ioReturn(status) }
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !devices.isEmpty else { return false }

        for device in devices {
            guard let size = IOHIDDeviceGetProperty(device, kIOHIDMaxFeatureReportSizeKey as CFString) as? NSNumber,
                  size.intValue >= 64, size.intValue <= 4096 else { throw AsusACPIClientError.incompatibleProtocol }
            try sendFeatureReport(device, bytes: [0x5A] + Array("ASUS Tech.Inc.".utf8), size: size.intValue)
            try sendFeatureReport(device, bytes: [0x5A, 0xBA, 0xC5, 0xC4, brightness], size: size.intValue)
        }
        return true
    }

    private func sendFeatureReport(_ device: IOHIDDevice, bytes: [UInt8], size: Int) throws {
        var report = [UInt8](repeating: 0, count: size)
        report.replaceSubrange(0..<bytes.count, with: bytes)
        let status = report.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0x5A, $0.baseAddress!, $0.count)
        }
        guard status == kIOReturnSuccess else { throw AsusACPIClientError.ioReturn(status) }
    }
}
