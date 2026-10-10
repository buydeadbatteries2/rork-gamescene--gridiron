import Foundation

// MARK: - Achievement coordinator

/// Routes gameplay events to the achievement and legacy services. The single
/// seam between the game flow and the recognition layer: views and view models
/// call these static methods at safe breaks (quarter result, recorded game,
/// completed season) — never mid-puzzle and never on a timer.
///
/// Order matters: the roster ledger is updated by the caller first, so player
/// milestones always read post-game career totals.
@MainActor
enum AchievementCoordinator {

    /// One solved quarter in a real game. Training never calls this.
    static func quarterSolved(livesLost: Int, hintsUsed: Int, isOvertime: Bool, difficulty: DifficultyLevel) {
        AchievementManager.shared.noteQuarterSolved(
            livesLost: livesLost,
            hintsUsed: hintsUsed,
            isOvertime: isOvertime,
            difficulty: difficulty
        )
        LegacyStore.shared.recordQuarterSolved()
        claimPendingRewards()
    }

    /// One finished, recorded game. `match` is the completed match; `stage`
    /// says which kind of game it was. The caller must have recorded the game
    /// into the season and roster ledgers already.
    static func gameCompleted(match: GameMatch, stage: FranchiseGameStage, difficulty: DifficultyLevel) {
        let result = match.result
        let won = result?.isWin ?? false
        let wentToOT = match.overtimeRecord != nil
        let wonOT = match.overtimeRecord?.outcome == .solved
        // COMEBACK CASE: at the Q4 snap only one quarter was solved, Q4 was
        // solved to force overtime, and overtime was then won.
        let regulation = match.quarterRecords
        let solvedBeforeQ4 = regulation.dropLast().filter { $0.outcome == .solved }.count
        let forcedOTFromOne = regulation.count == GameMatch.regulationQuarters
            && solvedBeforeQ4 == 1
            && regulation.last?.outcome == .solved

        AchievementManager.shared.noteGameCompleted(
            won: won,
            quartersSolved: match.quartersSolved,
            wentToOT: wentToOT,
            wonOT: wonOT,
            wrongPlacements: match.totalWrongPlacements,
            forcedOvertimeFromOneSolved: forcedOTFromOne,
            difficulty: difficulty,
            stage: stage
        )

        // Streaks and franchise-wide counters (history already includes this game).
        LegacyStore.shared.recordGameResult(isWin: won)
        if let history = RosterManager.shared.franchise?.history {
            AchievementManager.shared.noteFranchiseState(
                gamesPlayed: history.wins + history.losses,
                currentWinStreak: LegacyStore.shared.currentWinStreak,
                longestWinStreak: LegacyStore.shared.longestWinStreak
            )
        }

        playerMilestones()
        claimPendingRewards()
    }

    /// Player-category achievements, evaluated after the roster ledger
    /// applied the game's stat awards.
    static func playerMilestones() {
        guard let players = RosterManager.shared.franchise?.allPlayers else { return }
        AchievementManager.shared.notePlayerMilestones(players: players)
    }

    /// One completed season, archived once. Builds the historical snapshot
    /// (team identity, record, difficulty, postseason result) and the
    /// championship trophy when the season ended with a title.
    static func seasonCompleted(season: Season, difficulty: DifficultyLevel) {
        let summary = SeasonResult.summary(for: season, nameFor: { SeasonManager.shared.name(for: $0) })
        let standing = season.userStanding
        let wins = standing?.totalWins ?? 0
        let losses = standing?.totalLosses ?? 0

        // Historical franchise snapshot — frozen at this moment on purpose.
        var trophy: ChampionshipTrophy?
        if summary.wonChampionship, let team = TeamStore.shared.userTeam {
            var opponentName = "UNKNOWN"
            var resultLine = summary.finalRecord
            if let championship = season.bracket?.championship, let result = championship.result {
                let opponentID = championship.teamA == season.userTeamID ? championship.teamB : championship.teamA
                opponentName = OpponentTeams.team(with: opponentID)?.displayName ?? "UNKNOWN"
                resultLine = result.scoreLine
            }
            trophy = ChampionshipTrophy(
                seasonNumber: season.seasonNumber,
                teamState: team.state,
                teamName: team.teamName,
                logoID: team.logoID,
                primaryColorHex: team.primaryColorHex,
                secondaryColorHex: team.secondaryColorHex,
                regularSeasonRecord: summary.finalRecord,
                difficulty: difficulty.title,
                opponentName: opponentName,
                resultLine: resultLine,
                date: .now
            )
        }

        let postseasonResult: String
        if !summary.qualifiedForPlayoffs {
            postseasonResult = SeasonArchiveEntry.missedPlayoffsResult
        } else if summary.wonChampionship {
            postseasonResult = SeasonArchiveEntry.championResult
        } else if summary.reachedChampionship {
            postseasonResult = SeasonArchiveEntry.lostChampionshipResult
        } else {
            postseasonResult = SeasonArchiveEntry.lostSemifinalResult
        }

        let entry = SeasonArchiveEntry(
            seasonNumber: season.seasonNumber,
            recordLine: summary.finalRecord,
            wins: wins,
            losses: losses,
            standing: summary.finalStanding,
            totalTeams: summary.totalTeams,
            difficulty: difficulty.title,
            postseasonResult: postseasonResult,
            date: .now
        )

        LegacyStore.shared.completeSeason(entry, trophy: trophy)
        // BACK TO BACK compares this season against the PREVIOUS title's season.
        let previousTitleSeason = LegacyStore.shared.trophies
            .map(\.seasonNumber)
            .filter { $0 < season.seasonNumber }
            .max()
        AchievementManager.shared.noteSeasonCompleted(
            summary: summary,
            wins: wins,
            losses: losses,
            championshipCount: LegacyStore.shared.championshipsWon,
            lastTitleSeasonNumber: previousTitleSeason
        )
        claimPendingRewards()
    }

    /// Pays every unlocked-but-unpaid achievement reward through the wallet.
    /// The `"achievement-<id>"` transaction id makes a second payment
    /// impossible — the wallet ledger is the guarantee.
    static func claimPendingRewards() {
        for achievement in AchievementManager.shared.unclaimedRewardAchievements() {
            let paid = PlayerWallet.shared.earn(
                amount: achievement.reward,
                kind: .achievementReward,
                transactionID: "achievement-\(achievement.id.rawValue)"
            )
            // `false` here means the wallet already paid this id — record the
            // claim either way so the pending list drains.
            AchievementManager.shared.markRewardClaimed(achievement.id)
            _ = paid
        }
    }
}
