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
/// position reads at a glance without ever showing a face.
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

// MARK: - Avatar

/// Premium helmet-and-shoulders bust. Identity comes from helmet shape, facemask
/// hardware, dark visor, shoulder silhouette and jersey color — never a face.
struct PlayerHelmetAvatar: View {
    let position: FootballPosition
    var variant: PlayerVariant?
    var size: CGFloat = 72

    private var arch: HelmetArch { HelmetArch(position: position) }
    private var isOffense: Bool { position.side == .offense }
    private let s: CGFloat

    init(position: FootballPosition, variant: PlayerVariant? = nil, size: CGFloat = 72) {
        self.position = position
        self.variant = variant
        self.size = size
        self.s = size
    }

    /// FAST slims down and leans; POWER widens and settles; VETERAN stands composed.
    private var shoulderScale: CGFloat {
        var scale = arch.shoulderScale
        switch variant {
        case .fast: scale *= 0.9
        case .power: scale *= 1.12
        case .veteran, nil: break
        }
        return min(scale, 1.3)
    }

    private var stanceTilt: Double { variant == .fast ? -4 : 0 }
    private var helmetDrop: CGFloat { variant == .power ? s * 0.02 : 0 }

    private var shellDiameter: CGFloat { s * 0.6 * arch.helmetScale }

    var body: some View {
        ZStack {
            spotlight
            neck
            shoulders
            helmet
            facemask
            decals
        }
        .frame(width: s, height: s)
        .rotationEffect(.degrees(stanceTilt))
        .accessibilityHidden(true)
    }

    // MARK: Pieces

    private var spotlight: some View {
        RadialGradient(
            colors: [accent.opacity(0.22), .clear],
            center: UnitPoint(x: 0.5, y: 0.32),
            startRadius: 2,
            endRadius: s * 0.55
        )
        .frame(width: s, height: s)
    }

    private var neck: some View {
        Capsule()
            .fill(isOffense ? Color(hex: 0x1A160F) : Color(hex: 0xAEB6BD))
            .frame(width: s * (variant == .power ? 0.28 : 0.22), height: s * 0.2)
            .offset(y: s * 0.14 + helmetDrop)
    }

    private var shoulders: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: s * 0.16,
            bottomLeadingRadius: s * 0.05,
            bottomTrailingRadius: s * 0.05,
            topTrailingRadius: s * 0.16
        )
        .fill(jerseyGradient)
        .frame(width: s * 0.88 * shoulderScale, height: s * 0.32)
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: s * 0.16,
                bottomLeadingRadius: s * 0.05,
                bottomTrailingRadius: s * 0.05,
                topTrailingRadius: s * 0.16
            )
            .strokeBorder(accent.opacity(0.55), lineWidth: max(1, s * 0.018))
        }
        .offset(y: s * 0.33)
    }

    private var helmet: some View {
        let d = shellDiameter
        return Circle()
            .fill(shellGradient)
            .frame(width: d, height: d)
            .overlay {
                crownStripes(diameter: d)
                visor(diameter: d)
            }
            .clipShape(.circle)
            .overlay {
                Circle().strokeBorder(accent.opacity(0.85), lineWidth: max(1, s * 0.02))
            }
            .offset(y: -s * 0.09 + helmetDrop)
            .shadow(color: .black.opacity(0.5), radius: s * 0.04, y: s * 0.03)
    }

    private func crownStripes(diameter d: CGFloat) -> some View {
        Group {
            if arch.stripeCount == 1 {
                Capsule()
                    .fill(accent)
                    .frame(width: d * 0.1, height: d)
            } else if arch.stripeCount == 2 {
                HStack(spacing: d * 0.2) {
                    Capsule().fill(accent.opacity(0.85)).frame(width: d * 0.055, height: d)
                    Capsule().fill(accent.opacity(0.85)).frame(width: d * 0.055, height: d)
                }
            }
        }
        .opacity(arch.stripeCount == 0 ? 0 : 1)
    }

    private func visor(diameter d: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0x27303C), Color(hex: 0x0C0F13)], startPoint: .top, endPoint: .bottom))
                .frame(width: d * 0.66 * arch.visorScale, height: d * 0.3)
            Capsule()
                .fill(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center))
                .frame(width: d * 0.5 * arch.visorScale, height: d * 0.1)
                .offset(y: -d * 0.07)
        }
        .offset(y: d * 0.12)
    }

    /// Facemask hardware sits at the lower front and may poke past the shell edge.
    private var facemask: some View {
        let d = shellDiameter
        let barWidth = d * 0.72
        let barHeight = max(1.5, s * 0.032)
        let gap = barHeight * 1.05

        return ZStack {
            switch arch.facemask {
            case .single:
                bar(width: barWidth, height: barHeight)
            case .double:
                VStack(spacing: gap) {
                    bar(width: barWidth, height: barHeight)
                    bar(width: barWidth, height: barHeight)
                }
            case .cage:
                VStack(spacing: gap) {
                    bar(width: barWidth, height: barHeight)
                    bar(width: barWidth, height: barHeight)
                    bar(width: barWidth, height: barHeight)
                }
                .overlay {
                    Capsule()
                        .fill(facemaskColor)
                        .frame(width: barHeight * 0.9, height: barHeight * 2 + gap * 2)
                }
            case .grill:
                VStack(spacing: gap) {
                    bar(width: barWidth, height: barHeight * 1.35)
                    bar(width: barWidth, height: barHeight)
                }
                .overlay {
                    HStack(spacing: barWidth * 0.3) {
                        Capsule().fill(facemaskColor).frame(width: barHeight * 0.9, height: barHeight * 1.35 + gap)
                        Capsule().fill(facemaskColor).frame(width: barHeight * 0.9, height: barHeight * 1.35 + gap)
                    }
                }
            }
        }
        .offset(y: -s * 0.09 + helmetDrop + d * 0.36)
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        Capsule().fill(facemaskColor).frame(width: width, height: height)
    }

    /// VETERAN gets captain's bars on the side of the shell.
    private var decals: some View {
        Group {
            if variant == .veteran {
                VStack(spacing: s * 0.025) {
                    Capsule().fill(Theme.goldGradient).frame(width: s * 0.13, height: s * 0.035)
                    Capsule().fill(Theme.goldGradient).frame(width: s * 0.13, height: s * 0.035)
                }
                .rotationEffect(.degrees(-18))
                .offset(x: -shellDiameter * 0.36, y: -s * 0.16)
            }
        }
    }

    // MARK: Colors

    private var accent: Color { isOffense ? Theme.gold : Color(hex: 0x5C6E82) }
    private var facemaskColor: Color { isOffense ? Color(hex: 0xC9A25A) : Color(hex: 0x8B97A3) }

    private var shellGradient: LinearGradient {
        isOffense
            ? LinearGradient(colors: [Color(hex: 0x4A3F30), Color(hex: 0x0E0C09)], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [.white, Color(hex: 0x9FA6AD)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var jerseyGradient: LinearGradient {
        isOffense
            ? LinearGradient(colors: [Color(hex: 0x2A231A), Color(hex: 0x14110D)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color(hex: 0xF2F4F6), Color(hex: 0xC6CDD4)], startPoint: .top, endPoint: .bottom)
    }
}
