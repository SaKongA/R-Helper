import Darwin
import Foundation

nonisolated final class CPUUsageReader {
    private var previousTicks: [UInt32]?
    private var previousTime: TimeInterval?

    func reset() {
        previousTicks = nil
        previousTime = nil
    }

    func read() -> Double? {
        var info = host_cpu_load_info_data_t()
        let expectedCount = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var count = expectedCount
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS, count == expectedCount else {
            reset()
            return nil
        }
        let ticks = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
        let now = ProcessInfo.processInfo.systemUptime
        defer { previousTicks = ticks; previousTime = now }
        guard let previousTicks, let previousTime, now - previousTime <= 5,
              zip(ticks, previousTicks).allSatisfy({ $0 >= $1 }) else { return nil }
        let deltas = zip(ticks, previousTicks).map { UInt64($0 - $1) }
        let total = deltas.reduce(0, +)
        guard total > 0 else { return nil }
        return Double(total - deltas[Int(CPU_STATE_IDLE)]) / Double(total) * 100
    }
}
