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
-- 4. AUTH-USER PROFILE CREATION (Phase 13D) — the signup trigger.
--    When the project has "Confirm email" enabled, Supabase signup returns
--    a user but NO authenticated session, so the CLIENT CANNOT insert its
--    own profile (RLS requires auth.uid() = id). The initial profile is
--    therefore created by trusted database logic when the auth user is
--    created: the client passes username / first_name / last_name as signup
--    user metadata (never passwords or sensitive data — email/password are
--    handled by Supabase Auth itself), and this function turns them into a
--    profile row. The existing derived-fields trigger (section 2) then
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
-- Future tables (Phase 13A defines the shape; features come later):
--   factions, faction_members (max 11 per faction-season = starting lineup),
--   faction_season_roster_slots (position per slot, footballDisplayName
--   snapshot), competitive_seasons, competitive_season_members,
--   competitive_game_assignments (server-authoritative caseID + difficulty),
--   competitive_game_results, faction_battles, faction_battle_rosters,
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
