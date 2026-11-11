import Foundation

/// Presentation only: never changes the case's answer, placement or scoring.
nonisolated enum ProfileOptions {
    static func preferred(for position: FootballPosition) -> [PlayerProfile] {
        switch position {
        case .qb: [.veteran, .rookie, .reliable, .technical, .elusive, .underrated, .overrated]
        case .rb: [.fast, .powerful, .elusive, .reliable, .rookie, .veteran, .underrated, .overrated]
        case .wr: [.fast, .elusive, .reliable, .technical, .rookie, .veteran, .underrated, .overrated]
        case .te, .ol: [.powerful, .reliable, .technical, .veteran, .rookie, .underrated, .overrated]
        case .dl: [.powerful, .technical, .fast, .veteran, .rookie, .underrated, .overrated]
        case .lb: [.powerful, .fast, .reliable, .technical, .veteran, .rookie, .underrated, .overrated]
        case .cb: [.fast, .technical, .elusive, .reliable, .veteran, .rookie, .underrated, .overrated]
        case .fs, .ss: [.fast, .reliable, .technical, .veteran, .elusive, .rookie, .underrated, .overrated]
        }
    }

    /// First three specialties: 6 tickets; other suggested profiles: 3;
    /// unusual profiles: 1. No bans, including on the correct answer.
    static func weight(_ profile: PlayerProfile, for position: FootballPosition) -> Int {
        let pool = preferred(for: position)
        guard let index = pool.firstIndex(of: profile) else { return 1 }
        return index < 3 ? 6 : 3
    }

    static func choices(position: FootballPosition, correct: PlayerProfile, seed: UInt64) -> [PlayerProfile] {
        var rng = SeededGenerator(seed: seed)
        var remaining = PlayerProfile.allCases.filter { $0 != correct }
        var result = [correct]
        for _ in 0..<3 {
            let total = remaining.reduce(0) { $0 + weight($1, for: position) }
            var ticket = Int(rng.next() % UInt64(total))
            var selected = 0
            for index in remaining.indices {
                ticket -= weight(remaining[index], for: position)
                if ticket < 0 { selected = index; break }
            }
            result.append(remaining.remove(at: selected))
        }
        // The answer has no privileged chip location.
        for index in stride(from: result.count - 1, through: 1, by: -1) {
            result.swapAt(index, Int(rng.next() % UInt64(index + 1)))
        }
        return result
    }

    static func make(puzzle: QuarterPuzzle, session: String) -> [String: [PlayerProfile]] {
        var result: [String: [PlayerProfile]] = [:]
        var used: [FootballPosition: Set<Set<PlayerProfile>>] = [:]
        for player in puzzle.missingPlayers.sorted(by: { $0.id < $1.id }) {
            guard let correct = puzzle.solutions[player.id]?.profile else { continue }
            var options: [PlayerProfile] = []
            for attempt in 0..<64 {
                let seed = SeededGenerator.hash(["profile-options-v1", session, puzzle.id, player.id, String(attempt)])
                options = choices(position: player.position, correct: correct, seed: seed)
                if !used[player.position, default: []].contains(Set(options)) { break }
            }
            used[player.position, default: []].insert(Set(options))
            result[player.id] = options
        }
        return result
    }
}
