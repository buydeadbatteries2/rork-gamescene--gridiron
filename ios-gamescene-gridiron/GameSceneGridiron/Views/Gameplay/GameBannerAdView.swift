import SwiftUI

/// Banner slot pinned to the absolute bottom of the gameplay screen. Fixed
/// height, laid out as its own row — never overlapping field, clues, tray or
/// navigation controls. Ad-Free owners get no banner at all and the layout
/// expands naturally into the freed space.
///
/// The Google Mobile Ads banner view slots in behind `AdManager`; until live
/// AdMob configuration exists, development builds render the reserved
/// placeholder in the same fixed slot.
struct GameBannerAdView: View {
    static let height: CGFloat = 50

    var body: some View {
        if AdManager.shared.showsBannerAds {
            bannerContent
        }
    }

    @ViewBuilder
    private var bannerContent: some View {
        // Ad SDK integration point: the live AdMob banner view replaces this
        // placeholder while keeping the same fixed 50pt slot.
        AdBannerPlaceholder()
    }
}
