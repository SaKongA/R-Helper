import AppKit
import SwiftUI

struct FnShortcutMenuRow: View {
    @State private var anchor: NSView?
    @State private var isLoading = false

    var body: some View {
        MenuRow(L10n.text("Fn 快捷键"), showsSubmenuArrow: true) {
            guard !isLoading else { return }
            isLoading = true
            Task { @MainActor in
                let result = await Task.detached(priority: .userInitiated) {
                    Result { try ShortcutsCommand.list() }
                }.value
                isLoading = false
                guard let anchor, anchor.window != nil else { return }
                showMenu(result, at: anchor)
            }
        }
        .background(NativeMenuAnchor(view: $anchor))
    }

    private func showMenu(_ result: Result<[SystemShortcut], Error>, at anchor: NSView) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        switch result {
        case .failure:
            let item = NSMenuItem(title: L10n.text("无法读取快捷指令"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        case .success(let shortcuts):
            for (key, title) in ShortcutBindings.keys {
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                let submenu = NSMenu(title: title)
                submenu.autoenablesItems = false
                let selected = ShortcutBindings.shared.identifier(for: key)
                let none = NSMenuItem(title: L10n.text("不绑定"), action: #selector(ShortcutBindings.select(_:)), keyEquivalent: "")
                none.target = ShortcutBindings.shared
                none.representedObject = ["key": String(key.rawValue)]
                none.state = selected == nil ? .on : .off
                submenu.addItem(none)
                if shortcuts.isEmpty {
                    let empty = NSMenuItem(title: L10n.text("没有快捷指令"), action: nil, keyEquivalent: "")
                    empty.isEnabled = false
                    submenu.addItem(empty)
                }
                for shortcut in shortcuts {
                    let option = NSMenuItem(title: shortcut.name, action: #selector(ShortcutBindings.select(_:)), keyEquivalent: "")
                    option.target = ShortcutBindings.shared
                    option.representedObject = ["key": String(key.rawValue), "identifier": shortcut.identifier, "name": shortcut.name]
                    option.state = selected == shortcut.identifier ? .on : .off
                    submenu.addItem(option)
                }
                item.submenu = submenu
                menu.addItem(item)
            }
        }
        menu.popUp(positioning: nil, at: NSPoint(x: anchor.bounds.maxX, y: anchor.bounds.maxY), in: anchor)
    }
}
