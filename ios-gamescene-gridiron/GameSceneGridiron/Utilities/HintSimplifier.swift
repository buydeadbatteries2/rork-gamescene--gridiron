import SwiftUI

// MARK: - Simplified hints (Phase 11.7)
//
// A hint no longer hands the player another vague clue — it dissects one
// useful unresolved clue into plain language: WHO the lead is about
// (position), HOW they win the matchup (profile, described without naming
// it), and WHAT the original jargon actually said. Fully local and
// deterministic — authored replacement rules and profile descriptors, never
// a live AI request — so every competitive-eligible case works offline.

/// A simplified hint: plain-language text plus the short phrases to
/// marker-highlight (never the whole hint).
nonisolated struct SimplifiedHint: Equatable, Sendable {
    let text: String
    let highlightPhrases: [String]
}

nonisolated enum HintSimplifier {
    /// Authored replacement rules: case-file jargon → plain language.
    /// Applied in order, case-insensitively, deterministically.
    private static let replacements: [(pattern: String, replacement: String)] = [
        ("keeps biting on the underneath action", "keeps making mistakes on the short routes"),
        ("keeps biting on", "keeps guessing wrong against"),
        ("biting on", "guessing wrong against"),
        ("needs enough burst to", "needs speed to"),
        ("enough burst", "enough speed"),
        ("burst", "speed"),
        ("raw juice", "raw speed"),
        ("juice", "speed"),
        ("explosive", "very quick"),
        ("press-mauler", "strength blocker"),
        ("press mauler", "strength blocker"),
        ("mauler", "strength player"),
        ("physicality", "strength"),
        ("physical presence", "strength"),
        ("plays physical", "uses strength"),
        ("seasoned hands", "experienced hands"),
        ("seasoned", "experienced"),
        ("savvy", "experienced"),
        ("craft", "experience"),
        ("twelve seasons", "many seasons of experience"),
        ("sees the motion coming", "reads the play early"),
        ("sees it coming before anyone else", "reads the play early"),
        ("before anyone else does", "before anyone else"),
        ("reputation over execution", "highly regarded but keeps making mistakes"),
        ("expected to dominate", "highly regarded"),
        ("blue-chip", "highly regarded"),
    ]

    /// Plain-language descriptor for the solved profile — close enough to
    /// infer the answer, never the profile's choice-screen name.
    private static func profileDescriptor(_ profile: PlayerProfile) -> (sentence: String, highlights: [String]) {
        switch profile {
        case .fast:
            return ("They need SPEED to win this matchup.", ["speed"])
        case .powerful:
            return ("They win with pure STRENGTH, not finesse.", ["strength"])
        case .veteran:
            return ("They rely on EXPERIENCE and reading the play early.", ["experience"])
        case .rookie:
            return ("They are a FIRST-YEAR player still learning the game.", ["first-year"])
        case .overrated:
            return ("They are HIGHLY REGARDED but keep MAKING MISTAKES.", ["highly regarded", "making mistakes"])
        }
    }

    /// Simplifies one authored hint. `positionName` is the missing player's
    /// position (public knowledge — it is on their tray card); `profile` is
    /// the authored solution's deployment profile, described in plain words.
    static func simplify(text: String, positionName: String?, profile: PlayerProfile?) -> SimplifiedHint {
        var lines: [String] = []
        var candidateHighlights: [String] = []

        if let positionName, !positionName.isEmpty {
            lines.append("This lead is about the \(positionName).")
            candidateHighlights.append(positionName)
        }

        lines.append(applyReplacements(text))

        if let profile {
            let descriptor = profileDescriptor(profile)
            lines.append(descriptor.sentence)
            candidateHighlights.append(contentsOf: descriptor.highlights)
        }

        let joined = lines.joined(separator: " ")
        // Only highlight phrases that actually occur in the text — and never
        // the profile's choice-screen name (the player infers it).
        var seen: Set<String> = []
        let highlights = candidateHighlights
            .map { $0.lowercased() }
            .filter { phrase in
                guard !phrase.isEmpty, seen.insert(phrase).inserted else { return false }
                return joined.localizedCaseInsensitiveContains(phrase)
            }
        return SimplifiedHint(text: joined, highlightPhrases: highlights)
    }

    /// Applies the authored replacement rules.
    private static func applyReplacements(_ text: String) -> String {
        var result = text
        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: [.caseInsensitive])
        }
        return result
    }

    // MARK: Presentation

    /// Marker-highlighted attributed string: category highlights (evidence,
    /// positions, directions) plus strong emphasis on the simplified hint's
    /// key phrases. With `highContrast` the markers switch to the saturated
    /// High Contrast palette.
    @MainActor
    static func attributed(_ hint: SimplifiedHint, highContrast: Bool) -> AttributedString {
        var attributed = ClueHighlighter.highlighted(hint.text, highContrast: highContrast)
        for phrase in hint.highlightPhrases {
            for range in ClueHighlighter.ranges(of: phrase, in: hint.text) {
                if let target = Range(range, in: attributed) {
                    attributed[target].backgroundColor = highContrast ? Theme.highlightTraitHC : Theme.highlightTrait
                    attributed[target].foregroundColor = Theme.ink
                }
            }
        }
        return attributed
    }
}
