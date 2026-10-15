import SwiftUI

/// The SHOP: manila case-file supplies. Game Balls are earned through play
/// and topped up through verified store consumables; the SPECIAL section
/// carries the one-time Starter Pack and Remove Forced Ads. Every store
/// price comes from RevenueCat/StoreKit metadata — never a hard-coded
/// number. Entitlement identifiers never surface in the UI.
struct ShopView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isConfirmingHint = false
    @State private var isRestoring = false
    @State private var toast: String?
    /// Blocks a rapid double-tap from buying two hints in one gesture.
    @State private var hintThrottle = TapThrottle()
    /// Blocks a rapid double-tap from starting two store purchases.
    @State private var purchaseThrottle = TapThrottle()

    private var wallet: PlayerWallet { PlayerWallet.shared }
    private var store: PurchaseManager { PurchaseManager.shared }
    private var config: EconomyConfig { .standard }

    /// The product whose purchase is currently in flight (progress state).
    @State private var purchasingProductID: String?

    var body: some View {
        ZStack {
            DeskBackground()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 18) {
                        balanceCard

                        hintsSection

                        gameBallsSection

                        specialSection

                        restoreButton
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }

            if let toast {
                toastView(toast)
            }

            if isConfirmingHint {
                HintPurchaseConfirmation(
                    hintCost: config.hintCost,
                    balance: wallet.gameBalls,
                    onConfirm: {
                        isConfirmingHint = false
                        buyHint()
                    },
                    onCancel: {
                        Haptics.tick()
                        isConfirmingHint = false
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.22), value: isConfirmingHint)
        .task { await store.loadOfferings() }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button {
                Haptics.tick()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.45), in: .circle)
            }
            .accessibilityLabel("Close shop")

            Spacer()

            Text("SHOP")
                .font(.system(size: 24, weight: .black).width(.compressed))
                .tracking(3)
                .foregroundStyle(Theme.goldGradient)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: Balance

    private var balanceCard: some View {
        HStack(spacing: 14) {
            WalletPill(amount: wallet.gameBalls)
            Spacer(minLength: 8)
            HintPill(count: wallet.hints)
        }
        .padding(12)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(-0.5))
        .overlay(alignment: .top) { PushPin(size: 16).offset(y: -8) }
        .padding(.top, 8)
    }

    // MARK: Hints (Game Ball economy)

    private var hintsSection: some View {
        VStack(spacing: 12) {
            sectionHeader("HINTS", symbol: "lightbulb.fill")

            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.goldGradient)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.35), in: .rect(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text("1 HINT")
                        .font(.system(size: 17, weight: .heavy).width(.condensed))
                        .foregroundStyle(Theme.paperInk)
                    Text("A simplified lead on the case, whenever you need it.")
                        .font(Theme.typewriter(10, relativeTo: .caption2))
                        .foregroundStyle(Theme.paperInkSoft)
                }

                Spacer(minLength: 8)

                Button {
                    Haptics.tick()
                    withAnimation(.easeOut(duration: 0.2)) { isConfirmingHint = true }
                } label: {
                    HStack(spacing: 6) {
                        Text("\(config.hintCost)")
                            .font(.system(size: 16, weight: .black).width(.condensed))
                            .monospacedDigit()
                        GameBallIcon(size: 12)
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .frame(height: 40)
                .disabled(!wallet.canAffordHint)
                .opacity(wallet.canAffordHint ? 1 : 0.45)
                .scaleEffect(wallet.canAffordHint ? 1 : 0.92)
                .accessibilityLabel("Buy one hint for \(config.hintCost) Game Balls")
                .accessibilityHint(wallet.canAffordHint ? "Adds one hint to your inventory" : "Not enough Game Balls")
            }
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(0.4))
    }

    // MARK: Game Balls (store consumables)

    private var gameBallsSection: some View {
        VStack(spacing: 12) {
            sectionHeader("GAME BALLS", symbol: "football.fill")

            ForEach(PurchaseManager.gameBallProductIDs, id: \.self) { productID in
                storeRow(
                    title: "\(PurchaseManager.gameBallAmounts[productID] ?? 0) GAME BALLS",
                    detail: "A top-up of earned assistance currency.",
                    price: store.localizedPrice(forProductID: productID),
                    priceFallback: "GAME BALL PACK",
                    isOwned: false,
                    isWorking: store.isPurchasing && purchasingProductID == productID
                ) {
                    purchase(productID) { await store.purchaseGameBalls(productID: productID) }
                }
            }
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(-0.3))
    }

    // MARK: Special (non-consumables)

    private var specialSection: some View {
        VStack(spacing: 12) {
            sectionHeader("SPECIAL", symbol: "seal.fill")

            storeRow(
                title: "STARTER PACK",
                detail: "\(config.starterPackHints) Hints plus \(config.starterPackGameBalls) Game Balls — a one-time kit.",
                price: store.localizedPrice(forProductID: PurchaseManager.starterPackProductID),
                priceFallback: "ONE-TIME KIT",
                isOwned: store.hasStarterPack,
                ownedLabel: "OWNED",
                isWorking: store.isPurchasing && purchasingProductID == PurchaseManager.starterPackProductID
            ) {
                purchase(PurchaseManager.starterPackProductID) { await store.purchaseStarterPack() }
            }

            storeRow(
                title: "REMOVE FORCED ADS",
                detail: "Permanently removes forced full-screen ads. Optional rewarded videos remain available.",
                price: store.localizedPrice(forProductID: PurchaseManager.removeAdsProductID),
                priceFallback: "ONE-TIME PURCHASE",
                isOwned: store.hasRemoveAds,
                ownedLabel: "OWNED",
                isWorking: store.isPurchasing && purchasingProductID == PurchaseManager.removeAdsProductID
            ) {
                purchase(PurchaseManager.removeAdsProductID) { await store.purchaseRemoveAds() }
            }
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(0.3))
    }

    // MARK: Restore

    private var restoreButton: some View {
        Button {
            restorePurchases()
        } label: {
            Text("RESTORE PURCHASES")
                .font(.system(size: 12, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, minHeight: 40)
                .overlay {
                    Capsule().strokeBorder(Theme.paperInkSoft.opacity(0.4), lineWidth: 1)
                }
                .contentShape(.capsule)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isRestoring || !store.isAdFreeAvailable)
        .padding(.bottom, 8)
    }

    // MARK: Store rows

    private func storeRow(
        title: String,
        detail: String,
        price: String?,
        priceFallback: String,
        isOwned: Bool,
        ownedLabel: String = "OWNED",
        isWorking: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy).width(.condensed))
                    .foregroundStyle(Theme.paperInk)
                Text(detail)
                    .font(Theme.typewriter(10, relativeTo: .caption2))
                    .foregroundStyle(Theme.paperInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if isOwned {
                Label(ownedLabel, systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .heavy).width(.condensed))
                    .tracking(1)
                    .foregroundStyle(Theme.success)
                    .accessibilityAddTraits(.isSelected)
            } else if let price {
                Button(action: action) {
                    HStack(spacing: 6) {
                        if isWorking {
                            ProgressView()
                                .tint(Theme.goldLight)
                        } else {
                            Text(price)
                                .font(.system(size: 15, weight: .black).width(.condensed))
                        }
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .frame(minWidth: 74, minHeight: 40)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .frame(height: 40)
                .disabled(isWorking)
                .accessibilityLabel("Buy \(title) for \(price)")
            } else {
                Text(store.isConfigured ? "UNAVAILABLE" : priceFallback)
                    .font(.system(size: 11, weight: .heavy).width(.condensed))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInkSoft)
                    .frame(minWidth: 74, minHeight: 40)
                    .overlay {
                        Capsule().strokeBorder(Theme.paperInkSoft.opacity(0.35), lineWidth: 1.2)
                    }
                    .accessibilityLabel("\(title) unavailable in this build")
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Actions

    private func buyHint() {
        guard hintThrottle.accept() else { return }
        guard wallet.buyHint() else {
            Haptics.warning()
            showToast("NOT ENOUGH GAME BALLS")
            return
        }
        Haptics.success()
        AudioManager.shared.play(.hintPurchaseConfirm)
        showToast("+1 HINT")
    }

    /// Runs one store purchase with double-tap protection and full state
    /// handling. Success toasts only after RevenueCat verifies the
    /// transaction; cancellation resolves quietly.
    private func purchase(_ productID: String, _ flow: @escaping () async -> PurchaseManager.PurchaseFlowState) {
        guard purchaseThrottle.accept() else { return }
        Haptics.pickUp()
        purchasingProductID = productID
        Task { @MainActor in
            let outcome = await flow()
            switch outcome {
            case .success:
                Haptics.success()
                AudioManager.shared.play(.hintPurchaseConfirm)
                if let message = store.statusMessage { showToast(message) }
            case .cancelled:
                break // quiet — the user backed out
            case .pending:
                showToast("PURCHASE PENDING APPROVAL")
            case .failed:
                Haptics.warning()
                showToast(store.statusMessage ?? "PURCHASE FAILED — TRY AGAIN")
            case .unavailable:
                Haptics.warning()
                showToast("STORE NOT CONNECTED IN THIS BUILD")
            case .idle, .purchasing:
                break
            }
            purchasingProductID = nil
        }
    }

    private func restorePurchases() {
        Haptics.tick()
        Task { @MainActor in
            isRestoring = true
            let restored = await store.restorePurchases()
            isRestoring = false
            if let message = store.statusMessage { showToast(message) }
            if restored {
                Haptics.success()
                AudioManager.shared.play(.hintPurchaseConfirm)
            }
        }
    }

    // MARK: Chrome

    private func sectionHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.gold)
            Text(title)
                .font(.system(size: 13, weight: .heavy).width(.condensed))
                .tracking(3)
                .foregroundStyle(Theme.paperInkSoft)
            Rectangle()
                .fill(Theme.paperInkSoft.opacity(0.35))
                .frame(height: 1)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private func toastView(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 13, weight: .heavy).width(.condensed))
                .tracking(1.5)
                .foregroundStyle(Theme.paperInk)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .paperCard(cornerRadius: 4)
                .padding(.bottom, 28)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task(id: message) {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut) { toast = nil }
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toast = message }
    }
}

#Preview {
    ShopView()
}
