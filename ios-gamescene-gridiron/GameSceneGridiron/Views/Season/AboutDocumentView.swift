import SwiftUI

nonisolated enum AboutDocument: String, Identifiable, CaseIterable {
    case privacy = "Privacy Policy"
    case terms = "Terms of Use"
    case support = "Support"
    var id: String { rawValue }

    var text: String {
        switch self {
        case .privacy:
            return """
            Effective November 9, 2026

            This policy describes how GameScene Gridiron handles information when you use the app. For privacy questions or requests, contact support@ndstriistudios.com.

            INFORMATION AND PURPOSES
            Team and player names, season progress, settings, game statistics and virtual currency records are stored on your device to operate the game. If you create an account, account information such as your email, username and football display name is processed through our authentication service. Online competitive features process match assignments, results and related records to verify play and maintain rankings. Public usernames, display names and competitive results may be visible to other players; your email is not intended for public display.

            PURCHASES AND ADVERTISING
            Apple processes App Store payments. RevenueCat helps validate transactions and manage purchase entitlements; the app does not receive your full payment-card details. Google AdMob and its partners may process device identifiers, advertising interactions, diagnostics and other information under their privacy policies to deliver and measure ads, prevent fraud and manage consent. Ad privacy options are available in Settings when required by Google's consent system. Device tracking permissions and regional consent choices affect available advertising processing.

            SERVICE PROVIDERS
            We use service providers including Supabase for account and online game services, RevenueCat for purchases, and Google AdMob for advertising. They process information according to their services and applicable privacy terms. Information may be processed outside your country. We may disclose information when legally required or necessary to protect users, prevent abuse or secure the service.

            STORAGE AND SECURITY
            Local progress remains on your device unless removed or reset; deleting the app may remove local data. Server-side account and competitive records are retained as needed to provide the service, resolve disputes, prevent fraud and meet legal obligations. No storage or transmission method is completely secure. Do not include sensitive information in team names, player names or public profile fields.

            YOUR CHOICES
            You can change audio and other local preferences in Settings and manage permissions through iOS Settings. Contact support@ndstriistudios.com for access, correction or deletion requests and other rights available in your region. We may need to verify account ownership. Removing the app alone does not delete server-side account records. Purchase records may need to be retained for legal or fraud-prevention purposes.

            CHILDREN AND UPDATES
            The service is not directed to children under 13. If you believe a child has provided personal information, contact us. Review the App Store age rating and obtain any consent required in your region. We may update this policy as features or legal requirements change; the effective date identifies the current version.
            """
        case .terms:
            return """
            Effective November 9, 2026

            By using GameScene Gridiron, you agree to these terms. If you do not agree, stop using the app. Questions may be sent to support@ndstriistudios.com.

            USE OF THE APP
            You receive a limited, personal, non-transferable right to use the app for entertainment, subject to these terms and Apple's applicable terms. You must meet applicable age and consent requirements. Keep your account secure and provide accurate account information. Do not cheat, exploit defects, interfere with services, impersonate others, or use offensive or unlawful names or content.

            GAMEPLAY AND ONLINE FEATURES
            Features, availability and balancing may change. Online features require connectivity and may be interrupted. Competitive results may be verified and invalidated for abuse. We may restrict access for violations or security reasons. The app is not affiliated with or endorsed by the NFL or its teams.

            GAME BALLS AND PURCHASES
            Game Balls and other virtual items are for use within the app only. They have no cash value, cannot be redeemed for money and are not transferable. Prices and the cost of optional actions are shown before confirmation. Confirmed virtual-currency actions spend the displayed amount. Cancelling an editing session after paying its disclosed entry fee does not refund that fee. Local progress and consumable balances may be lost if device data is removed; do not assume they are synced between devices.

            App Store purchases are processed by Apple and are subject to its payment and refund policies. Use Restore Purchases for eligible non-consumable entitlements; consumed items are not restored through that action. Nothing in these terms limits statutory consumer rights or Apple's refund process.

            OWNERSHIP AND FAIR USE
            The app and its original content are protected by intellectual-property laws. You retain rights you have in information you provide, and permit its use to operate and display the features you choose. Do not copy, redistribute or misuse app content except as permitted by law.

            AVAILABILITY AND RESPONSIBILITY
            The app is provided as available. We do not promise uninterrupted service or preservation of all progress. To the extent permitted by law, implied warranties and liability for indirect loss are excluded. These limits do not exclude rights or liabilities that cannot lawfully be excluded.

            CHANGES AND CONTACT
            Terms may be updated for changes to the app or legal requirements. Material changes will be communicated as required by law. Contact support@ndstriistudios.com for support or questions. Apple's Standard End User License Agreement also applies where applicable.
            """
        case .support:
            return """
            Need help with GameScene Gridiron?

            Email support@ndstriistudios.com for gameplay issues, account or privacy requests, purchase questions and feedback.

            Include your device model, iOS version, app version and build, and a short description of what happened. Screenshots and steps to reproduce a problem are helpful. Never send your password, verification codes or full payment details.

            For a missing non-consumable purchase, try Restore Purchases in Settings. App Store refund requests are handled by Apple.

            If email is not configured on your device, copy the address below and use your preferred email service.
            """
        }
    }
}

struct AboutDocumentView: View {
    let document: AboutDocument
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var copied = false
    @State private var emailUnavailable = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(document.text)
                        .font(.body)
                        .textSelection(.enabled)
                    if document == .support {
                        Text(AppInfo.displayLine).font(.caption)
                        Button("Email Support") {
                            guard let url = AppLinks.supportURL else { return }
                            openURL(url) { accepted in emailUnavailable = !accepted }
                        }
                        .buttonStyle(.borderedProminent)
                        Button(copied ? "Address Copied" : "Copy Email Address") {
                            UIPasteboard.general.string = "support@ndstriistudios.com"
                            copied = true
                        }
                        if emailUnavailable {
                            Text("No email app is available. Copy the address and contact us using your email service.")
                                .font(.caption)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(document.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}
