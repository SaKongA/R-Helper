import Combine
import Foundation

@MainActor
final class HardwareMonitoringState: ObservableObject {
    static let shared = HardwareMonitoringState()

    enum State {
        case stopped
        case loading
        case refreshing(HardwareSensorSample)
        case ready(HardwareSensorSample)
    }

    @Published private(set) var state: State = .stopped
    var sample: HardwareSensorSample? {
        switch state {
        case .refreshing(let sample), .ready(let sample): sample
        case .stopped, .loading: nil
        }
    }
    var driverStatus: KextConnectionStatus? { sample?.driver }

    private let controller = SensorController()
    private let samplingQueue = DispatchQueue(label: "com.rhelper.hardware-monitoring", qos: .utility)
    private var task: Task<Void, Never>?
    private var generation = UUID()

    func start() {
        guard task == nil else { return }
        let generation = UUID()
        self.generation = generation
        state = .loading
        task = Task { @MainActor in
            let clock = ContinuousClock()
            var firstSample = true
            while !Task.isCancelled {
                let deadline = clock.now.advanced(by: .milliseconds(1500))
                if let sample { state = .refreshing(sample) }
                let sample = await readSample(resetCPUUsage: firstSample)
                firstSample = false
                guard !Task.isCancelled, self.generation == generation else { break }
                state = .ready(sample)
                do { try await clock.sleep(until: deadline) }
                catch { break }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        generation = UUID()
        state = .stopped
    }

    private func readSample(resetCPUUsage: Bool) async -> HardwareSensorSample {
        let controller = controller
        return await withCheckedContinuation { continuation in
            samplingQueue.async {
                continuation.resume(returning: controller.readHardware(resetCPUUsage: resetCPUUsage))
            }
        }
    }
}
