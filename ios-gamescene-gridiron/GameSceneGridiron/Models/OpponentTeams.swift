import Foundation

/// The 10 fixed fictional opponents. Each has a distinct emblem, color pair and
/// matchup personality, built from the same `GameTeam` model as the user's team.
nonisolated enum OpponentTeams {
    static let all: [GameTeam] = [
        GameTeam(
            state: "Texas", teamName: "Outlaws", logoID: "bull",
            primaryColorHex: 0x1A1A1A, secondaryColorHex: 0xD9B56E, isUserTeam: false
        ),
        GameTeam(
            state: "Arizona", teamName: "Scorpions", logoID: "scorpion",
            primaryColorHex: 0x8E1F2F, secondaryColorHex: 0xF2C230, isUserTeam: false
        ),
        GameTeam(
            state: "Florida", teamName: "Hammerheads", logoID: "shark",
            primaryColorHex: 0x2FA8C9, secondaryColorHex: 0x1E2A4A, isUserTeam: false
        ),
        GameTeam(
            state: "Ohio", teamName: "Steel Boars", logoID: "boar",
            primaryColorHex: 0xC9CDD1, secondaryColorHex: 0xE2762D, isUserTeam: false
        ),
        GameTeam(
            state: "Colorado", teamName: "Blizzard", logoID: "snowflake",
            primaryColorHex: 0xF2F2F2, secondaryColorHex: 0x2C5FB8, isUserTeam: false
        ),
        GameTeam(
            state: "Georgia", teamName: "Firebirds", logoID: "phoenix",
            primaryColorHex: 0xC2412F, secondaryColorHex: 0x1A1A1A, isUserTeam: false
        ),
        GameTeam(
            state: "Oregon", teamName: "Night Hawks", logoID: "hawk",
            primaryColorHex: 0x2C6B3C, secondaryColorHex: 0x7DB84F, isUserTeam: false
        ),
        GameTeam(
            state: "New York", teamName: "Sentinels", logoID: "shield",
            primaryColorHex: 0x1E2A4A, secondaryColorHex: 0xC9CDD1, isUserTeam: false
        ),
        GameTeam(
            state: "Nevada", teamName: "Thunder", logoID: "lightning",
            primaryColorHex: 0x6B4FA0, secondaryColorHex: 0xF2C230, isUserTeam: false
        ),
        GameTeam(
            state: "Louisiana", teamName: "Vipers", logoID: "serpent",
            primaryColorHex: 0x7DB84F, secondaryColorHex: 0x1A1A1A, isUserTeam: false
        )
    ]
}
