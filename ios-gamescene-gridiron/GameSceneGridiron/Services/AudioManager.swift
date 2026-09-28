import AVFoundation
import SwiftUI

/// Owns all audio for the game: looping background music, one-shot effects,
/// volumes, mute state and the persisted Music / Sound Effects settings.
///
/// Views and view models call the shared instance; no audio logic lives in
/// SwiftUI code. Missing bundled assets degrade silently to no-ops so the
/// architecture keeps working while assets are swapped or regenerated.
@Observable
final class AudioManager {
    static let shared = AudioManager()

    static let fileExtension = "mp3"

    private enum DefaultsKey {
        static let musicEnabled = "audio.musicEnabled"
        static let effectsEnabled = "audio.soundEffectsEnabled"
    }

    // MARK: Settings (persisted locally)

    private(set) var isMusicEnabled: Bool {
        didSet { defaults.set(isMusicEnabled, forKey: DefaultsKey.musicEnabled) }
    }

    private(set) var isSoundEffectsEnabled: Bool {
        didSet { defaults.set(isSoundEffectsEnabled, forKey: DefaultsKey.effectsEnabled) }
    }

    /// Master levels (0...1). Music stays low so clue reading is never overpowered.
    var musicVolume: Float = 0.3
    var effectVolume: Float = 0.85

    private let defaults: UserDefaults
    private var musicPlayer: AVAudioPlayer?
    private var activeEffectPlayers: [AVAudioPlayer] = []
    private var effectData: [SoundEffect: Data] = [:]
    private var currentTrack: MusicTrack?
    /// True while a screen wants the music bed (even if music is currently muted),
    /// so re-enabling music mid-game resumes the correct track.
    private var isMusicDesired = false
    private var isSessionConfigured = false
    private var fadeTask: Task<Void, Never>?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isMusicEnabled = defaults.object(forKey: DefaultsKey.musicEnabled) as? Bool ?? true
        self.isSoundEffectsEnabled = defaults.object(forKey: DefaultsKey.effectsEnabled) as? Bool ?? true
    }

    // MARK: Music

    /// Starts (or confirms) the looping music bed with a gentle fade-in.
    func playMusic(_ track: MusicTrack, fadeInDuration: TimeInterval = 1.2) {
        currentTrack = track
        isMusicDesired = true
        guard isMusicEnabled else { return }
        startMusicPlayer(track, fadeInDuration: fadeInDuration)
    }

    /// Fades the music out and releases the bed (result screens, leaving gameplay).
    func stopMusic(fadeOutDuration: TimeInterval = 0.8) {
        isMusicDesired = false
        currentTrack = nil
        guard let player = musicPlayer else { return }
        fadeOutAndStop(player, duration: fadeOutDuration)
    }

    /// Silence during the pause menu; `resumeMusic` brings it back smoothly.
    func pauseMusic() {
        musicPlayer?.pause()
    }

    func resumeMusic(fadeInDuration: TimeInterval = 0.6) {
        guard isMusicEnabled, isMusicDesired, let player = musicPlayer, !player.isPlaying else { return }
        player.volume = min(player.volume, musicVolume * 0.4)
        player.play()
        player.setVolume(musicVolume, fadeDuration: fadeInDuration)
    }

    private func startMusicPlayer(_ track: MusicTrack, fadeInDuration: TimeInterval) {
        configureSessionIfNeeded()
        fadeTask?.cancel()
        if let player = musicPlayer, player.isPlaying, currentTrack == track {
            player.setVolume(musicVolume, fadeDuration: fadeInDuration)
            return
        }
        guard let data = Self.loadData(named: track.rawValue) else { return }
        guard let player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.mp3.rawValue) else { return }
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        player.play()
        player.setVolume(musicVolume, fadeDuration: fadeInDuration)
        musicPlayer = player
    }

    private func fadeOutAndStop(_ player: AVAudioPlayer, duration: TimeInterval) {
        player.setVolume(0, fadeDuration: duration)
        fadeTask?.cancel()
        fadeTask = Task { [weak player] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            player?.pause()
            player?.currentTime = 0
        }
    }

    // MARK: Sound effects

    /// Plays a one-shot effect. Overlapping plays of the same effect are allowed.
    func play(_ effect: SoundEffect) {
        guard isSoundEffectsEnabled else { return }
        configureSessionIfNeeded()
        let data: Data
        if let cached = effectData[effect] {
            data = cached
        } else if let loaded = Self.loadData(named: effect.rawValue) {
            effectData[effect] = loaded
            data = loaded
        } else {
            return
        }
        guard let player = try? AVAudioPlayer(data: data, fileTypeHint: AVFileType.mp3.rawValue) else { return }
        player.volume = effectVolume
        player.prepareToPlay()
        player.play()
        activeEffectPlayers.removeAll { !$0.isPlaying }
        activeEffectPlayers.append(player)
    }

    // MARK: Settings

    func setMusicEnabled(_ isEnabled: Bool) {
        guard isEnabled != isMusicEnabled else { return }
        isMusicEnabled = isEnabled
        if isEnabled {
            if isMusicDesired, let track = currentTrack {
                startMusicPlayer(track, fadeInDuration: 0.6)
            }
        } else if let player = musicPlayer {
            fadeOutAndStop(player, duration: 0.3)
        }
    }

    func setSoundEffectsEnabled(_ isEnabled: Bool) {
        isSoundEffectsEnabled = isEnabled
    }

    // MARK: Plumbing

    /// Ambient category: respects the silent switch and mixes with other audio.
    private func configureSessionIfNeeded() {
        guard !isSessionConfigured else { return }
        isSessionConfigured = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private static func loadData(named name: String) -> Data? {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else { return nil }
        return try? Data(contentsOf: url)
    }
}
