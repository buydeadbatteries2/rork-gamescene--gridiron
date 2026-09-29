import CoreGraphics
import Foundation
import Testing
@testable import GameSceneGridiron

/// Phase 4 season coverage: schedule generation, week progression, CPU
/// simulation determinism, standings, playoffs, championship and new-season
/// resets. All through `SeasonManager` with isolated UserDefaults.
@MainActor
@Suite("SeasonTests")
struct SeasonTests {
    private let suiteName: String
    private let defaults: UserDefaults
    private let manager: SeasonManager
    private let userTeam = GameTeam(
        state: "Virginia", teamName: "Cyber Wolves", logoID: "wolf",
        primaryColorHex: 0x1E2A4A, secondaryColorHex: 0xC9CDD1, isUserTeam: true
    )

    init() {
        suiteName = "gamescene.season-tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        manager = SeasonManager(defaults: defaults)
    }

    // MARK: Schedule

    @Test("Schedule: 10 weeks, every opponent once, ascending dates")
    func scheduleIsCompleteRoundRobin() {
        manager.startNewSeason(userTeam: userTeam)

        let season = try! #require(manager.season)
        #expect(season.games.count == 10)
        #expect(Set(season.games.map(\.week)) == Set(1...10))
        #expect(Set(season.games.map(\.opponentID)) == Set(OpponentTeams.all.map(\.id)))

        let dates = season.games.map(\.date)
        #expect(dates == dates.sorted())
    }

    @Test("Only Week 1 is playable at season start")
    func onlyFirstWeekPlayable() {
        manager.startNewSeason(userTeam: userTeam)

        let season = try! #require(manager.season)
        #expect(season.currentGame?.week == 1)
        #expect(season.games.dropFirst().allSatisfy { !$0.isPlayed })
        #expect(manager.currentWeek == 1)
    }

    // MARK: Recording

    @Test("Recording a win updates record, calendar, CPU standings and unlocks Week 2")
    func winRecordsAndAdvances() {
        manager.startNewSeason(userTeam: userTeam)

        let recorded = manager.recordUserResult(isWin: true, userScore: 3, opponentScore: 1, wentToOT: false)
        #expect(recorded)

        let season = try! #require(manager.season)
        #expect(season.currentGame?.week == 2)
        #expect(season.games.first?.isPlayed == true)

        let userStanding = try! #require(season.userStanding)
        #expect(userStanding.totalWins == 1)
        #expect(userStanding.recordLine == "1–0")

        let opponentID = try! #require(season.games.first?.opponentID)
        let opponentStanding = try! #require(season.standing(for: opponentID))
        #expect(opponentStanding.totalLosses == 1)

        // The 8 non-resting opponents each played one simulated CPU game.
        let restingID = opponentID
        let cpuPlayed = season.standings.filter { standing in
            standing.teamID != season.userTeamID
                && standing.teamID != restingID
                && standing.gamesPlayed == 1
        }
        #expect(cpuPlayed.count == 8)
    }

    @Test("Recording via GameMatch maps quarter records correctly")
    func recordUserMatchMapsQuarters() {
        manager.startNewSeason(userTeam: userTeam)
        let opponent = try! #require(manager.nextOpponent)

        var match = GameMatch.fresh()
        for index in 0..<3 {
            match.recordQuarter(
                index: index, label: "Q\(index + 1)", isOvertime: false,
                outcome: .solved, correctPlacements: 4, wrongPlacements: 1, livesLost: 1, hintsUsed: 0
            )
        }
        match.recordQuarter(
            index: 3, label: "Q4", isOvertime: false,
            outcome: .failed, correctPlacements: 3, wrongPlacements: 2, livesLost: 2, hintsUsed: 1
        )
        #expect(match.result == .victory)
        #expect(match.scoreLine == "3–1")

        #expect(manager.recordUserMatch(match, opponent: opponent))

        let season = try! #require(manager.season)
        #expect(season.currentGame?.week == 2)
        let userStanding = try! #require(season.userStanding)
        #expect(userStanding.recordLine == "1–0")
    }

    @Test("App restart preserves the full season state")
    func restartPreservesSeason() {
        manager.startNewSeason(userTeam: userTeam)
        #expect(manager.recordUserResult(isWin: false, userScore: 1, opponentScore: 3, wentToOT: false))

        let reloaded = SeasonManager(defaults: defaults)
        #expect(reloaded.season == manager.season)
        #expect(reloaded.currentWeek == 2)
        #expect(reloaded.userRecordLine == "0–1")
    }

    // MARK: Simulation

    @Test("CPU simulation is deterministic for the same matchup")
    func simulationIsDeterministic() {
        let home = OpponentTeams.all[0]
        let away = OpponentTeams.all[3]

        let first = SeasonSim.simulateGame(seasonNumber: 1, week: 4, home: home, away: away)
        let second = SeasonSim.simulateGame(seasonNumber: 1, week: 4, home: home, away: away)
        #expect(first == second)

        let otherWeek = SeasonSim.simulateGame(seasonNumber: 1, week: 5, home: home, away: away)
        // Not a strict requirement, but the seeds differ so results should vary.
        _ = otherWeek
    }

    @Test("Simulated scores follow the game's rules")
    func simulatedScoresFollowRules() {
        var rng = SeededGenerator(seed: 42)
        for _ in 0..<200 {
            let home = OpponentTeams.all[Int(rng.next() % 10)]
            var awayID = OpponentTeams.all[Int(rng.next() % 10)].id
            if awayID == home.id { awayID = OpponentTeams.all[(Int(rng.next() % 9) + 1) % 10].id }
            let away = try! #require(OpponentTeams.team(with: awayID))
            let result = SeasonSim.simulateGame(seasonNumber: 1, week: 3, home: home, away: away)
            #expect(result.winnerScore >= 3 && result.winnerScore <= 4)
            if result.wentToOT {
                #expect(result.loserScore == 2)
            } else {
                #expect(result.loserScore <= 1)
            }
        }
    }

    // MARK: Result math

    @Test("GameResult outcome mapping and score lines")
    func resultOutcomeMapping() {
        let user = userTeam
        let opponent = OpponentTeams.all[0]

        let regulationWin = GameResult.fromPerspective(
            teamID: user.id, opponentID: opponent.id,
            isWin: true, teamScore: 3, opponentScore: 1, wentToOT: false
        )
        #expect(regulationWin.scoreLine == "3–1")
        #expect(regulationWin.outcome(for: user.id) == .win)
        #expect(regulationWin.outcome(for: opponent.id) == .loss)

        let otLoss = GameResult.fromPerspective(
            teamID: user.id, opponentID: opponent.id,
            isWin: false, teamScore: 2, opponentScore: 3, wentToOT: true
        )
        #expect(otLoss.scoreLine == "3–2 OT")
        #expect(otLoss.outcome(for: user.id) == .lossOT)
        #expect(otLoss.outcome(for: opponent.id) == .winOT)
    }

    // MARK: Full season → postseason

    /// Plays all 10 weeks with scripted user results.
    private func playWholeSeason(winCount: Int) {
        manager.startNewSeason(userTeam: userTeam)
        for week in 1...10 {
            let isWin = week <= winCount
            #expect(manager.recordUserResult(
                isWin: isWin,
                userScore: isWin ? 3 : 1,
                opponentScore: isWin ? 1 : 3,
                wentToOT: false
            ))
        }
    }

    @Test("Perfect season qualifies #1 and reaches the championship")
    func perfectSeasonReachesChampionship() {
        playWholeSeason(winCount: 10)

        let season = try! #require(manager.season)
        #expect(season.phase == .postseason)
        let bracket = try! #require(season.bracket)
        #expect(bracket.semifinal1.seedA == 1 && bracket.semifinal1.seedB == 4)
        #expect(bracket.semifinal2.seedA == 2 && bracket.semifinal2.seedB == 3)
        #expect(bracket.semifinal1.has(teamID: userTeam.id))
        #expect(bracket.semifinal2.result != nil) // CPU semifinal resolved
        #expect(manager.pendingPlayoffOpponentID != nil)

        // Win the semifinal → championship appears and waits for the player.
        #expect(manager.recordUserPlayoffResult(isWin: true, userScore: 4, opponentScore: 0, wentToOT: false))
        let withChampionship = try! #require(manager.season?.bracket)
        let championship = try! #require(withChampionship.championship)
        #expect(championship.has(teamID: userTeam.id))
        #expect(championship.result == nil)
        #expect(manager.season?.phase == .postseason)
        #expect(manager.pendingPlayoffOpponentID != nil)

        // Win it all.
        #expect(manager.recordUserPlayoffResult(isWin: true, userScore: 3, opponentScore: 2, wentToOT: true))
        #expect(manager.season?.phase == .complete)
        #expect(manager.season?.bracket?.championID == userTeam.id)
        let summary = try! #require(manager.seasonResult)
        #expect(summary.wonChampionship)
        #expect(summary.finalRecord == "10–0")
        #expect(summary.finalStanding == 1)
        #expect(summary.reachedChampionship)
        #expect(summary.championshipOutcome?.isWin == true)
    }

    @Test("Losing the semifinal ends the run and crowns a CPU champion")
    func semifinalLossCompletesSeason() {
        playWholeSeason(winCount: 10)

        #expect(manager.season?.phase == .postseason)
        #expect(manager.recordUserPlayoffResult(isWin: false, userScore: 1, opponentScore: 3, wentToOT: false))

        let season = try! #require(manager.season)
        #expect(season.phase == .complete)
        let bracket = try! #require(season.bracket)
        #expect(bracket.championID != nil)
        #expect(bracket.championID != userTeam.id)
        #expect(bracket.championship?.result != nil)

        let summary = try! #require(manager.seasonResult)
        #expect(summary.qualifiedForPlayoffs)
        #expect(summary.reachedChampionship == false)
        #expect(summary.semifinalOutcome?.isWin == false)
        #expect(summary.wonChampionship == false)
    }

    @Test("Winless season misses the playoffs and the CPU postseason resolves")
    func winlessSeasonCompletesLocally() {
        playWholeSeason(winCount: 0)

        let season = try! #require(manager.season)
        #expect(season.phase == .complete)
        let bracket = try! #require(season.bracket)
        #expect(!bracket.semifinal1.has(teamID: userTeam.id))
        #expect(!bracket.semifinal2.has(teamID: userTeam.id))
        #expect(bracket.championID != nil)

        let summary = try! #require(manager.seasonResult)
        #expect(summary.finalRecord == "0–10")
        #expect(summary.qualifiedForPlayoffs == false)
        #expect(summary.finalStanding > 4)
    }

    // MARK: Standings

    @Test("Standings sort by wins with the user included")
    func standingsSortByWins() {
        playWholeSeason(winCount: 7)

        let ranked = manager.rankedStandings()
        #expect(ranked.count == 11)
        let wins = ranked.map(\.totalWins)
        #expect(wins == wins.sorted(by: >))

        // A 7–3 team can be overtaken by a strong CPU rival — the position just
        // has to match the ranked list exactly.
        let userPosition = try! #require(Season.position(of: userTeam.id, in: ranked))
        #expect(manager.userStandingPosition == userPosition)
        #expect(ranked[0].totalWins >= 7)
    }

    // MARK: New season

    @Test("New season resets competition data and keeps the franchise")
    func newSeasonResetsCompetition() {
        playWholeSeason(winCount: 6)
        let firstSeason = try! #require(manager.season)

        manager.startNewSeason(userTeam: userTeam)
        let secondSeason = try! #require(manager.season)

        #expect(secondSeason.seasonNumber == firstSeason.seasonNumber + 1)
        #expect(secondSeason.userTeamID == userTeam.id)
        #expect(secondSeason.games.allSatisfy { !$0.isPlayed })
        #expect(secondSeason.standings.allSatisfy { $0.gamesPlayed == 0 })
        #expect(secondSeason.bracket == nil)
        #expect(secondSeason.phase == .regularSeason)
        #expect(secondSeason.currentGame?.week == 1)
        // A fresh schedule: same opponents, potentially different order.
        #expect(Set(secondSeason.games.map(\.opponentID)) == Set(OpponentTeams.all.map(\.id)))
    }
}
