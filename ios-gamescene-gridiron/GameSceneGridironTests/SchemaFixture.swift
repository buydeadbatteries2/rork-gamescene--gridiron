import Foundation

/// Byte-identical snapshot of `supabase/schema.sql` (repo root). The test
/// runner only receives the app folder — the repo-root `supabase/` directory
/// is not part of the uploaded source — so the tests pin this copy. Keep the
/// two files in sync: schema.sql is what gets pasted into Supabase, this
/// fixture is what SchemaHardeningTests validates. Regenerate with
/// scripts/regenerate-schema-fixture.sh after editing schema.sql.
enum SchemaFixture {
    static let sql = #"""
-- GameScene: Gridiron — Supabase schema (Phase 13A: hardened accounts & profile; Phase 13D: signup trigger;
-- Phase 14/14A: leaderboards; Phase 14B: server-owned ranked seasons + match assignments)
-- Run in the Supabase SQL editor / migration pipeline. Safe to re-run (idempotent).
--
-- Phase 14B hardening: EVERY function below (SECURITY DEFINER and trigger
-- functions alike) runs with `set search_path = ''` and references only
-- schema-qualified objects (public.*, auth.*; built-ins resolve through
-- pg_catalog, which is always searched first).
--
-- Identity contract:
--   * profiles.id IS the Supabase Auth UUID (auth.users.id) — the ONLY canonical
--     relationship key. Usernames/emails are never foreign keys.
--   * PRIVATE: public.profiles — a signed-in user can only ever SELECT /
--     INSERT / UPDATE their OWN row (auth.uid() = id). Anonymous has NO access.
--     Real names (first_name, last_name) live only here.
--   * PUBLIC: public.public_profiles — a view exposing ONLY public identity and
--     competitive columns for future leaderboards / versus / factions. It never
--     exposes first_name, last_name, email or any authentication data.
--   * COMPETITIVE STATS ARE SERVER-AUTHORITATIVE: clients cannot set
--     global_rating, career_games_played, career_wins, career_losses,
--     career_cases_solved or championships. Blocked at the privilege layer
--     (column-level UPDATE grant) AND by a trigger guard. Only trusted backend
--     logic (service role / SQL editor, where no user JWT is present) may
--     change them.
--   * The service-role key stays server-side only. All client access goes
--     through RLS and the grants below.

-- ===========================================================================
-- 1. PRIVATE: profiles
-- ===========================================================================
create table if not exists public.profiles (
    id                     uuid primary key references auth.users (id) on delete cascade,
    username               text        not null check (char_length(username) between 3 and 20
                                       and username ~ '^[A-Za-z0-9_]+$'),
    username_normalized    text        not null,
    first_name             text        not null default '',
    last_name              text        not null default '',
    football_display_name  text        not null default '',
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now(),
    selected_franchise_id  uuid,
    current_faction_id     uuid,
    global_rating          int         not null default 0,
    career_games_played    int         not null default 0,
    career_wins            int         not null default 0,
    career_losses          int         not null default 0,
    career_cases_solved    int         not null default 0,
    championships          int         not null default 0,
    constraint username_normalized_matches check (username_normalized = lower(username))
);

-- Phase 14B: real names are bounded (≤ 50 characters each). Existing rows
-- are trimmed first so the constraints validate; handle_new_user trims
-- signup metadata the same way, and an oversized client UPDATE fails the
-- CHECK (safe failure — nothing is truncated silently on that path).
update public.profiles set
    first_name = left(btrim(first_name), 50),
    last_name  = left(btrim(last_name), 50)
where char_length(first_name) > 50 or char_length(last_name) > 50
   or first_name <> btrim(first_name) or last_name <> btrim(last_name);
alter table public.profiles drop constraint if exists profiles_first_name_length;
alter table public.profiles add constraint profiles_first_name_length check (char_length(first_name) <= 50);
alter table public.profiles drop constraint if exists profiles_last_name_length;
alter table public.profiles add constraint profiles_last_name_length check (char_length(last_name) <= 50);

-- Non-negative career statistics. (do-block keeps re-runs idempotent.)
do $$ begin
    alter table public.profiles
        add constraint competitive_stats_non_negative check (
            global_rating >= 0 and
            career_games_played >= 0 and
            career_wins >= 0 and
            career_losses >= 0 and
            career_cases_solved >= 0 and
            championships >= 0
        );
exception when duplicate_object then null; end $$;

-- Case-insensitive global username uniqueness: "GridironKing" and
-- "gridironking" collide.
create unique index if not exists profiles_username_normalized_key
    on public.profiles (lower(username_normalized));

-- ===========================================================================
-- 2. Server-side derivation — username normalization, football display name
--    ("Julius Hudson" -> "J. Hudson") and updated_at stay consistent even if
--    a client forgets or lies about them.
-- ===========================================================================
create or replace function public.sync_profile_derived_fields()
returns trigger language plpgsql set search_path = '' as $$
begin
    -- Trim only — never truncate here: an oversized name must FAIL the
    -- length CHECK rather than be silently shortened.
    new.first_name := btrim(new.first_name);
    new.last_name := btrim(new.last_name);
    new.username_normalized := lower(new.username);
    new.football_display_name := case
        when btrim(new.first_name) = '' and btrim(new.last_name) = '' then ''
        when btrim(new.last_name)  = '' then btrim(new.first_name)
        when btrim(new.first_name) = '' then btrim(new.last_name)
        else left(btrim(new.first_name), 1) || '. ' || btrim(new.last_name)
    end;
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists profiles_sync_username_normalized on public.profiles;
drop trigger if exists profiles_sync_derived_fields on public.profiles;
create trigger profiles_sync_derived_fields
    before insert or update on public.profiles
    for each row execute function public.sync_profile_derived_fields();

-- ===========================================================================
-- 3. Competitive stats guard — SERVER-AUTHORITATIVE.
--    Client requests carry a user JWT (auth.uid() is not null). Trusted
--    backend callers — service role, scheduled jobs, the SQL editor — have
--    auth.uid() null and are the ONLY writers allowed to change these values.
--    The guard silently ignores client-sent stats instead of erroring so the
--    client's idempotent full-profile upsert keeps working.
-- ===========================================================================
create or replace function public.guard_competitive_stats_update()
returns trigger language plpgsql set search_path = '' as $$
begin
    if auth.uid() is not null then
        new.global_rating       := old.global_rating;
        new.career_games_played := old.career_games_played;
        new.career_wins         := old.career_wins;
        new.career_losses       := old.career_losses;
        new.career_cases_solved := old.career_cases_solved;
        new.championships       := old.championships;
    end if;
    return new;
end;
$$;

create or replace function public.guard_competitive_stats_insert()
returns trigger language plpgsql set search_path = '' as $$
begin
    if auth.uid() is not null then
        new.global_rating       := 0;
        new.career_games_played := 0;
        new.career_wins         := 0;
        new.career_losses       := 0;
        new.career_cases_solved := 0;
        new.championships       := 0;
    end if;
    return new;
end;
$$;

drop trigger if exists profiles_guard_competitive_stats_update on public.profiles;
create trigger profiles_guard_competitive_stats_update
    before update on public.profiles
    for each row execute function public.guard_competitive_stats_update();

drop trigger if exists profiles_guard_competitive_stats_insert on public.profiles;
create trigger profiles_guard_competitive_stats_insert
    before insert on public.profiles
    for each row execute function public.guard_competitive_stats_insert();

-- ===========================================================================
-- 4. AUTH-USER PROFILE CREATION (Phase 13D, flow updated Phase 13E) — the
--    signup trigger. THE AUTHORITATIVE INITIAL PROFILE CREATION PATH: the
--    client never inserts the initial profile. The client passes username /
--    first_name / last_name as signup user metadata (never passwords or
--    sensitive data — email/password are handled by Supabase Auth itself),
--    and this function turns them into a profile row when the auth user is
--    created. With "Confirm email" DISABLED (Phase 13E) the signup returns
--    an active session and the app signs the player in immediately, reading
--    the trigger-created row by the authenticated UUID; if email
--    confirmation were ever re-enabled there would be NO session at signup
--    and the client could not insert its own profile anyway (RLS requires
--    auth.uid() = id) — which is exactly why the trigger owns creation. The existing derived-fields trigger (section 2) then
--    derives username_normalized + football_display_name + updated_at.
--    COMPETITIVE STATS ARE NEVER SET HERE — they keep their zero defaults
--    and remain server-authoritative (sections 1 + 3).
--    Idempotent: ON CONFLICT (id) DO NOTHING — repeated trigger execution
--    can never duplicate a profile for the same Auth UUID.
-- ===========================================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    requested_username text := coalesce(
        nullif(btrim(new.raw_user_meta_data->>'username'), ''),
        'PLAYER' || upper(left(replace(new.id::text, '-', ''), 8))
    );
begin
    -- Server-side username rule: 3–20 characters, letters/numbers/underscore
    -- only (mirrors the client's AccountValidator).
    if requested_username !~ '^[A-Za-z0-9_]{3,20}$' then
        raise exception 'USERNAME_INVALID';
    end if;
    begin
        insert into public.profiles (id, username, first_name, last_name)
        values (
            new.id,
            requested_username,
            -- Phase 14B: metadata is untrusted — trimmed and capped at 50.
            left(btrim(coalesce(new.raw_user_meta_data->>'first_name', '')), 50),
            left(btrim(coalesce(new.raw_user_meta_data->>'last_name', '')), 50)
        )
        on conflict (id) do nothing;
    exception
        when unique_violation then
            -- Case-insensitive username collision
            -- (profiles_username_normalized_key). Supabase Auth wraps trigger
            -- failures as "Database error saving new user"; the client maps
            -- that to a readable USERNAME ALREADY TAKEN message.
            raise exception 'USERNAME_TAKEN';
    end;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- Best-effort client pre-flight so a taken username surfaces as a readable
-- message BEFORE auth is consumed. SECURITY DEFINER (owner: postgres) is
-- deliberate — the caller may be anon (pre-signup); the function exposes a
-- single BOOLEAN, never row data. The trigger remains the atomic authority.
--
-- Phase 14B — documented tradeoff: an anon-callable availability check is
-- inherently a USERNAME-EXISTENCE ORACLE (anyone can learn whether a
-- username is registered). Usernames are public identity anyway (they are
-- shown on leaderboards), so the oracle leaks nothing private, but it is
-- bounded: input longer than 64 characters or not matching the username
-- format returns false WITHOUT any table lookup, each call is a single
-- index probe, the answer is only a boolean (never ids, names or emails),
-- and request volume is bounded by the Supabase API gateway rate limits
-- (anon has no identity the database could rate-limit on).
create or replace function public.is_username_available(requested text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select case
        when requested is null or char_length(requested) > 64 then false
        when btrim(requested) !~ '^[A-Za-z0-9_]{3,20}$' then false
        else not exists (
            select 1 from public.profiles p
            where lower(p.username_normalized) = lower(btrim(requested))
        )
    end;
$$;

revoke all on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to anon, authenticated;

-- ===========================================================================
-- 5. PRIVATE RLS — own row only. No "or true" anywhere; anonymous users get
--    nothing. The legacy Phase 13 "profiles_select_public" policy is dropped.
-- ===========================================================================
alter table public.profiles enable row level security;

drop policy if exists "profiles_select_public" on public.profiles;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
    for select to authenticated
    using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
    for insert to authenticated
    with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
    for update to authenticated
    using (auth.uid() = id)
    with check (auth.uid() = id);

-- Defense in depth at the privilege layer:
--   * anon: NO access to private profiles at all.
--   * authenticated: SELECT + INSERT their own row (RLS-enforced). UPDATE is
--     restricted to account-owned editable columns only — competitive stats
--     are not even submitable by clients (the trigger guard above is the
--     second wall). DELETE has no policy and no privilege.
revoke all on public.profiles from anon;
revoke delete, update on public.profiles from authenticated;
grant select, insert on public.profiles to authenticated;
grant update (username, first_name, last_name, selected_franchise_id, current_faction_id)
    on public.profiles to authenticated;

-- ===========================================================================
-- 6. PUBLIC: public_profiles — the safe public-facing profile source for
--    future leaderboards, versus and factions. The view runs with its owner's
--    privileges (security_invoker = false) so it can serve public columns to
--    other users, but it exposes ONLY the columns selected below — never
--    first_name, last_name, email or any authentication data. Franchise and
--    faction relationships will later be exposed through their own proper
--    tables, not through this view. All GameScene online features require an
--    account, so the view is authenticated-only: anon cannot query or scrape
--    the directory.
-- ===========================================================================
create or replace view public.public_profiles with (security_invoker = false) as
select
    id,
    username,
    football_display_name,
    created_at,
    global_rating,
    career_games_played,
    career_wins,
    career_losses,
    career_cases_solved,
    championships
from public.profiles;

revoke all on public.public_profiles from anon;
grant select on public.public_profiles to authenticated;

-- ===========================================================================
-- 7. PHASE 14 / 14A / 14B — GLOBAL LEADERBOARDS (server-verified ranked results)
--
--    Trust model (Phase 14B):
--      * The SERVER owns ranked seasons and per-game match assignments.
--        `start-ranked-match` (Edge Function, user from the JWT) calls
--        issue_ranked_match_assignment, which validates or creates the
--        season (difficulty locked server-side), chooses the five cases for
--        that game number from the private catalog, snapshots their
--        versions and EXACT adapted solutions, and records a persistent
--        match_id. Clients cannot invent seasons, match ids or case lists.
--      * `submit-ranked-result` sends raw facts only (no score, no user id)
--        and calls record_verified_ranked_result (service_role only), which
--        loads the assignment by match_id and verifies owner, season, game
--        number, difficulty, case ids, case versions and every placement
--        against the snapshotted exact solution, then computes the score
--        from ranked_scoring_config and updates career stats — all in one
--        transaction. It is the ONLY writer of ranked results and stats.
--      * Hints used / wrong placements are SELF-REPORTED local statistics.
--        They are stored for display only, are NOT server-verified, never
--        affect the score or leaderboard order, so purchased hints give no
--        competitive advantage.
--
--    Honesty note: solo GameScene cases run fully offline, so the app binary
--    holds the case content and therefore the solutions — bundled solutions
--    are NOT secret and this design makes NO anti-cheat claim against a
--    modified client. What the server guarantees is AUTHORITY: which cases a
--    ranked game uses, at which difficulty and version, that each match
--    scores once, the scoring formula, the leaderboard week and every stat
--    write. Future Versus/Faction cases will use distribution =
--    'server_assigned' (content never bundled) for stronger guarantees.
-- ===========================================================================

-- 7a. PRIVATE competitive case catalog. Populated by the GENERATED file
--     supabase/competitive_catalog.sql (paste after this schema). Solutions
--     are never readable by anon/authenticated: RLS on, no policies, and no
--     privileges. Only the service role reads them.
create table if not exists public.competitive_cases (
    case_id               text        primary key,
    case_version          int         not null check (case_version >= 1),
    -- AUTHORED tier = content difficulty of the case itself. It is NOT the
    -- season mode: the season mode (ranked_seasons.difficulty) decides the
    -- adaptation variant and the score multiplier; the tier only gates which
    -- cases a mode may be assigned (see issue_ranked_match_assignment).
    difficulty            text        not null check (difficulty in ('rookie', 'pro', 'all_pro', 'hall_of_famer')),
    -- Calibrated 1–100 score (CaseDifficultyCalibration) — never a default.
    difficulty_score      int         not null,
    band                  int         not null default 0,
    missing_count         int         not null check (missing_count between 1 and 8),
    active                boolean     not null default true,
    competitive_eligible  boolean     not null default true,
    -- 'client_bundled' = shipped in the app (solo leaderboards);
    -- 'server_assigned' = reserved for future Versus/Faction matches.
    distribution          text        not null default 'client_bundled',
    fingerprint           text        not null,
    -- Phase 14B: EXACT adapted solution per adapter variant
    -- {"rookie": [{player_key, slot_key, profile}…], "pro_early": […],
    --  "pro": […], "all_pro": […], "hall_of_famer": […]}
    solutions             jsonb       not null,
    updated_at            timestamptz not null default now()
);

-- Idempotent upgrades for a table created by an earlier paste.
alter table public.competitive_cases add column if not exists distribution text not null default 'client_bundled';
alter table public.competitive_cases alter column difficulty_score drop default;
alter table public.competitive_cases drop constraint if exists competitive_cases_difficulty_score_check;
alter table public.competitive_cases add constraint competitive_cases_difficulty_score_check
    check (difficulty_score between 1 and 100);
alter table public.competitive_cases drop constraint if exists competitive_cases_distribution_check;
alter table public.competitive_cases add constraint competitive_cases_distribution_check
    check (distribution in ('client_bundled', 'server_assigned'));
-- NOT VALID: Phase 14A rows (per-difficulty solutions) are not re-checked
-- until competitive_catalog.sql re-upserts them with the five variants.
alter table public.competitive_cases drop constraint if exists competitive_cases_solution_variants_check;
alter table public.competitive_cases add constraint competitive_cases_solution_variants_check
    check (solutions ?& array['rookie', 'pro_early', 'pro', 'all_pro', 'hall_of_famer']) not valid;
create index if not exists competitive_cases_band_idx on public.competitive_cases (band, distribution);

alter table public.competitive_cases enable row level security;
alter table public.competitive_cases force row level security;
revoke all on public.competitive_cases from public;
revoke all on public.competitive_cases from anon, authenticated;

-- 7a.1 Catalog drift detection — ONE ROW PER DISTRIBUTION. The generated
--      competitive_catalog.sql owns the 'client_bundled' row; a future
--      server-assigned catalog records its own checksum under
--      'server_assigned'. Service role only. (A Phase 14A single-row table,
--      keyed by `id`, is replaced; the next catalog paste refills it.)
do $$ begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'competitive_catalog_meta' and column_name = 'id'
    ) then
        drop table public.competitive_catalog_meta;
    end if;
end $$;

create table if not exists public.competitive_catalog_meta (
    distribution         text        primary key check (distribution in ('client_bundled', 'server_assigned')),
    case_count           int         not null,
    catalog_fingerprint  text        not null,
    expected_checksum    text        not null,
    updated_at           timestamptz not null default now()
);

alter table public.competitive_catalog_meta enable row level security;
revoke all on public.competitive_catalog_meta from public;
revoke all on public.competitive_catalog_meta from anon, authenticated;

-- md5 over one canonical line per ACTIVE case OF ONE DISTRIBUTION, ordered
-- by case_id (C collation): id|version|difficulty|score|band|missing|active|
-- eligible|distribution|fingerprint|md5(solutions jsonb text). The export
-- script and the iOS tests build the identical lines. server_assigned rows
-- never affect the client_bundled checksum.
drop function if exists public.competitive_catalog_checksum();
create or replace function public.competitive_catalog_checksum(p_distribution text default 'client_bundled')
returns text
language sql
stable
security definer
set search_path = ''
as $$
    select md5(coalesce(string_agg(
        c.case_id || '|' || c.case_version || '|' || c.difficulty || '|' || c.difficulty_score || '|'
            || c.band || '|' || c.missing_count || '|'
            || (case when c.active then 'true' else 'false' end) || '|'
            || (case when c.competitive_eligible then 'true' else 'false' end) || '|'
            || c.distribution || '|' || c.fingerprint || '|' || md5(c.solutions::text),
        E'\n' order by c.case_id collate "C"
    ), ''))
    from public.competitive_cases c
    where c.active and c.distribution = p_distribution;
$$;

revoke all on function public.competitive_catalog_checksum(text) from public, anon, authenticated;
grant execute on function public.competitive_catalog_checksum(text) to service_role;

-- 7a.2 Case version history (Phase 14B). Every (case, version) keeps the one
--      fingerprint it shipped with. The trigger rejects a version regression
--      and a changed fingerprint without a version bump — the same rules the
--      generator enforces through competitive_case_versions.json.
create table if not exists public.competitive_case_version_history (
    case_id       text        not null,
    case_version  int         not null check (case_version >= 1),
    fingerprint   text        not null,
    recorded_at   timestamptz not null default now(),
    primary key (case_id, case_version)
);

alter table public.competitive_case_version_history enable row level security;
revoke all on public.competitive_case_version_history from public;
revoke all on public.competitive_case_version_history from anon, authenticated;

insert into public.competitive_case_version_history (case_id, case_version, fingerprint)
select c.case_id, c.case_version, c.fingerprint from public.competitive_cases c
on conflict (case_id, case_version) do nothing;

create or replace function public.enforce_case_version_history()
returns trigger language plpgsql set search_path = '' as $$
declare
    v_max  int;
    v_fp   text;
begin
    if tg_op = 'UPDATE' then
        if new.case_version < old.case_version then
            raise exception 'CASE_VERSION_REGRESSION: % % -> %', new.case_id, old.case_version, new.case_version;
        end if;
        if new.case_version = old.case_version and new.fingerprint <> old.fingerprint then
            raise exception 'CASE_FINGERPRINT_CHANGED_WITHOUT_VERSION_BUMP: % v%', new.case_id, new.case_version;
        end if;
    end if;
    select max(h.case_version) into v_max
    from public.competitive_case_version_history h where h.case_id = new.case_id;
    if v_max is not null and new.case_version < v_max then
        raise exception 'CASE_VERSION_REGRESSION: % % < %', new.case_id, new.case_version, v_max;
    end if;
    select h.fingerprint into v_fp
    from public.competitive_case_version_history h
    where h.case_id = new.case_id and h.case_version = new.case_version;
    if v_fp is not null and v_fp <> new.fingerprint then
        raise exception 'CASE_FINGERPRINT_CHANGED_WITHOUT_VERSION_BUMP: % v%', new.case_id, new.case_version;
    end if;
    insert into public.competitive_case_version_history (case_id, case_version, fingerprint)
    values (new.case_id, new.case_version, new.fingerprint)
    on conflict (case_id, case_version) do nothing;
    return new;
end;
$$;

revoke all on function public.enforce_case_version_history() from public, anon, authenticated;
drop trigger if exists competitive_cases_version_history on public.competitive_cases;
create trigger competitive_cases_version_history
    before insert or update on public.competitive_cases
    for each row execute function public.enforce_case_version_history();

-- 7b. The ONE scoring configuration. Edit the row (never code) to rebalance;
--     the score function reads it on every verified result.
create table if not exists public.ranked_scoring_config (
    id                          int          primary key default 1 check (id = 1),
    quarter_solved_points       int          not null,
    game_win_points             int          not null,
    overtime_win_points         int          not null,
    perfect_regulation_points   int          not null,
    -- Phase 14B: retired (pinned to 0). Hints/wrong placements are
    -- self-reported and must never earn points.
    no_hints_points             int          not null,
    no_wrong_placements_points  int          not null,
    rookie_multiplier           numeric(4,2) not null,
    pro_multiplier              numeric(4,2) not null,
    all_pro_multiplier          numeric(4,2) not null,
    hall_of_famer_multiplier    numeric(4,2) not null,
    weekly_best_games           int          not null,
    alltime_best_games          int          not null,
    provisional_min_games       int          not null,
    submissions_per_hour        int          not null,
    -- Phase 14A: leaderboard-week trust window for client completion times.
    max_offline_age_days        int          not null default 30,
    min_game_duration_seconds   int          not null default 20,
    max_trusted_game_hours      int          not null default 168,
    max_clock_skew_seconds      int          not null default 300,
    -- Phase 14B: ranked protocol + assignment policy.
    min_ranked_protocol         int          not null default 2,
    assignment_prefetch_games   int          not null default 3,
    assignment_ttl_hours        int          not null default 336,
    assignment_submit_grace_days int         not null default 30,
    assignments_per_hour        int          not null default 60,
    updated_at                  timestamptz  not null default now()
);

alter table public.ranked_scoring_config add column if not exists max_offline_age_days         int not null default 30;
alter table public.ranked_scoring_config add column if not exists min_game_duration_seconds    int not null default 20;
alter table public.ranked_scoring_config add column if not exists max_trusted_game_hours       int not null default 168;
alter table public.ranked_scoring_config add column if not exists max_clock_skew_seconds       int not null default 300;
alter table public.ranked_scoring_config add column if not exists min_ranked_protocol          int not null default 2;
alter table public.ranked_scoring_config add column if not exists assignment_prefetch_games    int not null default 3;
alter table public.ranked_scoring_config add column if not exists assignment_ttl_hours         int not null default 336;
alter table public.ranked_scoring_config add column if not exists assignment_submit_grace_days int not null default 30;
alter table public.ranked_scoring_config add column if not exists assignments_per_hour         int not null default 60;
alter table public.ranked_scoring_config drop constraint if exists ranked_scoring_config_no_self_reported_bonus;

insert into public.ranked_scoring_config (
    id, quarter_solved_points, game_win_points, overtime_win_points,
    perfect_regulation_points, no_hints_points, no_wrong_placements_points,
    rookie_multiplier, pro_multiplier, all_pro_multiplier, hall_of_famer_multiplier,
    weekly_best_games, alltime_best_games, provisional_min_games, submissions_per_hour,
    max_offline_age_days, min_game_duration_seconds, max_trusted_game_hours, max_clock_skew_seconds,
    min_ranked_protocol, assignment_prefetch_games, assignment_ttl_hours, assignment_submit_grace_days,
    assignments_per_hour
) values (1, 10, 10, 5, 5, 0, 0, 1.00, 1.25, 1.50, 2.00, 10, 25, 5, 30, 30, 20, 168, 300, 2, 3, 336, 30, 60)
on conflict (id) do update set
    quarter_solved_points        = excluded.quarter_solved_points,
    game_win_points              = excluded.game_win_points,
    overtime_win_points          = excluded.overtime_win_points,
    perfect_regulation_points    = excluded.perfect_regulation_points,
    no_hints_points              = excluded.no_hints_points,
    no_wrong_placements_points   = excluded.no_wrong_placements_points,
    rookie_multiplier            = excluded.rookie_multiplier,
    pro_multiplier               = excluded.pro_multiplier,
    all_pro_multiplier           = excluded.all_pro_multiplier,
    hall_of_famer_multiplier     = excluded.hall_of_famer_multiplier,
    weekly_best_games            = excluded.weekly_best_games,
    alltime_best_games           = excluded.alltime_best_games,
    provisional_min_games        = excluded.provisional_min_games,
    submissions_per_hour         = excluded.submissions_per_hour,
    max_offline_age_days         = excluded.max_offline_age_days,
    min_game_duration_seconds    = excluded.min_game_duration_seconds,
    max_trusted_game_hours       = excluded.max_trusted_game_hours,
    max_clock_skew_seconds       = excluded.max_clock_skew_seconds,
    min_ranked_protocol          = excluded.min_ranked_protocol,
    assignment_prefetch_games    = excluded.assignment_prefetch_games,
    assignment_ttl_hours         = excluded.assignment_ttl_hours,
    assignment_submit_grace_days = excluded.assignment_submit_grace_days,
    assignments_per_hour         = excluded.assignments_per_hour,
    updated_at                   = now();

-- Self-reported stats can never be re-enabled as score bonuses.
alter table public.ranked_scoring_config add constraint ranked_scoring_config_no_self_reported_bonus
    check (no_hints_points = 0 and no_wrong_placements_points = 0);
alter table public.ranked_scoring_config drop constraint if exists ranked_scoring_config_bounds;
alter table public.ranked_scoring_config add constraint ranked_scoring_config_bounds check (
    min_ranked_protocol >= 1
    and assignment_prefetch_games between 1 and 12
    and assignment_ttl_hours >= 1
    and assignment_submit_grace_days >= 0
    and assignments_per_hour >= 1
    and submissions_per_hour >= 1
);

alter table public.ranked_scoring_config enable row level security;
revoke all on public.ranked_scoring_config from public;
revoke all on public.ranked_scoring_config from anon, authenticated;

-- 7c. SERVER-OWNED ranked seasons (Phase 14B). One row per season; the
--     difficulty is locked at creation and the schedule seed (server
--     random, never sent to clients) drives case selection. Created ONLY by
--     issue_ranked_match_assignment; starting a new season closes the
--     user's other active seasons. Clients have no access.
create table if not exists public.ranked_seasons (
    season_id      uuid        primary key default gen_random_uuid(),
    user_id        uuid        not null references public.profiles (id) on delete cascade,
    difficulty     text        not null check (difficulty in ('rookie', 'pro', 'all_pro', 'hall_of_famer')),
    schedule_seed  text        not null,
    status         text        not null default 'active' check (status in ('active', 'closed')),
    created_at     timestamptz not null default now(),
    closed_at      timestamptz,
    constraint ranked_seasons_season_user_key unique (season_id, user_id)
);
create index if not exists ranked_seasons_user_idx on public.ranked_seasons (user_id, status);

alter table public.ranked_seasons enable row level security;
revoke all on public.ranked_seasons from public;
revoke all on public.ranked_seasons from anon, authenticated;

-- 7d. Verified ranked results. One row per competitive match id (unique),
--     one per (user, season, game number). Written ONLY by
--     record_verified_ranked_result — clients have no INSERT/UPDATE/DELETE.
create table if not exists public.ranked_game_results (
    id                          uuid         primary key default gen_random_uuid(),
    match_id                    uuid         not null,
    user_id                     uuid         not null references public.profiles (id) on delete cascade,
    season_id                   uuid,
    game_number                 int          not null check (game_number between 1 and 12),
    difficulty                  text         not null check (difficulty in ('rookie', 'pro', 'all_pro', 'hall_of_famer')),
    regulation_quarters_solved  int          not null check (regulation_quarters_solved between 0 and 4),
    regulation_quarters_lost    int          not null check (regulation_quarters_lost between 0 and 4),
    game_won                    boolean      not null,
    overtime_played             boolean      not null,
    overtime_won                boolean      not null,
    -- SELF-REPORTED local statistics (never verified, never scored).
    wrong_placements            int          not null check (wrong_placements >= 0),
    hints_used                  int          not null check (hints_used >= 0),
    base_score                  int          not null check (base_score >= 0),
    difficulty_multiplier       numeric(4,2) not null check (difficulty_multiplier > 0),
    final_score                 int          not null check (final_score >= 0),
    verified                    boolean      not null default true,
    case_results                jsonb        not null default '[]'::jsonb,
    started_at                  timestamptz,
    completed_at                timestamptz,
    game_version                text,
    -- Phase 14A: the instant that decides the leaderboard WEEK — the
    -- server-validated completion time, or the receipt time when the
    -- client's timestamps cannot be trusted. Set only by
    -- record_verified_ranked_result.
    leaderboard_at              timestamptz  not null default now(),
    leaderboard_at_source       text         not null default 'received_at'
                                check (leaderboard_at_source in ('completed_at', 'received_at')),
    created_at                  timestamptz  not null default now(),
    constraint ranked_game_results_match_id_key unique (match_id),
    constraint ranked_game_results_quarters_check
        check (regulation_quarters_solved + regulation_quarters_lost = 4),
    constraint ranked_game_results_overtime_check
        check (overtime_played or not overtime_won)
);

alter table public.ranked_game_results add column if not exists leaderboard_at timestamptz not null default now();
alter table public.ranked_game_results add column if not exists leaderboard_at_source text not null default 'received_at';
alter table public.ranked_game_results add column if not exists assignment_id uuid;
alter table public.ranked_game_results add column if not exists ranked_protocol int;

-- Phase 14B migration: results without a season (Phase 14 clients that never
-- sent one) cannot be tied to a server season. They are copied VERBATIM into
-- a private archive and removed from the ranked table. Career stats already
-- earned from them are left untouched (they were verified games).
create table if not exists public.ranked_game_results_unseasoned_archive (
    id           uuid        primary key,
    user_id      uuid        not null,
    row_data     jsonb       not null,
    archived_at  timestamptz not null default now()
);
alter table public.ranked_game_results_unseasoned_archive enable row level security;
revoke all on public.ranked_game_results_unseasoned_archive from public;
revoke all on public.ranked_game_results_unseasoned_archive from anon, authenticated;

insert into public.ranked_game_results_unseasoned_archive (id, user_id, row_data)
select r.id, r.user_id, to_jsonb(r) from public.ranked_game_results r where r.season_id is null
on conflict (id) do nothing;
delete from public.ranked_game_results r where r.season_id is null;
alter table public.ranked_game_results alter column season_id set not null;

-- Phase 14A client-generated season ids become CLOSED server seasons (their
-- results stay ranked; no new assignments can be issued for them).
insert into public.ranked_seasons (season_id, user_id, difficulty, schedule_seed, status, closed_at)
select distinct on (r.season_id) r.season_id, r.user_id, r.difficulty, md5(r.season_id::text || ':legacy'), 'closed', now()
from public.ranked_game_results r
where not exists (select 1 from public.ranked_seasons s where s.season_id = r.season_id)
order by r.season_id, r.created_at
on conflict (season_id) do nothing;

alter table public.ranked_game_results drop constraint if exists ranked_game_results_season_fk;
alter table public.ranked_game_results add constraint ranked_game_results_season_fk
    foreign key (season_id, user_id) references public.ranked_seasons (season_id, user_id) on delete cascade not valid;

drop index if exists public.ranked_game_results_season_game_key;
create unique index ranked_game_results_season_game_key
    on public.ranked_game_results (user_id, season_id, game_number);

create index if not exists ranked_game_results_created_at_idx
    on public.ranked_game_results (created_at);
create index if not exists ranked_game_results_leaderboard_at_idx
    on public.ranked_game_results (leaderboard_at);
create index if not exists ranked_game_results_user_idx
    on public.ranked_game_results (user_id, final_score desc);
create index if not exists ranked_game_results_season_idx
    on public.ranked_game_results (season_id, game_number);

alter table public.ranked_game_results enable row level security;

drop policy if exists "ranked_results_select_own" on public.ranked_game_results;
create policy "ranked_results_select_own" on public.ranked_game_results
    for select to authenticated
    using (auth.uid() = user_id);

revoke all on public.ranked_game_results from public;
revoke all on public.ranked_game_results from anon;
revoke insert, update, delete, truncate, references, trigger on public.ranked_game_results from authenticated;
revoke insert, update, delete on public.ranked_game_results from authenticated;
grant select on public.ranked_game_results to authenticated;

-- 7e. PRIVATE ranked match assignments (Phase 14B). Issued ONLY by
--     issue_ranked_match_assignment (service role). Each row pins the five
--     cases (4 regulation + overtime) of one season game, their versions,
--     the solution variant and the EXACT expected solutions snapshotted at
--     issue time, plus the catalog fingerprint. Clients cannot read, insert
--     or update it.
create table if not exists public.ranked_match_assignments (
    assignment_id        uuid        primary key default gen_random_uuid(),
    match_id             uuid        not null,
    user_id              uuid        not null references public.profiles (id) on delete cascade,
    season_id            uuid        not null,
    game_number          int         not null check (game_number between 1 and 12),
    difficulty           text        not null check (difficulty in ('rookie', 'pro', 'all_pro', 'hall_of_famer')),
    solution_variant     text        not null check (solution_variant in ('rookie', 'pro_early', 'pro', 'all_pro', 'hall_of_famer')),
    case_ids             text[]      not null check (cardinality(case_ids) = 5),
    case_versions        int[]       not null check (cardinality(case_versions) = 5),
    expected_solutions   jsonb       not null check (jsonb_typeof(expected_solutions) = 'array'
                                                     and jsonb_array_length(expected_solutions) = 5),
    catalog_fingerprint  text        not null,
    issued_at            timestamptz not null default now(),
    expires_at           timestamptz not null,
    replaced_at          timestamptz,
    consumed_result_id   uuid,
    consumed_at          timestamptz,
    constraint ranked_match_assignments_match_id_key unique (match_id),
    constraint ranked_match_assignments_season_fk
        foreign key (season_id, user_id) references public.ranked_seasons (season_id, user_id) on delete cascade,
    constraint ranked_match_assignments_consumed_check
        check ((consumed_result_id is null) = (consumed_at is null)),
    constraint ranked_match_assignments_expiry_check check (expires_at > issued_at)
);
create unique index if not exists ranked_match_assignments_live_key
    on public.ranked_match_assignments (season_id, game_number) where replaced_at is null;
create index if not exists ranked_match_assignments_user_idx
    on public.ranked_match_assignments (user_id, issued_at);

alter table public.ranked_match_assignments enable row level security;
alter table public.ranked_match_assignments force row level security;
revoke all on public.ranked_match_assignments from public;
revoke all on public.ranked_match_assignments from anon, authenticated;

alter table public.ranked_game_results drop constraint if exists ranked_game_results_assignment_fk;
alter table public.ranked_game_results add constraint ranked_game_results_assignment_fk
    foreign key (assignment_id) references public.ranked_match_assignments (assignment_id) on delete cascade not valid;
alter table public.ranked_game_results drop constraint if exists ranked_game_results_assignment_required;
alter table public.ranked_game_results add constraint ranked_game_results_assignment_required
    check (assignment_id is not null and ranked_protocol is not null) not valid;
create unique index if not exists ranked_game_results_assignment_key
    on public.ranked_game_results (assignment_id) where assignment_id is not null;

-- 7f. Submission audit (service role only). Rate limiting no longer counts
--     these rows (that check-then-insert raced); see 7g.
create table if not exists public.ranked_submission_attempts (
    id          bigserial   primary key,
    user_id     uuid        not null,
    match_id    uuid,
    outcome     text        not null check (outcome in ('verified', 'duplicate', 'rejected', 'error')),
    reason      text,
    created_at  timestamptz not null default now()
);
create index if not exists ranked_submission_attempts_user_idx
    on public.ranked_submission_attempts (user_id, created_at);

alter table public.ranked_submission_attempts enable row level security;
revoke all on public.ranked_submission_attempts from public;
revoke all on public.ranked_submission_attempts from anon, authenticated;
revoke all on sequence public.ranked_submission_attempts_id_seq from public, anon, authenticated;

-- 7g. ATOMIC rate limiting (Phase 14B). Fixed hourly windows per (user,
--     bucket). One INSERT … ON CONFLICT DO UPDATE … WHERE count < limit
--     statement: the row lock serializes concurrent callers, so exactly
--     `limit` calls per window succeed no matter how many race. Buckets:
--     'submit' (submissions_per_hour), 'assign' (assignments_per_hour).
create table if not exists public.ranked_rate_limits (
    user_id       uuid        not null,
    bucket        text        not null check (bucket in ('submit', 'assign')),
    window_start  timestamptz not null,
    count         int         not null check (count >= 0),
    primary key (user_id, bucket, window_start)
);

alter table public.ranked_rate_limits enable row level security;
revoke all on public.ranked_rate_limits from public;
revoke all on public.ranked_rate_limits from anon, authenticated;

create or replace function public.consume_ranked_rate_limit(p_user_id uuid, p_bucket text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_limit   int;
    v_window  timestamptz := date_trunc('hour', now());
    v_count   int;
begin
    if p_user_id is null then
        raise exception 'INVALID_ARGUMENTS';
    end if;
    select case p_bucket when 'submit' then c.submissions_per_hour
                         when 'assign' then c.assignments_per_hour end
      into v_limit
      from public.ranked_scoring_config c where c.id = 1;
    if v_limit is null then
        raise exception 'INVALID_RATE_LIMIT_BUCKET';
    end if;
    delete from public.ranked_rate_limits l
    where l.user_id = p_user_id and l.window_start < now() - interval '2 days';
    insert into public.ranked_rate_limits as l (user_id, bucket, window_start, count)
    values (p_user_id, p_bucket, v_window, 1)
    on conflict (user_id, bucket, window_start)
        do update set count = l.count + 1 where l.count < v_limit
    returning l.count into v_count;
    return v_count is not null;
end;
$$;

revoke all on function public.consume_ranked_rate_limit(uuid, text) from public, anon, authenticated;
grant execute on function public.consume_ranked_rate_limit(uuid, text) to service_role;

-- 7h. Helpers (internal).
-- Which adapter variant the client's CaseDifficultyAdapter produces for a
-- season mode + game number (port of DifficultyResolver; verified by
-- Phase14BAdapterParityTests): Pro games 1–3 resolve to the rookie tier
-- (max 4 missing players) but keep the Pro profile pool.
create or replace function public.ranked_solution_variant(p_difficulty text, p_game_number int)
returns text
language sql
immutable
set search_path = ''
as $$
    select case
        when p_difficulty = 'rookie' then 'rookie'
        when p_difficulty = 'pro' and p_game_number <= 3 then 'pro_early'
        when p_difficulty = 'pro' then 'pro'
        when p_difficulty = 'all_pro' then 'all_pro'
        when p_difficulty = 'hall_of_famer' then 'hall_of_famer'
    end;
$$;

create or replace function public.ranked_tier_rank(p_difficulty text)
returns int
language sql
immutable
set search_path = ''
as $$
    select case p_difficulty when 'rookie' then 0 when 'pro' then 1 when 'all_pro' then 2 when 'hall_of_famer' then 3 end;
$$;

-- Strict JSON integer reader for case results (rejects strings, fractions,
-- out-of-range values).
create or replace function public.ranked_json_int(p_value jsonb, p_min int, p_max int)
returns int
language plpgsql
immutable
set search_path = ''
as $$
declare
    v numeric;
begin
    if p_value is null or jsonb_typeof(p_value) <> 'number' then
        raise exception 'INVALID_CASE_RESULTS';
    end if;
    v := (p_value #>> '{}')::numeric;
    if v <> trunc(v) or v < p_min or v > p_max then
        raise exception 'INVALID_CASE_RESULTS';
    end if;
    return v::int;
end;
$$;

revoke all on function public.ranked_solution_variant(text, int) from public, anon, authenticated;
revoke all on function public.ranked_tier_rank(text) from public, anon, authenticated;
revoke all on function public.ranked_json_int(jsonb, int, int) from public, anon, authenticated;

-- 7i. ASSIGNMENT ISSUER (Phase 14B) — called by the start-ranked-match Edge
--     Function (service_role) with the JWT user. One game per call.
--
--     Season: p_season_id null starts a NEW season (game 1 only) with a
--     server UUID and a server-random schedule seed, and closes the user's
--     other active seasons. A given p_season_id must exist, belong to the
--     user, be active and match p_difficulty (the lock) — an arbitrary or
--     foreign season id is rejected.
--
--     Game window: 1–12, not already recorded, and at most
--     assignment_prefetch_games beyond the highest recorded game (offline
--     policy A: a bounded prefetch while online).
--
--     Idempotent: an unexpired, unconsumed live assignment for the same
--     (season, game) is returned again (reused = true). An expired one is
--     marked replaced and a fresh one is issued.
--
--     Case selection (authored tier vs season mode): each quarter q uses
--     catalog band q (overtime: band 5). Eligible = active, competitive,
--     client_bundled cases of that band; All-Pro and Hall of Famer seasons
--     additionally exclude rookie-TIER cases. The eligible pool is ordered
--     by calibrated difficulty_score plus a seeded ±2 jitter, and each mode
--     takes a window of 12 consecutive cases starting at
--     floor(mode_index * (n - 12) / 3) (rookie 0 = easiest … HoF 3 =
--     hardest). Game g uses window position g-1. So a Hall of Famer season
--     can never be assigned the easy end of the catalog, and the ×2
--     multiplier always applies to the hardest window. The solution
--     variant follows the app's difficulty progression
--     (ranked_solution_variant).
drop function if exists public.issue_ranked_match_assignment(uuid, uuid, int, text);
create or replace function public.issue_ranked_match_assignment(
    p_user_id      uuid,
    p_season_id    uuid,
    p_game_number  int,
    p_difficulty   text
)
returns table (
    assignment_id        uuid,
    match_id             uuid,
    season_id            uuid,
    game_number          int,
    difficulty           text,
    case_ids             text[],
    case_versions        int[],
    issued_at            timestamptz,
    expires_at           timestamptz,
    catalog_fingerprint  text,
    reused               boolean
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
    cfg          public.ranked_scoring_config%rowtype;
    v_season     public.ranked_seasons%rowtype;
    v_asg        public.ranked_match_assignments%rowtype;
    v_fp         text;
    v_variant    text;
    v_mode       int;
    v_floor      int;
    v_offset     int;
    v_band       int;
    v_n          int;
    v_high       int;
    v_cid        text;
    v_ver        int;
    v_sol        jsonb;
    v_ids        text[] := '{}';
    v_versions   int[] := '{}';
    v_solutions  jsonb := '[]'::jsonb;
begin
    if p_user_id is null or p_game_number is null or p_difficulty is null then
        raise exception 'INVALID_ARGUMENTS';
    end if;
    if p_difficulty not in ('rookie', 'pro', 'all_pro', 'hall_of_famer') then
        raise exception 'INVALID_DIFFICULTY';
    end if;
    if p_game_number not between 1 and 12 then
        raise exception 'INVALID_GAME_NUMBER';
    end if;
    select * into cfg from public.ranked_scoring_config c where c.id = 1;
    if not found then
        raise exception 'SCORING_CONFIG_MISSING';
    end if;
    select m.catalog_fingerprint into v_fp
    from public.competitive_catalog_meta m where m.distribution = 'client_bundled';
    if v_fp is null then
        raise exception 'CATALOG_NOT_LOADED';
    end if;

    -- Season: create (game 1, no id) or validate.
    if p_season_id is null then
        if p_game_number <> 1 then
            raise exception 'SEASON_REQUIRED';
        end if;
        insert into public.ranked_seasons (user_id, difficulty, schedule_seed)
        values (p_user_id, p_difficulty, md5(gen_random_uuid()::text || clock_timestamp()::text))
        returning * into v_season;
        update public.ranked_seasons s set status = 'closed', closed_at = now()
        where s.user_id = p_user_id and s.status = 'active' and s.season_id <> v_season.season_id;
    else
        select * into v_season from public.ranked_seasons s where s.season_id = p_season_id for update;
        if not found then
            raise exception 'SEASON_NOT_FOUND';
        end if;
        if v_season.user_id <> p_user_id then
            raise exception 'SEASON_CONFLICT';
        end if;
        -- Status BEFORE difficulty: a CLOSED historical season always answers
        -- season_closed (never a difficulty mismatch), so the client clears
        -- the stale pointer and goes through the fresh-season flow instead of
        -- retrying forever. A closed season is never resurrected here.
        if v_season.status <> 'active' then
            raise exception 'SEASON_CLOSED';
        end if;
        if v_season.difficulty <> p_difficulty then
            raise exception 'SEASON_DIFFICULTY_MISMATCH';
        end if;
    end if;

    -- Game window.
    if exists (
        select 1 from public.ranked_game_results r
        where r.user_id = p_user_id and r.season_id = v_season.season_id and r.game_number = p_game_number
    ) then
        raise exception 'GAME_ALREADY_RECORDED';
    end if;
    select coalesce(max(r.game_number), 0) into v_high
    from public.ranked_game_results r
    where r.user_id = p_user_id and r.season_id = v_season.season_id;
    if p_game_number > v_high + cfg.assignment_prefetch_games then
        raise exception 'GAME_OUT_OF_WINDOW';
    end if;

    -- Reuse a live assignment when possible.
    select * into v_asg from public.ranked_match_assignments a
    where a.season_id = v_season.season_id and a.game_number = p_game_number and a.replaced_at is null
    for update;
    if found then
        if v_asg.consumed_result_id is not null then
            raise exception 'GAME_ALREADY_RECORDED';
        end if;
        if v_asg.expires_at > now() then
            return query select v_asg.assignment_id, v_asg.match_id, v_asg.season_id, v_asg.game_number,
                                v_asg.difficulty, v_asg.case_ids, v_asg.case_versions, v_asg.issued_at,
                                v_asg.expires_at, v_asg.catalog_fingerprint, true;
            return;
        end if;
        update public.ranked_match_assignments a set replaced_at = now()
        where a.assignment_id = v_asg.assignment_id;
    end if;

    -- Select the five cases.
    v_variant := public.ranked_solution_variant(p_difficulty, p_game_number);
    v_mode := public.ranked_tier_rank(p_difficulty);
    v_floor := case when p_difficulty in ('all_pro', 'hall_of_famer') then 1 else 0 end;
    v_offset := p_game_number - 1;
    for v_band in 1 .. 5 loop
        select count(*) into v_n
        from public.competitive_cases c
        where c.band = v_band and c.active and c.competitive_eligible
          and c.distribution = 'client_bundled'
          and public.ranked_tier_rank(c.difficulty) >= v_floor;
        if v_n < 12 then
            raise exception 'CATALOG_POOL_TOO_SMALL: band % has % eligible cases', v_band, v_n;
        end if;
        select o.case_id, o.case_version, o.solutions -> v_variant
          into v_cid, v_ver, v_sol
        from (
            select c.case_id, c.case_version, c.solutions,
                   row_number() over (
                       order by c.difficulty_score
                                + (('x' || substr(md5(v_season.schedule_seed || ':' || c.case_id), 1, 8))::bit(32)::bigint
                                   / 4294967295.0) * 4 - 2,
                                c.case_id collate "C"
                   ) - 1 as idx
            from public.competitive_cases c
            where c.band = v_band and c.active and c.competitive_eligible
              and c.distribution = 'client_bundled'
              and public.ranked_tier_rank(c.difficulty) >= v_floor
        ) o
        where o.idx = floor(v_mode * (v_n - 12) / 3.0)::int + v_offset;
        if v_cid is null or v_sol is null or jsonb_typeof(v_sol) <> 'array' then
            raise exception 'SOLUTION_MISSING: band %', v_band;
        end if;
        v_ids := v_ids || v_cid;
        v_versions := v_versions || v_ver;
        v_solutions := v_solutions || jsonb_build_array(v_sol);
        v_cid := null;
        v_sol := null;
    end loop;

    insert into public.ranked_match_assignments (
        match_id, user_id, season_id, game_number, difficulty, solution_variant,
        case_ids, case_versions, expected_solutions, catalog_fingerprint, expires_at
    ) values (
        gen_random_uuid(), p_user_id, v_season.season_id, p_game_number, p_difficulty, v_variant,
        v_ids, v_versions, v_solutions, v_fp, now() + make_interval(hours => cfg.assignment_ttl_hours)
    )
    returning * into v_asg;

    return query select v_asg.assignment_id, v_asg.match_id, v_asg.season_id, v_asg.game_number,
                        v_asg.difficulty, v_asg.case_ids, v_asg.case_versions, v_asg.issued_at,
                        v_asg.expires_at, v_asg.catalog_fingerprint, false;
end;
$$;

revoke all on function public.issue_ranked_match_assignment(uuid, uuid, int, text) from public, anon, authenticated;
grant execute on function public.issue_ranked_match_assignment(uuid, uuid, int, text) to service_role;

-- 7j. THE ONLY WRITER of ranked results and career stats (service_role).
--     Phase 14B: identity, season, cases and solutions come from the
--     ASSIGNMENT, never from the client. The caller passes the JWT user and
--     the raw per-case facts; this function
--       1. returns the stored result for an already-recorded match_id
--          (idempotent retry; another user's match id = MATCH_ID_CONFLICT),
--       2. enforces the minimum ranked protocol and a non-empty, bounded
--          game_version,
--       3. locks the assignment by match_id and verifies owner, season,
--          game number, difficulty, not replaced / consumed / expired,
--       4. verifies every case result: case id + version equal the
--          assignment, quarter order, every placement is contained in the
--          EXACT snapshotted solution, players/slots distinct, a solved case
--          places the whole solution, a failed case does not, overtime
--          present iff regulation ended 2–2,
--       5. derives the summary (quarters, win, overtime) itself and scores
--          it from ranked_scoring_config — hints and wrong placements are
--          stored as self-reported stats and never scored,
--       6. inserts the result, consumes the assignment and updates career
--          stats in the same transaction. Championships are NOT touched.
--
--     Leaderboard week (14A, fixed in 14B): completed_at is honored only
--     when the server can validate it (ordered, within skew of receipt,
--     within max offline age, plausible duration, not before the account
--     existed, not before the assignment was issued) AND it is consistent
--     with the season's other TRUSTED games' leaderboard_at. Games whose
--     own time was untrusted (received_at) never poison later games.
drop function if exists public.record_verified_ranked_result(uuid, uuid, uuid, int, text, int, boolean, boolean, boolean, int, int, jsonb, timestamptz, timestamptz, text);
drop function if exists public.record_verified_ranked_result(uuid, uuid, uuid, int, text, jsonb, timestamptz, timestamptz, text, int);
create or replace function public.record_verified_ranked_result(
    p_user_id          uuid,
    p_match_id         uuid,
    p_season_id        uuid,
    p_game_number      int,
    p_difficulty       text,
    p_case_results     jsonb,
    p_started_at       timestamptz,
    p_completed_at     timestamptz,
    p_game_version     text,
    p_ranked_protocol  int
)
returns table (
    result_id              uuid,
    final_score            int,
    duplicate              boolean,
    leaderboard_at         timestamptz,
    leaderboard_at_source  text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
    cfg         public.ranked_scoring_config%rowtype;
    existing    public.ranked_game_results%rowtype;
    v_asg       public.ranked_match_assignments%rowtype;
    v_version   text := btrim(coalesce(p_game_version, ''));
    v_n         int;
    v_i         int;
    v_cr        jsonb;
    v_pl        jsonb;
    v_expected  jsonb;
    v_players   text[];
    v_slots     text[];
    v_outcome   text;
    v_solved    int := 0;
    v_ot_played boolean;
    v_ot_won    boolean := false;
    v_won       boolean;
    v_hints     int := 0;
    v_wrong     int := 0;
    v_base      int;
    v_mult      numeric(4,2);
    v_final     int;
    v_id        uuid;
    v_received  timestamptz := now();
    v_trusted   boolean;
    v_board_at  timestamptz;
    v_source    text;
begin
    if p_user_id is null or p_match_id is null or p_season_id is null
       or p_game_number is null or p_difficulty is null then
        raise exception 'INVALID_ARGUMENTS';
    end if;

    -- 1. Idempotent retry (fast path).
    select * into existing from public.ranked_game_results r where r.match_id = p_match_id;
    if found then
        if existing.user_id <> p_user_id then
            raise exception 'MATCH_ID_CONFLICT';
        end if;
        return query select existing.id, existing.final_score, true, existing.leaderboard_at, existing.leaderboard_at_source;
        return;
    end if;

    -- 2. Protocol + version.
    select * into cfg from public.ranked_scoring_config c where c.id = 1;
    if not found then
        raise exception 'SCORING_CONFIG_MISSING';
    end if;
    if p_ranked_protocol is null or p_ranked_protocol < cfg.min_ranked_protocol then
        raise exception 'CLIENT_OUTDATED';
    end if;
    if char_length(v_version) < 1 or char_length(v_version) > 40 then
        raise exception 'INVALID_GAME_VERSION';
    end if;

    -- 3. The assignment (row lock serializes concurrent retries).
    select * into v_asg from public.ranked_match_assignments a where a.match_id = p_match_id for update;
    if not found then
        raise exception 'ASSIGNMENT_NOT_FOUND';
    end if;
    -- A concurrent retry may have committed while we waited for the lock.
    select * into existing from public.ranked_game_results r where r.match_id = p_match_id;
    if found then
        if existing.user_id <> p_user_id then
            raise exception 'MATCH_ID_CONFLICT';
        end if;
        return query select existing.id, existing.final_score, true, existing.leaderboard_at, existing.leaderboard_at_source;
        return;
    end if;
    if v_asg.user_id <> p_user_id then
        raise exception 'ASSIGNMENT_OWNER_MISMATCH';
    end if;
    if v_asg.season_id <> p_season_id or v_asg.game_number <> p_game_number or v_asg.difficulty <> p_difficulty then
        raise exception 'ASSIGNMENT_MISMATCH';
    end if;
    if v_asg.consumed_result_id is not null then
        raise exception 'ASSIGNMENT_CONSUMED';
    end if;
    if v_asg.replaced_at is not null then
        raise exception 'ASSIGNMENT_REPLACED';
    end if;
    if v_received > v_asg.expires_at + make_interval(days => cfg.assignment_submit_grace_days) then
        raise exception 'ASSIGNMENT_EXPIRED';
    end if;
    if exists (
        select 1 from public.ranked_game_results r
        where r.user_id = p_user_id and r.season_id = p_season_id and r.game_number = p_game_number
    ) then
        raise exception 'DUPLICATE_SEASON_GAME';
    end if;

    -- 4. Case results against the assignment's exact solutions.
    if p_case_results is null or jsonb_typeof(p_case_results) <> 'array' then
        raise exception 'INVALID_CASE_RESULTS';
    end if;
    v_n := jsonb_array_length(p_case_results);
    if v_n not in (4, 5) then
        raise exception 'INVALID_CASE_RESULTS';
    end if;
    for v_i in 0 .. v_n - 1 loop
        v_cr := p_case_results -> v_i;
        if jsonb_typeof(v_cr) <> 'object' then
            raise exception 'INVALID_CASE_RESULTS';
        end if;
        if (v_cr ->> 'case_id') is distinct from v_asg.case_ids[v_i + 1] then
            raise exception 'CASE_MISMATCH';
        end if;
        if (v_cr -> 'case_version') is distinct from to_jsonb(v_asg.case_versions[v_i + 1]) then
            raise exception 'CASE_VERSION_MISMATCH';
        end if;
        if (v_cr -> 'quarter_index') is distinct from to_jsonb(v_i) then
            raise exception 'INVALID_CASE_RESULTS';
        end if;
        v_outcome := v_cr ->> 'outcome';
        if v_outcome is null or v_outcome not in ('solved', 'failed') then
            raise exception 'INVALID_CASE_RESULTS';
        end if;
        v_hints := v_hints + public.ranked_json_int(v_cr -> 'hints_used', 0, 100);
        v_wrong := v_wrong + public.ranked_json_int(v_cr -> 'wrong_placements', 0, 100);
        if jsonb_typeof(v_cr -> 'placements') is distinct from 'array'
           or jsonb_array_length(v_cr -> 'placements') > 8 then
            raise exception 'INVALID_CASE_RESULTS';
        end if;
        v_expected := v_asg.expected_solutions -> v_i;
        v_players := '{}';
        v_slots := '{}';
        for v_pl in select e.value from jsonb_array_elements(v_cr -> 'placements') e loop
            if jsonb_typeof(v_pl) <> 'object'
               or jsonb_typeof(v_pl -> 'player_key') is distinct from 'string'
               or jsonb_typeof(v_pl -> 'slot_key') is distinct from 'string'
               or jsonb_typeof(v_pl -> 'profile') is distinct from 'string' then
                raise exception 'INVALID_CASE_RESULTS';
            end if;
            if not (v_expected @> jsonb_build_array(jsonb_build_object(
                    'player_key', v_pl ->> 'player_key',
                    'slot_key', v_pl ->> 'slot_key',
                    'profile', v_pl ->> 'profile'))) then
                raise exception 'PLACEMENT_MISMATCH';
            end if;
            if (v_pl ->> 'player_key') = any(v_players) or (v_pl ->> 'slot_key') = any(v_slots) then
                raise exception 'PLACEMENT_MISMATCH';
            end if;
            v_players := v_players || (v_pl ->> 'player_key');
            v_slots := v_slots || (v_pl ->> 'slot_key');
        end loop;
        if v_outcome = 'solved' and cardinality(v_players) <> jsonb_array_length(v_expected) then
            raise exception 'SOLVED_CASE_INCOMPLETE';
        end if;
        if v_outcome = 'failed' and cardinality(v_players) >= jsonb_array_length(v_expected) then
            raise exception 'FAILED_CASE_COMPLETE';
        end if;
        if v_i < 4 and v_outcome = 'solved' then
            v_solved := v_solved + 1;
        end if;
        if v_i = 4 then
            v_ot_won := v_outcome = 'solved';
        end if;
    end loop;
    v_ot_played := v_solved = 2;
    if (v_n = 5) <> v_ot_played then
        raise exception 'OVERTIME_MISMATCH';
    end if;
    v_won := v_solved >= 3 or v_ot_won;

    -- 5. Score (server-derived facts only; no self-reported bonuses).
    v_base := v_solved * cfg.quarter_solved_points
        + (case when v_won then cfg.game_win_points else 0 end)
        + (case when v_ot_won then cfg.overtime_win_points else 0 end)
        + (case when v_solved = 4 then cfg.perfect_regulation_points else 0 end);
    v_mult := case p_difficulty
        when 'rookie' then cfg.rookie_multiplier
        when 'pro' then cfg.pro_multiplier
        when 'all_pro' then cfg.all_pro_multiplier
        when 'hall_of_famer' then cfg.hall_of_famer_multiplier
    end;
    if v_mult is null then
        raise exception 'INVALID_DIFFICULTY';
    end if;
    -- Consistent rounding: numeric round() is half away from zero.
    v_final := round(v_base::numeric * v_mult)::int;

    -- Leaderboard week: validated completion time, else receipt time.
    v_trusted := coalesce(
        p_started_at is not null
        and p_completed_at is not null
        and p_started_at < p_completed_at
        and p_completed_at <= v_received + make_interval(secs => cfg.max_clock_skew_seconds)
        and p_started_at >= v_received - make_interval(days => cfg.max_offline_age_days)
        and p_started_at >= v_asg.issued_at - make_interval(secs => cfg.max_clock_skew_seconds)
        and p_completed_at - p_started_at >= make_interval(secs => cfg.min_game_duration_seconds)
        and p_completed_at - p_started_at <= make_interval(hours => cfg.max_trusted_game_hours),
        false);
    if v_trusted and exists (
        select 1 from public.profiles p
        where p.id = p_user_id and p_started_at < p.created_at - make_interval(secs => cfg.max_clock_skew_seconds)
    ) then
        v_trusted := false;
    end if;
    -- Season order is checked ONLY against games whose own time was trusted,
    -- using the leaderboard instant they were actually bucketed at.
    if v_trusted and exists (
        select 1 from public.ranked_game_results r
        where r.user_id = p_user_id and r.season_id = p_season_id
          and r.leaderboard_at_source = 'completed_at'
          and ((r.game_number < p_game_number and r.leaderboard_at > least(p_completed_at, v_received))
            or (r.game_number > p_game_number and r.leaderboard_at < least(p_completed_at, v_received)))
    ) then
        v_trusted := false;
    end if;
    if v_trusted then
        v_board_at := least(p_completed_at, v_received);
        v_source := 'completed_at';
    else
        v_board_at := v_received;
        v_source := 'received_at';
    end if;

    -- 6. Record + consume + career stats (one transaction).
    begin
        insert into public.ranked_game_results (
            match_id, user_id, season_id, game_number, difficulty,
            regulation_quarters_solved, regulation_quarters_lost, game_won,
            overtime_played, overtime_won, wrong_placements, hints_used,
            base_score, difficulty_multiplier, final_score, verified,
            case_results, started_at, completed_at, game_version,
            leaderboard_at, leaderboard_at_source, assignment_id, ranked_protocol
        ) values (
            p_match_id, p_user_id, p_season_id, p_game_number, p_difficulty,
            v_solved, 4 - v_solved, v_won,
            v_ot_played, v_ot_won, v_wrong, v_hints,
            v_base, v_mult, v_final, true,
            p_case_results, p_started_at, p_completed_at, v_version,
            v_board_at, v_source, v_asg.assignment_id, p_ranked_protocol
        )
        returning id into v_id;
    exception
        when unique_violation then
            select * into existing from public.ranked_game_results r where r.match_id = p_match_id;
            if found and existing.user_id = p_user_id then
                return query select existing.id, existing.final_score, true, existing.leaderboard_at, existing.leaderboard_at_source;
                return;
            end if;
            raise exception 'DUPLICATE_SEASON_GAME';
    end;

    update public.ranked_match_assignments a
    set consumed_result_id = v_id, consumed_at = v_received
    where a.assignment_id = v_asg.assignment_id;

    -- Career stats move ONLY here, after verification. global_rating is the
    -- rounded average of the player's best all-time verified results.
    update public.profiles p set
        career_games_played = p.career_games_played + 1,
        career_wins         = p.career_wins + (case when v_won then 1 else 0 end),
        career_losses       = p.career_losses + (case when v_won then 0 else 1 end),
        career_cases_solved = p.career_cases_solved + v_solved + (case when v_ot_won then 1 else 0 end),
        global_rating       = (
            select coalesce(round(avg(best.final_score)), 0)::int
            from (
                select r.final_score from public.ranked_game_results r
                where r.user_id = p_user_id and r.verified
                order by r.final_score desc, r.created_at asc
                limit cfg.alltime_best_games
            ) best
        )
    where p.id = p_user_id;

    return query select v_id, v_final, false, v_board_at, v_source;
end;
$$;

revoke all on function public.record_verified_ranked_result(uuid, uuid, uuid, int, text, jsonb, timestamptz, timestamptz, text, int) from public, anon, authenticated;
grant execute on function public.record_verified_ranked_result(uuid, uuid, uuid, int, text, jsonb, timestamptz, timestamptz, text, int) to service_role;

-- 7k. INTERNAL leaderboard aggregation (not callable by clients).
--     WEEKLY: Monday 00:00 UTC → Sunday 23:59:59 UTC, bucketed by each
--     result's leaderboard_at (server-validated completion time, receipt
--     time as fallback — see 7j); score = SUM of the best N verified games.
--     ALL-TIME: score = AVERAGE of the best N verified games (1 decimal);
--     fewer than provisional_min_games verified games = PROVISIONAL (listed
--     after established players). Difficulty filter uses each game's
--     recorded difficulty. Tiebreakers (Phase 14B: server-derived facts
--     only): higher average, more wins, more quarters; full ties share the
--     rank and list by who reached the score first. hints_used /
--     wrong_placements are returned as self-reported display stats only.
create or replace function public.ranked_leaderboard_rows(p_board text, p_difficulty text)
returns table (
    rank                   bigint,
    user_id                uuid,
    username               text,
    football_display_name  text,
    score                  numeric,
    games_counted          int,
    total_games            int,
    average_score          numeric,
    wins                   int,
    quarters_solved        int,
    hints_used             int,
    wrong_placements       int,
    top_difficulty         text,
    is_provisional         boolean,
    first_reached_at       timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
    with cfg as (
        select c.* from public.ranked_scoring_config c where c.id = 1
    ),
    week_start as (
        select (date_trunc('week', now() at time zone 'utc') at time zone 'utc') as ts
    ),
    eligible as (
        select r.*
        from public.ranked_game_results r
        where r.verified
          and (p_difficulty = 'all' or r.difficulty = p_difficulty)
          and (p_board = 'alltime' or (
                r.leaderboard_at >= (select w.ts from week_start w)
                and r.leaderboard_at < (select w.ts from week_start w) + interval '7 days'))
    ),
    ordered as (
        select e.*,
               row_number() over (partition by e.user_id order by e.final_score desc, e.created_at asc, e.id asc) as game_rank,
               count(*) over (partition by e.user_id) as user_total
        from eligible e
    ),
    counted as (
        select o.*
        from ordered o cross join cfg
        where o.game_rank <= (case when p_board = 'weekly' then cfg.weekly_best_games else cfg.alltime_best_games end)
    ),
    agg as (
        select
            c.user_id,
            count(*)::int                                                         as games_counted,
            max(c.user_total)::int                                                as total_games,
            sum(c.final_score)::numeric                                           as total_score,
            round(avg(c.final_score)::numeric, 1)                                 as average_score,
            (count(*) filter (where c.game_won))::int                             as wins,
            sum(c.regulation_quarters_solved + (case when c.overtime_won then 1 else 0 end))::int as quarters_solved,
            sum(c.hints_used)::int                                                as hints_used,
            sum(c.wrong_placements)::int                                          as wrong_placements,
            max(case c.difficulty when 'rookie' then 1 when 'pro' then 2 when 'all_pro' then 3 else 4 end) as top_level,
            max(c.created_at)                                                     as first_reached_at
        from counted c
        group by c.user_id
    ),
    scored as (
        select
            a.*,
            (case when p_board = 'weekly' then a.total_score else a.average_score end) as score,
            (p_board = 'alltime' and a.total_games < cfg.provisional_min_games)      as is_provisional
        from agg a cross join cfg
    )
    select
        rank() over (
            order by s.is_provisional asc, s.score desc, s.average_score desc, s.wins desc,
                     s.quarters_solved desc
        )                                   as rank,
        s.user_id,
        pp.username,
        pp.football_display_name,
        s.score,
        s.games_counted,
        s.total_games,
        s.average_score,
        s.wins,
        s.quarters_solved,
        s.hints_used,
        s.wrong_placements,
        (case s.top_level when 1 then 'rookie' when 2 then 'pro' when 3 then 'all_pro' else 'hall_of_famer' end) as top_difficulty,
        s.is_provisional,
        s.first_reached_at
    from scored s
    join public.public_profiles pp on pp.id = s.user_id;
$$;

revoke all on function public.ranked_leaderboard_rows(text, text) from public, anon, authenticated;

-- 7l. CLIENT READS (authenticated only). Page size is capped at 50.
create or replace function public.ranked_leaderboard(
    p_board text,
    p_difficulty text default 'all',
    p_limit int default 50,
    p_offset int default 0
)
returns table (
    rank                   bigint,
    user_id                uuid,
    username               text,
    football_display_name  text,
    score                  numeric,
    games_counted          int,
    total_games            int,
    average_score          numeric,
    wins                   int,
    quarters_solved        int,
    hints_used             int,
    wrong_placements       int,
    top_difficulty         text,
    is_provisional         boolean,
    first_reached_at       timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
    if auth.uid() is null then
        raise exception 'AUTH_REQUIRED';
    end if;
    if p_board not in ('weekly', 'alltime') then
        raise exception 'INVALID_BOARD';
    end if;
    if p_difficulty not in ('all', 'rookie', 'pro', 'all_pro', 'hall_of_famer') then
        raise exception 'INVALID_DIFFICULTY';
    end if;
    return query
        select lr.*
        from public.ranked_leaderboard_rows(p_board, p_difficulty) lr
        order by lr.rank asc, lr.first_reached_at asc, lr.username asc
        limit least(greatest(coalesce(p_limit, 50), 1), 50)
        offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function public.ranked_leaderboard(text, text, int, int) from public, anon;
grant execute on function public.ranked_leaderboard(text, text, int, int) to authenticated;

-- The caller's own row (pinned YOUR RANK). Empty = no verified games yet.
create or replace function public.my_ranked_standing(p_board text, p_difficulty text default 'all')
returns table (
    rank                   bigint,
    user_id                uuid,
    username               text,
    football_display_name  text,
    score                  numeric,
    games_counted          int,
    total_games            int,
    average_score          numeric,
    wins                   int,
    quarters_solved        int,
    hints_used             int,
    wrong_placements       int,
    top_difficulty         text,
    is_provisional         boolean,
    first_reached_at       timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
    if auth.uid() is null then
        raise exception 'AUTH_REQUIRED';
    end if;
    if p_board not in ('weekly', 'alltime') then
        raise exception 'INVALID_BOARD';
    end if;
    if p_difficulty not in ('all', 'rookie', 'pro', 'all_pro', 'hall_of_famer') then
        raise exception 'INVALID_DIFFICULTY';
    end if;
    return query
        select lr.*
        from public.ranked_leaderboard_rows(p_board, p_difficulty) lr
        where lr.user_id = auth.uid();
end;
$$;

revoke all on function public.my_ranked_standing(text, text) from public, anon;
grant execute on function public.my_ranked_standing(text, text) to authenticated;

-- Username search over PUBLIC profile columns only (prefix match, 2–20
-- characters, at most 20 rows). Never real names or email.
create or replace function public.search_public_profiles(p_query text, p_limit int default 20)
returns table (
    id                     uuid,
    username               text,
    football_display_name  text,
    global_rating          int,
    career_games_played    int,
    career_wins            int,
    championships          int
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
    q text := lower(btrim(coalesce(p_query, '')));
begin
    if auth.uid() is null then
        raise exception 'AUTH_REQUIRED';
    end if;
    if q !~ '^[a-z0-9_]{2,20}$' then
        return;
    end if;
    return query
        select pp.id, pp.username, pp.football_display_name, pp.global_rating,
               pp.career_games_played, pp.career_wins, pp.championships
        from public.public_profiles pp
        where lower(pp.username) like replace(q, '_', '\_') || '%'
        order by lower(pp.username) asc
        limit least(greatest(coalesce(p_limit, 20), 1), 20);
end;
$$;

revoke all on function public.search_public_profiles(text, int) from public, anon;
grant execute on function public.search_public_profiles(text, int) to authenticated;

-- ===========================================================================
-- 8. PHASE 15A — ASYNCHRONOUS 1-v-1 VERSUS (server-authoritative foundation)
--
--    Purely ADDITIVE: nothing in section 7 (Ranked) is written or changed.
--    Versus has its own config row, tables, rate limits, career stats and
--    functions. It only READS the shared competitive catalog and calls the
--    immutable helpers ranked_solution_variant / ranked_tier_rank /
--    ranked_json_int.
--
--    Trust model:
--      * `find-versus-match` (Edge Function, user from the JWT, body =
--        difficulty ONLY) calls versus_find_match. The SERVER pairs players:
--        a client can never name an opponent, a match id or a case.
--      * Matchmaking is serialized by two transaction advisory locks taken in
--        a fixed order (per user, then per difficulty queue) plus a row lock
--        (FOR UPDATE SKIP LOCKED) on the waiting match being claimed, and a
--        partial unique index allows ONE waiting match per user. So two
--        simultaneous searches of different users at the same difficulty
--        pair with each other, a double tap / retry of the same user returns
--        the same match (reused = true), and a waiting match is claimed by
--        exactly one opponent.
--      * The five cases, their versions and the EXACT expected solutions are
--        SNAPSHOTTED when the match is created (private table
--        versus_match_solutions). Both players get the same snapshot; later
--        catalog edits never touch a live match.
--      * `submit-versus-result` sends raw per-case facts only (no score, no
--        user id, no summary). versus_record_result verifies membership,
--        status, expiry, case ids/versions/order and every placement against
--        the snapshot, computes the score from versus_config, records the
--        result once per (match, user) and — under the match row lock —
--        resolves the winner exactly once when both results exist.
--      * Expiry is LAZY (no cron): every find / submit / read first resolves
--        the relevant overdue matches deterministically under row locks.
--      * No pay-to-win: purchasable hints are disabled in Versus
--        (versus_config CHECK) and a result reporting hints is rejected.
--        Self-reported hint / wrong-placement counts are never scored.
--      * Clients never read Versus tables directly. They read their own
--        matches / history and anyone's public record through SECURITY
--        DEFINER RPCs that expose public profile columns only.
--
--    Case content (15A): the server_assigned pool is used when every band
--    has eligible server-only cases. Until that content exists the server
--    falls back to the bundled pool — TEMPORARY DEV FALLBACK, gated by
--    versus_config.allow_bundled_fallback and recorded per match as
--    content_source = 'bundled_dev_fallback'. Assignment stays
--    server-owned either way; bundled solutions are not secret.
-- ===========================================================================

-- 8a. Versus configuration. Point values and multipliers start equal to
--     Ranked but live in their own row so a Ranked rebalance never silently
--     changes Versus (and vice versa).
create table if not exists public.versus_config (
    id                          int          primary key default 1 check (id = 1),
    quarter_solved_points       int          not null default 10,
    game_win_points             int          not null default 10,
    overtime_win_points         int          not null default 5,
    perfect_regulation_points   int          not null default 5,
    rookie_multiplier           numeric(4,2) not null default 1.00,
    pro_multiplier              numeric(4,2) not null default 1.25,
    all_pro_multiplier          numeric(4,2) not null default 1.50,
    hall_of_famer_multiplier    numeric(4,2) not null default 2.00,
    match_ttl_hours             int          not null default 24,
    -- TEMPORARY: bundled cases may back Versus until server-only content ships.
    allow_bundled_fallback      boolean      not null default true,
    purchasable_hints_allowed   boolean      not null default false,
    min_versus_protocol         int          not null default 1,
    finds_per_hour              int          not null default 30,
    submissions_per_hour        int          not null default 30,
    case_window_size            int          not null default 12,
    updated_at                  timestamptz  not null default now()
);

insert into public.versus_config (id) values (1) on conflict (id) do nothing;

alter table public.versus_config drop constraint if exists versus_config_bounds;
alter table public.versus_config add constraint versus_config_bounds check (
    quarter_solved_points >= 0 and game_win_points >= 0 and overtime_win_points >= 0
    and perfect_regulation_points >= 0
    and rookie_multiplier > 0 and pro_multiplier > 0 and all_pro_multiplier > 0 and hall_of_famer_multiplier > 0
    and match_ttl_hours between 1 and 720
    and min_versus_protocol >= 1 and finds_per_hour >= 1 and submissions_per_hour >= 1
    and case_window_size between 1 and 200
);
alter table public.versus_config drop constraint if exists versus_config_no_purchased_advantage;
alter table public.versus_config add constraint versus_config_no_purchased_advantage
    check (purchasable_hints_allowed = false);

alter table public.versus_config enable row level security;
revoke all on public.versus_config from public;
revoke all on public.versus_config from anon, authenticated;

-- 8b. Matches. player_a created the match (waiting_for_opponent); player_b
--     is assigned by the server when it claims the match (active).
create table if not exists public.versus_matches (
    match_id             uuid        primary key default gen_random_uuid(),
    player_a_id          uuid        not null references public.profiles (id) on delete cascade,
    player_b_id          uuid        references public.profiles (id) on delete cascade,
    status               text        not null default 'waiting_for_opponent'
                                     check (status in ('waiting_for_opponent', 'active', 'completed', 'expired', 'cancelled')),
    difficulty           text        not null check (difficulty in ('rookie', 'pro', 'all_pro', 'hall_of_famer')),
    solution_variant     text        not null check (solution_variant in ('rookie', 'pro_early', 'pro', 'all_pro', 'hall_of_famer')),
    content_source       text        not null check (content_source in ('server_assigned', 'bundled_dev_fallback')),
    case_ids             text[]      not null check (cardinality(case_ids) = 5),
    case_versions        int[]       not null check (cardinality(case_versions) = 5),
    catalog_fingerprint  text        not null,
    created_at           timestamptz not null default now(),
    matched_at           timestamptz,
    expires_at           timestamptz not null,
    completed_at         timestamptz,
    winner_user_id       uuid        references public.profiles (id) on delete set null,
    is_tie               boolean     not null default false,
    is_forfeit           boolean     not null default false,
    resolution           text        check (resolution in ('score', 'cases_solved', 'regulation_quarters', 'tie',
                                                           'forfeit', 'expired_unplayed', 'expired_no_opponent', 'cancelled')),
    constraint versus_matches_no_self_match check (player_b_id is null or player_b_id <> player_a_id),
    constraint versus_matches_opponent_state check (
        (status = 'waiting_for_opponent' and player_b_id is null)
        or (status in ('active', 'completed') and player_b_id is not null)
        or status in ('expired', 'cancelled')
    ),
    constraint versus_matches_closed_state check ((status in ('waiting_for_opponent', 'active')) = (completed_at is null)),
    constraint versus_matches_winner_state check (
        (winner_user_id is null or (status = 'completed' and winner_user_id in (player_a_id, player_b_id)))
        and not (is_tie and winner_user_id is not null)
        and (status <> 'completed' or is_tie <> (winner_user_id is not null))
        and (not is_forfeit or (status = 'completed' and winner_user_id is not null))
    ),
    constraint versus_matches_expiry_check check (expires_at > created_at)
);
-- ONE waiting match per user (double tap / retry cannot open a second one).
create unique index if not exists versus_matches_one_waiting_per_user
    on public.versus_matches (player_a_id) where status = 'waiting_for_opponent';
create index if not exists versus_matches_queue_idx
    on public.versus_matches (difficulty, created_at) where status = 'waiting_for_opponent';
create index if not exists versus_matches_player_a_idx on public.versus_matches (player_a_id, status);
create index if not exists versus_matches_player_b_idx on public.versus_matches (player_b_id, status);
create index if not exists versus_matches_due_idx
    on public.versus_matches (expires_at) where status in ('waiting_for_opponent', 'active');

alter table public.versus_matches enable row level security;
alter table public.versus_matches force row level security;
revoke all on public.versus_matches from public;
revoke all on public.versus_matches from anon, authenticated;

-- 8c. PRIVATE solution snapshot (service role only; never returned).
create table if not exists public.versus_match_solutions (
    match_id            uuid  primary key references public.versus_matches (match_id) on delete cascade,
    expected_solutions  jsonb not null check (jsonb_typeof(expected_solutions) = 'array'
                                              and jsonb_array_length(expected_solutions) = 5)
);

alter table public.versus_match_solutions enable row level security;
alter table public.versus_match_solutions force row level security;
revoke all on public.versus_match_solutions from public;
revoke all on public.versus_match_solutions from anon, authenticated;

-- 8d. Verified results — server-derived facts only, one per (match, user).
--     client_started_at / client_completed_at are self-reported claims kept
--     for diagnostics; they never decide anything.
create table if not exists public.versus_match_results (
    result_id                   uuid         primary key default gen_random_uuid(),
    match_id                    uuid         not null references public.versus_matches (match_id) on delete cascade,
    user_id                     uuid         not null references public.profiles (id) on delete cascade,
    regulation_quarters_solved  int          not null check (regulation_quarters_solved between 0 and 4),
    overtime_played             boolean      not null,
    overtime_won                boolean      not null,
    cases_solved                int          not null check (cases_solved between 0 and 5),
    game_won                    boolean      not null,
    base_score                  int          not null check (base_score >= 0),
    difficulty_multiplier       numeric(4,2) not null check (difficulty_multiplier > 0),
    final_score                 int          not null check (final_score >= 0),
    case_results                jsonb        not null,
    server_elapsed_seconds      int          not null check (server_elapsed_seconds >= 0),
    client_started_at           timestamptz,
    client_completed_at         timestamptz,
    game_version                text         not null,
    versus_protocol             int          not null,
    received_at                 timestamptz  not null default now(),
    constraint versus_match_results_once unique (match_id, user_id),
    constraint versus_match_results_overtime_check check (overtime_played or not overtime_won)
);

alter table public.versus_match_results enable row level security;
alter table public.versus_match_results force row level security;
revoke all on public.versus_match_results from public;
revoke all on public.versus_match_results from anon, authenticated;

-- 8e. Versus career stats (server-only writer; public via versus_public_record).
create table if not exists public.versus_career_stats (
    user_id                 uuid        primary key references public.profiles (id) on delete cascade,
    versus_games_played     int         not null default 0 check (versus_games_played >= 0),
    versus_wins             int         not null default 0 check (versus_wins >= 0),
    versus_losses           int         not null default 0 check (versus_losses >= 0),
    versus_ties             int         not null default 0 check (versus_ties >= 0),
    versus_forfeit_wins     int         not null default 0 check (versus_forfeit_wins >= 0),
    versus_forfeit_losses   int         not null default 0 check (versus_forfeit_losses >= 0),
    updated_at              timestamptz not null default now(),
    constraint versus_career_stats_sum check (versus_wins + versus_losses + versus_ties = versus_games_played)
);

alter table public.versus_career_stats enable row level security;
alter table public.versus_career_stats force row level security;
revoke all on public.versus_career_stats from public;
revoke all on public.versus_career_stats from anon, authenticated;

-- 8f. Atomic Versus rate limits (own table; Ranked buckets untouched).
create table if not exists public.versus_rate_limits (
    user_id       uuid        not null,
    bucket        text        not null check (bucket in ('find', 'submit')),
    window_start  timestamptz not null,
    count         int         not null check (count >= 0),
    primary key (user_id, bucket, window_start)
);

alter table public.versus_rate_limits enable row level security;
revoke all on public.versus_rate_limits from public;
revoke all on public.versus_rate_limits from anon, authenticated;

create or replace function public.consume_versus_rate_limit(p_user_id uuid, p_bucket text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_limit   int;
    v_window  timestamptz := date_trunc('hour', now());
    v_count   int;
begin
    if p_user_id is null then
        raise exception 'INVALID_ARGUMENTS';
    end if;
    select case p_bucket when 'find' then c.finds_per_hour
                         when 'submit' then c.submissions_per_hour end
      into v_limit
      from public.versus_config c where c.id = 1;
    if v_limit is null then
        raise exception 'INVALID_RATE_LIMIT_BUCKET';
    end if;
    delete from public.versus_rate_limits l
    where l.user_id = p_user_id and l.window_start < now() - interval '2 days';
    insert into public.versus_rate_limits as l (user_id, bucket, window_start, count)
    values (p_user_id, p_bucket, v_window, 1)
    on conflict (user_id, bucket, window_start)
        do update set count = l.count + 1 where l.count < v_limit
    returning l.count into v_count;
    return v_count is not null;
end;
$$;

revoke all on function public.consume_versus_rate_limit(uuid, text) from public, anon, authenticated;
grant execute on function public.consume_versus_rate_limit(uuid, text) to service_role;

-- 8g. Internal: career stats bump (one row per user, created on first game).
create or replace function public.versus_bump_stats(
    p_user_id uuid, p_win int, p_loss int, p_tie int, p_forfeit_win int, p_forfeit_loss int
)
returns void
language sql
security definer
set search_path = ''
as $$
    insert into public.versus_career_stats as s (
        user_id, versus_games_played, versus_wins, versus_losses, versus_ties,
        versus_forfeit_wins, versus_forfeit_losses
    ) values (p_user_id, 1, p_win, p_loss, p_tie, p_forfeit_win, p_forfeit_loss)
    on conflict (user_id) do update set
        versus_games_played   = s.versus_games_played + 1,
        versus_wins           = s.versus_wins + p_win,
        versus_losses         = s.versus_losses + p_loss,
        versus_ties           = s.versus_ties + p_tie,
        versus_forfeit_wins   = s.versus_forfeit_wins + p_forfeit_win,
        versus_forfeit_losses = s.versus_forfeit_losses + p_forfeit_loss,
        updated_at            = now();
$$;

revoke all on function public.versus_bump_stats(uuid, int, int, int, int, int) from public, anon, authenticated;

-- 8h. Internal: RESOLUTION. The caller MUST hold the match row lock
--     (SELECT … FOR UPDATE). Idempotent: a closed match is left untouched,
--     so a match is resolved — and career stats move — exactly once.
--
--     Both results present (active) → winner by, in order:
--       1. higher server final_score                 (resolution 'score')
--       2. more cases solved (regulation + overtime) ('cases_solved')
--       3. more regulation quarters solved           ('regulation_quarters')
--       4. otherwise a TIE                           ('tie')
--     Elapsed time is NOT a tiebreaker in 15A: the only play-time numbers
--     are client-reported (untrusted), and the server-measured interval
--     (assignment → receipt) includes idle/queue time, so it is stored as
--     server_elapsed_seconds for diagnostics only.
--
--     Overdue (expires_at <= now()):
--       * waiting, no opponent ever joined → 'expired' (no record impact,
--         even if the creator submitted),
--       * active, exactly one result → 'completed' FORFEIT win for the
--         finisher (wins + forfeit_wins / losses + forfeit_losses),
--       * active, no result → 'expired' (no record impact).
create or replace function public.versus_resolve_locked(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_m       public.versus_matches%rowtype;
    v_ra      public.versus_match_results%rowtype;
    v_rb      public.versus_match_results%rowtype;
    v_has_a   boolean;
    v_has_b   boolean;
    v_winner  uuid;
    v_loser   uuid;
    v_res     text;
begin
    select * into v_m from public.versus_matches m where m.match_id = p_match_id;
    if not found or v_m.status not in ('waiting_for_opponent', 'active') then
        return;
    end if;
    select * into v_ra from public.versus_match_results r where r.match_id = p_match_id and r.user_id = v_m.player_a_id;
    v_has_a := found;
    if v_m.player_b_id is not null then
        select * into v_rb from public.versus_match_results r where r.match_id = p_match_id and r.user_id = v_m.player_b_id;
        v_has_b := found;
    else
        v_has_b := false;
    end if;

    if v_m.status = 'active' and v_has_a and v_has_b then
        if v_ra.final_score <> v_rb.final_score then
            v_res := 'score';
            v_winner := case when v_ra.final_score > v_rb.final_score then v_m.player_a_id else v_m.player_b_id end;
        elsif v_ra.cases_solved <> v_rb.cases_solved then
            v_res := 'cases_solved';
            v_winner := case when v_ra.cases_solved > v_rb.cases_solved then v_m.player_a_id else v_m.player_b_id end;
        elsif v_ra.regulation_quarters_solved <> v_rb.regulation_quarters_solved then
            v_res := 'regulation_quarters';
            v_winner := case when v_ra.regulation_quarters_solved > v_rb.regulation_quarters_solved
                             then v_m.player_a_id else v_m.player_b_id end;
        else
            v_res := 'tie';
            v_winner := null;
        end if;
        update public.versus_matches m set
            status = 'completed', completed_at = now(), winner_user_id = v_winner,
            is_tie = (v_winner is null), is_forfeit = false, resolution = v_res
        where m.match_id = p_match_id;
        if v_winner is null then
            perform public.versus_bump_stats(v_m.player_a_id, 0, 0, 1, 0, 0);
            perform public.versus_bump_stats(v_m.player_b_id, 0, 0, 1, 0, 0);
        else
            v_loser := case when v_winner = v_m.player_a_id then v_m.player_b_id else v_m.player_a_id end;
            perform public.versus_bump_stats(v_winner, 1, 0, 0, 0, 0);
            perform public.versus_bump_stats(v_loser, 0, 1, 0, 0, 0);
        end if;
        return;
    end if;

    if v_m.expires_at > now() then
        return;
    end if;

    if v_m.status = 'waiting_for_opponent' then
        update public.versus_matches m set status = 'expired', completed_at = now(), resolution = 'expired_no_opponent'
        where m.match_id = p_match_id;
    elsif v_has_a <> v_has_b then
        v_winner := case when v_has_a then v_m.player_a_id else v_m.player_b_id end;
        v_loser := case when v_has_a then v_m.player_b_id else v_m.player_a_id end;
        update public.versus_matches m set
            status = 'completed', completed_at = now(), winner_user_id = v_winner,
            is_tie = false, is_forfeit = true, resolution = 'forfeit'
        where m.match_id = p_match_id;
        perform public.versus_bump_stats(v_winner, 1, 0, 0, 1, 0);
        perform public.versus_bump_stats(v_loser, 0, 1, 0, 0, 1);
    else
        update public.versus_matches m set status = 'expired', completed_at = now(), resolution = 'expired_unplayed'
        where m.match_id = p_match_id;
    end if;
end;
$$;

revoke all on function public.versus_resolve_locked(uuid) from public, anon, authenticated;

-- 8i. Internal: LAZY expiry. Resolves every overdue open match of one user
--     (or of everyone when p_user_id is null — for an operator). Rows
--     locked by a concurrent resolver are skipped: that transaction is
--     already resolving them.
create or replace function public.versus_expire_due(p_user_id uuid)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id  uuid;
    v_n   int := 0;
begin
    for v_id in
        select m.match_id from public.versus_matches m
        where m.status in ('waiting_for_opponent', 'active')
          and m.expires_at <= now()
          and (p_user_id is null or m.player_a_id = p_user_id or m.player_b_id = p_user_id)
        order by m.match_id
        for update skip locked
    loop
        perform public.versus_resolve_locked(v_id);
        v_n := v_n + 1;
    end loop;
    return v_n;
end;
$$;

revoke all on function public.versus_expire_due(uuid) from public, anon, authenticated;
grant execute on function public.versus_expire_due(uuid) to service_role;

-- 8j. Internal: the per-player view of matches. Opponent identity comes from
--     public_profiles (username + football display name — never real names
--     or email). The opponent's score / cases are revealed ONLY once the
--     match is completed; before that the caller learns only whether the
--     opponent has submitted. player_state:
--       waiting_for_opponent — no opponent yet, caller has not submitted
--       submitted            — no opponent yet, caller already submitted
--       active               — opponent joined, caller has not submitted
--       opponent_pending     — caller submitted, opponent has not
--       completed / expired / cancelled — closed.
create or replace function public.versus_player_rows(p_user_id uuid)
returns table (
    match_id               uuid,
    status                 text,
    player_state           text,
    role                   text,
    difficulty             text,
    case_ids               text[],
    case_versions          int[],
    catalog_fingerprint    text,
    content_source         text,
    created_at             timestamptz,
    matched_at             timestamptz,
    expires_at             timestamptz,
    completed_at           timestamptz,
    opponent_user_id       uuid,
    opponent_username      text,
    opponent_display_name  text,
    my_submitted           boolean,
    my_final_score         int,
    my_cases_solved        int,
    opponent_submitted     boolean,
    opponent_final_score   int,
    opponent_cases_solved  int,
    outcome                text,
    is_forfeit             boolean,
    resolution             text
)
language sql
stable
security definer
set search_path = ''
as $$
    select
        m.match_id,
        m.status,
        case
            when m.status in ('completed', 'expired', 'cancelled') then m.status
            when m.player_b_id is null and mine.result_id is null then 'waiting_for_opponent'
            when m.player_b_id is null then 'submitted'
            when mine.result_id is null then 'active'
            else 'opponent_pending'
        end,
        case when m.player_a_id = p_user_id then 'player_a' else 'player_b' end,
        m.difficulty, m.case_ids, m.case_versions, m.catalog_fingerprint, m.content_source,
        m.created_at, m.matched_at, m.expires_at, m.completed_at,
        opp.id, opp.username, opp.football_display_name,
        mine.result_id is not null, mine.final_score, mine.cases_solved,
        theirs.result_id is not null,
        case when m.status = 'completed' then theirs.final_score end,
        case when m.status = 'completed' then theirs.cases_solved end,
        case
            when m.status <> 'completed' then null
            when m.is_tie then 'tie'
            when m.winner_user_id = p_user_id then 'win'
            else 'loss'
        end,
        m.is_forfeit,
        m.resolution
    from public.versus_matches m
    left join public.versus_match_results mine
        on mine.match_id = m.match_id and mine.user_id = p_user_id
    left join public.versus_match_results theirs
        on theirs.match_id = m.match_id and theirs.user_id <> p_user_id
    left join public.public_profiles opp
        on opp.id = (case when m.player_a_id = p_user_id then m.player_b_id else m.player_a_id end)
    where p_user_id is not null
      and (m.player_a_id = p_user_id or m.player_b_id = p_user_id);
$$;

revoke all on function public.versus_player_rows(uuid) from public, anon, authenticated;
grant execute on function public.versus_player_rows(uuid) to service_role;

-- 8k. MATCHMAKING — called by find-versus-match (service_role) with the JWT
--     user and a difficulty. Steps (one transaction):
--       1. per-user advisory lock; lazily resolve the user's overdue matches,
--       2. an open match the user has NOT submitted yet: same difficulty →
--          returned again (reused = true; retry-after-timeout safe); a
--          waiting one at another difficulty → cancelled (no opponent, no
--          record impact); an active one at another difficulty →
--          VERSUS_MATCH_IN_PROGRESS,
--       3. per-difficulty queue advisory lock; claim the OLDEST waiting match
--          of that difficulty created by SOMEONE ELSE (never self) whose
--          creator has no other active match against this user (no
--          duplicate pairing), FOR UPDATE SKIP LOCKED; the claim resets the
--          expiry so the joiner gets the full window,
--       4. otherwise create a waiting match with a fresh case snapshot (one
--          waiting match per user; a user whose waiting match is already
--          submitted gets VERSUS_ALREADY_WAITING).
--
--     Case snapshot: bands 1–4 = regulation quarters, band 5 = overtime.
--     Pool = active, competitive cases of the chosen distribution; All-Pro /
--     Hall of Famer exclude rookie-TIER cases. Ordered by calibrated
--     difficulty_score, the mode takes a window of case_window_size cases at
--     floor(mode_index * (n - w) / 3) (rookie easiest … HoF hardest) and a
--     server-random case inside it. Variant = the mode's full adaptation
--     (ranked_solution_variant(mode, 12): Pro → 'pro', never 'pro_early').
create or replace function public.versus_find_match(p_user_id uuid, p_difficulty text)
returns table (
    match_id               uuid,
    status                 text,
    player_state           text,
    role                   text,
    difficulty             text,
    case_ids               text[],
    case_versions          int[],
    catalog_fingerprint    text,
    content_source         text,
    created_at             timestamptz,
    matched_at             timestamptz,
    expires_at             timestamptz,
    completed_at           timestamptz,
    opponent_user_id       uuid,
    opponent_username      text,
    opponent_display_name  text,
    my_submitted           boolean,
    my_final_score         int,
    my_cases_solved        int,
    opponent_submitted     boolean,
    opponent_final_score   int,
    opponent_cases_solved  int,
    outcome                text,
    is_forfeit             boolean,
    resolution             text,
    reused                 boolean
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
    cfg          public.versus_config%rowtype;
    v_m          public.versus_matches%rowtype;
    v_found      boolean;
    v_dist       text;
    v_source     text;
    v_fp         text;
    v_variant    text;
    v_mode       int;
    v_floor      int;
    v_band       int;
    v_n          int;
    v_w          int;
    v_pick       int;
    v_ok         boolean;
    v_cid        text;
    v_ver        int;
    v_sol        jsonb;
    v_ids        text[] := '{}';
    v_versions   int[] := '{}';
    v_solutions  jsonb := '[]'::jsonb;
    v_id         uuid;
begin
    if p_user_id is null or p_difficulty is null then
        raise exception 'INVALID_ARGUMENTS';
    end if;
    if p_difficulty not in ('rookie', 'pro', 'all_pro', 'hall_of_famer') then
        raise exception 'INVALID_DIFFICULTY';
    end if;
    select * into cfg from public.versus_config c where c.id = 1;
    if not found then
        raise exception 'VERSUS_CONFIG_MISSING';
    end if;
    if not exists (select 1 from public.profiles p where p.id = p_user_id) then
        raise exception 'PROFILE_REQUIRED';
    end if;

    -- 1. Serialize this user's matchmaking; resolve overdue matches first.
    perform pg_advisory_xact_lock(hashtextextended('versus:user:' || p_user_id::text, 0));
    perform public.versus_expire_due(p_user_id);

    -- 2. An open match the user still has to play.
    select m.* into v_m from public.versus_matches m
    where (m.player_a_id = p_user_id or m.player_b_id = p_user_id)
      and m.status in ('waiting_for_opponent', 'active')
      and not exists (
          select 1 from public.versus_match_results r
          where r.match_id = m.match_id and r.user_id = p_user_id)
    order by m.created_at desc
    limit 1
    for update;
    if found then
        if v_m.difficulty = p_difficulty then
            return query select v.*, true from public.versus_player_rows(p_user_id) v where v.match_id = v_m.match_id;
            return;
        end if;
        if v_m.status = 'waiting_for_opponent' then
            update public.versus_matches m
            set status = 'cancelled', completed_at = now(), resolution = 'cancelled'
            where m.match_id = v_m.match_id;
        else
            raise exception 'VERSUS_MATCH_IN_PROGRESS';
        end if;
    end if;

    -- 3. Claim the oldest compatible waiting match of this difficulty.
    perform pg_advisory_xact_lock(hashtextextended('versus:queue:' || p_difficulty, 0));
    select m.* into v_m from public.versus_matches m
    where m.status = 'waiting_for_opponent'
      and m.difficulty = p_difficulty
      and m.player_a_id <> p_user_id
      and m.expires_at > now()
      and not exists (
          select 1 from public.versus_matches x
          where x.status = 'active'
            and ((x.player_a_id = m.player_a_id and x.player_b_id = p_user_id)
              or (x.player_a_id = p_user_id and x.player_b_id = m.player_a_id)))
    order by m.created_at asc, m.match_id asc
    limit 1
    for update skip locked;
    v_found := found;
    if v_found then
        update public.versus_matches m set
            player_b_id = p_user_id,
            status = 'active',
            matched_at = now(),
            expires_at = now() + make_interval(hours => cfg.match_ttl_hours)
        where m.match_id = v_m.match_id;
        return query select v.*, false from public.versus_player_rows(p_user_id) v where v.match_id = v_m.match_id;
        return;
    end if;

    -- 4. Nothing to join: open a waiting match with a fresh snapshot.
    if exists (
        select 1 from public.versus_matches m
        where m.player_a_id = p_user_id and m.status = 'waiting_for_opponent'
    ) then
        raise exception 'VERSUS_ALREADY_WAITING';
    end if;

    v_variant := public.ranked_solution_variant(p_difficulty, 12);
    v_mode := public.ranked_tier_rank(p_difficulty);
    v_floor := case when p_difficulty in ('all_pro', 'hall_of_famer') then 1 else 0 end;

    -- Prefer server-only content; bundled is the TEMPORARY dev fallback.
    foreach v_dist in array array['server_assigned', 'client_bundled'] loop
        if v_dist = 'client_bundled' and not cfg.allow_bundled_fallback then
            exit;
        end if;
        select m.catalog_fingerprint into v_fp
        from public.competitive_catalog_meta m where m.distribution = v_dist;
        v_ok := v_fp is not null;
        if v_ok then
            for v_band in 1 .. 5 loop
                if not exists (
                    select 1 from public.competitive_cases c
                    where c.band = v_band and c.active and c.competitive_eligible
                      and c.distribution = v_dist
                      and public.ranked_tier_rank(c.difficulty) >= v_floor
                      and jsonb_typeof(c.solutions -> v_variant) = 'array'
                      and jsonb_array_length(c.solutions -> v_variant) > 0
                ) then
                    v_ok := false;
                end if;
            end loop;
        end if;
        if v_ok then
            v_source := v_dist;
            exit;
        end if;
        v_fp := null;
    end loop;
    if v_source is null then
        raise exception 'VERSUS_CATALOG_UNAVAILABLE';
    end if;

    for v_band in 1 .. 5 loop
        select count(*) into v_n
        from public.competitive_cases c
        where c.band = v_band and c.active and c.competitive_eligible
          and c.distribution = v_source
          and public.ranked_tier_rank(c.difficulty) >= v_floor
          and jsonb_typeof(c.solutions -> v_variant) = 'array'
          and jsonb_array_length(c.solutions -> v_variant) > 0;
        v_w := least(cfg.case_window_size, v_n);
        -- Pick the index ONCE (random() inside WHERE is re-evaluated per row).
        v_pick := floor(v_mode * (v_n - v_w) / 3.0)::int + floor(random() * v_w)::int;
        select o.case_id, o.case_version, o.solutions -> v_variant
          into v_cid, v_ver, v_sol
        from (
            select c.case_id, c.case_version, c.solutions,
                   row_number() over (order by c.difficulty_score, c.case_id collate "C") - 1 as idx
            from public.competitive_cases c
            where c.band = v_band and c.active and c.competitive_eligible
              and c.distribution = v_source
              and public.ranked_tier_rank(c.difficulty) >= v_floor
              and jsonb_typeof(c.solutions -> v_variant) = 'array'
              and jsonb_array_length(c.solutions -> v_variant) > 0
        ) o
        where o.idx = v_pick;
        if v_cid is null or v_sol is null then
            raise exception 'VERSUS_CATALOG_UNAVAILABLE';
        end if;
        v_ids := v_ids || v_cid;
        v_versions := v_versions || v_ver;
        v_solutions := v_solutions || jsonb_build_array(v_sol);
        v_cid := null;
        v_sol := null;
    end loop;

    insert into public.versus_matches (
        player_a_id, difficulty, solution_variant, content_source,
        case_ids, case_versions, catalog_fingerprint, expires_at
    ) values (
        p_user_id, p_difficulty, v_variant,
        case when v_source = 'server_assigned' then 'server_assigned' else 'bundled_dev_fallback' end,
        v_ids, v_versions, v_fp, now() + make_interval(hours => cfg.match_ttl_hours)
    )
    returning match_id into v_id;
    insert into public.versus_match_solutions (match_id, expected_solutions) values (v_id, v_solutions);

    return query select v.*, false from public.versus_player_rows(p_user_id) v where v.match_id = v_id;
end;
$$;

revoke all on function public.versus_find_match(uuid, text) from public, anon, authenticated;
grant execute on function public.versus_find_match(uuid, text) to service_role;

-- 8l. THE ONLY WRITER of Versus results (service_role, via
--     submit-versus-result). Steps:
--       1. existing (match, user) result → returned again (duplicate),
--       2. lock the match row; the caller must be player A or B,
--       3. overdue → resolved NOW under the lock (forfeit / expiry) and
--          outcome 'expired' is returned (a late result never counts, and
--          the expiry commits deterministically),
--       4. closed match → VERSUS_MATCH_CLOSED; protocol / version checks,
--       5. every case result against the SNAPSHOT: ids, versions, quarter
--          order, placements ⊂ exact solution, distinct players / slots,
--          solved = complete, failed = incomplete, overtime iff 2–2,
--          hints_used must be 0 (no purchased advantage),
--       6. score from versus_config (server-derived facts only),
--       7. insert, then versus_resolve_locked — a winner is decided exactly
--          once, by whichever submission completes the pair.
create or replace function public.versus_record_result(
    p_user_id          uuid,
    p_match_id         uuid,
    p_case_results     jsonb,
    p_started_at       timestamptz,
    p_completed_at     timestamptz,
    p_game_version     text,
    p_versus_protocol  int
)
returns table (
    outcome                text,
    result_id              uuid,
    final_score            int,
    cases_solved           int,
    match_status           text,
    player_state           text,
    match_outcome          text,
    opponent_final_score   int
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
    cfg            public.versus_config%rowtype;
    v_m            public.versus_matches%rowtype;
    v_existing     public.versus_match_results%rowtype;
    v_expected_all jsonb;
    v_version      text := btrim(coalesce(p_game_version, ''));
    v_n            int;
    v_i            int;
    v_cr           jsonb;
    v_pl           jsonb;
    v_expected     jsonb;
    v_players      text[];
    v_slots        text[];
    v_outcome      text;
    v_solved       int := 0;
    v_ot_played    boolean;
    v_ot_won       boolean := false;
    v_won          boolean;
    v_hints        int := 0;
    v_base         int;
    v_mult         numeric(4,2);
    v_final        int;
    v_id           uuid;
    v_issued       timestamptz;
begin
    if p_user_id is null or p_match_id is null then
        raise exception 'INVALID_ARGUMENTS';
    end if;
    select * into cfg from public.versus_config c where c.id = 1;
    if not found then
        raise exception 'VERSUS_CONFIG_MISSING';
    end if;

    -- 1. Idempotent retry (fast path).
    select * into v_existing from public.versus_match_results r
    where r.match_id = p_match_id and r.user_id = p_user_id;
    if found then
        return query select 'duplicate'::text, v_existing.result_id, v_existing.final_score, v_existing.cases_solved,
                            v.status, v.player_state, v.outcome, v.opponent_final_score
                     from public.versus_player_rows(p_user_id) v where v.match_id = p_match_id;
        return;
    end if;

    -- 2. Lock + membership.
    select * into v_m from public.versus_matches m where m.match_id = p_match_id for update;
    if not found then
        raise exception 'VERSUS_MATCH_NOT_FOUND';
    end if;
    if v_m.player_a_id <> p_user_id and v_m.player_b_id is distinct from p_user_id then
        raise exception 'VERSUS_NOT_A_MEMBER';
    end if;
    select * into v_existing from public.versus_match_results r
    where r.match_id = p_match_id and r.user_id = p_user_id;
    if found then
        return query select 'duplicate'::text, v_existing.result_id, v_existing.final_score, v_existing.cases_solved,
                            v.status, v.player_state, v.outcome, v.opponent_final_score
                     from public.versus_player_rows(p_user_id) v where v.match_id = p_match_id;
        return;
    end if;

    -- 3. Lazy expiry under the lock: the late result never counts.
    if v_m.status in ('waiting_for_opponent', 'active') and v_m.expires_at <= now() then
        perform public.versus_resolve_locked(p_match_id);
        return query select 'expired'::text, null::uuid, null::int, null::int,
                            v.status, v.player_state, v.outcome, v.opponent_final_score
                     from public.versus_player_rows(p_user_id) v where v.match_id = p_match_id;
        return;
    end if;

    -- 4. Status, protocol, version.
    if v_m.status not in ('waiting_for_opponent', 'active') then
        raise exception 'VERSUS_MATCH_CLOSED';
    end if;
    if p_versus_protocol is null or p_versus_protocol < cfg.min_versus_protocol then
        raise exception 'CLIENT_OUTDATED';
    end if;
    if char_length(v_version) < 1 or char_length(v_version) > 40 then
        raise exception 'INVALID_GAME_VERSION';
    end if;
    select s.expected_solutions into v_expected_all
    from public.versus_match_solutions s where s.match_id = p_match_id;
    if v_expected_all is null then
        raise exception 'VERSUS_SNAPSHOT_MISSING';
    end if;

    -- 5. Case results against the snapshot.
    if p_case_results is null or jsonb_typeof(p_case_results) <> 'array' then
        raise exception 'INVALID_CASE_RESULTS';
    end if;
    v_n := jsonb_array_length(p_case_results);
    if v_n not in (4, 5) then
        raise exception 'INVALID_CASE_RESULTS';
    end if;
    for v_i in 0 .. v_n - 1 loop
        v_cr := p_case_results -> v_i;
        if jsonb_typeof(v_cr) <> 'object' then
            raise exception 'INVALID_CASE_RESULTS';
        end if;
        if (v_cr ->> 'case_id') is distinct from v_m.case_ids[v_i + 1] then
            raise exception 'CASE_MISMATCH';
        end if;
        if (v_cr -> 'case_version') is distinct from to_jsonb(v_m.case_versions[v_i + 1]) then
            raise exception 'CASE_VERSION_MISMATCH';
        end if;
        if (v_cr -> 'quarter_index') is distinct from to_jsonb(v_i) then
            raise exception 'INVALID_CASE_RESULTS';
        end if;
        v_outcome := v_cr ->> 'outcome';
        if v_outcome is null or v_outcome not in ('solved', 'failed') then
            raise exception 'INVALID_CASE_RESULTS';
        end if;
        v_hints := v_hints + public.ranked_json_int(v_cr -> 'hints_used', 0, 100);
        perform public.ranked_json_int(v_cr -> 'wrong_placements', 0, 100);
        if jsonb_typeof(v_cr -> 'placements') is distinct from 'array'
           or jsonb_array_length(v_cr -> 'placements') > 8 then
            raise exception 'INVALID_CASE_RESULTS';
        end if;
        v_expected := v_expected_all -> v_i;
        v_players := '{}';
        v_slots := '{}';
        for v_pl in select e.value from jsonb_array_elements(v_cr -> 'placements') e loop
            if jsonb_typeof(v_pl) <> 'object'
               or jsonb_typeof(v_pl -> 'player_key') is distinct from 'string'
               or jsonb_typeof(v_pl -> 'slot_key') is distinct from 'string'
               or jsonb_typeof(v_pl -> 'profile') is distinct from 'string' then
                raise exception 'INVALID_CASE_RESULTS';
            end if;
            if not (v_expected @> jsonb_build_array(jsonb_build_object(
                    'player_key', v_pl ->> 'player_key',
                    'slot_key', v_pl ->> 'slot_key',
                    'profile', v_pl ->> 'profile'))) then
                raise exception 'PLACEMENT_MISMATCH';
            end if;
            if (v_pl ->> 'player_key') = any(v_players) or (v_pl ->> 'slot_key') = any(v_slots) then
                raise exception 'PLACEMENT_MISMATCH';
            end if;
            v_players := v_players || (v_pl ->> 'player_key');
            v_slots := v_slots || (v_pl ->> 'slot_key');
        end loop;
        if v_outcome = 'solved' and cardinality(v_players) <> jsonb_array_length(v_expected) then
            raise exception 'SOLVED_CASE_INCOMPLETE';
        end if;
        if v_outcome = 'failed' and cardinality(v_players) >= jsonb_array_length(v_expected) then
            raise exception 'FAILED_CASE_COMPLETE';
        end if;
        if v_i < 4 and v_outcome = 'solved' then
            v_solved := v_solved + 1;
        end if;
        if v_i = 4 then
            v_ot_won := v_outcome = 'solved';
        end if;
    end loop;
    v_ot_played := v_solved = 2;
    if (v_n = 5) <> v_ot_played then
        raise exception 'OVERTIME_MISMATCH';
    end if;
    if v_hints > 0 and not cfg.purchasable_hints_allowed then
        raise exception 'VERSUS_HINTS_NOT_ALLOWED';
    end if;
    v_won := v_solved >= 3 or v_ot_won;

    -- 6. Score (server-derived facts only).
    v_base := v_solved * cfg.quarter_solved_points
        + (case when v_won then cfg.game_win_points else 0 end)
        + (case when v_ot_won then cfg.overtime_win_points else 0 end)
        + (case when v_solved = 4 then cfg.perfect_regulation_points else 0 end);
    v_mult := case v_m.difficulty
        when 'rookie' then cfg.rookie_multiplier
        when 'pro' then cfg.pro_multiplier
        when 'all_pro' then cfg.all_pro_multiplier
        when 'hall_of_famer' then cfg.hall_of_famer_multiplier
    end;
    v_final := round(v_base::numeric * v_mult)::int;
    v_issued := case when v_m.player_a_id = p_user_id then v_m.created_at else v_m.matched_at end;

    -- 7. Record once, then resolve under the same lock.
    begin
        insert into public.versus_match_results (
            match_id, user_id, regulation_quarters_solved, overtime_played, overtime_won,
            cases_solved, game_won, base_score, difficulty_multiplier, final_score,
            case_results, server_elapsed_seconds, client_started_at, client_completed_at,
            game_version, versus_protocol
        ) values (
            p_match_id, p_user_id, v_solved, v_ot_played, v_ot_won,
            v_solved + (case when v_ot_won then 1 else 0 end), v_won, v_base, v_mult, v_final,
            p_case_results, greatest(0, floor(extract(epoch from (now() - v_issued))))::int,
            p_started_at, p_completed_at, v_version, p_versus_protocol
        )
        returning result_id into v_id;
    exception
        when unique_violation then
            select * into v_existing from public.versus_match_results r
            where r.match_id = p_match_id and r.user_id = p_user_id;
            return query select 'duplicate'::text, v_existing.result_id, v_existing.final_score, v_existing.cases_solved,
                                v.status, v.player_state, v.outcome, v.opponent_final_score
                         from public.versus_player_rows(p_user_id) v where v.match_id = p_match_id;
            return;
    end;

    perform public.versus_resolve_locked(p_match_id);

    return query select 'recorded'::text, v_id, v_final, v_solved + (case when v_ot_won then 1 else 0 end),
                        v.status, v.player_state, v.outcome, v.opponent_final_score
                 from public.versus_player_rows(p_user_id) v where v.match_id = p_match_id;
end;
$$;

revoke all on function public.versus_record_result(uuid, uuid, jsonb, timestamptz, timestamptz, text, int) from public, anon, authenticated;
grant execute on function public.versus_record_result(uuid, uuid, jsonb, timestamptz, timestamptz, text, int) to service_role;

-- 8m. CLIENT READS (authenticated only; user = auth.uid()). Each resolves
--     the relevant overdue matches first, so what the client sees is
--     always the server's settled truth.
--     my_versus_matches: open matches (waiting / active / submitted /
--     opponent pending). my_versus_history: completed matches, newest
--     first, page size capped at 50.
create or replace function public.my_versus_matches()
returns table (
    match_id               uuid,
    status                 text,
    player_state           text,
    role                   text,
    difficulty             text,
    case_ids               text[],
    case_versions          int[],
    catalog_fingerprint    text,
    content_source         text,
    created_at             timestamptz,
    matched_at             timestamptz,
    expires_at             timestamptz,
    completed_at           timestamptz,
    opponent_user_id       uuid,
    opponent_username      text,
    opponent_display_name  text,
    my_submitted           boolean,
    my_final_score         int,
    my_cases_solved        int,
    opponent_submitted     boolean,
    opponent_final_score   int,
    opponent_cases_solved  int,
    outcome                text,
    is_forfeit             boolean,
    resolution             text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'AUTH_REQUIRED';
    end if;
    perform public.versus_expire_due(v_uid);
    return query
        select v.* from public.versus_player_rows(v_uid) v
        where v.status in ('waiting_for_opponent', 'active')
        order by v.created_at desc;
end;
$$;

revoke all on function public.my_versus_matches() from public, anon;
grant execute on function public.my_versus_matches() to authenticated;

create or replace function public.my_versus_history(p_limit int default 20, p_offset int default 0)
returns table (
    match_id               uuid,
    difficulty             text,
    completed_at           timestamptz,
    opponent_user_id       uuid,
    opponent_username      text,
    opponent_display_name  text,
    my_final_score         int,
    opponent_final_score   int,
    outcome                text,
    is_forfeit             boolean,
    resolution             text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'AUTH_REQUIRED';
    end if;
    perform public.versus_expire_due(v_uid);
    return query
        select v.match_id, v.difficulty, v.completed_at, v.opponent_user_id, v.opponent_username,
               v.opponent_display_name, v.my_final_score, v.opponent_final_score, v.outcome,
               v.is_forfeit, v.resolution
        from public.versus_player_rows(v_uid) v
        where v.status = 'completed'
        order by v.completed_at desc, v.match_id
        limit least(greatest(coalesce(p_limit, 20), 1), 50)
        offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function public.my_versus_history(int, int) from public, anon;
grant execute on function public.my_versus_history(int, int) to authenticated;

-- Public Versus record of any player: public profile columns + the six
-- counters. Never real names, email or match internals.
create or replace function public.versus_public_record(p_user_id uuid)
returns table (
    user_id                uuid,
    username               text,
    football_display_name  text,
    versus_games_played    int,
    versus_wins            int,
    versus_losses          int,
    versus_ties            int,
    versus_forfeit_wins    int,
    versus_forfeit_losses  int
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
    if auth.uid() is null then
        raise exception 'AUTH_REQUIRED';
    end if;
    if p_user_id is null then
        return;
    end if;
    perform public.versus_expire_due(p_user_id);
    return query
        select pp.id, pp.username, pp.football_display_name,
               coalesce(s.versus_games_played, 0), coalesce(s.versus_wins, 0),
               coalesce(s.versus_losses, 0), coalesce(s.versus_ties, 0),
               coalesce(s.versus_forfeit_wins, 0), coalesce(s.versus_forfeit_losses, 0)
        from public.public_profiles pp
        left join public.versus_career_stats s on s.user_id = pp.id
        where pp.id = p_user_id;
end;
$$;

revoke all on function public.versus_public_record(uuid) from public, anon;
grant execute on function public.versus_public_record(uuid) to authenticated;

-- ===========================================================================
-- Future tables (Phase 13A defines the shape; features come later):
--   factions, faction_members (max 11 per faction-season = starting lineup),
--   faction_season_roster_slots (position per slot, footballDisplayName
--   snapshot), competitive_seasons, competitive_season_members,
--   competitive_game_assignments (Phase 14B ships ranked_seasons +
--   ranked_match_assignments above for solo-season leaderboards; Versus /
--   Faction will use server_assigned cases), competitive_game_results
--   (Phase 14 ships ranked_game_results above), faction_battles, faction_battle_rosters,
--   faction_daily_progress.
-- Server-side rules to enforce when they land:
--   * assignments and results are written ONLY by the server (service role),
--     never by clients — no local case rerolling; stats updates to
--     profiles also come only from trusted backend logic.
--   * other users' profile reads (leaderboards, factions) go through
--     public.public_profiles, never the private profiles table.
--   * roster slot positions are unique per (faction_id, season_id).
-- ===========================================================================
"""#
}
