import Combine

@MainActor
final class ToastAnimationState: ObservableObject {
    @Published var isVisible = false
}
