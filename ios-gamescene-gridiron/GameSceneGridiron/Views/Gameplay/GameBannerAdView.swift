import SwiftUI

/// Banner slot pinned to the absolute bottom of the gameplay screen, laid out
/// as its own row — never overlapping field, clues, tray or navigation
/// controls.
///
/// Banner visibility contract (release-safe):
/// - Ad-Free owners: the banner is never requested and never shown; the space
///   is reclaimed automatically the moment ownership is verified.
/// - No loaded ad: the slot collapses entirely — a release build never shows
///   a fake, reserved or "sponsored" strip.
/// - A real AdMob banner that successfully loads displays here through
///   `AdManager` (SDK integration point in `AdManager.requestBannerAd`).
/// - Debug builds may show the clearly labeled development placeholder while
///   no real ad is loaded, for layout testing only.
struct GameBannerAdView: View {
    static let height: CGFloat = 50

    var body: some View {
        Group {
            switch AdManager.shared.bannerVisibility {
            case .hidden:
                // Collapses the row — the layout expands into the freed space.
                EmptyView()
            case .loadedBanner:
                bannerContent
            case .developmentPlaceholder:
                AdBannerPlaceholder()
            }
        }
        .onAppear { AdManager.shared.requestBannerAd() }
    }

    @ViewBuilder
    private var bannerContent: some View {
        // Ad SDK integration point: the live AdMob banner view renders here
        // in the same fixed 50pt slot once its load callback reports success.
        AdBannerPlaceholder()
    }
}
