import Foundation
import Testing
@testable import GameSceneGridiron

// MARK: - Phase 13A schema hardening tests
//
// Static validation of the Supabase profile schema. The SQL is not executed
// here — these tests pin the security contract so a regression (an "or true"
// policy, client-writable competitive stats, missing constraints) cannot ship.
//
// The schema text lives in `SchemaFixture.sql` (below) because the test runner
// only receives the app folder — the repo-root `supabase/schema.sql` is not
// part of the uploaded source. Keep `supabase/schema.sql` and this fixture
// byte-identical: schema.sql is what gets pasted into Supabase, the fixture is
// what the tests pin.
@MainActor
struct SchemaHardeningTests {

    private static var cachedSQL: String?

    /// Loads and normalizes the fixture schema: comments stripped, whitespace
    /// (including newlines) collapsed to single spaces, lowercased — so
    /// assertions match content, not formatting.
    private func schemaSQL() throws -> String {
        if let cached = Self.cachedSQL { return cached }
        let raw = SchemaFixture.sql
        let lines = raw.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("--") }
            .joined(separator: " ")
            .replacingOccurrences(of: "\t", with: " ")
        let flattened = lines.split(whereSeparator: { $0 == " " || $0 == "\r" })
            .joined(separator: " ")
            .lowercased()
        Self.cachedSQL = flattened
        return flattened
    }

    /// The (normalized) SQL statement beginning at `marker`, up to its
    /// terminating semicolon.
    private func statement(_ sql: String, starting marker: String) -> String {
        guard let range = sql.range(of: marker) else { return "" }
        return String(sql[range.lowerBound...].prefix(while: { $0 != ";" }))
    }

    /// A full plpgsql function block (functions contain inner semicolons, so
    /// `statement` cannot cut them out) — from the marker through `end; $$;`.
    private func function(_ sql: String, named marker: String) -> String {
        guard let start = sql.range(of: marker) else { return "" }
        guard let end = sql.range(of: "end; $$;", range: start.upperBound..<sql.endIndex) else {
            return String(sql[start.lowerBound...])
        }
        return String(sql[start.lowerBound..<end.upperBound])
    }

    // MARK: Private profiles are readable only by their owner

    @Test func privateProfileSelectIsOwnerOnly() throws {
        let sql = try schemaSQL()
        #expect(sql.contains("alter table public.profiles enable row level security"))
        let selectOwn = statement(sql, starting: "create policy \"profiles_select_own\"")
        #expect(selectOwn.contains("for select to authenticated"))
        #expect(selectOwn.contains("using (auth.uid() = id)"))
        #expect(!selectOwn.contains("anon"))
        #expect(!selectOwn.contains("or true"))
        // The legacy always-true policy must never be re-created (its drop
        // statement remains for upgrades from the unhardened Phase 13 schema).
        #expect(!sql.contains("create policy \"profiles_select_public\""))
    }

    @Test func privateProfileInsertAndUpdateAreOwnerOnly() throws {
        let sql = try schemaSQL()
        let insertOwn = statement(sql, starting: "create policy \"profiles_insert_own\"")
        #expect(insertOwn.contains("for insert to authenticated"))
        #expect(insertOwn.contains("with check (auth.uid() = id)"))
        let updateOwn = statement(sql, starting: "create policy \"profiles_update_own\"")
        #expect(updateOwn.contains("for update to authenticated"))
        #expect(updateOwn.contains("using (auth.uid() = id)"))
        #expect(updateOwn.contains("with check (auth.uid() = id)"))
    }

    @Test func anonymousUsersHaveNoPrivateProfileAccess() throws {
        let sql = try schemaSQL()
        #expect(sql.contains("revoke all on public.profiles from anon"))
        // The always-true shortcut must never reappear anywhere in the schema.
        #expect(!sql.contains("or true"))
        // No RLS policy grants anon access to the private table.
        for policy in ["profiles_select_own", "profiles_insert_own", "profiles_update_own"] {
            let block = statement(sql, starting: "create policy \"\(policy)\"")
            #expect(!block.contains(" anon"))
        }
    }

    @Test func profileRowCascadesWithAuthUser() throws {
        let sql = try schemaSQL()
        #expect(sql.contains("references auth.users (id) on delete cascade"))
    }

    // MARK: Public profile surface exposes only safe columns

    @Test func publicProfilesViewIsAuthenticatedOnly() throws {
        let sql = try schemaSQL()
        #expect(sql.contains("revoke all on public.public_profiles from anon"))
        #expect(sql.contains("grant select on public.public_profiles to authenticated"))
        // The combined anon+authenticated grant must never return for the
        // public view — table/view surfaces stay split. (The Phase 13D
        // is_username_available RPC is a deliberate exception: a single
        // boolean, explicitly revoked from public first, then granted to
        // anon + authenticated for the pre-signup probe.)
        let viewGrant = statement(sql, starting: "grant select on public.public_profiles")
        #expect(!viewGrant.contains("anon"))
        #expect(!sql.contains("grant select on public.public_profiles to anon, authenticated"))
    }

    @Test func publicProfilesViewExcludesPrivateData() throws {
        let sql = try schemaSQL()
        let view = statement(sql, starting: "create or replace view public.public_profiles")
        #expect(!view.isEmpty)
        for column in ["id", "username", "football_display_name", "created_at",
                       "global_rating", "career_games_played", "career_wins",
                       "career_losses", "career_cases_solved", "championships"] {
            #expect(view.contains(column), "public_profiles must expose \(column)")
        }
        for forbidden in ["first_name", "last_name", "email", "username_normalized",
                          "selected_franchise_id", "current_faction_id", "updated_at"] {
            #expect(!view.contains(forbidden), "public_profiles must not expose \(forbidden)")
        }
    }

    // MARK: Username normalization + case-insensitive uniqueness

    @Test func usernameUniquenessIsCaseInsensitive() throws {
        let sql = try schemaSQL()
        #expect(sql.contains("create unique index if not exists profiles_username_normalized_key"))
        #expect(sql.contains("on public.profiles (lower(username_normalized))"))
        #expect(sql.contains("username_normalized = lower(username)"))
        #expect(sql.contains("new.username_normalized := lower(new.username)"))
    }

    @Test func usernameShapeConstraintMatchesSwiftRules() throws {
        let sql = try schemaSQL()
        #expect(sql.contains("char_length(username) between 3 and 20"))
        // Case-preserved in the schema ('A-Za-z0-9_'); lowercased here by the
        // normalizer, so the expected pattern is written pre-folded.
        #expect(sql.contains("username ~ '^[a-za-z0-9_]+$'"))
    }

    // MARK: Football display name derives server-side

    @Test func footballDisplayNameDerivesServerSide() throws {
        let sql = try schemaSQL()
        #expect(sql.contains("new.football_display_name := case"))
        #expect(sql.contains("left(btrim(new.first_name), 1) || '. ' || btrim(new.last_name)"))
        #expect(sql.contains("create trigger profiles_sync_derived_fields"))
    }

    // MARK: Competitive stats are server-authoritative

    @Test func clientCannotUpdateCompetitiveStats() throws {
        let sql = try schemaSQL()
        #expect(sql.contains("revoke delete, update on public.profiles from authenticated"))
        let grantUpdate = statement(sql, starting: "grant update (")
        #expect(!grantUpdate.isEmpty)
        for column in ProfileUpdateFields.editable {
            #expect(grantUpdate.contains(column), "clients may update \(column)")
        }
        for stat in ProfileUpdateFields.serverOnly {
            #expect(!grantUpdate.contains(stat), "clients must not update \(stat)")
        }
    }

    @Test func triggerGuardIgnoresClientStatWrites() throws {
        let sql = try schemaSQL()
        let updateGuard = function(sql, named: "create or replace function public.guard_competitive_stats_update")
        #expect(updateGuard.contains("auth.uid() is not null"))
        for stat in ProfileUpdateFields.serverOnly {
            #expect(updateGuard.contains("new.\(stat)"), "guard pins \(stat)")
            #expect(updateGuard.contains(":= old.\(stat)"), "guard keeps server value for \(stat)")
        }
        let insertGuard = function(sql, named: "create or replace function public.guard_competitive_stats_insert")
        #expect(insertGuard.contains("auth.uid() is not null"))
        for stat in ProfileUpdateFields.serverOnly {
            #expect(insertGuard.contains("new.\(stat) := 0"), "client inserts get \(stat) = 0")
        }
    }

    @Test func negativeCompetitiveStatsAreRejected() throws {
        let sql = try schemaSQL()
        let constraint = statement(sql, starting: "add constraint competitive_stats_non_negative")
        #expect(!constraint.isEmpty)
        for stat in ProfileUpdateFields.serverOnly {
            #expect(constraint.contains("\(stat) >= 0"), "\(stat) cannot go negative")
        }
    }

    // MARK: Swift-side update payload contract

    @Test func clientUpdatePayloadExcludesCompetitiveStats() {
        let profile = UserProfile(
            authUserID: UUID(),
            username: "GridironKing",
            firstName: "Julius",
            lastName: "Hudson"
        )
        let values = ProfileUpdateFields.values(for: profile)
        let keys = Set(values.keys)
        #expect(keys == Set(ProfileUpdateFields.editable))
        #expect(keys.isDisjoint(with: ProfileUpdateFields.serverOnly))
        // Flatten [String: String?] for readable assertions — a nil value means
        // SQL NULL is written, never a "nil" string.
        let flat = values.mapValues { $0 ?? "<null>" }
        #expect(flat["username"] == "GridironKing")
        #expect(flat["first_name"] == "Julius")
        #expect(flat["last_name"] == "Hudson")
        #expect(flat["selected_franchise_id"] == "<null>")
        #expect(flat["current_faction_id"] == "<null>")
    }
}
