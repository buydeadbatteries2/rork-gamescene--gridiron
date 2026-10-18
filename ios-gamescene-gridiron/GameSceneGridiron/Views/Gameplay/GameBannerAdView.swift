import SwiftUI

/// Banner slot pinned to the absolute bottom of the gameplay screen, laid out
/// as its own row — never overlapping field, clues, tray or navigation
/// controls.
///
/// Banner visibility contract:
/// - Remove Forced Ads owners: the banner is never requested and never shown;
///   the space is reclaimed automatically the moment ownership is verified.
/// - An active ad session (valid app ID + consent) mounts the REAL
///   `AdMobBannerView` immediately — the view performs the load — and keeps
///   it mounted through the loading→loaded transition so the in-flight
///   request is never cancelled by a view identity change.
/// - A failed load collapses the slot (release) or shows the small DEBUG
///   diagnostic; a bounded retry cycle (3 attempts, 5s apart) re-arms it.
/// - Builds with no AdMob session may show the clearly labeled development
///   placeholder (DEBUG only, layout testing).
struct GameBannerAdView: View {
    @State private var adManager = AdManager.shared
    @State private var purchases = PurchaseManager.shared
    @State private var adMob = AdMobService.shared
    @State private var reloadToken = 0
    @State private var retryTask: Task<Void, Never>?

    /// Max automatic reloads after failures — never a tight loop.
    private let maxReloadAttempts = 3

    private var availableWidth: CGFloat {
        max(0, UIScreen.main.bounds.width - 32)
    }

    var body: some View {
        content
            .onAppear { adManager.requestBannerAd() }
            .onDisappear { retryTask?.cancel() }
            .onChange(of: adManager.didBannerLoadFail) { _, failed in
                if failed { scheduleReload() }
            }
    }

    /// One stable branch for the real banner: mounted while loading AND while
    /// loaded, so SwiftUI never tears the `BannerView` down mid-request.
    @ViewBuilder
    private var content: some View {
        if adManager.showsBannerAds, adMob.canServeAds, !adManager.didBannerLoadFail {
            realBanner
        } else if adManager.showsBannerAds, adMob.canServeAds {
            unavailableDiagnostic
        } else if adManager.bannerVisibility == .developmentPlaceholder {
            AdBannerPlaceholder()
        }
    }

    private var realBanner: some View {
        let dimensions = AdMobBannerView.adaptiveDimensions(for: availableWidth)
        return AdMobBannerView(availableWidth: availableWidth)
            .id(reloadToken)
            .frame(width: dimensions.width, height: dimensions.height)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityHidden(true)
    }

    /// Post-failure state: a small DEBUG diagnostic (TEST BANNER UNAVAILABLE)
    /// while the retry cycle is pending; release collapses to nothing.
    @ViewBuilder
    private var unavailableDiagnostic: some View {
        #if DEBUG
        Text("TEST BANNER UNAVAILABLE")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(Theme.paperInk.opacity(0.45))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .accessibilityHidden(true)
        #endif
    }

    private func scheduleReload() {
        guard reloadToken < maxReloadAttempts else { return }
        retryTask?.cancel()
        retryTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            reloadToken += 1
            adManager.retryBannerAfterFailure()
        }
    }
}
