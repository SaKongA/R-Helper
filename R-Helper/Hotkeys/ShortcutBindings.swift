import AppKit
import Foundation

nonisolated struct SystemShortcut: Sendable {
    let name: String
    let identifier: String
}

nonisolated enum ShortcutsCommand {
    static func list() throws -> [SystemShortcut] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list", "--show-identifiers"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, let text = String(data: data, encoding: .utf8) else {
            throw ShortcutCommandError.failed
        }
        return text.split(whereSeparator: \.isNewline).compactMap { line in
            guard line.last == ")", let range = line.range(of: " (", options: .backwards) else { return nil }
            let name = String(line[..<range.lowerBound])
            let id = String(line[range.upperBound..<line.index(before: line.endIndex)])
            guard !name.isEmpty, UUID(uuidString: id) != nil else { return nil }
            return SystemShortcut(name: name, identifier: id)
        }
    }

    static func run(_ identifier: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", identifier]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ShortcutCommandError.failed }
    }
}

nonisolated enum ShortcutCommandError: Error {
    case failed
}

@MainActor
final class ShortcutBindings: NSObject {
    static let shared = ShortcutBindings()
    private let storageKey = "fnShortcutBindings"
    private let namesKey = "fnShortcutNames"

    static let keys: [(Hotkey, String)] = [(.fnF4, "Fn + F4"), (.fnF11, "Fn + F11"), (.fnF12, "Fn + F12"), (.fnC, "Fn + C"), (.fnV, "Fn + V")]

    func identifier(for key: Hotkey) -> String? {
        (UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String])?[String(key.rawValue)]
    }

    @objc func select(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: String], let key = data["key"] else { return }
        var bindings = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] ?? [:]
        bindings[key] = data["identifier"]
        UserDefaults.standard.set(bindings, forKey: storageKey)
        if let identifier = data["identifier"], let name = data["name"] {
            var names = UserDefaults.standard.dictionary(forKey: namesKey) as? [String: String] ?? [:]
            names[identifier] = name
            UserDefaults.standard.set(names, forKey: namesKey)
        }
        DispatchQueue.main.async {
            MenuPresentation.shared.isPresented = true
        }
    }

    func runIfBound(_ key: Hotkey) -> Bool {
        guard let identifier = identifier(for: key) else { return false }
        let savedName = (UserDefaults.standard.dictionary(forKey: namesKey) as? [String: String])?[identifier]
        DispatchQueue.global(qos: .userInitiated).async {
            let name = savedName ?? (try? ShortcutsCommand.list().first { $0.identifier == identifier }?.name) ?? "快捷指令"
            Task { @MainActor in
                self.showFeedback(name: name, result: "正在运行")
            }
            do {
                try ShortcutsCommand.run(identifier)
                Task { @MainActor in
                    self.showFeedback(name: name, result: "运行完成")
                }
            } catch {
                AppLogger.error("快捷指令运行失败：\(error.localizedDescription)")
                Task { @MainActor in
                    self.showFeedback(name: name, result: "运行失败")
                }
            }
        }
        return true
    }

    private func showFeedback(name: String, result: String) {
        guard UserDefaults.standard.bool(forKey: "fnNotificationEnabled") else { return }
        ToastController.shared.show(ToastContent(title: "快捷指令", detail: "\(name) · \(L10n.text(result))", symbol: "sparkles"))
    }
}
