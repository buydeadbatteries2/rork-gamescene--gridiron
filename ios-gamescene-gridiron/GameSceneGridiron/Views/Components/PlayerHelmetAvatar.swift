import SwiftUI

// MARK: - Helmet identity system

/// Facemask personality per position group.
nonisolated enum FacemaskStyle {
    /// Sleek single bar — skill players and coverage backs.
    case single
    /// Balanced two-bar — hybrid bodies.
    case double
    /// Workman three-bar cage — interior line.
    case cage
    /// Heavy grill with vertical posts — trench aggression.
    case grill
}

/// Visual archetype for each position group. Proportions differ subtly — helmet
/// width, shoulder mass, facemask hardware, visor size and crown striping — so a
/// position reads at a glance without ever showing a face. Used by the simplified
/// field tokens; roster cards use realistic rendered portraits instead.
nonisolated enum HelmetArch {
    case leader   // QB  — clean, balanced, centered stripe
    case speed    // RB/WR — slim shell, twin speed stripes
    case hybrid   // TE  — strong but athletic, two-bar
    case lineman  // OL  — widest shell, full cage, matte
    case trench   // DL  — heavy grill, massive shoulders
    case hawk     // LB  — thick stripe, widened stance
    case cover    // CB/FS/SS — leanest shell, biggest visor

    init(position: FootballPosition) {
        switch position {
        case .qb: self = .leader
        case .rb, .wr: self = .speed
        case .te: self = .hybrid
        case .ol: self = .lineman
        case .dl: self = .trench
        case .lb: self = .hawk
        case .cb, .ss, .fs: self = .cover
        }
    }

    var helmetScale: CGFloat {
        switch self {
        case .leader: 1.0
        case .speed: 0.94
        case .hybrid: 1.03
        case .lineman: 1.08
        case .trench: 1.1
        case .hawk: 1.05
        case .cover: 0.92
        }
    }

    var shoulderScale: CGFloat {
        switch self {
        case .leader: 0.98
        case .speed: 0.9
        case .hybrid: 1.08
        case .lineman: 1.18
        case .trench: 1.2
        case .hawk: 1.12
        case .cover: 0.88
        }
    }

    var facemask: FacemaskStyle {
        switch self {
        case .leader, .speed, .cover: .single
        case .hybrid, .hawk: .double
        case .lineman: .cage
        case .trench: .grill
        }
    }

    var visorScale: CGFloat {
        switch self {
        case .cover: 1.12
        case .speed: 1.02
        case .leader, .hybrid, .hawk: 0.96
        case .lineman, .trench: 0.88
        }
    }

    /// 0 = matte crown, 1 = center stripe, 2 = twin speed stripes.
    var stripeCount: Int {
        switch self {
        case .leader, .hybrid, .hawk: 1
        case .speed: 2
        case .lineman, .trench, .cover: 0
        }
    }
}
