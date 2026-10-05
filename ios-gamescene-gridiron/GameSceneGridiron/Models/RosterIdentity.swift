import Foundation

// MARK: - Roster identity

/// Links one puzzle player to a real franchise roster member: the puzzle's
/// generic player takes on the user's actual player name and body asset for
/// that quarter. Pure data — the runtime engine keeps its own ids.
nonisolated struct RosterIdentity: Hashable, Sendable {
    let franchisePlayerID: UUID
    /// The case-file authoring key this puzzle player came from ("rb", "wr2"),
    /// used to look up the case's explicitly authored stat event.
    let playerKey: String
    /// Full fictional name, e.g. "Marcus Reed".
    let fullName: String
    /// Display name, e.g. "M. Reed".
    let shortName: String
    let position: FootballPosition
    /// Controlled-library body asset for portraits.
    let bodyAssetID: String
}

// MARK: - Puzzle conversion

extension QuarterPuzzle {
    /// Applies franchise roster identities to a converted puzzle: assigned
    /// missing players are renamed to the user's actual roster members (with
    /// their permanent body asset). Player ids, clues, slots and solutions are
    /// untouched, so gameplay and uniqueness are unaffected.
    func withRosterIdentities(_ identities: [String: RosterIdentity]) -> QuarterPuzzle {
        guard !identities.isEmpty else { return self }
        var players = missingPlayers
        for index in players.indices {
            guard let identity = identities[players[index].id] else { continue }
            players[index] = FootballPlayer(
                id: players[index].id,
                name: identity.fullName,
                position: players[index].position,
                cardAsset: identity.bodyAssetID
            )
        }
        return QuarterPuzzle(
            id: id,
            index: index,
            quarterLabel: quarterLabel,
            title: title,
            introHeading: introHeading,
            introBody: introBody,
            startingLives: startingLives,
            startingHints: startingHints,
            visiblePlayers: visiblePlayers,
            missingPlayers: players,
            evidence: evidence,
            slots: slots,
            clues: clues,
            hints: hints,
            solutions: solutions
        )
    }
}
