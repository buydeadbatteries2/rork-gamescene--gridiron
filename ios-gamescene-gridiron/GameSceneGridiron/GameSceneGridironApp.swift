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

    init() {
        // RevenueCat configures exactly once, here — never in views.
        // DEBUG/development uses the Test Store public key; RELEASE uses the
        // production iOS public key. The secret key is never a client concern.
        PurchaseManager.shared.configure()
        // Google Mobile Ads initializes exactly once, here — the UMP consent
        // flow runs after start; ads are only requested once consent allows.
        // DEBUG builds run Google's public test ad units; RELEASE uses the
        // build-injected production identifiers (missing → ads disabled).
        AdMobService.shared.configure()
    }

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
                AdMobService.shared.handleScenePhase(active: false)
            case .active:
                AudioManager.shared.resumeMusic()
                AdMobService.shared.handleScenePhase(active: true)
            @unknown default:
                break
            }
        }
    }
}
