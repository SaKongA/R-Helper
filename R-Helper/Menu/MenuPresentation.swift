import Combine

@MainActor
final class MenuPresentation: ObservableObject {
    static let shared = MenuPresentation()
    @Published var isPresented = false
}
