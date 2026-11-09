-- Additive team-identity backup. No roster, season, economy or competitive changes.
create table if not exists public.user_teams (
    user_id uuid primary key references auth.users(id) on delete cascade,
    team_id uuid not null,
    state text not null check (length(trim(state)) between 1 and 100),
    team_name text not null check (length(trim(team_name)) between 1 and 100),
    logo_id text not null check (length(trim(logo_id)) between 1 and 100),
    primary_color bigint not null check (primary_color between 0 and 16777215),
    secondary_color bigint not null check (secondary_color between 0 and 16777215)
);
alter table public.user_teams enable row level security;
revoke all on public.user_teams from public, anon, authenticated;
grant select, insert on public.user_teams to authenticated;
-- Identity is immutable to client updates; migration inserts ON CONFLICT DO NOTHING.
grant update (state, team_name, logo_id, primary_color, secondary_color)
    on public.user_teams to authenticated;
drop policy if exists user_teams_select_own on public.user_teams;
create policy user_teams_select_own on public.user_teams for select to authenticated
    using (auth.uid() = user_id);
drop policy if exists user_teams_insert_own on public.user_teams;
create policy user_teams_insert_own on public.user_teams for insert to authenticated
    with check (auth.uid() = user_id);
drop policy if exists user_teams_update_own on public.user_teams;
create policy user_teams_update_own on public.user_teams for update to authenticated
    using (auth.uid() = user_id) with check (auth.uid() = user_id);
