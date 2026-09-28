import SwiftUI

/// Pause menu: resume, restart the quarter, audio settings, or return to Home.
struct PauseOverlay: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    private var audio: AudioManager { .shared }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture(perform: onResume)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text("TIMEOUT")
                    .font(Theme.typewriterBold(30, relativeTo: .title))
                    .foregroundStyle(Theme.paperInk)
                Text("The evidence isn't going anywhere.")
                    .font(Theme.typewriter(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.paperInkSoft)

                Button(action: onResume) {
                    Label("RESUME", systemImage: "play.fill").padding(.horizontal, 20)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .padding(.top, 6)

                Button(action: onRestart) {
                    Label("Restart Quarter", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.paperInk)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .overlay { Capsule().strokeBorder(Theme.paperInk.opacity(0.4), lineWidth: 1.2) }
                        .contentShape(.capsule)
                }
                .buttonStyle(PressableButtonStyle(playsPressSound: true))

                Button(action: onQuit) {
                    Text("Leave Investigation")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(PressableButtonStyle(playsPressSound: true))

                audioSettings
            }
            .padding(24)
            .paperCard(cornerRadius: 10)
            .overlay(alignment: .topTrailing) {
                CautionTape(stripeWidth: 7)
                    .frame(width: 90, height: 14)
                    .rotationEffect(.degrees(40))
                    .offset(x: 18, y: 10)
                    .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: 10))
            .padding(.horizontal, 32)
        }
    }

    private var audioSettings: some View {
        VStack(spacing: 10) {
            Text("AUDIO")
                .font(.system(size: 11, weight: .heavy).width(.condensed))
                .tracking(1.6)
                .foregroundStyle(Theme.paperInkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            audioRow(
                title: "Music",
                icon: "music.note",
                isOn: audio.isMusicEnabled
            ) { audio.setMusicEnabled($0) }

            audioRow(
                title: "Sound Effects",
                icon: "speaker.wave.2.fill",
                isOn: audio.isSoundEffectsEnabled
            ) { audio.setSoundEffectsEnabled($0) }
        }
        .padding(.top, 4)
    }

    private func audioRow(
        title: String,
        icon: String,
        isOn: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.bronze)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.paperInk)
            Spacer()
            Toggle(title, isOn: Binding(
                get: { isOn },
                set: { onChange($0) }
            ))
            .labelsHidden()
            .tint(Theme.bronze)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background {
            Capsule().fill(Theme.paperInk.opacity(0.06))
        }
    }
}
