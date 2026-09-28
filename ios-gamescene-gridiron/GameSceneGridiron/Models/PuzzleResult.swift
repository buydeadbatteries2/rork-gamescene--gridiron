import Foundation

/// Outcome of the current quarter. Losing a quarter never ends the whole game.
nonisolated enum PuzzleResult: Hashable, Sendable {
    case inProgress
    case won
    case lost
}

/// Short on-screen feedback after an action.
nonisolated struct FeedbackMessage: Identifiable, Hashable, Sendable {
    nonisolated enum Tone: Hashable, Sendable {
        case success
        case failure
        case info
        case lead
    }

    let id: String
    let title: String
    let detail: String?
    let tone: Tone

    init(title: String, detail: String? = nil, tone: Tone) {
        self.id = UUID().uuidString
        self.title = title
        self.detail = detail
        self.tone = tone
    }
}
