import SwiftUI

/// SwiftUI illustrations of the physical evidence left on the field, with a soft
/// gold halo backing so each object reads as a clue on the photoreal turf.
struct EvidenceItemView: View {
    let kind: EvidenceItem.Kind
    var size: CGFloat = 26

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

            Group {
                switch kind {
                case .orangeTowel: towel
                case .droppedGlove: glove
                case .waterBottle: bottle
                case .muddyFootprints: footprints
                case .looseFootball: football
                }
            }
        }
        .frame(width: size * 1.3, height: size * 1.3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title)
    }

    private var towel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(hex: 0xFF8A2A), Color(hex: 0xC4520E)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 1.05, height: size * 0.72)
                .rotationEffect(.degrees(8))
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: 0xE66A1A))
                .frame(width: size * 0.7, height: size * 0.5)
                .rotationEffect(.degrees(-14))
                .offset(x: size * 0.12, y: size * 0.08)
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: size * 0.6, height: 1.2)
                    .offset(y: CGFloat(i - 1) * size * 0.14)
                    .rotationEffect(.degrees(6))
            }
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

    private var footprints: some View {
        Image(systemName: "shoeprints.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size * 1.05)
            .foregroundStyle(Color(hex: 0x5A3D22).opacity(0.9))
            .shadow(color: Color(hex: 0x3A2612).opacity(0.6), radius: 1)
    }

    private var football: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: 0xA0582A), Color(hex: 0x5A2C12)], center: UnitPoint(x: 0.4, y: 0.35), startRadius: 1, endRadius: size * 0.5))
                .frame(width: size * 0.95, height: size * 0.56)
            Capsule().fill(Color.white.opacity(0.9)).frame(width: size * 0.36, height: 1.5)
            HStack(spacing: size * 0.06) {
                ForEach(0..<4, id: \.self) { _ in
                    Capsule().fill(Color.white.opacity(0.9)).frame(width: 1.3, height: size * 0.12)
                }
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 2)
    }
}
