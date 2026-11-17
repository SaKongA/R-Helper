import SwiftUI

struct MenuRow: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let isSelected: Bool
    let isLast: Bool
    let showsSubmenuArrow: Bool
    let action: () -> Void
    @State private var isHovered = false

    init(_ title: String, isSelected: Bool = false, isLast: Bool = false, showsSubmenuArrow: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.isLast = isLast
        self.showsSubmenuArrow = showsSubmenuArrow
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Checkmark(isSelected: isSelected)
                    .frame(width: 14, height: 12)
                Text(title)
                Spacer(minLength: 0)
                if showsSubmenuArrow {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(!isEnabled ? Color.secondary : isHovered ? Color.white : Color.primary)
            .background(
                isEnabled && isHovered ? Color.accentColor : Color.clear,
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: isLast ? 10 : 4,
                    bottomTrailingRadius: isLast ? 10 : 4,
                    topTrailingRadius: 4
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
