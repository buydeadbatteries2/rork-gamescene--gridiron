import AVFoundation
import Foundation

/// All mutable state and AVAudioPlayer access are confined to this serial queue.
/// Never recycles players or polls isPlaying (unsafe on the cloud simulator).
nonisolated final class EffectsPlayback: @unchecked Sendable {
    private let queue = DispatchQueue(label: "gamescene.sound-effects", qos: .userInitiated)
    private var dataCache: [String: Data] = [:]
    private struct ActiveEffect {
        let player: AVAudioPlayer
        let duration: TimeInterval
        let startedAt: Date
    }
    private var active: [ActiveEffect] = []

    func play(name: String, volume: Float, limit: Int) {
        let requestedAt = Date()
        queue.async { [self] in
            // Never replay a stale backlog after a stalled audio subsystem.
            guard Date().timeIntervalSince(requestedAt) < 0.25 else { return }
            let data: Data
            if let cached = dataCache[name] {
                data = cached
            } else {
                guard let url = Bundle.main.url(forResource: name, withExtension: "mp3"),
                      let loaded = try? Data(contentsOf: url) else { return }
                dataCache[name] = loaded
                data = loaded
            }
            guard let player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.mp3.rawValue) else { return }
            player.volume = volume
            player.prepareToPlay()
            let duration = player.duration
            let now = Date()
            active.removeAll { now.timeIntervalSince($0.startedAt) >= $0.duration }
            if active.count >= limit {
                active.removeFirst(active.count - limit + 1)
            }
            player.play()
            active.append(ActiveEffect(player: player, duration: duration, startedAt: now))
        }
    }
}
