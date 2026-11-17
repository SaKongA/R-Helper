import Foundation
import IOKit

nonisolated enum AsusACPIClientError: LocalizedError, Equatable {
    case serviceNotFound
    case notConnected
    case incompatibleProtocol
    case ioReturn(kern_return_t)
    case timeout

    var isUnsupported: Bool {
        if case .ioReturn(let status) = self { return UInt32(bitPattern: status) == 0xE00002C7 }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .serviceNotFound: L10n.text("未找到驱动服务")
        case .notConnected: L10n.text("驱动未连接")
        case .incompatibleProtocol: L10n.text("驱动协议或返回数据不兼容")
        case .ioReturn(let status): String(format: L10n.text("IOKit 错误 0x%08X"), UInt32(bitPattern: status))
        case .timeout: L10n.text("驱动未在规定时间内回复，操作结果未知")
        }
    }
}

private nonisolated final class AsusACPICompletionGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private let completion: @Sendable (Result<Value, Error>) -> Void

    init(completion: @escaping @Sendable (Result<Value, Error>) -> Void) {
        self.completion = completion
    }

    func finish(_ result: Result<Value, Error>) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        lock.unlock()
        completion(result)
    }
}

nonisolated final class AsusACPIClient {
    private let lock = NSLock()
    private var connection: io_connect_t = 0

    deinit { disconnect() }

    // 在后台执行驱动操作并处理超时
    static func run<Value>(timeout: TimeInterval = 5, operation: @escaping @Sendable () throws -> Value, completion: @escaping @Sendable (Result<Value, Error>) -> Void) {
        let gate = AsusACPICompletionGate(completion: completion)
        DispatchQueue.global(qos: .userInitiated).async {
            gate.finish(Result { try operation() })
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
            gate.finish(.failure(AsusACPIClientError.timeout))
        }
    }

    // 连接华硕 ACPI 驱动
    func connect() throws {
        lock.lock()
        defer { lock.unlock() }
        if connection != 0 { return }
        try logged("连接驱动") {
            guard let matching = IOServiceMatching("AsusACPIService") else { throw AsusACPIClientError.serviceNotFound }
            let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
            guard service != 0 else { throw AsusACPIClientError.serviceNotFound }
            defer { IOObjectRelease(service) }
            var opened: io_connect_t = 0
            let status = IOServiceOpen(service, mach_task_self_, 0, &opened)
            guard status == KERN_SUCCESS else { throw AsusACPIClientError.ioReturn(status) }
            connection = opened
            AppLogger.info("AsusACPIService 已连接")
        }
    }

    // 关闭与驱动的连接
    func disconnect() {
        lock.lock()
        defer { lock.unlock() }
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    // 发送结构化请求并接收返回数据
    func exchange(selector: UInt32, input: Data = Data(), outputSize: Int, suppressUnsupportedLog: Bool = false) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        return try logged("驱动请求 \(selector)", suppressUnsupported: suppressUnsupportedLog) {
            guard connection != 0 else { throw AsusACPIClientError.notConnected }
            guard outputSize >= 0 else { throw AsusACPIClientError.incompatibleProtocol }
            var output = Data(count: outputSize)
            var size = outputSize
            let status = input.withUnsafeBytes { inputBytes in
                output.withUnsafeMutableBytes { outputBytes in
                    IOConnectCallStructMethod(connection, selector, inputBytes.baseAddress, inputBytes.count, outputBytes.baseAddress, &size)
                }
            }
            guard status == KERN_SUCCESS else { throw AsusACPIClientError.ioReturn(status) }
            guard size <= outputSize else { throw AsusACPIClientError.incompatibleProtocol }
            output.count = size
            return output
        }
    }

    // 发送单个数值请求
    func send(selector: UInt32, value: UInt64) throws {
        lock.lock()
        defer { lock.unlock() }
        try logged("驱动请求 \(selector)") {
            guard connection != 0 else { throw AsusACPIClientError.notConnected }
            var input = value
            let status = IOConnectCallScalarMethod(connection, selector, &input, 1, nil, nil)
            guard status == KERN_SUCCESS else { throw AsusACPIClientError.ioReturn(status) }
        }
    }

    private func logged<T>(_ operation: String, suppressUnsupported: Bool = false, _ action: () throws -> T) throws -> T {
        do { return try action() }
        catch {
            if !suppressUnsupported || (error as? AsusACPIClientError)?.isUnsupported != true {
                AppLogger.error("\(operation)失败：\(Self.describe(error))")
            }
            throw error
        }
    }

    private static func describe(_ error: Error) -> String {
        error.localizedDescription
    }
}
