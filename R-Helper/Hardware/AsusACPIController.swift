import Foundation

nonisolated final class AsusACPIController {
    private let client: AsusACPIClient

    init(client: AsusACPIClient) { self.client = client }

    // 调用驱动控制器接口
    func call(_ operation: AsusACPIOperation, arguments: [UInt32] = []) throws -> AsusACPIResponse {
        guard arguments.count <= 8 else { throw AsusACPIClientError.incompatibleProtocol }
        var request = AsusACPIRequest()
        request.operation = UInt32(operation.rawValue)
        withUnsafeMutableBytes(of: &request.arguments) { buffer in
            for (index, value) in arguments.enumerated() {
                buffer.storeBytes(of: value, toByteOffset: index * MemoryLayout<UInt32>.stride, as: UInt32.self)
            }
        }
        let input = withUnsafeBytes(of: &request) { Data($0) }
        let data = try client.exchange(selector: UInt32(AsusACPICommandController.rawValue), input: input, outputSize: MemoryLayout<AsusACPIResponse>.size)
        guard data.count == MemoryLayout<AsusACPIResponse>.size else { throw AsusACPIClientError.incompatibleProtocol }
        let response = data.withUnsafeBytes { $0.loadUnaligned(as: AsusACPIResponse.self) }
        guard response.payloadSize <= MemoryLayout.size(ofValue: response.payload) else { throw AsusACPIClientError.incompatibleProtocol }
        return response
    }

    // 读取驱动版本与状态
    func readState(logDetails: Bool = true) throws -> AsusACPIState {
        let data = try client.exchange(selector: UInt32(AsusACPICommandGetState.rawValue), outputSize: MemoryLayout<AsusACPIState>.size)
        guard data.count == MemoryLayout<AsusACPIState>.size else { throw AsusACPIClientError.incompatibleProtocol }
        let state = data.withUnsafeBytes { $0.loadUnaligned(as: AsusACPIState.self) }
        guard state.version == AsusACPIProtocolVersion else { throw AsusACPIClientError.incompatibleProtocol }
        if logDetails {
            AppLogger.info(String(format: "扩展协议版本 %u，能力 0x%08X，有效字段 0x%08X", state.version, state.capabilities, state.validFields))
            if state.validFields & UInt32(AsusACPIValidCPUFan) != 0 { AppLogger.info("CPU 风扇 \(state.cpuFanRPM) RPM") }
            if state.validFields & UInt32(AsusACPIValidGPUFan) != 0 { AppLogger.info("GPU 风扇 \(state.gpuFanRPM) RPM") }
        }
        return state
    }

    // 在后台读取扩展信息和当前性能模式
    static func readStartupInformation(completion: @escaping @Sendable (AsusACPIHardwareMode?) -> Void) {
        AsusACPIClient.run { () throws -> AsusACPIHardwareMode? in
            let client = AsusACPIClient()
            try client.connect()
            defer { client.disconnect() }
            do { _ = try AsusACPIController(client: client).readState() }
            catch { AppLogger.error("读取扩展信息失败：\(error)") }
            do { return try PerformanceController(client: client).readMode() }
            catch let error as AsusACPIClientError where error.isUnsupported {
                AppLogger.info("无法读取或识别固件性能模式，将使用已保存的模式或初始化平衡模式")
                return nil
            }
        } completion: { result in
            switch result {
            case .success(let mode): completion(mode)
            case .failure(let error):
                AppLogger.error("读取驱动状态失败：\(error.localizedDescription)")
                if (error as? AsusACPIClientError) == .timeout {
                    Task { @MainActor in
                        ToastController.shared.show(ToastContent(title: "驱动", detail: "驱动未响应", symbol: "exclamationmark.circle"))
                    }
                }
                completion(nil)
            }
        }
    }
}
