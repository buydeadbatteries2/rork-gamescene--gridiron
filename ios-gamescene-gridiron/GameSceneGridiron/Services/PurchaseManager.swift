import Foundation
import Observation
import RevenueCat

// MARK: - Purchase manager (RevenueCat)

/// The single purchase service. Configures the RevenueCat Purchases SDK
/// exactly once at app start, resolves the `default` offering's packages by
/// identifier (never array position), exposes localized store prices, and
/// owns every purchase/restore flow.
///
/// Entitlement model:
/// - `remove_ads_ent` — persistent non-consumable Remove Forced Ads.
/// - `starter_pack_ent` — persistent non-consumable Starter Pack.
/// - Game Ball products are consumables and deliberately have NO
///   entitlement — ownership is proven per-purchase through the store
///   transaction id and the wallet's ledger, never through entitlements.
///
/// The secret (`REVENUECAT_SECRET_API_KEY`) is server-only and must never be
/// referenced by any client code; only the public SDK keys are used here.
@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    // MARK: Product & entitlement identifiers

    /// Production store product IDs (Phase 11.7).
    static let starterPackProductID = "starter_pack"
    static let removeAdsProductID = "remove_ads"
    static let gameBallProductIDs = ["25_game_balls", "150_game_balls", "350_game_balls"]

    /// Game Balls granted per consumable product.
    static let gameBallAmounts: [String: Int] = [
        "25_game_balls": 25,
        "150_game_balls": 150,
        "350_game_balls": 350,
    ]

    static let removeAdsEntitlementID = "remove_ads_ent"
    static let starterPackEntitlementID = "starter_pack_ent"
    static let defaultOfferingID = "default"

    /// RevenueCat package identifiers are store-specific: the Test Store uses
    /// a `_test` suffix, the App Store offering uses `_app`.
    nonisolated static func packageID(forProductID productID: String, isDevelopmentBuild: Bool) -> String {
        productID + (isDevelopmentBuild ? "_test" : "_app")
    }

    nonisolated static var isDevelopmentBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// The public SDK key for this build configuration. DEBUG/development
    /// builds use the RevenueCat Test Store key; RELEASE builds use the
    /// production iOS key. A Release build NEVER falls back to the Test
    /// Store key: a missing key means RevenueCat stays unavailable and the
    /// purchasing UI shows a graceful unavailable state.
    nonisolated static func apiKeyForCurrentBuild(testKey: String, productionKey: String) -> String? {
        #if DEBUG
        let key = testKey
        #else
        let key = productionKey
        #endif
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: Purchase flow state

    enum PurchaseFlowState: Equatable, Sendable {
        case idle
        case purchasing
        /// RevenueCat verified the transaction. `transactionID` is the store
        /// transaction identity used for grant idempotency.
        case success(transactionID: String?)
        /// The user backed out of the store sheet — never an error.
        case cancelled
        /// Awaiting approval (e.g. parental consent) — not a failure.
        case pending
        case failed(String)
        /// No configured RevenueCat SDK, offering or package.
        case unavailable
    }

    // MARK: Observable state

    private(set) var isConfigured = false
    private(set) var hasRemoveAds = false
    private(set) var hasStarterPack = false
    private(set) var currentOffering: Offering?
    private(set) var isLoadingOfferings = false
    private(set) var isPurchasing = false
    private(set) var isWorking = false
    private(set) var statusMessage: String?

    // MARK: Compatibility surface (legacy call sites)

    /// Legacy alias — Remove Forced Ads ownership.
    var hasAdFree: Bool { hasRemoveAds }
    /// Legacy alias for the old Ad-Free price label.
    var adFreePrice: String? { localizedPrice(forProductID: Self.removeAdsProductID) }
    /// False when RevenueCat is not configured (no key / no offering).
    var isAdFreeAvailable: Bool { isConfigured && currentOffering != nil }

    private var updatesTask: Task<Void, Never>?
    private let wallet: PlayerWallet

    init(wallet: PlayerWallet = .shared) {
        self.wallet = wallet
    }

    // MARK: Configuration (call exactly once, from the App's init)

    /// Configures the RevenueCat SDK once. Anonymous App User ID behavior —
    /// a future authenticated login can `logIn` without rewriting this UI.
    func configure(testKey: String = Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY, productionKey: String = Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY) {
        guard !isConfigured else { return }
        // Unit/UI test hosts relaunch the app dozens of times per run; a live
        // SDK session per relaunch destabilizes the simulator harness. Tests
        // exercise the purchase flows through the wallet ledger instead.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        guard let apiKey = Self.apiKeyForCurrentBuild(testKey: testKey, productionKey: productionKey) else {
            statusMessage = "STORE NOT CONNECTED IN THIS BUILD"
            return
        }
        #if DEBUG
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: apiKey)
        isConfigured = true

        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await info in Purchases.shared.customerInfoStream {
                await self.apply(info)
            }
        }
        Task { [weak self] in await self?.loadOfferings() }
    }

    // MARK: Offerings & packages

    /// Fetches the current (`default`) offering. Packages are resolved by
    /// identifier — never by array position.
    func loadOfferings() async {
        guard isConfigured else { return }
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current ?? offerings.offering(identifier: Self.defaultOfferingID)
        } catch {
            // Sanitized: no SDK internals, no keys.
            statusMessage = "The store could not be reached. Try again shortly."
        }
    }

    /// Resolves the package for a production product ID: by offering package
    /// identifier first (`<productID>_app` / `<productID>_test`), then by the
    /// underlying store product identifier. Returns nil when missing —
    /// callers show an unavailable state, never a crash.
    func package(forProductID productID: String) -> Package? {
        guard let offering = currentOffering else { return nil }
        let expectedPackageID = Self.packageID(
            forProductID: productID,
            isDevelopmentBuild: Self.isDevelopmentBuild
        )
        return offering.availablePackages.first { $0.identifier == expectedPackageID }
            ?? offering.availablePackages.first { $0.storeProduct.productIdentifier == productID }
    }

    /// Localized store price — never a hard-coded number.
    func localizedPrice(forProductID productID: String) -> String? {
        package(forProductID: productID)?.storeProduct.localizedPriceString
    }

    // MARK: Purchases

    /// Purchases a Game Ball consumable. Grants currency only after
    /// RevenueCat verifies the transaction, exactly once per store
    /// transaction id.
    func purchaseGameBalls(productID: String) async -> PurchaseFlowState {
        guard let amount = Self.gameBallAmounts[productID] else {
            return .failed("Unknown Game Ball pack.")
        }
        guard let package = package(forProductID: productID) else { return .unavailable }
        let outcome = await purchase(package)
        switch outcome {
        case .success(let transactionID):
            guard let transactionID else {
                // No store transaction identity — never grant on guesswork.
                return .failed("The purchase could not be verified. You were not charged for currency.")
            }
            if wallet.grantStoreGameBalls(amount, transactionID: transactionID) {
                statusMessage = "+\(amount) GAME BALLS"
            }
            return .success(transactionID: transactionID)
        default:
            return outcome
        }
    }

    /// Purchases the one-time Starter Pack. Contents (+2 hints, +10 Game
    /// Balls) are granted through the wallet's permanent flag — restores and
    /// edge-case repurchases can never duplicate them.
    func purchaseStarterPack() async -> PurchaseFlowState {
        guard let package = package(forProductID: Self.starterPackProductID) else { return .unavailable }
        let outcome = await purchase(package)
        if case .success = outcome {
            await applyCurrentCustomerInfo()
            if wallet.grantStarterPackContents() {
                statusMessage = "STARTER PACK UNLOCKED"
            }
        }
        return outcome
    }

    /// Purchases Remove Forced Ads.
    func purchaseRemoveAds() async -> PurchaseFlowState {
        guard let package = package(forProductID: Self.removeAdsProductID) else { return .unavailable }
        let outcome = await purchase(package)
        if case .success = outcome {
            await applyCurrentCustomerInfo()
            statusMessage = "FORCED ADS REMOVED"
        }
        return outcome
    }

    /// Legacy single-product purchase path (Settings/Shop compatibility).
    @discardableResult
    func purchaseAdFree() async -> Bool {
        guard case .success = await purchaseRemoveAds() else { return false }
        return true
    }

    /// The raw purchase. Cancellation resolves `.cancelled` (never an error),
    /// pending payment resolves `.pending`, and only a verified transaction
    /// resolves `.success`.
    private func purchase(_ package: Package) async -> PurchaseFlowState {
        guard isConfigured else { return .unavailable }
        guard !isPurchasing else { return .failed("A purchase is already in progress.") }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            return .success(transactionID: result.transaction?.transactionIdentifier)
        } catch ErrorCode.purchaseCancelledError {
            return .cancelled
        } catch ErrorCode.paymentPendingError {
            return .pending
        } catch {
            statusMessage = "The purchase could not be completed. Try again."
            return .failed("purchase_failed")
        }
    }

    // MARK: Restore

    /// Restores durable non-consumable ownership (Remove Forced Ads,
    /// Starter Pack). Never fabricates consumable Game Ball purchases, and
    /// the Starter Pack contents cannot be granted twice.
    @discardableResult
    func restorePurchases() async -> Bool {
        guard isConfigured else {
            statusMessage = "STORE NOT CONNECTED IN THIS BUILD"
            return false
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            await apply(info)
            if hasRemoveAds || hasStarterPack {
                statusMessage = "PURCHASES RESTORED"
            } else {
                statusMessage = "NO PURCHASES TO RESTORE"
            }
            return hasRemoveAds || hasStarterPack
        } catch {
            statusMessage = "RESTORE FAILED — TRY AGAIN"
            return false
        }
    }

    // MARK: Entitlement application

    private func applyCurrentCustomerInfo() async {
        guard let info = try? await Purchases.shared.customerInfo() else { return }
        await apply(info)
    }

    private func apply(_ info: CustomerInfo) async {
        hasRemoveAds = info.entitlements[Self.removeAdsEntitlementID]?.isActive == true
        hasStarterPack = info.entitlements[Self.starterPackEntitlementID]?.isActive == true
        // Starter Pack ownership always (re-)checks against the permanent
        // grant flag — a restore can never duplicate the contents.
        if hasStarterPack, wallet.grantStarterPackContents() {
            statusMessage = "STARTER PACK RESTORED"
        }
    }
}
