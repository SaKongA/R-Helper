import Combine
import Foundation

@MainActor
final class HardwareMonitoringState: ObservableObject {
    static let shared = HardwareMonitoringState()
    @Published private(set) var sample: HardwareSensorSample?
    var driverStatus: KextConnectionStatus? { sample?.driver }
    private var task: Task<Void, Never>?

    func start() {
        guard task == nil else { return }
        task = Task { @MainActor in
            let controller = SensorController()
            let clock = ContinuousClock()
            while !Task.isCancelled {
                let deadline = clock.now.advanced(by: .milliseconds(1500))
                let sample = await Task.detached(priority: .utility) {
                    controller.readHardware()
                }.value
                guard !Task.isCancelled else { break }
                self.sample = sample
                do { try await clock.sleep(until: deadline) }
                catch { break }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        sample = nil
    }
}
