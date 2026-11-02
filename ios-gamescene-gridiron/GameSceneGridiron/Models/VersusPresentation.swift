import Foundation

// MARK: - Phase 15B — Versus player-facing presentation (pure, testable)
//
// Everything a Versus screen renders is derived here from the SERVER's match
// row. The client never decides a winner, a forfeit or an expiry: it maps
// the server's `status` / `player_state` / `outcome` / `is_forfeit` to copy.

extension VersusRules {
    /// The server snapshots `ranked_solution_variant(difficulty, 12)` — the
    /// championship stage of the chosen mode. Playing at any other stage
    /// would expect different placements than the server verifies.
    nonisolated static let adaptationStage: SeasonStage = .championship
    /// Gentle polling while a match is waiting on someone (seconds).
    nonisolated static let pollInterval: TimeInterval = 45
    /// Minimum gap between automatic refreshes (manual refresh ignores it).
    nonisolated static let refreshThrottle: TimeInterval = 5
    /// Cases in one Versus match: four regulation quarters + overtime.
    nonisolated static let caseCount = 5
}

/// What one Versus match means for THIS player right now.
nonisolated enum VersusPhase: Equatable, Sendable {
    /// No opponent yet; the cases are already assigned — the player may play now.
    case waitingCanPlay
    /// Opponent found; the player has not played yet.
    case readyToPlay
    /// The player submitted; waiting on an opponent to join / to finish.
    case submittedWaiting(opponentJoined: Bool)
    /// The server resolved the match (score, tiebreak or forfeit).
    case resolved(VersusOutcome, isForfeit: Bool)
    /// Expired with no result: nobody played (or no opponent ever joined).
    /// No W/L impact.
    case expiredNoResult
    /// Closed by the server (e.g. a different difficulty was searched).
    case cancelled

    static func of(_ match: VersusMatch) -> VersusPhase {
        switch match.status {
        case .completed:
            if let outcome = match.outcome { return .resolved(outcome, isForfeit: match.isForfeit) }
            return .expiredNoResult
        case .expired:
            return .expiredNoResult
        case .cancelled:
            return .cancelled
        case .waitingForOpponent, .active:
            switch match.playerState {
            case .waitingForOpponent: return .waitingCanPlay
            case .active: return .readyToPlay
            case .submitted: return .submittedWaiting(opponentJoined: false)
            case .opponentPending: return .submittedWaiting(opponentJoined: true)
            case .completed:
                if let outcome = match.outcome { return .resolved(outcome, isForfeit: match.isForfeit) }
                return .expiredNoResult
            case .expired: return .expiredNoResult
            case .cancelled: return .cancelled
            }
        }
    }

    var canPlay: Bool { self == .waitingCanPlay || self == .readyToPlay }
    var isClosed: Bool {
        switch self {
        case .resolved, .expiredNoResult, .cancelled: true
        default: false
        }
    }
    /// The match still needs someone (me or the opponent) — worth polling.
    var isPending: Bool { !isClosed }
}

nonisolated enum VersusPresentation {
    /// WIN / LOSS / TIE / FORFEIT WIN / FORFEIT LOSS — straight from the server.
    static func resultTitle(_ outcome: VersusOutcome, isForfeit: Bool) -> String {
        switch (outcome, isForfeit) {
        case (.win, true): "FORFEIT WIN"
        case (.loss, true): "FORFEIT LOSS"
        case (.win, false): "WIN"
        case (.loss, false): "LOSS"
        case (.tie, _): "TIE"
        }
    }

    static func shortResult(_ outcome: VersusOutcome) -> String {
        switch outcome {
        case .win: "W"
        case .loss: "L"
        case .tie: "T"
        }
    }

    /// The opponent's score is shown ONLY once the server completed the
    /// match; before that it is sealed even if the row carried a number.
    static func opponentScoreText(_ match: VersusMatch) -> String {
        guard match.status == .completed, let score = match.opponentFinalScore else { return "SEALED" }
        return "\(score)"
    }

    static func opponentCasesText(_ match: VersusMatch) -> String? {
        guard match.status == .completed, let solved = match.opponentCasesSolved else { return nil }
        return "\(solved)"
    }

    static func myScoreText(_ match: VersusMatch) -> String {
        match.myFinalScore.map(String.init) ?? "—"
    }

    /// "W-L-T" record line.
    static func recordLine(_ record: VersusCareerRecord?) -> String {
        guard let record else { return "0-0-0" }
        return "\(record.wins)-\(record.losses)-\(record.ties)"
    }

    /// Current streak from newest-first history ("W3", "L1", "T2"); nil
    /// without history.
    static func streak(_ history: [VersusHistoryEntry]) -> String? {
        guard let first = history.first?.outcome else { return nil }
        let run = history.prefix { $0.outcome == first }.count
        return "\(shortResult(first))\(run)"
    }

    /// Public identity line: username first, football display name as subtitle.
    static func opponentName(_ match: VersusMatch) -> String {
        if let name = match.opponentUsername, !name.isEmpty { return "@\(name)" }
        return "UNKNOWN DETECTIVE"
    }

    static func expiredDetail(_ match: VersusMatch) -> String {
        switch match.resolution {
        case .expiredNoOpponent: "No opponent took the case before the deadline. No result — your record is unchanged."
        default: "Neither detective closed the file before the deadline. No result — records unchanged."
        }
    }

    static func resolutionDetail(_ match: VersusMatch) -> String {
        switch match.resolution {
        case .forfeit:
            match.outcome == .win
                ? "Your opponent never submitted before the deadline."
                : "You didn't submit before the deadline."
        case .casesSolved: "Scores level — decided on cases solved."
        case .regulationQuarters: "Scores level — decided on regulation quarters."
        case .tie: "Dead even on every tiebreak."
        default: "Decided on verified score."
        }
    }

    static func findErrorMessage(_ reason: String) -> String {
        switch reason {
        case "versus_match_in_progress": "You already have an active match at another difficulty. Finish it first."
        case "versus_already_waiting": "Your submitted case file is still waiting for an opponent."
        case "versus_catalog_unavailable": "No case files are available for this difficulty right now."
        case "profile_required": "Finish setting up your account to play Versus."
        default: "Matchmaking couldn't complete. Try again in a moment."
        }
    }

    static func submitErrorMessage(_ reason: String) -> String {
        switch reason {
        case "versus_match_closed": "This match was already closed by the server."
        case "versus_hints_not_allowed": "Hints aren't allowed in Versus — this file can't count."
        case "case_mismatch", "case_version_mismatch": "These case files don't match the server's assignment."
        default: "The server rejected this case file (\(reason))."
        }
    }

    /// "Expires in 21h 14m" / "Expired".
    static func deadlineText(_ match: VersusMatch, now: Date = Date()) -> String {
        guard let deadline = match.expiresAtDate else { return "Deadline set by the server" }
        let remaining = deadline.timeIntervalSince(now)
        guard remaining > 0 else { return "Deadline passed — awaiting server" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return hours > 0 ? "Expires in \(hours)h \(minutes)m" : "Expires in \(max(minutes, 1))m"
    }

    static func shortDate(_ iso: String?) -> String {
        guard let iso, let date = RankedAssignmentWire.parseDate(iso) else { return "—" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: Playability (no local substitution)

nonisolated enum VersusPlayability {
    /// nil when every assigned case exists locally at the server's version;
    /// otherwise a reason — the match is then NOT playable (never substituted).
    static func problem(
        for match: VersusMatch,
        caseExists: (String) -> Bool = { CaseLibrary.caseByID($0) != nil },
        version: (String) -> Int? = CompetitiveCaseCatalog.competitiveVersion(forCaseID:)
    ) -> String? {
        guard match.difficultyLevel != nil else { return "unknown_difficulty" }
        guard match.caseIDs.count == VersusRules.caseCount,
              match.caseVersions.count == VersusRules.caseCount else { return "invalid_case_count" }
        for (id, expected) in zip(match.caseIDs, match.caseVersions) {
            guard caseExists(id) else { return "missing_case" }
            guard version(id) == expected else { return "case_version_mismatch" }
        }
        return nil
    }
}

/// The exact server assignment handed to gameplay.
nonisolated struct VersusPlayContext: Codable, Hashable, Sendable, Identifiable {
    let matchID: UUID
    var id: UUID { matchID }
    let caseIDs: [String]
    let caseVersions: [Int]
    let difficulty: DifficultyLevel
    let startedAt: Date

    init?(match: VersusMatch, startedAt: Date) {
        guard let level = match.difficultyLevel,
              match.caseIDs.count == VersusRules.caseCount,
              match.caseVersions.count == VersusRules.caseCount else { return nil }
        matchID = match.matchID
        caseIDs = match.caseIDs
        caseVersions = match.caseVersions
        difficulty = level
        self.startedAt = startedAt
    }

    /// Per-match investigation snapshot key (never the season's global key).
    static func snapshotKey(matchID: UUID) -> String {
        "gamescene.gridiron.versus.investigation.\(matchID.uuidString)"
    }
}

/// Saved after each quarter so a force-close resumes the same match.
nonisolated struct VersusProgress: Codable, Hashable, Sendable {
    let matchID: UUID
    let startedAt: Date
    let match: GameMatch
    let caseResults: [CompetitiveCaseResult]
}

/// A finished game whose submission has not been confirmed by the server.
nonisolated struct VersusPendingSubmission: Codable, Hashable, Sendable {
    let match: VersusMatch
    let startedAt: Date
    let caseResults: [CompetitiveCaseResult]
}

extension VersusMatch {
    /// The match after a verified receipt — server numbers only. The
    /// opponent's score is adopted only when the server completed the match.
    nonisolated func applying(receipt: VersusSubmitReceipt) -> VersusMatch {
        let newStatus = receipt.matchStatus ?? status
        let completed = newStatus == .completed
        return VersusMatch(
            matchID: matchID, status: newStatus,
            playerState: receipt.playerState ?? playerState,
            role: role, difficulty: difficulty, caseIDs: caseIDs, caseVersions: caseVersions,
            catalogFingerprint: catalogFingerprint, contentSource: contentSource,
            createdAt: createdAt, matchedAt: matchedAt, expiresAt: expiresAt, completedAt: completedAt,
            opponentUserID: opponentUserID, opponentUsername: opponentUsername,
            opponentDisplayName: opponentDisplayName,
            mySubmitted: true,
            myFinalScore: receipt.finalScore ?? myFinalScore,
            myCasesSolved: receipt.casesSolved ?? myCasesSolved,
            opponentSubmitted: opponentSubmitted || completed,
            opponentFinalScore: completed ? (receipt.opponentFinalScore ?? opponentFinalScore) : nil,
            opponentCasesSolved: completed ? opponentCasesSolved : nil,
            outcome: completed ? (receipt.matchOutcome ?? outcome) : nil,
            isForfeit: isForfeit, resolution: resolution, reused: reused
        )
    }

    /// Fallback summary built from a history row (when the single-match
    /// read is unavailable): server numbers, no cases solved.
    nonisolated static func fromHistory(_ entry: VersusHistoryEntry, cached: VersusMatch?) -> VersusMatch {
        VersusMatch(
            matchID: entry.matchID, status: .completed, playerState: .completed,
            role: cached?.role ?? "player_a", difficulty: entry.difficulty,
            caseIDs: cached?.caseIDs ?? [], caseVersions: cached?.caseVersions ?? [],
            catalogFingerprint: cached?.catalogFingerprint, contentSource: cached?.contentSource ?? .bundledDevFallback,
            createdAt: cached?.createdAt ?? (entry.completedAt ?? ""), matchedAt: cached?.matchedAt,
            expiresAt: cached?.expiresAt ?? (entry.completedAt ?? ""), completedAt: entry.completedAt,
            opponentUserID: entry.opponentUserID, opponentUsername: entry.opponentUsername,
            opponentDisplayName: entry.opponentDisplayName,
            mySubmitted: entry.myFinalScore != nil, myFinalScore: entry.myFinalScore,
            myCasesSolved: cached?.myCasesSolved,
            opponentSubmitted: entry.opponentFinalScore != nil, opponentFinalScore: entry.opponentFinalScore,
            opponentCasesSolved: nil, outcome: entry.outcome, isForfeit: entry.isForfeit,
            resolution: entry.resolution, reused: nil
        )
    }

    /// Local stand-in when a tracked match vanished from every read and its
    /// deadline passed (single-match RPC not deployed yet): expired, no result.
    nonisolated func asExpiredNoResult() -> VersusMatch {
        VersusMatch(
            matchID: matchID, status: .expired, playerState: .expired,
            role: role, difficulty: difficulty, caseIDs: caseIDs, caseVersions: caseVersions,
            catalogFingerprint: catalogFingerprint, contentSource: contentSource,
            createdAt: createdAt, matchedAt: matchedAt, expiresAt: expiresAt, completedAt: completedAt,
            opponentUserID: opponentUserID, opponentUsername: opponentUsername,
            opponentDisplayName: opponentDisplayName,
            mySubmitted: mySubmitted, myFinalScore: myFinalScore, myCasesSolved: myCasesSolved,
            opponentSubmitted: false, opponentFinalScore: nil, opponentCasesSolved: nil,
            outcome: nil, isForfeit: false,
            resolution: opponentUserID == nil ? .expiredNoOpponent : .expiredUnplayed, reused: nil
        )
    }
}
