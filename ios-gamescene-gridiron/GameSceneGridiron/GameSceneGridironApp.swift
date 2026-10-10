//
//  GameSceneGridironApp.swift
//  GameSceneGridiron
//
//  Created by Rork on September 28, 2026.
//

import SwiftUI

@main
struct GameSceneGridironApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            // Lifecycle audio: backgrounding pauses the music bed (the system
            // silences ambient audio anyway — this keeps our state coherent);
            // returning resumes cleanly without starting a second player.
            switch phase {
            case .background, .inactive:
                AudioManager.shared.pauseMusic()
            case .active:
                AudioManager.shared.resumeMusic()
            @unknown default:
                break
            }
        }
    }
}
