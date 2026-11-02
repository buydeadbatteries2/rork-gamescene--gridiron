// GameScene: Gridiron — Phase 15A Versus result verification.
//
// POST /functions/v1/submit-versus-result  (Authorization: Bearer <user JWT>)
// Body: {"match_id", "started_at", "completed_at", "case_results": [...],
//        "game_version", "versus_protocol"}
//
// Trust model:
//   * The user is derived from the JWT ONLY. The payload carries no user id,
//     no score, no winner and no summary; unknown top-level keys are rejected.
//   * versus_record_result (service_role only, SECURITY DEFINER,
//     search_path='') locks the match row, checks membership (player A or B),
//     status and expiry, then verifies case ids, order, versions and EVERY
//     placement against the solution SNAPSHOT taken at match creation (the
//     same snapshot for both players). It computes the score from
//     versus_config, stores the result once per (match, user) and — under the
//     same lock — resolves the winner exactly once when both results exist.
//   * Hints are disabled in Versus (no purchased advantage): a result that
//     reports hints is rejected. Wrong placements are self-reported, never
//     scored. Client timestamps are stored as claims and decide nothing.
//   * Idempotent: a retried submission returns the stored result (duplicate).
//   * A submission that arrives after the match expired never counts: the
//     database resolves the expiry (forfeit / expired) deterministically and
//     this function answers 410 versus_match_expired.
//   * Bundled case solutions ship in the app and are NOT secret while Versus
//     runs on the TEMPORARY bundled fallback; server_assigned cases are
//     never shipped to clients.
//
// Responses:
//   200 {"status":"verified","result_id","final_score","cases_solved","duplicate",
//        "match_status","player_state","match_outcome","opponent_final_score"}
//   4xx {"status":"rejected","reason"}       — final; the client never retries
//   401 / 429 / 5xx                          — transient; the client retries
import { createClient } from "jsr:@supabase/supabase-js@2";

const PROFILES = ["rookie", "veteran", "fast", "powerful", "overrated"];
const OVERTIME_INDEX = 4;
const MAX_PLACEMENTS = 8;
const MAX_BODY_BYTES = 32 * 1024;
const MAX_GAME_VERSION = 40;
const ALLOWED_KEYS = new Set(["match_id", "started_at", "completed_at", "case_results", "game_version", "versus_protocol"]);

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

export interface VersusPayload {
  match_id: string;
  started_at: string;
  completed_at: string;
  case_results: CaseResult[];
  game_version: string;
  versus_protocol: number;
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
// Structural validation (pure). The database is the authority for membership,
// expiry, the snapshot, exact solutions, overtime rules, scoring and winner.
// ---------------------------------------------------------------------------

export function validateVersusStructure(body: unknown): VersusPayload {
  ensure(typeof body === "object" && body !== null && !Array.isArray(body), "malformed_body");
  for (const key of Object.keys(body as Record<string, unknown>)) ensure(ALLOWED_KEYS.has(key), "unexpected_field");
  const p = body as VersusPayload;
  ensure(typeof p.match_id === "string" && UUID_RE.test(p.match_id), "invalid_match_id");
  ensure(typeof p.game_version === "string" && p.game_version.trim().length >= 1 &&
    p.game_version.trim().length <= MAX_GAME_VERSION, "invalid_game_version");
  ensure(isInt(p.versus_protocol, 1, 1000), "client_outdated");

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
    // No purchased advantage: hints are disabled in Versus.
    ensure(c.hints_used === 0, "versus_hints_not_allowed");
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
export function sanitizedVersusCaseResults(results: CaseResult[]): CaseResult[] {
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
export const VERSUS_RECORD_ERRORS: ReadonlyArray<readonly [string, number]> = [
  ["VERSUS_MATCH_NOT_FOUND", 404],
  ["VERSUS_NOT_A_MEMBER", 403],
  ["VERSUS_MATCH_CLOSED", 409],
  ["VERSUS_HINTS_NOT_ALLOWED", 422],
  ["VERSUS_SNAPSHOT_MISSING", 409],
  ["CLIENT_OUTDATED", 426],
  ["INVALID_GAME_VERSION", 422],
  ["CASE_VERSION_MISMATCH", 409],
  ["CASE_MISMATCH", 409],
  ["PLACEMENT_MISMATCH", 422],
  ["SOLVED_CASE_INCOMPLETE", 422],
  ["FAILED_CASE_COMPLETE", 422],
  ["OVERTIME_MISMATCH", 422],
  ["INVALID_CASE_RESULTS", 422],
  ["INVALID_ARGUMENTS", 422],
];

export function mapVersusRecordError(message: string): { reason: string; status: number } {
  for (const [code, status] of VERSUS_RECORD_ERRORS) {
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

  // 3. Declared size precheck BEFORE reading the body.
  const declared = Number(req.headers.get("Content-Length") ?? "0");
  if (Number.isFinite(declared) && declared > MAX_BODY_BYTES) return reject("body_too_large", 413);

  // 4. Atomic per-user rate limit (Versus 'submit' bucket).
  const { data: allowed, error: limitError } = await admin.rpc("consume_versus_rate_limit", {
    p_user_id: userID,
    p_bucket: "submit",
  });
  if (limitError) return json(503, { status: "error", reason: "rate_limit_unavailable" });
  if (allowed !== true) return json(429, { status: "error", reason: "rate_limited" });

  // 5. Bounded read + parse + structure.
  const raw = await req.text();
  if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) return reject("body_too_large", 413);
  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    return reject("malformed_body", 400);
  }
  let payload: VersusPayload;
  try {
    payload = validateVersusStructure(body);
  } catch (error) {
    const reason = error instanceof Rejection ? error.reason : "malformed_body";
    return reject(reason, reason === "client_outdated" ? 426 : 422);
  }

  // 6. Record — the database verifies, scores, stores once, resolves once.
  const { data, error } = await admin.rpc("versus_record_result", {
    p_user_id: userID,
    p_match_id: payload.match_id,
    p_case_results: sanitizedVersusCaseResults(payload.case_results),
    p_started_at: payload.started_at,
    p_completed_at: payload.completed_at,
    p_game_version: payload.game_version,
    p_versus_protocol: payload.versus_protocol,
  });
  if (error) {
    const mapped = mapVersusRecordError(error.message ?? "");
    if (mapped.status >= 500) return json(mapped.status, { status: "error", reason: mapped.reason });
    return reject(mapped.reason, mapped.status);
  }
  const row = (Array.isArray(data) ? data[0] : data) as Record<string, unknown> | undefined;
  if (!row) return json(503, { status: "error", reason: "record_failed" });
  if (row.outcome === "expired") return reject("versus_match_expired", 410);
  const completed = row.match_status === "completed";
  return json(200, {
    status: "verified",
    result_id: row.result_id,
    final_score: row.final_score,
    cases_solved: row.cases_solved,
    duplicate: row.outcome === "duplicate",
    match_status: row.match_status,
    player_state: row.player_state,
    match_outcome: completed ? (row.match_outcome ?? null) : null,
    opponent_final_score: completed ? (row.opponent_final_score ?? null) : null,
  });
});
