import Foundation
import Testing
@testable import GameSceneGridiron

/// Validates the persistent franchise roster: shape, deterministic identity,
/// the roster→puzzle identity mapping, stat awards from solved cases, the
/// game leaders / Player of the Game selection, season rolling, records and
/// dynasty history.
@MainActor
struct FranchiseRosterTests {

    // MARK: Helpers

    private func makeManager() -> RosterManager {
        let suiteName = "franchise-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return RosterManager(defaults: defaults)
    }

    private func makeTeam() -> GameTeam {
        GameTeam(
            state: "Virginia",
            teamName: "Cyber Wolves",
            logoID: "shield",
            primaryColorHex: 0x1A1A1A,
            secondaryColorHex: 0xD9B56E,
            isUserTeam: true
        )
    }

    private func makeManagerWithRoster() -> (RosterManager, GameTeam) {
        let manager = makeManager()
        let team = makeTeam()
        manager.ensureRoster(for: team)
        return (manager, team)
    }

    // MARK: Roster shape

    @Test func rosterHasTwelvePlayersSixPerSide() {
        let (manager, _) = makeManagerWithRoster()
        let franchise = manager.franchise

        guard let franchise else {
            Issue.record("franchise was not created")
            return
        }

        #expect(franchise.allPlayers.count == 12)
        #expect(franchise.players(on: .offense).count == 6)
        #expect(franchise.players(on: .defense).count == 6)
        #expect(Set(franchise.allPlayers.map(\.slot)) == Set(RosterSlot.allCases))

        let requiredOffense: [RosterSlot] = [.qb, .rb, .wr1, .wr2, .te, .ol]
        let requiredDefense: [RosterSlot] = [.de, .dt, .lb, .cb, .fs, .ss]
        let slots = Set(franchise.allPlayers.map(\.slot))
        #expect(requiredOffense.allSatisfy { slots.contains($0) })
        #expect(requiredDefense.allSatisfy { slots.contains($0) })

        // Names use "F. Last" display format; all controlled-library bodies.
        for player in franchise.allPlayers {
            #expect(player.displayName.contains(". "))
            #expect(PlayerBodyCatalog.contains(player.bodyAssetID))
        }
        #expect(Set(franchise.allPlayers.map(\.lastName)).count == 12)
    }

    @Test func rosterIsDeterministicAndPersists() {
        let suiteName = "franchise-determinism-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let team = makeTeam()

        let first = RosterManager(defaults: defaults)
        first.ensureRoster(for: team)
        let firstNames = first.franchise?.allPlayers.map(\.fullName) ?? []
        let firstIDs = first.franchise?.allPlayers.map(\.id) ?? []

        // A fresh manager over the same storage must reproduce the same roster.
        let second = RosterManager(defaults: defaults)
        #expect(second.franchise?.allPlayers.map(\.fullName) == firstNames)
        #expect(second.franchise?.allPlayers.map(\.id) == firstIDs)
        #expect(second.franchise?.teamID == team.id)

        // Re-confirming the same team never regenerates the roster.
        second.ensureRoster(for: team)
        #expect(second.franchise?.allPlayers.map(\.id) == firstIDs)
    }

    // MARK: Identity assignment

    @Test func identityAssignmentUsesRosterMembersByPosition() {
        let (manager, _) = makeManagerWithRoster()
        let franchise = manager.franchise!

        // case_final_drive_empty_01 requires qb, wr1, wr2, de, cb.
        let map = manager.identityAssignments(forCaseID: "case_final_drive_empty_01")
        #expect(map.count == 5)

        let playersByID = Dictionary(uniqueKeysWithValues: franchise.allPlayers.map { ($0.id, $0) })
        let wrIdentities = map.values.filter { $0.position == .wr }.map(\.franchisePlayerID)
        #expect(Set(wrIdentities).count == 2, "both WR slots must map to the two distinct franchise receivers")

        for (_, identity) in map {
            let player = playersByID[identity.franchisePlayerID]
            #expect(player != nil)
            #expect(player?.position == identity.position)
            #expect(identity.shortName.contains(". "))
            #expect(PlayerBodyCatalog.contains(identity.bodyAssetID))
        }

        // Both WR identities must be the roster's actual WR slots.
        let rosterWRIDs = Set(franchise.allPlayers.filter { $0.slot == .wr1 || $0.slot == .wr2 }.map(\.id))
        #expect(Set(wrIdentities) == rosterWRIDs)

        // The DE slot identity must be the roster's DE.
        let deIdentity = map.values.first { $0.position == .dl }
        let rosterDEID = franchise.allPlayers.first { $0.slot == .de }?.id
        #expect(deIdentity?.franchisePlayerID == rosterDEID)
    }

    @Test func duplicatePositionBeyondRosterDepthStaysFictional() {
        let (manager, _) = makeManagerWithRoster()
        let franchise = manager.franchise!

        // The roster carries exactly one CB; a third CB demand stays unmapped.
        let map = RosterManager.identityAssignments(
            missing: [("cb1", .cb), ("cb2", .cb), ("cb3", .cb)],
            players: franchise.allPlayers,
            caseID: "case_test"
        )
        #expect(map.count == 1)
        #expect(map["case_test-cb2"] == nil)
        #expect(map["case_test-cb3"] == nil)

        // Two WR demands resolve to both receivers.
        let wrMap = RosterManager.identityAssignments(
            missing: [("wr1", .wr), ("wr2", .wr)],
            players: franchise.allPlayers,
            caseID: "case_test"
        )
        #expect(wrMap.count == 2)
        #expect(wrMap.values.map(\.franchisePlayerID).count == 2)
    }

    @Test func puzzleConversionAppliesRosterIdentities() {
        let (manager, _) = makeManagerWithRoster()
        let franchise = manager.franchise!

        guard let puzzleCase = CaseLibrary.caseByID("case_final_drive_empty_01") else {
            Issue.record("library case missing")
            return
        }

        let map = manager.identityAssignments(forCaseID: "case_final_drive_empty_01")
        let puzzle = CaseLibrary.puzzle(for: puzzleCase, quarterIndex: 0).withRosterIdentities(map)

        #expect(puzzle.isWellFormed)
        #expect(puzzle.solutions.count == puzzleCase.solution.count)

        let namesByID = Dictionary(uniqueKeysWithValues: map.values.map { ($0.franchisePlayerID, $0.fullName) })
        let rosterNames = Set(franchise.allPlayers.map(\.fullName))
        var renamed = 0
        for player in puzzle.missingPlayers {
            if let identity = map[player.id] {
                #expect(player.name == identity.fullName)
                #expect(rosterNames.contains(player.name))
                #expect(PlayerBodyCatalog.contains(player.cardAsset))
                renamed += 1
            } else {
                #expect(!namesByID.values.contains(player.name))
            }
        }
        #expect(renamed == 5)

        // Clues, slots and solutions are untouched by identity mapping.
        #expect(puzzle.clues.count == puzzleCase.clues.count)
        #expect(puzzle.slots.count == puzzleCase.slots.count)
        #expect(puzzle.missingPlayers.count == puzzleCase.missing.count)
    }

    // MARK: Stat award engine

    private func makeIdentity(_ franchise: Franchise, slot: RosterSlot) -> RosterIdentity? {
        guard let player = franchise.allPlayers.first(where: { $0.slot == slot }) else { return nil }
        return RosterIdentity(
            franchisePlayerID: player.id,
            fullName: player.fullName,
            shortName: player.displayName,
            position: player.position,
            bodyAssetID: player.bodyAssetID
        )
    }

    @Test func statEngineAwardsByVariant() {
        let (manager, _) = makeManagerWithRoster()
        let franchise = manager.franchise!
        let rb = makeIdentity(franchise, slot: .rb)
        let cb = makeIdentity(franchise, slot: .cb)
        let qb = makeIdentity(franchise, slot: .qb)

        guard let rb, let cb, let qb else {
            Issue.record("roster identities missing")
            return
        }

        func puzzlePlayer(_ identity: RosterIdentity) -> FootballPlayer {
            FootballPlayer(id: "p-\(identity.franchisePlayerID.uuidString)", name: identity.fullName, position: identity.position, cardAsset: identity.bodyAssetID)
        }

        // Same RB, three different situations → three different stat shapes.
        let fastRB = StatAwardEngine.events(
            from: [PlacedPlayer(player: puzzlePlayer(rb), variant: .fast, slot: PlacementSlot(id: "s1", x: 0.5, y: 0.5))],
            identities: ["p-\(rb.franchisePlayerID.uuidString)": rb]
        )
        #expect(fastRB.map(\.stat).sorted { $0.rawValue < $1.rawValue } == [.successfulRuns, .successfulRuns])

        let powerRB = StatAwardEngine.events(
            from: [PlacedPlayer(player: puzzlePlayer(rb), variant: .power, slot: PlacementSlot(id: "s1", x: 0.5, y: 0.5))],
            identities: ["p-\(rb.franchisePlayerID.uuidString)": rb]
        )
        #expect(Set(powerRB.map(\.stat)) == [.successfulRuns, .brokenTackles])

        let veteranRB = StatAwardEngine.events(
            from: [PlacedPlayer(player: puzzlePlayer(rb), variant: .veteran, slot: PlacementSlot(id: "s1", x: 0.5, y: 0.5))],
            identities: ["p-\(rb.franchisePlayerID.uuidString)": rb]
        )
        #expect(Set(veteranRB.map(\.stat)) == [.successfulRuns, .keyBlocks])

        // A Veteran CB coverage case earns an interception; a Fast QB read earns a scramble.
        let veteranCB = StatAwardEngine.events(
            from: [PlacedPlayer(player: puzzlePlayer(cb), variant: .veteran, slot: PlacementSlot(id: "s2", x: 0.4, y: 0.3))],
            identities: ["p-\(cb.franchisePlayerID.uuidString)": cb]
        )
        #expect(Set(veteranCB.map(\.stat)) == [.tackles, .interceptions])

        let fastQB = StatAwardEngine.events(
            from: [PlacedPlayer(player: puzzlePlayer(qb), variant: .fast, slot: PlacementSlot(id: "s3", x: 0.5, y: 0.6))],
            identities: ["p-\(qb.franchisePlayerID.uuidString)": qb]
        )
        #expect(Set(fastQB.map(\.stat)) == [.successfulReads, .scrambleOpportunities])
    }

    @Test func statEngineIgnoresPlayersWithoutRosterIdentity() {
        let placements = [
            PlacedPlayer(
                player: FootballPlayer(id: "unknown", name: "Milo Mudd", position: .lb, cardAsset: "football_player_linebacker"),
                variant: .fast,
                slot: PlacementSlot(id: "s1", x: 0.5, y: 0.5)
            )
        ]
        #expect(StatAwardEngine.events(from: placements, identities: [:]).isEmpty)
        #expect(StatAwardEngine.events(from: [], identities: ["unknown": RosterIdentity(franchisePlayerID: UUID(), fullName: "X Y", shortName: "X. Y", position: .lb, bodyAssetID: "football_player_linebacker")]).isEmpty)
    }

    @Test func playerOfTheGameIsHighestWeightedScore() {
        let cbID = UUID()
        let wrID = UUID()
        let events = [
            PlayerStatEvent(franchisePlayerID: cbID, playerName: "T. Brooks", position: .cb, stat: .tackles, count: 1),
            PlayerStatEvent(franchisePlayerID: cbID, playerName: "T. Brooks", position: .cb, stat: .interceptions, count: 2),
            PlayerStatEvent(franchisePlayerID: wrID, playerName: "D. Ellis", position: .wr, stat: .receptions, count: 3)
        ]
        #expect(StatAwardEngine.playerOfTheGameID(from: events) == cbID)

        let leaders = StatAwardEngine.leaderBoard(from: events)
        #expect(leaders.count == 2)
        #expect(leaders.first?.id == cbID)
        #expect(leaders[0].score > leaders[1].score)
    }

    // MARK: Recording games

    @Test func recordGameAppliesStatsLogsAndPOG() {
        let (manager, _) = makeManagerWithRoster()
        let franchise = manager.franchise!
        let rb = franchise.allPlayers.first { $0.slot == .rb }!
        let cb = franchise.allPlayers.first { $0.slot == .cb }!

        let events = [
            PlayerStatEvent(franchisePlayerID: rb.id, playerName: rb.displayName, position: .rb, stat: .successfulRuns, count: 2),
            PlayerStatEvent(franchisePlayerID: rb.id, playerName: rb.displayName, position: .rb, stat: .brokenTackles, count: 1),
            PlayerStatEvent(franchisePlayerID: cb.id, playerName: cb.displayName, position: .cb, stat: .tackles, count: 3),
            PlayerStatEvent(franchisePlayerID: cb.id, playerName: cb.displayName, position: .cb, stat: .interceptions, count: 1)
        ]

        manager.recordGame(
            stage: .regularSeason,
            seasonNumber: 1,
            week: 3,
            opponentName: "Texas Outlaws",
            teamWon: true,
            events: events,
            appearedIDs: [rb.id, cb.id]
        )

        let updatedRB = manager.player(withID: rb.id)!
        let updatedCB = manager.player(withID: cb.id)!

        #expect(updatedRB.seasonStats.value(for: .successfulRuns) == 2)
        #expect(updatedRB.seasonStats.value(for: .brokenTackles) == 1)
        #expect(updatedRB.seasonStats.value(for: .gamesPlayed) == 1)
        #expect(updatedCB.seasonStats.value(for: .tackles) == 3)
        #expect(updatedCB.seasonStats.value(for: .gamesPlayed) == 1)

        // POG: CB's INT outweighs the RB's runs.
        #expect(updatedCB.seasonStats.value(for: .playerOfTheGame) == 1)
        #expect(updatedRB.seasonStats.value(for: .playerOfTheGame) == 0)

        #expect(updatedCB.gameLogs.count == 1)
        let log = updatedCB.gameLogs[0]
        #expect(log.weekLabel == "W3")
        #expect(log.opponentName == "Texas Outlaws")
        #expect(log.teamWon)
        #expect(log.wasPlayerOfGame)
        #expect(log.stats.value(for: .tackles) == 3)

        #expect(manager.franchise?.history.wins == 1)
        #expect(manager.franchise?.history.losses == 0)
        #expect(manager.franchise?.records.record(for: .tackles)?.value == 3)
        #expect(manager.franchise?.records.record(for: .tackles)?.holderName == cb.displayName)
    }

    @Test func gamesPlayedCountedOncePerGameNotPerQuarter() {
        let (manager, _) = makeManagerWithRoster()
        let lb = manager.franchise!.allPlayers.first { $0.slot == .lb }!

        // Appeared in every quarter of one game → still one game played.
        manager.recordGame(
            stage: .regularSeason,
            seasonNumber: 1,
            week: 1,
            opponentName: "Arizona Scorpions",
            teamWon: false,
            events: [],
            appearedIDs: [lb.id]
        )
        #expect(manager.player(withID: lb.id)!.seasonStats.value(for: .gamesPlayed) == 1)
        #expect(manager.franchise?.history.losses == 1)
    }

    @Test func recordsOnlyGrowAndKeepTheirSeason() {
        let (manager, _) = makeManagerWithRoster()
        let de = manager.franchise!.allPlayers.first { $0.slot == .de }!

        manager.recordGame(
            stage: .regularSeason, seasonNumber: 2, week: 1,
            opponentName: "Ohio Steel Boars", teamWon: true,
            events: [PlayerStatEvent(franchisePlayerID: de.id, playerName: de.displayName, position: .dl, stat: .sacks, count: 4)],
            appearedIDs: [de.id]
        )
        // Season 2 closes; season 3 starts from a fresh stat line.
        manager.completeSeason(finishedSeasonNumber: 2)
        manager.recordGame(
            stage: .regularSeason, seasonNumber: 3, week: 5,
            opponentName: "Nevada Thunder", teamWon: false,
            events: [PlayerStatEvent(franchisePlayerID: de.id, playerName: de.displayName, position: .dl, stat: .sacks, count: 2)],
            appearedIDs: [de.id]
        )

        let record = manager.franchise?.records.record(for: .sacks)
        #expect(record?.value == 4)
        #expect(record?.seasonNumber == 2)
    }

    @Test func historyCountersTrackPlayoffRuns() {
        let (manager, _) = makeManagerWithRoster()
        let player = manager.franchise!.allPlayers[0]

        // Regular win, then a semifinal win (berth + title-game appearance),
        // then the championship win (title).
        manager.recordGame(stage: .regularSeason, seasonNumber: 1, week: 1, opponentName: "A", teamWon: true, events: [], appearedIDs: [player.id])
        manager.recordGame(stage: .regularSeason, seasonNumber: 1, week: 2, opponentName: "B", teamWon: false, events: [], appearedIDs: [player.id])
        manager.recordGame(stage: .semifinal, seasonNumber: 1, week: 11, opponentName: "C", teamWon: true, events: [], appearedIDs: [player.id])
        manager.recordGame(stage: .championship, seasonNumber: 1, week: 12, opponentName: "D", teamWon: true, events: [], appearedIDs: [player.id])

        let history = manager.franchise!.history
        #expect(history.wins == 3)
        #expect(history.losses == 1)
        #expect(history.playoffAppearances == 1)
        #expect(history.championshipAppearances == 1)
        #expect(history.championshipsWon == 1)
    }

    // MARK: Season lifecycle

    @Test func seasonRollPreservesCareerAndResetsSeason() {
        let (manager, _) = makeManagerWithRoster()
        let rb = manager.franchise!.allPlayers.first { $0.slot == .rb }!
        let rosterIDs = manager.franchise!.allPlayers.map(\.id)
        let rosterNames = manager.franchise!.allPlayers.map(\.fullName)

        manager.recordGame(
            stage: .regularSeason, seasonNumber: 1, week: 1,
            opponentName: "Texas Outlaws", teamWon: true,
            events: [PlayerStatEvent(franchisePlayerID: rb.id, playerName: rb.displayName, position: .rb, stat: .successfulRuns, count: 3)],
            appearedIDs: [rb.id]
        )

        manager.completeSeason(finishedSeasonNumber: 1)

        let rolled = manager.player(withID: rb.id)!
        #expect(rolled.careerStats.value(for: .successfulRuns) == 3)
        #expect(rolled.careerStats.value(for: .gamesPlayed) == 1)
        #expect(rolled.seasonStats.value(for: .successfulRuns) == 0)
        #expect(rolled.seasonStats.value(for: .gamesPlayed) == 0)
        #expect(manager.franchise!.history.seasonsPlayed == 1)

        // The same 12 players stay with the franchise.
        #expect(manager.franchise!.allPlayers.map(\.id) == rosterIDs)
        #expect(manager.franchise!.allPlayers.map(\.fullName) == rosterNames)

        // A second season's stats stack onto career, season resets again.
        manager.recordGame(
            stage: .regularSeason, seasonNumber: 2, week: 1,
            opponentName: "Georgia Firebirds", teamWon: true,
            events: [PlayerStatEvent(franchisePlayerID: rb.id, playerName: rb.displayName, position: .rb, stat: .successfulRuns, count: 2)],
            appearedIDs: [rb.id]
        )
        manager.completeSeason(finishedSeasonNumber: 2)
        #expect(manager.player(withID: rb.id)!.careerStats.value(for: .successfulRuns) == 5)
        #expect(manager.franchise!.history.seasonsPlayed == 2)
    }

    @Test func careerStatsSurviveManagerRestart() {
        let suiteName = "franchise-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let team = makeTeam()

        let manager = RosterManager(defaults: defaults)
        manager.ensureRoster(for: team)
        let qb = manager.franchise!.allPlayers.first { $0.slot == .qb }!
        let qbID = qb.id
        manager.recordGame(
            stage: .regularSeason, seasonNumber: 1, week: 1,
            opponentName: "Texas Outlaws", teamWon: true,
            events: [PlayerStatEvent(franchisePlayerID: qb.id, playerName: qb.displayName, position: .qb, stat: .successfulReads, count: 2)],
            appearedIDs: [qb.id]
        )
        manager.completeSeason(finishedSeasonNumber: 1)

        // Reload from the same storage: everything preserved.
        let reloaded = RosterManager(defaults: defaults)
        let player = reloaded.player(withID: qbID)!
        #expect(player.careerStats.value(for: .successfulReads) == 2)
        #expect(player.gameLogs.count == 1)
        #expect(reloaded.franchise?.history.seasonsPlayed == 1)
    }
}
