import Foundation
import IOKit

nonisolated struct AMDRyzenSample: Sendable {
    let frequencyMHz: Double
    let temperatureCelsius: Double
    let powerWatts: Double
    let coreFrequenciesMHz: [Double]
    let coreLoads: [Double?]
    let pState: UInt64?
    let pStateDefinitions: [UInt64]
    let pStateFrequenciesMHz: [Double]
    let instructionDelta: UInt64?
    let cpuIdentification: [UInt64]
    let driverVersion: String?
    let boostSupported: Bool?
    let boostEnabled: Bool?
    let powerManagement: Bool?
    let lowPowerMode: Bool?
    let highPriorityCores: UInt64?
    let boardVendor: String?
    let boardName: String?
}

nonisolated enum AMDRyzenClientError: Error {
    case serviceNotFound
    case invalidData
    case ioReturn(kern_return_t)
}

nonisolated final class AMDRyzenClient {
    private var connection: io_connect_t = 0

    deinit { disconnect() }

    private func connect() throws {
        if connection != 0 { return }
        guard let matching = IOServiceMatching("AMDRyzenCPUPowerManagement") else {
            throw AMDRyzenClientError.serviceNotFound
        }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { throw AMDRyzenClientError.serviceNotFound }
        defer { IOObjectRelease(service) }

        var opened: io_connect_t = 0
        let openStatus = IOServiceOpen(service, mach_task_self_, 0, &opened)
        guard openStatus == KERN_SUCCESS else { throw AMDRyzenClientError.ioReturn(openStatus) }
        connection = opened
    }

    private func disconnect() {
        if connection != 0 { IOServiceClose(connection); connection = 0 }
    }

    func readSample() throws -> AMDRyzenSample {
        try connect()
        var coreCount: UInt64 = 0
        var scalarCount: UInt32 = 1
        var values = [Float](repeating: 0, count: 1024)
        var outputSize = values.count * MemoryLayout<Float>.stride
        let status = values.withUnsafeMutableBytes { output in
            IOConnectCallMethod(connection, 4, nil, 0, nil, 0, &coreCount, &scalarCount, output.baseAddress, &outputSize)
        }
        guard status == KERN_SUCCESS else { disconnect(); throw AMDRyzenClientError.ioReturn(status) }
        guard scalarCount == 1, coreCount > 0, coreCount <= UInt64(values.count - 3),
              outputSize == (Int(coreCount) + 3) * MemoryLayout<Float>.stride else {
            throw AMDRyzenClientError.invalidData
        }

        let frequencies = values[3..<(Int(coreCount) + 3)]
        guard values[0].isFinite, values[0] >= 0,
              values[1].isFinite, values[1] > 0, values[1] < 150,
              frequencies.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 10000 }) else {
            throw AMDRyzenClientError.invalidData
        }
        let frequency = frequencies.reduce(0.0) { $0 + Double($1) } / Double(coreCount)
        let loads = readValues(selector: 6, type: Float.self) ?? []
        let words = readValues(selector: 0, type: UInt64.self) ?? []
        let clocks = readValues(selector: 1, type: Float.self) ?? []
        let boost = readValues(selector: 11, type: UInt64.self) ?? []
        let board = readBuffer(selector: 16)
        let boardBytes = board?.0 ?? Data()
        let validBoard = board?.1 == 1 && boardBytes.count == 128
        let coreLoads = (0..<Int(coreCount)).map { index -> Double? in
            guard index < loads.count, loads[index].isFinite, (0...1).contains(loads[index]) else { return nil }
            return Double(loads[index])
        }
        return AMDRyzenSample(
            frequencyMHz: frequency,
            temperatureCelsius: Double(values[1]),
            powerWatts: Double(values[0]),
            coreFrequenciesMHz: frequencies.map(Double.init),
            coreLoads: coreLoads,
            pState: readValues(selector: 9, type: UInt64.self)?.first,
            pStateDefinitions: words.count == 8 ? words : [],
            pStateFrequenciesMHz: clocks.count == 8 && clocks.allSatisfy({ $0.isFinite && $0 >= 0 }) ? clocks.map(Double.init) : [],
            instructionDelta: readValues(selector: 5, type: UInt64.self)?.first,
            cpuIdentification: readValues(selector: 7, type: UInt64.self) ?? [],
            driverVersion: readBuffer(selector: 8).flatMap { text($0.0) },
            boostSupported: boost.count == 2 ? boost[0] != 0 : nil,
            boostEnabled: boost.count == 2 && boost[0] != 0 ? boost[1] != 0 : nil,
            powerManagement: readValues(selector: 13, type: UInt64.self)?.first.map { $0 != 0 },
            lowPowerMode: readValues(selector: 18, type: UInt64.self)?.first.map { $0 != 0 },
            highPriorityCores: readValues(selector: 17, type: UInt64.self)?.first,
            boardVendor: validBoard ? text(boardBytes.prefix(64)) : nil,
            boardName: validBoard ? text(boardBytes.suffix(64)) : nil
        )
    }

    private func readBuffer(selector: UInt32) -> (Data, UInt64?)? {
        var data = Data(count: 4096)
        var outputSize = data.count
        var scalar: UInt64 = 0
        var scalarCount: UInt32 = 1
        let status = data.withUnsafeMutableBytes { buffer in
            IOConnectCallMethod(connection, selector, nil, 0, nil, 0, &scalar, &scalarCount, buffer.baseAddress, &outputSize)
        }
        guard status == KERN_SUCCESS, outputSize <= data.count, scalarCount <= 1 else { return nil }
        data.count = outputSize
        return (data, scalarCount == 1 ? scalar : nil)
    }

    private func readValues<T>(selector: UInt32, type: T.Type) -> [T]? {
        guard let data = readBuffer(selector: selector)?.0,
              data.count % MemoryLayout<T>.stride == 0 else { return nil }
        return data.withUnsafeBytes { buffer in
            (0..<(data.count / MemoryLayout<T>.stride)).map {
                buffer.loadUnaligned(fromByteOffset: $0 * MemoryLayout<T>.stride, as: T.self)
            }
        }
    }

    private func text<D: DataProtocol>(_ data: D) -> String? {
        let bytes = Data(data.prefix { $0 != 0 })
        guard let value = String(data: bytes, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
