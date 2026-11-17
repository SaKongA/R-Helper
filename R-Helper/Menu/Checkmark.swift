import SwiftUI

struct Checkmark: View {
    let isSelected: Bool

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 2, y: 6))
            path.addLine(to: CGPoint(x: 5, y: 9))
            path.addLine(to: CGPoint(x: 12, y: 2))
        }
        .trim(from: 0, to: isSelected ? 1 : 0)
        .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        .animation(.easeInOut(duration: 0.22), value: isSelected)
        .accessibilityHidden(true)
    }
}
