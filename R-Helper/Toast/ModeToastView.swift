import SwiftUI

struct ModeToastView: View {
    let content: ToastContent
    let isDark: Bool

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if content.isAsset {
                    Image(content.symbol)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: content.symbol)
                        .font(.system(size: 24, weight: .medium))
                }
            }
            .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text(content.title))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Text(L10n.text(content.detail))
                    .font(.headline)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 58)
        .background {
            ToastBlurView(isDark: isDark)
                .clipShape(Capsule())
                .overlay {
                    Capsule().fill(Color.black.opacity(isDark ? 0.18 : 0.06))
                }
        }
        .overlay {
            Capsule().strokeBorder(
                LinearGradient(
                    colors: isDark
                        ? [.white.opacity(0.28), .white.opacity(0.08), .white.opacity(0.14)]
                        : [.white.opacity(0.8), .black.opacity(0.08), .black.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .padding(3)
    }
}
