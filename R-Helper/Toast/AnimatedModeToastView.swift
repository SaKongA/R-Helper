import SwiftUI

struct AnimatedModeToastView: View {
    let content: ToastContent
    let isDark: Bool
    @ObservedObject var animationState: ToastAnimationState

    var body: some View {
        ModeToastView(content: content, isDark: isDark)
            .compositingGroup()
            .offset(y: animationState.isVisible ? 0 : 8)
            .opacity(animationState.isVisible ? 1 : 0)
            .padding(.vertical, 8)
    }
}
