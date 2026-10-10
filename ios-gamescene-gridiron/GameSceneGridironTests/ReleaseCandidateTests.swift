import CoreGraphics
import Foundation
import Testing
@testable import GameSceneGridiron

/// Phase 9 release-candidate hardening: difficulty/progression balancing,
/// puzzle geometry fairness, stat-event metadata consistency, economy
/// double-claim protection and the local balance telemetry.
@MainActor
@Suite("ReleaseCandidateTests")
struct ReleaseCandidateTests {

    // MARK: Difficulty balancing (item 3)

    @Test("Season progression: 1–3 easier < 4–6 < 7–8 < 9–10 very hard")
    func weeklyProgressionBands() {
        for seasonNumber in 1...3 {
            func averageRating(weeks: ClosedRange<Int>) -> Double {
                let ratings = weeks.flatMap { week in
                    CaseScheduler.gameCaseIDs(seasonNumber: seasonNumber, week: week).regulation
                        .map { CaseDifficultyProfile(of: CaseLibrary.caseByID($0)!).rating }
                }
                return ratings.reduce(0, +) / Double(ratings.count)
            }

            let early = averageRating(weeks: 1...3)
            let mid = averageRating(weeks: 4...6)
            let late = averageRating(weeks: 7...8)
            let stretch = averageRating(weeks: 9...10)
            // The per-season ordering jitter (±0.04) makes adjacent weeks
            // near-ties at group boundaries — the ramp must hold within that
            // noise and be strictly ascending across the season.
            #expect(early <= mid + 0.02, "season \(seasonNumber): games 1–3 must not be harder than 4–6")
            #expect(mid <= late + 0.02, "season \(seasonNumber): games 4–6 must not be harder than 7–8")
            #expect(late <= stretch + 0.02, "season \(seasonNumber): games 7–8 must not be harder than 9–10")
            #expect(early < stretch, "season \(seasonNumber): the season must genuinely ramp up")
        }
    }

    @Test("Rookie never receives Hall-of-Famer-level cases at any stage")
    func rookieCeilingStaysApproachable() {
        for stage in SeasonStage.allCases {
            let target = DifficultyResolver.target(selected: .rookie, stage: stage)
            #expect(
                target.tier != .hallOfFamer && target.tier != .allPro,
                "rookie + \(stage.label) resolves to \(target.tier.rawValue) — too hard"
            )
            // Rookie structural knobs: no added decoys anywhere on the ramp.
            #expect(target.addedDecoys == 0, "rookie + \(stage.label) adds decoys")
        }

        // And every adapted rookie case keeps the rookie caps across the library.
        for puzzleCase in CaseLibrary.all {
            for stage in SeasonStage.allCases {
                let target = DifficultyResolver.target(selected: .rookie, stage: stage)
                let adapted = CaseDifficultyAdapter.adapt(puzzleCase, to: target)
                let decoys = adapted.slots.count - adapted.solution.count
                #expect(decoys <= 2, "\(puzzleCase.id)/\(stage.label): \(decoys) decoys")
                #expect(adapted.missing.count <= max(4, puzzleCase.missing.count), "\(puzzleCase.id)/\(stage.label)")
            }
        }
    }

    @Test("Hall of Famer is hard through deduction, never ambiguity")
    func hallOfFamerStaysUniqueAtTheCeiling() {
        for puzzleCase in CaseLibrary.all {
            let target = DifficultyResolver.target(selected: .hallOfFamer, stage: .championship)
            let adapted = CaseDifficultyAdapter.adapt(puzzleCase, to: target)
            #expect(CaseSolver.isUnique(adapted), "\(puzzleCase.id): HOF championship variant lost uniqueness")
        }
    }

    // MARK: Puzzle fairness — geometry (item 2)

    @Test("Slots and evidence stay in bounds and never overlap badly")
    func coordinatesStayInBoundsAndSeparate() {
        var failures: [String] = []
        let cases = CaseLibrary.all + [TrainingCase.authored]
        for puzzleCase in cases {
            for slot in puzzleCase.slots {
                if !(0...1).contains(slot.x) || !(0...1).contains(slot.y) {
                    failures.append("\(puzzleCase.id)/slot \(slot.key): out of bounds (\(slot.x), \(slot.y))")
                }
            }
            for item in puzzleCase.evidence {
                if !(0...1).contains(item.x) || !(0...1).contains(item.y) {
                    failures.append("\(puzzleCase.id)/evidence \(item.key): out of bounds")
                }
            }
            // No two placement targets may sit on top of each other — nearest-
            // target resolution must stay unambiguous for a human thumb.
            for (i, a) in puzzleCase.slots.enumerated() {
                for b in puzzleCase.slots[(i + 1)...] {
                    let distance = hypot(a.x - b.x, a.y - b.y)
                    if distance < 0.04 {
                        failures.append("\(puzzleCase.id): slots \(a.key)/\(b.key) overlap (Δ\(distance))")
                    }
                }
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    @Test("Stat-event metadata references real cases and players")
    func statEventMetadataIsConsistent() {
        var failures: [String] = []
        let casesByID = Dictionary(uniqueKeysWithValues: (CaseLibrary.all + [TrainingCase.authored]).map { ($0.id, $0) })
        for (caseID, events) in CaseStatEvents.table {
            guard let puzzleCase = casesByID[caseID] else {
                failures.append("stat table references unknown case \(caseID)")
                continue
            }
            let playerKeys = Set(puzzleCase.missing.map(\.key))
            for playerKey in events.keys where !playerKeys.contains(playerKey) {
                failures.append("\(caseID): stat event for unknown player \(playerKey)")
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    // MARK: Economy double-claim protection (items 9–10)

    @Test("Match rewards, doubles and Last Chance can never pay out twice")
    func economyRewardsAreIdempotent() {
        let wallet = PlayerWallet(defaults: UserDefaults(suiteName: "rc-economy.\(UUID().uuidString)")!)
        _ = wallet.addHints(3)

        // Same transaction id claimed twice credits once.
        #expect(wallet.earn(amount: 25, kind: .matchReward, transactionID: "tx-1"))
        let afterFirst = wallet.gameBalls
        #expect(!wallet.earn(amount: 25, kind: .matchReward, transactionID: "tx-1"))
        #expect(wallet.gameBalls == afterFirst)

        // A reward double requires the base claim and fires once.
        let breakdown = MatchRewardBreakdown(transactionID: "tx-2", lines: [], total: 20)
        #expect(wallet.claimMatchReward(breakdown))
        #expect(wallet.doubleMatchReward(breakdown))
        #expect(!wallet.doubleMatchReward(breakdown), "double reward paid twice")

        // One rewarded life per quarter, ever.
        #expect(wallet.markLastChanceUsed(for: "w3-q2"))
        #expect(!wallet.markLastChanceUsed(for: "w3-q2"))

        // An unaffordable hint purchase is atomic: nothing deducted, none granted.
        let brokeWallet = PlayerWallet(defaults: UserDefaults(suiteName: "rc-economy2.\(UUID().uuidString)")!)
        let hintsBefore = brokeWallet.hints
        #expect(!brokeWallet.buyHint())
        #expect(brokeWallet.hints == hintsBefore)
        #expect(brokeWallet.gameBalls == 0)
    }

    // MARK: Balance telemetry (item 19)

    @Test("Balance telemetry records locally and clears cleanly")
    func telemetryRecordsLocally() {
        let suite = UserDefaults(suiteName: "rc-telemetry.\(UUID().uuidString)")!
        let telemetry = BalanceTelemetry(defaults: suite)

        telemetry.recordWrongPlacement(caseID: "case_a")
        telemetry.recordWrongPlacement(caseID: "case_a")
        telemetry.recordHintUsed(caseID: "case_a")
        telemetry.recordQuarterFailure(caseID: "case_b", difficulty: "ROOKIE")

        // Persisted immediately, not only in memory.
        let reloaded = BalanceTelemetry(defaults: suite)
        #expect(reloaded.snapshot.cases["case_a"]?.wrongPlacements == 2)
        #expect(reloaded.snapshot.cases["case_a"]?.hintsUsed == 1)
        #expect(reloaded.snapshot.cases["case_b"]?.quarterFailures == 1)
        #expect(reloaded.snapshot.difficulty["case_b"] == "ROOKIE")

        reloaded.clear()
        #expect(BalanceTelemetry(defaults: suite).snapshot.cases.isEmpty)
    }
}
