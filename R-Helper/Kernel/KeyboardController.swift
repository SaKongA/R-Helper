import Foundation

nonisolated final class KeyboardController {
    private let kernel: KernelController

    init(client: AsusACPIClient) { kernel = KernelController(client: client) }

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
        _ = try kernel.call(AsusACPIOpKeyboardSetBrightness, arguments: [brightness])
    }
}
