// Phase 14A/14B — LOCAL dry run of supabase/schema.sql + competitive_catalog.sql.
//
// Runs the files inside an in-memory PGlite (real Postgres compiled to
// WASM) with a minimal Supabase shim (auth.users, auth.uid(), anon /
// authenticated / service_role roles). Nothing touches a real Supabase
// project. It first applies the Phase 14A snapshot (scripts/fixtures/) and
// records legacy results, then applies the CURRENT files on top — proving
// the migration — and exercises seasons, assignments, exact-solution
// verification, scoring, the week rules, rate limiting and hardening.
//
//   mkdir -p /tmp/pgcheck && cd /tmp/pgcheck && bun add @electric-sql/pglite
//   PGLITE=/tmp/pgcheck/node_modules/@electric-sql/pglite/dist/index.js \
//     bun scripts/verify-supabase-sql.mjs
//
// PGlite is single-connection: "concurrent" calls below are issued with
// Promise.all and serialized by the engine. They prove the single-statement
// atomic logic; true multi-backend races rely on Postgres row locks
// (ON CONFLICT DO UPDATE / SELECT … FOR UPDATE).
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
async function expectError(name, sql, fragment, params) {
  try {
    if (params) await db.query(sql, params);
    else await db.exec(sql);
    failures.push(`${name}: expected error containing "${fragment}"`);
  } catch (error) {
    check(name, String(error.message).includes(fragment), `got: ${error.message}`);
  }
}
async function rows(sql, params = []) {
  return (await db.query(sql, params)).rows;
}
const uuid = () => crypto.randomUUID();
const iso = (ms) => new Date(ms).toISOString();
const ago = (ms) => iso(Date.now() - ms);
const SEC = 1000, MIN = 60 * SEC, HOUR = 60 * MIN, DAY = 24 * HOUR;

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

// ---------------------------------------------------------------- Phase 14A state (legacy)
const alice = "11111111-1111-1111-1111-111111111111";
const bob = "22222222-2222-2222-2222-222222222222";
const carol = "33333333-3333-3333-3333-333333333333";
await db.exec(readFileSync(join(ROOT, "scripts/fixtures/phase14a_schema.sql"), "utf8"));
await db.exec(readFileSync(join(ROOT, "scripts/fixtures/phase14a_catalog.sql"), "utf8"));
const longName = "N".repeat(80);
await db.exec(`
  insert into auth.users (id, raw_user_meta_data) values
    ('${alice}', '{"username":"alice_qb","first_name":"Alice","last_name":"Secret"}'),
    ('${bob}',   '{"username":"bob_lb","first_name":"Bob","last_name":"Hidden"}'),
    ('${carol}', '{"username":"carol_cb","first_name":"${longName}","last_name":"  ${longName}  "}');
  update public.profiles set created_at = now() - interval '90 days';
`);
const legacySeason = uuid();
await db.exec(`
  select * from public.record_verified_ranked_result('${alice}', gen_random_uuid(), null, 1, 'pro', 4, true, false, false, 0, 0, '[]', now() - interval '10 minutes', now(), 'legacy');
  select * from public.record_verified_ranked_result('${alice}', gen_random_uuid(), '${legacySeason}', 1, 'pro', 4, true, false, false, 0, 0, '[]', now() - interval '10 minutes', now(), 'legacy');
`);
const legacyCareer = (await rows(`select career_games_played from public.profiles where id = '${alice}'`))[0].career_games_played;
check("legacy 14A results recorded", legacyCareer === 2);

// ---------------------------------------------------------------- apply current files
const schema = readFileSync(join(ROOT, "supabase/schema.sql"), "utf8");
const catalog = readFileSync(join(ROOT, "supabase/competitive_catalog.sql"), "utf8");
await db.exec(schema);
check("schema applies over Phase 14A", true);
await db.exec(schema); // idempotent re-paste
check("schema re-applies (idempotent)", true);
await db.exec(catalog);
check("catalog applies + checksum self-check", true);
await db.exec(catalog);
check("catalog re-applies (idempotent)", true);

// Migration results.
const archived = await rows(`select count(*)::int n from public.ranked_game_results_unseasoned_archive`);
check("null-season legacy result archived", archived[0].n === 1, JSON.stringify(archived));
check("no null-season results remain", (await rows(`select count(*)::int n from public.ranked_game_results where season_id is null`))[0].n === 0);
const notNull = await rows(`select is_nullable from information_schema.columns where table_name = 'ranked_game_results' and column_name = 'season_id'`);
check("season_id is NOT NULL", notNull[0].is_nullable === "NO");
const legacyRow = await rows(`select status, user_id, difficulty from public.ranked_seasons where season_id = $1`, [legacySeason]);
check("legacy client season became a CLOSED server season", legacyRow[0]?.status === "closed" && legacyRow[0]?.user_id === alice);
check("career stats untouched by migration",
  (await rows(`select career_games_played from public.profiles where id = '${alice}'`))[0].career_games_played === 2);
const carolNames = (await rows(`select first_name, last_name from public.profiles where id = '${carol}'`))[0];
check("migration trims existing oversized names to 50", carolNames.first_name.length === 50 && carolNames.last_name.length === 50, JSON.stringify(carolNames));
const cfgRow = (await rows(`select * from public.ranked_scoring_config`))[0];
check("no-hints / no-wrong bonuses are 0", cfgRow.no_hints_points === 0 && cfgRow.no_wrong_placements_points === 0);
check("min ranked protocol configured", cfgRow.min_ranked_protocol === 2 && cfgRow.assignment_prefetch_games === 3);
await expectError("self-reported bonus cannot be re-enabled", `update public.ranked_scoring_config set no_hints_points = 3`, "ranked_scoring_config_no_self_reported_bonus");

// Catalog.
const meta = await rows(`select distribution, public.competitive_catalog_checksum(distribution) as actual, expected_checksum from public.competitive_catalog_meta`);
check("meta keyed by distribution", meta.length === 1 && meta[0].distribution === "client_bundled", JSON.stringify(meta));
check("checksum matches export", meta[0].actual === meta[0].expected_checksum, JSON.stringify(meta[0]));
const counts = await rows(`
  select count(*)::int as n,
         count(*) filter (where difficulty_score between 1 and 100)::int as scored,
         count(*) filter (where competitive_eligible and active)::int as eligible,
         count(*) filter (where solutions ?& array['rookie','pro_early','pro','all_pro','hall_of_famer'])::int as variants
  from public.competitive_cases`);
check("150 catalog rows", counts[0].n === 150, JSON.stringify(counts[0]));
check("every row has a 1-100 score", counts[0].scored === 150);
check("150 eligible", counts[0].eligible === 150);
check("every row has all five solution variants", counts[0].variants === 150);
const trimmed = await rows(`select count(*)::int n from public.competitive_cases where jsonb_array_length(solutions->'rookie') < jsonb_array_length(solutions->'all_pro')`);
check("45 cases trim one player in the rookie variant", trimmed[0].n === 45, JSON.stringify(trimmed));
const dist = await rows(`select difficulty, min(difficulty_score) lo, max(difficulty_score) hi, count(*)::int n from public.competitive_cases group by 1 order by 2`);
console.log("score distribution:", dist.map((d) => `${d.difficulty} ${d.n} [${d.lo}-${d.hi}]`).join(", "));

await db.exec(`begin; update public.competitive_cases set solutions = jsonb_set(solutions, '{pro,0,profile}', '"overrated"') where case_id = 'case_rookie_060';`);
check("tampered solution changes checksum", (await rows(`select public.competitive_catalog_checksum() as c`))[0].c !== meta[0].expected_checksum);
await db.exec(`rollback;`);

// server_assigned rows: excluded from the client checksum, never retired by a catalog refresh.
await db.exec(`
  insert into public.competitive_cases (case_id, case_version, difficulty, difficulty_score, band, missing_count, distribution, fingerprint, solutions)
  values ('versus_case_001', 1, 'pro', 40, 1, 4, 'server_assigned', 'ffff000011112222',
          '{"rookie":[],"pro_early":[],"pro":[],"all_pro":[],"hall_of_famer":[]}');
`);
check("checksum ignores server_assigned rows", (await rows(`select public.competitive_catalog_checksum() c`))[0].c === meta[0].expected_checksum);
await db.exec(catalog);
const versus = await rows(`select active from public.competitive_cases where case_id = 'versus_case_001'`);
check("catalog refresh does not retire server_assigned rows", versus[0].active === true);
check("server_assigned checksum is separate", (await rows(`select public.competitive_catalog_checksum('server_assigned') c`))[0].c !== meta[0].expected_checksum);

// Version history trigger.
await expectError("fingerprint change without version bump fails",
  `update public.competitive_cases set fingerprint = 'deadbeefdeadbeef' where case_id = 'case_rookie_060'`, "CASE_FINGERPRINT_CHANGED_WITHOUT_VERSION_BUMP");
await expectError("version regression fails",
  `begin; update public.competitive_cases set case_version = 2, fingerprint = 'aaaa' where case_id = 'case_rookie_060';
   update public.competitive_cases set case_version = 1 where case_id = 'case_rookie_060'; commit;`, "CASE_VERSION_REGRESSION");
await db.exec(`rollback;`);
await expectError("re-using a historical version with new content fails",
  `begin; update public.competitive_cases set case_version = 2, fingerprint = 'aaaa' where case_id = 'case_rookie_060';
   update public.competitive_cases set case_version = 3, fingerprint = 'bbbb' where case_id = 'case_rookie_060';
   insert into public.competitive_cases (case_id, case_version, difficulty, difficulty_score, band, missing_count, fingerprint, solutions)
   values ('case_rookie_060', 2, 'rookie', 20, 1, 4, 'cccc', '{"rookie":[],"pro_early":[],"pro":[],"all_pro":[],"hall_of_famer":[]}')
   on conflict (case_id) do update set case_version = excluded.case_version, fingerprint = excluded.fingerprint; commit;`, "CASE_VERSION_REGRESSION");
await db.exec(`rollback;`);
await db.exec(`begin; update public.competitive_cases set case_version = case_version + 1, fingerprint = 'bumped0000000000' where case_id = 'case_rookie_060'; rollback;`);
check("fingerprint change WITH a version bump is accepted", true);

// ---------------------------------------------------------------- hardening
const loose = await rows(`
  select p.proname, p.proconfig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and (p.prosecdef or p.prorettype = 'trigger'::regtype)
    and not coalesce(p.proconfig @> array['search_path=""'], false)`);
check("every SECURITY DEFINER / trigger fn has search_path ''", loose.length === 0, JSON.stringify(loose));
const definerCount = (await rows(`select count(*)::int n from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.prosecdef`))[0].n;
check("definer functions present", definerCount >= 10, String(definerCount));

await db.exec(`insert into auth.users (id, raw_user_meta_data) values ('44444444-4444-4444-4444-444444444444', '{"username":"dave_te","first_name":"${"D".repeat(300)}","last_name":"  Lee  "}')`);
const dave = (await rows(`select first_name, last_name, football_display_name from public.profiles where username = 'dave_te'`))[0];
check("signup trims oversized names to 50", dave.first_name.length === 50 && dave.last_name === "Lee", JSON.stringify(dave));

async function asUser(id, sql, params = []) {
  await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub', '${id}', false);`);
  try {
    return await rows(sql, params);
  } finally {
    await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`);
  }
}
async function asRoleExpectError(name, role, id, sql, fragment) {
  await db.exec(`set role ${role}; select set_config('request.jwt.claim.sub', '${id ?? ""}', false);`);
  try {
    await db.exec(sql);
    failures.push(`${name}: expected error containing "${fragment}"`);
  } catch (error) {
    check(name, String(error.message).includes(fragment), `got: ${error.message}`);
  } finally {
    await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`);
  }
}
const asUserExpectError = (name, id, sql, fragment) => asRoleExpectError(name, "authenticated", id, sql, fragment);

await asUserExpectError("oversized client name update fails safely", alice,
  `update public.profiles set first_name = '${"X".repeat(51)}' where id = '${alice}'`, "profiles_first_name_length");
check("name unchanged after rejected update", (await rows(`select first_name from public.profiles where id = '${alice}'`))[0].first_name === "Alice");

await db.exec(`set role anon;`);
const avail = async (v) => (await rows(`select public.is_username_available($1) a`, [v]))[0].a;
check("username oracle: taken -> false", (await avail("ALICE_QB")) === false);
check("username oracle: free -> true", (await avail("free_name")) === true);
check("username oracle: bad format -> false", (await avail("bad name!")) === false);
check("username oracle: >64 chars -> false", (await avail("a".repeat(5000))) === false);
check("username oracle: null -> false", (await avail(null)) === false);
await db.exec(`reset role;`);

// ---------------------------------------------------------------- security
await asUserExpectError("client cannot read competitive_cases", alice, `select * from public.competitive_cases`, "permission denied");
await asUserExpectError("client cannot read catalog meta", alice, `select * from public.competitive_catalog_meta`, "permission denied");
await asUserExpectError("client cannot read version history", alice, `select * from public.competitive_case_version_history`, "permission denied");
await asUserExpectError("client cannot run checksum fn", alice, `select public.competitive_catalog_checksum()`, "permission denied");
await asUserExpectError("client cannot read scoring config", alice, `select * from public.ranked_scoring_config`, "permission denied");
await asUserExpectError("client cannot read attempts", alice, `select * from public.ranked_submission_attempts`, "permission denied");
await asUserExpectError("client cannot read seasons", alice, `select * from public.ranked_seasons`, "permission denied");
await asUserExpectError("client cannot insert season", alice, `insert into public.ranked_seasons (user_id, difficulty, schedule_seed) values ('${alice}', 'hall_of_famer', 'x')`, "permission denied");
await asUserExpectError("client cannot read assignments", alice, `select * from public.ranked_match_assignments`, "permission denied");
await asUserExpectError("client cannot insert assignment", alice,
  `insert into public.ranked_match_assignments (match_id, user_id, season_id, game_number, difficulty, solution_variant, case_ids, case_versions, expected_solutions, catalog_fingerprint, expires_at)
   values (gen_random_uuid(), '${alice}', gen_random_uuid(), 1, 'rookie', 'rookie', '{a,b,c,d,e}', '{1,1,1,1,1}', '[[],[],[],[],[]]', 'x', now() + interval '1 day')`, "permission denied");
await asUserExpectError("client cannot update assignment", alice, `update public.ranked_match_assignments set consumed_at = null`, "permission denied");
await asUserExpectError("client cannot read rate limits", alice, `select * from public.ranked_rate_limits`, "permission denied");
await asUserExpectError("client cannot read archive", alice, `select * from public.ranked_game_results_unseasoned_archive`, "permission denied");
await asUserExpectError("client cannot issue assignment", alice, `select * from public.issue_ranked_match_assignment('${alice}', null, 1, 'hall_of_famer')`, "permission denied");
await asUserExpectError("client cannot consume rate limit", alice, `select public.consume_ranked_rate_limit('${alice}', 'submit')`, "permission denied");
await asUserExpectError("client cannot insert ranked result", alice,
  `insert into public.ranked_game_results (match_id, user_id, season_id, game_number, difficulty, regulation_quarters_solved, regulation_quarters_lost, game_won, overtime_played, overtime_won, wrong_placements, hints_used, base_score, difficulty_multiplier, final_score)
   values (gen_random_uuid(), '${alice}', gen_random_uuid(), 1, 'pro', 4, 0, true, false, false, 0, 0, 41, 1.25, 999)`, "permission denied");
await asUserExpectError("client cannot call record fn", alice,
  `select * from public.record_verified_ranked_result('${alice}', gen_random_uuid(), gen_random_uuid(), 1, 'pro', '[]', now() - interval '10 minutes', now(), 'x', 2)`, "permission denied");
await asUserExpectError("client cannot call internal board fn", alice, `select * from public.ranked_leaderboard_rows('weekly', 'all')`, "permission denied");
await asUserExpectError("client cannot set global_rating", alice, `update public.profiles set global_rating = 9999 where id = '${alice}'`, "permission denied");
await asRoleExpectError("anon cannot read leaderboard", "anon", null, `select * from public.ranked_leaderboard('weekly')`, "permission denied");
await asRoleExpectError("anon cannot issue assignment", "anon", null, `select * from public.issue_ranked_match_assignment('${alice}', null, 1, 'rookie')`, "permission denied");

// ---------------------------------------------------------------- assignments
await db.exec(`set role service_role;`);
async function issue(user, season, game, difficulty) {
  return (await rows(`select * from public.issue_ranked_match_assignment($1, $2, $3, $4)`, [user, season, game, difficulty]))[0];
}
async function expectedFor(matchID) {
  return (await rows(`select expected_solutions, solution_variant from public.ranked_match_assignments where match_id = $1`, [matchID]))[0];
}
function results(asg, exp, outcomes, mutate) {
  const out = outcomes.map((o, i) => ({
    case_id: asg.case_ids[i],
    case_version: asg.case_versions[i],
    quarter_index: i,
    outcome: o,
    hints_used: 0,
    wrong_placements: 0,
    placements: o === "solved" ? exp[i] : exp[i].slice(0, exp[i].length - 1),
  }));
  if (mutate) mutate(out);
  return out;
}
async function submit(asg, caseResults, opts = {}) {
  const {
    user = asg.__user, season = asg.season_id, game = asg.game_number, difficulty = asg.difficulty,
    match = asg.match_id, started = ago(MIN), completed = ago(30 * SEC), version = "ios-test 1.0", protocol = 2,
  } = opts;
  return (await rows(
    `select * from public.record_verified_ranked_result($1, $2, $3, $4, $5, $6::jsonb, $7::timestamptz, $8::timestamptz, $9, $10)`,
    [user, match, season, game, difficulty, JSON.stringify(caseResults), started, completed, version, protocol],
  ))[0];
}
async function submitErr(name, asg, caseResults, opts, fragment) {
  try {
    await submit(asg, caseResults, opts);
    failures.push(`${name}: expected error containing "${fragment}"`);
  } catch (error) {
    check(name, String(error.message).includes(fragment), `got: ${error.message}`);
  }
}
async function issueErr(name, args, fragment) {
  try {
    await issue(...args);
    failures.push(`${name}: expected error containing "${fragment}"`);
  } catch (error) {
    check(name, String(error.message).includes(fragment), `got: ${error.message}`);
  }
}
async function play(user, season, game, difficulty, outcomes, opts = {}) {
  const asg = await issue(user, season, game, difficulty);
  asg.__user = user;
  const exp = (await expectedFor(asg.match_id)).expected_solutions;
  const r = await submit(asg, results(asg, exp, outcomes), opts);
  return { asg, exp, r };
}
const PERFECT = ["solved", "solved", "solved", "solved"];

// Season creation rules.
await issueErr("season id required after game 1", [alice, null, 2, "hall_of_famer"], "SEASON_REQUIRED");
await issueErr("arbitrary season id rejected", [alice, uuid(), 1, "hall_of_famer"], "SEASON_NOT_FOUND");
await issueErr("legacy (closed) season gets no assignments", [alice, legacySeason, 2, "pro"], "SEASON_CLOSED");

// Full Hall of Famer season for alice: 12 games, all perfect.
const careerBefore = (await rows(`select career_games_played from public.profiles where id = '${alice}'`))[0].career_games_played;
const hof = await issue(alice, null, 1, "hall_of_famer");
hof.__user = alice;
const hofSeason = hof.season_id;
check("assignment returns no solutions/variant", !Object.keys(hof).some((k) => /solution|variant|seed/.test(k)), Object.keys(hof).join(","));
check("assignment pins 5 cases + versions", hof.case_ids.length === 5 && hof.case_versions.length === 5);
const hofAgain = await issue(alice, hofSeason, 1, "hall_of_famer");
check("re-issuing a live assignment is idempotent", hofAgain.reused === true && hofAgain.match_id === hof.match_id);
await issueErr("foreign season rejected", [bob, hofSeason, 1, "hall_of_famer"], "SEASON_CONFLICT");
await issueErr("season difficulty locked", [alice, hofSeason, 2, "rookie"], "SEASON_DIFFICULTY_MISMATCH");
await issueErr("prefetch window bounded", [alice, hofSeason, 4, "hall_of_famer"], "GAME_OUT_OF_WINDOW");
const hofIssued = [hof];
const hofExp = (await expectedFor(hof.match_id)).expected_solutions;
const r1 = await submit(hof, results(hof, hofExp, PERFECT));
check("HOF perfect = (40+10+5)*2 = 110 (no hint/wrong bonus)", r1.final_score === 110, JSON.stringify(r1));
check("recent game uses completed_at", r1.leaderboard_at_source === "completed_at");
const r1b = await submit(hof, results(hof, hofExp, PERFECT));
check("duplicate match is idempotent", r1b.duplicate === true && r1b.final_score === 110 && r1b.result_id === r1.result_id);
await submitErr("other user cannot reuse a recorded match id", hof, results(hof, hofExp, PERFECT), { user: bob }, "MATCH_ID_CONFLICT");
await issueErr("recorded game cannot be re-issued", [alice, hofSeason, 1, "hall_of_famer"], "GAME_ALREADY_RECORDED");
for (let g = 2; g <= 12; g += 1) {
  const { asg, r } = await play(alice, hofSeason, g, "hall_of_famer", PERFECT);
  hofIssued.push(asg);
  if (r.final_score !== 110) failures.push(`HoF game ${g} scored ${r.final_score}`);
}
check("12-game HoF season recorded", (await rows(`select count(*)::int n from public.ranked_game_results where season_id = $1`, [hofSeason]))[0].n === 12);
const careerAfter = (await rows(`select career_games_played, career_wins, championships from public.profiles where id = '${alice}'`))[0];
check("career stats updated after each insert", careerAfter.career_games_played === careerBefore + 12, JSON.stringify(careerAfter));
check("championships untouched", careerAfter.championships === 0);
for (let band = 0; band < 5; band += 1) {
  const ids = new Set(hofIssued.map((a) => a.case_ids[band]));
  if (ids.size !== 12) failures.push(`HoF band ${band + 1} repeats a case: ${ids.size}`);
}
check("no case repeats within a band across the season", true);

// Easier cases cannot earn the HoF multiplier.
const tierOf = new Map((await rows(`select case_id, difficulty, difficulty_score from public.competitive_cases`)).map((r) => [r.case_id, r]));
const hofTiers = hofIssued.flatMap((a) => a.case_ids.map((id) => tierOf.get(id).difficulty));
check("HoF season is never assigned rookie-tier cases", !hofTiers.includes("rookie"), JSON.stringify(hofTiers));
const meanScore = (list) => list.flatMap((a) => a.case_ids.map((id) => tierOf.get(id).difficulty_score)).reduce((s, x, _, arr) => s + x / arr.length, 0);

// Rookie season for alice (closes the HoF season).
const rk = await issue(alice, null, 1, "rookie");
rk.__user = alice;
const rkSeason = rk.season_id;
check("new season closes the previous active season",
  (await rows(`select status from public.ranked_seasons where season_id = $1`, [hofSeason]))[0].status === "closed");
await issueErr("closed season gets no new assignments", [alice, hofSeason, 1, "hall_of_famer"], "SEASON_CLOSED");
// Pin a case the rookie adapter trims into slot 0 so the exact-subset test is deterministic
// (game 1 draws from the easiest window, which rarely contains a trimmed case).
const trimCase = (await rows(`select case_id, case_version as version, solutions from public.competitive_cases
  where distribution = 'client_bundled' and active and jsonb_array_length(solutions->'rookie') < jsonb_array_length(solutions->'all_pro')
  order by case_id collate "C" limit 1`))[0];
check("catalog contains rookie-trimmed cases", !!trimCase);
await db.exec(`reset role; update public.ranked_match_assignments
  set case_ids[1] = '${trimCase.case_id}', case_versions[1] = ${trimCase.version},
      expected_solutions = jsonb_set(expected_solutions, '{0}', '${JSON.stringify(trimCase.solutions.rookie).replace(/'/g, "''")}'::jsonb)
  where match_id = '${rk.match_id}'; set role service_role;`);
rk.case_ids[0] = trimCase.case_id;
rk.case_versions[0] = trimCase.version;
const rkExpRow = await expectedFor(rk.match_id);
check("rookie game uses the rookie variant", rkExpRow.solution_variant === "rookie");
const rkExp = rkExpRow.expected_solutions;
check("rookie and HoF game-1 cases differ", rk.case_ids.join() !== hof.case_ids.join());
check("HoF schedule is harder than rookie (mean score)", meanScore([hof]) > meanScore([rk]), `${meanScore([hof])} vs ${meanScore([rk])}`);

// Exact adapted solution: an arbitrary trimmed subset fails.
let trimmedChecked = false;
for (let i = 0; i < 4 && !trimmedChecked; i += 1) {
  const full = (await rows(`select solutions->'all_pro' s from public.competitive_cases where case_id = $1`, [rk.case_ids[i]]))[0].s;
  if (full.length > rkExp[i].length) {
    const kept = new Set(rkExp[i].map((p) => p.player_key));
    const dropped = full.find((p) => !kept.has(p.player_key));
    for (const profile of ["rookie", "veteran"]) {
      await submitErr(`rookie: other trimmed subset (${profile}) fails`, rk,
        results(rk, rkExp, PERFECT, (o) => { o[i].placements = [...rkExp[i].slice(1), { ...dropped, profile }]; }), {}, "PLACEMENT_MISMATCH");
    }
    trimmedChecked = true;
  }
}
check("found a trimmed rookie case to test", trimmedChecked);
await submitErr("rookie: solved needs every expected placement", rk,
  results(rk, rkExp, PERFECT, (o) => { o[0].placements = rkExp[0].slice(1); }), {}, "SOLVED_CASE_INCOMPLETE");
await submitErr("game_version must be non-empty", rk, results(rk, rkExp, PERFECT), { version: "   " }, "INVALID_GAME_VERSION");
await submitErr("game_version is bounded", rk, results(rk, rkExp, PERFECT), { version: "v".repeat(41) }, "INVALID_GAME_VERSION");
await submitErr("outdated ranked protocol rejected", rk, results(rk, rkExp, PERFECT), { protocol: 1 }, "CLIENT_OUTDATED");
await submitErr("arbitrary match id rejected", rk, results(rk, rkExp, PERFECT), { match: uuid() }, "ASSIGNMENT_NOT_FOUND");
await submitErr("owner must match the JWT user", rk, results(rk, rkExp, PERFECT), { user: bob }, "ASSIGNMENT_OWNER_MISMATCH");
await submitErr("season must equal the assignment", rk, results(rk, rkExp, PERFECT), { season: hofSeason }, "ASSIGNMENT_MISMATCH");
await submitErr("arbitrary season id rejected at submit", rk, results(rk, rkExp, PERFECT), { season: uuid() }, "ASSIGNMENT_MISMATCH");
await submitErr("game number must equal the assignment", rk, results(rk, rkExp, PERFECT), { game: 2 }, "ASSIGNMENT_MISMATCH");
await submitErr("difficulty must equal the assignment (no HoF x2 on rookie cases)", rk, results(rk, rkExp, PERFECT), { difficulty: "hall_of_famer" }, "ASSIGNMENT_MISMATCH");
await submitErr("case ids must equal the assignment", rk,
  results(rk, rkExp, PERFECT, (o) => { o[1].case_id = hof.case_ids[1]; }), {}, "CASE_MISMATCH");
await submitErr("case order must equal the assignment", rk,
  results(rk, rkExp, PERFECT, (o) => { [o[0], o[1]] = [o[1], o[0]]; o[0].quarter_index = 0; o[1].quarter_index = 1; }), {}, "CASE_MISMATCH");
await submitErr("case versions must equal the assignment", rk,
  results(rk, rkExp, PERFECT, (o) => { o[2].case_version += 1; }), {}, "CASE_VERSION_MISMATCH");
await submitErr("placement must be in the exact solution", rk,
  results(rk, rkExp, PERFECT, (o) => { o[0].placements = [{ ...rkExp[0][0], profile: rkExp[0][0].profile === "rookie" ? "veteran" : "rookie" }, ...rkExp[0].slice(1)]; }), {}, "PLACEMENT_MISMATCH");
await submitErr("duplicate placements rejected", rk,
  results(rk, rkExp, PERFECT, (o) => { o[0].placements = [rkExp[0][0], ...rkExp[0].slice(0, rkExp[0].length - 1)]; }), {}, "PLACEMENT_MISMATCH");
await submitErr("failed case cannot be complete", rk,
  results(rk, rkExp, ["solved", "solved", "solved", "failed"], (o) => { o[3].placements = rkExp[3]; }), {}, "FAILED_CASE_COMPLETE");
await submitErr("2-2 regulation requires overtime", rk, results(rk, rkExp, ["solved", "solved", "failed", "failed"]), {}, "OVERTIME_MISMATCH");
await submitErr("overtime only after 2-2", rk, results(rk, rkExp, [...PERFECT, "solved"]), {}, "OVERTIME_MISMATCH");
await submitErr("hints must be integers", rk, results(rk, rkExp, PERFECT, (o) => { o[0].hints_used = "0"; }), {}, "INVALID_CASE_RESULTS");
const rkRes = await submit(rk, results(rk, rkExp, ["solved", "solved", "failed", "failed", "solved"], (o) => { o[2].hints_used = 3; o[1].wrong_placements = 2; }));
check("Rookie 2/4 + OT win = 20+10+5 = 35", rkRes.final_score === 35, JSON.stringify(rkRes));
const rkRow = (await rows(`select hints_used, wrong_placements, overtime_played, overtime_won, game_won from public.ranked_game_results where match_id = $1`, [rk.match_id]))[0];
check("self-reported stats stored but unscored", rkRow.hints_used === 3 && rkRow.wrong_placements === 2 && rkRow.game_won && rkRow.overtime_won, JSON.stringify(rkRow));
const zeroHints = await play(alice, rkSeason, 2, "rookie", ["solved", "solved", "failed", "failed", "solved"]);
check("hint-free game scores the same as a hinted one", zeroHints.r.final_score === 35);

// Timestamp trust: an untrusted earlier game does not poison later games.
const g3 = await play(alice, rkSeason, 3, "rookie", PERFECT, { started: ago(HOUR), completed: iso(Date.now() + 2 * HOUR) });
check("future completion falls back to receipt", g3.r.leaderboard_at_source === "received_at");
const g4asg = await issue(alice, rkSeason, 4, "rookie");
g4asg.__user = alice;
const g4exp = (await expectedFor(g4asg.match_id)).expected_solutions;
const g4 = await submit(g4asg, results(g4asg, g4exp, PERFECT));
check("untrusted earlier game does not poison a later trusted game", g4.leaderboard_at_source === "completed_at", JSON.stringify(g4));
const g5 = await play(alice, rkSeason, 5, "rookie", PERFECT, { started: ago(2 * DAY), completed: ago(2 * DAY - HOUR) });
check("game started before its assignment was issued falls back", g5.r.leaderboard_at_source === "received_at");
const g6asg = await issue(alice, rkSeason, 6, "rookie");
g6asg.__user = alice;
await db.exec(`reset role; update public.ranked_match_assignments set issued_at = now() - interval '10 days' where match_id = '${g6asg.match_id}'; set role service_role;`);
const g6exp = (await expectedFor(g6asg.match_id)).expected_solutions;
const g6 = await submit(g6asg, results(g6asg, g6exp, PERFECT), { started: ago(6 * DAY + HOUR), completed: ago(6 * DAY) });
check("trusted game completing before an earlier TRUSTED game falls back", g6.leaderboard_at_source === "received_at", JSON.stringify(g6));
const g7asg = await issue(alice, rkSeason, 7, "rookie");
g7asg.__user = alice;
await db.exec(`reset role; update public.ranked_match_assignments set issued_at = now() - interval '45 days', expires_at = now() - interval '31 days' where match_id = '${g7asg.match_id}'; set role service_role;`);
const g7exp = (await expectedFor(g7asg.match_id)).expected_solutions;
await submitErr("assignment past expiry + grace rejected", g7asg, results(g7asg, g7exp, PERFECT), {}, "ASSIGNMENT_EXPIRED");
const g7new = await issue(alice, rkSeason, 7, "rookie");
check("expired assignment is replaced on re-issue", g7new.reused === false && g7new.match_id !== g7asg.match_id);
await submitErr("replaced assignment rejected", g7asg, results(g7asg, g7exp, PERFECT), {}, "ASSIGNMENT_REPLACED");

// Offline window: an older-but-valid assignment keeps its completion time.
const bobPro = await issue(bob, null, 1, "pro");
bobPro.__user = bob;
await db.exec(`reset role; update public.ranked_match_assignments set issued_at = now() - interval '7 days' where match_id = '${bobPro.match_id}'; set role service_role;`);
const bobProExp = (await expectedFor(bobPro.match_id)).expected_solutions;
check("pro game 1 uses pro_early variant", (await expectedFor(bobPro.match_id)).solution_variant === "pro_early");
const bp1 = await submit(bobPro, results(bobPro, bobProExp, ["solved", "failed", "failed", "failed"]), { started: ago(6 * DAY + HOUR), completed: ago(6 * DAY) });
check("Pro 1/4 loss = 10*1.25 = 13", bp1.final_score === 13, JSON.stringify(bp1));
check("6-day-old offline game keeps validated completion time", bp1.leaderboard_at_source === "completed_at");
await play(bob, bobPro.season_id, 2, "pro", ["solved", "failed", "failed", "failed"]);
await play(bob, bobPro.season_id, 3, "pro", ["solved", "failed", "failed", "failed"]);
const bp4 = await issue(bob, bobPro.season_id, 4, "pro");
bp4.__user = bob;
const bp4row = await expectedFor(bp4.match_id);
check("pro game 4 uses the untrimmed pro variant", bp4row.solution_variant === "pro");
await submitErr("pro game 4: an arbitrary length-1 subset fails", bp4,
  results(bp4, bp4row.expected_solutions, PERFECT, (o) => { o[0].placements = bp4row.expected_solutions[0].slice(0, -1); }), {}, "SOLVED_CASE_INCOMPLETE");

// Concurrent retries of one match: exactly one insert.
const bp4res = results(bp4, bp4row.expected_solutions, PERFECT);
const [c1, c2] = await Promise.all([submit(bp4, bp4res), submit(bp4, bp4res)]);
check("concurrent retry is idempotent", [c1.duplicate, c2.duplicate].sort().join() === "false,true" && c1.result_id === c2.result_id);

// A consumed assignment can never score twice.
const bobCareer = (await rows(`select career_games_played from public.profiles where id = '${bob}'`))[0].career_games_played;
await submit(bp4, bp4res);
check("resubmitting a consumed match changes nothing",
  (await rows(`select career_games_played from public.profiles where id = '${bob}'`))[0].career_games_played === bobCareer);
await db.exec(`reset role; delete from public.ranked_game_results where match_id = '${bp4.match_id}'; set role service_role;`);
await submitErr("consumed assignment cannot score again even if its result vanished", bp4, bp4res, {}, "ASSIGNMENT_CONSUMED");

// Atomic rate limit.
const limits = await Promise.all(Array.from({ length: 40 }, () => rows(`select public.consume_ranked_rate_limit($1, 'submit') ok`, [carol])));
check("rate limit admits exactly submissions_per_hour", limits.filter((r) => r[0].ok).length === 30, String(limits.filter((r) => r[0].ok).length));
const assignOk = (await rows(`select public.consume_ranked_rate_limit($1, 'assign') ok`, [carol]))[0].ok;
check("rate limit buckets are independent", assignOk === true);
await expectError("unknown rate-limit bucket rejected", `select public.consume_ranked_rate_limit('${carol}', 'other')`, "INVALID_RATE_LIMIT_BUCKET");

// ---------------------------------------------------------------- reads
await db.exec(`reset role;`);
const weekly = await asUser(alice, `select * from public.ranked_leaderboard('weekly')`);
const weeklyCols = Object.keys(weekly[0] ?? {});
check("weekly board returns rows", weekly.length >= 2, JSON.stringify(weekly.length));
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
