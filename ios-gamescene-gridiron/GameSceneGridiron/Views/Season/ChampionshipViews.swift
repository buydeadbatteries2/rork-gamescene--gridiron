import SwiftUI

// MARK: - Team celebration colors

extension GameTeam {
    /// Confetti/celebration palette: the franchise's own colors plus case-file gold.
    var celebrationPalette: [Color] { [primaryColor, secondaryColor, Theme.gold, Theme.paper] }
}

// MARK: - Championship intro

/// THE GRIDIRON CASE — the dramatic full-screen presentation before the
/// championship match: stadium lights, both team colors, one last case.
struct ChampionshipIntroView: View {
    let userTeam: GameTeam
    let opponent: GameTeam
    let onPlay: () -> Void
    let onClose: () -> Void

    @State private var hasAppeared: Bool = false
    @State private var beamsActive: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("football_stadium_night")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .allowsHitTesting(false)
                .ignoresSafeArea()
            LinearGradient(
                colors: [.black.opacity(0.85), .black.opacity(0.45), .black.opacity(0.9)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            lightBeams

            VStack(spacing: 20) {
                HStack {
                    Button {
                        Haptics.tick()
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.goldLight)
                            .frame(width: 38, height: 38)
                            .background(Color.black.opacity(0.45), in: .circle)
                            .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Close")
                    Spacer()
                }

                Spacer()

                VStack(spacing: 6) {
                    Text("THE GRIDIRON CASE")
                        .font(.system(size: 40, weight: .black).width(.compressed))
                        .tracking(1.5)
                        .foregroundStyle(Theme.goldGradient)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("CHAMPIONSHIP")
                        .font(.system(size: 14, weight: .heavy).width(.condensed))
                        .tracking(8)
                        .foregroundStyle(Theme.goldLight)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.6), in: .rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Theme.goldGradient, lineWidth: 2)
                        .padding(3)
                }
                .scaleEffect(hasAppeared ? 1 : 0.85)
                .opacity(hasAppeared ? 1 : 0)

                matchupRow
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 16)

                Spacer()

                Button {
                    Haptics.pickUp()
                    AudioManager.shared.play(.profileSelect)
                    onPlay()
                } label: {
                    HStack {
                        Spacer()
                        Text("PLAY THE CASE")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 28)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                .opacity(hasAppeared ? 1 : 0)
                .padding(.bottom, 26)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) { hasAppeared = true }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { beamsActive = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The Gridiron Case championship. \(userTeam.displayName) versus \(opponent.displayName)")
    }

    /// Sweeping stadium light beams.
    private var lightBeams: some View {
        ZStack {
            Beam(angle: 18, glow: userTeam.primaryColor, isActive: beamsActive)
            Beam(angle: -22, glow: opponent.primaryColor, isActive: beamsActive)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var matchupRow: some View {
        HStack(spacing: 16) {
            TeamLockupView(team: userTeam, emblemSize: 58, nameSize: 15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .shadow(color: userTeam.primaryColor.opacity(0.7), radius: 16)
            Text("VS")
                .font(.system(size: 22, weight: .black).width(.compressed))
                .foregroundStyle(Theme.gold)
            TeamLockupView(team: opponent, emblemSize: 58, nameSize: 15)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .shadow(color: opponent.primaryColor.opacity(0.7), radius: 16)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.55), in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1)
        }
    }

    private struct Beam: View {
        let angle: Double
        let glow: Color
        let isActive: Bool

        var body: some View {
            LinearGradient(
                colors: [glow.opacity(0.16), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 130)
            .rotationEffect(.degrees(isActive ? angle : angle - 14), anchor: .top)
            .blendMode(.screen)
        }
    }
}

// MARK: - Champions celebration

/// CASE CLOSED — GRIDIRON CHAMPIONS. Confetti, camera flashes and the full
/// title celebration after winning THE GRIDIRON CASE.
struct ChampionsCelebrationView: View {
    let userTeam: GameTeam
    let summary: SeasonResult
    let onViewSummary: () -> Void

    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image("football_stadium_night")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .allowsHitTesting(false)
                .ignoresSafeArea()
                .opacity(0.55)
            LinearGradient(colors: [.black.opacity(0.4), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ConfettiCanvas(palette: userTeam.celebrationPalette)
                .allowsHitTesting(false)
            CameraFlashOverlay()
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 30)

                    VStack(spacing: 8) {
                        Text("CASE CLOSED")
                            .font(.system(size: 26, weight: .black).width(.compressed))
                            .tracking(4)
                            .foregroundStyle(Theme.paperInk)
                        Text("GRIDIRON CHAMPIONS")
                            .font(.system(size: 40, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(Theme.goldGradient)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                    .background(Color.black.opacity(0.65), in: .rect(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Theme.goldGradient, lineWidth: 3)
                            .padding(4)
                    }
                    .rotationEffect(.degrees(hasAppeared ? -2 : -10))
                    .scaleEffect(hasAppeared ? 1 : 1.8)
                    .opacity(hasAppeared ? 1 : 0)

                    TeamEmblemView(team: userTeam, size: 110)
                        .shadow(color: userTeam.primaryColor.opacity(0.8), radius: 26)
                        .scaleEffect(hasAppeared ? 1 : 0.6)
                        .opacity(hasAppeared ? 1 : 0)

                    Text(userTeam.displayName.uppercased())
                        .font(.system(size: 22, weight: .black).width(.compressed))
                        .tracking(1.5)
                        .foregroundStyle(Theme.paperInk)
                        .multilineTextAlignment(.center)

                    honorCard
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)

                    Button {
                        Haptics.pickUp()
                        onViewSummary()
                    } label: {
                        HStack {
                            Spacer()
                            Text("VIEW SEASON SUMMARY")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .padding(.horizontal, 26)
                    }
                    .buttonStyle(GoldCapsuleButtonStyle())
                    .opacity(hasAppeared ? 1 : 0)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 22)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            AudioManager.shared.play(.caseSolved)
            Haptics.pickUp()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15)) { hasAppeared = true }
        }
        .sensoryFeedback(.success, trigger: hasAppeared)
    }

    private var honorCard: some View {
        VStack(spacing: 0) {
            honorRow("SEASON RECORD", summary.finalRecord, tint: Theme.paperInk)
            honorRow("FINAL STANDING", "#\(summary.finalStanding) OF \(summary.totalTeams)", tint: Theme.paperInk)
            honorRow("POSTSEASON", "GRIDIRON CASE CHAMPIONS", tint: Theme.goldLight)
            if summary.championshipOutcome?.wentToOT == true {
                honorRow("FINAL", "WON IN OVERTIME", tint: Theme.easy)
            }
        }
        .padding(.vertical, 8)
        .paperCard(cornerRadius: 8)
        .rotationEffect(.degrees(0.6))
    }

    private func honorRow(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(Theme.typewriter(12, relativeTo: .caption))
                    .foregroundStyle(Theme.paperInkSoft)
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .heavy).width(.compressed))
                    .tracking(0.6)
                    .foregroundStyle(tint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Rectangle()
                .fill(Theme.paperInk.opacity(0.1))
                .frame(height: 1)
        }
    }
}

/// Falling confetti in the champion's colors plus case-file gold.
private struct ConfettiCanvas: View {
    let palette: [Color]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<80 {
                    var rng = SeededGenerator(seed: UInt64(index &* 2_654_435_761 &+ 17))
                    let x0 = rng.nextDouble()
                    let speed = 0.055 + rng.nextDouble() * 0.075
                    let drift = (rng.nextDouble() - 0.5) * 60
                    let spin = rng.nextDouble() * 6 - 3
                    let delay = rng.nextDouble()
                    let colorIndex = Int(rng.nextDouble() * Double(palette.count))

                    let progress = ((t * speed + delay) * 1.4).truncatingRemainder(dividingBy: 1.0)
                    let y = progress * (size.height + 60) - 30
                    let x = x0 * size.width + drift * progress + sin(t * 1.6 + Double(index)) * 10
                    let rotation = t * spin + Double(index)

                    let rect = CGRect(x: 0, y: 0, width: 7, height: 10)
                    var transformed = context
                    transformed.translateBy(x: x, y: y)
                    transformed.rotate(by: .degrees(rotation))
                    transformed.fill(
                        Path(rect),
                        with: .color(palette[colorIndex].opacity(0.85))
                    )
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Sparse camera flashes popping across the stadium crowd.
private struct CameraFlashOverlay: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<14 {
                    var rng = SeededGenerator(seed: UInt64(index &* 97 &+ 5))
                    let x = rng.nextDouble() * size.width
                    let y = rng.nextDouble() * size.height * 0.55
                    let period = 0.9 + rng.nextDouble() * 1.6
                    let offset = rng.nextDouble() * period
                    let phase = (t + offset).truncatingRemainder(dividingBy: period) / period
                    let alpha = max(0, sin(phase * .pi) - 0.75) * 4
                    guard alpha > 0 else { continue }

                    let center = CGPoint(x: x, y: y)
                    let radius: CGFloat = 10 + CGFloat(index % 3) * 5
                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                        with: .radialGradient(
                            Gradient(colors: [.white.opacity(alpha), .clear]),
                            center: center,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Season summary

/// End-of-season dossier: final record, standing, playoff run and the next
/// step — START NEW SEASON keeps the franchise and resets the competition.
struct SeasonSummaryView: View {
    let userTeam: GameTeam
    let summary: SeasonResult
    let championName: String?
    let onStartNewSeason: () -> Void
    let onClose: () -> Void

    @State private var hasAppeared: Bool = false

    private var heading: String {
        summary.wonChampionship ? "GRIDIRON CHAMPIONS"
            : summary.reachedChampionship ? "CHAMPIONSHIP RUN ENDS"
            : summary.qualifiedForPlayoffs ? "POSTSEASON EXIT"
            : "SEASON COMPLETE"
    }

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                VStack(spacing: 20) {
                    header

                    VStack(spacing: 16) {
                        TeamEmblemView(team: userTeam, size: 86)
                            .shadow(color: userTeam.primaryColor.opacity(0.55), radius: 18)
                            .scaleEffect(hasAppeared ? 1 : 0.7)
                            .opacity(hasAppeared ? 1 : 0)

                        Text(userTeam.displayName.uppercased())
                            .font(.system(size: 20, weight: .black).width(.compressed))
                            .tracking(1.2)
                            .foregroundStyle(Theme.paperInk)
                            .multilineTextAlignment(.center)

                        Text(heading)
                            .font(.system(size: 24, weight: .black).width(.compressed))
                            .tracking(1.5)
                            .foregroundStyle(summary.wonChampionship ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.paperInkSoft))
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .paperCard(cornerRadius: 8)

                    dossierCard
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)

                    buttons
                        .opacity(hasAppeared ? 1 : 0)
                        .padding(.bottom, 26)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.85).delay(0.1)) { hasAppeared = true }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tick()
                onClose()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.45), in: .circle)
                    .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Back")

            Text("CASE FILE — SEASON \(summary.seasonNumber)")
                .font(.system(size: 20, weight: .black).width(.compressed))
                .tracking(1.5)
                .foregroundStyle(Theme.goldGradient)
                .frame(maxWidth: .infinity)

            Text("CLOSED")
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(2)
                .foregroundStyle(Theme.danger)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .overlay {
                    Capsule().strokeBorder(Theme.danger.opacity(0.7), lineWidth: 1.5)
                }
                .rotationEffect(.degrees(-4))
        }
    }

    private var dossierCard: some View {
        VStack(spacing: 0) {
            summaryRow("FINAL RECORD", summary.finalRecord)
            summaryRow("FINAL STANDING", "#\(summary.finalStanding) OF \(summary.totalTeams)")

            summaryRow(
                "POSTSEASON",
                summary.qualifiedForPlayoffs
                    ? (summary.reachedChampionship ? "THE GRIDIRON CASE" : "SEMIFINALS")
                    : "DID NOT QUALIFY",
                valueTint: summary.qualifiedForPlayoffs ? Theme.goldLight : Theme.paperInkSoft
            )

            if let semifinal = summary.semifinalOutcome {
                summaryRow("SEMIFINAL", outcomeLabel(semifinal), valueTint: semifinal.isWin ? Theme.easy : Theme.danger)
            }
            if summary.reachedChampionship, let championship = summary.championshipOutcome {
                summaryRow("THE GRIDIRON CASE", outcomeLabel(championship), valueTint: championship.isWin ? Theme.easy : Theme.danger)
            }
            if !summary.wonChampionship, let championName {
                summaryRow("CHAMPIONS", championName.uppercased())
            }
        }
        .padding(.vertical, 8)
        .paperCard(cornerRadius: 8)
        .overlay(alignment: .top) { PushPin(size: 18).offset(y: -8) }
        .padding(.top, 8)
    }

    private func summaryRow(_ label: String, _ value: String, valueTint: Color = Theme.paperInk) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(Theme.typewriter(13, relativeTo: .subheadline))
                    .foregroundStyle(Theme.paperInkSoft)
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .heavy).width(.compressed))
                    .tracking(0.6)
                    .foregroundStyle(valueTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            Rectangle()
                .fill(Theme.paperInk.opacity(0.1))
                .frame(height: 1)
        }
    }

    private func outcomeLabel(_ outcome: GameOutcome) -> String {
        switch outcome {
        case .win: "WON"
        case .loss: "LOST"
        case .winOT: "WON IN OT"
        case .lossOT: "LOST IN OT"
        }
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.pickUp()
                AudioManager.shared.play(.profileSelect)
                onStartNewSeason()
            } label: {
                HStack {
                    Spacer()
                    Text("START NEW SEASON")
                    Spacer()
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .bold))
                }
                .padding(.horizontal, 26)
            }
            .buttonStyle(GoldCapsuleButtonStyle())
            .accessibilityHint("Keeps your franchise and resets the competition")

            Button {
                Haptics.tick()
                onClose()
            } label: {
                Text("HOME")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.paperInk)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay { Capsule().strokeBorder(Theme.paperInk.opacity(0.4), lineWidth: 1.2) }
                    .contentShape(.capsule)
            }
            .buttonStyle(PressableButtonStyle(playsPressSound: true))
        }
    }
}
