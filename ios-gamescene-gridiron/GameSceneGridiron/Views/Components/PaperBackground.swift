import SwiftUI

/// Aged manila case-file paper surface.
struct PaperSurface: View {
    var cornerRadius: CGFloat = 6
    var darkness: Double = 0

    var body: some View {
        Theme.paper
            .overlay {
                Image("manila_paper_texture")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.85)
                    .allowsHitTesting(false)
            }
            .overlay {
                LinearGradient(
                    colors: [.white.opacity(0.08), .clear, .black.opacity(0.14 + darkness)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

extension View {
    /// Places the view on a paper card with a soft drop shadow.
    func paperCard(cornerRadius: CGFloat = 6, darkness: Double = 0) -> some View {
        background {
            PaperSurface(cornerRadius: cornerRadius, darkness: darkness)
                .shadow(color: .black.opacity(0.55), radius: 10, y: 6)
        }
    }
}

/// Brass push pin used to "pin" photos to the desk.
struct PushPin: View {
    var size: CGFloat = 22

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hex: 0xF6E2A8), Theme.bronze, Theme.bronzeDeep],
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: 1,
                    endRadius: size * 0.6
                )
            )
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.6), radius: 3, x: 2, y: 3)
            .accessibilityHidden(true)
    }
}

/// Small torn paper note with typewriter copy.
struct StickyNote: View {
    let text: String
    var rotation: Double = -4
    var width: CGFloat = 92

    var body: some View {
        Text(text)
            .font(Theme.typewriter(11, relativeTo: .caption2))
            .foregroundStyle(Theme.paperInk)
            .multilineTextAlignment(.center)
            .lineSpacing(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(width: width)
            .paperCard(cornerRadius: 2, darkness: 0.08)
            .rotationEffect(.degrees(rotation))
            .accessibilityHidden(true)
    }
}
