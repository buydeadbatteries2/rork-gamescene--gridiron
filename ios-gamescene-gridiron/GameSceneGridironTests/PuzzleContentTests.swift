import CoreGraphics
import Foundation
import Testing
@testable import GameSceneGridiron

/// Validates the controlled 20-body player-art library and the per-quarter
/// uniqueness contract: every quarter is its own investigation with its own
/// players, clues, hints, evidence layout and solution.
struct PlayerAssetAndPuzzleUniquenessTests {

    private static var allPuzzles: [QuarterPuzzle] {
        MatchPuzzles.regulation + [MatchPuzzles.overtime]
    }

    // MARK: Controlled art library

    @Test func controlledLibraryHasExactlyTwentyBodies() {
        #expect(PlayerBodyCatalog.all.count == 20)
        #expect(Set(PlayerBodyCatalog.all.map(\.id)).count == 20)

        // Distribution: 2 QB, 2 RB, 3 WR, 2 TE, 3 OL, 3 DL, 2 LB, 3 DB.
        let counts = Dictionary(grouping: PlayerBodyCatalog.all, by: \.position).mapValues(\.count)
        #expect(counts[.qb] == 2)
        #expect(counts[.rb] == 2)
        #expect(counts[.wr] == 3)
        #expect(counts[.te] == 2)
        #expect(counts[.ol] == 3)
        #expect(counts[.dl] == 3)
        #expect(counts[.lb] == 2)
        #expect(counts[.cb] == 3) // shared defensive-back pool covers CB/SS/FS
    }

    @Test func bodyAssetMappingCoversAllPositionsAndProfiles() {
        for position in FootballPosition.allCases {
            for variant in PlayerVariant.allCases {
                let asset = PlayerBodyCatalog.bodyAsset(for: position, variant: variant)
                #expect(PlayerBodyCatalog.contains(asset), "\(position)/\(variant) mapped outside the library")
            }
            #expect(PlayerBodyCatalog.contains(PlayerBodyCatalog.bodyAsset(for: position)))
        }
    }

    @Test func everyMissingPlayerUsesTheControlledLibrary() {
        for puzzle in Self.allPuzzles {
            for player in puzzle.missingPlayers {
                #expect(
                    PlayerBodyCatalog.contains(player.cardAsset),
                    "\(puzzle.id)/\(player.id) uses non-library asset \(player.cardAsset)"
                )
            }
        }
    }

    // MARK: Quarter uniqueness

    @Test func eachQuarterIsAUniqueInvestigation() {
        let puzzles = Self.allPuzzles

        func normalize(_ text: String) -> String {
            text.lowercased()
                .filter { $0.isLetter || $0.isNumber || $0 == " " }
                .split(separator: " ")
                .joined(separator: " ")
        }

        var clueTexts: [String: String] = [:]
        var hintTexts: [String: String] = [:]
        for puzzle in puzzles {
            #expect(puzzle.hints.count >= 3, "\(puzzle.id) needs at least 3 unique hints")

            for clue in puzzle.clues {
                let key = normalize(clue.text)
                #expect(clueTexts[key] == nil, "Clue text shared between \(clueTexts[key] ?? "?") and \(puzzle.id)")
                clueTexts[key] = puzzle.id
            }
            for hint in puzzle.hints {
                let key = normalize(hint.text)
                #expect(hintTexts[key] == nil, "Hint text shared between \(hintTexts[key] ?? "?") and \(puzzle.id)")
                hintTexts[key] = puzzle.id
            }
        }

        // The missing-player position combination must change quarter to quarter.
        let compositions = puzzles.map { puzzle in
            puzzle.missingPlayers.map(\.position.rawValue).sorted().joined(separator: ",")
        }
        #expect(Set(compositions).count == compositions.count, "Two quarters use the same position combination: \(compositions)")

        // Evidence layouts differ as well — no two quarters share the same map.
        let evidenceLayouts = puzzles.map { puzzle in
            puzzle.evidence.map { "\($0.kind)-\($0.x)-\($0.y)" }.sorted().joined(separator: "|")
        }
        #expect(Set(evidenceLayouts).count == evidenceLayouts.count, "Two quarters reuse the same evidence layout")

        // Names vary naturally: last names stay unique across the whole set,
        // and every name renders in first-initial + last-name style.
        let lastNames = puzzles.flatMap { puzzle in
            puzzle.missingPlayers.map { $0.name.split(separator: " ").last.map(String.init) ?? "" }
        }
        #expect(Set(lastNames).count == lastNames.count, "Duplicate last names: \(lastNames)")

        for puzzle in puzzles {
            for player in puzzle.missingPlayers {
                #expect(player.shortName.contains(". "), "\(player.name) is not initial+last style")
            }
        }
    }

    // MARK: Hint isolation

    @Test @MainActor func hintProgressionIsIsolatedPerQuarter() {
        // Hints now live in the persistent wallet: a new quarter continues
        // the same balance instead of resetting to the puzzle's starting hints.
        let wallet = PlayerWallet(defaults: UserDefaults(suiteName: "hints-\(UUID().uuidString)")!)
        wallet.addHints(5)

        // Using a hint inside Q1 only ever surfaces a Q1 hint.
        let q1 = GameViewModel(puzzle: MatchPuzzles.regulation[0], wallet: wallet)
        #expect(q1.canUseHint)
        q1.useHint()
        #expect(!q1.usedHints.isEmpty)
        let q1HintTexts = Set(MatchPuzzles.regulation[0].hints.map(\.text))
        #expect(q1.usedHints.allSatisfy { q1HintTexts.contains($0.text) })

        // Starting the next quarter resets the used-hint sequence but keeps
        // the wallet balance — hints persist across quarters.
        let balanceAfterQ1 = wallet.hints
        let q2 = GameViewModel(puzzle: MatchPuzzles.regulation[1], wallet: wallet)
        #expect(q2.usedHints.isEmpty)
        #expect(q2.hintsRemaining == balanceAfterQ1)
        q2.useHint()
        #expect(wallet.hints == balanceAfterQ1 - 1)
        let q2HintTexts = Set(MatchPuzzles.regulation[1].hints.map(\.text))
        #expect(q2.usedHints.allSatisfy { q2HintTexts.contains($0.text) })

        // And that first Q2 hint genuinely belongs to Q2's puzzle data.
        let otherQuarterHints = Set(
            (MatchPuzzles.regulation.dropFirst(2) + [MatchPuzzles.overtime]).flatMap(\.hints).map(\.text)
        )
        #expect(q2.usedHints.allSatisfy { !otherQuarterHints.contains($0.text) })
    }
}
