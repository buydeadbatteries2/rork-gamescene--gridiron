import Foundation

/// The 10 fixed fictional opponents. Each has a distinct emblem, color pair,
/// matchup personality and a hidden strength rating (1–5) that only influences
/// the local CPU result simulation — never shown to the player.
///
/// Every opponent carries a FIXED UUID so a persisted season schedule, results
/// and standings survive app restarts.
nonisolated enum OpponentTeams {
    private static func fixedID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "5EEDC0DE-0000-4000-8000-%012d", index))!
    }

    private static let definitions: [(team: GameTeam, strength: Int)] = [
        (
            GameTeam(
                id: fixedID(1),
                state: "Texas", teamName: "Outlaws", logoID: "bull",
                primaryColorHex: 0x1A1A1A, secondaryColorHex: 0xD9B56E, isUserTeam: false
            ),
            5
        ),
        (
            GameTeam(
                id: fixedID(2),
                state: "Arizona", teamName: "Scorpions", logoID: "scorpion",
                primaryColorHex: 0x8E1F2F, secondaryColorHex: 0xF2C230, isUserTeam: false
            ),
            4
        ),
        (
            GameTeam(
                id: fixedID(3),
                state: "Florida", teamName: "Hammerheads", logoID: "shark",
                primaryColorHex: 0x2FA8C9, secondaryColorHex: 0x1E2A4A, isUserTeam: false
            ),
            4
        ),
        (
            GameTeam(
                id: fixedID(4),
                state: "Ohio", teamName: "Steel Boars", logoID: "boar",
                primaryColorHex: 0xC9CDD1, secondaryColorHex: 0xE2762D, isUserTeam: false
            ),
            3
        ),
        (
            GameTeam(
                id: fixedID(5),
                state: "Colorado", teamName: "Blizzard", logoID: "snowflake",
                primaryColorHex: 0xF2F2F2, secondaryColorHex: 0x2C5FB8, isUserTeam: false
            ),
            3
        ),
        (
            GameTeam(
                id: fixedID(6),
                state: "Georgia", teamName: "Firebirds", logoID: "phoenix",
                primaryColorHex: 0xC2412F, secondaryColorHex: 0x1A1A1A, isUserTeam: false
            ),
            4
        ),
        (
            GameTeam(
                id: fixedID(7),
                state: "Oregon", teamName: "Night Hawks", logoID: "hawk",
                primaryColorHex: 0x2C6B3C, secondaryColorHex: 0x7DB84F, isUserTeam: false
            ),
            2
        ),
        (
            GameTeam(
                id: fixedID(8),
                state: "New York", teamName: "Sentinels", logoID: "shield",
                primaryColorHex: 0x1E2A4A, secondaryColorHex: 0xC9CDD1, isUserTeam: false
            ),
            4
        ),
        (
            GameTeam(
                id: fixedID(9),
                state: "Nevada", teamName: "Thunder", logoID: "lightning",
                primaryColorHex: 0x6B4FA0, secondaryColorHex: 0xF2C230, isUserTeam: false
            ),
            3
        ),
        (
            GameTeam(
                id: fixedID(10),
                state: "Louisiana", teamName: "Vipers", logoID: "serpent",
                primaryColorHex: 0x7DB84F, secondaryColorHex: 0x1A1A1A, isUserTeam: false
            ),
            2
        )
    ]

    static let all: [GameTeam] = definitions.map(\.team)

    /// Hidden 1–5 strength rating that biases the CPU result simulation.
    static func strength(of teamID: UUID) -> Int {
        definitions.first { $0.team.id == teamID }?.strength ?? 3
    }

    static func team(with id: UUID) -> GameTeam? {
        definitions.first { $0.team.id == id }?.team
    }
}
