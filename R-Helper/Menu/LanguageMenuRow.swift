import AppKit
import SwiftUI

@MainActor
private final class LanguageMenuAction: NSObject {
    static let shared = LanguageMenuAction()

    @objc func select(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, AppLanguage(rawValue: value) != nil else { return }
        UserDefaults.standard.set(value, forKey: AppLanguage.preferenceKey)
    }
}

struct LanguageMenuRow: View {
    @AppStorage("appLanguage") private var language = "system"
    @State private var anchor: NSView?

    var body: some View {
        MenuRow(L10n.text("语言"), showsSubmenuArrow: true) {
            guard let anchor else { return }
            let menu = NSMenu()
            menu.autoenablesItems = false
            for option in AppLanguage.allCases {
                let item = NSMenuItem(title: option.title, action: #selector(LanguageMenuAction.select(_:)), keyEquivalent: "")
                item.target = LanguageMenuAction.shared
                item.representedObject = option.rawValue
                item.state = option.rawValue == language ? .on : .off
                menu.addItem(item)
            }
            menu.popUp(positioning: nil, at: NSPoint(x: anchor.bounds.maxX, y: anchor.bounds.maxY), in: anchor)
        }
        .background(NativeMenuAnchor(view: $anchor))
    }
}
