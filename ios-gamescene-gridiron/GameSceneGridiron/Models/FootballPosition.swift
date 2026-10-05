import Foundation

/// Which side of the ball a player belongs to.
nonisolated enum TeamSide: String, Hashable, Sendable {
    case offense
    case defense
}

/// Football positions used by puzzles. Visible players may use line positions too.
nonisolated enum FootballPosition: String, Codable, Hashable, Sendable, CaseIterable {
    case qb = "QB"
    case rb = "RB"
    case wr = "WR"
    case te = "TE"
    case ol = "OL"
    case dl = "DL"
    case lb = "LB"
    case cb = "CB"
    case ss = "SS"
    case fs = "FS"

    var side: TeamSide {
        switch self {
        case .qb, .rb, .wr, .te, .ol: .offense
        case .dl, .lb, .cb, .ss, .fs: .defense
        }
    }

    var fullName: String {
        switch self {
        case .qb: "Quarterback"
        case .rb: "Running Back"
        case .wr: "Wide Receiver"
        case .te: "Tight End"
        case .ol: "Offensive Line"
        case .dl: "Defensive Line"
        case .lb: "Linebacker"
        case .cb: "Cornerback"
        case .ss: "Strong Safety"
        case .fs: "Free Safety"
        }
    }
}
