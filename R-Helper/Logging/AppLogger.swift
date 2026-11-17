import Foundation
import Combine

@MainActor
final class AppLogStore: ObservableObject {
    static let shared = AppLogStore()
    @Published private(set) var entries: [String] = []

    func append(_ entry: String) {
        entries.append(entry)
        if entries.count > 200 { entries.removeFirst(entries.count - 200) }
    }
}

nonisolated enum AppLogger {
    static func info(_ message: String) {
        NSLog("%@", "[INFO] R-Helper: \(message)")
        Task { @MainActor in AppLogStore.shared.append("[INFO] \(message)") }
    }

    static func error(_ message: String) {
        NSLog("%@", "[ERROR] R-Helper: \(message)")
        Task { @MainActor in AppLogStore.shared.append("[ERROR] \(message)") }
    }
}
