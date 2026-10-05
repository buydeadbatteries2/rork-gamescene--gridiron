import SwiftUI

/// SELECT DIFFICULTY — four premium cards shown when starting a new season.
/// PRO carries the RECOMMENDED stamp. The choice is persisted immediately and
/// shapes every puzzle of the coming season.
struct DifficultySelectView: View {
    let onConfirm: (DifficultyLevel) -> Void

    @State private var selection: DifficultyLevel = DifficultyManager.shared.selected
    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            DeskBackground()

            VStack(spacing: 20) {
                header
                cardStack
                confirmButton
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 16)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { hasAppeared = true }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("SELECT DIFFICULTY")
                .font(.system(size: 26, weight: .black).width(.compressed))
                .tracking(2)
                .foregroundStyle(Theme.goldGradient)
            Text("HOW HARD SHOULD THE CASES RUN?")
                .font(Theme.typewriter(11, relativeTo: .caption))
                .tracking(1.2)
                .foregroundStyle(Theme.paperInkSoft)
        }
    }

    private var cardStack: some View {
        VStack(spacing: 10) {
            ForEach(DifficultyLevel.allCases, id: \.self) { level in
                DifficultyCard(level: level, isSelected: selection == level) {
                    Haptics.tick()
                    AudioManager.shared.play(.cardSelect)
                    withAnimation(.snappy) { selection = level }
                }
            }
        }
    }

    private var confirmButton: some View {
        Button {
            Haptics.pickUp()
            AudioManager.shared.play(.profileSelect)
            onConfirm(selection)
        } label: {
            HStack {
                Spacer()
                Text("START SEASON")
                Spacer()
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.horizontal, 26)
        }
        .buttonStyle(GoldCapsuleButtonStyle())
        .accessibilityHint("Starts the season with \(selection.title) difficulty")
    }
}

/// One difficulty card: mode title, one-line blurb, RECOMMENDED stamp on PRO,
/// gold gradient border + checkmark while selected.
private struct DifficultyCard: View {
    let level: DifficultyLevel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(level.title)
                            .font(.system(size: 17, weight: .black).width(.compressed))
                            .tracking(1.2)
                            .foregroundStyle(isSelected ? Theme.goldLight : Theme.paperInk)
                        if level.isRecommended {
                            Text("RECOMMENDED")
                                .font(.system(size: 8, weight: .heavy).width(.condensed))
                                .tracking(1.2)
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Theme.goldGradient, in: .capsule)
                        }
                    }
                    Text(level.blurb)
                        .font(Theme.typewriter(11, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.goldGradient)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.35), in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.paperInk.opacity(0.2)),
                        lineWidth: isSelected ? 1.6 : 1
                    )
            }
            .shadow(color: isSelected ? Theme.gold.opacity(0.3) : .black.opacity(0.4), radius: isSelected ? 12 : 5, y: 3)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .accessibilityLabel("\(level.title): \(level.blurb)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
