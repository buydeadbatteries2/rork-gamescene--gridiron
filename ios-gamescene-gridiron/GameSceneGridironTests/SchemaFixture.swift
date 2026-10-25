import Foundation

/// Byte-identical snapshot of `supabase/schema.sql` (repo root). The test
/// runner only receives the app folder — the repo-root `supabase/` directory
/// is not part of the uploaded source — so the tests pin this copy. Keep the
/// two files in sync: schema.sql is what gets pasted into Supabase, this
/// fixture is what SchemaHardeningTests validates. Regenerate with
/// scripts/regenerate-schema-fixture.sh after editing schema.sql.
enum SchemaFixture {
    static let sql = #"""
-- GameScene: Gridiron — Supabase schema (Phase 13A: hardened accounts & profile; Phase 13D: signup trigger)
-- Run in the Supabase SQL editor / migration pipeline. Safe to re-run (idempotent).
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
returns trigger language plpgsql set search_path = public as $$
begin
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
returns trigger language plpgsql set search_path = public as $$
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
returns trigger language plpgsql set search_path = public as $$
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
set search_path = public
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
            coalesce(new.raw_user_meta_data->>'first_name', ''),
            coalesce(new.raw_user_meta_data->>'last_name', '')
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
create or replace function public.is_username_available(requested text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select not exists (
        select 1 from public.profiles
        where lower(username_normalized) = lower(btrim(requested))
    );
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
-- 7. PHASE 14 — GLOBAL LEADERBOARDS (server-verified ranked results)
--
--    Trust model: the client NEVER submits a score. A finished season game
--    is sent as raw facts to the `submit-ranked-result` Edge Function, which
--    derives the user from the JWT, validates every case id / version /
--    placement against the PRIVATE solutions below, and calls
--    record_verified_ranked_result (service_role only). That function is the
--    ONLY writer of ranked results and of career stats — it computes the
--    score from the single ranked_scoring_config row. Clients can read only
--    their own result rows plus leaderboard-safe aggregates through the
--    SECURITY DEFINER read functions at the end of this section, which join
--    public.public_profiles (never real names or email).
-- ===========================================================================

-- 7a. PRIVATE competitive case catalog. Populated by the GENERATED file
--     supabase/competitive_catalog.sql (paste after this schema). Solutions
--     are never readable by anon/authenticated: RLS on, no policies, and no
--     privileges. Only the service role (Edge Function) reads them.
create table if not exists public.competitive_cases (
    case_id               text        primary key,
    case_version          int         not null check (case_version >= 1),
    difficulty            text        not null check (difficulty in ('rookie', 'pro', 'all_pro', 'hall_of_famer')),
    difficulty_score      int         not null default 0,
    band                  int         not null default 0,
    missing_count         int         not null check (missing_count between 1 and 8),
    active                boolean     not null default true,
    competitive_eligible  boolean     not null default true,
    fingerprint           text        not null,
    -- {"rookie": [{player_key, slot_key, profile}…], "pro": […], "all_pro": […], "hall_of_famer": […]}
    solutions             jsonb       not null,
    updated_at            timestamptz not null default now()
);

alter table public.competitive_cases enable row level security;
revoke all on public.competitive_cases from anon, authenticated;

-- 7b. The ONE scoring configuration. Edit the row (never code) to rebalance;
--     the score function reads it on every verified result.
create table if not exists public.ranked_scoring_config (
    id                          int          primary key default 1 check (id = 1),
    quarter_solved_points       int          not null,
    game_win_points             int          not null,
    overtime_win_points         int          not null,
    perfect_regulation_points   int          not null,
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
    updated_at                  timestamptz  not null default now()
);

insert into public.ranked_scoring_config (
    id, quarter_solved_points, game_win_points, overtime_win_points,
    perfect_regulation_points, no_hints_points, no_wrong_placements_points,
    rookie_multiplier, pro_multiplier, all_pro_multiplier, hall_of_famer_multiplier,
    weekly_best_games, alltime_best_games, provisional_min_games, submissions_per_hour
) values (1, 10, 10, 5, 5, 3, 3, 1.00, 1.25, 1.50, 2.00, 10, 25, 5, 30)
on conflict (id) do update set
    quarter_solved_points      = excluded.quarter_solved_points,
    game_win_points            = excluded.game_win_points,
    overtime_win_points        = excluded.overtime_win_points,
    perfect_regulation_points  = excluded.perfect_regulation_points,
    no_hints_points            = excluded.no_hints_points,
    no_wrong_placements_points = excluded.no_wrong_placements_points,
    rookie_multiplier          = excluded.rookie_multiplier,
    pro_multiplier             = excluded.pro_multiplier,
    all_pro_multiplier         = excluded.all_pro_multiplier,
    hall_of_famer_multiplier   = excluded.hall_of_famer_multiplier,
    weekly_best_games          = excluded.weekly_best_games,
    alltime_best_games         = excluded.alltime_best_games,
    provisional_min_games      = excluded.provisional_min_games,
    submissions_per_hour       = excluded.submissions_per_hour,
    updated_at                 = now();

alter table public.ranked_scoring_config enable row level security;
revoke all on public.ranked_scoring_config from anon, authenticated;

-- 7c. Verified ranked results. One row per competitive match id (unique),
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
    created_at                  timestamptz  not null default now(),
    constraint ranked_game_results_match_id_key unique (match_id),
    constraint ranked_game_results_quarters_check
        check (regulation_quarters_solved + regulation_quarters_lost = 4),
    constraint ranked_game_results_overtime_check
        check (overtime_played or not overtime_won)
);

create unique index if not exists ranked_game_results_season_game_key
    on public.ranked_game_results (user_id, season_id, game_number)
    where season_id is not null;
create index if not exists ranked_game_results_created_at_idx
    on public.ranked_game_results (created_at);
create index if not exists ranked_game_results_user_idx
    on public.ranked_game_results (user_id, final_score desc);

alter table public.ranked_game_results enable row level security;

drop policy if exists "ranked_results_select_own" on public.ranked_game_results;
create policy "ranked_results_select_own" on public.ranked_game_results
    for select to authenticated
    using (auth.uid() = user_id);

revoke all on public.ranked_game_results from anon;
revoke insert, update, delete on public.ranked_game_results from authenticated;
grant select on public.ranked_game_results to authenticated;

-- 7d. Submission audit + rate limiting (service role only).
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
revoke all on public.ranked_submission_attempts from anon, authenticated;

-- 7e. THE ONLY WRITER of ranked results and career stats. Called by the Edge
--     Function (service_role) AFTER it validated every case against the
--     private catalog. Idempotent by match id: a repeated submission returns
--     the stored result with duplicate = true and changes nothing.
--     Championships are NOT incremented here (future verified path only).
create or replace function public.record_verified_ranked_result(
    p_user_id                    uuid,
    p_match_id                   uuid,
    p_season_id                  uuid,
    p_game_number                int,
    p_difficulty                 text,
    p_regulation_quarters_solved int,
    p_game_won                   boolean,
    p_overtime_played            boolean,
    p_overtime_won               boolean,
    p_wrong_placements           int,
    p_hints_used                 int,
    p_case_results               jsonb,
    p_started_at                 timestamptz,
    p_completed_at               timestamptz,
    p_game_version               text
)
returns table (result_id uuid, final_score int, duplicate boolean)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
    cfg       public.ranked_scoring_config%rowtype;
    existing  public.ranked_game_results%rowtype;
    v_base    int;
    v_mult    numeric(4,2);
    v_final   int;
    v_id      uuid;
begin
    select * into existing from public.ranked_game_results r where r.match_id = p_match_id;
    if found then
        if existing.user_id <> p_user_id then
            raise exception 'MATCH_ID_CONFLICT';
        end if;
        return query select existing.id, existing.final_score, true;
        return;
    end if;

    if p_season_id is not null and exists (
        select 1 from public.ranked_game_results r
        where r.user_id = p_user_id and r.season_id = p_season_id and r.difficulty <> p_difficulty
    ) then
        raise exception 'SEASON_DIFFICULTY_MISMATCH';
    end if;

    if p_season_id is not null and exists (
        select 1 from public.ranked_game_results r
        where r.user_id = p_user_id and r.season_id = p_season_id and r.game_number = p_game_number
    ) then
        raise exception 'DUPLICATE_SEASON_GAME';
    end if;

    select * into cfg from public.ranked_scoring_config c where c.id = 1;
    if not found then
        raise exception 'SCORING_CONFIG_MISSING';
    end if;

    v_base := p_regulation_quarters_solved * cfg.quarter_solved_points
        + (case when p_game_won then cfg.game_win_points else 0 end)
        + (case when p_overtime_won then cfg.overtime_win_points else 0 end)
        + (case when p_regulation_quarters_solved = 4 then cfg.perfect_regulation_points else 0 end)
        + (case when p_hints_used = 0 then cfg.no_hints_points else 0 end)
        + (case when p_wrong_placements = 0 then cfg.no_wrong_placements_points else 0 end);

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

    begin
        insert into public.ranked_game_results (
            match_id, user_id, season_id, game_number, difficulty,
            regulation_quarters_solved, regulation_quarters_lost, game_won,
            overtime_played, overtime_won, wrong_placements, hints_used,
            base_score, difficulty_multiplier, final_score, verified,
            case_results, started_at, completed_at, game_version
        ) values (
            p_match_id, p_user_id, p_season_id, p_game_number, p_difficulty,
            p_regulation_quarters_solved, 4 - p_regulation_quarters_solved, p_game_won,
            p_overtime_played, p_overtime_won, p_wrong_placements, p_hints_used,
            v_base, v_mult, v_final, true,
            coalesce(p_case_results, '[]'::jsonb), p_started_at, p_completed_at, p_game_version
        )
        returning id into v_id;
    exception
        when unique_violation then
            -- A concurrent retry of the same match won the race: idempotent.
            select * into existing from public.ranked_game_results r where r.match_id = p_match_id;
            if found and existing.user_id = p_user_id then
                return query select existing.id, existing.final_score, true;
                return;
            end if;
            raise exception 'DUPLICATE_SEASON_GAME';
    end;

    -- Career stats move ONLY here, after verification. global_rating is the
    -- rounded average of the player's best all-time verified results.
    update public.profiles p set
        career_games_played = p.career_games_played + 1,
        career_wins         = p.career_wins + (case when p_game_won then 1 else 0 end),
        career_losses       = p.career_losses + (case when p_game_won then 0 else 1 end),
        career_cases_solved = p.career_cases_solved + p_regulation_quarters_solved
                              + (case when p_overtime_won then 1 else 0 end),
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

    return query select v_id, v_final, false;
end;
$$;

revoke all on function public.record_verified_ranked_result(uuid, uuid, uuid, int, text, int, boolean, boolean, boolean, int, int, jsonb, timestamptz, timestamptz, text) from public, anon, authenticated;
grant execute on function public.record_verified_ranked_result(uuid, uuid, uuid, int, text, int, boolean, boolean, boolean, int, int, jsonb, timestamptz, timestamptz, text) to service_role;

-- 7f. INTERNAL leaderboard aggregation (not callable by clients).
--     WEEKLY: Monday 00:00 UTC → Sunday 23:59:59 UTC, bucketed by the
--     server's received time; score = SUM of the best N verified games.
--     ALL-TIME: score = AVERAGE of the best N verified games (1 decimal);
--     fewer than provisional_min_games verified games = PROVISIONAL (listed
--     after established players). Difficulty filter uses each game's
--     recorded difficulty. Tiebreakers: higher average, more wins, more
--     quarters, fewer hints, fewer wrong placements; full ties share the
--     rank and list by who reached the score first.
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
set search_path = public
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
          and (p_board = 'alltime' or r.created_at >= (select w.ts from week_start w))
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
                     s.quarters_solved desc, s.hints_used asc, s.wrong_placements asc
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

-- 7g. CLIENT READS (authenticated only). Page size is capped at 50.
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
set search_path = public
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
set search_path = public
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
set search_path = public
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
-- Future tables (Phase 13A defines the shape; features come later):
--   factions, faction_members (max 11 per faction-season = starting lineup),
--   faction_season_roster_slots (position per slot, footballDisplayName
--   snapshot), competitive_seasons, competitive_season_members,
--   competitive_game_assignments (server-authoritative caseID + difficulty),
--   competitive_game_results (Phase 14 ships ranked_game_results above for
--   solo-season leaderboards), faction_battles, faction_battle_rosters,
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
