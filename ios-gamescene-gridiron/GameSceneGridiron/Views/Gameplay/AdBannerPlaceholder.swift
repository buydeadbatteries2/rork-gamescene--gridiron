import SwiftUI

/// Reserved space for a future banner ad. Fixed height so it never overlaps gameplay.
struct AdBannerPlaceholder: View {
    static let height: CGFloat = 50

    var body: some View {
        Text("AdBannerPlaceholder")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.paperInk.opacity(0.4))
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .background {
                PaperSurface(cornerRadius: 6, darkness: 0.2)
                    .opacity(0.55)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6).strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                CautionTape(stripeWidth: 5)
                    .frame(width: 40, height: 8)
                    .rotationEffect(.degrees(35))
                    .offset(x: 8, y: 4)
            }
            .clipShape(.rect(cornerRadius: 6))
            .accessibilityHidden(true)
    }
}
