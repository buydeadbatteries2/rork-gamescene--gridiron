// Local Postgres/WASM policy checks; never connects to the production database.
// PGLITE=/path/to/@electric-sql/pglite/dist/index.js bun scripts/verify-user-teams-sql.mjs
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.PGLITE);
const db = new PGlite();
let passed = 0;
const check = (value) => { assert.ok(value); passed++; };
const denied = async (sql) => {
  await assert.rejects(db.exec(sql)); passed++;
};
await db.exec(`
create role anon; create role authenticated;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$
select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth, public to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated;
insert into auth.users values ('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002');
`);
const migration = readFileSync(new URL('../supabase/migrations/20261109_user_teams.sql', import.meta.url), 'utf8');
await db.exec(migration);
await db.exec(migration); // Deployment idempotency.
const a = '00000000-0000-0000-0000-000000000001';
const b = '00000000-0000-0000-0000-000000000002';
const team = '10000000-0000-0000-0000-000000000001';
const insert = (owner, name = 'Wolves', color = 123) => `insert into public.user_teams values ('${owner}', '${team}', 'Virginia', '${name}', 'wolf', ${color}, 456)`;
await db.exec(`set role authenticated; set request.jwt.claim.sub = '${a}';`);
await db.exec(insert(a));
check((await db.query('select * from public.user_teams')).rows.length === 1);
await db.exec(insert(a, 'Cannot overwrite') + ' on conflict (user_id) do nothing');
check((await db.query('select team_name from public.user_teams')).rows[0].team_name === 'Wolves');
await denied(insert(b));
await denied(`update public.user_teams set user_id = '${b}'`);
await denied(`update public.user_teams set team_id = '${b}'`);
await denied('delete from public.user_teams');
await denied('update public.user_teams set primary_color = 16777216');
await db.exec("update public.user_teams set team_name = 'Edited'");
check((await db.query('select team_name from public.user_teams')).rows[0].team_name === 'Edited');
await db.exec(`set request.jwt.claim.sub = '${b}';`);
check((await db.query('select * from public.user_teams')).rows.length === 0);
await db.exec("update public.user_teams set team_name = 'Other account'");
await denied(insert(b, '', 123));
await db.exec(insert(b));
check((await db.query('select * from public.user_teams')).rows.length === 1);
await db.exec('set role anon');
await denied('select * from public.user_teams');
await denied(insert(a));
await db.exec('reset role');
check((await db.query(`select team_name from public.user_teams where user_id = '${a}'`)).rows[0].team_name === 'Edited');
await db.exec(`delete from auth.users where id = '${a}'`);
check((await db.query(`select * from public.user_teams where user_id = '${a}'`)).rows.length === 0);
await db.close();
console.log(`${passed} user-team SQL checks passed (local PGlite; no production access).`);
