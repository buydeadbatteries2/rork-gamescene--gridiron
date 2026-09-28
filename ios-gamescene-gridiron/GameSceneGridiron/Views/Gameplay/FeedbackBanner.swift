import SwiftUI

/// Short stamped message after a placement or hint.
struct FeedbackBanner: View {
    let message: FeedbackMessage

    private var tint: Color {
        switch message.tone {
        case .success: Theme.success
        case .failure: Theme.danger
        case .info: Theme.gold
        case .lead: Theme.caution
        }
    }

    private var symbol: String {
        switch message.tone {
        case .success: "checkmark.seal.fill"
        case .failure: "xmark.octagon.fill"
        case .info: "info.circle.fill"
        case .lead: "lightbulb.max.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(message.title)
                    .font(.system(size: 17, weight: .black).width(.condensed))
                    .tracking(1)
                    .foregroundStyle(message.tone == .success ? Theme.goldLight : .white)
                if let detail = message.detail {
                    Text(detail)
                        .font(Theme.typewriter(12.5, relativeTo: .footnote))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: 0x14110D).opacity(0.94))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.8), lineWidth: 1.5)
                }
                .shadow(color: tint.opacity(0.45), radius: 16)
        }
        .accessibilityElement(children: .combine)
    }
}
