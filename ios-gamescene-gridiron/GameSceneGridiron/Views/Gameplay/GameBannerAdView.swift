import SwiftUI

/// Banner slot pinned to the absolute bottom of the gameplay screen, laid out
/// as its own row — never overlapping field, clues, tray or navigation
/// controls.
///
/// Banner visibility contract (release-safe):
/// - Remove Forced Ads owners: the banner is never requested and never shown;
///   the space is reclaimed automatically the moment ownership is verified.
/// - No loaded ad / no consent / ads unsupported: the slot collapses entirely
///   — a release build never shows a fake, reserved or "sponsored" strip.
/// - A real AdMob banner that successfully loads displays here through
///   `AdMobBannerView` (adaptive width, loaded via `AdManager`).
/// - Debug builds may show the clearly labeled development placeholder while
///   no real ad is loaded (builds without a valid AdMob app ID), for layout
///   testing only.
struct GameBannerAdView: View {
    @State private var adManager = AdManager.shared
    @State private var purchases = PurchaseManager.shared
    @State private var adMob = AdMobService.shared

    var body: some View {
        Group {
            switch adManager.bannerVisibility {
            case .hidden:
                // Collapses the row — the layout expands into the freed space.
                EmptyView()
            case .loadedBanner:
                let dimensions = AdMobBannerView.adaptiveDimensions(for: UIScreen.main.bounds.width - 32)
                AdMobBannerView(availableWidth: UIScreen.main.bounds.width - 32)
                    .frame(width: dimensions.width, height: dimensions.height)
            case .developmentPlaceholder:
                AdBannerPlaceholder()
            }
        }
        .onAppear { adManager.requestBannerAd() }
    }
}
