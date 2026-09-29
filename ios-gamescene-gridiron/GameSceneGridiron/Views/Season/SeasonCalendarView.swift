import SwiftUI

/// The coach's calendar — a manila season-planning sheet pinned to the desk.
/// Ten weekly games across fictional months with page-turn navigation,
/// penciled-in future games, a highlighted current week and case-file stamps
/// on completed games.
struct SeasonCalendarView: View {
    let userTeam: GameTeam
    let onClose: () -> Void
    let onEditTeam: () -> Void
    let onOpenStandings: () -> Void
    let onOpenPostseason: () -> Void
    let onOpenSummary: () -> Void
    let onPlayGame: (ScheduledGame) -> Void

    @State private var seasonManager = SeasonManager.shared
    @State private var monthIndex: Int = 0
    @State private var pageForward: Bool = true
    @State private var hasAppeared: Bool = false

    private var season: Season? { seasonManager.season }

    var body: some View {
        ZStack {
            DeskBackground()

            ScrollView {
                calendarSheet
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 18)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { hasAppeared = true }
            syncMonth()
        }
        .onChange(of: seasonManager.currentWeek) { _, _ in
            syncMonth()
        }
    }

    // MARK: - Sheet

    private var calendarSheet: some View {
        VStack(spacing: 16) {
            header
            recordStrip
            monthNavigation
            monthPages
            if season?.phase != .regularSeason {
                postseasonBanner
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background {
            PaperSurface(cornerRadius: 8, darkness: 0.04)
                .shadow(color: .black.opacity(0.6), radius: 16, y: 10)
        }
        .overlay(alignment: .topLeading) {
            PushPin(size: 20).offset(x: 26, y: -9)
        }
        .overlay(alignment: .topTrailing) {
            PushPin(size: 20).offset(x: -26, y: -7)
        }
        .overlay(alignment: .leading) {
            // Notebook margin line.
            Rectangle()
                .fill(Theme.danger.opacity(0.28))
                .frame(width: 2)
                .padding(.leading, 34)
                .padding(.vertical, 18)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            PlayDiagramDoodle()
                .frame(width: 120, height: 78)
                .offset(x: 8, y: -6)
                .allowsHitTesting(false)
        }
        .rotationEffect(.degrees(-0.7))
    }

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
                Text("SEASON \(season?.seasonNumber ?? 1)")
                    .font(.system(size: 26, weight: .black).width(.compressed))
                    .tracking(1.5)
                    .foregroundStyle(Theme.goldGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("CASE SCHEDULE — FICTIONAL LEAGUE")
                    .font(Theme.typewriter(10, relativeTo: .caption2))
                    .tracking(1)
                    .foregroundStyle(Theme.paperInkSoft.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)

            Button {
                Haptics.tick()
                AudioManager.shared.play(.cardSelect)
                onOpenStandings()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "list.star")
                        .font(.system(size: 13, weight: .bold))
                    Text("STANDINGS")
                        .font(.system(size: 8, weight: .heavy).width(.condensed))
                        .tracking(1)
                }
                .foregroundStyle(Theme.paperInk)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Theme.gold.opacity(0.16), in: .rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Theme.gold.opacity(0.5), lineWidth: 1)
                }
            }
            .buttonStyle(PressableButtonStyle())

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
    }

    /// Your franchise + running record pinned above the schedule.
    private var recordStrip: some View {
        HStack(spacing: 12) {
            TeamLockupView(team: userTeam, emblemSize: 44, nameSize: 15)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(seasonManager.userRecordLine ?? "0–0")
                    .font(.system(size: 30, weight: .black).width(.compressed))
                    .monospacedDigit()
                    .foregroundStyle(Theme.paperInk)
                Text(weekChipLabel)
                    .font(.system(size: 10, weight: .heavy).width(.condensed))
                    .tracking(1.4)
                    .foregroundStyle(Theme.goldLight)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.6), in: .capsule)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.35), in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.gold.opacity(0.25), lineWidth: 1)
        }
        .rotationEffect(.degrees(0.4))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Season \(season?.seasonNumber ?? 1), \(weekChipLabel), record \(seasonManager.userRecordLine ?? "0–0")")
    }

    private var weekChipLabel: String {
        if season?.phase == .regularSeason, let week = seasonManager.currentWeek {
            return "WEEK \(week)"
        }
        return season?.phase == .complete ? "SEASON COMPLETE" : "POSTSEASON"
    }

    // MARK: - Month navigation

    private var monthGroups: [(title: String, games: [ScheduledGame])] {
        guard let games = season?.games else { return [] }
        let calendar = Calendar.current
        var groups: [(title: String, games: [ScheduledGame])] = []
        for game in games {
            let month = calendar.component(.month, from: game.date)
            let year = calendar.component(.year, from: game.date)
            let title = "\(Self.monthFormatter.monthSymbols[month - 1].uppercased()) \(year)"
            if let lastIndex = groups.indices.last,
               groups[lastIndex].title == title {
                groups[lastIndex].games.append(game)
            } else {
                groups.append((title, [game]))
            }
        }
        return groups
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        return formatter
    }()

    private var canGoBack: Bool { monthIndex > 0 }
    private var canGoForward: Bool { monthIndex < monthGroups.count - 1 }

    private func moveMonth(forward: Bool) {
        guard forward ? canGoForward : canGoBack else { return }
        Haptics.tick()
        AudioManager.shared.play(.cardSelect)
        pageForward = forward
        withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
            monthIndex += forward ? 1 : -1
        }
    }

    /// Jumps to the month that holds the current (or most recent) game.
    private func syncMonth() {
        let groups = monthGroups
        guard !groups.isEmpty else { return }
        let targetDate = season?.currentGame?.date ?? season?.games.last?.date ?? Date()
        let calendar = Calendar.current
        let target = "\(calendar.component(.month, from: targetDate))-\(calendar.component(.year, from: targetDate))"
        if let index = groups.firstIndex(where: { group in
            let date = group.games[0].date
            return "\(calendar.component(.month, from: date))-\(calendar.component(.year, from: date))" == target
        }), index != monthIndex {
            monthIndex = index
        } else if monthIndex >= groups.count {
            monthIndex = groups.count - 1
        }
    }

    private var monthNavigation: some View {
        let groups = monthGroups
        return HStack(spacing: 14) {
            Button { moveMonth(forward: false) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.paperInk)
                    .frame(width: 40, height: 40)
                    .background(Theme.gold.opacity(canGoBack ? 0.22 : 0.06), in: .circle)
                    .overlay { Circle().strokeBorder(Theme.gold.opacity(canGoBack ? 0.5 : 0.15), lineWidth: 1) }
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canGoBack)
            .opacity(canGoBack ? 1 : 0.35)
            .accessibilityLabel("Previous month")

            Text(groups.indices.contains(monthIndex) ? groups[monthIndex].title : "")
                .font(.system(size: 19, weight: .black).width(.compressed))
                .tracking(1.4)
                .foregroundStyle(Theme.paperInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)

            Button { moveMonth(forward: true) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.paperInk)
                    .frame(width: 40, height: 40)
                    .background(Theme.gold.opacity(canGoForward ? 0.22 : 0.06), in: .circle)
                    .overlay { Circle().strokeBorder(Theme.gold.opacity(canGoForward ? 0.5 : 0.15), lineWidth: 1) }
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1 : 0.35)
            .accessibilityLabel("Next month")
        }
    }

    @ViewBuilder
    private var monthPages: some View {
        let groups = monthGroups
        if groups.indices.contains(monthIndex) {
            VStack(spacing: 10) {
                ForEach(groups[monthIndex].games) { game in
                    CalendarGameRow(
                        game: game,
                        userTeamID: userTeam.id,
                        isCurrent: season?.currentGame?.id == game.id
                    ) {
                        onPlayGame(game)
                    }
                }
            }
            .id(monthIndex)
            .transition(CalendarPageTurn(forward: pageForward))
        }
    }

    // MARK: - Postseason banner

    private var postseasonBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "seal")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.goldLight)
                VStack(alignment: .leading, spacing: 3) {
                    Text(season?.phase == .complete ? "REGULAR SEASON COMPLETE" : "POSTSEASON READY")
                        .font(.system(size: 16, weight: .black).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(Theme.paperInk)
                    Text(season?.phase == .complete ? "The case has a final page." : "Four teams. One case to crack.")
                        .font(Theme.typewriter(11, relativeTo: .caption))
                        .foregroundStyle(Theme.paperInkSoft)
                }
                Spacer(minLength: 0)
            }

            Button {
                Haptics.pickUp()
                AudioManager.shared.play(.profileSelect)
                onOpenPostseason()
            } label: {
                HStack {
                    Spacer()
                    Text(season?.phase == .complete ? "VIEW FINAL BRACKET" : "VIEW POSTSEASON")
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
                }
                .padding(.horizontal, 24)
            }
            .buttonStyle(GoldCapsuleButtonStyle())

            if season?.phase == .complete {
                Button {
                    Haptics.tick()
                    onOpenSummary()
                } label: {
                    Text("VIEW SEASON SUMMARY")
                        .font(.system(size: 12, weight: .heavy).width(.condensed))
                        .tracking(1.5)
                        .foregroundStyle(Theme.goldLight)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.4), in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.gold.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
        }
        .rotationEffect(.degrees(-0.4))
    }
}

// MARK: - Game row

/// One scheduled game line: date tab, opponent, and its state — penciled in,
/// highlighted as this week, or stamped with the result.
private struct CalendarGameRow: View {
    let game: ScheduledGame
    let userTeamID: UUID
    let isCurrent: Bool
    let onPlay: () -> Void

    private var opponent: GameTeam? { OpponentTeams.team(with: game.opponentID) }

    private var outcome: GameOutcome? {
        game.result.map { $0.outcome(for: userTeamID) }
    }

    private var resultLine: String? {
        guard let result = game.result, let outcome else { return nil }
        let userScore = outcome.isWin ? result.winnerScore : result.loserScore
        let opponentScore = outcome.isWin ? result.loserScore : result.winnerScore
        let letter = outcome.isWin ? "W" : "L"
        return "\(letter) \(userScore)–\(opponentScore)\(outcome.wentToOT ? " OT" : "")"
    }

    var body: some View {
        HStack(spacing: 12) {
            dateChip

            if let opponent {
                TeamEmblemView(team: opponent, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(opponent.displayName.uppercased())
                        .font(.system(size: 15, weight: .black).width(.compressed))
                        .tracking(0.6)
                        .foregroundStyle(isCurrent ? Theme.goldLight : Theme.paperInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 6) {
                        Text(Self.timeFormatter.string(from: game.date))
                            .font(Theme.typewriter(11, relativeTo: .caption))
                            .foregroundStyle(Theme.paperInkSoft)
                        Text(game.isHome ? "HOME" : "AWAY")
                            .font(.system(size: 9, weight: .heavy).width(.condensed))
                            .tracking(1)
                            .foregroundStyle(game.isHome ? Theme.gold : Theme.paperInkSoft.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.35), in: .capsule)
                    }
                }
            }

            Spacer(minLength: 8)
            trailingState
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(rowBackground)
        .overlay(rowBorder)
        .shadow(color: isCurrent ? Theme.gold.opacity(0.35) : .black.opacity(0.3), radius: isCurrent ? 10 : 4, y: isCurrent ? 2 : 3)
        .opacity(isPenciled ? 0.72 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var isPenciled: Bool { !game.isPlayed && !isCurrent }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                isCurrent
                    ? AnyShapeStyle(Theme.gold.opacity(0.14))
                    : AnyShapeStyle(Color.black.opacity(0.3))
            )
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(
                isCurrent ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.paperInk.opacity(0.2)),
                lineWidth: isCurrent ? 1.6 : 1
            )
    }

    private var accessibilityText: String {
        var parts = [Self.longDateFormatter.string(from: game.date)]
        if let opponent {
            parts.append(opponent.displayName)
        }
        parts.append(game.isHome ? "home" : "away")
        if let resultLine {
            parts.append("Result \(resultLine)")
        } else if isCurrent {
            parts.append("This week. Playable.")
        } else {
            parts.append("Scheduled.")
        }
        return parts.joined(separator: ", ")
    }

    private var dateChip: some View {
        VStack(spacing: 1) {
            Text(Self.weekdayFormatter.string(from: game.date).uppercased())
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(1)
                .foregroundStyle(Theme.danger.opacity(0.85))
            Text(Self.dayFormatter.string(from: game.date))
                .font(.system(size: 26, weight: .black).width(.compressed))
                .monospacedDigit()
                .foregroundStyle(Theme.paperInk)
            Text(Self.monthAbbrevFormatter.string(from: game.date).uppercased())
                .font(.system(size: 9, weight: .heavy).width(.condensed))
                .tracking(1.4)
                .foregroundStyle(Theme.paperInkSoft)
        }
        .frame(width: 52)
        .padding(.vertical, 6)
        .background(Theme.gold.opacity(0.1), in: .rect(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Theme.paperInk.opacity(0.25), lineWidth: 1)
        }
        .overlay {
            if game.isPlayed {
                CompletedStamp()
                    .rotationEffect(.degrees(-11))
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var trailingState: some View {
        if let resultLine, let outcome {
            VStack(alignment: .trailing, spacing: 2) {
                Text(resultLine)
                    .font(.system(size: 17, weight: .black).width(.compressed))
                    .monospacedDigit()
                    .foregroundStyle(outcome.isWin ? Theme.easy : Theme.danger)
                Text(outcome.wentToOT ? "OVERTIME" : "FINAL")
                    .font(.system(size: 8, weight: .heavy).width(.condensed))
                    .tracking(1.4)
                    .foregroundStyle(Theme.paperInkSoft)
            }
        } else if isCurrent {
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    Haptics.pickUp()
                    AudioManager.shared.play(.profileSelect)
                    onPlay()
                } label: {
                    Text("PLAY")
                        .font(.system(size: 14, weight: .black).width(.compressed))
                        .tracking(1.6)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                }
                .buttonStyle(GoldCapsuleButtonStyle())
                Text("THIS WEEK")
                    .font(.system(size: 8, weight: .heavy).width(.condensed))
                    .tracking(1.4)
                    .foregroundStyle(Theme.goldLight)
            }
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.paperInkSoft.opacity(0.7))
                Text("PENCILED IN")
                    .font(.system(size: 8, weight: .heavy).width(.condensed))
                    .tracking(1.2)
                    .foregroundStyle(Theme.paperInkSoft.opacity(0.7))
            }
        }
    }

    // MARK: Formatters

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    private static let monthAbbrevFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
}

// MARK: - Stamp

/// Hand-inked double-stroke X stamped over finished games.
private struct CompletedStamp: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var first = Path()
            first.move(to: CGPoint(x: w * 0.08, y: h * 0.18))
            first.addQuadCurve(
                to: CGPoint(x: w * 0.92, y: h * 0.86),
                control: CGPoint(x: w * 0.42, y: h * 0.62)
            )
            var second = Path()
            second.move(to: CGPoint(x: w * 0.9, y: h * 0.14))
            second.addQuadCurve(
                to: CGPoint(x: w * 0.1, y: h * 0.88),
                control: CGPoint(x: w * 0.6, y: h * 0.44)
            )
            context.stroke(
                first,
                with: .color(Theme.danger.opacity(0.85)),
                style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
            )
            context.stroke(
                second,
                with: .color(Theme.danger.opacity(0.75)),
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
            )
        }
        .frame(width: 58, height: 58)
        .accessibilityHidden(true)
    }
}

// MARK: - Doodle

/// Faint chalkboard-style football play diagram doodled on the sheet corner.
private struct PlayDiagramDoodle: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let ink = Theme.paperInk.opacity(0.16)
            let stroke = StrokeStyle(lineWidth: 2, lineCap: .round)

            // Route squiggle.
            var route = Path()
            route.move(to: CGPoint(x: w * 0.12, y: h * 0.82))
            route.addCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.2),
                control1: CGPoint(x: w * 0.3, y: h * 0.15),
                control2: CGPoint(x: w * 0.55, y: h * 0.72)
            )
            context.stroke(route, with: .color(ink), style: stroke)

            // Arrowhead.
            var arrow = Path()
            arrow.move(to: CGPoint(x: w * 0.78, y: h * 0.18))
            arrow.addLine(to: CGPoint(x: w * 0.88, y: h * 0.2))
            arrow.addLine(to: CGPoint(x: w * 0.84, y: h * 0.32))
            context.stroke(arrow, with: .color(ink), style: stroke)

            // Offensive O's.
            for point in [CGPoint(x: 0.2, y: 0.86), CGPoint(x: 0.36, y: 0.86), CGPoint(x: 0.52, y: 0.86)] {
                let rect = CGRect(x: w * point.x - 7, y: h * point.y - 7, width: 14, height: 14)
                context.stroke(Path(ellipseIn: rect), with: .color(ink), style: stroke)
            }

            // Defensive X's.
            for point in [CGPoint(x: 0.3, y: 0.42), CGPoint(x: 0.56, y: 0.5), CGPoint(x: 0.76, y: 0.62)] {
                let cx = w * point.x
                let cy = h * point.y
                var x = Path()
                x.move(to: CGPoint(x: cx - 6, y: cy - 6))
                x.addLine(to: CGPoint(x: cx + 6, y: cy + 6))
                x.move(to: CGPoint(x: cx + 6, y: cy - 6))
                x.addLine(to: CGPoint(x: cx - 6, y: cy + 6))
                context.stroke(x, with: .color(ink), style: stroke)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Page turn

/// Paper-flip transition for month pages: the sheet swings on its spine while
/// fading, like physically turning a calendar page.
struct CalendarPageTurn: Transition {
    var forward: Bool

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .rotation3DEffect(
                .degrees(angle(for: phase)),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                anchorZ: 0,
                perspective: 0.55
            )
            .opacity(phase == .identity ? 1 : 0.2)
            .offset(x: phase == .identity ? 0 : (forward ? 18 : -18))
    }

    private func angle(for phase: TransitionPhase) -> Double {
        switch phase {
        case .identity: 0
        case .willAppear: forward ? -72 : 72
        case .didDisappear: forward ? 72 : -72
        @unknown default: 0
        }
    }
}
