// Phase 15A — runs the REAL Versus Edge Function sources locally (no Supabase).
//
// Each index.ts is loaded with its jsr import replaced by a stub client and a
// fake Deno global that captures the request handler. The pure validators and
// error mappers are exercised directly, and the handler is driven end-to-end
// with a mock admin client to prove: JWT-only identity, difficulty-only body,
// rate limiting before matchmaking, whitelisted responses, and the
// expired → 410 mapping.
//
//   bun scripts/verify-versus-edge.mjs
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const work = mkdtempSync(join(tmpdir(), "versus-edge-"));

let passed = 0;
const failures = [];
function check(name, condition, detail = "") {
  if (condition) passed += 1;
  else failures.push(`${name} ${detail}`);
}
function throwsReason(fn, reason) {
  try {
    fn();
    return false;
  } catch (e) {
    return e.reason === reason;
  }
}

// Mock Supabase admin client, configured per request.
globalThis.__mock = null;
writeFileSync(join(work, "stub.ts"), `
export function createClient() {
  const m = (globalThis as any).__mock;
  return {
    auth: { getUser: async (t: string) => m.users[t] ? { data: { user: { id: m.users[t] } }, error: null } : { data: null, error: { message: "bad jwt" } } },
    rpc: async (name: string, args: Record<string, unknown>) => { m.calls.push({ name, args }); return m.rpc(name, args); },
    from: () => ({ insert: async () => ({}) }),
  };
}
`);
let handler = null;
globalThis.Deno = {
  env: { get: (k) => ({ SUPABASE_URL: "http://local", SUPABASE_SERVICE_ROLE_KEY: "svc" })[k] },
  serve: (fn) => { handler = fn; },
};
async function load(name) {
  const src = readFileSync(join(ROOT, `supabase/functions/${name}/index.ts`), "utf8")
    .replace(`from "jsr:@supabase/supabase-js@2"`, `from "./stub.ts"`);
  const file = join(work, `${name}.ts`);
  writeFileSync(file, src);
  const mod = await import(file);
  return { mod, handler };
}

function mock(rpc, users = { "jwt-ava": "aaaaaaaa-0000-0000-0000-000000000001" }) {
  globalThis.__mock = { users, calls: [], rpc };
  return globalThis.__mock;
}
function post(body, token = "jwt-ava", extraHeaders = {}) {
  const raw = typeof body === "string" ? body : JSON.stringify(body);
  return new Request("http://local/fn", {
    method: "POST",
    headers: { Authorization: token ? `Bearer ${token}` : "", "Content-Type": "application/json", ...extraHeaders },
    body: raw,
  });
}

// ---------------------------------------------------------------- find-versus-match
const find = await load("find-versus-match");
const { validateFindRequest, mapFindError, publicVersusMatch } = find.mod;
check("find: difficulty accepted", validateFindRequest({ difficulty: "pro" }).difficulty === "pro");
check("find: invalid difficulty", throwsReason(() => validateFindRequest({ difficulty: "legend" }), "invalid_difficulty"));
check("find: opponent id rejected", throwsReason(() => validateFindRequest({ difficulty: "pro", opponent_id: "x" }), "unexpected_field"));
check("find: user id rejected", throwsReason(() => validateFindRequest({ difficulty: "pro", user_id: "x" }), "unexpected_field"));
check("find: case ids rejected", throwsReason(() => validateFindRequest({ difficulty: "pro", case_ids: [] }), "unexpected_field"));
check("find: match id rejected", throwsReason(() => validateFindRequest({ difficulty: "pro", match_id: "x" }), "unexpected_field"));
check("find: array body rejected", throwsReason(() => validateFindRequest([]), "malformed_body"));
check("find: in-progress → 409", mapFindError("VERSUS_MATCH_IN_PROGRESS").status === 409);
check("find: already waiting → 409", mapFindError("x VERSUS_ALREADY_WAITING y").status === 409);
check("find: profile → 403", mapFindError("PROFILE_REQUIRED").status === 403);
check("find: catalog → 503", mapFindError("VERSUS_CATALOG_UNAVAILABLE").status === 503);
check("find: unknown → 503 retryable", mapFindError("boom").status === 503);
const hidden = publicVersusMatch({ status: "active", opponent_final_score: 50, opponent_cases_solved: 3, solutions: [1], solution_variant: "pro" });
check("find: opponent score hidden before completion", hidden.opponent_final_score === null && hidden.opponent_cases_solved === null);
check("find: solutions / variant never serialized", !("solutions" in hidden) && !("solution_variant" in hidden) && !("expected_solutions" in hidden));

const row = {
  match_id: "m1", status: "waiting_for_opponent", player_state: "waiting_for_opponent", role: "player_a", difficulty: "pro",
  case_ids: ["a", "b", "c", "d", "e"], case_versions: [1, 1, 1, 1, 1], catalog_fingerprint: "fp", content_source: "bundled_dev_fallback",
  created_at: "2026-11-02T10:00:00.123456+00:00", matched_at: null, expires_at: "2026-11-03T10:00:00.123456+00:00", completed_at: null,
  opponent_user_id: null, my_submitted: false, opponent_submitted: false, is_forfeit: false, reused: false,
};
let m = mock(async (name) => (name === "consume_versus_rate_limit" ? { data: true, error: null } : { data: [row], error: null }));
let res = await find.handler(post({ difficulty: "pro" }));
let out = await res.json();
check("find: 200 waiting", res.status === 200 && out.status === "waiting" && out.match.match_id === "m1", JSON.stringify(out));
check("find: millisecond timestamps", out.match.created_at === "2026-11-02T10:00:00.123Z");
const mmCall = m.calls.find((c) => c.name === "versus_find_match");
check("find: user from JWT, difficulty only", mmCall.args.p_user_id === "aaaaaaaa-0000-0000-0000-000000000001" && mmCall.args.p_difficulty === "pro"
  && Object.keys(mmCall.args).length === 2);
check("find: rate limit precedes matchmaking", m.calls[0].name === "consume_versus_rate_limit" && m.calls[0].args.p_bucket === "find");

m = mock(async () => ({ data: [{ ...row, status: "active", player_state: "active" }], error: null }));
m.rpc = async (name) => (name === "consume_versus_rate_limit" ? { data: true, error: null } : { data: [{ ...row, status: "active", player_state: "active" }], error: null });
out = await (await find.handler(post({ difficulty: "pro" }))).json();
check("find: active → matched", out.status === "matched");

m = mock(async () => ({ data: true, error: null }));
res = await find.handler(post({ difficulty: "pro" }, null));
check("find: missing JWT → 401", res.status === 401 && m.calls.length === 0);
res = await find.handler(post({ difficulty: "pro" }, "forged"));
check("find: invalid JWT → 401", res.status === 401 && m.calls.length === 0);
res = await find.handler(new Request("http://local/fn", { method: "GET" }));
check("find: GET → 405", res.status === 405);
res = await find.handler(post({ difficulty: "pro", opponent_id: "aaaaaaaa-0000-0000-0000-000000000002" }));
check("find: opponent in body → 422, never reaches matchmaking", res.status === 422 && !m.calls.some((c) => c.name === "versus_find_match"));
res = await find.handler(post("{nope"));
check("find: malformed JSON → 400", res.status === 400);
m = mock(async (name) => (name === "consume_versus_rate_limit" ? { data: false, error: null } : { data: [row], error: null }));
res = await find.handler(post({ difficulty: "pro" }));
check("find: rate limited → 429", res.status === 429 && !m.calls.some((c) => c.name === "versus_find_match"));
m = mock(async (name) => (name === "consume_versus_rate_limit" ? { data: true, error: null } : { data: null, error: { message: "VERSUS_MATCH_IN_PROGRESS" } }));
res = await find.handler(post({ difficulty: "rookie" }));
out = await res.json();
check("find: DB rejection → 409 rejected", res.status === 409 && out.status === "rejected" && out.reason === "versus_match_in_progress");
res = await find.handler(post({ difficulty: "pro" }, "jwt-ava", { "Content-Length": "5000" }));
check("find: oversized body → 413", res.status === 413);

// ---------------------------------------------------------------- submit-versus-result
const submit = await load("submit-versus-result");
const { validateVersusStructure, sanitizedVersusCaseResults, mapVersusRecordError } = submit.mod;
const pl = (i) => ({ player_key: `p${i}`, slot_key: `s${i}`, profile: "veteran" });
const caseResult = (i, extra = {}) => ({ case_id: `case_${i}`, case_version: 1, quarter_index: i, outcome: "solved", hints_used: 0, wrong_placements: 0, placements: [pl(1), pl(2)], ...extra });
const good = {
  match_id: "aaaaaaaa-1111-2222-3333-444444444444", started_at: "2026-11-02T10:00:00Z", completed_at: "2026-11-02T10:10:00Z",
  case_results: [0, 1, 2, 3].map((i) => caseResult(i)), game_version: "ios 1.0", versus_protocol: 1,
};
check("submit: valid payload", validateVersusStructure(structuredClone(good)).match_id === good.match_id);
check("submit: score field rejected", throwsReason(() => validateVersusStructure({ ...good, final_score: 999 }), "unexpected_field"));
check("submit: winner field rejected", throwsReason(() => validateVersusStructure({ ...good, winner_user_id: "x" }), "unexpected_field"));
check("submit: user id rejected", throwsReason(() => validateVersusStructure({ ...good, user_id: "x" }), "unexpected_field"));
check("submit: hints rejected", throwsReason(() => validateVersusStructure({ ...good, case_results: [caseResult(0, { hints_used: 1 }), ...good.case_results.slice(1)] }), "versus_hints_not_allowed"));
check("submit: bad match id", throwsReason(() => validateVersusStructure({ ...good, match_id: "nope" }), "invalid_match_id"));
check("submit: 3 cases rejected", throwsReason(() => validateVersusStructure({ ...good, case_results: good.case_results.slice(0, 3) }), "invalid_case_count"));
check("submit: quarter order enforced", throwsReason(() => validateVersusStructure({ ...good, case_results: [caseResult(1), caseResult(0), caseResult(2), caseResult(3)] }), "invalid_quarter_index"));
check("submit: duplicate placement", throwsReason(() => validateVersusStructure({ ...good, case_results: [caseResult(0, { placements: [pl(1), pl(1)] }), ...good.case_results.slice(1)] }), "duplicate_placement"));
check("submit: reversed timestamps", throwsReason(() => validateVersusStructure({ ...good, started_at: good.completed_at, completed_at: good.started_at }), "invalid_timestamps"));
check("submit: protocol 0 → client_outdated", throwsReason(() => validateVersusStructure({ ...good, versus_protocol: 0 }), "client_outdated"));
const sanitized = sanitizedVersusCaseResults([{ ...caseResult(0), score: 999, placements: [{ ...pl(1), extra: 1 }] }]);
check("submit: sanitizer drops unknown keys", !("score" in sanitized[0]) && !("extra" in sanitized[0].placements[0]));
check("submit: not a member → 403", mapVersusRecordError("VERSUS_NOT_A_MEMBER").status === 403);
check("submit: closed → 409", mapVersusRecordError("VERSUS_MATCH_CLOSED").status === 409);
check("submit: case version mismatch maps precisely", mapVersusRecordError("CASE_VERSION_MISMATCH").reason === "case_version_mismatch");
check("submit: unknown → 503", mapVersusRecordError("boom").status === 503);

const recorded = { outcome: "recorded", result_id: "r1", final_score: 69, cases_solved: 4, match_status: "active", player_state: "opponent_pending", match_outcome: null, opponent_final_score: 40 };
m = mock(async (name) => (name === "consume_versus_rate_limit" ? { data: true, error: null } : { data: [recorded], error: null }));
res = await submit.handler(post(good));
out = await res.json();
check("submit: 200 verified", res.status === 200 && out.status === "verified" && out.final_score === 69 && out.duplicate === false, JSON.stringify(out));
check("submit: opponent score hidden while pending", out.opponent_final_score === null && out.match_outcome === null);
const recCall = m.calls.find((c) => c.name === "versus_record_result");
check("submit: user from JWT; no score passed", recCall.args.p_user_id === "aaaaaaaa-0000-0000-0000-000000000001" && !("p_final_score" in recCall.args));
check("submit: rate bucket submit", m.calls[0].args.p_bucket === "submit");
m = mock(async (name) => (name === "consume_versus_rate_limit" ? { data: true, error: null } : { data: [{ ...recorded, outcome: "duplicate", match_status: "completed", match_outcome: "win" }], error: null }));
out = await (await submit.handler(post(good))).json();
check("submit: duplicate flagged, final outcome shown", out.duplicate === true && out.match_outcome === "win" && out.opponent_final_score === 40);
m = mock(async (name) => (name === "consume_versus_rate_limit" ? { data: true, error: null } : { data: [{ outcome: "expired", result_id: null, match_status: "completed" }], error: null }));
res = await submit.handler(post(good));
out = await res.json();
check("submit: expired → 410 rejected", res.status === 410 && out.reason === "versus_match_expired");
m = mock(async (name) => (name === "consume_versus_rate_limit" ? { data: true, error: null } : { data: null, error: { message: "VERSUS_NOT_A_MEMBER" } }));
res = await submit.handler(post(good));
check("submit: non-member → 403", res.status === 403);
m = mock(async () => ({ data: true, error: null }));
res = await submit.handler(post(good, null));
check("submit: no JWT → 401", res.status === 401 && m.calls.length === 0);
res = await submit.handler(post({ ...good, final_score: 500 }));
check("submit: client score → 422 before DB", res.status === 422 && !m.calls.some((c) => c.name === "versus_record_result"));

console.log(`\n${passed} checks passed, ${failures.length} failed`);
if (failures.length) {
  for (const f of failures) console.log(" FAIL", f);
  process.exit(1);
}
