import Combine
import Foundation
import SwiftUI

@MainActor
final class PerformanceState: ObservableObject {
    static let shared = PerformanceState()
    private let savedModeKey = "lastSuccessfulPerformanceMode"
    @Published private(set) var mode: PerformanceMode? = UserDefaults.standard.string(forKey: "lastSuccessfulPerformanceMode").flatMap(PerformanceMode.init(rawValue:))
    @Published private(set) var isApplying = false
    private var hasRequestedChange = false

    func initialize(hardwareMode: AsusACPIHardwareMode?) {
        guard !hasRequestedChange else { return }
        if UserDefaults.standard.string(forKey: savedModeKey).flatMap(PerformanceMode.init(rawValue:)) == nil {
            select(.balanced, showToast: false)
        } else if let hardwareMode {
            update(from: hardwareMode)
        }
    }

    func update(from hardwareMode: AsusACPIHardwareMode) {
        guard !hasRequestedChange else { return }
        switch hardwareMode {
        case .silent: mode = .silent
        case .balanced: mode = .balanced
        case .performance: mode = .performance
        }
    }

    func select(_ selected: PerformanceMode, showToast: Bool = true) {
        guard !isApplying else { return }
        hasRequestedChange = true
        let hardwareMode: AsusACPIHardwareMode
        switch selected {
        case .silent: hardwareMode = .silent
        case .balanced: hardwareMode = .balanced
        case .performance: hardwareMode = .performance
        }
        isApplying = true
        AsusACPIClient.run {
            let client = AsusACPIClient()
            try client.connect()
            defer { client.disconnect() }
            let controller = PerformanceController(client: client)
            try controller.setMode(hardwareMode)
        } completion: { result in
            Task { @MainActor in
                self.isApplying = false
                switch result {
                case .success:
                    UserDefaults.standard.set(selected.rawValue, forKey: self.savedModeKey)
                    withAnimation(.easeInOut(duration: 0.18)) { self.mode = selected }
                    if showToast { ModeToastController.shared.show(selected) }
                case .failure(let error):
                    AppLogger.error("性能模式操作失败：\(error.localizedDescription)")
                    let detail = (error as? AsusACPIClientError) == .timeout ? "驱动未响应" : "操作失败"
                    if showToast { ModeToastController.shared.show(ToastContent(title: "性能模式", detail: detail, symbol: "exclamationmark.circle")) }
                }
            }
        }
    }
}
