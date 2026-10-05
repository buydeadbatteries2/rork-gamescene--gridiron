import Foundation

/// The football landmark a placement slot represents (QB pocket, backfield lane,
/// wide split, corner, deep safety...). Derived from the authored slot key, so
/// existing case definitions need no new data.
nonisolated enum SlotRole: Hashable, Sendable {
    case qbPocket
    case backfield
    case slotReceiver
    case wideReceiver
    case tightEnd
    case offensiveLine
    case defensiveLine
    case linebacker
    case corner
    case boxSafety
    case deepSafety

    /// Positions whose slot keys carry their own landmark prefix
    /// ("rb-right", "fs-center", "cb-slot"...) resolve directly.
    private static let positionPrefixes: [(prefix: String, role: SlotRole)] = [
        ("qb", .qbPocket),
        ("rb", .backfield),
        ("wr", .wideReceiver),
        ("te", .tightEnd),
        ("ol", .offensiveLine),
        ("dl", .defensiveLine),
        ("dt", .defensiveLine),
        ("de", .defensiveLine),
        ("lb", .linebacker),
        ("cb", .corner),
        ("ss", .boxSafety),
        ("fs", .deepSafety)
    ]

    /// Keyword landmarks for the remaining authored keys ("under-center",
    /// "left-gun", "slot-left", "box-right", "mike", "bunch"...).
    private static let keywords: [(token: String, role: SlotRole)] = [
        ("gun", .qbPocket),
        ("pistol", .qbPocket),
        ("under", .qbPocket),
        ("backfield", .backfield),
        ("back", .backfield),
        ("slot", .slotReceiver),
        ("wide", .wideReceiver),
        ("bunch", .wideReceiver),
        ("trips", .wideReceiver),
        ("te", .tightEnd),
        ("ol", .offensiveLine),
        ("guard", .offensiveLine),
        ("tackle", .offensiveLine),
        ("gap", .offensiveLine),
        ("edge", .defensiveLine),
        ("nose", .defensiveLine),
        ("3tech", .defensiveLine),
        ("backer", .linebacker),
        ("mike", .linebacker),
        ("box", .boxSafety),
        ("corner", .corner),
        ("safety", .deepSafety),
        ("deep", .deepSafety)
    ]

    /// The slot's landmark, or nil when the key carries no readable meaning —
    /// unknown keys stay universal candidates (never hidden from anyone).
    static func role(ofSlotID slotID: String) -> SlotRole? {
        let key = slotKey(of: slotID).lowercased()
        let tokens = key.split(separator: "-").map(String.init)
        guard !tokens.isEmpty else { return nil }
        // Position-prefixed keys ("rb-right", "cb1-right", "wr2-slot"): match
        // the head TOKEN exactly (trailing digits stripped) — a raw prefix
        // check would make "deep-center" collide with the "de" (DL) prefix.
        let head = tokens[0].trimmingCharacters(in: CharacterSet(charactersIn: "0123456789"))
        if let match = positionPrefixes.first(where: { $0.prefix == head }) {
            return match.role
        }
        for token in tokens {
            for (keyword, role) in keywords where token == keyword {
                return role
            }
        }
        return nil
    }

    /// Strips the runtime case prefix ("case_x-s-key" → "key"); standalone
    /// puzzle slot ids pass through unchanged.
    private static func slotKey(of slotID: String) -> String {
        if let range = slotID.range(of: "-s-") {
            return String(slotID[range.upperBound...])
        }
        return slotID
    }

    /// Whether a position could legitimately line up at this landmark. The
    /// answer only ever widens the mystery set with football-plausible spots —
    /// it never decides correctness.
    static func accepts(_ position: FootballPosition, slotID: String) -> Bool {
        guard let slotRole = role(ofSlotID: slotID) else { return true }
        return accepts(position, slotRole: slotRole)
    }

    static func accepts(_ position: FootballPosition, slotRole: SlotRole) -> Bool {
        switch position {
        case .qb: slotRole == .qbPocket
        case .rb: slotRole == .backfield || slotRole == .qbPocket
        case .wr: slotRole == .wideReceiver || slotRole == .slotReceiver
        case .te: slotRole == .tightEnd
        case .ol: slotRole == .offensiveLine
        case .dl: slotRole == .defensiveLine || slotRole == .tightEnd
        case .lb: slotRole == .linebacker || slotRole == .boxSafety
        case .cb: slotRole == .corner || slotRole == .slotReceiver
        case .ss: slotRole == .boxSafety || slotRole == .deepSafety || slotRole == .linebacker
        case .fs: slotRole == .deepSafety || slotRole == .boxSafety
        }
    }
}
