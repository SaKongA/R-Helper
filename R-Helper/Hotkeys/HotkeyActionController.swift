import Foundation

@MainActor
final class HotkeyActionController {
    static let shared = HotkeyActionController()
    private var busy = false
    private let backlightQueue = DispatchQueue(label: "com.rhelper.keyboard-backlight")

    func handle(_ hotkey: Hotkey) {
        if hotkey == .menu {
            MenuPresentation.shared.isPresented.toggle()
            return
        }
        if hotkey == .brightnessUp || hotkey == .brightnessDown {
            DisplayBrightnessHotkey.shared.adjust(up: hotkey == .brightnessUp)
            return
        }
        if hotkey == .performanceMode {
            cyclePerformanceMode()
            return
        }
        if hotkey == .keyboardLightUp || hotkey == .keyboardLightDown {
            adjustBacklight(up: hotkey == .keyboardLightUp)
            return
        }
        guard (hotkey == .fnLock || hotkey == .touchpad), !busy else { return }
        let isTouchpad = hotkey == .touchpad
        busy = true
        AsusACPIClient.run {
            let client = AsusACPIClient()
            defer { Task { @MainActor in self.busy = false } }
            try client.connect()
            defer { client.disconnect() }
            if isTouchpad { return try TouchpadController(client: client).toggle() }
            return try KeyboardController(client: client).toggleFnLock()
        } completion: { result in
            Task { @MainActor in
                switch result {
                case .success(let enabled):
                    AppLogger.info("\(isTouchpad ? "触控板" : "Fn 锁")：\(enabled ? "开启" : "关闭")")
                    guard UserDefaults.standard.bool(forKey: "fnNotificationEnabled") else { return }
                    ToastController.shared.show(hotkey: isTouchpad ? .touchpad : .fnLock, enabled: enabled)
                case .failure(let error):
                    AppLogger.error("\(isTouchpad ? "触控板" : "Fn 锁")操作失败：\(error.localizedDescription)")
                    let detail = (error as? AsusACPIClientError) == .timeout ? "驱动未响应" : "操作失败"
                    guard UserDefaults.standard.bool(forKey: "fnNotificationEnabled") else { return }
                    ToastController.shared.show(ToastContent(title: isTouchpad ? "触控板" : "Fn 锁", detail: detail, symbol: "exclamationmark.circle"))
                }
            }
        }
    }

    private func cyclePerformanceMode() {
        let state = PerformanceState.shared
        guard !state.isApplying else { return }
        let modes = PerformanceMode.allCases
        let next: PerformanceMode
        if let current = state.mode, let index = modes.firstIndex(of: current) {
            next = modes[(index + 1) % modes.count]
        } else {
            next = .balanced
        }
        state.select(next, showToast: UserDefaults.standard.bool(forKey: "fnNotificationEnabled"))
    }

    private func adjustBacklight(up: Bool) {
        backlightQueue.async {
            let defaults = UserDefaults.standard
            let key = "keyboardBacklightBrightness"
            let stored = defaults.object(forKey: key) == nil ? 1 : defaults.integer(forKey: key)
            let current = min(3, max(0, stored))
            let brightness = min(3, max(0, current + (up ? 1 : -1)))
            do {
                let client = AsusACPIClient()
                try client.connect()
                defer { client.disconnect() }
                try KeyboardController(client: client).setBacklightBrightness(UInt32(brightness))
                defaults.set(brightness, forKey: key)
                AppLogger.info("键盘背光亮度：\(brightness)")
                Task { @MainActor in
                    guard UserDefaults.standard.bool(forKey: "fnNotificationEnabled") else { return }
                    let levels = ["关闭", "低", "中", "高"]
                    ToastController.shared.show(ToastContent(title: "键盘背光", detail: levels[brightness], symbol: up ? "KeyboardLightUp" : "KeyboardLightDown", isAsset: true))
                }
            } catch {
                AppLogger.error("键盘背光操作失败：\(error.localizedDescription)")
                Task { @MainActor in
                    guard UserDefaults.standard.bool(forKey: "fnNotificationEnabled") else { return }
                    ToastController.shared.show(ToastContent(title: "键盘背光", detail: "操作失败", symbol: "exclamationmark.circle"))
                }
            }
        }
    }
}
