import SwiftUI

/// SETTINGS — difficulty lives here. Changing it during an active season
/// applies from the next unplayed game; completed games are never touched.
/// Audio toggles mirror the pause-menu switches and persist via the audio
/// manager.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var difficulty = DifficultyManager.shared
    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    difficultyCard
                    audioCard
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

    // MARK: Difficulty

    private var difficultyCard: some View {
        VStack(spacing: 2) {
            sectionHeader("DIFFICULTY", symbol: "speedometer")
            ForEach(DifficultyLevel.allCases, id: \.self) { level in
                difficultyRow(level)
            }
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
        .rotationEffect(.degrees(-0.5))
        .accessibilityElement(children: .contain)
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
        VStack(spacing: 2) {
            sectionHeader("AUDIO", symbol: "speaker.wave.2")
            Toggle(isOn: Binding(
                get: { AudioManager.shared.isMusicEnabled },
                set: { AudioManager.shared.setMusicEnabled($0) }
            )) {
                settingLabel("MUSIC", detail: "Investigation score")
            }
            .tint(Theme.gold)
            .padding(.vertical, 10)

            Toggle(isOn: Binding(
                get: { AudioManager.shared.isSoundEffectsEnabled },
                set: { AudioManager.shared.setSoundEffectsEnabled($0) }
            )) {
                settingLabel("SOUND EFFECTS", detail: "Stings, snaps and stamps")
            }
            .tint(Theme.gold)
            .padding(.vertical, 10)
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
        .rotationEffect(.degrees(0.5))
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
        Text("CHANGING DIFFICULTY APPLIES FROM YOUR NEXT UNPLAYED GAME. COMPLETED GAMES ARE NEVER CHANGED.")
            .font(.system(size: 9, weight: .heavy).width(.condensed))
            .tracking(1.2)
            .foregroundStyle(Theme.paperInkSoft.opacity(0.75))
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .padding(.horizontal, 12)
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
