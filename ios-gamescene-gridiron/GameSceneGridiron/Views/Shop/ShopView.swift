import SwiftUI

/// The SHOP: manila case-file supplies. Game Balls are earned through play —
/// no real-money Game Ball packs. Hints are bought with earned Game Balls
/// (small confirmation before spending), and Ad-Free is the one-time StoreKit
/// purchase at its localized App Store price, never a hard-coded number.
struct ShopView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isConfirmingHint = false
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var toast: String?

    private var wallet: PlayerWallet { PlayerWallet.shared }
    private var config: EconomyConfig { .standard }

    var body: some View {
        ZStack {
            DeskBackground()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 18) {
                        balanceCard

                        hintsSection

                        adFreeSection

                        Text("GAME BALLS ARE EARNED THROUGH PLAY.")
                            .font(Theme.typewriter(10, relativeTo: .caption2))
                            .tracking(2)
                            .foregroundStyle(Theme.paperInkSoft.opacity(0.8))
                            .padding(.top, 4)
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

    // MARK: Hints

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
                    Text("A fresh lead on the case, whenever you need it.")
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

    // MARK: Ad-Free

    private var adFreeSection: some View {
        VStack(spacing: 12) {
            sectionHeader("AD-FREE", symbol: "eye.slash.fill")

            Text("Removes banner and automatic ads permanently. Optional reward videos remain available when you choose to use them.")
                .font(Theme.typewriter(12, relativeTo: .footnote))
                .foregroundStyle(Theme.paperInk)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            adFreeButton

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
            .disabled(isRestoring)
        }
        .padding(14)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(-0.3))
    }

    @ViewBuilder
    private var adFreeButton: some View {
        if PurchaseManager.shared.hasAdFree {
            Label("AD-FREE OWNED — THANK YOU", systemImage: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .heavy).width(.condensed))
                .tracking(1.5)
                .foregroundStyle(Theme.success)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay {
                    Capsule().strokeBorder(Theme.success.opacity(0.5), lineWidth: 1.4)
                }
                .accessibilityAddTraits(.isSelected)
        } else if let price = PurchaseManager.shared.adFreePrice {
            Button {
                purchaseAdFree(price: price)
            } label: {
                HStack(spacing: 10) {
                    if isPurchasing {
                        ProgressView()
                            .tint(Theme.goldLight)
                    } else {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text("AD-FREE — \(price)")
                        .font(.system(size: 16, weight: .heavy).width(.condensed))
                        .tracking(1)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(GoldCapsuleButtonStyle())
            .disabled(isPurchasing)
            .accessibilityHint("One-time purchase. Removes banner and automatic ads permanently.")
        } else {
            Text("STORE NOT CONNECTED IN THIS BUILD")
                .font(.system(size: 12, weight: .heavy).width(.condensed))
                .tracking(1.5)
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay {
                    Capsule().strokeBorder(Theme.paperInkSoft.opacity(0.35), lineWidth: 1.2)
                }
        }
    }

    // MARK: Actions

    private func buyHint() {
        guard wallet.buyHint() else {
            Haptics.warning()
            showToast("NOT ENOUGH GAME BALLS")
            return
        }
        Haptics.success()
        AudioManager.shared.play(.hintPurchaseConfirm)
        showToast("+1 HINT")
    }

    private func purchaseAdFree(price: String) {
        Haptics.pickUp()
        Task { @MainActor in
            isPurchasing = true
            let granted = await PurchaseManager.shared.purchaseAdFree()
            isPurchasing = false
            if granted {
                Haptics.success()
                AudioManager.shared.play(.hintPurchaseConfirm)
                showToast("AD-FREE UNLOCKED")
            } else if let message = PurchaseManager.shared.statusMessage {
                showToast(message)
            }
        }
    }

    private func restorePurchases() {
        Haptics.tick()
        Task { @MainActor in
            isRestoring = true
            await PurchaseManager.shared.restorePurchases()
            isRestoring = false
            if let message = PurchaseManager.shared.statusMessage {
                showToast(message)
                if message.contains("RESTORED") {
                    Haptics.success()
                    AudioManager.shared.play(.hintPurchaseConfirm)
                }
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
