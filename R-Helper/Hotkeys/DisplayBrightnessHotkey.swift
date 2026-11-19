import Foundation

@MainActor
final class DisplayBrightnessHotkey {
    static let shared = DisplayBrightnessHotkey()
    private let displayBrightnessQueue = DispatchQueue(label: "com.rhelper.display-brightness")
    private var displayBrightnessRepeat: Task<Void, Never>?
    private var heldBrightnessUp: Bool?
    private var displayBrightnessBusy = false

    func handleKey(up: Bool, pressed: Bool) {
        if !pressed {
            if heldBrightnessUp == up { stopRepeat() }
            return
        }
        guard heldBrightnessUp != up else { return }
        stopRepeat()
        heldBrightnessUp = up
        adjust(up: up)
        displayBrightnessRepeat = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(400))
                for _ in 0..<130 {
                    guard !Task.isCancelled else { return }
                    adjust(up: up)
                    try await Task.sleep(for: .milliseconds(110))
                }
                stopRepeat()
            } catch {}
        }
    }

    func stopRepeat() {
        displayBrightnessRepeat?.cancel()
        displayBrightnessRepeat = nil
        heldBrightnessUp = nil
    }

    func adjust(up: Bool) {
        guard !displayBrightnessBusy else { return }
        displayBrightnessBusy = true
        displayBrightnessQueue.async {
            do {
                let brightness = try DisplayBrightnessController.adjust(up: up)
                let percentage = Int((brightness * 100).rounded())
                AppLogger.info("屏幕亮度：\(percentage)%")
                Task { @MainActor in
                    self.displayBrightnessBusy = false
                    guard UserDefaults.standard.bool(forKey: "fnNotificationEnabled") else { return }
                    ToastController.shared.show(ToastContent(title: "屏幕亮度", detail: "\(percentage)%", symbol: up ? "sun.max" : "sun.min"))
                }
            } catch {
                AppLogger.error("屏幕亮度操作失败：\(error.localizedDescription)")
                Task { @MainActor in
                    self.displayBrightnessBusy = false
                    self.stopRepeat()
                    guard UserDefaults.standard.bool(forKey: "fnNotificationEnabled") else { return }
                    ToastController.shared.show(ToastContent(title: "屏幕亮度", detail: "操作失败", symbol: "exclamationmark.circle"))
                }
            }
        }
    }

}
