import Foundation

nonisolated enum LegalDocument: String, Identifiable {
    case privacy, terms
    var id: String { rawValue }
    var title: String { self == .privacy ? "Privacy Policy" : "Terms of Use" }
    var text: String { self == .privacy ? Self.privacyText : Self.termsText }

    static let privacyText = """
    Effective date: November 7, 2026

    1. About this policy
    This Privacy Policy explains how NDSTRII Studios ("we", "us", or "our") handles information in GameScene: Gridiron. Contact us at support@ndstriistudios.com with privacy questions or requests. This policy covers the app; other websites and services may have their own policies.

    2. Information we handle
    Local game data: The app stores settings, team information, solo progress, achievements, and virtual-item balances on your device. Device backups may also contain this data.

    Account information: If you create an account, we process your email address, authentication information, username, first and last name, account identifier, and profile information. Authentication is provided through Supabase. You can use guest mode for solo play, but online features require an account.

    Competitive activity: Online play sends match assignments, submitted results, and related gameplay information to our backend to verify results and maintain rankings and career records. Your username, football display name (which may include your first initial and last name), and competitive statistics may be visible to other players. Your email address and full first name are not intended for public leaderboard display.

    Purchases: Apple processes App Store payments. RevenueCat helps us validate purchases and manage entitlements. Purchase-related data can include product identifiers, transaction identifiers, purchase status, and an anonymous or account-linked user identifier. We do not receive your full payment-card details.

    Advertising and technical data: Google AdMob and its partners may process IP addresses, device and advertising identifiers, app interactions, ad impressions, diagnostics, and approximate location inferred from IP addresses to deliver and measure ads, prevent fraud, and operate their services. Collection and use depend on device permissions, consent choices, region, and provider configuration. Service providers may also process connection and security logs when you use online features.

    Support: If you email us, we receive your email address, message, and any attachments you choose to send. Do not send passwords or payment-card details.

    3. How information is used
    We use information to operate the game, save progress, authenticate accounts, verify competitive results, display rankings, fulfill purchases, deliver and measure advertising, respond to support requests, prevent abuse, and comply with legal obligations. Where applicable law requires a legal basis, we rely on performance of our agreement with you, legitimate interests such as security and service operation, legal obligations, or consent for activities that require it.

    4. Sharing and service providers
    We disclose information as needed to service providers including Supabase for authentication and backend hosting, RevenueCat for purchase management, Apple for platform and payment services, and Google AdMob and its advertising partners for advertising. Public competitive information is shared with other players as described above. We may also disclose information when required by law, to protect rights or safety, or in connection with a business transfer subject to applicable safeguards.

    We do not sell personal information for money. Advertising-related disclosures may qualify as a "sale", "sharing", or targeted advertising under some privacy laws. Use the privacy controls described below or contact us to exercise applicable rights.

    Provider information:
    Google: https://policies.google.com/privacy
    RevenueCat: https://www.revenuecat.com/privacy/
    Supabase: https://supabase.com/privacy
    Apple: https://www.apple.com/legal/privacy/

    5. Your choices and rights
    You may play solo as a guest. Where available, use Privacy Options in Settings to review advertising consent choices. You can also change tracking permission in your device's privacy settings. Declining tracking does not prevent core gameplay; ads may still appear. The Remove Forced Ads purchase removes forced ads as described in the Shop, but does not remove optional rewarded videos.

    Depending on your location, you may have rights to access, correct, delete, or obtain a copy of personal information, restrict or object to processing, withdraw consent, or opt out of certain advertising disclosures. Contact support@ndstriistudios.com to request assistance, including account or data deletion. We may need to verify your identity. Certain records may need to be retained for legal, security, or transaction purposes. You may also complain to your local data-protection authority. We will not discriminate against you for exercising applicable privacy rights.

    Deleting the app does not automatically delete an online account or server records. Local-only progress may be lost when app data is removed; device backups are managed through your platform settings.

    6. Retention, security, and international processing
    We retain information for as long as reasonably needed for the purposes above, including maintaining your account, resolving disputes, preventing fraud, and meeting legal obligations. Retention varies by data type, and backup copies may remain for a limited period after deletion. We use reasonable safeguards, but no storage or transmission method is completely secure. Our providers may process information outside your country, where privacy laws may differ; applicable transfer safeguards are used where legally required.

    7. Children
    GameScene: Gridiron is not directed to children under 13, or a higher minimum age where local law requires. We do not knowingly collect personal information from children below that age. If you believe a child has provided personal information, contact us so we can investigate and take appropriate action.

    8. Changes and contact
    We may update this policy as the app or legal requirements change. We will revise the effective date and provide additional notice or obtain consent when required. For questions or requests, email support@ndstriistudios.com.
    """

    static let termsText = """
    Effective date: November 7, 2026

    1. Agreement and eligibility
    These Terms of Use govern your use of GameScene: Gridiron, provided by NDSTRII Studios ("we", "us", or "our"). By using the app, you agree to these terms. If you do not agree, do not use the app. You must be at least 13 years old, or the higher minimum age required by local law. If you are under the age of legal adulthood, a parent or guardian must review and agree to these terms and supervise your use.

    2. License and ownership
    We grant you a limited, personal, nonexclusive, nontransferable license to use the app for lawful, noncommercial entertainment, subject to these terms and applicable App Store rules. The app, its artwork, game content, and branding belong to us or our licensors. You may not copy, distribute, sell, or exploit them without permission, except where law permits. The app uses fictional football content and is not endorsed by or affiliated with the NFL or any professional football team.

    3. Accounts and public identity
    Solo play is available in guest mode. Online features require an account. Provide accurate account information, protect your credentials, and contact us if you suspect unauthorized access. You are responsible for activity under your account to the extent permitted by law. Your username, football display name, and competitive statistics may be public. Do not use names that impersonate others, infringe rights, or contain abusive or unlawful material.

    4. Fair play and acceptable use
    Do not cheat, automate gameplay for unfair advantage, manipulate results, exploit vulnerabilities, interfere with the service, access accounts or data without authorization, or use the app unlawfully. Online results and rankings are subject to server verification. We may reject invalid results, correct errors, and restrict or suspend accounts for abuse or violations, with notice and an opportunity to contact us where appropriate. You may ask us to review an account restriction at support@ndstriistudios.com.

    5. Purchases and virtual items
    Optional purchases may include Game Balls, packs, and removal of forced ads. The Shop displays the applicable price and contents before purchase. Apple processes payments, and its purchase and refund rules apply alongside your statutory rights. Request refunds through Apple where applicable; contact us for delivery problems.

    Virtual currency and items are licensed for use within the game, have no cash value, and cannot be redeemed for money, transferred, or resold. Consumable items may not be restorable after use or loss of local data. Eligible nonconsumable entitlements can be checked using Restore Purchases with the relevant Apple account. Local-only progress and balances are not guaranteed to transfer between devices. Nothing in these terms limits mandatory consumer remedies.

    Remove Forced Ads applies to forced advertising as described in the Shop; optional rewarded ads may remain available. Rewarded-ad benefits are granted only when the app receives confirmation that the reward was earned. Ad availability is not guaranteed.

    6. Availability, updates, and saved data
    We may update gameplay, content, balancing, or online features. Online services depend on network access and third-party systems and may be interrupted or discontinued. We will provide notice and remedies where required by law. Keep device backups where available. Deleting app data can remove local progress; signing out or deleting the app does not automatically delete an online account. Contact support@ndstriistudios.com for account-deletion assistance.

    7. Privacy and third-party services
    Our Privacy Policy explains our handling of personal information. The app uses third-party services for authentication, hosting, advertising, and purchases. Their applicable terms and privacy policies also govern your direct use of those services. We do not control third-party advertisements or linked sites.

    8. Disclaimers and liability
    To the extent permitted by law, the app is provided "as is" and "as available", without warranties of uninterrupted or error-free operation or fitness for a particular purpose. To the extent permitted by law, we are not liable for indirect or consequential losses arising from use of the app. These limitations do not exclude liability that cannot lawfully be excluded, including applicable consumer guarantees, fraud, or liability for intentional misconduct. Your mandatory legal rights remain unaffected.

    9. Ending use
    You may stop using the app at any time. We may restrict or terminate access for material violations of these terms or where required by law. Ending access does not automatically create a refund right beyond applicable law and platform policies. Sections that by their nature should continue, including ownership and applicable liability provisions, survive termination.

    10. Apple platform terms
    These terms are between you and NDSTRII Studios, not Apple. Apple is not responsible for the app's content, maintenance, or support. Where applicable, Apple may refund the purchase price if the app fails to conform to an applicable warranty, and Apple has no other warranty obligation to the maximum extent permitted by law. We, not Apple, are responsible for addressing app-related claims as required by law. Apple and its subsidiaries are third-party beneficiaries of these terms and may enforce them against you. Your use must comply with applicable Apple usage rules and export and sanctions laws.

    11. Changes, disputes, and contact
    We may revise these terms and will update the effective date. Material changes will be communicated where required by law; if you do not accept revised terms, stop using the app. Nothing here removes protections or courts available to you under mandatory local law. If a provision is unenforceable, the remaining provisions remain effective to the extent permitted by law.

    For support, legal questions, or concerns, contact support@ndstriistudios.com.
    """
}
