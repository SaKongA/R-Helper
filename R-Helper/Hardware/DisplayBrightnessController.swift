import CoreGraphics
import Darwin
import Foundation

nonisolated enum DisplayBrightnessError: LocalizedError {
    case displayUnavailable
    case interfaceUnavailable
    case readFailed(Int32)
    case writeFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .displayUnavailable: L10n.text("未找到内置显示器")
        case .interfaceUnavailable: L10n.text("屏幕亮度接口不可用")
        case .readFailed(let status): L10n.pair("读取屏幕亮度失败", "\(status)")
        case .writeFailed(let status): L10n.pair("设置屏幕亮度失败", "\(status)")
        }
    }
}

nonisolated enum DisplayBrightnessController {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    static func adjust(up: Bool) throws -> Float {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
            throw DisplayBrightnessError.displayUnavailable
        }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        let result = displays.withUnsafeMutableBufferPointer {
            CGGetOnlineDisplayList(UInt32($0.count), $0.baseAddress, &count)
        }
        guard result == .success,
              let display = displays.prefix(Int(count)).first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
            throw DisplayBrightnessError.displayUnavailable
        }

        guard let framework = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY | RTLD_LOCAL) else {
            throw DisplayBrightnessError.interfaceUnavailable
        }
        defer { dlclose(framework) }
        guard let getSymbol = dlsym(framework, "DisplayServicesGetBrightness"),
              let setSymbol = dlsym(framework, "DisplayServicesSetBrightness") else {
            throw DisplayBrightnessError.interfaceUnavailable
        }
        let getBrightness = unsafeBitCast(getSymbol, to: GetBrightness.self)
        let setBrightness = unsafeBitCast(setSymbol, to: SetBrightness.self)
        var brightness: Float = 0
        let readStatus = getBrightness(display, &brightness)
        guard readStatus == 0, brightness.isFinite, (0...1).contains(brightness) else {
            throw DisplayBrightnessError.readFailed(readStatus)
        }
        let position = sqrt(brightness)
        let next = min(1, max(0, position + (up ? 1.0 / 16.0 : -1.0 / 16.0)))
        if next != position {
            for step in 1...8 {
                let progress = Float(step) / 8
                let value = position + (next - position) * progress
                let writeStatus = setBrightness(display, value * value)
                guard writeStatus == 0 else { throw DisplayBrightnessError.writeFailed(writeStatus) }
                if step < 8 { usleep(10_000) }
            }
        }
        let confirmStatus = getBrightness(display, &brightness)
        guard confirmStatus == 0, brightness.isFinite, (0...1).contains(brightness) else {
            throw DisplayBrightnessError.readFailed(confirmStatus)
        }
        return brightness
    }
}
