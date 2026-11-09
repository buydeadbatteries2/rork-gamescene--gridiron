import SwiftUI

/// Keeps menu ambience off for the whole match, including intros and results.
struct GameAudioScope: ViewModifier {
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { AudioManager.shared.enterGameAudio(id) }
            .onDisappear { AudioManager.shared.leaveGameAudio(id) }
    }
}
