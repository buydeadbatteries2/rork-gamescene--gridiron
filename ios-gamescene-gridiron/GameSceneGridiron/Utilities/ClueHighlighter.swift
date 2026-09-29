import SwiftUI

/// Marker-style highlighting for clue and hint text. Scans the copy for the kinds
/// of information a detective needs — physical evidence, field position, player
/// types and Fast/Power/Veteran flavor — and paints soft highlighter backgrounds
/// under each category so the notebook reads like an annotated case file.
///
/// Priority order decides who wins overlapping words (e.g. "strong safety" is a
/// position highlight, not a trait highlight). Colors live in `Theme`.
enum ClueHighlighter {
    private struct Rule {
        let pattern: String
        let color: Color
    }

    private static let rules: [Rule] = [
        // 0. Rule-outs — rose marker ("not a cornerback"), highest priority so the
        // whole negation reads as one thought before position highlighting kicks in.
        Rule(
            pattern: #"\bnot (?:a|an|the) \w+(?: \w+)?\b"#,
            color: Theme.highlightNegative
        ),
        // 1. Physical evidence — blue marker
        Rule(
            pattern: #"\b(orange towel|loose football|muddy footprints|water bottle|dropped glove|towel|football|bottle|glove|footprints)\b"#,
            color: Theme.highlightEvidence
        ),
        // 2. Who the clue is about — orange marker
        Rule(
            pattern: #"\b(running back|wide receiver|tight end|cornerback|linebacker|strong safety|free safety|quarterback|defensive end|offensive line|safety|lineman|blocker|receiver|defender|route runner|back)\b"#,
            color: Theme.highlightPosition
        ),
        // 3. Fast / Power / Veteran flavor — purple marker
        Rule(
            pattern: #"\b(film study|twelve seasons|strong enough|quick|speed|strong|physical|seasoned|fast)\b"#,
            color: Theme.highlightTrait
        ),
        // 4. Where on the field — yellow marker
        Rule(
            pattern: #"\b(right sideline|left sideline|right side|left side|dead center|directly across|across from|deeper than|center of the field|line of scrimmage|top of the field|bottom of the field|in front of|deeper|deep|wide|behind|sideline|backfield)\b"#,
            color: Theme.highlightDirection
        ),
    ]

    /// Returns the text with soft marker backgrounds applied. Unmatched copy keeps
    /// its normal styling, so the notebook never turns into neon clutter.
    static func highlighted(_ text: String) -> AttributedString {
        var result = AttributedString()
        var cursor = text.startIndex

        for (range, color) in mergedMatches(in: text) {
            if cursor < range.lowerBound {
                result.append(AttributedString(String(text[cursor..<range.lowerBound])))
            }
            var segment = AttributedString(String(text[range]))
            segment.backgroundColor = color
            result.append(segment)
            cursor = range.upperBound
        }
        if cursor < text.endIndex {
            result.append(AttributedString(String(text[cursor...])))
        }
        return result
    }

    /// Collects regex matches for every rule, first-come-first-served so higher
    /// priority rules keep their words, then sorts them back into reading order.
    private static func mergedMatches(in text: String) -> [(Range<String.Index>, Color)] {
        var kept: [(Range<String.Index>, Color)] = []
        for rule in rules {
            for range in matches(in: text, pattern: rule.pattern) where !kept.contains(where: { $0.0.overlaps(range) }) {
                kept.append((range, rule.color))
            }
        }
        return kept.sorted { $0.0.lowerBound < $1.0.lowerBound }
    }

    private static func matches(in text: String, pattern: String) -> [Range<String.Index>] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsText = text as NSString
        return regex
            .matches(in: text, range: NSRange(location: 0, length: nsText.length))
            .compactMap { Range($0.range, in: text) }
    }
}
