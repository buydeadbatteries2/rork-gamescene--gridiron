import SwiftUI

/// ONLINE ACCOUNT UNAVAILABLE — the legible status card shown when this build
/// has no Supabase configuration (secrets not injected). Dark translucent
/// case-file panel, parchment text, gold border — never dark-on-dark.
/// Rendered ONLY while configuration is absent; disappears entirely once the
/// Supabase client is ready.
struct AccountUnavailableCard: View {
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .bold))
                Text("ONLINE ACCOUNT UNAVAILABLE")
                    .font(.system(size: 13, weight: .black).width(.condensed))
                    .tracking(1.6)
            }
            .foregroundStyle(Theme.gold)
            Text(message)
                .font(Theme.typewriter(13, relativeTo: .footnote))
                .foregroundStyle(Theme.paper)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
            Text("GUEST PROGRESS IS NEVER LOST — IT JOINS YOUR FILE IF YOU SIGN IN LATER.")
                .font(.system(size: 9, weight: .heavy).width(.condensed))
                .tracking(1.2)
                .foregroundStyle(Theme.paper.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.72), in: .rect(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.gold.opacity(0.55), lineWidth: 1.2) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Online account unavailable. \(message)")
    }
}

#Preview {
    ZStack {
        DeskBackground()
        AccountUnavailableCard(message: "Accounts aren't available in this build — you can keep playing solo.")
            .padding(20)
    }
}
