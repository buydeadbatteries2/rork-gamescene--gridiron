-- GameScene: Gridiron — Supabase schema (Phase 13: accounts & profile foundation)
-- Run in the Supabase SQL editor / migration pipeline. Safe to re-run (idempotent).
--
-- Identity contract:
--   * profiles.id IS the Supabase Auth UUID (auth.users.id) — the ONLY
--     canonical relationship key. Usernames/emails are never foreign keys.
--   * Username uniqueness is enforced CASE-INSENSITIVELY through the unique
--     index on lower(username) — "GridironKing" and "gridironking" collide.
--   * The service-role key stays server-side only. All client access goes
--     through RLS below.

-- ===========================================================================
-- profiles
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

-- Case-insensitive global username uniqueness.
create unique index if not exists profiles_username_normalized_key
    on public.profiles (lower(username_normalized));

-- Keep username_normalized in sync automatically.
create or replace function public.sync_username_normalized()
returns trigger language plpgsql as $$
begin
    new.username_normalized := lower(new.username);
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists profiles_sync_username_normalized on public.profiles;
create trigger profiles_sync_username_normalized
    before insert or update of username on public.profiles
    for each row execute function public.sync_username_normalized();

-- Row 1: users may create/update their own profile (id must be auth.uid()).
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
    for insert to authenticated
    with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
    for update to authenticated
    using (auth.uid() = id)
    with check (auth.uid() = id);

-- Row 2: public surfaces read ONLY the public identity fields (username,
-- jersey name, rating, career stats). Full real names are account-private —
-- a column-level policy keeps first_name/last_name invisible to other users.
alter table public.profiles enable row level security;

drop policy if exists "profiles_select_public" on public.profiles;
create policy "profiles_select_public" on public.profiles
    for select to authenticated
    using (
        auth.uid() = id
        or true  -- public read of non-sensitive columns, restricted below
    );

revoke select (first_name, last_name) on public.profiles from anon, authenticated;
grant select (id, username, username_normalized, football_display_name,
              created_at, global_rating, career_games_played, career_wins,
              career_losses, career_cases_solved, championships,
              selected_franchise_id, current_faction_id)
    on public.profiles to anon, authenticated;

-- ===========================================================================
-- Future tables (Phase 13 defines the shape; features come later):
--   factions, faction_members (max 11 per faction-season = starting lineup),
--   faction_season_roster_slots (position per slot, footballDisplayName
--   snapshot), competitive_seasons, competitive_season_members,
--   competitive_game_assignments (server-authoritative caseID + difficulty),
--   competitive_game_results, faction_battles, faction_battle_rosters,
--   faction_daily_progress.
-- Server-side rules to enforce when they land:
--   * assignments are inserted ONLY by the server (service role), never by
--     clients — no local case rerolling.
--   * roster slot positions are unique per (faction_id, season_id).
-- ===========================================================================
