import AppKit
import Combine
import SwiftUI

@MainActor
final class ToastController {
    static let shared = ToastController()

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    func show(_ mode: PerformanceMode) {
        present(ToastContent(mode: mode))
    }

    func show(_ content: ToastContent) {
        present(content)
    }

    func show(hotkey: Hotkey, enabled: Bool) {
        guard let content = ToastContent(hotkey: hotkey, enabled: enabled) else { return }
        present(content)
    }

    private func present(_ content: ToastContent) {
        dismissTask?.cancel()
        panel?.orderOut(nil)

        guard let screen = NSScreen.main else { return }

        let appearance = NSApplication.shared.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let animationState = ToastAnimationState()
        let contentView = NSHostingView(rootView: AnimatedToastView(content: content, isDark: isDark, animationState: animationState))
        let size = contentView.fittingSize
        let target = NSRect(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.minY + 12,
            width: size.width,
            height: size.height
        )
        let panel = NSPanel(
            contentRect: target,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.appearance = appearance
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.contentView = contentView
        contentView.layoutSubtreeIfNeeded()
        contentView.displayIfNeeded()
        panel.orderFrontRegardless()
        self.panel = panel

        DispatchQueue.main.async {
            withAnimation(.spring(duration: 0.4, bounce: 0.12)) {
                animationState.isVisible = true
            }
        }

        dismissTask = Task { [weak self, weak panel] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled, let panel else { return }
            withAnimation(.smooth(duration: 0.22)) {
                animationState.isVisible = false
            }
            try? await Task.sleep(for: .milliseconds(250))
            panel.orderOut(nil)
            if self?.panel === panel {
                self?.panel = nil
            }
        }
    }
}

@MainActor
final class ToastAnimationState: ObservableObject {
    @Published var isVisible = false
}
