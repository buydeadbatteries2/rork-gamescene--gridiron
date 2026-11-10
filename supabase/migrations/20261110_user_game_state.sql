-- Owner-private solo progress backup, not a source of ranked scores or entitlements.
-- Apply after 20261109_user_teams.sql. No existing game/profile tables are rewritten.
create table if not exists public.user_game_state (
    user_id uuid primary key references auth.users(id) on delete cascade,
    team_id uuid not null,
    schema_version integer not null default 1 check (schema_version = 1),
    revision bigint not null default 1 check (revision > 0),
    snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object' and octet_length(snapshot::text) <= 4194304),
    updated_at timestamptz not null default now()
);
alter table public.user_game_state enable row level security;
revoke all on public.user_game_state from public, anon, authenticated;
grant select on public.user_game_state to authenticated;
grant insert (user_id, team_id, schema_version, snapshot) on public.user_game_state to authenticated;
grant update (schema_version, snapshot) on public.user_game_state to authenticated;
drop policy if exists game_state_select_own on public.user_game_state;
create policy game_state_select_own on public.user_game_state for select to authenticated using (auth.uid() = user_id);
drop policy if exists game_state_insert_own on public.user_game_state;
create policy game_state_insert_own on public.user_game_state for insert to authenticated
    with check (auth.uid() = user_id and exists (select 1 from public.user_teams t where t.user_id = auth.uid() and t.team_id = user_game_state.team_id));
drop policy if exists game_state_update_own on public.user_game_state;
create policy game_state_update_own on public.user_game_state for update to authenticated
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id and exists (select 1 from public.user_teams t where t.user_id = auth.uid() and t.team_id = user_game_state.team_id));

create or replace function public.stamp_user_game_state() returns trigger
language plpgsql set search_path = '' as $$
begin
    if (new.snapshot->>'schemaVersion')::integer is distinct from new.schema_version
       or (new.snapshot->>'teamID')::uuid is distinct from new.team_id then
        raise exception 'Invalid progress snapshot identity';
    end if;
    if tg_op = 'UPDATE' then
        new.revision := old.revision + 1;
    else
        new.revision := 1;
    end if;
    new.updated_at := clock_timestamp();
    return new;
end;
$$;
revoke all on function public.stamp_user_game_state() from public, anon, authenticated;
drop trigger if exists stamp_user_game_state on public.user_game_state;
create trigger stamp_user_game_state before insert or update on public.user_game_state
    for each row execute function public.stamp_user_game_state();
