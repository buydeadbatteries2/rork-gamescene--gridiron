import Foundation

/// Bundled music cues. Each raw value is the base file name of an MP3 bundled
/// into the app's Resources folder (original AI-generated audio, loop-friendly).
enum MusicTrack: String, CaseIterable {
    /// Original brass-and-strings stadium theme for launch and menus.
    case menuTheme = "gridiron_menu_theme"
    /// Mysterious 80s synth-rock gameplay bed: analog bass, atmospheric pads,
    /// restrained guitar, gated percussion. Suspenseful, instrumental, loops seamlessly.
    case gameplayTheme = "synth_rock_thriller_suspense"
}
