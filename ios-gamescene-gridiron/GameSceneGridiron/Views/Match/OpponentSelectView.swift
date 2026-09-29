import SwiftUI

/// SELECT OPPONENT — the temporary stand-in for the future season schedule.
/// Shows the 10 fixed fictional rivals as cards and launches the full match.
struct OpponentSelectView: View {
    let userTeam: GameTeam
    let onEditTeam: () -> Void
    let onClose: () -> Void

    @State private var opponent: GameTeam?
    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            DeskBackground()

            VStack(spacing: 14) {
                header

                ScrollView {
                    VStack(spacing: 12) {
                        matchupBanner
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 14)

                        ForEach(Array(OpponentTeams.all.enumerated()), id: \.element.id) { index, team in
                            OpponentCard(userTeam: userTeam, opponent: team) {
                                Haptics.pickUp()
                                AudioManager.shared.play(.profileSelect)
                                opponent = team
                            }
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 18)
                            .animation(
                                .spring(response: 0.55, dampingFraction: 0.85).delay(Double(index) * 0.04),
                                value: hasAppeared
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 26)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, 12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { hasAppeared = true }
        }
        .fullScreenCover(item: $opponent) { team in
            MatchFlowView(userTeam: userTeam, opponent: team)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
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
            .accessibilityLabel("Back to home")

            VStack(spacing: 2) {
                Text("SELECT OPPONENT")
                    .font(.system(size: 24, weight: .black).width(.compressed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.goldGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("TEMPORARY BOARD — SEASON SCHEDULE ARRIVES LATER")
                    .font(Theme.typewriter(10, relativeTo: .caption2))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInkSoft.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)

            Button {
                Haptics.tick()
                onEditTeam()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.45), in: .circle)
                    .overlay { Circle().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1) }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Edit your team")
        }
        .padding(.horizontal, 20)
    }

    /// Your franchise pinned against the board.
    private var matchupBanner: some View {
        HStack(spacing: 12) {
            TeamLockupView(team: userTeam, emblemSize: 48, nameSize: 17)
            Spacer(minLength: 0)
            Text("YOUR\nFRANCHISE")
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(1.5)
                .foregroundStyle(Theme.paperInkSoft)
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .paperCard(cornerRadius: 6)
        .rotationEffect(.degrees(-0.6))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Opponent card

/// One rival franchise card: emblem, name, kit color dots and a scout hint.
private struct OpponentCard: View {
    let userTeam: GameTeam
    let opponent: GameTeam
    let onSelect: () -> Void

    @State private var isPressedGlow: Bool = false

    /// Whether this rival will wear the light away treatment when the two
    /// primary kits would be too close on the field.
    private var wearsAlternate: Bool {
        TeamKitResolver.areSimilar(userTeam.primaryColorHex, opponent.primaryColorHex)
            || TeamKitResolver.areSimilar(userTeam.primaryColorHex, opponent.secondaryColorHex)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                TeamEmblemView(team: opponent, size: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(opponent.displayName.uppercased())
                        .font(.system(size: 18, weight: .black).width(.compressed))
                        .tracking(0.8)
                        .foregroundStyle(Theme.goldLight)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(opponent.primaryColor)
                            .frame(width: 13, height: 13)
                            .overlay { Circle().strokeBorder(Color.black.opacity(0.4), lineWidth: 1) }
                        Circle()
                            .fill(opponent.secondaryColor)
                            .frame(width: 13, height: 13)
                            .overlay { Circle().strokeBorder(Color.black.opacity(0.4), lineWidth: 1) }
                        Text("HOME KIT")
                            .font(.system(size: 9, weight: .heavy).width(.condensed))
                            .tracking(1.2)
                            .foregroundStyle(Theme.paperInkSoft)
                    }
                    if wearsAlternate {
                        Text("CLASH KIT AUTO-EQUIPPED")
                            .font(.system(size: 9, weight: .heavy).width(.condensed))
                            .tracking(1)
                            .foregroundStyle(Theme.caution)
                    }
                }

                Spacer(minLength: 0)

                VStack(spacing: 5) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Theme.gold)
                    Text("SCOUT")
                        .font(.system(size: 9, weight: .heavy).width(.condensed))
                        .tracking(1.5)
                        .foregroundStyle(Theme.paperInkSoft)
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.surfaceRaised, Theme.charcoal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(isPressedGlow ? 0.55 : 0.25), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.5), radius: 8, y: 5)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.97))
        .onChange(of: isPressedGlow) { _, _ in }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Opponent \(opponent.displayName)")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Opponent select") {
    OpponentSelectView(
        userTeam: GameTeam(
            state: "Virginia", teamName: "Cyber Wolves", logoID: "wolf",
            primaryColorHex: 0x1E2A4A, secondaryColorHex: 0xC9CDD1, isUserTeam: true
        ),
        onEditTeam: {},
        onClose: {}
    )
}
