import Foundation

nonisolated enum AsusACPIHardwareFan: UInt32 {
    case cpu = 0
    case gpu = 1
    case middle = 2
}

nonisolated struct CPUSensorSample: Sendable {
    let frequencyMHz: Double
    let temperatureCelsius: Double
    let powerWatts: Double
    let details: AMDRyzenSample
}

nonisolated struct FanSensorSample: Sendable {
    let cpuRPM: UInt32?
    let gpuRPM: UInt32?
}

nonisolated struct HardwareSensorSample: Sendable {
    let driver: KextConnectionStatus
    let cpu: CPUSensorSample?
    let cpuUsagePercent: Double?
    let cpuInfo: CPUInfo
    let gpuModel: String?
    let gpuStatistics: GPUStatistics?
    let fans: FanSensorSample?
    let gpuTemperature: UInt32?
    let batteryDischarge: Double?
}

nonisolated enum KextConnectionStatus: Sendable {
    case connected(UInt32)
    case disconnected(any Error)
}

nonisolated final class SensorController: @unchecked Sendable {
    private let client: AsusACPIClient
    private let amdRyzen = AMDRyzenClient()
    private let cpuUsageReader = CPUUsageReader()

    init(client: AsusACPIClient = AsusACPIClient()) { self.client = client }

    // 读取 CPU 频率、温度和功耗
    func readCPU() throws -> CPUSensorSample {
        let sample = try amdRyzen.readSample()
        return CPUSensorSample(frequencyMHz: sample.frequencyMHz, temperatureCelsius: sample.temperatureCelsius, powerWatts: sample.powerWatts, details: sample)
    }

    // 读取指定风扇转速
    func readFanSpeed(_ fan: AsusACPIHardwareFan) throws -> UInt32 {
        try read(AsusACPIOpFanReadSpeed, argument: fan.rawValue)
    }

    // 读取 CPU 和 GPU 风扇转速
    func readFanSpeeds() throws -> FanSensorSample {
        try client.connect()
        let cpu = try? readFanSpeed(.cpu)
        let gpu = try? readFanSpeed(.gpu)
        if cpu == nil && gpu == nil { client.disconnect() }
        return FanSensorSample(cpuRPM: cpu, gpuRPM: gpu)
    }

    // 读取 CPU 或 GPU 温度
    func readTemperature(_ fan: AsusACPIHardwareFan) throws -> UInt32 {
        try read(AsusACPIOpFanReadTemperature, argument: fan.rawValue)
    }

    // 读取电池放电功率
    func readBatteryDischarge() throws -> Double {
        let value = try read(AsusACPIOpPowerReadBatteryDischarge)
        return Double(Int32(bitPattern: value)) / 100
    }

    // 读取全部可用的监测数据
    func readHardware(resetCPUUsage: Bool = false) -> HardwareSensorSample {
        if resetCPUUsage { cpuUsageReader.reset() }
        let cpu = try? readCPU()
        let cpuUsage = cpuUsageReader.read()
        let cpuInfo = readCPUInfo()
        let gpu = readGPUDevice()
        let gpuStatistics = gpu.flatMap { GPUStatisticsReader.read(device: $0) }
        let driver: KextConnectionStatus
        let state: AsusACPIState
        do {
            try client.connect()
            state = try AsusACPIController(client: client).readState(logDetails: false)
            driver = .connected(state.version)
        } catch {
            client.disconnect()
            return HardwareSensorSample(driver: .disconnected(error), cpu: cpu, cpuUsagePercent: cpuUsage, cpuInfo: cpuInfo, gpuModel: gpu?.model, gpuStatistics: gpuStatistics, fans: nil, gpuTemperature: nil, batteryDischarge: nil)
        }
        let cpuFan = state.validFields & UInt32(AsusACPIValidCPUFan) != 0 ? state.cpuFanRPM : nil
        let gpuFan = state.validFields & UInt32(AsusACPIValidGPUFan) != 0 ? state.gpuFanRPM : nil
        let gpuTemperature = try? readTemperature(.gpu)
        let batteryDischarge = try? readBatteryDischarge()
        return HardwareSensorSample(driver: driver, cpu: cpu, cpuUsagePercent: cpuUsage, cpuInfo: cpuInfo, gpuModel: gpu?.model, gpuStatistics: gpuStatistics, fans: FanSensorSample(cpuRPM: cpuFan, gpuRPM: gpuFan), gpuTemperature: gpuTemperature, batteryDischarge: batteryDischarge)
    }

    // 读取系统提供的 CPU 信息
    func readCPUInfo() -> CPUInfo {
        CPUInfoReader.read()
    }

    // 读取系统识别的 GPU 型号
    func readGPUDevice() -> GPUDevice? {
        GPUModelReader.read()
    }

    private func read(_ operation: AsusACPIOperation, argument: UInt32 = 0) throws -> UInt32 {
        var request = AsusACPIRequest()
        request.operation = UInt32(operation.rawValue)
        request.arguments.0 = argument
        let input = withUnsafeBytes(of: &request) { Data($0) }
        let data = try client.exchange(selector: UInt32(AsusACPICommandController.rawValue), input: input, outputSize: MemoryLayout<AsusACPIResponse>.size)
        guard data.count == MemoryLayout<AsusACPIResponse>.size else { throw AsusACPIClientError.incompatibleProtocol }
        let response = data.withUnsafeBytes { $0.loadUnaligned(as: AsusACPIResponse.self) }
        guard response.payloadSize <= MemoryLayout.size(ofValue: response.payload) else { throw AsusACPIClientError.incompatibleProtocol }
        return response.values.0
    }
}
