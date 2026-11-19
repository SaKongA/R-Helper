import SwiftUI

enum PerformanceMode: String, CaseIterable, Identifiable {
    case silent = "静音"
    case balanced = "平衡"
    case performance = "性能"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .silent: "leaf.fill"
        case .balanced: "gauge.with.dots.needle.50percent"
        case .performance: "bolt.fill"
        }
    }
}
