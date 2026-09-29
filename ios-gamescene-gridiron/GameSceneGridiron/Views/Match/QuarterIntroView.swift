import SwiftUI

/// Cinematic pre-quarter briefing: the football scenario that frames the case,
/// plus the case-file title. Flavor only — no timers, no gameplay here.
struct QuarterIntroView: View {
    let puzzle: QuarterPuzzle
    let isOvertime: Bool
    let onBegin: () -> Void

    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            DeskBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                introCard
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 26)

                Spacer(minLength: 12)

                Button {
                    onBegin()
                } label: {
                    HStack {
                        Spacer()
                        Text(isOvertime ? "BEGIN OVERTIME" : "BEGIN QUARTER")
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 26)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .padding(.bottom, 26)
                .opacity(hasAppeared ? 1 : 0)
            }
            .padding(.horizontal, 22)
        }
        .onAppear {
            Haptics.tick()
            AudioManager.shared.play(.cardSelect)
            withAnimation(.spring(response: 0.65, dampingFraction: 0.8).delay(0.1)) { hasAppeared = true }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hasAppeared)
    }

    private var introCard: some View {
        VStack(spacing: 16) {
            if isOvertime {
                overtimeBanner
            } else {
                quarterTag
            }

            Text(puzzle.introHeading)
                .font(.system(size: 40, weight: .black).width(.compressed))
                .tracking(2)
                .foregroundStyle(isOvertime ? AnyShapeStyle(Theme.danger) : AnyShapeStyle(Theme.goldGradient))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(puzzle.introBody)
                .font(Theme.typewriter(17, relativeTo: .body))
                .foregroundStyle(Theme.paperInk)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)

            divider

            HStack(spacing: 8) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.bronzeDeep)
                Text("CASE FILE — \(puzzle.title.uppercased())")
                    .font(Theme.typewriterBold(13, relativeTo: .footnote))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInk)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Theme.paperInk.opacity(0.06), in: .capsule)
            .overlay { Capsule().strokeBorder(Theme.paperInk.opacity(0.25), lineWidth: 1) }
            .minimumScaleFactor(0.8)
            .lineLimit(1)

            if isOvertime {
                Text("3 lives. Same rules. No second chances.")
                    .font(Theme.typewriter(12, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInkSoft)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .paperCard(cornerRadius: 8)
        .overlay(alignment: .topLeading) {
            if !isOvertime {
                PushPin()
                    .offset(x: 18, y: -10)
            } else {
                CautionTape(stripeWidth: 7)
                    .frame(width: 110, height: 14)
                    .rotationEffect(.degrees(-18))
                    .offset(x: 10, y: 8)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(.rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.6), radius: 16, y: 10)
    }

    private var quarterTag: some View {
        Text("QUARTER \(puzzle.index + 1)")
            .font(.system(size: 13, weight: .heavy).width(.condensed))
            .tracking(3)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Theme.goldGradient, in: .capsule)
            .accessibilityAddTraits(.isHeader)
    }

    private var overtimeBanner: some View {
        Text("OVERTIME")
            .font(.system(size: 13, weight: .heavy).width(.condensed))
            .tracking(3)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Theme.danger, in: .capsule)
            .accessibilityAddTraits(.isHeader)
    }

    private var divider: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Theme.paperInk.opacity(0.25)).frame(height: 1)
            Rectangle().fill(Theme.bronze).frame(width: 42, height: 2)
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    QuarterIntroView(puzzle: SampleQuarter.puzzle, isOvertime: false, onBegin: {})
}
