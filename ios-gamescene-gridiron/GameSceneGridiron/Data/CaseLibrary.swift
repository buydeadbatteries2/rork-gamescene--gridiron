import Foundation

// MARK: - Roster name pool

/// Fictional roster names assigned deterministically per case, so a case file
/// always presents the same players. The stride-6 window scheme guarantees the
/// five cases inside any single game never share a name.
nonisolated enum CaseRoster {
    static let pool: [String] = [
        "Amos Delgado", "Bruno Vance", "Cato Brill", "Dov Marsh", "Eli Sandoval",
        "Finn Corrigan", "Gus Prather", "Hank Ostrander", "Ike Munoz", "Jae Parkin",
        "Kofi Adjei", "Lamar Ogden", "Miles Okoro", "Nico Peters", "Omar Siddiq",
        "Pete Lindholm", "Quincy Duke", "Ray Underhill", "Silas Bartok", "Tobias Fenn",
        "Ulysses Grantham", "Vic Sorrell", "Wade Kimura", "Xavi Tolbert", "Yuri Volkov",
        "Zack Mercer", "Andre Kingsley", "Bail Osei", "Cyrus Dunn", "Dev Okonkwo",
        "Emory Colton", "Felix Ibarra", "Grant Hollis", "Hugh Nakamura", "Ivan Bezdek",
        "Jonah Redmond", "Kai Brennan", "Lev Aronov", "Marek Dvorak", "Nate Farrow",
        "Otis Granger", "Paul Kimbrough", "Quinn Ashby", "Rocco Baldini", "Sam Ellery",
        "Tomas Vesely", "Ulric Tan", "Vince Barrow", "Wes Calloway", "Yusuf Kane",
        "Aaron Burke", "Bo Callahan", "Cecil Drummond", "Dante Rourke", "Erik Halvorsen",
        "Frank Moreau", "Glenn Ackerman", "Homer Willis", "Idris Toure", "Jett Carlson",
        "Kurt Weiss", "Leon Duffy", "Milo Franks", "Noel Girard", "Oscar Prewitt",
        "Perry Nkemdi", "Rex Hutchins", "Sean Lockhart", "Titus Weller", "Uri Fontaine",
        "Vaughn Malone", "Walt Jessup", "Xander Poe", "York Bellamy", "Zeke Traylor",
        "Asher Vaughn", "Buck Compton", "Cole Denning", "Dutch Rennick", "Ezra Lattimore",
        "Gideon Frost", "Harlan Boyd", "Irving Slauson", "Jasper Holt", "Kirby Stanek",
        "Lyle Odom", "Mason Trell", "Nolan Christie", "Orville Baines", "Percy Ellwood",
        "Quinton Harrell", "Roscoe Tandy", "Saul Bergman", "Terrell Bunkley", "Umberto Salas",
        "Vern Pascucci", "Wendell Haynes", "Xavier Cortez", "Yannick Sowa", "Zeph Turnage",
        "Alton Creech", "Bennie Suggs", "Cletus Warrick", "Dewey Ozburn", "Earnest Kilgore",
        "Floyd Pettis", "Garth Molina", "Hoyt Wilkes", "Irwin Pacheco", "Jules Boudreau",
        "Kelvin Osterman", "Lonnie Privett", "Mack Yarborough", "Norbert Egan", "Orvin Castleberry",
        "Prentice Moya", "Quentin Rasmussen", "Rudolph Banda", "Sherman Ochs", "Thurman Poole",
        "Vito Lambright", "Wilbur Choate", "Yosef Alvarado", "Zeb Kidder", "Ambrose Little",
        "Bertram Quill", "Clarence Mudd", "Denver Ryal", "Elmore Frick", "Festus Grubb",
        "Grover Kimbrel", "Hollis Danner", "Ignatz Pohl", "Junior Shavers", "Lucius Gatlin",
        "Melvin Oubre", "Norval Pinkston", "Odis Keeton", "Pinkney Rucker", "Ransom Eldridge",
        "Stacy Mullins", "Thad Pemberton", "Urbano Delacruz", "Vester Oneal", "Wilmer Koonce",
        "Yancy Prokop", "Zane Osterhout", "Bert Naccarato", "Coy Featherstone", "Dewitt Ozment"
    ]

    /// Deterministic names for one case: a consecutive window of the pool,
    /// offset by the case's roster seed. Never repeats inside a case and never
    /// collides with another case scheduled in the same game.
    static func names(forRosterSeed seed: Int, count: Int) -> [String] {
        (0..<count).map { pool[((seed * 6 + $0) % pool.count + pool.count) % pool.count] }
    }
}

// MARK: - Formation building

/// Accumulates the visible players of one case with auto-generated ids.
nonisolated struct FormationBuilder {
    private(set) var players: [FieldPlayer] = []
    private var count = 0

    mutating func add(_ position: FootballPosition, _ x: Double, _ y: Double) {
        players.append(FieldPlayer(id: "v\(count)", position: position, x: x, y: y))
        count += 1
    }

    /// Offensive line: five interior blockers on one depth line.
    mutating func line(_ xs: [Double], y: Double = 0.565) {
        for x in xs { add(.ol, x, y) }
    }

    /// Defensive front: down linemen on one depth line.
    mutating func front(_ xs: [Double], y: Double = 0.475) {
        for x in xs { add(.dl, x, y) }
    }
}

nonisolated enum Formation {
    /// Builds a case's visible-formation array.
    static func build(_ closure: (inout FormationBuilder) -> Void) -> [FieldPlayer] {
        var builder = FormationBuilder()
        closure(&builder)
        return builder.players
    }
}

// MARK: - Library

/// The local puzzle library: 50 validated case definitions across five quarter
/// bands (Q1–Q4 + overtime). Nothing here is generated at play time — every
/// case is authored, constraint-checked and converted to the runtime engine.
nonisolated enum CaseLibrary {
    static let all: [QuarterCase] =
        CasePack1.all + CasePack2.all + CasePack3.all + CasePack4.all + CasePack5.all

    /// All cases of one quarter band (1...5).
    static func band(_ band: Int) -> [QuarterCase] {
        all.filter { $0.band == band }
    }

    static func caseByID(_ id: String) -> QuarterCase? {
        all.first { $0.id == id }
    }

    /// The case's explicitly authored stat events: playerKey → the stat that
    /// occurred in this scenario. The player's profile never decides this —
    /// the case file does. Players without an entry fall back to the engine's
    /// position-neutral base stat.
    static func statEvents(forCaseID caseID: String) -> [String: PlayerStat] {
        CaseStatEvents.table[caseID] ?? [:]
    }

    // MARK: Authoring helper

    /// Compact authoring entry point used by the case packs. Tuple labels keep
    /// the definitions readable while the result is a fully keyed case model.
    static func makeCase(
        id: String,
        seed: Int,
        band: Int,
        title: String,
        heading: String,
        body: String,
        visible: [FieldPlayer],
        missing: [(key: String, position: FootballPosition)],
        evidence: [(key: String, kind: EvidenceItem.Kind, x: Double, y: Double, rotation: Double)],
        slots: [(key: String, x: Double, y: Double)],
        clues: [(player: String, family: ClueFamily, difficulty: ClueDifficulty, text: String, constraints: [CaseConstraint], evidence: [String])],
        hints: [(player: String, text: String)],
        solution: [(player: String, slot: String, variant: PlayerVariant)]
    ) -> QuarterCase {
        QuarterCase(
            id: id,
            band: band,
            rosterSeed: seed,
            title: title,
            introHeading: heading,
            introBody: body,
            visible: visible,
            missing: missing.map { CasePlayer(key: $0.key, position: $0.position) },
            evidence: evidence.map { CaseEvidence(key: $0.key, kind: $0.kind, x: $0.x, y: $0.y, rotation: $0.rotation) },
            slots: slots.map { CaseSlot(key: $0.key, x: $0.x, y: $0.y) },
            clues: clues.map {
                CaseClue(
                    playerKey: $0.player,
                    family: $0.family,
                    difficulty: $0.difficulty,
                    text: $0.text,
                    constraints: $0.constraints,
                    evidenceKeys: $0.evidence
                )
            },
            hints: hints.map { CaseHint(playerKey: $0.player, text: $0.text) },
            solution: solution.map { CaseSolution(playerKey: $0.player, slotKey: $0.slot, variant: $0.variant) }
        )
    }

    // MARK: Runtime conversion

    /// Converts an authored case into the runtime `QuarterPuzzle` the existing
    /// gameplay engine consumes. Gameplay never knows about cases.
    static func puzzle(for puzzleCase: QuarterCase, quarterIndex: Int) -> QuarterPuzzle {
        let labels = ["Q1", "Q2", "Q3", "Q4", "OT"]
        let names = CaseRoster.names(forRosterSeed: puzzleCase.rosterSeed, count: puzzleCase.missing.count)

        let missing: [FootballPlayer] = puzzleCase.missing.enumerated().map { index, entry in
            FootballPlayer(
                id: "\(puzzleCase.id)-\(entry.key)",
                name: names[index],
                position: entry.position,
                cardAsset: PlayerBodyCatalog.bodyAsset(for: entry.position)
            )
        }

        let evidence = puzzleCase.evidence.map {
            EvidenceItem(id: "\(puzzleCase.id)-e-\($0.key)", kind: $0.kind, x: $0.x, y: $0.y, rotation: $0.rotation)
        }

        let slots = puzzleCase.slots.map {
            PlacementSlot(id: "\(puzzleCase.id)-s-\($0.key)", x: $0.x, y: $0.y)
        }

        let clues: [PuzzleClue] = puzzleCase.clues.enumerated().map { index, clue in
            PuzzleClue(
                id: index + 1,
                text: clue.text,
                difficulty: clue.difficulty,
                playerID: "\(puzzleCase.id)-\(clue.playerKey)"
            )
        }

        let hints: [PuzzleHint] = puzzleCase.hints.map {
            PuzzleHint(id: "\(puzzleCase.id)-h-\($0.playerKey)", playerID: "\(puzzleCase.id)-\($0.playerKey)", text: $0.text)
        }

        var solutions: [String: PlacementSolution] = [:]
        for entry in puzzleCase.solution {
            solutions["\(puzzleCase.id)-\(entry.playerKey)"] = PlacementSolution(
                slotID: "\(puzzleCase.id)-s-\(entry.slotKey)",
                variant: entry.variant
            )
        }

        return QuarterPuzzle(
            id: puzzleCase.id,
            index: quarterIndex,
            quarterLabel: labels[min(max(quarterIndex, 0), labels.count - 1)],
            title: puzzleCase.title,
            introHeading: puzzleCase.introHeading,
            introBody: puzzleCase.introBody,
            startingLives: 3,
            startingHints: 3,
            visiblePlayers: puzzleCase.visible,
            missingPlayers: missing,
            evidence: evidence,
            slots: slots,
            clues: clues,
            hints: hints,
            solutions: solutions
        )
    }

    /// Convenience: resolve a scheduled case id into its runtime puzzle.
    static func puzzle(id: String, quarterIndex: Int) -> QuarterPuzzle? {
        caseByID(id).map { puzzle(for: $0, quarterIndex: quarterIndex) }
    }
}
