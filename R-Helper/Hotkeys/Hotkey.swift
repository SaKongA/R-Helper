import Foundation

enum Hotkey: UInt32 {
    case keyboardLightUp = 0xC4
    case keyboardLightDown = 0xC5
    case mute = 0xE2
    case performanceMode = 0xAE
    case menu = 0x38
    case touchpad = 0x6B
    case brightnessDown = 0x10
    case brightnessUp = 0x20
    case airplaneMode = 0x88
    case fnLock = 0x4E
    case superLock = 0x4F
    case camera = 0x85
    case previousAuraEffect = 0xB2
    case fnF4 = 0xB3
    case fnF11 = 0x10000
    case fnF12 = 0x10001
    case keyboardLight = 0xC7
    case fnV = 0x8A
    case fnC = 0x9E

    static func decode(page: UInt32, usage: UInt32, value: Int) -> (key: Hotkey, enabled: Bool?)? {
        if page == 0x0C, usage == 0xE2, value == 0 { return (.mute, nil) }
        if page == 0x01, usage == 0xC6, value == 1 { return (.fnF12, nil) }
        if page == 0xFF31, usage == UInt32.max {
            if value == 447 { return (.superLock, false) }
            if value == 65983 { return (.superLock, true) }
        }
        guard page == 0xFF31, usage != UInt32.max, value == 1 else { return nil }
        if usage == 0x99 || usage == 0x9D { return (.performanceMode, nil) }
        if usage == 0x6C { return (.fnF11, nil) }
        if usage == 0x88 { return (.fnF12, nil) }
        guard let key = Hotkey(rawValue: usage) else { return nil }
        return (key, nil)
    }

    var isToggle: Bool {
        switch self {
        case .touchpad, .airplaneMode, .fnLock, .superLock, .keyboardLight: true
        default: false
        }
    }
}
