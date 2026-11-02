// GameScene: Gridiron — Phase 15A asynchronous 1-v-1 Versus matchmaking.
//
// POST /functions/v1/find-versus-match  (Authorization: Bearer <user JWT>)
// Body: {"difficulty": "rookie"|"pro"|"all_pro"|"hall_of_famer"}   — nothing else.
//
// Trust model:
//   * The user comes from the JWT ONLY. The body may carry the difficulty and
//     nothing else: any other key (user_id, opponent_id, match_id, case_ids,
//     score …) is REJECTED, so a client can never name an opponent or a case.
//   * The SERVER pairs players. versus_find_match (service_role only,
//     SECURITY DEFINER, search_path='') serializes matchmaking with advisory
//     locks (per user, then per difficulty queue), claims the oldest waiting
//     match of the SAME difficulty created by someone else with FOR UPDATE
//     SKIP LOCKED (never self, never a duplicate active pairing), or opens a
//     waiting match with a fresh server-chosen five-case snapshot. One waiting
//     match per user (unique index). Re-calling while a match of the same
//     difficulty is unplayed returns it again (reused = true) — safe for
//     double taps and retry-after-timeout.
//   * The response carries ONLY what the client needs to play: match id,
//     status, case ids + versions, timestamps, catalog fingerprint, content
//     source and the opponent's PUBLIC identity (username + football display
//     name). Never solutions, the solution variant or another player's score
//     before the match completes.
//
// Responses:
//   200 {"status":"matched"|"waiting", "match": {...}}
//   4xx {"status":"rejected","reason"}   — final for this request
//   401 / 429 / 5xx                      — transient; the client may retry
import { createClient } from "jsr:@supabase/supabase-js@2";

const DIFFICULTIES = ["rookie", "pro", "all_pro", "hall_of_famer"] as const;
type Difficulty = (typeof DIFFICULTIES)[number];
const MAX_BODY_BYTES = 1024;
const ALLOWED_KEYS = new Set(["difficulty"]);

export interface FindRequest {
  difficulty: Difficulty;
}

class Rejection extends Error {
  constructor(public reason: string) {
    super(reason);
  }
}

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function reject(reason: string, status = 422): Response {
  return json(status, { status: "rejected", reason });
}

function ensure(condition: boolean, reason: string): asserts condition {
  if (!condition) throw new Rejection(reason);
}

/// Structural validation (pure): difficulty ONLY. Unknown keys are rejected
/// so a client cannot even attempt to choose an opponent, match or case.
export function validateFindRequest(body: unknown): FindRequest {
  ensure(typeof body === "object" && body !== null && !Array.isArray(body), "malformed_body");
  const p = body as Record<string, unknown>;
  for (const key of Object.keys(p)) ensure(ALLOWED_KEYS.has(key), "unexpected_field");
  ensure(DIFFICULTIES.includes(p.difficulty as Difficulty), "invalid_difficulty");
  return { difficulty: p.difficulty as Difficulty };
}

/// Database error → (reason, HTTP status). Unknown errors are transient (503).
export const FIND_ERRORS: ReadonlyArray<readonly [string, number]> = [
  ["VERSUS_MATCH_IN_PROGRESS", 409],
  ["VERSUS_ALREADY_WAITING", 409],
  ["PROFILE_REQUIRED", 403],
  ["INVALID_DIFFICULTY", 422],
  ["INVALID_ARGUMENTS", 422],
  ["VERSUS_CATALOG_UNAVAILABLE", 503],
  ["VERSUS_CONFIG_MISSING", 503],
];

export function mapFindError(message: string): { reason: string; status: number } {
  for (const [code, status] of FIND_ERRORS) {
    if (message.includes(code)) return { reason: code.toLowerCase(), status };
  }
  return { reason: "matchmaking_failed", status: 503 };
}

/// ISO-8601 with millisecond precision (Postgres returns microseconds).
function isoMillis(value: unknown): unknown {
  const parsed = typeof value === "string" ? Date.parse(value) : NaN;
  return Number.isFinite(parsed) ? new Date(parsed).toISOString() : value;
}

/// Whitelist of fields returned to the client (shared shape with the
/// my_versus_matches RPC so the app decodes one model).
export function publicVersusMatch(row: Record<string, unknown>): Record<string, unknown> {
  const completed = row.status === "completed";
  return {
    match_id: row.match_id,
    status: row.status,
    player_state: row.player_state,
    role: row.role,
    difficulty: row.difficulty,
    case_ids: row.case_ids,
    case_versions: row.case_versions,
    catalog_fingerprint: row.catalog_fingerprint,
    content_source: row.content_source,
    created_at: isoMillis(row.created_at),
    matched_at: row.matched_at == null ? null : isoMillis(row.matched_at),
    expires_at: isoMillis(row.expires_at),
    completed_at: row.completed_at == null ? null : isoMillis(row.completed_at),
    opponent_user_id: row.opponent_user_id ?? null,
    opponent_username: row.opponent_username ?? null,
    opponent_display_name: row.opponent_display_name ?? null,
    my_submitted: row.my_submitted === true,
    my_final_score: row.my_final_score ?? null,
    my_cases_solved: row.my_cases_solved ?? null,
    opponent_submitted: row.opponent_submitted === true,
    // Defense in depth: never reveal the opponent's numbers before completion.
    opponent_final_score: completed ? (row.opponent_final_score ?? null) : null,
    opponent_cases_solved: completed ? (row.opponent_cases_solved ?? null) : null,
    outcome: row.outcome ?? null,
    is_forfeit: row.is_forfeit === true,
    resolution: row.resolution ?? null,
    reused: row.reused === true,
  };
}

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

  // 4. Atomic per-user rate limit (Versus 'find' bucket; Ranked untouched).
  const { data: allowed, error: limitError } = await admin.rpc("consume_versus_rate_limit", {
    p_user_id: userID,
    p_bucket: "find",
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
  let request: FindRequest;
  try {
    request = validateFindRequest(body);
  } catch (error) {
    return reject(error instanceof Rejection ? error.reason : "malformed_body");
  }

  // 6. Matchmaking — the database pairs, snapshots and persists atomically.
  const { data, error } = await admin.rpc("versus_find_match", {
    p_user_id: userID,
    p_difficulty: request.difficulty,
  });
  if (error) {
    const mapped = mapFindError(error.message ?? "");
    if (mapped.status >= 500) return json(mapped.status, { status: "error", reason: mapped.reason });
    return reject(mapped.reason, mapped.status);
  }
  const row = (Array.isArray(data) ? data[0] : data) as Record<string, unknown> | undefined;
  if (!row) return json(503, { status: "error", reason: "matchmaking_failed" });
  const status = row.status === "waiting_for_opponent" ? "waiting" : "matched";
  return json(200, { status, match: publicVersusMatch(row) });
});
