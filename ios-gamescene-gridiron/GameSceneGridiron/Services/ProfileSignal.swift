import Foundation

/// A typed, auditable piece of prose, not a keyword guessed from a clue.
/// The exact phrase must be present in the displayed text and agree with the
/// authoritative solution. Two variants per tier = eight per profile.
nonisolated struct ProfileSignal: Hashable, Sendable {
    let profile: PlayerProfile
    let tier: DifficultyLevel
    let variant: Int
    var phrase: String { ProfileDialect.phrases(profile, tier: tier)[variant] }
}

nonisolated enum ProfileDialect {
    static func phrases(_ profile: PlayerProfile, tier: DifficultyLevel) -> [String] {
        let lines: [String] = switch profile {
        case .rookie: [
            "A first-year player, still learning the adjustment, fits this assignment.",
            "The young, inexperienced jersey is developing with every rep.",
            "The newest arrival hesitates when the formation shifts.",
            "Raw promise shows, but the reads are still being learned.",
            "The playbook is newer to him than the uniform; the adjustment takes a beat.",
            "The staff is teaching the response that the older jerseys already know.",
            "His first camp ended weeks ago; this look has not yet become instinct.",
            "The correction arrives from the sideline before his recognition does. It is his first season."
        ]
        case .veteran: [
            "Years of experience let him recognize this look immediately.",
            "A seasoned player draws on a decade of reps here.",
            "He has seen this pressure for years and stays composed.",
            "Several seasons of film study explain why he is ready for the adjustment.",
            "He recalls the same disguise from seasons past before the snap arrives.",
            "The response comes from a library of old Sundays, not a new lesson.",
            "Before the motion ends, he recalls how this look unfolded three seasons ago.",
            "The disguise is new to the sideline, not to someone with his years on the field."
        ]
        case .fast: [
            "Pure speed and instant acceleration win this rep.",
            "His straight-line burst outruns everyone in pursuit.",
            "He closes the gap with recovery speed rather than a change of direction.",
            "The first few strides create a lead nobody can recover.",
            "A clean lane is enough: pursuit loses ground with every stride.",
            "Once both players straighten their paths, the separation only grows.",
            "The angle is even and neither changes course; the gap still closes in two strides.",
            "With the route reduced to a footrace, the trailing jersey cannot hold the distance."
        ]
        case .powerful: [
            "Pure strength anchors him against the bull rush.",
            "Physical force lets him hold ground against the heaviest contact.",
            "He absorbs the rush without giving ground, winning through strength.",
            "Contact stalls against him; his force moves the other player instead.",
            "The collision arrives square, yet his base never gives an inch.",
            "With no room for finesse, he moves the contest through sheer force.",
            "Both reach contact evenly; only the other jersey travels backward.",
            "The push gathers bodies, but the point beneath his feet does not move."
        ]
        case .overrated: [
            "The reputation is bigger than the performance on tape.",
            "The headlines promise more than his execution delivers.",
            "The big name keeps its billing, but the recent reps do not earn it.",
            "His highlight reel is famous; today's ordinary assignments go unfinished.",
            "The scouting praise survives another rep that fails to support it.",
            "The press box remembers the name more fondly than the film room does.",
            "The introduction draws attention; the reviewed snaps never justify it.",
            "His billing rises while the evidence on the cut-up keeps falling short."
        ]
        case .underrated: [
            "Overlooked and rarely credited, he produces more than his reputation suggests.",
            "His tape is better than the quiet reputation surrounding him.",
            "The productive reps pile up without his name making the headlines.",
            "He does effective work that the scouting chatter keeps overlooking.",
            "The film room keeps finding his contribution where the awards list finds none.",
            "The opponent accounts for him more carefully than the press does.",
            "His name is absent from the preview, but present on every decisive cut-up.",
            "The billing is modest; the evidence keeps exceeding it."
        ]
        case .elusive: [
            "He changes direction and makes defenders miss clean contact.",
            "Slippery cuts let him escape the defender trying to square him up.",
            "He wins with a second cut, not a straight-line footrace.",
            "The defender reaches the spot; his change of direction leaves only air to grab.",
            "The pursuit angle is correct until his hips send the rep somewhere else.",
            "He carries momentum through a cut that leaves the tackler planted.",
            "The closing jersey arrives on time, but cannot square a shoulder to his next path.",
            "At the meeting point he changes the question; the hands close on empty space."
        ]
        case .reliable: [
            "Dependable and assignment-sound, he does the job every snap.",
            "Consistent execution makes him the player the staff trusts each down.",
            "His assignment is completed again, without a missed responsibility.",
            "The call changes; his dependable execution does not.",
            "The staff stops checking that responsibility because it is fulfilled on every rep.",
            "No spectacular play draws the eye, and no missed duty appears on the tape.",
            "Across the entire cut-up, that assignment has no unexplained vacancy.",
            "The checklist changes every down; his column remains complete."
        ]
        case .technical: [
            "Precise footwork and inside hand placement win through technique.",
            "He relies on mechanics and exact angles, not raw strength or speed.",
            "Each foot lands deliberately and his hands find the same inside target.",
            "He wins with polished form rather than the better physical tools.",
            "The advantage begins in the angle of his feet and the timing of his hands.",
            "The heavier jersey loses to a sequence of precise steps and well-placed hands.",
            "The rep is won before contact: balanced feet, inside hands, a perfectly arranged base.",
            "Neither size nor pace separates them; the decisive difference is the placement of a hand."
        ]
        }
        let offset: Int = switch tier {
        case .rookie: 0
        case .pro: 2
        case .allPro: 4
        case .hallOfFamer: 6
        }
        return Array(lines[offset..<(offset + 2)])
    }

    static func signal(profile: PlayerProfile, tier: DifficultyLevel, key: String) -> ProfileSignal {
        ProfileSignal(profile: profile, tier: tier, variant: Int(SeededGenerator.hash([key, profile.rawValue]) % 2))
    }

    static func addingSignal(to clue: CaseClue, profile: PlayerProfile, tier: DifficultyLevel, key: String) -> CaseClue {
        let signal = signal(profile: profile, tier: tier, key: key)
        var text = clue.text
        if let old = clue.profileSignal {
            text = text.replacingOccurrences(of: old.phrase, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return CaseClue(playerKey: clue.playerKey, family: clue.family, difficulty: clue.difficulty,
                        text: text + " " + signal.phrase, constraints: clue.constraints,
                        evidenceKeys: clue.evidenceKeys, profileSignal: signal)
    }

    /// Independent validator: deleting/changing the displayed phrase, profile
    /// metadata, or owning player fails. No credit for arbitrary keyword hits.
    static func failures(in puzzle: QuarterCase) -> [String] {
        puzzle.missing.compactMap { player in
            guard let answer = puzzle.solution.first(where: { $0.playerKey == player.key }) else {
                return "\(puzzle.id)/\(player.key): missing answer"
            }
            let clues = puzzle.clues.filter { $0.playerKey == player.key }
            let supported = clues.contains { clue in
                guard let signal = clue.profileSignal, (0..<2).contains(signal.variant) else { return false }
                return signal.profile == answer.profile && clue.text.contains(signal.phrase)
            }
            let contradiction = clues.contains { clue in
                guard let signal = clue.profileSignal else { return false }
                return signal.profile != answer.profile
            }
            return supported && !contradiction ? nil : "\(puzzle.id)/\(player.key): missing or contradictory profile signal"
        }
    }
}
