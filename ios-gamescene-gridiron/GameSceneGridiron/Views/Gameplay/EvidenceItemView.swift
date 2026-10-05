import SwiftUI

/// SwiftUI illustrations of the physical evidence left on the field, with a soft
/// gold halo backing so each object reads as a clue on the photoreal turf.
/// Covers the full 38-object evidence library; every object is fictional and
/// generic — no real-world brands anywhere.
struct EvidenceItemView: View {
    let kind: EvidenceItem.Kind
    var size: CGFloat = 26

    /// Field-damage marks lie flat on the turf — they get no contact shadow.
    private static let flatMarks: Set<EvidenceItem.Kind> = [
        .skidMarks, .tornTurf, .grassStain, .cleatMarks, .divot,
        .chalkMark, .wetPatch, .draggedFootTrail, .muddyFootprints
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.gold.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 1,
                        endRadius: size * 0.75
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)

            if !Self.flatMarks.contains(kind) {
                // Soft contact shadow so objects sit on the turf, not on it.
                Ellipse()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: size * 1.0, height: size * 0.26)
                    .blur(radius: 2.2)
                    .offset(y: size * 0.44)
            }

            Group {
                switch kind {
                case .orangeTowel: towel
                case .droppedGlove: glove
                case .waterBottle: bottle
                case .muddyFootprints: footprints
                case .looseFootball: football
                case .mouthguard: mouthguard
                case .wristPlaybook: wristPlaybook
                case .chinStrap: chinStrap
                case .brokenHelmetStrap: brokenStrap
                case .looseCleat: cleat
                case .kickingTee: kickingTee
                case .handWarmer: handWarmer
                case .shoulderPadStrap: padStrap
                case .kneeBrace: kneeBrace
                case .visorCloth: visorCloth
                case .tapeRoll: tapeRoll
                case .wristband: wristband
                case .sportsDrinkCup: drinkCup
                case .droppedPlayCard: playCard
                case .clipboard: clipboard
                case .laminatedPlaySheet: playSheet
                case .headset: headset
                case .challengeFlag: challengeFlag
                case .markerBoard: markerBoard
                case .whistle: whistle
                case .equipmentBag: equipmentBag
                case .orangeCone: cone
                case .pylon: pylon
                case .yardMarker: yardMarker
                case .chainMarker: chainMarker
                case .skidMarks: skidMarks
                case .tornTurf: tornTurf
                case .grassStain: grassStain
                case .cleatMarks: cleatMarks
                case .divot: divot
                case .chalkMark: chalkMark
                case .wetPatch: wetPatch
                case .draggedFootTrail: dragTrail
                }
            }
        }
        .frame(width: size * 1.3, height: size * 1.3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title)
    }

    // MARK: Core objects

    private var towel: some View {
        ZStack {
            // Base cloth with a soft cotton gradient.
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(hex: 0xFF9A42), Color(hex: 0xB84A0C)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 1.05, height: size * 0.72)
                .rotationEffect(.degrees(8))
            // Folded-over section.
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(hex: 0xF27A24), Color(hex: 0xD05A14)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.7, height: size * 0.5)
                .rotationEffect(.degrees(-14))
                .offset(x: size * 0.12, y: size * 0.08)
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.12))
                        .frame(width: size * 0.7, height: size * 0.12)
                        .offset(y: -size * 0.17)
                        .rotationEffect(.degrees(-14))
                }
            // Fold shadow creases.
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: size * 0.55, height: 1.2)
                    .offset(x: size * 0.05, y: CGFloat(i - 1) * size * 0.14)
                    .rotationEffect(.degrees(6))
            }
            // Frayed corner.
            Circle()
                .trim(from: 0.6, to: 0.9)
                .stroke(Color(hex: 0xE87A28), lineWidth: 1.2)
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: -size * 0.42, y: -size * 0.24)
        }
        .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 2)
    }

    private var glove: some View {
        Image(systemName: "hand.raised.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.78)
            .foregroundStyle(LinearGradient(colors: [Color(hex: 0xF4F1E8), Color(hex: 0xB9B3A5)], startPoint: .top, endPoint: .bottom))
            .overlay {
                Image(systemName: "hand.raised")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.78)
                    .foregroundStyle(Color(hex: 0x3A3A3A).opacity(0.6))
            }
            .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var bottle: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(hex: 0xEDEDED))
                .frame(width: size * 0.24, height: size * 0.16)
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0x7FC4F2), Color(hex: 0x2C7BC0)], startPoint: .leading, endPoint: .trailing))
                .frame(width: size * 0.42, height: size * 0.95)
                .overlay {
                    Capsule().fill(Color.white.opacity(0.35)).frame(width: size * 0.08).offset(x: -size * 0.09)
                }
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    /// Pressed cleat prints stamped into the turf: two staggered soles with
    /// toe cleats, reading as a short trail of footprints.
    private var footprints: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                cleatPrint
                    .offset(
                        x: CGFloat(i % 2) * size * 0.42 - size * 0.21,
                        y: CGFloat(i / 2) * size * 0.48 - size * 0.24
                    )
                    .rotationEffect(.degrees(i % 2 == 0 ? -14 : 12))
            }
        }
        .shadow(color: Color(hex: 0x2E1F10).opacity(0.6), radius: 1)
    }

    private var cleatPrint: some View {
        VStack(spacing: size * 0.025) {
            Ellipse()
                .fill(Color(hex: 0x4A341E).opacity(0.88))
                .frame(width: size * 0.2, height: size * 0.26)
            HStack(spacing: size * 0.035) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color(hex: 0x4A341E).opacity(0.8))
                        .frame(width: size * 0.055, height: size * 0.055)
                }
            }
        }
    }

    private var football: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: 0xA0582A), Color(hex: 0x5A2C12)], center: UnitPoint(x: 0.4, y: 0.35), startRadius: 1, endRadius: size * 0.5))
                .frame(width: size * 0.95, height: size * 0.56)
            // End stripes.
            ForEach([-0.28, 0.28], id: \.self) { x in
                Capsule()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 1.6, height: size * 0.4)
                    .offset(x: size * x)
            }
            Capsule().fill(Color.white.opacity(0.9)).frame(width: size * 0.36, height: 1.5)
            HStack(spacing: size * 0.06) {
                ForEach(0..<4, id: \.self) { _ in
                    Capsule().fill(Color.white.opacity(0.9)).frame(width: 1.3, height: size * 0.12)
                }
            }
            // Specular highlight.
            Ellipse()
                .fill(Color.white.opacity(0.18))
                .frame(width: size * 0.3, height: size * 0.12)
                .rotationEffect(.degrees(-18))
                .offset(x: -size * 0.18, y: -size * 0.13)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    // MARK: Equipment

    private var mouthguard: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0xFAFAFA), Color(hex: 0xCFCBC0)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.9, height: size * 0.4)
            HStack(spacing: size * 0.06) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule().fill(Color(hex: 0x8A867C)).frame(width: 1.4, height: size * 0.22)
                }
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var wristPlaybook: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(LinearGradient(colors: [Color(hex: 0x2B2B30), Color(hex: 0x17171B)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.95, height: size * 0.62)
            VStack(spacing: size * 0.07) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i == 1 ? Color(hex: 0xE8B23A) : Color.white.opacity(0.75))
                        .frame(width: i == 2 ? size * 0.3 : size * 0.6, height: 1.4)
                }
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var chinStrap: some View {
        ZStack {
            Capsule()
                .fill(Color(hex: 0x37404A))
                .frame(width: size * 0.78, height: size * 0.1)
                .rotationEffect(.degrees(-24))
                .offset(x: -size * 0.16, y: size * 0.12)
            Capsule()
                .fill(Color(hex: 0x37404A))
                .frame(width: size * 0.78, height: size * 0.1)
                .rotationEffect(.degrees(24))
                .offset(x: size * 0.16, y: size * 0.12)
            Circle()
                .fill(Color(hex: 0x9BA4AE))
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(y: size * 0.2)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var brokenStrap: some View {
        ZStack {
            Capsule()
                .fill(Color(hex: 0x37404A))
                .frame(width: size * 0.44, height: size * 0.1)
                .rotationEffect(.degrees(-18))
                .offset(x: -size * 0.24, y: size * 0.1)
            Capsule()
                .fill(Color(hex: 0x37404A))
                .frame(width: size * 0.44, height: size * 0.1)
                .rotationEffect(.degrees(18))
                .offset(x: size * 0.24, y: -size * 0.08)
            Capsule()
                .fill(Color(hex: 0xB8B2A6))
                .frame(width: size * 0.1, height: size * 0.05)
                .rotationEffect(.degrees(-18))
                .offset(x: -size * 0.05, y: size * 0.02)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var cleat: some View {
        ZStack {
            Capsule()
                .fill(Color(hex: 0x23242A))
                .frame(width: size * 1.0, height: size * 0.22)
                .offset(y: size * 0.16)
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(LinearGradient(colors: [Color(hex: 0xEDEAE2), Color(hex: 0xC9C4B6)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.82, height: size * 0.42)
                .rotationEffect(.degrees(-6))
                .offset(x: size * 0.03, y: -size * 0.04)
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(Color(hex: 0x4A4E55))
                    .frame(width: size * 0.07, height: size * 0.07)
                    .offset(x: CGFloat(i - 2) * size * 0.18, y: size * 0.28)
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var kickingTee: some View {
        ZStack {
            Image(systemName: "arrowtriangle.down.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.62, height: size * 0.5)
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFF8A2A), Color(hex: 0xC4520E)], startPoint: .top, endPoint: .bottom))
            Capsule()
                .fill(Color(hex: 0x8A3A08))
                .frame(width: size * 0.8, height: size * 0.12)
                .offset(y: size * 0.26)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var handWarmer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(hex: 0x39424C), Color(hex: 0x1E242B)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.66, height: size * 0.95)
            Capsule()
                .fill(Color(hex: 0xE8B23A).opacity(0.85))
                .frame(width: size * 0.34, height: size * 0.1)
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: size * 0.4, height: 1.2)
                    .offset(y: CGFloat(i + 1) * size * 0.18)
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var padStrap: some View {
        ZStack {
            Capsule()
                .fill(Color(hex: 0x6B7280))
                .frame(width: size * 0.95, height: size * 0.12)
                .rotationEffect(.degrees(38))
            Capsule()
                .fill(Color(hex: 0x525A66))
                .frame(width: size * 0.95, height: size * 0.12)
                .rotationEffect(.degrees(-38))
            Circle()
                .fill(Color(hex: 0xD5DAE0))
                .frame(width: size * 0.16, height: size * 0.16)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var kneeBrace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(hex: 0xF2F2F2), Color(hex: 0xC9CCD1)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.5, height: size * 0.95)
            Circle()
                .stroke(Color(hex: 0x3A3E45), lineWidth: size * 0.06)
                .frame(width: size * 0.2, height: size * 0.2)
            Circle()
                .stroke(Color(hex: 0x3A3E45), lineWidth: size * 0.06)
                .frame(width: size * 0.2, height: size * 0.2)
                .offset(y: size * 0.3)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var visorCloth: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: 0x23262E), Color(hex: 0x111318)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.66, height: size * 0.66)
                .rotationEffect(.degrees(45))
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(width: size * 0.62, height: 1.4)
                .rotationEffect(.degrees(45))
                .offset(x: -size * 0.08, y: size * 0.08)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var tapeRoll: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xEDEDE6))
                .frame(width: size * 0.78, height: size * 0.78)
            Circle()
                .fill(Color(hex: 0xB9B5AA))
                .frame(width: size * 0.32, height: size * 0.32)
            Capsule()
                .fill(Color(hex: 0xE3E3DA))
                .frame(width: size * 0.34, height: size * 0.14)
                .offset(x: size * 0.42, y: size * 0.18)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var wristband: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0xF4F1E8), Color(hex: 0xC4BFB1)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.92, height: size * 0.34)
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color(hex: 0x2B2B30))
                    .frame(width: size * 0.1, height: size * 0.3)
                    .offset(x: CGFloat(i - 1) * size * 0.18)
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var drinkCup: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [Color(hex: 0x2FA88C), Color(hex: 0x1C6E5B)], startPoint: .leading, endPoint: .trailing))
                .frame(width: size * 0.52, height: size * 0.8)
            Capsule()
                .fill(Color(hex: 0xEDEDE6))
                .frame(width: size * 0.62, height: size * 0.14)
                .offset(y: -size * 0.4)
            Capsule()
                .fill(Color(hex: 0xD5DAE0))
                .frame(width: size * 0.1, height: size * 0.5)
                .rotationEffect(.degrees(14))
                .offset(x: size * 0.14, y: -size * 0.3)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var playCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(hex: 0xF6F5EF))
                .frame(width: size * 0.62, height: size * 0.92)
                .rotationEffect(.degrees(-8))
            Capsule()
                .fill(Color(hex: 0xC0392B))
                .frame(width: size * 0.44, height: 1.6)
                .rotationEffect(.degrees(-32))
                .offset(x: size * 0.04, y: -size * 0.12)
            Capsule()
                .fill(Color(hex: 0x2471A3))
                .frame(width: size * 0.4, height: 1.6)
                .rotationEffect(.degrees(28))
                .offset(x: -size * 0.02, y: size * 0.16)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    // MARK: Sideline / coaching

    private var clipboard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(LinearGradient(colors: [Color(hex: 0x7A5230), Color(hex: 0x4E3018)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.7, height: size * 0.95)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(hex: 0xF4F2E9))
                .frame(width: size * 0.52, height: size * 0.7)
                .offset(y: size * 0.06)
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color(hex: 0x9A958A))
                    .frame(width: size * 0.34, height: 1.3)
                    .offset(y: size * (-0.1 + Double(i) * 0.16))
            }
            Capsule()
                .fill(Color(hex: 0xC9C4B6))
                .frame(width: size * 0.28, height: size * 0.12)
                .offset(y: -size * 0.42)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var playSheet: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [Color(hex: 0xF8FAFC), Color(hex: 0xD9E2EA)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.72, height: size * 0.95)
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color(hex: 0x2471A3).opacity(0.7))
                    .frame(width: size * (i == 1 ? 0.28 : 0.44), height: 1.4)
                    .offset(y: size * (-0.16 + Double(i) * 0.16))
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var headset: some View {
        Image(systemName: "headphones")
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.9)
            .foregroundStyle(LinearGradient(colors: [Color(hex: 0x4A525C), Color(hex: 0x23282E)], startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var challengeFlag: some View {
        ZStack {
            Capsule()
                .fill(Color(hex: 0x8A6A3A))
                .frame(width: size * 0.1, height: size * 0.95)
                .offset(x: -size * 0.28)
            Image(systemName: "flag.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.66, height: size * 0.6)
                .foregroundStyle(Color(hex: 0xE8B23A))
                .offset(x: size * 0.1)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var markerBoard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(LinearGradient(colors: [Color(hex: 0xFFFFFFFB), Color(hex: 0xE2E2DC)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 1.0, height: size * 0.7)
                .overlay(
                    RoundedRectangle(cornerRadius: 2.5)
                        .stroke(Color(hex: 0x9BA4AE), lineWidth: 1.4)
                )
            Capsule()
                .fill(Color(hex: 0xC0392B))
                .frame(width: size * 0.42, height: 1.6)
                .rotationEffect(.degrees(-6))
                .offset(x: -size * 0.08, y: -size * 0.1)
            Capsule()
                .fill(Color(hex: 0x2471A3))
                .frame(width: size * 0.3, height: 1.6)
                .rotationEffect(.degrees(10))
                .offset(x: size * 0.1, y: size * 0.1)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var whistle: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xD5DAE0), Color(hex: 0x8A919B)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(x: size * 0.08, y: size * 0.08)
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0xD5DAE0), Color(hex: 0x8A919B)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.55, height: size * 0.24)
                .rotationEffect(.degrees(-12))
                .offset(x: -size * 0.22, y: -size * 0.12)
            Circle()
                .fill(Color(hex: 0x2B2B30))
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(x: size * 0.1, y: size * 0.06)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var equipmentBag: some View {
        Image(systemName: "suitcase.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.95)
            .foregroundStyle(LinearGradient(colors: [Color(hex: 0x3E4A38), Color(hex: 0x1F261B)], startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var cone: some View {
        ZStack {
            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.66, height: size * 0.58)
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFF8A2A), Color(hex: 0xC4520E)], startPoint: .top, endPoint: .bottom))
                .offset(y: -size * 0.04)
            Capsule()
                .fill(Color.white.opacity(0.75))
                .frame(width: size * 0.3, height: size * 0.08)
                .offset(y: -size * 0.08)
            Capsule()
                .fill(Color(hex: 0x8A3A08))
                .frame(width: size * 0.85, height: size * 0.12)
                .offset(y: size * 0.3)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var pylon: some View {
        ZStack(alignment: .bottom) {
            // Side face gives the marker a sense of dimension.
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [Color(hex: 0xB8480C), Color(hex: 0x8A3208)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.16, height: size * 0.74)
                .offset(x: size * 0.19, y: -size * 0.04)
            // Front face.
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [Color(hex: 0xFF7A2A), Color(hex: 0xD2550E)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.3, height: size * 0.8)
            Capsule()
                .fill(Color(hex: 0xF6F5EF))
                .frame(width: size * 0.3, height: size * 0.14)
                .offset(y: -size * 0.32)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var yardMarker: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(LinearGradient(colors: [Color(hex: 0xFF8A2A), Color(hex: 0xC4520E)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.7, height: size * 0.7)
            Capsule()
                .fill(Color(hex: 0xF6F5EF))
                .frame(width: size * 0.4, height: size * 0.14)
            Capsule()
                .fill(Color(hex: 0xF6F5EF))
                .frame(width: size * 0.24, height: size * 0.14)
                .offset(y: size * 0.18)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    private var chainMarker: some View {
        ZStack {
            Capsule()
                .fill(Color(hex: 0xD5DAE0))
                .frame(width: size * 0.1, height: size * 0.8)
                .offset(x: -size * 0.32)
            Capsule()
                .fill(Color(hex: 0xD5DAE0))
                .frame(width: size * 0.1, height: size * 0.8)
                .offset(x: size * 0.32)
            Circle()
                .fill(Color(hex: 0xE8B23A))
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(x: -size * 0.32, y: -size * 0.4)
            Circle()
                .fill(Color(hex: 0xE8B23A))
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(x: size * 0.32, y: -size * 0.4)
            Capsule()
                .fill(Color.white.opacity(0.85))
                .frame(width: size * 0.62, height: 1.4)
                .offset(y: size * 0.12)
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }

    // MARK: Field damage / marks

    private var skidMarks: some View {
        VStack(spacing: size * 0.12) {
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(Color(hex: 0x2E2620).opacity(0.8))
                    .frame(width: size * 1.0, height: size * 0.14)
                    .rotationEffect(.degrees(i == 0 ? 8 : 8))
                    .offset(x: CGFloat(i) * size * 0.05)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 1.5, x: 1, y: 1)
    }

    private var tornTurf: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: 0x4A3A22))
                .frame(width: size * 0.95, height: size * 0.62)
                .rotationEffect(.degrees(-8))
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [Color(hex: 0x2F6B33), Color(hex: 0x1E4522)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.8, height: size * 0.48)
                .rotationEffect(.degrees(-8))
                .offset(x: -size * 0.06, y: -size * 0.08)
        }
        .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 2)
    }

    private var grassStain: some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: 0x3F7A34).opacity(0.55))
                .frame(width: size * 0.95, height: size * 0.55)
            Ellipse()
                .fill(Color(hex: 0x2C5524).opacity(0.5))
                .frame(width: size * 0.55, height: size * 0.3)
                .offset(x: size * 0.1, y: size * 0.06)
        }
        .shadow(color: .black.opacity(0.3), radius: 1.5)
    }

    private var cleatMarks: some View {
        VStack(spacing: size * 0.1) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: size * 0.14) {
                    ForEach(0..<3, id: \.self) { col in
                        Capsule()
                            .fill(Color(hex: 0x33291D).opacity(0.85))
                            .frame(width: size * 0.2, height: size * 0.1)
                            .rotationEffect(.degrees(row == 0 ? 20 : 20))
                            .offset(x: CGFloat(col % 2) * size * 0.06)
                    }
                }
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 1)
    }

    private var divot: some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: 0x5A4024))
                .frame(width: size * 0.8, height: size * 0.34)
            Ellipse()
                .fill(Color(hex: 0x6B5230))
                .frame(width: size * 0.34, height: size * 0.16)
                .offset(x: -size * 0.18, y: -size * 0.05)
            Capsule()
                .fill(Color(hex: 0x3F7A34).opacity(0.7))
                .frame(width: size * 0.4, height: size * 0.1)
                .rotationEffect(.degrees(14))
                .offset(x: size * 0.24, y: -size * 0.12)
        }
        .shadow(color: .black.opacity(0.4), radius: 1.5)
    }

    private var chalkMark: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.92))
                .frame(width: size * 0.9, height: size * 0.1)
                .rotationEffect(.degrees(45))
            Capsule()
                .fill(Color.white.opacity(0.92))
                .frame(width: size * 0.9, height: size * 0.1)
                .rotationEffect(.degrees(-45))
        }
        .shadow(color: .black.opacity(0.4), radius: 1)
    }

    private var wetPatch: some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: 0x24455C).opacity(0.5))
                .frame(width: size * 1.0, height: size * 0.6)
            Ellipse()
                .fill(Color.white.opacity(0.22))
                .frame(width: size * 0.4, height: size * 0.14)
                .offset(x: -size * 0.14, y: -size * 0.08)
        }
        .shadow(color: .black.opacity(0.3), radius: 1.5)
    }

    private var dragTrail: some View {
        VStack(alignment: .leading, spacing: size * 0.1) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color(hex: 0x4A3A22).opacity(0.75))
                    .frame(width: size * (0.65 - CGFloat(i) * 0.14), height: size * 0.13)
                    .offset(x: CGFloat(i) * size * 0.16)
            }
        }
        .rotationEffect(.degrees(24))
        .shadow(color: .black.opacity(0.4), radius: 1.5, x: 1, y: 1)
    }
}
