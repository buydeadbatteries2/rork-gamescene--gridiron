import CoreGraphics
import Foundation
import Testing
@testable import GameSceneGridiron

/// Validates the local case library: shape, per-case uniqueness (via the
/// brute-force `CaseSolver`), evidence consistency, content variety and the
/// season scheduler's repeat-free guarantees.
struct CaseLibraryTests {

    private var library: [QuarterCase] { CaseLibrary.all }

    // MARK: Library shape

    @Test func libraryHasAtLeastFiftyUniqueCases() {
        #expect(library.count >= 50, "library must hold at least 50 case definitions")
        let ids = library.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate case ids present")
        #expect(ids.allSatisfy { $0.hasPrefix("case_") }, "case ids must use the case_ prefix")

        for band in 1...5 {
            let bandCases = library.filter { $0.band == band }
            #expect(bandCases.count == 10, "band \(band) should hold exactly 10 cases, found \(bandCases.count)")
        }
    }

    @Test func everyCaseIsWellFormed() {
        var failures: [String] = []
        for puzzleCase in library {
            let issues = wellFormedIssues(puzzleCase)
            if !issues.isEmpty {
                failures.append("\(puzzleCase.id): \(issues.joined(separator: "; "))")
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    private func wellFormedIssues(_ puzzleCase: QuarterCase) -> [String] {
        var issues: [String] = []

        let solutionPlayers = puzzleCase.solution.map(\.playerKey)
        if Set(solutionPlayers).count != solutionPlayers.count {
            issues.append("duplicate players in solution")
        }
        let solutionSlots = puzzleCase.solution.map(\.slotKey)
        if Set(solutionSlots).count != solutionSlots.count {
            issues.append("duplicate slots in solution")
        }
        for entry in puzzleCase.solution {
            if puzzleCase.player(withKey: entry.playerKey) == nil { issues.append("solution player \(entry.playerKey) missing") }
            if puzzleCase.slot(withKey: entry.slotKey) == nil { issues.append("solution slot \(entry.slotKey) missing") }
        }

        let cluePlayers = puzzleCase.clues.map(\.playerKey)
        let hintPlayers = puzzleCase.hints.map(\.playerKey)
        for player in puzzleCase.missing {
            let clueCount = cluePlayers.filter { $0 == player.key }.count
            if clueCount != 1 {
                issues.append("player \(player.key) has \(clueCount) clues, expected 1")
            }
            if !hintPlayers.contains(player.key) {
                issues.append("player \(player.key) has no hint")
            }
        }
        if puzzleCase.hints.count < 3 {
            issues.append("only \(puzzleCase.hints.count) hints, expected at least 3")
        }

        let evidenceCount = puzzleCase.evidence.count
        if evidenceCount < 3 || evidenceCount > 6 {
            issues.append("\(evidenceCount) evidence items, expected 3-6")
        }

        let difficulties = Set(puzzleCase.clues.map(\.difficulty))
        if !difficulties.contains(.easy) { issues.append("no easy clue") }
        if !difficulties.contains(.hard) { issues.append("no hard clue") }

        let families = Set(puzzleCase.clues.map(\.family))
        if families.count < 4 {
            issues.append("only \(families.count) clue families")
        }

        return issues
    }

    // MARK: Uniqueness

    @Test func everyCaseHasExactlyOneSolution() {
        var failures: [String] = []
        for puzzleCase in library {
            let diagnosis = CaseSolver.diagnose(puzzleCase)
            guard !diagnosis.isUnique else { continue }
            var detail = "solutions=\(diagnosis.totalSolutionCount)"
            detail += ", assignments=\(diagnosis.validAssignments)"
            if !diagnosis.intendedViolations.isEmpty {
                detail += ", intendedViolations=\(diagnosis.intendedViolations.joined(separator: " | "))"
            }
            let ambiguous = diagnosis.allowedVariants
                .filter { $0.value.count > 1 }
                .map { "\($0.key): \($0.value.map(\.rawValue).sorted().joined(separator: "/"))" }
            if !ambiguous.isEmpty {
                detail += ", ambiguousVariants=\(ambiguous.joined(separator: ","))"
            }
            if diagnosis.exampleAssignments.count > 1 {
                let alternate = diagnosis.exampleAssignments[1]
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key)→\($0.value)" }
                    .joined(separator: " ")
                detail += ", alternate=\(alternate)"
            }
            failures.append("\(puzzleCase.id) → \(detail)")
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    // MARK: Evidence consistency

    @Test func evidenceReferencesAreConsistent() {
        var failures: [String] = []
        for puzzleCase in library {
            let evidenceKeys = Set(puzzleCase.evidence.map(\.key))
            var referenced: Set<String> = []
            for clue in puzzleCase.clues {
                for key in clue.evidenceKeys {
                    referenced.insert(key)
                    guard let item = puzzleCase.evidence(withKey: key) else {
                        failures.append("\(puzzleCase.id)/clue(\(clue.playerKey)) references unknown evidence \(key)")
                        continue
                    }
                    let title = item.kind.title.lowercased()
                    if !clue.text.lowercased().contains(title) {
                        failures.append("\(puzzleCase.id)/clue(\(clue.playerKey)) does not mention \(item.kind.title)")
                    }
                }
            }
            let decorative = evidenceKeys.subtracting(referenced)
            if !decorative.isEmpty {
                failures.append("\(puzzleCase.id) has decorative evidence: \(decorative.sorted().joined(separator: ","))")
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    // MARK: Text variety

    @Test func noDuplicateClueOrHintTextAcrossLibrary() {
        var clueTexts: [String: String] = [:]
        var hintTexts: [String: String] = [:]
        var failures: [String] = []
        func normalize(_ text: String) -> String {
            text.lowercased()
                .filter { $0.isLetter || $0.isNumber || $0 == " " }
                .split(separator: " ")
                .joined(separator: " ")
        }
        for puzzleCase in library {
            for clue in puzzleCase.clues {
                let key = normalize(clue.text)
                if let first = clueTexts[key] {
                    failures.append("clue text duplicated: \(puzzleCase.id) and \(first)")
                } else {
                    clueTexts[key] = puzzleCase.id
                }
            }
            for hint in puzzleCase.hints {
                let key = normalize(hint.text)
                if let first = hintTexts[key] {
                    failures.append("hint text duplicated: \(puzzleCase.id) and \(first)")
                } else {
                    hintTexts[key] = puzzleCase.id
                }
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    // MARK: Content variety

    @Test func puzzleShapesVaryAcrossLibrary() {
        let missingCounts = Set(library.map(\.missing.count))
        #expect(missingCounts.contains(4), "library should include 4-missing cases")
        #expect(missingCounts.contains(5), "library should include 5-missing cases")
        #expect(missingCounts.contains(6), "library should include 6-missing cases")

        let combos = library.map { puzzleCase in
            puzzleCase.evidence.map(\.kind.rawValue).sorted().joined(separator: ",")
        }
        #expect(Set(combos).count == combos.count, "two cases share the same evidence combination")

        for band in 1...5 {
            let mixes = library.filter { $0.band == band }.map { puzzleCase in
                puzzleCase.missing.map(\.position.rawValue).sorted().joined(separator: ",")
            }
            #expect(Set(mixes).count == mixes.count, "band \(band) repeats a position mix")
        }

        let legacy: Set<EvidenceItem.Kind> = [.orangeTowel, .droppedGlove, .waterBottle, .muddyFootprints, .looseFootball]
        let stale = library.filter { puzzleCase in
            Set(puzzleCase.evidence.map(\.kind)).isSubset(of: legacy)
        }
        #expect(stale.isEmpty, "cases using only legacy evidence: \(stale.map(\.id).joined(separator: ","))")
    }

    @Test func profileAnswersVaryByPosition() {
        var byPosition: [FootballPosition: Set<PlayerVariant>] = [:]
        var counts: [FootballPosition: Int] = [:]
        for puzzleCase in library {
            for entry in puzzleCase.solution {
                guard let player = puzzleCase.player(withKey: entry.playerKey) else { continue }
                byPosition[player.position, default: []].insert(entry.variant)
                counts[player.position, default: 0] += 1
            }
        }
        var failures: [String] = []
        for position in FootballPosition.allCases {
            let variants = byPosition[position] ?? []
            let count = counts[position] ?? 0
            if count >= 3 && variants.count < 2 {
                failures.append("\(position.rawValue) is always \(variants.first?.rawValue ?? "?") across \(count) answers")
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    // MARK: Runtime conversion

    @Test func everyCaseConvertsToAValidPuzzle() {
        var failures: [String] = []
        for puzzleCase in library {
            let quarterIndex = min(puzzleCase.band - 1, 4)
            let puzzle = CaseLibrary.puzzle(for: puzzleCase, quarterIndex: quarterIndex)
            guard puzzle.isWellFormed else {
                failures.append("\(puzzleCase.id): puzzle not well formed")
                continue
            }
            if puzzle.missingPlayers.count != puzzleCase.missing.count {
                failures.append("\(puzzleCase.id): player count mismatch")
            }
            let names = puzzle.missingPlayers.map(\.name)
            if Set(names).count != names.count {
                failures.append("\(puzzleCase.id): duplicate roster names")
            }
            for player in puzzle.missingPlayers
            where !PlayerBodyCatalog.contains(player.cardAsset) {
                failures.append("\(puzzleCase.id): \(player.id) uses non-library asset \(player.cardAsset)")
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    // MARK: Scheduler

    @Test func schedulerProducesRepeatFreeSeasons() {
        var failures: [String] = []
        for seasonNumber in 1...3 {
            let schedule = CaseScheduler.seasonSchedule(seasonNumber: seasonNumber)
            if schedule.count != 40 {
                failures.append("season \(seasonNumber): schedule has \(schedule.count) ids")
            }
            if Set(schedule).count != schedule.count {
                failures.append("season \(seasonNumber): case repeated across the season")
            }
            for week in 1...10 {
                let game = CaseScheduler.gameCaseIDs(seasonNumber: seasonNumber, week: week)
                let regulation = game.regulation
                if Set(regulation).count != regulation.count {
                    failures.append("season \(seasonNumber) week \(week): repeated case inside the game")
                }
                if regulation.contains(game.overtime) {
                    failures.append("season \(seasonNumber) week \(week): overtime case repeats a regulation case")
                }
                for id in regulation + [game.overtime] {
                    if CaseLibrary.caseByID(id) == nil {
                        failures.append("season \(seasonNumber) week \(week): unknown case id \(id)")
                    }
                }
                for (quarter, id) in regulation.enumerated() {
                    if CaseLibrary.puzzle(id: id, quarterIndex: quarter) == nil {
                        failures.append("season \(seasonNumber) week \(week): \(id) does not resolve")
                    }
                }
                if CaseLibrary.puzzle(id: game.overtime, quarterIndex: 4) == nil {
                    failures.append("season \(seasonNumber) week \(week): OT \(game.overtime) does not resolve")
                }
            }
            let overtimeIDs = (1...10).map { CaseScheduler.overtimeCaseID(seasonNumber: seasonNumber, week: $0) }
            if Set(overtimeIDs).count != overtimeIDs.count {
                failures.append("season \(seasonNumber): overtime cases repeat")
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }
}
