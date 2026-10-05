import StoreKit
import Observation

/// StoreKit 2 manager for the one-time Ad-Free purchase. StoreKit stays the
/// sole authority for the entitlement: `hasAdFree` is always re-derived from
/// verified `Transaction.currentEntitlements`, never from a local flag.
///
/// Ad-Free removes banner ads and forced interstitials permanently. Optional
/// rewarded videos stay available to owners — they are user-initiated rewards,
/// not ads the app forces on anyone.
@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    static let adFreeProductID = "gamescene.gridiron.adfree"

    private(set) var hasAdFree = false
    private(set) var adFreeProduct: Product?
    private(set) var isWorking = false
    private(set) var statusMessage: String?

    /// Localized App Store price, when the product is reachable. Never
    /// hard-code a price in the UI — always display this.
    var adFreePrice: String? { adFreeProduct?.displayPrice }

    /// False in builds without a connected store (development/simulator).
    var isAdFreeAvailable: Bool { adFreeProduct != nil }

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        await refreshEntitlement()
        adFreeProduct = try? await Product.products(for: [Self.adFreeProductID]).first
    }

    private func refreshEntitlement() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if transaction.productID == Self.adFreeProductID, transaction.revocationDate == nil {
                owned = true
            }
        }
        hasAdFree = owned
    }

    /// Attempts the Ad-Free purchase. Returns true when the entitlement is
    /// owned afterwards.
    @discardableResult
    func purchaseAdFree() async -> Bool {
        guard let product = adFreeProduct else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlement()
                return hasAdFree
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            statusMessage = "The purchase could not be completed. Try again."
            return false
        }
    }

    /// RESTORE PURCHASES — re-derives the entitlement from the App Store.
    func restorePurchases() async {
        isWorking = true
        defer { isWorking = false }
        try? await AppStore.sync()
        await refreshEntitlement()
        statusMessage = hasAdFree ? "AD-FREE RESTORED" : "NO PURCHASES TO RESTORE"
    }
}
