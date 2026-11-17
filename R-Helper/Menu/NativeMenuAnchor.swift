import AppKit
import SwiftUI

private final class MenuAnchorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct NativeMenuAnchor: NSViewRepresentable {
    @Binding var view: NSView?

    func makeNSView(context: Context) -> NSView {
        let anchor = MenuAnchorView()
        DispatchQueue.main.async { view = anchor }
        return anchor
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
