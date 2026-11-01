// GameScene: Gridiron — Phase 14B ranked result verification.
//
// POST /functions/v1/submit-ranked-result  (Authorization: Bearer <user JWT>)
//
// Trust model:
//   * The user is derived from the JWT ONLY. The payload carries no user_id;
//     one sent by an old client is ignored, never an authority.
//   * Every ranked game is bound to a SERVER assignment created by
//     start-ranked-match. record_verified_ranked_result (service_role only,
//     SECURITY DEFINER, search_path='') loads the assignment by match_id FOR
//     UPDATE and verifies owner, season, game number, difficulty, case ids,
//     case order and case versions, rejects consumed / replaced / expired
//     assignments, and checks every placement against the EXACT adapted
//     solution snapshotted at issue time (no "any length-1 subset" leeway).
//   * This function is a thin STRUCTURAL validator. It holds no catalog,
//     solution or scoring logic; the client sends no score and no summary.
//     The database computes the score from ranked_scoring_config and updates
//     career stats after the insert, in one transaction.
//   * Hints and wrong placements are SELF-REPORTED, stored for display only,
//     never scored and never called verified.
//   * Bundled case solutions ship in the app and are NOT secret: this is
//     consistency checking against server assignments, not anti-cheat.
//   * Idempotent by match_id: a retried submission returns the stored result.
//   * Leaderboard week: completed_at is a CLAIM. The database honors it only
//     after validating it against receipt time, assignment issue time,
//     duration, account age and the player's previous TRUSTED games; else it
//     uses receipt time and returns the bucket it used.
//   * Order: method → auth → Content-Length precheck → atomic rate limit →
//     bounded read → parse → structure → record.
//
// Responses:
//   200 {"status":"verified","result_id","final_score","duplicate","leaderboard_at","leaderboard_at_source"}
//   4xx {"status":"rejected","reason"}       — final; the client never retries
//   401 / 429 / 5xx                          — transient; the client retries
import { createClient } from "jsr:@supabase/supabase-js@2";

const DIFFICULTIES = ["rookie", "pro", "all_pro", "hall_of_famer"] as const;
type Difficulty = (typeof DIFFICULTIES)[number];
const PROFILES = ["rookie", "veteran", "fast", "powerful", "overrated"];
const OVERTIME_INDEX = 4;
const MAX_PLACEMENTS = 8;
const MAX_BODY_BYTES = 32 * 1024;
const MAX_GAME_VERSION = 40;

interface Placement {
  player_key: string;
  slot_key: string;
  profile: string;
}

interface CaseResult {
  case_id: string;
  case_version: number;
  quarter_index: number;
  outcome: "solved" | "failed";
  hints_used: number;
  wrong_placements: number;
  placements: Placement[];
}

export interface Payload {
  match_id: string;
  season_id: string;
  game_number: number;
  difficulty: Difficulty;
  started_at: string;
  completed_at: string;
  case_results: CaseResult[];
  game_version: string;
  ranked_protocol: number;
}

class Rejection extends Error {
  constructor(public reason: string) {
    super(reason);
  }
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const KEY_RE = /^[A-Za-z0-9_-]{1,64}$/;

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function reject(reason: string, status = 422): Response {
  return json(status, { status: "rejected", reason });
}

function isInt(value: unknown, min: number, max: number): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= min && value <= max;
}

function ensure(condition: boolean, reason: string): asserts condition {
  if (!condition) throw new Rejection(reason);
}

// ---------------------------------------------------------------------------
// Structural validation (pure). The database is the authority for everything
// semantic: assignment binding, exact solutions, overtime rules, scoring and
// timestamp trust. A body user_id is ignored (never read).
// ---------------------------------------------------------------------------

export function validateStructure(body: unknown): Payload {
  ensure(typeof body === "object" && body !== null && !Array.isArray(body), "malformed_body");
  const p = body as Payload;
  ensure(typeof p.match_id === "string" && UUID_RE.test(p.match_id), "invalid_match_id");
  ensure(typeof p.season_id === "string" && UUID_RE.test(p.season_id), "invalid_season_id");
  ensure(isInt(p.game_number, 1, 12), "invalid_game_number");
  ensure(DIFFICULTIES.includes(p.difficulty), "invalid_difficulty");
  ensure(typeof p.game_version === "string" && p.game_version.trim().length >= 1 &&
    p.game_version.trim().length <= MAX_GAME_VERSION, "invalid_game_version");
  ensure(isInt(p.ranked_protocol, 1, 1000), "client_outdated");

  const started = Date.parse(p.started_at);
  const completed = Date.parse(p.completed_at);
  ensure(typeof p.started_at === "string" && typeof p.completed_at === "string" &&
    Number.isFinite(started) && Number.isFinite(completed) && started < completed, "invalid_timestamps");

  ensure(Array.isArray(p.case_results), "invalid_case_results");
  ensure(p.case_results.length === 4 || p.case_results.length === 5, "invalid_case_count");
  const caseIDs = new Set<string>();
  p.case_results.forEach((c, i) => {
    ensure(typeof c === "object" && c !== null, "invalid_case_results");
    ensure(typeof c.case_id === "string" && KEY_RE.test(c.case_id), "invalid_case_id");
    ensure(isInt(c.case_version, 1, 100000), "invalid_case_version");
    ensure(c.quarter_index === i && isInt(c.quarter_index, 0, OVERTIME_INDEX), "invalid_quarter_index");
    ensure(c.outcome === "solved" || c.outcome === "failed", "invalid_outcome");
    ensure(isInt(c.hints_used, 0, 100) && isInt(c.wrong_placements, 0, 100), "invalid_case_totals");
    ensure(Array.isArray(c.placements) && c.placements.length <= MAX_PLACEMENTS, "invalid_placements");
    const players = new Set<string>();
    const slots = new Set<string>();
    for (const pl of c.placements) {
      ensure(typeof pl === "object" && pl !== null && typeof pl.player_key === "string" &&
        typeof pl.slot_key === "string" && KEY_RE.test(pl.player_key) && KEY_RE.test(pl.slot_key) &&
        PROFILES.includes(pl.profile), "invalid_placement");
      ensure(!players.has(pl.player_key) && !slots.has(pl.slot_key), "duplicate_placement");
      players.add(pl.player_key);
      slots.add(pl.slot_key);
    }
    ensure(!caseIDs.has(c.case_id), "duplicate_case");
    caseIDs.add(c.case_id);
  });
  return p;
}

/// Only the fields the writer needs, re-serialized (drops unknown keys).
export function sanitizedCaseResults(results: CaseResult[]): CaseResult[] {
  return results.map((c) => ({
    case_id: c.case_id,
    case_version: c.case_version,
    quarter_index: c.quarter_index,
    outcome: c.outcome,
    hints_used: c.hints_used,
    wrong_placements: c.wrong_placements,
    placements: c.placements.map((pl) => ({ player_key: pl.player_key, slot_key: pl.slot_key, profile: pl.profile })),
  }));
}

/// Database error → (reason, HTTP status). 4xx is final; unknown → 503.
export const RECORD_ERRORS: ReadonlyArray<readonly [string, number]> = [
  ["MATCH_ID_CONFLICT", 409],
  ["CLIENT_OUTDATED", 426],
  ["INVALID_GAME_VERSION", 422],
  ["ASSIGNMENT_NOT_FOUND", 404],
  ["ASSIGNMENT_OWNER_MISMATCH", 403],
  ["ASSIGNMENT_MISMATCH", 409],
  ["ASSIGNMENT_CONSUMED", 409],
  ["ASSIGNMENT_REPLACED", 409],
  ["ASSIGNMENT_EXPIRED", 410],
  ["DUPLICATE_SEASON_GAME", 409],
  ["CASE_VERSION_MISMATCH", 409],
  ["CASE_MISMATCH", 409],
  ["PLACEMENT_MISMATCH", 422],
  ["SOLVED_CASE_INCOMPLETE", 422],
  ["FAILED_CASE_COMPLETE", 422],
  ["OVERTIME_MISMATCH", 422],
  ["INVALID_CASE_RESULTS", 422],
  ["INVALID_DIFFICULTY", 422],
  ["INVALID_ARGUMENTS", 422],
];

export function mapRecordError(message: string): { reason: string; status: number } {
  for (const [code, status] of RECORD_ERRORS) {
    if (message.includes(code)) return { reason: code.toLowerCase(), status };
  }
  return { reason: "record_failed", status: 503 };
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request): Promise<Response> => {
  // 1. Method.
  if (req.method !== "POST") return json(405, { status: "error", reason: "method_not_allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json(500, { status: "error", reason: "server_misconfigured" });

  // 2. Authenticate: the user comes from the JWT, never from the body.
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) return json(401, { status: "error", reason: "unauthorized" });
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const userID = userData?.user?.id;
  if (userError || !userID) return json(401, { status: "error", reason: "unauthorized" });

  const logAttempt = async (matchID: string | null, outcome: string, reason: string | null) => {
    await admin.from("ranked_submission_attempts").insert({ user_id: userID, match_id: matchID, outcome, reason });
  };

  // 3. Declared size precheck BEFORE reading the body.
  const declared = Number(req.headers.get("Content-Length") ?? "0");
  if (Number.isFinite(declared) && declared > MAX_BODY_BYTES) return reject("body_too_large", 413);

  // 4. Atomic per-user rate limit ('submit' bucket) — one upsert, race-free.
  const { data: allowed, error: limitError } = await admin.rpc("consume_ranked_rate_limit", {
    p_user_id: userID,
    p_bucket: "submit",
  });
  if (limitError) return json(503, { status: "error", reason: "rate_limit_unavailable" });
  if (allowed !== true) return json(429, { status: "error", reason: "rate_limited" });

  // 5. Bounded read (Content-Length may be absent or understated).
  const raw = await req.text();
  if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) return reject("body_too_large", 413);
  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    await logAttempt(null, "rejected", "malformed_body");
    return reject("malformed_body", 400);
  }

  // 6. Structure.
  let payload: Payload;
  try {
    payload = validateStructure(body);
  } catch (error) {
    const reason = error instanceof Rejection ? error.reason : "malformed_body";
    await logAttempt(null, "rejected", reason);
    return reject(reason, reason === "client_outdated" ? 426 : 422);
  }

  // 7. Record — the database verifies the assignment + exact solutions,
  //    computes the score and updates career stats (idempotent by match_id).
  const { data: recorded, error: recordError } = await admin.rpc("record_verified_ranked_result", {
    p_user_id: userID,
    p_match_id: payload.match_id,
    p_season_id: payload.season_id,
    p_game_number: payload.game_number,
    p_difficulty: payload.difficulty,
    p_case_results: sanitizedCaseResults(payload.case_results),
    p_started_at: payload.started_at,
    p_completed_at: payload.completed_at,
    p_game_version: payload.game_version,
    p_ranked_protocol: payload.ranked_protocol,
  });
  if (recordError) {
    const mapped = mapRecordError(recordError.message ?? "");
    if (mapped.status >= 500) {
      await logAttempt(payload.match_id, "error", mapped.reason);
      return json(mapped.status, { status: "error", reason: mapped.reason });
    }
    await logAttempt(payload.match_id, "rejected", mapped.reason);
    return reject(mapped.reason, mapped.status);
  }
  const row = (Array.isArray(recorded) ? recorded[0] : recorded) as Record<string, unknown> | undefined;
  if (!row) {
    await logAttempt(payload.match_id, "error", "record_failed");
    return json(503, { status: "error", reason: "record_failed" });
  }
  await logAttempt(payload.match_id, row.duplicate ? "duplicate" : "verified", null);
  return json(200, {
    status: "verified",
    result_id: row.result_id,
    final_score: row.final_score,
    duplicate: row.duplicate === true,
    leaderboard_at: row.leaderboard_at,
    leaderboard_at_source: row.leaderboard_at_source,
  });
});
