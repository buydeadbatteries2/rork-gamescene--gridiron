import Foundation

/// Distinct one-shot sound effects for UI and gameplay moments.
/// Raw values are the base file names of bundled MP3s (original AI-generated audio).
/// All cues share the case-file atmosphere: cinematic, subtle 80s synth /
/// sports-thriller flavor — never childish or arcade-like. Winning moments
/// (correct placement, quarter victory) get triumphant victory cues.
enum SoundEffect: String, CaseIterable {
    case buttonPress = "cinematic_synth_button_tick"
    case cardSelect = "detective_card_flip"
    case profileSelect = "synth_chirp_confirm"
    case dragBegin = "card_lift_synth_whoosh"
    case placementCorrect = "victory_synth_sting"
    case placementWrong = "noir_synth_sting"
    case hintUsed = "typewriter_synth_reveal"
    case quarterWon = "victory_fanfare_sports"
    case quarterLost = "descending_synth_sting"
    case caseSolved = "case_closed_sting"
    // Phase 6 economy cues.
    case gameballDeposit = "synth_coin_deposit"
    case hintPurchaseConfirm = "synth_brass_confirmation_chime"
}
