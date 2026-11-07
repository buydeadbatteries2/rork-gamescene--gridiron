import SwiftUI

/// SETTINGS — everything the player can tune, grouped in pinned cards:
/// GAMEPLAY (difficulty + tutorial replay), AUDIO (toggles + volumes),
/// ACCESSIBILITY (haptics, reduce motion, larger clue text, high contrast),
/// PURCHASES (Ad-Free status + restore) and ABOUT (version + legal links).
/// Difficulty is locked while a season is running (shown, never hidden);
/// between seasons the choice is free until the next season starts.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var difficulty = DifficultyManager.shared
    @State private var seasonManager = SeasonManager.shared
    @State private var purchaseManager = PurchaseManager.shared
    @State private var audio = AudioManager.shared
    @State private var tutorial = TutorialManager.shared
    @State private var adMob = AdMobService.shared
    @State private var auth = AuthService.shared
    @State private var hasAppeared: Bool = false
    @State private var isReplayingTutorial: Bool = false
    @State private var isShowingProfile: Bool = false

    /// Phase 11.6: while a season is running the difficulty is pinned to the
    /// level the season was started with. The current difficulty stays fully
    /// visible — it just can't change until the season ends.
    private var isDifficultyLocked: Bool { seasonManager.hasSeasonInProgress }
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
                    accountCard
                    audioCard
                    accessibilityCard
                    purchasesCard
                    privacyCard
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
        .sheet(isPresented: $isShowingProfile) {
            NavigationStack { ProfileView() }
                .preferredColorScheme(.dark)
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
            if isDifficultyLocked, let locked = seasonManager.activeSeasonDifficulty {
                lockedDifficultyBanner(locked)
            }
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

    /// Phase 11.6 locked-difficulty banner: DIFFICULTY / ALL-PRO with the
    /// supporting line, shown while a season is running.
    private func lockedDifficultyBanner(_ locked: DifficultyLevel) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.35), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text("DIFFICULTY — \(locked.title)")
                    .font(.system(size: 12, weight: .black).width(.condensed))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInk)
                Text("Locked until the current season ends.")
                    .font(Theme.typewriter(10.5, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Theme.gold.opacity(0.08), in: .rect(cornerRadius: 6))
        .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.gold.opacity(0.25), lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Difficulty \(locked.title). Locked until the current season ends.")
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
        .disabled(isDifficultyLocked)
        .accessibilityLabel("\(level.title) difficulty")
        .accessibilityHint(isDifficultyLocked ? "Locked until the current season ends" : "")
        .accessibilityAddTraits(difficulty.selected == level ? [.isSelected] : [])
    }

    // MARK: Account

    /// ACCOUNT — signed-in state at a glance, opening the player file. Solo
    /// play never requires an account; online competition will later be gated
    /// by `AccountGatePolicy` through this same entry point.
    private var accountCard: some View {
        card(rotation: 0.45) {
            sectionHeader("ACCOUNT", symbol: "person.crop.circle")
            Button {
                Haptics.tick()
                AudioManager.shared.play(.buttonPress)
                isShowingProfile = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: accountSymbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.goldLight)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.4), in: .circle)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(accountTitle)
                            .font(.system(size: 15, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(Theme.paperInk)
                        Text(accountDetail)
                            .font(Theme.typewriter(11, relativeTo: .caption))
                            .foregroundStyle(Theme.paperInkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
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
            .accessibilityLabel("Account — \(accountTitle)")
        }
    }

    private var accountSymbol: String {
        if case .authenticated = auth.state { return "person.crop.circle.badge.checkmark" }
        return "person.crop.circle.badge.questionmark"
    }

    private var accountTitle: String {
        if case .authenticated(let profile) = auth.state {
            return profile.footballDisplayName.isEmpty ? profile.username.uppercased() : profile.footballDisplayName.uppercased()
        }
        return "GUEST FILE"
    }

    private var accountDetail: String {
        if case .authenticated(let profile) = auth.state {
            return "Signed in · \(profile.username)"
        }
        if case .needsProfileRecovery = auth.state {
            return "Account found — finish syncing your player file"
        }
        return "Playing solo — tap to add an account"
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
                    Text(purchaseManager.hasAdFree ? "FORCED ADS REMOVED" : "ADS ENABLED")
                        .font(.system(size: 15, weight: .black).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(Theme.paperInk)
                    Text(purchaseManager.hasAdFree ? "No forced ads. Optional rewarded videos remain available." : "Remove Forced Ads strips them permanently")
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

    // MARK: Privacy

    /// PRIVACY — Google's UMP privacy-options entry point, shown ONLY when
    /// the consent configuration says one is required (no geography is ever
    /// assumed in code). The existing Privacy Policy / Terms / Support hooks
    /// stay in ABOUT below.
    @ViewBuilder
    private var privacyCard: some View {
        if adMob.isPrivacyOptionsRequired {
            card(rotation: 0.35) {
                sectionHeader("PRIVACY", symbol: "hand.raised")
                Button {
                    Haptics.tick()
                    AudioManager.shared.play(.buttonPress)
                    Task {
                        try? await adMob.showPrivacyOptionsForm()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.goldLight)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.4), in: .circle)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("PRIVACY OPTIONS")
                                .font(.system(size: 15, weight: .black).width(.compressed))
                                .tracking(1)
                                .foregroundStyle(Theme.paperInk)
                            Text("Review or change your ad privacy choices")
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
                .accessibilityLabel("Privacy options")
            }
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
            Text(isDifficultyLocked
                 ? "DIFFICULTY IS LOCKED WHILE A SEASON IS RUNNING. YOU'LL CHOOSE AGAIN BEFORE THE NEXT SEASON STARTS."
                 : "CHANGING DIFFICULTY APPLIES FROM YOUR NEXT UNPLAYED GAME. COMPLETED GAMES ARE NEVER CHANGED.")
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
