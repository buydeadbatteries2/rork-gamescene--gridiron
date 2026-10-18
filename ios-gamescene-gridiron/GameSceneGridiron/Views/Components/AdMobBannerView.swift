import SwiftUI
import GoogleMobileAds

/// The real Google Mobile Ads banner: an anchored adaptive banner sized to
/// the available width — never an arbitrary oversized fixed frame. Created as
/// soon as the session can serve ads (the view itself performs the load);
/// its load callbacks (and only those) flip the AdManager banner state.
struct AdMobBannerView: UIViewRepresentable {
    /// Available width for the adaptive banner (screen minus slot padding).
    let availableWidth: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: Self.adaptiveSize(for: availableWidth))
        let unitID = AdMobService.shared.bannerUnitID
        banner.adUnitID = unitID
        banner.rootViewController = Self.topViewController()
        banner.delegate = context.coordinator
        #if DEBUG
        let dimensions = Self.adaptiveDimensions(for: availableWidth)
        print("[AdMobBanner] request started — config: \(AdMobConfig.debugUnitLabel(for: unitID)) banner, adaptive \(Int(dimensions.width))×\(Int(dimensions.height))pt, rootViewController: \(banner.rootViewController != nil ? "yes" : "NO")")
        #endif
        // A nil unit ID (unsupported build) must never reach the SDK — the
        // policy never mounts this view in that case anyway.
        if unitID != nil {
            banner.load(Request())
        }
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

    /// The active foreground scene's top-most view controller, with a fallback
    /// to any key window — the banner needs a valid presenter for click-through.
    @MainActor
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var root = scene?.keyWindow?.rootViewController
            ?? scenes.compactMap(\.keyWindow?.rootViewController).first
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
            #if DEBUG
            print("[AdMobBanner] banner loaded ✓")
            #endif
            Task { @MainActor in
                AdManager.shared.noteBannerLoadResult(true)
            }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("[AdMobBanner] banner failed: \(error.localizedDescription)")
            #endif
            Task { @MainActor in
                AdManager.shared.noteBannerLoadResult(false)
            }
        }
    }
}
