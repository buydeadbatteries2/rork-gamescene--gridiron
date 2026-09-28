import SwiftUI

/// Primary bronze/gold capsule call-to-action.
struct GoldCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .bold).width(.condensed))
            .tracking(1.2)
            .foregroundStyle(Theme.goldLight)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background {
                Capsule()
                    .fill(Theme.bronzeButton)
                    .overlay {
                        Capsule()
                            .fill(
                                LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center)
                            )
                            .padding(3)
                    }
                    .overlay {
                        Capsule().strokeBorder(Theme.goldGradient, lineWidth: 2)
                    }
                    .shadow(color: Theme.bronze.opacity(configuration.isPressed ? 0.25 : 0.5), radius: configuration.isPressed ? 8 : 18)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 5)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { AudioManager.shared.play(.buttonPress) }
            }
    }
}

/// Square dark HUD button with a thin gold rim.
struct HUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Theme.goldLight)
            .frame(width: 46, height: 46)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color(hex: 0x3A3024), Color(hex: 0x1A1510)], startPoint: .top, endPoint: .bottom)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { AudioManager.shared.play(.buttonPress) }
            }
    }
}

/// Generic springy press feedback for custom tappable surfaces.
/// Opt in to the button-press sound for plain action buttons — surfaces that
/// already have a distinct cue (player cards, variant chips, arrows) keep it off
/// so sounds never double-fire.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var playsPressSound: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && playsPressSound { AudioManager.shared.play(.buttonPress) }
            }
    }
}
