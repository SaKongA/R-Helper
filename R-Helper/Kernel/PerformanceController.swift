import Foundation

nonisolated enum AsusACPIHardwareMode: UInt64 {
    case balanced = 0
    case performance = 1
    case silent = 2

    var name: String {
        switch self {
        case .balanced: "平衡"
        case .performance: "性能"
        case .silent: "静音"
        }
    }
}

nonisolated final class PerformanceController {
    private let client: AsusACPIClient

    init(client: AsusACPIClient) { self.client = client }

    // 读取固件当前性能模式
    func readMode() throws -> AsusACPIHardwareMode {
        var request = AsusACPIRequest()
        request.operation = UInt32(AsusACPIOpPerformanceReadMode.rawValue)
        let input = withUnsafeBytes(of: &request) { Data($0) }
        let data = try client.exchange(selector: UInt32(AsusACPICommandController.rawValue), input: input, outputSize: MemoryLayout<AsusACPIResponse>.size, suppressUnsupportedLog: true)
        guard data.count == MemoryLayout<AsusACPIResponse>.size else { throw AsusACPIClientError.incompatibleProtocol }
        let response = data.withUnsafeBytes { $0.loadUnaligned(as: AsusACPIResponse.self) }
        guard response.payloadSize <= MemoryLayout.size(ofValue: response.payload),
              let mode = AsusACPIHardwareMode(rawValue: UInt64(response.values.0)) else { throw AsusACPIClientError.incompatibleProtocol }
        AppLogger.info("当前性能模式：\(mode.name)")
        return mode
    }

    // 设置静音、平衡或性能模式
    func setMode(_ mode: AsusACPIHardwareMode) throws {
        try client.send(selector: UInt32(AsusACPICommandSetMode.rawValue), value: mode.rawValue)
        AppLogger.info("已设置性能模式：\(mode.name)")
    }
}
