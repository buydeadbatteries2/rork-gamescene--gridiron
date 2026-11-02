// Phase 15A — LOCAL dry run of the asynchronous 1-v-1 Versus backend.
//
// Applies supabase/schema.sql + competitive_catalog.sql inside an in-memory
// PGlite (real Postgres in WASM) with the same minimal Supabase shim as
// verify-supabase-sql.mjs, then exercises matchmaking, the case snapshot,
// exact-solution verification, server scoring, tiebreaks, lazy expiry /
// forfeit, career stats, privacy and the "no purchased advantage" rule.
// Nothing touches a real Supabase project.
//
//   mkdir -p /tmp/pgcheck && cd /tmp/pgcheck && bun add @electric-sql/pglite
//   PGLITE=/tmp/pgcheck/node_modules/@electric-sql/pglite/dist/index.js \
//     bun scripts/verify-versus-sql.mjs
//
// PGlite is single-connection: "simultaneous" calls are issued with
// Promise.all and serialized by the engine. They prove each call is atomic
// and idempotent; true multi-backend races rely on the advisory locks, the
// FOR UPDATE row locks and the unique constraints exercised here.
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
async function rows(sql, params = []) {
  return (await db.query(sql, params)).rows;
}
async function expectError(name, fn, fragment) {
  try {
    await fn();
    failures.push(`${name}: expected error containing "${fragment}"`);
  } catch (error) {
    check(name, String(error.message).includes(fragment), `got: ${error.message}`);
  }
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
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
  alter default privileges in schema public grant execute on functions to anon, authenticated, service_role;
`);

const schema = readFileSync(join(ROOT, "supabase/schema.sql"), "utf8");
const catalog = readFileSync(join(ROOT, "supabase/competitive_catalog.sql"), "utf8");
await db.exec(schema);
await db.exec(schema);
await db.exec(catalog);
check("schema + catalog apply twice (idempotent)", true);

const U = (n) => `0000000${n}-0000-0000-0000-000000000000`.slice(-36).replace(/^.{8}/, `${String(n).padStart(8, "0")}`);
const users = {};
const names = ["ava", "ben", "cam", "dee", "eli", "fay", "gus", "hal", "ivy", "jon", "kit", "lou", "max", "ned", "oli", "pia",
  "rae", "sam", "tom", "uma", "vic", "wes", "xan", "yul"];
let values = [];
names.forEach((n, i) => {
  users[n] = U(i + 1);
  values.push(`('${users[n]}', '{"username":"${n}_qb","first_name":"Real${n}","last_name":"Secret${n}"}')`);
});
await db.exec(`insert into auth.users (id, raw_user_meta_data) values ${values.join(",")};`);
const ghost = "99999999-9999-9999-9999-999999999999"; // no profile

// ---------------------------------------------------------------- helpers (service role = Edge Function)
async function asService(fn) {
  await db.exec(`set role service_role;`);
  try {
    return await fn();
  } finally {
    await db.exec(`reset role;`);
  }
}
async function asUser(id, sql, params = []) {
  await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub', '${id ?? ""}', false);`);
  try {
    return await rows(sql, params);
  } finally {
    await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`);
  }
}
async function asRoleError(name, role, id, sql, fragment) {
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
const find = (user, difficulty) =>
  asService(async () => (await rows(`select * from public.versus_find_match($1, $2)`, [user, difficulty]))[0]);
async function snapshot(matchID) {
  return (await rows(`select expected_solutions from public.versus_match_solutions where match_id = $1`, [matchID]))[0]
    .expected_solutions;
}
async function matchRow(matchID) {
  return (await rows(`select * from public.versus_matches where match_id = $1`, [matchID]))[0];
}
function caseResults(match, exp, outcomes, mutate) {
  const out = outcomes.map((o, i) => ({
    case_id: match.case_ids[i],
    case_version: match.case_versions[i],
    quarter_index: i,
    outcome: o,
    hints_used: 0,
    wrong_placements: 0,
    placements: o === "solved" ? exp[i] : exp[i].slice(0, exp[i].length - 1),
  }));
  if (mutate) mutate(out);
  return out;
}
async function submitRaw(user, matchID, results, opts = {}) {
  const { version = "ios-test 1.0", protocol = 1 } = opts;
  return asService(async () => (await rows(
    `select * from public.versus_record_result($1, $2, $3::jsonb, now() - interval '5 minutes', now(), $4, $5)`,
    [user, matchID, JSON.stringify(results), version, protocol],
  ))[0]);
}
async function play(user, match, outcomes, opts = {}) {
  const exp = await snapshot(match.match_id);
  return submitRaw(user, match.match_id, caseResults(match, exp, outcomes, opts.mutate), opts);
}
async function stats(user) {
  return (await rows(`select * from public.versus_career_stats where user_id = $1`, [user]))[0] ?? null;
}
async function pair(a, b, difficulty) {
  const wa = await find(a, difficulty);
  const mb = await find(b, difficulty);
  check(`pair ${difficulty}: second player claims the first player's match`,
    wa.status === "waiting_for_opponent" && mb.match_id === wa.match_id && mb.status === "active");
  return { wa, mb, match: await matchRow(mb.match_id) };
}
const W4 = ["solved", "solved", "solved", "solved"];
const W3 = ["solved", "solved", "solved", "failed"];
const L1 = ["solved", "failed", "failed", "failed"];
const L0 = ["failed", "failed", "failed", "failed"];
const OTW = ["solved", "solved", "failed", "failed", "solved"];
const OTL = ["solved", "solved", "failed", "failed", "failed"];

// ---------------------------------------------------------------- config / no purchased advantage
const cfg = (await rows(`select * from public.versus_config`))[0];
check("versus scoring mirrors ranked values", cfg.quarter_solved_points === 10 && cfg.game_win_points === 10
  && cfg.overtime_win_points === 5 && cfg.perfect_regulation_points === 5, JSON.stringify(cfg));
check("versus expiry default 24h", cfg.match_ttl_hours === 24);
check("purchasable hints disabled", cfg.purchasable_hints_allowed === false);
await expectError("purchasable hints cannot be enabled",
  () => db.exec(`update public.versus_config set purchasable_hints_allowed = true`), "versus_config_no_purchased_advantage");
const rankedCfgBefore = JSON.stringify((await rows(`select * from public.ranked_scoring_config`))[0]);

// ---------------------------------------------------------------- privileges / auth
for (const t of ["versus_config", "versus_matches", "versus_match_solutions", "versus_match_results", "versus_career_stats", "versus_rate_limits"]) {
  await asRoleError(`authenticated cannot read ${t}`, "authenticated", users.ava, `select * from public.${t}`, "permission denied");
  await asRoleError(`anon cannot read ${t}`, "anon", null, `select * from public.${t}`, "permission denied");
}
await asRoleError("client cannot insert a match", "authenticated", users.ava,
  `insert into public.versus_matches (player_a_id, difficulty, solution_variant, content_source, case_ids, case_versions, catalog_fingerprint, expires_at)
   values ('${users.ava}', 'pro', 'pro', 'bundled_dev_fallback', '{a,b,c,d,e}', '{1,1,1,1,1}', 'x', now() + interval '1 day')`, "permission denied");
for (const fn of [
  `public.versus_find_match('${users.ava}', 'pro')`,
  `public.versus_record_result('${users.ava}', gen_random_uuid(), '[]', null, null, 'x', 1)`,
  `public.versus_expire_due(null)`,
  `public.versus_player_rows('${users.ava}')`,
  `public.consume_versus_rate_limit('${users.ava}', 'find')`,
]) {
  await asRoleError(`authenticated cannot call ${fn.split("(")[0]}`, "authenticated", users.ava, `select * from ${fn}`, "permission denied");
  await asRoleError(`anon cannot call ${fn.split("(")[0]}`, "anon", null, `select * from ${fn}`, "permission denied");
}
await asRoleError("anon cannot read my_versus_matches", "anon", null, `select * from public.my_versus_matches()`, "permission denied");
await asRoleError("anon cannot read versus history", "anon", null, `select * from public.my_versus_history(10, 0)`, "permission denied");
await asRoleError("anon cannot read public record", "anon", null, `select * from public.versus_public_record('${users.ava}')`, "permission denied");
await asRoleError("authenticated without uid → AUTH_REQUIRED", "authenticated", null, `select * from public.my_versus_matches()`, "AUTH_REQUIRED");
const definers = await rows(`
  select p.proname, p.proconfig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef and (p.proname like '%versus%')`);
check("every versus SECURITY DEFINER fn pins search_path ''", definers.length >= 10
  && definers.every((d) => (d.proconfig ?? []).some((c) => c === 'search_path=""' || c === "search_path=")), JSON.stringify(definers));

// ---------------------------------------------------------------- argument validation
await expectError("invalid difficulty rejected", () => find(users.ava, "legend"), "INVALID_DIFFICULTY");
await expectError("null difficulty rejected", () => find(users.ava, null), "INVALID_ARGUMENTS");
await expectError("user without profile rejected", () => find(ghost, "pro"), "PROFILE_REQUIRED");

// ---------------------------------------------------------------- basic matchmaking + snapshot
const w1 = await find(users.ava, "pro");
check("first search waits", w1.status === "waiting_for_opponent" && w1.player_state === "waiting_for_opponent" && w1.reused === false, JSON.stringify(w1));
check("waiting match has no opponent", w1.opponent_user_id === null);
check("bundled TEMPORARY fallback recorded", w1.content_source === "bundled_dev_fallback");
check("five cases snapshotted", w1.case_ids.length === 5 && w1.case_versions.length === 5);
check("all five cases distinct", new Set(w1.case_ids).size === 5);
const w1again = await find(users.ava, "pro");
check("double matchmaking returns same match (reused)", w1again.match_id === w1.match_id && w1again.reused === true);
check("still exactly one waiting match", (await rows(`select count(*)::int n from public.versus_matches where player_a_id = $1 and status = 'waiting_for_opponent'`, [users.ava]))[0].n === 1);
const m1 = await find(users.ben, "pro");
check("second player at same difficulty pairs", m1.match_id === w1.match_id && m1.status === "active" && m1.player_state === "active", JSON.stringify(m1));
check("joiner sees opponent username", m1.opponent_user_id === users.ava && m1.opponent_username === "ava_qb");
check("joiner gets the SAME cases", JSON.stringify(m1.case_ids) === JSON.stringify(w1.case_ids)
  && JSON.stringify(m1.case_versions) === JSON.stringify(w1.case_versions));
// football_display_name ("R. Lastname") is the app's existing PUBLIC identity
// (same column leaderboards expose via public_profiles); full first names,
// raw name fields and email never leave the server.
const leaks = (o) => /Realava|Realben|first_name|last_name|email/.test(JSON.stringify(o));
check("no private names/email leak into match rows", !leaks(m1) && m1.opponent_display_name === "R. Secretava", JSON.stringify(m1));
const m1row = await matchRow(m1.match_id);
check("match row: players set, not self", m1row.player_a_id === users.ava && m1row.player_b_id === users.ben);
check("pro variant is full adaptation", m1row.solution_variant === "pro");
const avaView = await asUser(users.ava, `select * from public.my_versus_matches()`);
check("creator sees the active match", avaView.length === 1 && avaView[0].player_state === "active" && avaView[0].opponent_username === "ben_qb");
const snap1 = await snapshot(m1.match_id);
const catalogSols = await rows(`select case_id, solutions->'pro' s from public.competitive_cases where case_id = any($1)`, [m1row.case_ids]);
check("snapshot equals catalog solutions at creation",
  m1row.case_ids.every((id, i) => JSON.stringify(catalogSols.find((c) => c.case_id === id).s) === JSON.stringify(snap1[i])));
const bands = await rows(`select case_id, band from public.competitive_cases where case_id = any($1)`, [m1row.case_ids]);
check("one case per band 1..5 in order", m1row.case_ids.every((id, i) => bands.find((b) => b.case_id === id).band === i + 1));

// catalog edits never touch a live match
const editedCase = m1row.case_ids[0];
await db.exec(`update public.competitive_cases set active = false where case_id = '${editedCase}'`);
check("snapshot survives catalog edit", JSON.stringify(await snapshot(m1.match_id)) === JSON.stringify(snap1));
await db.exec(`update public.competitive_cases set active = true where case_id = '${editedCase}'`);

// ---------------------------------------------------------------- different difficulties never pair
const cw = await find(users.cam, "rookie");
const dw = await find(users.dee, "hall_of_famer");
check("rookie and HoF do not pair", cw.status === "waiting_for_opponent" && dw.status === "waiting_for_opponent" && cw.match_id !== dw.match_id);
const ew = await find(users.eli, "rookie");
check("same-difficulty (rookie) pairs with rookie waiter", ew.match_id === cw.match_id && ew.status === "active");
const hofRow = await matchRow(dw.match_id);
const hofTiers = await rows(`select difficulty from public.competitive_cases where case_id = any($1)`, [hofRow.case_ids]);
check("HoF snapshot excludes rookie-tier cases", hofTiers.every((t) => t.difficulty !== "rookie"));

// switching difficulty cancels an unplayed waiting match (no record impact)
const dw2 = await find(users.dee, "all_pro");
check("switching difficulty opens new waiting match", dw2.match_id !== dw.match_id && dw2.difficulty === "all_pro");
check("old waiting match cancelled", (await matchRow(dw.match_id)).status === "cancelled");
// active match at another difficulty blocks a new search
await expectError("active match at other difficulty blocks search", () => find(users.ben, "rookie"), "VERSUS_MATCH_IN_PROGRESS");

// ---------------------------------------------------------------- self-match impossible
await expectError("DB forbids self match",
  () => db.exec(`update public.versus_matches set player_b_id = player_a_id where match_id = '${dw2.match_id}'`), "versus_matches_");
const deeAgain = await find(users.dee, "all_pro");
check("user never claims own waiting match", deeAgain.match_id === dw2.match_id && deeAgain.reused === true && deeAgain.status === "waiting_for_opponent");

// ---------------------------------------------------------------- simultaneous matching
const [sa, sb] = await Promise.all([find(users.fay, "all_pro"), find(users.gus, "all_pro")]);
const claimedDee = [sa, sb].filter((r) => r.match_id === dw2.match_id);
check("waiting match claimed by exactly one simultaneous searcher", claimedDee.length === 1, JSON.stringify([sa.match_id, sb.match_id, dw2.match_id]));
const other = [sa, sb].find((r) => r.match_id !== dw2.match_id);
check("the other simultaneous searcher waits", other.status === "waiting_for_opponent");
const [x1, x2] = await Promise.all([find(users.hal, "hall_of_famer"), find(users.ivy, "hall_of_famer")]);
check("two simultaneous searchers at an empty queue pair with each other", x1.match_id === x2.match_id
  && [x1.status, x2.status].includes("active"), JSON.stringify([x1, x2].map((x) => [x.match_id, x.status])));
const hofMatch = await matchRow(x1.match_id);
check("pair has two distinct players", hofMatch.player_a_id !== hofMatch.player_b_id && hofMatch.player_b_id !== null);

// retry after timeout: same call again returns same active match
const retry = await find(users.ben, "pro");
check("retry after timeout returns same active match", retry.match_id === m1.match_id && retry.reused === true && retry.status === "active");

// ---------------------------------------------------------------- submission verification
const mm = m1row;
await expectError("non-member cannot submit", () => play(users.cam, mm, W4), "VERSUS_NOT_A_MEMBER");
await expectError("unknown match", () => submitRaw(users.ava, "12345678-1234-1234-1234-123456789012", []), "VERSUS_MATCH_NOT_FOUND");
await expectError("outdated protocol", () => play(users.ava, mm, W4, { protocol: 0 }), "CLIENT_OUTDATED");
await expectError("missing version", () => play(users.ava, mm, W4, { version: "  " }), "INVALID_GAME_VERSION");
await expectError("swapped case id", () => play(users.ava, mm, W4, { mutate: (o) => { o[0].case_id = mm.case_ids[1]; } }), "CASE_MISMATCH");
await expectError("client-chosen case", () => play(users.ava, mm, W4, { mutate: (o) => { o[2].case_id = "case_rookie_001"; } }), "CASE_MISMATCH");
await expectError("wrong version", () => play(users.ava, mm, W4, { mutate: (o) => { o[1].case_version = 99; } }), "CASE_VERSION_MISMATCH");
await expectError("wrong quarter index", () => play(users.ava, mm, W4, { mutate: (o) => { o[1].quarter_index = 3; } }), "INVALID_CASE_RESULTS");
await expectError("wrong profile", () => play(users.ava, mm, W4, { mutate: (o) => { o[0].placements[0] = { ...o[0].placements[0], profile: "zzz" }; } }), "PLACEMENT_MISMATCH");
await expectError("duplicate placement", () => play(users.ava, mm, W4, { mutate: (o) => { o[0].placements[1] = o[0].placements[0]; } }), "PLACEMENT_MISMATCH");
await expectError("solved but incomplete", () => play(users.ava, mm, W4, { mutate: (o) => { o[0].placements.pop(); } }), "SOLVED_CASE_INCOMPLETE");
await expectError("failed but complete", () => play(users.ava, mm, L1, { mutate: (o) => { o[1].placements = snap1[1]; } }), "FAILED_CASE_COMPLETE");
await expectError("overtime when not 2–2", () => play(users.ava, mm, [...W3, "solved"]), "OVERTIME_MISMATCH");
await expectError("missing overtime at 2–2", () => play(users.ava, mm, ["solved", "solved", "failed", "failed"]), "OVERTIME_MISMATCH");
await expectError("purchased/used hints rejected", () => play(users.ava, mm, W4, { mutate: (o) => { o[0].hints_used = 1; } }), "VERSUS_HINTS_NOT_ALLOWED");
await expectError("too few cases", () => play(users.ava, mm, ["solved", "solved", "solved"]), "INVALID_CASE_RESULTS");
const forged = await play(users.ava, mm, L0, { mutate: (o) => { o.forEach((c) => { c.final_score = 9999; c.score = 9999; c.game_won = true; }); } });
check("client score fields ignored; server scores 0 for 0 solved", forged.outcome === "recorded" && forged.final_score === 0, JSON.stringify(forged));
check("after first submit: opponent_pending", forged.player_state === "opponent_pending" && forged.match_status === "active");
const dup = await play(users.ava, mm, W4);
check("duplicate submission idempotent (first result kept)", dup.outcome === "duplicate" && dup.final_score === 0 && dup.result_id === forged.result_id);
check("one result row per player", (await rows(`select count(*)::int n from public.versus_match_results where match_id = $1 and user_id = $2`, [mm.match_id, users.ava]))[0].n === 1);
const benRes = await play(users.ben, mm, W4);
// W4 at pro: (40 + 10 + 5) * 1.25 = 68.75 → 69
check("server score for perfect pro game", benRes.final_score === 69 && benRes.cases_solved === 4, JSON.stringify(benRes));
check("second submit completes match: win", benRes.match_status === "completed" && benRes.match_outcome === "win" && benRes.opponent_final_score === 0);
const done1 = await matchRow(mm.match_id);
check("winner decided by score", done1.winner_user_id === users.ben && done1.resolution === "score" && !done1.is_tie && !done1.is_forfeit);
check("stats: ben 1-0", JSON.stringify(await stats(users.ben)).includes('"versus_wins":1') && (await stats(users.ben)).versus_games_played === 1);
check("stats: ava 0-1", (await stats(users.ava)).versus_losses === 1 && (await stats(users.ava)).versus_games_played === 1);
await expectError("cancelled match rejects results", async () => play(users.dee, await matchRow(dw.match_id), W4), "VERSUS_MATCH_CLOSED");
check("completed match stats unchanged by later calls", (await stats(users.ben)).versus_games_played === 1);

// ---------------------------------------------------------------- simultaneous results resolve once
const sim = await pair(users.jon, users.kit, "pro");
const [rj, rk] = await Promise.all([play(users.jon, sim.match, W3), play(users.kit, sim.match, W4)]);
check("both simultaneous results recorded", rj.outcome === "recorded" && rk.outcome === "recorded");
const simRow = await matchRow(sim.match.match_id);
check("simultaneous: resolved once, higher score wins", simRow.status === "completed" && simRow.winner_user_id === users.kit);
check("simultaneous: stats counted once", (await stats(users.jon)).versus_games_played === 1 && (await stats(users.kit)).versus_games_played === 1);
const [d1, d2] = await Promise.all([play(users.jon, sim.match, W4), play(users.jon, sim.match, W4)]);
check("simultaneous duplicates are idempotent", d1.outcome === "duplicate" && d2.outcome === "duplicate");

// ---------------------------------------------------------------- tiebreaks
// Equal score + equal cases + equal quarters → tie.
const t1 = await pair(users.lou, users.max, "rookie");
await play(users.lou, t1.match, W3);
const tieRes = await play(users.max, t1.match, W3);
check("identical results → tie", tieRes.match_outcome === "tie" && (await matchRow(t1.match.match_id)).resolution === "tie");
check("tie stats", (await stats(users.lou)).versus_ties === 1 && (await stats(users.max)).versus_ties === 1);
// Tiebreak paths 'cases_solved' / 'regulation_quarters' are unreachable with
// the default point table (score is monotonic in both), so prove them by
// zeroing points on a throwaway transaction-free config tweak.
await db.exec(`update public.versus_config set quarter_solved_points = 0, game_win_points = 0, overtime_win_points = 0, perfect_regulation_points = 0`);
const t2 = await pair(users.ned, users.oli, "rookie");
await play(users.ned, t2.match, OTW); // 3 cases (2 reg + OT)
await play(users.oli, t2.match, OTL); // 2 cases
const t2row = await matchRow(t2.match.match_id);
check("equal score → more cases solved wins", t2row.winner_user_id === users.ned && t2row.resolution === "cases_solved", JSON.stringify(t2row));
const t3 = await pair(users.rae, users.sam, "pro");
await play(users.rae, t3.match, W3); // 3 cases, 3 regulation
await play(users.sam, t3.match, OTW); // 3 cases, 2 regulation
const t3row = await matchRow(t3.match.match_id);
check("equal score + cases → more regulation quarters wins", t3row.winner_user_id === users.rae && t3row.resolution === "regulation_quarters", JSON.stringify(t3row));
await db.exec(`update public.versus_config set quarter_solved_points = 10, game_win_points = 10, overtime_win_points = 5, perfect_regulation_points = 5`);
// OT win scoring: (20 + 10 + 5) * 1.0 = 35 at rookie
// Finish the open rookie match (cam vs eli) first so the rookie queue is empty.
await play(users.cam, await matchRow(cw.match_id), L1);
await play(users.eli, await matchRow(cw.match_id), OTW);
const scoreProbe = await pair(users.tom, users.uma, "rookie");
const otRes = await play(users.tom, scoreProbe.match, OTW);
check("OT win rookie score = 35", otRes.final_score === 35, JSON.stringify(otRes));
const otLoss = await play(users.uma, scoreProbe.match, OTL);
// OT loss: 20 * 1.0 = 20
check("OT loss rookie score = 20, loses", otLoss.final_score === 20 && otLoss.match_outcome === "loss", JSON.stringify(otLoss));

// ---------------------------------------------------------------- expiry / forfeit
async function backdate(matchID) {
  await db.exec(`update public.versus_matches set created_at = now() - interval '3 days', matched_at = case when matched_at is null then null else now() - interval '3 days' end, expires_at = now() - interval '1 hour' where match_id = '${matchID}'`);
}
// one finisher → forfeit win
const f = await pair(users.vic, users.wes, "pro");
const gusBefore = { versus_games_played: 0, versus_wins: 0, versus_forfeit_wins: 0 };
const ivyBefore = { versus_games_played: 0, versus_losses: 0, versus_forfeit_losses: 0 };
check("forfeit players start with no record", (await stats(users.vic)) === null && (await stats(users.wes)) === null);
await play(users.vic, f.match, W3);
await backdate(f.match.match_id);
const ivyLate = await play(users.wes, f.match, W4);
check("expiry racing submission: late result rejected as expired", ivyLate.outcome === "expired" && ivyLate.result_id === null, JSON.stringify(ivyLate));
const fRow = await matchRow(f.match.match_id);
check("one finisher → forfeit win", fRow.status === "completed" && fRow.is_forfeit && fRow.winner_user_id === users.vic && fRow.resolution === "forfeit");
check("late result not stored", (await rows(`select count(*)::int n from public.versus_match_results where match_id = $1 and user_id = $2`, [f.match.match_id, users.wes]))[0].n === 0);
const gusAfter = await stats(users.vic), ivyAfter = await stats(users.wes);
check("forfeit stats: winner", gusAfter.versus_wins === gusBefore.versus_wins + 1 && gusAfter.versus_forfeit_wins === gusBefore.versus_forfeit_wins + 1);
check("forfeit stats: loser", ivyAfter.versus_losses === ivyBefore.versus_losses + 1 && ivyAfter.versus_forfeit_losses === ivyBefore.versus_forfeit_losses + 1);
const again = await play(users.wes, f.match, W4).catch((e) => e);
check("after forfeit the match is closed", again instanceof Error && String(again.message).includes("VERSUS_MATCH_CLOSED"), String(again?.message ?? JSON.stringify(again)));
check("forfeit resolved exactly once", (await stats(users.vic)).versus_games_played === gusAfter.versus_games_played);
const wesHist = await asUser(users.wes, `select * from public.my_versus_history(10, 0)`);
check("forfeit loss visible in history", wesHist.some((h) => h.match_id === f.match.match_id && h.outcome === "loss" && h.is_forfeit));

// zero finishers → expired, no record impact (resolved lazily by a read)
const z = await pair(users.jon, users.lou, "rookie");
const jonBefore = await stats(users.jon), louBefore = await stats(users.lou);
await backdate(z.match.match_id);
const jonOpen = await asUser(users.jon, `select * from public.my_versus_matches()`);
check("lazy expiry on read: no open match left", !jonOpen.some((m) => m.match_id === z.match.match_id));
const zRow = await matchRow(z.match.match_id);
check("zero finishers → expired_unplayed", zRow.status === "expired" && zRow.resolution === "expired_unplayed" && zRow.winner_user_id === null);
check("zero-player expiry: no record impact",
  JSON.stringify(await stats(users.jon)) === JSON.stringify(jonBefore) && JSON.stringify(await stats(users.lou)) === JSON.stringify(louBefore));

// waiting match nobody joined → expired_no_opponent (even if creator submitted)
const lone = await find(users.max, "hall_of_famer");
const loneRow = await matchRow(lone.match_id);
check("lone match waiting", lone.status === "waiting_for_opponent");
const loneRes = await play(users.max, loneRow, W3);
check("creator may play while waiting", loneRes.outcome === "recorded" && loneRes.player_state === "submitted");
await expectError("already waiting + submitted → cannot open second", () => find(users.max, "hall_of_famer"), "VERSUS_ALREADY_WAITING");
const maxBefore = await stats(users.max);
await backdate(lone.match_id);
const sweep = await asService(async () => (await rows(`select public.versus_expire_due(null) n`))[0].n);
check("operator sweep resolves due matches", sweep >= 1);
const loneAfter = await matchRow(lone.match_id);
check("no opponent → expired_no_opponent", loneAfter.status === "expired" && loneAfter.resolution === "expired_no_opponent");
check("no-opponent expiry: no record impact", JSON.stringify(await stats(users.max)) === JSON.stringify(maxBefore));
check("expired waiting match never claimable", (await find(users.oli, "hall_of_famer")).match_id !== lone.match_id);

// ---------------------------------------------------------------- history / privacy
const benHist = await asUser(users.ben, `select * from public.my_versus_history(10, 0)`);
check("history: completed matches only", benHist.length >= 1 && benHist.every((h) => ["win", "loss", "tie"].includes(h.outcome)));
const benFirst = benHist.find((h) => h.match_id === mm.match_id);
check("history row: win vs ava", benFirst?.outcome === "win" && benFirst.opponent_username === "ava_qb" && benFirst.opponent_final_score === 0);
check("history row has no names/email/cases", !leaks(benHist) && !JSON.stringify(benHist).match(/case_|placements|expected/));
const camHist = await asUser(users.cam, `select * from public.my_versus_history(10, 0)`);
check("history is per-user (cam cannot see ava-vs-ben)", !camHist.some((h) => h.match_id === mm.match_id));
const capped = await asUser(users.ben, `select count(*)::int n from public.my_versus_history(5000, 0)`);
check("history page size capped", capped[0].n <= 50);
// opponent score hidden until completed
const hide = await pair(users.xan, users.yul, "pro");
await play(users.xan, hide.match, W4);
const piaOpen = (await asUser(users.yul, `select * from public.my_versus_matches()`)).find((m) => m.match_id === hide.match.match_id);
check("opponent's score hidden before completion", piaOpen && piaOpen.opponent_submitted === true && piaOpen.opponent_final_score === null && piaOpen.opponent_cases_solved === null, JSON.stringify(piaOpen));
const pub = (await asUser(users.cam, `select * from public.versus_public_record($1)`, [users.ben]))[0];
check("public record: counters + public identity", pub.username === "ben_qb" && pub.versus_wins === 1 && pub.versus_games_played === 1, JSON.stringify(pub));
check("public record: no real names", !leaks(pub));
const nobody = await asUser(users.cam, `select * from public.versus_public_record($1)`, [ghost]);
check("public record of unknown user is empty", nobody.length === 0);
const solsExposed = await asUser(users.ben, `select * from public.my_versus_matches()`);
check("client reads never include solutions", !JSON.stringify(solsExposed).includes("player_key"));

// ---------------------------------------------------------------- rate limits
await db.exec(`update public.versus_config set finds_per_hour = 2`);
const rl = await asService(async () => [
  (await rows(`select public.consume_versus_rate_limit($1, 'find') ok`, [users.ned]))[0].ok,
  (await rows(`select public.consume_versus_rate_limit($1, 'find') ok`, [users.ned]))[0].ok,
  (await rows(`select public.consume_versus_rate_limit($1, 'find') ok`, [users.ned]))[0].ok,
  (await rows(`select public.consume_versus_rate_limit($1, 'submit') ok`, [users.ned]))[0].ok,
]);
check("versus find bucket limits", rl[0] && rl[1] && !rl[2] && rl[3], JSON.stringify(rl));
await expectError("unknown rate bucket", () => asService(() => rows(`select public.consume_versus_rate_limit($1, 'other')`, [users.ned])), "INVALID_RATE_LIMIT_BUCKET");
check("ranked rate limits untouched", (await rows(`select count(*)::int n from public.ranked_rate_limits`).catch(() => [{ n: 0 }]))[0].n === 0);

// ---------------------------------------------------------------- server_assigned content preferred when complete
await db.exec(`
  insert into public.competitive_catalog_meta (distribution, case_count, catalog_fingerprint, expected_checksum)
  values ('server_assigned', 5, 'srv-fp-1', 'n/a') on conflict (distribution) do nothing;
`);
for (let band = 1; band <= 5; band++) {
  const src = (await rows(`select * from public.competitive_cases where band = $1 and difficulty = 'pro' and distribution = 'client_bundled' order by case_id limit 1`, [band]))[0];
  await db.query(
    `insert into public.competitive_cases (case_id, case_version, difficulty, difficulty_score, band, missing_count, distribution, fingerprint, solutions)
     values ($1, 1, 'pro', $2, $3, $4, 'server_assigned', $5, $6)`,
    [`srv_case_00${band}`, src.difficulty_score, band, src.missing_count, `srv${band}000000000000`.slice(0, 16), src.solutions],
  );
}
const srv = await find(users.oli, "pro");
check("server_assigned pool preferred when every band has content", srv.content_source === "server_assigned"
  && srv.case_ids.every((c) => c.startsWith("srv_case_")) && srv.catalog_fingerprint === "srv-fp-1", JSON.stringify(srv));

// ---------------------------------------------------------------- Ranked untouched
check("ranked scoring config unchanged", JSON.stringify((await rows(`select * from public.ranked_scoring_config`))[0]) === rankedCfgBefore);
check("no ranked results written by versus", (await rows(`select count(*)::int n from public.ranked_game_results`))[0].n === 0);
check("profiles career stats untouched by versus",
  (await rows(`select coalesce(sum(career_games_played),0)::int n from public.profiles`))[0].n === 0);

console.log(`\n${passed} checks passed, ${failures.length} failed`);
if (failures.length) {
  for (const f of failures) console.log(" FAIL", f);
  process.exit(1);
}
