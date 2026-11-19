import SwiftUI

struct ToastContent {
    let title: String
    let detail: String
    let symbol: String
    let isAsset: Bool

    init(mode: PerformanceMode) {
        title = "性能模式"
        detail = mode.rawValue
        symbol = mode.symbol
        isAsset = false
    }

    init(title: String, detail: String, symbol: String, isAsset: Bool = false) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.isAsset = isAsset
    }

    init?(hotkey: Hotkey, enabled: Bool) {
        let state = enabled ? "开启" : "关闭"
        switch hotkey {
        case .keyboardLightUp: self.init(title: "键盘背光", detail: "调亮", symbol: "KeyboardLightUp", isAsset: true)
        case .keyboardLightDown: self.init(title: "键盘背光", detail: "调暗", symbol: "KeyboardLightDown", isAsset: true)
        case .mute: self.init(title: "声音", detail: "静音", symbol: "SoundOff", isAsset: true)
        case .touchpad: self.init(title: "触控板", detail: state, symbol: enabled ? "TrackpadOn" : "TrackpadOff", isAsset: true)
        case .brightnessDown: self.init(title: "屏幕亮度", detail: "调暗", symbol: "sun.min")
        case .brightnessUp: self.init(title: "屏幕亮度", detail: "调亮", symbol: "sun.max")
        case .airplaneMode: self.init(title: "飞行模式", detail: state, symbol: "airplane")
        case .fnLock: self.init(title: "Fn 锁", detail: state, symbol: enabled ? "lock.fill" : "lock.open.fill")
        case .superLock: self.init(title: "Command 锁定", detail: state, symbol: enabled ? "lock.fill" : "lock.open.fill")
        case .camera: self.init(title: "摄像头", detail: "快捷键", symbol: "camera.fill")
        case .previousAuraEffect: self.init(title: "Aura 灯效", detail: "上一灯效", symbol: "sparkles")
        case .keyboardLight: self.init(title: "键盘灯", detail: state, symbol: "keyboard")
        case .performanceMode, .menu, .fnF4, .fnF11, .fnF12, .fnV, .fnC: return nil
        }
    }
}
