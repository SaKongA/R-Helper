import Foundation

nonisolated enum TouchpadControllerError: LocalizedError {
    case stateMismatch

    var errorDescription: String? { L10n.text("触控板状态与请求不一致") }
}

nonisolated final class TouchpadController {
    private let kernel: KernelController

    init(client: AsusACPIClient) { kernel = KernelController(client: client) }

    // 读取触控板状态
    func readEnabled() throws -> Bool {
        let value = try kernel.call(AsusACPIOpTouchpadRead).values.0
        guard value <= 1 else { throw AsusACPIClientError.incompatibleProtocol }
        return value == 1
    }

    // 设置触控板状态并确认结果
    func setEnabled(_ enabled: Bool) throws -> Bool {
        _ = try kernel.call(AsusACPIOpTouchpadSet, arguments: [enabled ? 1 : 0])
        let actual = try readEnabled()
        guard actual == enabled else { throw TouchpadControllerError.stateMismatch }
        return actual
    }

    // 切换触控板状态
    func toggle() throws -> Bool {
        try setEnabled(!readEnabled())
    }
}
