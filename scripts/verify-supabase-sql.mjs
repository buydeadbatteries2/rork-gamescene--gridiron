// Phase 14A — LOCAL dry run of supabase/schema.sql + competitive_catalog.sql.
//
// Runs both files inside an in-memory PGlite (real Postgres compiled to
// WASM) with a minimal Supabase shim (auth.users, auth.uid(), anon /
// authenticated / service_role roles). Nothing touches a real Supabase
// project. It proves the files apply cleanly, the catalog checksum
// self-check passes, and the leaderboard security / scoring / week rules
// behave as documented.
//
//   mkdir -p /tmp/pgcheck && cd /tmp/pgcheck && bun add @electric-sql/pglite
//   PGLITE=/tmp/pgcheck/node_modules/@electric-sql/pglite/dist/index.js \
//     bun scripts/verify-supabase-sql.mjs
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const { PGlite } = await import(process.env.PGLITE ?? "/tmp/pgcheck/node_modules/@electric-sql/pglite/dist/index.js");
const db = new PGlite();

let passed = 0;
const failures = [];
function check(name, condition, detail = "") {
  if (condition) passed += 1;
  else failures.push(`${name} ${detail}`);
}
async function expectError(name, sql, fragment) {
  try {
    await db.exec(sql);
    failures.push(`${name}: expected error containing "${fragment}"`);
  } catch (error) {
    check(name, String(error.message).includes(fragment), `got: ${error.message}`);
  }
}
async function rows(sql, params = []) {
  return (await db.query(sql, params)).rows;
}

// ---------------------------------------------------------------- shim
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin bypassrls;
  create schema auth;
  create table auth.users (id uuid primary key, raw_user_meta_data jsonb, created_at timestamptz default now());
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $$;
  grant usage on schema auth to anon, authenticated, service_role;
  grant execute on function auth.uid() to anon, authenticated, service_role;
  grant usage on schema public to anon, authenticated, service_role;
  -- Supabase's default privileges hand every new public table to the API
  -- roles; the schema must revoke what it does not want exposed.
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
  alter default privileges in schema public grant execute on functions to anon, authenticated, service_role;
`);

// ---------------------------------------------------------------- apply
const schema = readFileSync(join(ROOT, "supabase/schema.sql"), "utf8");
const catalog = readFileSync(join(ROOT, "supabase/competitive_catalog.sql"), "utf8");
await db.exec(schema);
check("schema applies", true);
await db.exec(schema); // idempotent re-paste
check("schema re-applies (idempotent)", true);
await db.exec(catalog);
check("catalog applies + checksum self-check", true);
await db.exec(catalog);
check("catalog re-applies (idempotent)", true);

const meta = await rows(`select public.competitive_catalog_checksum() as actual, expected_checksum from public.competitive_catalog_meta`);
check("checksum matches export", meta[0].actual === meta[0].expected_checksum, JSON.stringify(meta[0]));
const counts = await rows(`
  select count(*)::int as n,
         count(*) filter (where difficulty_score between 1 and 100)::int as scored,
         count(*) filter (where competitive_eligible and active)::int as eligible
  from public.competitive_cases`);
check("150 catalog rows", counts[0].n === 150, JSON.stringify(counts[0]));
check("every row has a 1-100 score", counts[0].scored === 150);
check("150 eligible", counts[0].eligible === 150);
const dist = await rows(`select difficulty, min(difficulty_score) lo, max(difficulty_score) hi, count(*)::int n from public.competitive_cases group by 1 order by 2`);
console.log("score distribution:", dist.map((d) => `${d.difficulty} ${d.n} [${d.lo}-${d.hi}]`).join(", "));

// Drift detection: tamper with one solution → checksum differs.
await db.exec(`begin; update public.competitive_cases set solutions = jsonb_set(solutions, '{pro,0,profile}', '"overrated"') where case_id = 'case_rookie_060';`);
const tampered = await rows(`select public.competitive_catalog_checksum() as c`);
check("tampered solution changes checksum", tampered[0].c !== meta[0].expected_checksum);
await db.exec(`rollback;`);

// ---------------------------------------------------------------- users
const alice = "11111111-1111-1111-1111-111111111111";
const bob = "22222222-2222-2222-2222-222222222222";
await db.exec(`
  insert into auth.users (id, raw_user_meta_data) values
    ('${alice}', '{"username":"alice_qb","first_name":"Alice","last_name":"Secret"}'),
    ('${bob}',   '{"username":"bob_lb","first_name":"Bob","last_name":"Hidden"}');
  update public.profiles set created_at = now() - interval '90 days';
`);
check("signup trigger created profiles", (await rows(`select count(*)::int n from public.profiles`))[0].n === 2);

async function asUser(id, sql) {
  await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub', '${id}', false);`);
  try {
    return await rows(sql);
  } finally {
    await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`);
  }
}
async function asUserExpectError(name, id, sql, fragment) {
  await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub', '${id}', false);`);
  try {
    await db.exec(sql);
    failures.push(`${name}: expected error containing "${fragment}"`);
  } catch (error) {
    check(name, String(error.message).includes(fragment), `got: ${error.message}`);
  } finally {
    await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`);
  }
}

// ---------------------------------------------------------------- security
await asUserExpectError("client cannot read competitive_cases", alice, `select * from public.competitive_cases`, "permission denied");
await asUserExpectError("client cannot read solutions column", alice, `select solutions from public.competitive_cases`, "permission denied");
await asUserExpectError("client cannot read catalog meta", alice, `select * from public.competitive_catalog_meta`, "permission denied");
await asUserExpectError("client cannot run checksum fn", alice, `select public.competitive_catalog_checksum()`, "permission denied");
await asUserExpectError("client cannot read scoring config", alice, `select * from public.ranked_scoring_config`, "permission denied");
await asUserExpectError("client cannot read attempts", alice, `select * from public.ranked_submission_attempts`, "permission denied");
await asUserExpectError("client cannot insert ranked result", alice,
  `insert into public.ranked_game_results (match_id, user_id, game_number, difficulty, regulation_quarters_solved, regulation_quarters_lost, game_won, overtime_played, overtime_won, wrong_placements, hints_used, base_score, difficulty_multiplier, final_score)
   values (gen_random_uuid(), '${alice}', 1, 'pro', 4, 0, true, false, false, 0, 0, 41, 1.25, 999)`, "permission denied");
await asUserExpectError("client cannot call record fn", alice,
  `select * from public.record_verified_ranked_result('${alice}', gen_random_uuid(), null, 1, 'pro', 4, true, false, false, 0, 0, '[]', now() - interval '10 minutes', now(), 'x')`, "permission denied");
await asUserExpectError("client cannot call internal board fn", alice, `select * from public.ranked_leaderboard_rows('weekly', 'all')`, "permission denied");
await asUserExpectError("client cannot set global_rating", alice, `update public.profiles set global_rating = 9999 where id = '${alice}'`, "permission denied");
await asUserExpectError("anon cannot read leaderboard", alice, `set role anon; select * from public.ranked_leaderboard('weekly')`, "permission denied");

// ---------------------------------------------------------------- recording
const caseRows = await rows(`select case_id from public.competitive_cases order by case_id limit 5`);
async function record({ user = alice, match, season = null, game = 1, difficulty = "pro", solved = 4, won = true, otPlayed = false, otWon = false, wrong = 0, hints = 0, started, completed }) {
  const r = await rows(
    `select * from public.record_verified_ranked_result($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12::jsonb, $13::timestamptz, $14::timestamptz, 'ios-test')`,
    [user, match, season, game, difficulty, solved, won, otPlayed, otWon, wrong, hints, JSON.stringify(caseRows.map((c) => ({ case_id: c.case_id }))), started, completed],
  );
  return r[0];
}
const uuid = () => crypto.randomUUID();
const ago = (ms) => new Date(Date.now() - ms).toISOString();
const MIN = 60 * 1000, HOUR = 60 * MIN, DAY = 24 * HOUR;

await db.exec(`set role service_role;`);
// Scoring audit: HOF perfect clean = (40+10+5+3+3)*2 = 122; rookie 2/4 OT win, hints = (20+10+5+0+3)*1 = 38
const m1 = uuid();
const r1 = await record({ match: m1, difficulty: "hall_of_famer", started: ago(20 * MIN), completed: ago(5 * MIN) });
check("HOF perfect clean = 122", r1.final_score === 122, JSON.stringify(r1));
check("recent game uses completed_at", r1.leaderboard_at_source === "completed_at");
const r1b = await record({ match: m1, difficulty: "hall_of_famer", started: ago(20 * MIN), completed: ago(5 * MIN) });
check("duplicate match is idempotent", r1b.duplicate === true && r1b.final_score === 122 && r1b.result_id === r1.result_id);
await expectError("other user cannot reuse match id",
  `select * from public.record_verified_ranked_result('${bob}', '${m1}', null, 1, 'pro', 4, true, false, false, 0, 0, '[]', now() - interval '10 minutes', now(), 'x')`, "MATCH_ID_CONFLICT");
const r2 = await record({ user: bob, match: uuid(), difficulty: "rookie", solved: 2, won: true, otPlayed: true, otWon: true, hints: 2, started: ago(30 * MIN), completed: ago(2 * MIN) });
check("Rookie 2/4 + OT win, hints = 38", r2.final_score === 38, JSON.stringify(r2));
const r3 = await record({ user: bob, match: uuid(), difficulty: "pro", solved: 1, won: false, wrong: 3, started: ago(30 * MIN), completed: ago(2 * MIN) });
check("Pro 1/4 loss, no hints = (10+3)*1.25 = 16", r3.final_score === 16, JSON.stringify(r3));

// Week rule.
const backdated = await record({ match: uuid(), started: ago(6 * DAY + HOUR), completed: ago(6 * DAY) });
check("6-day-old offline game keeps validated completion time", backdated.leaderboard_at_source === "completed_at");
const tooOld = await record({ match: uuid(), started: ago(40 * DAY), completed: ago(40 * DAY - HOUR) });
check("40-day-old claim falls back to receipt", tooOld.leaderboard_at_source === "received_at");
const future = await record({ match: uuid(), started: ago(HOUR), completed: new Date(Date.now() + 2 * HOUR).toISOString() });
check("future completion falls back to receipt", future.leaderboard_at_source === "received_at");
const instant = await record({ match: uuid(), started: ago(10 * 1000), completed: ago(5 * 1000) });
check("5-second game falls back to receipt", instant.leaderboard_at_source === "received_at");
const marathon = await record({ match: uuid(), started: ago(20 * DAY), completed: ago(HOUR) });
check(">168h game falls back to receipt", marathon.leaderboard_at_source === "received_at");
const preAccount = await rows(`select created_at from public.profiles where id = '${alice}'`);
await db.exec(`reset role; update public.profiles set created_at = now() - interval '1 day' where id = '${bob}'; set role service_role;`);
const beforeAccount = await record({ user: bob, match: uuid(), started: ago(3 * DAY), completed: ago(3 * DAY - HOUR) });
check("game before account creation falls back to receipt", beforeAccount.leaderboard_at_source === "received_at");
const season = uuid();
const g2 = await record({ match: uuid(), season, game: 2, started: ago(2 * DAY + HOUR), completed: ago(2 * DAY) });
check("season game 2 trusted", g2.leaderboard_at_source === "completed_at");
const g3 = await record({ match: uuid(), season, game: 3, started: ago(4 * DAY + HOUR), completed: ago(4 * DAY) });
check("season game 3 completing before game 2 falls back", g3.leaderboard_at_source === "received_at");
await expectError("season difficulty is locked",
  `select * from public.record_verified_ranked_result('${alice}', gen_random_uuid(), '${season}', 4, 'rookie', 4, true, false, false, 0, 0, '[]', now() - interval '10 minutes', now(), 'x')`, "SEASON_DIFFICULTY_MISMATCH");
await expectError("season game number cannot score twice",
  `select * from public.record_verified_ranked_result('${alice}', gen_random_uuid(), '${season}', 2, 'pro', 4, true, false, false, 0, 0, '[]', now() - interval '10 minutes', now(), 'x')`, "DUPLICATE_SEASON_GAME");

// Career stats + rating updated server-side only.
await db.exec(`reset role;`);
const aliceProfile = (await rows(`select career_games_played, career_wins, global_rating, championships from public.profiles where id = '${alice}'`))[0];
check("career stats counted per verified game", aliceProfile.career_games_played === 8 && aliceProfile.career_wins === 8, JSON.stringify(aliceProfile));
check("championships never incremented", aliceProfile.championships === 0);

// ---------------------------------------------------------------- reads
const weekly = await asUser(alice, `select * from public.ranked_leaderboard('weekly')`);
const weeklyCols = Object.keys(weekly[0] ?? {});
check("weekly board returns rows", weekly.length === 2, JSON.stringify(weekly));
check("board exposes no solutions/real names", !weeklyCols.some((c) => /solution|first_name|last_name|email|case_results/.test(c)), weeklyCols.join(","));
const weekStart = (await rows(`select date_trunc('week', now() at time zone 'utc') at time zone 'utc' as ts`))[0].ts;
const aliceWeekly = weekly.find((r) => r.user_id === alice);
const expectedWeekly = (await rows(
  `select coalesce(sum(final_score), 0)::int s from (select final_score from public.ranked_game_results where user_id = $1 and leaderboard_at >= $2 order by final_score desc limit 10) t`,
  [alice, weekStart],
))[0].s;
check("weekly score sums this week's leaderboard_at games", Number(aliceWeekly.score) === expectedWeekly, `${aliceWeekly.score} vs ${expectedWeekly}`);
const alltime = await asUser(alice, `select * from public.ranked_leaderboard('alltime')`);
const bobRow = alltime.find((r) => r.user_id === bob);
const aliceRow = alltime.find((r) => r.user_id === alice);
check("bob (<5 games) is provisional", bobRow.is_provisional === true);
check("alice (>=5 games) is established", aliceRow.is_provisional === false);
check("established ranks above provisional", Number(aliceRow.rank) < Number(bobRow.rank));
const mine = await asUser(bob, `select * from public.my_ranked_standing('alltime')`);
check("my standing returns only caller", mine.length === 1 && mine[0].user_id === bob);
const ownRows = await asUser(bob, `select user_id from public.ranked_game_results`);
check("clients read only their own result rows", ownRows.length > 0 && ownRows.every((r) => r.user_id === bob));
const search = await asUser(bob, `select * from public.search_public_profiles('ali')`);
check("search returns public columns only", search.length === 1 && !("first_name" in search[0]));
await asUserExpectError("client cannot update verified result", alice, `update public.ranked_game_results set final_score = 9999 where user_id = '${alice}'`, "permission denied");
await asUserExpectError("client cannot delete verified result", alice, `delete from public.ranked_game_results where user_id = '${alice}'`, "permission denied");

console.log(`\n${passed} checks passed, ${failures.length} failed`);
for (const f of failures) console.log("FAIL:", f);
process.exit(failures.length ? 1 : 0);
