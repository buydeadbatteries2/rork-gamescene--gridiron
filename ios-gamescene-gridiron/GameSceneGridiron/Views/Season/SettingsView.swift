import SwiftUI

/// SETTINGS — everything the player can tune, grouped in pinned cards:
/// GAMEPLAY (difficulty + tutorial replay), AUDIO (toggles + volumes),
/// ACCESSIBILITY (haptics, reduce motion, larger clue text, high contrast),
/// PURCHASES (Ad-Free status + restore) and ABOUT (version + legal links).
/// Changing difficulty during an active season applies from the next
/// unplayed game; completed games are never touched.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var difficulty = DifficultyManager.shared
    @State private var purchaseManager = PurchaseManager.shared
    @State private var audio = AudioManager.shared
    @State private var tutorial = TutorialManager.shared
    @State private var hasAppeared: Bool = false
    @State private var isReplayingTutorial: Bool = false
#if DEBUG
    @State private var isShowingDevMenu: Bool = false
#endif

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    gameplayCard
                    audioCard
                    accessibilityCard
                    purchasesCard
                    aboutCard
                    effectNote
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 30)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 16)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { hasAppeared = true }
        }
        .fullScreenCover(isPresented: $isReplayingTutorial) {
            // REPLAY TUTORIAL: the guided training case again — team creation,
            // difficulty, the season and the economy are never re-forced.
            TrainingFlowView(completeButtonTitle: "DONE") {
                isReplayingTutorial = false
            } onQuit: {
                isReplayingTutorial = false
            }
        }
        #if DEBUG
        .sheet(isPresented: $isShowingDevMenu) {
            DevMenuView()
        }
        #endif
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tick()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.45), in: .circle)
                    .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Close settings")

            VStack(spacing: 2) {
                Text("SETTINGS")
                    .font(.system(size: 26, weight: .black).width(.compressed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.goldGradient)
                Text("CASE BOARD PREFERENCES")
                    .font(Theme.typewriter(10, relativeTo: .caption2))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInkSoft.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Gameplay

    private var gameplayCard: some View {
        card(rotation: -0.5) {
            sectionHeader("GAMEPLAY", symbol: "speedometer")
            ForEach(DifficultyLevel.allCases, id: \.self) { level in
                difficultyRow(level)
            }
            Divider().overlay(Theme.paperInk.opacity(0.14)).padding(.vertical, 8)
            Button {
                Haptics.pickUp()
                AudioManager.shared.play(.cardSelect)
                isReplayingTutorial = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "graduationcap")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.goldLight)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.4), in: .circle)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("REPLAY TUTORIAL")
                            .font(.system(size: 15, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(Theme.paperInk)
                        Text("Run the guided Training Case again")
                            .font(Theme.typewriter(11, relativeTo: .caption))
                            .foregroundStyle(Theme.paperInkSoft)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.paperInk.opacity(0.4))
                }
                .padding(.vertical, 8)
                .contentShape(.rect)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.99))
            .accessibilityLabel("Replay tutorial")
        }
    }

    private func difficultyRow(_ level: DifficultyLevel) -> some View {
        Button {
            Haptics.tick()
            AudioManager.shared.play(.cardSelect)
            difficulty.select(level)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(level.title)
                            .font(.system(size: 15, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(Theme.paperInk)
                        if level.isRecommended {
                            Text("RECOMMENDED")
                                .font(.system(size: 7, weight: .heavy).width(.condensed))
                                .tracking(1.1)
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.goldGradient, in: .capsule)
                        }
                    }
                    Text(level.summary)
                        .font(Theme.typewriter(11, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                Image(systemName: difficulty.selected == level ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(difficulty.selected == level ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.paperInk.opacity(0.35)))
            }
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.99))
        .accessibilityLabel("\(level.title) difficulty")
        .accessibilityAddTraits(difficulty.selected == level ? [.isSelected] : [])
    }

    // MARK: Audio

    private var audioCard: some View {
        card(rotation: 0.5) {
            sectionHeader("AUDIO", symbol: "speaker.wave.2")

            Toggle(isOn: Binding(
                get: { audio.isMusicEnabled },
                set: { audio.setMusicEnabled($0) }
            )) {
                settingLabel("MUSIC", detail: "Investigation score")
            }
            .tint(Theme.gold)
            .padding(.vertical, 6)

            volumeSlider(label: "MUSIC VOLUME", value: Binding(
                get: { audio.musicVolume },
                set: { audio.musicVolume = $0 }
            ))

            Toggle(isOn: Binding(
                get: { audio.isSoundEffectsEnabled },
                set: { audio.setSoundEffectsEnabled($0) }
            )) {
                settingLabel("SOUND EFFECTS", detail: "Stings, snaps and stamps")
            }
            .tint(Theme.gold)
            .padding(.vertical, 6)

            volumeSlider(label: "SFX VOLUME", value: Binding(
                get: { audio.effectVolume },
                set: { audio.effectVolume = $0 }
            ))
        }
    }

    private func volumeSlider(label: String, value: Binding<Float>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(1.4)
                .foregroundStyle(Theme.paperInkSoft)
                .frame(width: 96, alignment: .leading)
            Slider(value: value, in: 0...1)
                .tint(Theme.gold)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    // MARK: Accessibility

    private var accessibilityCard: some View {
        card(rotation: -0.4) {
            sectionHeader("ACCESSIBILITY", symbol: "figure.wave")

            Toggle(isOn: Binding(
                get: { tutorial.isHapticsEnabled },
                set: { tutorial.isHapticsEnabled = $0 }
            )) {
                settingLabel("HAPTICS", detail: "Vibration on picks, verdicts and rewards")
            }
            .tint(Theme.gold)
            .padding(.vertical, 6)

            Toggle(isOn: Binding(
                get: { tutorial.isReduceMotionEnabled },
                set: { tutorial.isReduceMotionEnabled = $0 }
            )) {
                settingLabel("REDUCE MOTION", detail: "Calmer page flips and slides")
            }
            .tint(Theme.gold)
            .padding(.vertical, 6)

            Toggle(isOn: Binding(
                get: { tutorial.isLargerClueTextEnabled },
                set: { tutorial.isLargerClueTextEnabled = $0 }
            )) {
                settingLabel("LARGER CLUE TEXT", detail: "Bigger notebook type, never clipped")
            }
            .tint(Theme.gold)
            .padding(.vertical, 6)

            Toggle(isOn: Binding(
                get: { tutorial.isHighContrastCluesEnabled },
                set: { tutorial.isHighContrastCluesEnabled = $0 }
            )) {
                settingLabel("HIGH CONTRAST CLUES", detail: "Stronger highlighted words and tags")
            }
            .tint(Theme.gold)
            .padding(.vertical, 6)
        }
    }

    // MARK: Purchases

    private var purchasesCard: some View {
        card(rotation: 0.4) {
            sectionHeader("PURCHASES", symbol: "checkmark.seal")

            HStack(spacing: 12) {
                Image(systemName: purchaseManager.hasAdFree ? "seal.fill" : "seal")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(purchaseManager.hasAdFree ? Theme.gold : Theme.paperInkSoft)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.4), in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(purchaseManager.hasAdFree ? "AD-FREE OWNED" : "ADS ENABLED")
                        .font(.system(size: 15, weight: .black).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(Theme.paperInk)
                    Text(purchaseManager.hasAdFree ? "No banner or interstitial ads" : "Ad-Free removes them permanently")
                        .font(Theme.typewriter(11, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)

            Button {
                Haptics.tick()
                AudioManager.shared.play(.buttonPress)
                Task { await purchaseManager.restorePurchases() }
            } label: {
                Text("RESTORE PURCHASES")
                    .font(.system(size: 13, weight: .heavy).width(.condensed))
                    .tracking(1.6)
                    .foregroundStyle(Theme.paperInk)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay { Capsule().strokeBorder(Theme.paperInk.opacity(0.4), lineWidth: 1.2) }
                    .contentShape(.capsule)
            }
            .buttonStyle(PressableButtonStyle(playsPressSound: true))
            .accessibilityHint("Restores the Ad-Free purchase from the App Store")
        }
    }

    // MARK: About

    /// ABOUT — bundle version (read live, never hard-coded) plus configurable
    /// hooks for the Privacy Policy, Terms of Use and Support. A link that
    /// isn't configured yet renders a neutral unavailable state, never a dead
    /// end and never an invented URL.
    private var aboutCard: some View {
        card(rotation: -0.3) {
            sectionHeader("ABOUT", symbol: "info.circle")

            Text(AppInfo.displayLine)
                .font(.system(size: 14, weight: .heavy).width(.condensed))
                .tracking(1)
                .foregroundStyle(Theme.paperInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)
                .accessibilityLabel("App version \(AppInfo.version), build \(AppInfo.build)")

            aboutLinkRow("PRIVACY POLICY", symbol: "hand.raised.fill", url: AppLinks.privacyPolicyURL)
            aboutLinkRow("TERMS OF USE", symbol: "doc.plaintext", url: AppLinks.termsOfUseURL)
            aboutLinkRow("SUPPORT", symbol: "envelope", url: AppLinks.supportURL)
        }
    }

    private func aboutLinkRow(_ title: String, symbol: String, url: URL?) -> some View {
        Button {
            Haptics.tick()
            guard let url else { return }
            AudioManager.shared.play(.buttonPress)
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(url != nil ? Theme.gold : Theme.paperInkSoft.opacity(0.5))
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 13, weight: .heavy).width(.condensed))
                    .tracking(1.4)
                    .foregroundStyle(url != nil ? Theme.paperInk : Theme.paperInkSoft.opacity(0.7))
                Spacer()
                Text(url != nil ? "OPEN" : "COMING SOON")
                    .font(.system(size: 9, weight: .black).width(.condensed))
                    .tracking(1.2)
                    .foregroundStyle(Theme.paperInkSoft.opacity(0.7))
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(url == nil)
        .accessibilityLabel(title)
        .accessibilityHint(url != nil ? "Opens the page" : "Not yet available")
    }

    // MARK: Shared pieces

    private func card<Content: View>(rotation: Double, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 2) {
            content()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background {
            PaperSurface(cornerRadius: 8, darkness: 0.04)
                .shadow(color: .black.opacity(0.6), radius: 16, y: 10)
        }
        .overlay(alignment: .top) {
            PushPin(size: 18).offset(y: -8)
        }
        .rotationEffect(.degrees(rotation))
        .accessibilityElement(children: .contain)
    }

    private func settingLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .heavy).width(.condensed))
                .tracking(1.2)
                .foregroundStyle(Theme.paperInk)
            Text(detail)
                .font(Theme.typewriter(11, relativeTo: .caption))
                .foregroundStyle(Theme.paperInkSoft)
        }
    }

    private var effectNote: some View {
        VStack(spacing: 10) {
            Text("CHANGING DIFFICULTY APPLIES FROM YOUR NEXT UNPLAYED GAME. COMPLETED GAMES ARE NEVER CHANGED.")
                .font(.system(size: 9, weight: .heavy).width(.condensed))
                .tracking(1.2)
                .foregroundStyle(Theme.paperInkSoft.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 12)
            #if DEBUG
            Button {
                Haptics.tick()
                isShowingDevMenu = true
            } label: {
                Text("DEVELOPER QA")
                    .font(.system(size: 11, weight: .heavy).width(.condensed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.goldLight)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .overlay { Capsule().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
                    .contentShape(.capsule)
            }
            .accessibilityLabel("Developer QA menu (debug builds only)")
            #endif
        }
    }

    private func sectionHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.bronzeDeep)
            Text(title)
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.paperInkSoft)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
        .accessibilityAddTraits(.isHeader)
    }
}
