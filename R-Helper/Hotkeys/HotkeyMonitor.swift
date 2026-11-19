import CoreFoundation
import CoreGraphics
import Combine
import Foundation
import IOKit.hid

@MainActor
final class HotkeyMonitor: ObservableObject {
    static let shared = HotkeyMonitor()
    @Published private(set) var needsInputMonitoring = false
    @Published private(set) var openErrorStatus: kern_return_t?
    var openError: String? {
        openErrorStatus.map { String(format: L10n.text("HID 监听启动失败：0x%08X"), UInt32(bitPattern: $0)) }
    }
    private var manager: IOHIDManager?
    private var previewToggleStates: [Hotkey: Bool] = [:]

    func start(requestPermission: Bool = false) {
        guard manager == nil else { return }

        if !CGPreflightListenEventAccess() {
            if requestPermission { _ = CGRequestListenEventAccess() }
            guard CGPreflightListenEventAccess() else {
                needsInputMonitoring = true
                return
            }
        }
        needsInputMonitoring = false

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Int] = [
            kIOHIDVendorIDKey: 0x0B05,
            kIOHIDProductIDKey: 0x19B6,
            kIOHIDPrimaryUsagePageKey: 0xFF31
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        IOHIDManagerRegisterInputValueCallback(manager, { _, status, _, value in
            guard status == kIOReturnSuccess else { return }
            let element = IOHIDValueGetElement(value)
            let page = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            let reportID = IOHIDElementGetReportID(element)
            let pressed = IOHIDValueGetIntegerValue(value)
            guard page != 0xFF31 || reportID == 0x5A else { return }
            AppLogger.info(String(format: "HID report=0x%X page=0x%X usage=0x%X value=%ld", reportID, page, usage, pressed))
            if page == 0xFF31, (usage == Hotkey.brightnessUp.rawValue || usage == Hotkey.brightnessDown.rawValue), (pressed == 0 || pressed == 1) {
                Task { @MainActor in
                    DisplayBrightnessHotkey.shared.handleKey(up: usage == Hotkey.brightnessUp.rawValue, pressed: pressed == 1)
                }
                return
            }
            guard let event = Hotkey.decode(page: page, usage: usage, value: pressed) else { return }
            Task { @MainActor in
                let monitor = HotkeyMonitor.shared
                let hotkey = event.key
                if hotkey == .fnLock || hotkey == .touchpad || hotkey == .keyboardLightUp || hotkey == .keyboardLightDown || hotkey == .performanceMode || hotkey == .brightnessUp || hotkey == .brightnessDown || hotkey == .menu {
                    HotkeyActionController.shared.handle(hotkey)
                    return
                }
                let enabled = event.enabled ?? (hotkey.isToggle ? !(monitor.previewToggleStates[hotkey] ?? false) : false)
                if hotkey.isToggle { monitor.previewToggleStates[hotkey] = enabled }
                guard UserDefaults.standard.bool(forKey: "fnNotificationEnabled") else { return }
                ToastController.shared.show(hotkey: hotkey, enabled: enabled)
            }
        }, nil)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let status = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard status == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            openErrorStatus = status
            AppLogger.error(openError ?? L10n.text("HID 监听启动失败"))
            return
        }
        openErrorStatus = nil
        self.manager = manager
    }

    func stop() {
        DisplayBrightnessHotkey.shared.stopRepeat()
        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
    }

}
