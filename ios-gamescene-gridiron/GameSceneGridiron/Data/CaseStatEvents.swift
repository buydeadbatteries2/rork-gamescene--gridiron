import Foundation

// MARK: - Case stat events
//
// Explicit statistical metadata authored per case file: caseID → playerKey →
// the stat that actually occurred in that scenario. This — not the player's
// Fast/Power/Veteran profile — decides WHAT happened statistically. The same
// position answering the same profile can earn completely different events
// across cases (a Fast RB runs in one case and blocks on a screen in another).
// A solved placement whose case/player has no entry here falls back to the
// engine's position-neutral base stat, so every solved case still feeds the
// roster, leaders and Player of the Game.
nonisolated enum CaseStatEvents {

    static let table: [String: [String: PlayerStat]] = [

        // MARK: Band 1
        "case_spread_sideline_01": [
            "rb": .successfulRuns, "te": .successfulAssignments, "wr": .receptions,
            "cb": .coverageWins, "fs": .tackles
        ],
        "case_gun_protection_02": [
            "qb": .successfulReads, "ol": .protectionWins, "cb": .coverageWins, "ss": .tackles
        ],
        "case_singleback_gap_03": [
            "rb": .successfulRuns, "wr": .receptions, "lb": .stops, "fs": .coverageWins
        ],
        "case_tight_edge_04": [
            "te": .successfulAssignments, "ol": .blocks, "dl": .stops, "cb": .passBreakups
        ],
        "case_two_back_blitz_05": [
            "qb": .drivesSecured, "rb": .keyBlocks, "wr": .receptions, "ss": .tackles
        ],
        "case_trips_assignment_06": [
            "wr": .successfulAssignments, "te": .receptions, "lb": .coverageWins, "fs": .tackles
        ],
        "case_power_interior_07": [
            "rb": .brokenTackles, "ol": .blocks, "de": .pressures, "fs": .tackles
        ],
        "case_bunch_right_08": [
            "qb": .successfulReads, "te": .receptions, "wr": .bigPlays,
            "cb": .coverageWins, "ss": .tackles
        ],
        "case_motion_left_09": [
            "wr": .successfulAssignments, "rb": .successfulRuns, "dl": .stops,
            "cb": .coverageWins, "fs": .tackles
        ],
        "case_red_zone_look_10": [
            "te": .receptions, "ol": .blocks, "lb": .stops, "ss": .coverageWins
        ],

        // MARK: Band 2
        "case_empty_backfield_01": [
            "qb": .successfulReads, "wr1": .receptions, "wr2": .bigPlays,
            "de": .pressures, "ss": .tackles
        ],
        "case_nickel_slot_02": [
            "wr": .receptions, "te": .successfulAssignments, "cb1": .coverageWins,
            "cb2": .passBreakups, "lb": .tackles
        ],
        "case_goal_line_stand_03": [
            "te": .successfulAssignments, "ol": .blocks, "dl": .stops,
            "lb": .tackles, "ss": .tackles
        ],
        "case_pistol_push_04": [
            "qb": .drivesSecured, "rb": .successfulRuns, "ol": .protectionWins,
            "de": .sacks, "fs": .tackles
        ],
        "case_four_wide_flood_05": [
            "qb": .successfulReads, "wr1": .receptions, "wr2": .bigPlays,
            "cb": .passBreakups, "fs": .interceptions
        ],
        "case_strong_side_leak_06": [
            "te": .receptions, "rb": .successfulRuns, "dl": .stops,
            "lb": .tackles, "cb": .passBreakups
        ],
        "case_screen_left_07": [
            "rb": .brokenTackles, "wr": .successfulAssignments, "ol": .protectionWins,
            "dl": .stops, "ss": .tackles
        ],
        "case_post_safe_08": [
            "wr": .receptions, "te": .successfulAssignments, "cb": .coverageWins,
            "fs": .tackles, "lb": .coverageWins
        ],
        "case_two_tight_power_09": [
            "qb": .drivesSecured, "te": .successfulAssignments, "ol": .blocks,
            "dl": .stops, "lb": .tackles
        ],
        "case_blitz_a_gap_10": [
            "qb": .drivesSecured, "rb": .keyBlocks, "cb": .coverageWins,
            "de": .sacks, "fs": .tackles
        ],

        // MARK: Band 3
        "case_overs_front_01": [
            "qb": .drivesSecured, "wr": .receptions, "te": .successfulAssignments,
            "dl": .stops, "lb": .tackles, "ss": .coverageWins
        ],
        "case_crossing_routes_02": [
            "qb": .successfulReads, "rb": .keyBlocks, "wr": .bigPlays, "te": .receptions,
            "cb": .passBreakups, "fs": .interceptions
        ],
        "case_under_center_03": [
            "qb": .drivesSecured, "ol": .blocks, "te": .successfulAssignments,
            "dl": .stops, "lb": .tackles, "cb": .coverageWins
        ],
        "case_deep_safety_read_04": [
            "wr": .bigPlays, "rb": .successfulRuns, "cb": .coverageWins,
            "fs": .interceptions, "lb": .stops
        ],
        "case_edge_concern_05": [
            "qb": .scrambleOpportunities, "ol": .protectionWins, "de": .sacks,
            "cb": .passBreakups, "ss": .tackles
        ],
        "case_option_pitch_06": [
            "qb": .scrambleOpportunities, "rb": .successfulRuns, "wr": .successfulAssignments,
            "dl": .stops, "fs": .tackles
        ],
        "case_doubling_star_07": [
            "wr1": .receptions, "wr2": .bigPlays, "te": .receptions,
            "cb1": .coverageWins, "cb2": .passBreakups, "ss": .tackles
        ],
        "case_interior_stunt_08": [
            "ol": .protectionWins, "dt1": .pressures, "dt2": .sacks,
            "lb": .stops, "fs": .tackles
        ],
        "case_bootleg_right_09": [
            "qb": .scrambleOpportunities, "te": .receptions, "wr": .bigPlays,
            "dl": .pressures, "lb": .stops
        ],
        "case_cover_two_shell_10": [
            "wr": .bigPlays, "rb": .successfulRuns, "te": .receptions,
            "dl": .stops, "fs": .tackles
        ],

        // MARK: Band 4
        "case_unders_safety_01": [
            "qb": .drivesSecured, "ol": .blocks, "cb": .coverageWins, "ss": .tackles,
            "fs": .interceptions, "lb": .stops
        ],
        "case_three_level_flood_02": [
            "qb": .drivesSecured, "wr1": .receptions, "wr2": .bigPlays,
            "cb": .passBreakups, "fs": .coverageWins, "ss": .tackles
        ],
        "case_short_yardage_wedge_03": [
            "rb": .brokenTackles, "te": .successfulAssignments, "ol": .blocks,
            "dl": .stops, "lb": .tackles
        ],
        "case_scramble_drill_04": [
            "qb": .scrambleOpportunities, "wr": .bigPlays, "te": .receptions,
            "dl": .pressures, "ss": .tackles
        ],
        "case_screen_right_bias_05": [
            "rb": .successfulRuns, "wr": .successfulAssignments, "ol": .protectionWins,
            "lb": .stops, "cb": .passBreakups
        ],
        "case_cover_zero_rush_06": [
            "qb": .drivesSecured, "wr": .bigPlays, "de": .sacks,
            "dl2": .pressures, "fs": .tackles
        ],
        "case_gap_integrity_07": [
            "rb": .successfulRuns, "ol": .blocks, "dl": .stops,
            "lb": .tackles, "ss": .tackles
        ],
        "case_dbl_move_sideline_08": [
            "wr": .bigPlays, "te": .receptions, "cb": .passBreakups,
            "fs": .interceptions, "lb": .stops
        ],
        "case_two_minute_spread_09": [
            "qb": .drivesSecured, "wr1": .receptions, "wr2": .bigPlays,
            "ol": .protectionWins, "de": .pressures
        ],
        "case_red_zone_stamp_10": [
            "te": .receptions, "rb": .brokenTackles, "dl": .stops,
            "cb": .passBreakups, "ss": .tackles
        ],

        // MARK: Band 5
        "case_final_drive_empty_01": [
            "qb": .drivesSecured, "wr1": .receptions, "wr2": .bigPlays,
            "de": .pressures, "cb": .coverageWins
        ],
        "case_goal_line_power_02": [
            "rb": .brokenTackles, "te": .successfulAssignments, "ol": .blocks,
            "dl": .stops, "lb": .tackles
        ],
        "case_trips_coverage_03": [
            "wr1": .receptions, "wr2": .bigPlays, "te": .successfulAssignments,
            "cb": .passBreakups, "ss": .coverageWins, "fs": .interceptions
        ],
        "case_hail_mary_04": [
            "qb": .drivesSecured, "wr1": .bigPlays, "wr2": .receptions,
            "dl": .pressures, "fs": .passBreakups
        ],
        "case_all_out_pressure_05": [
            "ol": .protectionWins, "te": .successfulAssignments, "dl": .sacks,
            "lb": .stops, "ss": .tackles
        ],
        "case_kneel_down_war_06": [
            "rb": .successfulRuns, "ol": .blocks, "dl": .stops,
            "lb": .tackles, "cb": .passBreakups
        ],
        "case_deep_crosser_07": [
            "qb": .successfulReads, "wr": .bigPlays, "te": .receptions,
            "lb": .coverageWins, "cb": .passBreakups, "fs": .tackles
        ],
        "case_edge_or_die_08": [
            "qb": .scrambleOpportunities, "ol": .protectionWins, "de": .sacks,
            "ss": .tackles, "fs": .tackles
        ],
        "case_two_point_call_09": [
            "qb": .drivesSecured, "rb": .keyBlocks, "wr": .receptions,
            "cb": .coverageWins, "lb": .tackles
        ],
        "case_victory_formation_10": [
            "wr": .receptions, "te": .successfulAssignments, "dl": .stops,
            "cb": .passBreakups, "fs": .interceptions
        ]
    ]
}
