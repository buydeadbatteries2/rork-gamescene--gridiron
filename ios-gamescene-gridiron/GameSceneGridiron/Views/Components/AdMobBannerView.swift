import SwiftUI
import GoogleMobileAds

/// The real Google Mobile Ads banner: an anchored adaptive banner sized to
/// the available width — never an arbitrary oversized fixed frame. Only
/// created when the build supports ads and consent allows ad requests; its
/// load callbacks (and only those) flip the AdManager banner state.
struct AdMobBannerView: UIViewRepresentable {
    /// Available width for the adaptive banner (screen minus slot padding).
    let availableWidth: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: Self.adaptiveSize(for: availableWidth))
        banner.adUnitID = AdMobService.shared.bannerUnitID
        banner.rootViewController = Self.topViewController()
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    static func adaptiveSize(for width: CGFloat) -> AdSize {
        currentOrientationAnchoredAdaptiveBanner(width: max(0, width))
    }

    /// Google-free dimensions for SwiftUI layout (rows size themselves from
    /// the same width the banner requests).
    static func adaptiveDimensions(for width: CGFloat) -> CGSize {
        adaptiveSize(for: width).size
    }

    @MainActor
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var root = scene?.keyWindow?.rootViewController
        while let presented = root?.presentedViewController { root = presented }
        return root
    }

    func makeCoordinator() -> BannerCoordinator {
        BannerCoordinator()
    }

    /// Bridges the AdMob banner callbacks into the facade. The delegate fires
    /// on its own thread; UI state hops to the main actor.
    final class BannerCoordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            Task { @MainActor in
                AdManager.shared.noteBannerLoadResult(true)
            }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            Task { @MainActor in
                AdManager.shared.noteBannerLoadResult(false)
            }
        }
    }
}
