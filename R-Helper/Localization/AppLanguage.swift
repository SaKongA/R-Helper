import Foundation

nonisolated enum AppLanguage: String, CaseIterable {
    case system
    case chinese = "zh-Hans"
    case english = "en"

    static let preferenceKey = "appLanguage"

    static var selected: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "system") ?? .system
    }

    static var resolved: AppLanguage {
        let selected = selected
        guard selected == .system else { return selected }
        return Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? .chinese : .english
    }

    var title: String {
        switch self {
        case .system: L10n.text("跟随系统")
        case .chinese: "简体中文"
        case .english: "English"
        }
    }
}

nonisolated enum L10n {
    static func text(_ key: String) -> String {
        guard AppLanguage.resolved == .english,
              let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func pair(_ key: String, _ value: String) -> String {
        "\(text(key)): \(value)"
    }
}
